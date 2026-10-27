use crate::config::{Config, OWN_MASK, RETURN_MASK, UPSTREAM_MASK};
use anyhow::{Context, Result, ensure};
use rusqlite::Connection;
use serde::Serialize;
use std::{
    collections::BTreeMap,
    fs::{File, OpenOptions},
    io::Write,
    os::unix::fs::{OpenOptionsExt, PermissionsExt},
    path::Path,
    sync::atomic::{AtomicU64, Ordering},
    time::Duration,
};
use tokio::{io::AsyncWriteExt, process::Command};

#[derive(Clone, Serialize)]
pub struct Health {
    pub ready: bool,
    pub detail: &'static str,
}

pub fn atomic_write(path: &Path, bytes: &[u8], mode: u32) -> Result<()> {
    static SEQUENCE: AtomicU64 = AtomicU64::new(0);
    let parent = path.parent().context("missing parent directory")?;
    let temporary = parent.join(format!(
        ".write-{}-{}",
        std::process::id(),
        SEQUENCE.fetch_add(1, Ordering::Relaxed)
    ));
    let result = (|| {
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(mode)
            .open(&temporary)?;
        file.write_all(bytes)?;
        file.set_permissions(std::fs::Permissions::from_mode(mode))?;
        file.sync_all()?;
        std::fs::rename(&temporary, path)?;
        File::open(parent)?.sync_all()?;
        Ok(())
    })();
    if result.is_err() {
        let _ = std::fs::remove_file(&temporary);
    }
    result
}

pub async fn command(program: &Path, arguments: &[&str], input: Option<&str>) -> Result<Vec<u8>> {
    let mut command = Command::new(program);
    command
        .args(arguments)
        .kill_on_drop(true)
        .stdin(if input.is_some() {
            std::process::Stdio::piped()
        } else {
            std::process::Stdio::null()
        })
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped());
    let mut child = command.spawn().context("starting networking command")?;
    if let Some(input) = input {
        child
            .stdin
            .take()
            .context("missing command stdin")?
            .write_all(input.as_bytes())
            .await?;
    }
    let output = tokio::time::timeout(Duration::from_secs(10), child.wait_with_output()).await??;
    ensure!(
        output.status.success(),
        "networking command failed: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    Ok(output.stdout)
}

pub fn rules(config: &Config, db: &Connection) -> Result<String> {
    let mut elements = Vec::new();
    let mut statement = db.prepare(
        "SELECT r.ip, r.ingress, r.upstream FROM routes r JOIN assignments a ON a.ip = r.ip",
    )?;
    for row in statement.query_map([], |row| {
        Ok((
            row.get::<_, String>(0)?,
            row.get::<_, String>(1)?,
            row.get::<_, String>(2)?,
        ))
    })? {
        let (ip, ingress_id, upstream_id) = row?;
        let ip: std::net::Ipv4Addr = ip.parse()?;
        if let Some(ingress) = config.ingresses.get(&ingress_id) {
            if config.kind(ip) != Some(ingress.kind.as_str()) {
                continue;
            }
            // ID 255 is deliberately absent from routing policy and the fixed
            // forwarding allowlist. Removed exits must not become the default.
            let id = config
                .upstreams
                .get(&upstream_id)
                .map_or(255, |upstream| upstream.id);
            elements.push(format!("\"{}\" . {ip} : jump exit_{id}", ingress.interface));
        }
    }
    let mut output = String::from(
        "add table inet router_be\ndelete table inet router_be\ntable inet router_be {\n",
    );
    for id in config
        .upstreams
        .values()
        .map(|upstream| upstream.id)
        .chain(std::iter::once(255))
    {
        output.push_str(&format!(
            "    chain exit_{id} {{ ct mark set (ct mark & {}) | {}; }}\n",
            !UPSTREAM_MASK,
            u32::from(id) << 16
        ));
    }
    let entries = if elements.is_empty() {
        String::new()
    } else {
        format!("elements = {{ {} }}", elements.join(", "))
    };
    output.push_str(&format!(
        r#"    map selections {{
        type ifname . ipv4_addr : verdict
        {entries}
    }}
    chain prerouting {{
        type filter hook prerouting priority mangle; policy accept;
        meta nfproto != ipv4 return
        ct direction reply ct mark & {RETURN_MASK} != 0 meta mark set (meta mark & {}) | (ct mark & {RETURN_MASK})
        ct direction reply return
"#,
        !OWN_MASK
    ));
    let internal = config.internal_networks.join(", ");
    for ingress in config.ingresses.values() {
        let upstream = &config.upstreams[&ingress.default_upstream];
        let base = u32::from(ingress.return_id) << 24;
        let default_mark = base | (u32::from(upstream.id) << 16);
        let prefix = format!(
            "iifname \"{}\" ip saddr {}",
            ingress.interface, ingress.network
        );
        // Internal connections still remember their ingress so replies return to
        // the same Mesh node. Only their Internet-exit bits remain zero.
        output.push_str(&format!(
            "        {prefix} ct mark & {OWN_MASK} == 0 ip daddr {{ {internal} }} ct mark set (ct mark & {}) | {base}\n",
            !OWN_MASK,
        ));
        output.push_str(&format!(
            "        {prefix} ct mark & {OWN_MASK} == 0 iifname . ip saddr vmap @selections\n",
        ));
        output.push_str(&format!(
            "        {prefix} ct mark & {OWN_MASK} == 0 ct mark set (ct mark & {}) | {default_mark}\n",
            !OWN_MASK,
        ));
        output.push_str(&format!(
            "        {prefix} ct mark & {RETURN_MASK} == 0 ct mark set (ct mark & {}) | {base}\n",
            !RETURN_MASK,
        ));
        output.push_str(&format!(
            "        {prefix} meta mark set (meta mark & {}) | (ct mark & {UPSTREAM_MASK})\n",
            !OWN_MASK,
        ));
    }
    output.push_str(&format!(r#"    }}
    chain output {{
        type route hook output priority mangle; policy accept;
        meta nfproto ipv4 ct direction reply ct mark & {RETURN_MASK} != 0 meta mark set (meta mark & {}) | (ct mark & {RETURN_MASK})
    }}
}}
"#, !OWN_MASK));
    Ok(output)
}

pub async fn reconcile(config: &Config, db: &Connection, applied: &mut String) -> Result<()> {
    let desired = rules(config, db)?;
    let exists = command(&config.nft, &["list", "table", "inet", "router_be"], None)
        .await
        .is_ok();
    if *applied != desired || !exists {
        command(&config.nft, &["--check", "--file", "-"], Some(&desired)).await?;
        command(&config.nft, &["--file", "-"], Some(&desired)).await?;
        *applied = desired;
    }
    let mut statement = db.prepare(
        "SELECT a.ip, n.name FROM names n JOIN assignments a ON a.ip = n.ip ORDER BY n.name",
    )?;
    let mut hosts = format!("{} {}\n", config.address, config.hostname);
    for row in statement.query_map([], |row| {
        Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
    })? {
        let (ip, name) = row?;
        ensure!(crate::config::valid_label(&name), "invalid stored DNS name");
        let ip: std::net::Ipv4Addr = ip.parse()?;
        hosts.push_str(&format!("{ip} {name}.{}\n", config.domain));
    }
    let path = config.state_dir.join("dns/hosts");
    if std::fs::read(&path).ok().as_deref() != Some(hosts.as_bytes()) {
        // Stage outside the watched directory: dnsmasq must never read a partial file.
        let stage = config.state_dir.join("dns.next");
        atomic_write(&stage, hosts.as_bytes(), 0o644)?;
        std::fs::rename(stage, path)?;
        File::open(config.state_dir.join("dns"))?.sync_all()?;
    }
    Ok(())
}

pub async fn health(config: &Config) -> BTreeMap<String, Health> {
    let mut result = BTreeMap::new();
    for (id, upstream) in &config.upstreams {
        let link = command(
            &config.ip,
            &["-j", "link", "show", "dev", &upstream.interface],
            None,
        )
        .await
        .ok()
        .and_then(|bytes| serde_json::from_slice::<serde_json::Value>(&bytes).ok());
        let link_ready = link
            .as_ref()
            .and_then(|value| value[0]["flags"].as_array())
            .is_some_and(|flags| {
                flags.iter().any(|flag| flag == "UP") && flags.iter().any(|flag| flag == "LOWER_UP")
            });
        let routes = command(
            &config.ip,
            &[
                "-j",
                "-4",
                "route",
                "show",
                "table",
                &upstream.table.to_string(),
            ],
            None,
        )
        .await
        .ok()
        .and_then(|bytes| serde_json::from_slice::<serde_json::Value>(&bytes).ok());
        let route_ready = routes
            .as_ref()
            .and_then(|value| value.as_array())
            .is_some_and(|routes| {
                routes.iter().any(|route| {
                    route["dst"] == "default"
                        && route["dev"] == upstream.interface
                        && route["gateway"] == upstream.gateway.to_string()
                        && !route["flags"].as_array().is_some_and(|flags| {
                            flags
                                .iter()
                                .any(|flag| flag == "linkdown" || flag == "dead")
                        })
                })
            });
        result.insert(
            id.clone(),
            Health {
                ready: link_ready && route_ready,
                detail: if !link_ready {
                    "Link unavailable; no fallback"
                } else if !route_ready {
                    "Route unavailable; no fallback"
                } else {
                    "Link and route ready"
                },
            },
        );
    }
    result
}
