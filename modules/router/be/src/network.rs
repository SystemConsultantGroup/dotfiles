use crate::config::{Config, OWN_MASK};
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

// Conntrack labels isolate routing from programs that own the entire ct mark.
// Bit 111 tags our entries; bits 112..127 encode exit and ingress IDs. nft's
// ct_label literals are bit numbers, not integer masks.
fn label_flags(upstream: u8, ingress: u8) -> String {
    let value = u16::from(upstream) | (u16::from(ingress) << 8);
    (0..16)
        .filter(|bit| value & (1 << bit) != 0)
        .map(|bit| (112 + bit).to_string())
        .collect::<Vec<_>>()
        .join(" | ")
}

pub fn rules(config: &Config, db: &Connection) -> Result<String> {
    let mut selections = Vec::new();
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
            let id = config
                .upstreams
                .get(&upstream_id)
                .map_or(255, |upstream| upstream.id);
            selections.push(format!(
                "\"{}\" . {ip} : jump select_{}_{}",
                ingress.interface, ingress.return_id, id
            ));
        }
    }
    let ids: Vec<_> = std::iter::once(0)
        .chain(config.upstreams.values().map(|upstream| upstream.id))
        .chain(std::iter::once(255))
        .collect();
    let mut output = String::from(
        "add table inet router_be\ndelete table inet router_be\ntable inet router_be {\n",
    );
    for id in &ids {
        output.push_str(&format!(
            "    chain exit_{id} {{ meta mark set (meta mark & {}) | {}; }}\n",
            !OWN_MASK,
            u32::from(*id) << 16
        ));
    }
    let mut exits = Vec::new();
    let mut replies = Vec::new();
    for ingress in config.ingresses.values() {
        let return_id = ingress.return_id;
        output.push_str(&format!(
            "    chain reply_{return_id} {{ meta mark set (meta mark & {}) | {}; }}\n",
            !OWN_MASK,
            u32::from(return_id) << 24
        ));
        for id in &ids {
            let flags = label_flags(*id, return_id);
            output.push_str(&format!(
                "    chain select_{return_id}_{id} {{ ct label set ct label | (111 | {flags}); }}\n"
            ));
            exits.push(format!("({flags}) : jump exit_{id}"));
            replies.push(format!("({flags}) : jump reply_{return_id}"));
        }
    }
    let entries = if selections.is_empty() {
        String::new()
    } else {
        format!("elements = {{ {} }};", selections.join(", "))
    };
    output.push_str(&format!(
        "    map selections {{ type ifname . ipv4_addr : verdict; {entries} }}\n"
    ));
    output.push_str(&format!(
        "    map exit_labels {{ type ct_label : verdict; elements = {{ {} }}; }}\n",
        exits.join(", ")
    ));
    output.push_str(&format!(
        "    map reply_labels {{ type ct_label : verdict; elements = {{ {} }}; }}\n",
        replies.join(", ")
    ));
    let mask = (112..128)
        .map(|bit| bit.to_string())
        .collect::<Vec<_>>()
        .join(" | ");
    for (chain, map) in [
        ("restore_exit", "exit_labels"),
        ("restore_reply", "reply_labels"),
    ] {
        // Unknown/removed route labels fail closed instead of falling through
        // to the main table, even for an already established connection.
        output.push_str(&format!("    chain {chain} {{\n        ct label & 111 != 111 return\n        meta mark set (meta mark & {}) | {}\n        ct label & ({mask}) vmap @{map}\n    }}\n", !OWN_MASK, 255_u32 << 16));
    }
    output.push_str("    chain prerouting {\n        type filter hook prerouting priority mangle; policy accept;\n        meta nfproto != ipv4 return\n        ct direction reply jump restore_reply\n        ct direction reply return\n");
    let internal = config.internal_networks.join(", ");
    for ingress in config.ingresses.values() {
        let prefix = format!(
            "iifname \"{}\" ip saddr {}",
            ingress.interface, ingress.network
        );
        let internal_flags = label_flags(0, ingress.return_id);
        let default_flags = label_flags(
            config.upstreams[&ingress.default_upstream].id,
            ingress.return_id,
        );
        output.push_str(&format!("        {prefix} ct label & 111 != 111 ip daddr {{ {internal} }} ct label set ct label | (111 | {internal_flags})\n"));
        output.push_str(&format!(
            "        {prefix} ct label & 111 != 111 iifname . ip saddr vmap @selections\n"
        ));
        output.push_str(&format!("        {prefix} ct label & 111 != 111 ct label set ct label | (111 | {default_flags})\n"));
        output.push_str(&format!("        {prefix} jump restore_exit\n"));
    }
    output.push_str("    }\n    chain output {\n        type route hook output priority mangle; policy accept;\n        meta nfproto ipv4 ct direction reply jump restore_reply\n    }\n}\n");
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
