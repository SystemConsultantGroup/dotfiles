use crate::{
    config::{Config, valid_label},
    inventory::{self, Assignment, Cloudflare},
    network,
};
use anyhow::{Context, Result, ensure};
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::{collections::BTreeMap, net::Ipv4Addr, os::unix::fs::PermissionsExt, time::Duration};
use tokio::{
    io::{AsyncBufReadExt, AsyncWriteExt, BufReader},
    net::UnixListener,
};

#[derive(Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Request {
    pub ip: Ipv4Addr,
    pub operation: Operation,
}

#[derive(Deserialize, Serialize)]
#[serde(tag = "type", rename_all = "snake_case", deny_unknown_fields)]
pub enum Operation {
    View,
    Dns { name: Option<String> },
    Route { ingress: String, upstream: String },
}

#[derive(Deserialize, Serialize)]
pub struct Reply {
    pub status: u16,
    pub data: Value,
}

struct ApiError(u16, &'static str);
impl From<rusqlite::Error> for ApiError {
    fn from(error: rusqlite::Error) -> Self {
        tracing::error!(%error, "database operation failed");
        Self(500, "Unable to update device settings")
    }
}

type ApiResult<T> = std::result::Result<T, ApiError>;

struct Controller {
    config: Config,
    db: Connection,
    inventory_error: BTreeMap<String, String>,
    health: BTreeMap<String, network::Health>,
    applied: String,
    apply_error: bool,
}

impl Controller {
    fn assignments(&mut self, kind: &str, assignments: Vec<Assignment>) -> Result<()> {
        let tx = self.db.transaction()?;
        let existing: Vec<(String, String)> = {
            let mut query = tx.prepare("SELECT ip, generation FROM assignments WHERE kind = ?1")?;
            query
                .query_map([kind], |row| Ok((row.get(0)?, row.get(1)?)))?
                .collect::<std::result::Result<_, _>>()?
        };
        let active: BTreeMap<_, _> = assignments
            .iter()
            .map(|value| (value.ip.to_string(), value.generation.as_str()))
            .collect();
        for (ip, generation) in existing {
            // Merely observing a source IP is sufficient for self-service.
            // Inventory is used for lifecycle cleanup, never authentication.
            // An address with no known lease/registration is retained until an
            // authoritative assignment is learned; absence alone cannot prove
            // that an otherwise untracked static address was relinquished.
            if !generation.starts_with("observed:")
                && active.get(&ip).copied() != Some(generation.as_str())
            {
                tx.execute("DELETE FROM assignments WHERE ip = ?1", [&ip])?;
            }
        }
        for assignment in assignments {
            ensure!(assignment.kind == kind, "inventory kind mismatch");
            tx.execute("INSERT INTO assignments (ip, kind, generation, reported_name, expires) VALUES (?1, ?2, ?3, ?4, ?5)
                ON CONFLICT(ip) DO UPDATE SET generation = excluded.generation, reported_name = excluded.reported_name, expires = excluded.expires",
                params![assignment.ip.to_string(), kind, assignment.generation, assignment.reported_name, assignment.expires])?;
        }
        tx.commit()?;
        self.allocate_names()?;
        self.inventory_error.remove(kind);
        Ok(())
    }

    fn allocate_names(&mut self) -> Result<()> {
        let assignments: Vec<(String, Option<String>)> = {
            let mut query = self
                .db
                .prepare("SELECT ip, reported_name FROM assignments ORDER BY ip")?;
            query
                .query_map([], |row| Ok((row.get(0)?, row.get(1)?)))?
                .collect::<std::result::Result<_, _>>()?
        };
        for (ip, reported) in assignments {
            let existing: Option<(String, bool)> = self
                .db
                .query_row(
                    "SELECT name, custom FROM names WHERE ip = ?1",
                    [&ip],
                    |row| Ok((row.get(0)?, row.get(1)?)),
                )
                .optional()?;
            if existing.as_ref().is_some_and(|(_, custom)| *custom) {
                continue;
            }
            let base = reported.unwrap_or_else(|| format!("device-{}", ip.replace('.', "-")));
            let mut candidate = base.clone();
            let mut ordinal = 0;
            while self.reserved(&candidate) || !self.available(&candidate, &ip)? {
                let suffix = if ordinal == 0 {
                    format!("-{}", ip.replace('.', "-"))
                } else {
                    format!("-{}-{ordinal}", ip.replace('.', "-"))
                };
                candidate = format!("{}{}", &base[..base.len().min(63 - suffix.len())], suffix);
                ordinal += 1;
            }
            ensure!(valid_label(&candidate), "cannot allocate DNS name");
            if existing
                .as_ref()
                .is_some_and(|(name, _)| name == &candidate)
            {
                continue;
            }
            self.db.execute("INSERT INTO names (ip, name, custom) VALUES (?1, ?2, 0) ON CONFLICT(ip) DO UPDATE SET name = excluded.name", params![ip, candidate])?;
        }
        Ok(())
    }

    fn reserved(&self, name: &str) -> bool {
        self.config
            .reserved_names
            .iter()
            .any(|reserved| name == reserved)
            || self.config.hostname.split('.').next() == Some(name)
    }

    fn available(&self, name: &str, ip: &str) -> rusqlite::Result<bool> {
        self.db.query_row(
            "SELECT NOT EXISTS(SELECT 1 FROM names WHERE name = ?1 AND ip != ?2)",
            params![name, ip],
            |row| row.get(0),
        )
    }

    fn office(&mut self) {
        match inventory::office(&self.config)
            .and_then(|assignments| self.assignments("office", assignments))
        {
            Ok(()) => {}
            Err(error) => {
                tracing::warn!(%error, "DHCP inventory unavailable; retaining previous assignments");
                self.inventory_error
                    .insert("office".into(), "DHCP inventory unavailable".into());
            }
        }
    }

    fn mesh(&mut self, snapshot: Result<Vec<Assignment>>) {
        match snapshot.and_then(|assignments| self.assignments("mesh", assignments)) {
            Ok(()) => {}
            Err(error) => {
                tracing::warn!(%error, "Mesh inventory unavailable; retaining previous assignments");
                self.inventory_error
                    .insert("mesh".into(), "Mesh inventory unavailable".into());
            }
        }
    }

    async fn apply(&mut self) {
        match network::reconcile(&self.config, &self.db, &mut self.applied).await {
            Ok(()) => self.apply_error = false,
            Err(error) => {
                tracing::error!(%error, "unable to reconcile device policy; retaining last applied rules");
                self.apply_error = true;
            }
        }
        self.health = network::health(&self.config).await;
    }

    fn editable(&self, ip: Ipv4Addr) -> ApiResult<()> {
        if self.config.kind(ip).is_none() || ip == self.config.address {
            return Err(ApiError(403, "This source address cannot use self-service"));
        }
        Ok(())
    }

    fn observe_source(&mut self, ip: Ipv4Addr) -> ApiResult<()> {
        self.editable(ip)?;
        let kind = self.config.kind(ip).expect("authorized source kind");
        self.db.execute("INSERT INTO assignments(ip, kind, generation) VALUES (?1, ?2, ?3) ON CONFLICT(ip) DO NOTHING",
            params![ip.to_string(), kind, format!("observed:{ip}")])?;
        self.allocate_names()
            .map_err(|_| ApiError(500, "Unable to allocate the automatic name"))?;
        Ok(())
    }

    fn view(&self, ip: Ipv4Addr) -> ApiResult<Value> {
        let kind = self
            .config
            .kind(ip)
            .ok_or(ApiError(403, "This source address cannot use self-service"))?;
        let assignment: Option<(Option<String>, Option<i64>)> = self
            .db
            .query_row(
                "SELECT reported_name, expires FROM assignments WHERE ip = ?1",
                [ip.to_string()],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .optional()?;
        let name: Option<(String, bool)> = self
            .db
            .query_row(
                "SELECT name, custom FROM names WHERE ip = ?1",
                [ip.to_string()],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .optional()?;
        let routes = self.config.ingresses.iter().filter(|(_, ingress)| ingress.kind == kind).map(|(id, ingress)| {
            let selected: Option<String> = self.db.query_row("SELECT upstream FROM routes WHERE ip = ?1 AND ingress = ?2", params![ip.to_string(), id], |row| row.get(0)).optional()?;
            let selected = selected.unwrap_or_else(|| ingress.default_upstream.clone());
            Ok(json!({"id": id, "label": ingress.label, "selected": selected, "default": ingress.default_upstream}))
        }).collect::<rusqlite::Result<Vec<_>>>()?;
        let mut upstreams: Vec<_> = self
            .config
            .upstreams
            .iter()
            .map(|(id, upstream)| {
                json!({
                    "id": id, "label": upstream.label, "health": self.health.get(id),
                })
            })
            .collect();
        for route in &routes {
            let id = route["selected"].as_str().unwrap_or_default();
            if !self.config.upstreams.contains_key(id)
                && !upstreams.iter().any(|item| item["id"] == id)
            {
                upstreams.push(json!({"id": id, "label": format!("{id} (removed)"), "health": {"ready": false, "detail": "Selected exit was removed; no fallback"}}));
            }
        }
        let mut statement = self
            .db
            .prepare("SELECT name, ip FROM names ORDER BY name")?;
        let records = statement
            .query_map([], |row| {
                let name: String = row.get(0)?;
                let address: String = row.get(1)?;
                Ok(json!({"fqdn": format!("{name}.{}", self.config.domain), "ip": address}))
            })?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        let edit_error = self.editable(ip).err().map(|error| error.1);
        Ok(json!({
            "ip": ip, "kind": kind, "domain": self.config.domain,
            "reported_name": assignment.as_ref().and_then(|(name, _)| name.clone()),
            "expires": assignment.as_ref().and_then(|(_, expires)| *expires),
            "dns": name.map(|(name, custom)| json!({"fqdn": format!("{name}.{}", self.config.domain), "name": name, "custom": custom})),
            "records": records,
            "routes": routes, "upstreams": upstreams,
            "editable": edit_error.is_none(), "edit_error": edit_error,
            "inventory_warning": self.inventory_error.get(kind),
            "applied": !self.apply_error,
        }))
    }

    async fn handle(&mut self, request: Request) -> ApiResult<Value> {
        self.observe_source(request.ip)?;
        let ip = request.ip.to_string();
        match request.operation {
            Operation::View => {}
            Operation::Dns { name } => match name {
                Some(name) => {
                    if !valid_label(&name) {
                        return Err(ApiError(
                            400,
                            "Use 1–63 lowercase letters, digits, or hyphens; start and end with a letter or digit",
                        ));
                    }
                    if self.reserved(&name) {
                        return Err(ApiError(409, "This name is reserved"));
                    }
                    if !self.available(&name, &ip)? {
                        return Err(ApiError(409, "This name is already registered"));
                    }
                    self.db.execute("INSERT INTO names (ip, name, custom) VALUES (?1, ?2, 1) ON CONFLICT(ip) DO UPDATE SET name = excluded.name, custom = 1", params![ip, name])?;
                }
                None => {
                    self.db.execute("DELETE FROM names WHERE ip = ?1", [&ip])?;
                    self.allocate_names()
                        .map_err(|_| ApiError(500, "Unable to allocate the automatic name"))?;
                }
            },
            Operation::Route { ingress, upstream } => {
                let path = self
                    .config
                    .ingresses
                    .get(&ingress)
                    .ok_or(ApiError(400, "Unknown ingress path"))?;
                if Some(path.kind.as_str()) != self.config.kind(request.ip) {
                    return Err(ApiError(
                        403,
                        "This ingress does not belong to your source address",
                    ));
                }
                if !self.config.upstreams.contains_key(&upstream) {
                    return Err(ApiError(400, "Unknown upstream"));
                }
                if upstream == path.default_upstream {
                    self.db.execute(
                        "DELETE FROM routes WHERE ip = ?1 AND ingress = ?2",
                        params![ip, ingress],
                    )?;
                } else {
                    self.db.execute("INSERT INTO routes (ip, ingress, upstream) VALUES (?1, ?2, ?3) ON CONFLICT(ip, ingress) DO UPDATE SET upstream = excluded.upstream", params![ip, ingress, upstream])?;
                }
            }
        }
        self.apply().await;
        self.view(request.ip)
    }
}

pub async fn run(config: Config) -> Result<()> {
    let db_path = config.state_dir.join("state.sqlite");
    let db = Connection::open(&db_path)?;
    std::fs::set_permissions(&db_path, std::fs::Permissions::from_mode(0o600))?;
    db.busy_timeout(Duration::from_secs(5))?;
    let version: i64 = db.query_row("PRAGMA user_version", [], |row| row.get(0))?;
    ensure!(version <= 1, "database schema is newer than this be");
    db.execute_batch(include_str!("../migrations/001.sql"))?;
    let mut controller = Controller {
        config,
        db,
        inventory_error: BTreeMap::new(),
        health: BTreeMap::new(),
        applied: String::new(),
        apply_error: true,
    };
    // Read the current lease file before considering expiry: leases may have
    // been renewed while the controller was stopped. A failed snapshot is not
    // evidence that an address assignment ended.
    controller.office();
    controller.apply().await;
    // External inventory cannot block local self-service or packet-policy
    // restoration. Only complete snapshots cross into the serialized DB owner.
    let (updates, mut mesh_updates) = tokio::sync::mpsc::channel(1);
    let cloudflare = Cloudflare::from_env().unwrap_or_else(|error| {
        tracing::warn!(%error, "invalid Mesh inventory configuration; local self-service remains available");
        None
    });
    if let Some(cloudflare) = cloudflare {
        let config = controller.config.clone();
        tokio::spawn(async move {
            loop {
                let snapshot =
                    tokio::time::timeout(Duration::from_secs(20), cloudflare.snapshot(&config))
                        .await
                        .unwrap_or_else(|_| Err(anyhow::anyhow!("Cloudflare inventory timed out")));
                if updates.send(snapshot).await.is_err() {
                    break;
                }
                tokio::time::sleep(Duration::from_secs(60)).await;
            }
        });
    } else {
        controller.inventory_error.insert(
            "mesh".into(),
            "Mesh inventory credentials are missing or invalid; assignment cleanup is paused"
                .into(),
        );
    }
    if controller.config.socket.exists() {
        std::fs::remove_file(&controller.config.socket)?;
    }
    let listener =
        UnixListener::bind(&controller.config.socket).context("binding controller socket")?;
    std::fs::set_permissions(
        &controller.config.socket,
        std::fs::Permissions::from_mode(0o660),
    )?;
    tracing::info!("controller ready");
    let mut timer = tokio::time::interval(Duration::from_secs(5));
    timer.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    loop {
        tokio::select! {
            _ = tokio::signal::ctrl_c() => break,
            _ = timer.tick() => {
                controller.office();
                controller.apply().await;
            }
            Some(snapshot) = mesh_updates.recv() => {
                controller.mesh(snapshot);
                controller.apply().await;
            }
            connection = listener.accept() => {
                let (stream, _) = connection?;
                let (read, mut write) = stream.into_split();
                let mut read = BufReader::new(tokio::io::AsyncReadExt::take(read, 8193));
                let mut bytes = Vec::new();
                let received = tokio::time::timeout(Duration::from_secs(2), read.read_until(b'\n', &mut bytes)).await;
                if !matches!(received, Ok(Ok(1..=8192))) || bytes.last() != Some(&b'\n') { continue; }
                let reply = match serde_json::from_slice::<Request>(&bytes) {
                    Ok(request) => {
                        controller.office();
                        match controller.handle(request).await {
                            Ok(data) => Reply { status: 200, data },
                            Err(ApiError(status, error)) => Reply { status, data: json!({"error": error}) },
                        }
                    }
                    Err(_) => Reply { status: 400, data: json!({"error": "Invalid controller request"}) },
                };
                let mut bytes = serde_json::to_vec(&reply)?;
                bytes.push(b'\n');
                let _ = tokio::time::timeout(Duration::from_secs(2), write.write_all(&bytes)).await;
            }
        }
    }
    Ok(())
}
