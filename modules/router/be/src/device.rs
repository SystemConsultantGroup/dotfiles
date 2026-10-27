use anyhow::{Result, ensure};
use rusqlite::{Connection, Transaction, params};
use std::net::Ipv4Addr;

pub fn mac(value: &str) -> Option<String> {
    let octets = value
        .split(':')
        .map(|part| {
            (part.len() == 2 && part.bytes().all(|byte| byte.is_ascii_hexdigit()))
                .then(|| u8::from_str_radix(part, 16).ok())
                .flatten()
        })
        .collect::<Option<Vec<_>>>()?;
    (octets.len() == 6 && octets[0] & 1 == 0 && octets.iter().any(|octet| *octet != 0))
        .then(|| value.to_ascii_lowercase())
}

pub fn ensure_device(db: &Connection, kind: &str, identifier: &str) -> Result<i64> {
    ensure!(
        match kind {
            "office" => mac(identifier).as_deref() == Some(identifier),
            "mesh" => identifier.parse::<Ipv4Addr>().is_ok(),
            _ => false,
        },
        "invalid device identity"
    );
    db.execute(
        "INSERT INTO devices(kind, identifier) VALUES (?1, ?2) ON CONFLICT DO NOTHING",
        params![kind, identifier],
    )?;
    Ok(db.query_row(
        "SELECT id FROM devices WHERE kind = ?1 AND identifier = ?2",
        params![kind, identifier],
        |row| row.get(0),
    )?)
}

// The old IP-scoped schema is migrated once. Only legacy office assignments
// carrying a MAC in their DHCP generation can safely retain device preferences.
// Unresolved IP-only preferences must not pass to an unrelated future occupant.
pub fn migrate(db: &mut Connection) -> Result<()> {
    db.execute_batch("PRAGMA foreign_keys = ON;")?;
    let version: i64 = db.query_row("PRAGMA user_version", [], |row| row.get(0))?;
    ensure!(version <= 2, "database schema is newer than this be");
    if version == 2 {
        return Ok(());
    }
    let tx = db.transaction()?;
    if version == 0 {
        tx.execute_batch(include_str!("../migrations/001.sql"))?;
    }
    tx.execute_batch(include_str!("../migrations/002.sql"))?;
    let assignments = {
        let mut query = tx.prepare("SELECT ip, kind, generation FROM assignments ORDER BY ip")?;
        query
            .query_map([], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                ))
            })?
            .collect::<rusqlite::Result<Vec<_>>>()?
    };
    for (ip, kind, generation) in assignments {
        let identifier = if kind == "mesh" {
            Some(ip.clone())
        } else {
            generation.get(..17).and_then(mac)
        };
        let Some(identifier) = identifier else {
            continue;
        };
        let id = ensure_device(&tx, &kind, &identifier)?;
        tx.execute(
            "UPDATE assignments SET device_id = ?1 WHERE ip = ?2",
            params![id, ip],
        )?;
        tx.execute("INSERT OR IGNORE INTO names(device_id, name, custom) SELECT ?1, name, custom FROM legacy_names WHERE ip = ?2", params![id, ip])?;
        tx.execute("INSERT OR IGNORE INTO routes(device_id, ingress, upstream) SELECT ?1, ingress, upstream FROM legacy_routes WHERE ip = ?2", params![id, ip])?;
    }
    tx.execute_batch(
        "DROP TABLE legacy_routes; DROP TABLE legacy_names; PRAGMA user_version = 2;",
    )?;
    tx.commit()?;
    Ok(())
}

pub fn bind(tx: &Transaction<'_>, assignment: &crate::inventory::Assignment) -> Result<i64> {
    let crate::inventory::Assignment {
        ip,
        kind,
        identifier,
        generation,
        reported_name,
        expires,
    } = assignment;
    let id = ensure_device(tx, kind, identifier)?;
    // Office inventory models one current IPv4 binding per MAC. Retire an old
    // static/lease address before applying preferences to the new address.
    if kind == "office" {
        tx.execute(
            "DELETE FROM assignments WHERE device_id = ?1 AND ip != ?2",
            params![id, ip.to_string()],
        )?;
    }
    // Reusing an IP replaces only its binding, never the previous device's settings.
    tx.execute("INSERT INTO assignments(ip, kind, generation, reported_name, expires, device_id) VALUES (?1, ?2, ?3, ?4, ?5, ?6)
        ON CONFLICT(ip) DO UPDATE SET kind = excluded.kind, generation = excluded.generation, reported_name = excluded.reported_name, expires = excluded.expires, device_id = excluded.device_id",
        params![ip.to_string(), kind, generation, reported_name, expires, id])?;
    Ok(id)
}
