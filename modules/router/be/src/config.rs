use anyhow::{Context, Result, ensure};
use ipnet::Ipv4Net;
use serde::{Deserialize, Serialize};
use std::{
    collections::BTreeMap,
    net::Ipv4Addr,
    path::{Path, PathBuf},
};

pub const UPSTREAM_MASK: u32 = 0x00ff_0000;
pub const RETURN_MASK: u32 = 0xff00_0000;
pub const OWN_MASK: u32 = UPSTREAM_MASK | RETURN_MASK;

#[derive(Clone, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Config {
    pub hostname: String,
    pub address: Ipv4Addr,
    pub domain: String,
    pub state_dir: PathBuf,
    pub socket: PathBuf,
    pub lease_file: PathBuf,
    pub ip: PathBuf,
    pub nft: PathBuf,
    pub activity: Activity,
    pub reserved_names: Vec<String>,
    pub internal_networks: Vec<String>,
    pub ingresses: BTreeMap<String, Ingress>,
    pub upstreams: BTreeMap<String, Upstream>,
}

#[derive(Clone, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Activity {
    pub idle_seconds: u32,
    pub retention_days: u32,
}

#[derive(Clone, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
#[serde(rename_all = "camelCase")]
pub struct Ingress {
    pub label: String,
    pub interface: String,
    pub network: String,
    pub kind: String,
    pub default_upstream: String,
    pub return_id: u8,
    pub return_table: u32,
    pub gateway: Option<Ipv4Addr>,
}

#[derive(Clone, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Upstream {
    pub label: String,
    pub interface: String,
    pub gateway: Ipv4Addr,
    pub table: u32,
    pub id: u8,
}

impl Config {
    pub fn load(path: &Path) -> Result<Self> {
        let config: Self = serde_json::from_slice(&std::fs::read(path)?)?;
        ensure!(
            valid_domain(&config.hostname) && valid_domain(&config.domain),
            "invalid DNS configuration"
        );
        ensure!(
            (60..=86400).contains(&config.activity.idle_seconds)
                && (1..=3650).contains(&config.activity.retention_days),
            "invalid activity retention or timeout"
        );
        ensure!(
            !config.ingresses.is_empty() && !config.upstreams.is_empty(),
            "empty routing catalog"
        );
        let mut ids = std::collections::BTreeSet::new();
        for upstream in config.upstreams.values() {
            ensure!(
                upstream.id != 0 && upstream.id != 255 && ids.insert(upstream.id),
                "duplicate or zero upstream ID"
            );
            ensure!(
                valid_interface(&upstream.interface),
                "invalid upstream interface"
            );
        }
        ids.clear();
        for ingress in config.ingresses.values() {
            ensure!(
                ingress.return_id != 0 && ids.insert(ingress.return_id),
                "duplicate or zero return ID"
            );
            ensure!(
                valid_interface(&ingress.interface),
                "invalid ingress interface"
            );
            ingress
                .network
                .parse::<Ipv4Net>()
                .context("invalid ingress network")?;
            ensure!(
                matches!(ingress.kind.as_str(), "office" | "mesh"),
                "invalid ingress kind"
            );
            ensure!(
                config.upstreams.contains_key(&ingress.default_upstream),
                "unknown default upstream"
            );
        }
        for network in &config.internal_networks {
            network.parse::<Ipv4Net>()?;
        }
        Ok(config)
    }

    pub fn kind(&self, ip: Ipv4Addr) -> Option<&str> {
        self.ingresses
            .values()
            .find(|ingress| {
                ingress
                    .network
                    .parse::<Ipv4Net>()
                    .is_ok_and(|net| net.contains(&ip))
            })
            .map(|ingress| ingress.kind.as_str())
    }
}

pub fn valid_label(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 63
        && value
            .bytes()
            .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-')
        && !value.starts_with('-')
        && !value.ends_with('-')
}

fn valid_domain(value: &str) -> bool {
    value.len() <= 253 && value.split('.').all(valid_label)
}

fn valid_interface(value: &str) -> bool {
    !value.is_empty()
        && value.len() < 16
        && value
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b"_-.:".contains(&b))
}
