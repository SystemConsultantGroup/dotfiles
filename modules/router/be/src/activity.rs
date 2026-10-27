use crate::{config::Config, device, inventory, network};
use anyhow::{Context, Result, ensure};
use rusqlite::{Connection, OptionalExtension, params};
use serde_json::{Value, json};
use std::collections::BTreeMap;

pub const POLL_SECONDS: u64 = 15;

pub struct Collector {
    applied: String,
    since: i64,
    previous_poll: i64,
    cleanup_at: i64,
    pub warning: Option<&'static str>,
}

impl Collector {
    pub fn new(db: &Connection) -> Result<Self> {
        close_gap(db)?;
        Ok(Self {
            applied: String::new(),
            since: inventory::now(),
            previous_poll: inventory::now(),
            cleanup_at: 0,
            warning: Some("Activity monitoring is starting"),
        })
    }

    pub async fn poll(&mut self, config: &Config, db: &mut Connection) {
        if let Err(error) = self.collect(config, db).await {
            tracing::warn!(%error, "office activity monitoring unavailable");
            self.warning =
                Some("Activity monitoring unavailable; no online time is assumed during gaps");
            self.since = inventory::now();
            // A missing snapshot is not evidence of inactivity. Close the known
            // interval at its last evidence rather than counting the outage.
            if let Err(error) = close_gap(db) {
                tracing::error!(%error, "unable to checkpoint activity monitoring gap");
            }
        }
    }

    async fn collect(&mut self, config: &Config, db: &mut Connection) -> Result<()> {
        let desired = rules(config);
        let snapshot = network::command(
            &config.nft,
            &["-j", "list", "set", "inet", "router_activity", "office"],
            None,
        )
        .await;
        if self.applied != desired || snapshot.is_err() {
            close_gap(db)?;
            network::command(&config.nft, &["--check", "--file", "-"], Some(&desired)).await?;
            network::command(&config.nft, &["--file", "-"], Some(&desired)).await?;
            self.applied = desired;
            self.since = inventory::now();
            self.previous_poll = self.since;
            self.warning = Some("Activity monitoring is starting; earlier activity is unknown");
            return Ok(());
        }
        let now = inventory::now();
        if now < self.previous_poll || now - self.previous_poll > (POLL_SECONDS * 3) as i64 {
            close_gap(db)?;
            self.since = now;
        }
        self.previous_poll = now;
        let observations = parse(&snapshot?, i64::from(config.activity.idle_seconds), now)?;
        let tx = db.transaction()?;
        checkpoint(
            &tx,
            &observations,
            self.since,
            now,
            i64::from(config.activity.idle_seconds),
        )?;
        if now >= self.cleanup_at {
            tx.execute(
                "DELETE FROM activity_sessions WHERE ended_at IS NOT NULL AND ended_at < ?1",
                [now - i64::from(config.activity.retention_days) * 86400],
            )?;
        }
        tx.commit()?;
        if now >= self.cleanup_at {
            self.cleanup_at = now + 3600;
        }
        self.warning = None;
        Ok(())
    }
}

fn close_gap(db: &Connection) -> Result<()> {
    db.execute("UPDATE activity_sessions SET ended_at = last_activity, end_reason = 'monitoring_gap' WHERE ended_at IS NULL", [])?;
    Ok(())
}

// This table is independent of router_be: policy changes must never reset
// activity timeouts. These rules observe only, and have no packet verdict.
pub fn rules(config: &Config) -> String {
    let idle = config.activity.idle_seconds;
    let mut rules = format!(
        "add table inet router_activity\ndelete table inet router_activity\ntable inet router_activity {{\n    set office {{ type ether_addr; flags dynamic,timeout; timeout {idle}s; gc-interval 30s; size 65536; }}\n    chain observe {{\n        type filter hook prerouting priority -151; policy accept;\n"
    );
    for ingress in config
        .ingresses
        .values()
        .filter(|ingress| ingress.kind == "office")
    {
        rules.push_str(&format!("        iifname \"{}\" ip saddr {} ip saddr != {} update @office {{ ether saddr timeout {idle}s }}\n",
            ingress.interface, ingress.network, config.address));
    }
    rules.push_str("    }\n}\n");
    rules
}

pub fn parse(bytes: &[u8], idle: i64, now: i64) -> Result<BTreeMap<String, i64>> {
    let value: Value = serde_json::from_slice(bytes)?;
    let objects = value["nftables"]
        .as_array()
        .context("invalid nftables activity response")?;
    let set = objects
        .iter()
        .filter_map(|object| object.get("set"))
        .find(|set| {
            set["family"] == "inet" && set["table"] == "router_activity" && set["name"] == "office"
        })
        .context("missing office activity set")?;
    ensure!(
        set["type"] == "ether_addr" && set["timeout"].as_i64() == Some(idle),
        "unexpected activity set configuration"
    );
    let mut result = BTreeMap::new();
    if let Some(elements) = set.get("elem") {
        for entry in elements.as_array().context("invalid activity elements")? {
            let entry = &entry["elem"];
            let mac = entry["val"]
                .as_str()
                .and_then(device::mac)
                .context("invalid activity MAC")?;
            // libnftables JSON timeout/expiry values are seconds (not the
            // millisecond units used by the netlink attributes underneath).
            let expires = entry["expires"]
                .as_i64()
                .context("missing activity expiry")?;
            ensure!((0..=idle).contains(&expires), "invalid activity expiry");
            result.insert(mac, now - idle + expires);
        }
    }
    Ok(result)
}

pub fn checkpoint(
    db: &Connection,
    observations: &BTreeMap<String, i64>,
    since: i64,
    now: i64,
    idle: i64,
) -> Result<()> {
    // Expire against the previous observation before processing new traffic:
    // a device returning after the timeout starts a distinct session.
    for (mac, seen) in observations {
        if *seen < since {
            continue;
        }
        let id = device::ensure_device(db, "office", mac)?;
        let previous: Option<(i64, i64)> = db.query_row(
            "SELECT id, last_activity FROM activity_sessions WHERE device_id = ?1 AND ended_at IS NULL",
            [id], |row| Ok((row.get(0)?, row.get(1)?))).optional()?;
        if let Some((session, last)) = previous {
            if *seen <= last + idle {
                db.execute("UPDATE activity_sessions SET last_activity = MAX(last_activity, ?1) WHERE id = ?2", params![seen, session])?;
                continue;
            }
            db.execute("UPDATE activity_sessions SET ended_at = last_activity + ?1, end_reason = 'inactivity' WHERE id = ?2", params![idle, session])?;
        }
        db.execute("INSERT INTO activity_sessions(device_id, started_at, last_activity) VALUES (?1, ?2, ?2)", params![id, seen])?;
    }
    db.execute("UPDATE activity_sessions SET ended_at = last_activity + ?1, end_reason = 'inactivity' WHERE ended_at IS NULL AND last_activity + ?1 <= ?2", params![idle, now])?;
    Ok(())
}

pub fn view(db: &Connection, id: i64, config: &Config, warning: Option<&str>) -> Result<Value> {
    let now = inventory::now();
    let idle = i64::from(config.activity.idle_seconds);
    let last: Option<i64> = db.query_row(
        "SELECT MAX(last_activity) FROM activity_sessions WHERE device_id = ?1",
        [id],
        |row| row.get(0),
    )?;
    let current: Option<i64> = db.query_row("SELECT started_at FROM activity_sessions WHERE device_id = ?1 AND ended_at IS NULL AND last_activity + ?2 > ?3", params![id, idle, now], |row| row.get(0)).optional()?;
    let mut query = db.prepare("SELECT started_at, last_activity, ended_at, end_reason FROM activity_sessions WHERE device_id = ?1 ORDER BY started_at DESC, id DESC LIMIT 50")?;
    let sessions = query.query_map([id], |row| {
        Ok(json!({"started_at": row.get::<_, i64>(0)?, "last_activity": row.get::<_, i64>(1)?, "ended_at": row.get::<_, Option<i64>>(2)?, "end_reason": row.get::<_, Option<String>>(3)?}))
    })?.collect::<rusqlite::Result<Vec<_>>>()?;
    let mut totals = BTreeMap::new();
    for (label, seconds) in [("day", 86400), ("week", 7 * 86400)] {
        let total: i64 = db.query_row("SELECT COALESCE(SUM(MAX(0, MIN(COALESCE(ended_at, last_activity + ?2), ?3) - MAX(started_at, ?4))), 0) FROM activity_sessions WHERE device_id = ?1 AND started_at < ?3 AND COALESCE(ended_at, last_activity + ?2) > ?4",
            params![id, idle, now, now - seconds], |row| row.get(0))?;
        totals.insert(label, total);
    }
    Ok(json!({
        "status": if warning.is_some() || last.is_none() { "unknown" } else if current.is_some() { "online" } else { "offline" },
        "warning": warning, "last_activity": last, "session_started_at": current,
        "idle_seconds": idle, "retention_days": config.activity.retention_days,
        "totals": totals, "sessions": sessions, "sampled_at": now,
    }))
}
