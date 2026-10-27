use crate::config::{Config, valid_label};
use anyhow::{Context, Result, bail, ensure};
use serde::{Deserialize, Serialize};
use std::{
    collections::{BTreeMap, BTreeSet},
    net::Ipv4Addr,
    path::Path,
    time::{SystemTime, UNIX_EPOCH},
};

#[derive(Clone, Debug)]
pub struct Assignment {
    pub ip: Ipv4Addr,
    pub kind: String,
    pub identifier: String,
    pub generation: String,
    pub reported_name: Option<String>,
    pub expires: Option<i64>,
}

#[derive(Serialize, Deserialize)]
struct Observation {
    mac: String,
    name: String,
    generation: Option<String>,
}

pub fn now() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
        .try_into()
        .unwrap_or(i64::MAX)
}

pub fn office(config: &Config) -> Result<Vec<Assignment>> {
    // dnsmasq rewrites its lease file in place. Reject an in-flight snapshot
    // rather than interpreting a transient truncation as assignment removal.
    let before = std::fs::metadata(&config.lease_file)?;
    ensure!(
        before.modified()?.elapsed().unwrap_or_default() >= std::time::Duration::from_millis(100),
        "DHCP lease file is being updated"
    );
    let leases = std::fs::read_to_string(&config.lease_file).context("reading DHCP assignments")?;
    let after = std::fs::metadata(&config.lease_file)?;
    ensure!(
        before.modified()? == after.modified()?
            && before.len() == after.len()
            && (leases.is_empty() || leases.ends_with('\n')),
        "DHCP lease file changed during read"
    );
    let mut result = Vec::new();
    let mut seen = BTreeSet::new();
    for line in leases.lines().filter(|line| !line.trim().is_empty()) {
        let fields: Vec<_> = line.split_whitespace().collect();
        // IPv6 server identifiers and leases are not part of this IPv4 inventory.
        if fields[0] == "duid" {
            continue;
        }
        ensure!(fields.len() == 5, "invalid DHCP lease snapshot");
        if fields[2].contains(':') {
            continue;
        }
        let expires: i64 = fields[0].parse().context("invalid DHCP expiry")?;
        ensure!(expires >= 0, "invalid DHCP expiry");
        let ip: Ipv4Addr = fields[2].parse().context("invalid DHCP IPv4 address")?;
        ensure!(
            config.kind(ip) == Some("office") && seen.insert(ip),
            "unexpected DHCP address"
        );
        if expires != 0 && expires <= now() {
            continue;
        }
        let observation = std::fs::read(config.state_dir.join("leases").join(format!("{ip}.json")))
            .ok()
            .and_then(|bytes| serde_json::from_slice::<Observation>(&bytes).ok())
            .filter(|value| value.mac.eq_ignore_ascii_case(fields[1]));
        let generation = format!(
            "{}:{}:{}",
            fields[1].to_ascii_lowercase(),
            fields[4],
            observation
                .as_ref()
                .and_then(|value| value.generation.as_deref())
                .unwrap_or_default()
        );
        let name = observation
            .map(|value| value.name)
            .unwrap_or_else(|| fields[3].to_owned());
        result.push(Assignment {
            ip,
            kind: "office".into(),
            identifier: crate::device::mac(fields[1]).context("invalid DHCP MAC")?,
            generation,
            reported_name: reported_name(&name, &config.domain),
            expires: (expires != 0).then_some(expires),
        });
    }
    Ok(result)
}

pub fn observe(
    directory: &Path,
    action: &str,
    mac: &str,
    ip: Ipv4Addr,
    fallback: &str,
) -> Result<()> {
    ensure!(
        mac.split(':').count() == 6
            && mac
                .split(':')
                .all(|p| p.len() == 2 && p.bytes().all(|b| b.is_ascii_hexdigit())),
        "invalid MAC"
    );
    let path = directory.join(format!("{ip}.json"));
    let bytes = std::fs::read(&path).ok();
    let previous = bytes
        .as_ref()
        .and_then(|bytes| serde_json::from_slice::<Observation>(bytes).ok())
        .filter(|previous| previous.mac.eq_ignore_ascii_case(mac));
    match action {
        "add" | "old" => {
            let supplied =
                std::env::var("DNSMASQ_SUPPLIED_HOSTNAME").unwrap_or_else(|_| fallback.to_owned());
            let name = if supplied.is_empty() || supplied == "*" {
                previous
                    .as_ref()
                    .map(|value| value.name.as_str())
                    .unwrap_or(&supplied)
            } else {
                &supplied
            };
            // 'add' is a new assignment; 'old' is a renewal or startup replay.
            // Preserve this lifecycle marker across controller outages so even a
            // rapid release/reacquire by the same MAC clears saved preferences.
            let generation = if action == "old" {
                previous.as_ref().and_then(|value| value.generation.clone())
            } else {
                None
            }
            .unwrap_or_else(|| {
                format!(
                    "{}-{}",
                    std::process::id(),
                    SystemTime::now()
                        .duration_since(UNIX_EPOCH)
                        .unwrap_or_default()
                        .as_nanos()
                )
            });
            let observation = Observation {
                mac: mac.to_ascii_lowercase(),
                name: name.chars().take(253).collect(),
                generation: Some(generation),
            };
            let next = serde_json::to_vec(&observation)?;
            if bytes.as_deref() != Some(next.as_slice()) {
                crate::network::atomic_write(&path, &next, 0o644)?;
            }
        }
        "del" if previous.is_some() => {
            std::fs::remove_file(path)?;
        }
        _ => {}
    }
    Ok(())
}

// Run only from dnsmasq's ExecStartPre, while its lease file is not open.
// Ignoring newly supplied names does not stop dnsmasq exporting old names
// loaded from disk. Preserve those observations before clearing only that
// column; addresses, client IDs, and expiry times must remain unchanged.
pub fn prepare_leases(lease_file: &Path, directory: &Path) -> Result<()> {
    let original = match std::fs::read_to_string(lease_file) {
        Ok(value) => value,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(()),
        Err(error) => return Err(error.into()),
    };
    let mut lines = Vec::new();
    let mut changed = false;
    for line in original.lines() {
        let mut fields: Vec<_> = line.split_whitespace().collect();
        if fields.len() == 5
            && let Ok(ip) = fields[2].parse::<Ipv4Addr>()
        {
            observe(directory, "old", fields[1], ip, fields[3])?;
            if fields[3] != "*" {
                fields[3] = "*";
                lines.push(fields.join(" "));
                changed = true;
                continue;
            }
        }
        lines.push(line.to_owned());
    }
    if changed {
        crate::network::atomic_write(
            lease_file,
            format!("{}\n", lines.join("\n")).as_bytes(),
            0o644,
        )?;
    }
    Ok(())
}

fn reported_name(value: &str, domain: &str) -> Option<String> {
    let value = value.trim_end_matches('.').to_ascii_lowercase();
    let value = value.strip_suffix(&format!(".{domain}")).unwrap_or(&value);
    valid_label(value).then(|| value.to_owned())
}

#[derive(Deserialize)]
struct Page {
    success: bool,
    result: Vec<Registration>,
    result_info: Option<PageInfo>,
}
#[derive(Deserialize)]
struct PageInfo {
    cursor: Option<String>,
}
#[derive(Deserialize)]
struct Registration {
    id: String,
    virtual_ipv4: Option<Ipv4Addr>,
    revoked_at: Option<String>,
    deleted_at: Option<String>,
    device: Device,
}
#[derive(Deserialize)]
struct Device {
    name: String,
}

pub struct Cloudflare {
    client: reqwest::Client,
    account: String,
    token: String,
}

impl Cloudflare {
    pub fn from_env() -> Result<Option<Self>> {
        match (
            std::env::var("CLOUDFLARE_ACCOUNT_ID"),
            std::env::var("CLOUDFLARE_API_TOKEN"),
        ) {
            (Ok(account), Ok(token)) if !account.is_empty() && !token.is_empty() => {
                ensure!(
                    account.bytes().all(|b| b.is_ascii_hexdigit()) && account.len() == 32,
                    "invalid Cloudflare account ID"
                );
                Ok(Some(Self {
                    client: reqwest::Client::builder()
                        .timeout(std::time::Duration::from_secs(15))
                        .redirect(reqwest::redirect::Policy::none())
                        .build()?,
                    account,
                    token,
                }))
            }
            _ => Ok(None),
        }
    }

    pub async fn snapshot(&self, config: &Config) -> Result<Vec<Assignment>> {
        let mut cursor = String::new();
        let mut cursors = BTreeSet::new();
        let mut addresses = BTreeMap::new();
        for _ in 0..100 {
            let mut request = self
                .client
                .get(format!(
                    "https://api.cloudflare.com/client/v4/accounts/{}/devices/registrations",
                    self.account
                ))
                .bearer_auth(&self.token)
                .query(&[("status", "active"), ("per_page", "100")]);
            if !cursor.is_empty() {
                request = request.query(&[("cursor", &cursor)]);
            }
            // Do not attach request Debug output, response bodies, or credentials to errors.
            let response = request
                .send()
                .await
                .map_err(|_| anyhow::anyhow!("Cloudflare inventory request failed"))?;
            ensure!(
                response.status().is_success(),
                "Cloudflare inventory returned HTTP {}",
                response.status()
            );
            let page: Page = response
                .json()
                .await
                .map_err(|_| anyhow::anyhow!("invalid Cloudflare inventory response"))?;
            ensure!(page.success, "Cloudflare inventory was not successful");
            for registration in page.result {
                if registration.revoked_at.is_some() || registration.deleted_at.is_some() {
                    continue;
                }
                if let Some(ip) = registration.virtual_ipv4 {
                    if config.kind(ip) != Some("mesh") {
                        continue;
                    }
                    ensure!(
                        !registration.id.is_empty() && !addresses.contains_key(&ip),
                        "ambiguous Mesh assignment"
                    );
                    addresses.insert(
                        ip,
                        Assignment {
                            ip,
                            kind: "mesh".into(),
                            identifier: ip.to_string(),
                            generation: registration.id,
                            reported_name: reported_name(&registration.device.name, &config.domain),
                            expires: None,
                        },
                    );
                }
            }
            cursor = page
                .result_info
                .and_then(|info| info.cursor)
                .unwrap_or_default();
            if cursor.is_empty() {
                return Ok(addresses.into_values().collect());
            }
            ensure!(cursors.insert(cursor.clone()), "Cloudflare pagination loop");
        }
        bail!("Cloudflare inventory exceeded page limit")
    }
}
