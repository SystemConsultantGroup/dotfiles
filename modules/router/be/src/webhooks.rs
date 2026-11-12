//! Device-scoped subscriptions and capability reads. Only the controller owns SQLite.
#[cfg(test)]
#[path = "webhooks_tests.rs"]
mod tests;

use crate::{activity, inventory};
use anyhow::{Context, Result, ensure};
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::{io::Read, net::IpAddr, time::Duration};

#[derive(Debug, Default, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Query {
    pub from: Option<i64>,
    pub to: Option<i64>,
    pub limit: Option<u32>,
    pub cursor: Option<String>,
}

#[derive(Deserialize, Serialize)]
#[serde(tag = "action", rename_all = "snake_case", deny_unknown_fields)]
pub enum Operation {
    List,
    Begin {
        url: String,
    },
    Finish {
        id: String,
        accepted: bool,
    },
    Delete {
        id: String,
    },
    Read {
        id: String,
        view: String,
        query: Query,
    },
    Jobs,
    Delivered {
        id: String,
        revision: i64,
        success: bool,
    },
}

impl Operation {
    pub fn device_scoped(&self) -> bool {
        matches!(
            self,
            Self::List | Self::Begin { .. } | Self::Finish { .. } | Self::Delete { .. }
        )
    }
}

type ApiResult = std::result::Result<Value, (u16, &'static str)>;
type ApiReply = std::result::Result<crate::controller::Reply, (u16, &'static str)>;

fn token() -> Result<String> {
    let mut bytes = [0u8; 32];
    std::fs::File::open("/dev/urandom")?.read_exact(&mut bytes)?;
    Ok(bytes.iter().map(|byte| format!("{byte:02x}")).collect())
}

pub fn handle(
    db: &mut Connection,
    device: Option<i64>,
    operation: Operation,
    idle: i64,
    retention: i64,
    collector: &activity::Collector,
) -> ApiReply {
    // Convert database failures here, without logging SQL parameters or capabilities.
    execute(db, device, operation, idle, retention, collector)
        .unwrap_or(Err((500, "Unable to access activity")))
}

fn execute(
    db: &mut Connection,
    device: Option<i64>,
    operation: Operation,
    idle: i64,
    retention: i64,
    collector: &activity::Collector,
) -> Result<ApiReply> {
    let now = inventory::now();
    let device = device.unwrap_or(-1);
    // Abandoned verification attempts expire, including after process restarts.
    db.execute(
        "DELETE FROM activity_webhooks WHERE active = 0 AND created_at < ?1",
        [now - 30],
    )?;
    let mut status = 200;
    let data = match operation {
        Operation::List => {
            let mut q = db.prepare("SELECT id, url, created_at FROM activity_webhooks WHERE device_id = ?1 AND active = 1 ORDER BY created_at, id")?;
            let rows = q.query_map([device], |r| Ok(json!({"id": r.get::<_, String>(0)?, "url": r.get::<_, String>(1)?, "created_at": r.get::<_, i64>(2)? * 1000})))?;
            Value::Array(rows.collect::<rusqlite::Result<_>>()?)
        }
        Operation::Begin { url } => {
            if callback_url(&url).is_err() {
                return Ok(Err((400, "A public HTTPS callback URL is required")));
            }
            let existing: Option<(String, bool)> = db
                .query_row(
                    "SELECT id, active FROM activity_webhooks WHERE device_id = ?1 AND url = ?2",
                    params![device, url],
                    |r| Ok((r.get(0)?, r.get(1)?)),
                )
                .optional()?;
            if let Some((id, active)) = existing {
                if !active {
                    return Ok(Err((409, "Callback verification is already pending")));
                }
                json!({"id": id, "existing": true})
            } else {
                let count: i64 = db.query_row(
                    "SELECT COUNT(*) FROM activity_webhooks WHERE device_id = ?1",
                    [device],
                    |r| r.get(0),
                )?;
                if count >= 16 {
                    return Ok(Err((409, "Webhook limit reached")));
                }
                let id = token()?;
                db.execute("INSERT INTO activity_webhooks(id, device_id, url, created_at) VALUES (?1, ?2, ?3, ?4)", params![id, device, url, now])?;
                json!({"id": id, "existing": false})
            }
        }
        Operation::Finish { id, accepted } => {
            if !accepted {
                db.execute(
                    "DELETE FROM activity_webhooks WHERE id = ?1 AND device_id = ?2 AND active = 0",
                    params![id, device],
                )?;
                return Ok(Err((422, "Callback verification failed")));
            }
            let tx = db.transaction()?;
            let changed = tx.execute("UPDATE activity_webhooks SET active = 1 WHERE id = ?1 AND device_id = ?2 AND active = 0", params![id, device])?;
            if changed == 0 {
                return Ok(Err((404, "Unknown subscription")));
            }
            refresh(&tx, collector.warning.is_some(), now, idle)?;
            tx.commit()?;
            status = 201;
            json!({"id": id})
        }
        Operation::Delete { id } => {
            if db.execute(
                "DELETE FROM activity_webhooks WHERE id = ?1 AND device_id = ?2",
                params![id, device],
            )? == 0
            {
                return Ok(Err((404, "Unknown subscription")));
            }
            status = 204;
            Value::Null
        }
        Operation::Read { id, view, query } => {
            let owner: Option<i64> = db
                .query_row(
                    "SELECT device_id FROM activity_webhooks WHERE id = ?1 AND active = 1",
                    [&id],
                    |r| r.get(0),
                )
                .optional()?;
            let Some(owner) = owner else {
                return Ok(Err((404, "Unknown activity")));
            };
            return read(db, owner, &view, query, idle, retention, collector)
                .map(|result| result.map(|data| crate::controller::Reply { status: 200, data }));
        }
        Operation::Jobs => {
            let mut q = db.prepare("SELECT id, url, revision FROM activity_webhooks WHERE active = 1 AND revision > delivered AND next_attempt <= ?1 AND attempts < 12 ORDER BY next_attempt, created_at LIMIT 16")?;
            let rows = q.query_map([now], |r| Ok(json!({"id": r.get::<_, String>(0)?, "url": r.get::<_, String>(1)?, "revision": r.get::<_, i64>(2)?})))?;
            Value::Array(rows.collect::<rusqlite::Result<_>>()?)
        }
        Operation::Delivered {
            id,
            revision,
            success,
        } => {
            if success {
                db.execute("UPDATE activity_webhooks SET delivered = MAX(delivered, ?2), attempts = 0 WHERE id = ?1 AND revision >= ?2", params![id, revision])?;
            } else {
                // A newly queued revision must not inherit failure state from an old request.
                db.execute("UPDATE activity_webhooks SET attempts = attempts + 1, next_attempt = ?3 + MIN(3600, 5 * (1 << MIN(attempts, 10))) WHERE id = ?1 AND revision = ?2", params![id, revision, now])?;
            }
            json!({})
        }
    };
    Ok(Ok(crate::controller::Reply { status, data }))
}

/// Called inside the session checkpoint transaction. One durable, coalescing
/// notification per subscription bounds storage even when receivers are offline.
pub fn refresh(db: &Connection, unknown: bool, now: i64, idle: i64) -> rusqlite::Result<()> {
    db.execute("UPDATE activity_webhooks SET status = CASE
        WHEN ?1 OR NOT EXISTS (SELECT 1 FROM activity_sessions s WHERE s.device_id = activity_webhooks.device_id) THEN 'unknown'
        WHEN EXISTS (SELECT 1 FROM activity_sessions s WHERE s.device_id = activity_webhooks.device_id AND s.ended_at IS NULL AND s.last_activity + ?3 > ?2) THEN 'online'
        ELSE 'offline' END,
        revision = revision + 1, attempts = 0, next_attempt = 0
        WHERE active = 1 AND status IS NOT (CASE
        WHEN ?1 OR NOT EXISTS (SELECT 1 FROM activity_sessions s WHERE s.device_id = activity_webhooks.device_id) THEN 'unknown'
        WHEN EXISTS (SELECT 1 FROM activity_sessions s WHERE s.device_id = activity_webhooks.device_id AND s.ended_at IS NULL AND s.last_activity + ?3 > ?2) THEN 'online'
        ELSE 'offline' END)", params![unknown, now, idle])?;
    Ok(())
}

fn read(
    db: &Connection,
    owner: i64,
    view: &str,
    query: Query,
    idle: i64,
    retention: i64,
    collector: &activity::Collector,
) -> Result<ApiResult> {
    let now = inventory::now();
    let from = query.from.unwrap_or(0);
    let to = query.to.unwrap_or(now * 1000);
    if from < 0
        || to < 0
        || from >= to
        || to > 253402300799999
        || query.limit.is_some_and(|v| v == 0 || v > 100)
    {
        return Ok(Err((400, "Invalid activity query")));
    }
    let sampled = collector.sampled_at.map(|v| v * 1000);
    match view {
        "" => {
            if query.from.is_some()
                || query.to.is_some()
                || query.limit.is_some()
                || query.cursor.is_some()
            {
                return Ok(Err((400, "Unsupported activity query")));
            }
            let mut value = activity::snapshot(db, owner, idle, now, collector.warning)?;
            for field in ["last_activity", "session_started_at"] {
                if let Some(seconds) = value[field].as_i64() {
                    value[field] = json!(seconds * 1000);
                }
            }
            value["idle_seconds"] = json!(idle);
            value["retention_days"] = json!(retention);
            value["sampled_at"] = json!(sampled);
            Ok(Ok(value))
        }
        "sessions" => {
            let cursor = match query.cursor {
                Some(cursor) => match cursor
                    .split_once(':')
                    .and_then(|(a, b)| Some((a.parse::<i64>().ok()?, b.parse::<i64>().ok()?)))
                {
                    Some((a, b)) if a >= 0 && b > 0 => Some((a, b)),
                    _ => return Ok(Err((400, "Invalid activity cursor"))),
                },
                None => None,
            };
            let limit = query.limit.unwrap_or(50);
            let mut q = db.prepare("SELECT id, started_at, last_activity, ended_at, end_reason FROM activity_sessions WHERE device_id = ?1 AND started_at * 1000 < ?3 AND COALESCE(ended_at, last_activity + ?4) * 1000 > ?2 AND (?5 IS NULL OR (started_at, id) < (?5, ?6)) ORDER BY started_at DESC, id DESC LIMIT ?7")?;
            let rows = q.query_map(params![owner, from, to, idle, cursor.map(|v| v.0), cursor.map(|v| v.1), limit + 1], |r| Ok((r.get::<_, i64>(0)?, r.get::<_, i64>(1)?, json!({"started_at": r.get::<_, i64>(1)? * 1000, "last_activity": r.get::<_, i64>(2)? * 1000, "ended_at": r.get::<_, Option<i64>>(3)?.map(|v| v * 1000), "end_reason": r.get::<_, Option<String>>(4)?}))))?;
            let mut rows = rows.collect::<rusqlite::Result<Vec<_>>>()?;
            let more = rows.len() > limit as usize;
            rows.truncate(limit as usize);
            let next = if more {
                rows.last().map(|(id, start, _)| format!("{start}:{id}"))
            } else {
                None
            };
            Ok(Ok(
                json!({"sessions": rows.into_iter().map(|(_,_,v)| v).collect::<Vec<_>>(), "next_cursor": next, "sampled_at": sampled, "retention_days": retention}),
            ))
        }
        "summary" => {
            if query.from.is_none()
                || query.to.is_none()
                || query.cursor.is_some()
                || query.limit.is_some()
            {
                return Ok(Err((400, "Summary requires from and to only")));
            }
            let cap = collector.sampled_at.unwrap_or(0) * 1000;
            let total: i64 = db.query_row("SELECT COALESCE(SUM(MAX(0, MIN(COALESCE(ended_at * 1000, MIN((last_activity + ?4) * 1000, ?5)), ?3) - MAX(started_at * 1000, ?2))), 0) FROM activity_sessions WHERE device_id = ?1 AND started_at * 1000 < ?3", params![owner, from, to, idle, cap], |r| r.get(0))?;
            Ok(Ok(
                json!({"from": from, "to": to, "total_ms": total, "sampled_at": sampled, "retention_days": retention, "warning": collector.warning}),
            ))
        }
        _ => Ok(Err((404, "Unknown activity endpoint"))),
    }
}

pub fn callback_url(value: &str) -> Result<reqwest::Url> {
    ensure!(value.len() <= 2048, "callback URL too long");
    let url = reqwest::Url::parse(value)?;
    ensure!(
        url.scheme() == "https"
            && url.host_str().is_some()
            && url.username().is_empty()
            && url.password().is_none()
            && url.fragment().is_none(),
        "invalid callback URL"
    );
    Ok(url)
}

/// Conservative public-unicast policy, including IPv4-mapped IPv6 and special
/// purpose ranges. Re-resolve and pin every request; never trust proxy env vars.
pub fn public_ip(ip: IpAddr) -> bool {
    match ip {
        IpAddr::V4(ip) => {
            let [a, b, c, _] = ip.octets();
            !(a == 0
                || a == 10
                || a == 127
                || a >= 224
                || (a == 100 && (64..=127).contains(&b))
                || (a == 169 && b == 254)
                || (a == 172 && (16..=31).contains(&b))
                || (a == 192 && (b == 168 || b == 0 || (b == 88 && c == 99)))
                || (a == 198 && (b == 18 || b == 19 || (b == 51 && c == 100)))
                || (a == 203 && b == 0 && c == 113))
        }
        IpAddr::V6(ip) => {
            let s = ip.segments();
            // Only ordinary global unicast; exclude protocol assignments,
            // documentation, transition mechanisms and deprecated 6to4.
            s[0] & 0xe000 == 0x2000
                && !(s[0] == 0x2001 && (s[1] < 0x200 || s[1] == 0xdb8))
                && s[0] != 0x2002
                && !(s[0] == 0x3fff && s[1] < 0x1000)
        }
    }
}

async fn callback_inner(value: &str, verification: Option<&str>) -> Result<()> {
    let url = callback_url(value)?;
    let host = url.host_str().context("missing callback host")?;
    let host = host.trim_start_matches('[').trim_end_matches(']');
    let port = url
        .port_or_known_default()
        .context("missing callback port")?;
    let addresses: Vec<_> = tokio::net::lookup_host((host, port)).await?.collect();
    ensure!(
        !addresses.is_empty() && addresses.iter().all(|a| public_ip(a.ip())),
        "non-public callback destination"
    );
    let client = reqwest::Client::builder()
        .no_proxy()
        .redirect(reqwest::redirect::Policy::none())
        .timeout(Duration::from_secs(5))
        .resolve_to_addrs(host, &addresses)
        .build()?;
    let mut request = client.post(url);
    if let Some(id) = verification {
        request = request.json(&json!({"type": "verify", "id": id}));
    } else {
        request = request.header(reqwest::header::CONTENT_LENGTH, "0");
    }
    let mut response = request.send().await?;
    if let Some(id) = verification {
        ensure!(
            response.status() == reqwest::StatusCode::OK,
            "verification status"
        );
        let mut body = Vec::new();
        while let Some(chunk) = response.chunk().await? {
            ensure!(
                body.len() + chunk.len() <= 1024,
                "verification response too large"
            );
            body.extend_from_slice(&chunk);
        }
        ensure!(acknowledges(&body, id), "verification acknowledgement");
    } else {
        ensure!(response.status().is_success(), "notification status");
    }
    Ok(())
}

fn acknowledges(body: &[u8], id: &str) -> bool {
    body.len() <= 1024
        && serde_json::from_slice::<Value>(body)
            .ok()
            .and_then(|value| {
                value
                    .get("id")
                    .and_then(Value::as_str)
                    .map(|echo| echo == id)
            })
            .unwrap_or(false)
}

pub async fn callback(value: &str, verification: Option<&str>) -> bool {
    // Includes DNS resolution, connection, TLS, and bounded response consumption.
    matches!(
        tokio::time::timeout(Duration::from_secs(5), callback_inner(value, verification)).await,
        Ok(Ok(()))
    )
}
