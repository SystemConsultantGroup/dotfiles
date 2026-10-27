use crate::{
    activity,
    config::{Config, valid_label},
    device,
    inventory::{self, Assignment, Cloudflare},
    network,
};
use anyhow::{Context, Result, ensure};
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::{
    collections::{BTreeMap, BTreeSet},
    net::Ipv4Addr,
    os::unix::fs::{OpenOptionsExt, PermissionsExt},
    time::Duration,
};
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
    activity: activity::Collector,
}

impl Controller {
    fn assignments(&mut self, kind: &str, assignments: Vec<Assignment>) -> Result<()> {
        let tx = self.db.transaction()?;
        let existing: Vec<(String, String)> = {
            let mut query = tx.prepare("SELECT ip, generation FROM assignments WHERE kind = ?1")?;
            query
                .query_map([kind], |row| Ok((row.get(0)?, row.get(1)?)))?
                .collect::<rusqlite::Result<_>>()?
        };
        let active: BTreeMap<_, _> = assignments
            .iter()
            .map(|value| (value.ip.to_string(), value.generation.as_str()))
            .collect();
        for (ip, generation) in existing {
            // Inventory owns address lifetimes, not device preference lifetimes.
            // Static addresses observed through self-service remain bound until
            // a new authoritative lease or observed MAC replaces the binding.
            if !generation.starts_with("observed:")
                && active.get(&ip).copied() != Some(generation.as_str())
            {
                tx.execute("DELETE FROM assignments WHERE ip = ?1", [&ip])?;
            }
        }
        let mut identities = BTreeSet::new();
        for assignment in assignments {
            ensure!(assignment.kind == kind, "inventory kind mismatch");
            ensure!(
                identities.insert(assignment.identifier.clone()),
                "ambiguous device assignment"
            );
            device::bind(&tx, &assignment)?;
        }
        tx.commit()?;
        self.allocate_names()?;
        self.inventory_error.remove(kind);
        Ok(())
    }

    fn allocate_names(&mut self) -> Result<()> {
        let assignments: Vec<(i64, String, Option<String>)> = {
            let mut query = self.db.prepare("SELECT d.id, d.identifier, a.reported_name FROM assignments a JOIN devices d ON d.id = a.device_id ORDER BY a.ip")?;
            query
                .query_map([], |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)))?
                .collect::<rusqlite::Result<_>>()?
        };
        for (id, identifier, reported) in assignments {
            let existing: Option<(String, bool)> = self
                .db
                .query_row(
                    "SELECT name, custom FROM names WHERE device_id = ?1",
                    [id],
                    |row| Ok((row.get(0)?, row.get(1)?)),
                )
                .optional()?;
            if existing
                .as_ref()
                .is_some_and(|(_, custom)| *custom || reported.is_none())
            {
                continue;
            }
            let base = reported
                .unwrap_or_else(|| format!("device-{}", identifier.replace(['.', ':'], "-")));
            let mut candidate = base.clone();
            let mut ordinal = 0;
            while self.reserved(&candidate) || !self.available(&candidate, id)? {
                let suffix = if ordinal == 0 {
                    format!("-{id}")
                } else {
                    format!("-{id}-{ordinal}")
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
            self.db.execute("INSERT INTO names(device_id, name, custom) VALUES (?1, ?2, 0) ON CONFLICT(device_id) DO UPDATE SET name = excluded.name", params![id, candidate])?;
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

    fn available(&self, name: &str, id: i64) -> rusqlite::Result<bool> {
        self.db.query_row(
            "SELECT NOT EXISTS(SELECT 1 FROM names WHERE name = ?1 AND device_id != ?2)",
            params![name, id],
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

    async fn observe_source(&mut self, ip: Ipv4Addr) -> ApiResult<i64> {
        self.editable(ip)?;
        let kind = self.config.kind(ip).expect("authorized source kind");
        let address = ip.to_string();
        let identifier = if kind == "office" {
            let ingress = self
                .config
                .ingresses
                .values()
                .find(|ingress| {
                    ingress.kind == "office"
                        && ingress
                            .network
                            .parse::<ipnet::Ipv4Net>()
                            .is_ok_and(|net| net.contains(&ip))
                })
                .ok_or(ApiError(503, "Office interface unavailable"))?;
            // Resolve on the controller, never trust a MAC/device ID supplied
            // by HTTP. A neighbor entry is an identity hint, not authentication.
            let bytes = network::command(
                &self.config.ip,
                &[
                    "-j",
                    "-4",
                    "neigh",
                    "show",
                    "to",
                    &address,
                    "dev",
                    &ingress.interface,
                ],
                None,
            )
            .await
            .map_err(|_| ApiError(503, "Unable to resolve your device identity"))?;
            let neighbors: Vec<Value> = serde_json::from_slice(&bytes)
                .map_err(|_| ApiError(503, "Unable to resolve your device identity"))?;
            let macs: BTreeSet<_> = neighbors
                .iter()
                .filter(|neighbor| {
                    neighbor["dst"].as_str() == Some(address.as_str())
                        && neighbor["state"].as_array().is_some_and(|states| {
                            states.iter().any(|state| {
                                matches!(
                                    state.as_str(),
                                    Some("REACHABLE" | "STALE" | "DELAY" | "PROBE")
                                )
                            })
                        })
                })
                .filter_map(|neighbor| neighbor["lladdr"].as_str().and_then(device::mac))
                .collect();
            if macs.len() != 1 {
                return Err(ApiError(
                    503,
                    "Your office MAC is not resolved yet; retry shortly",
                ));
            }
            macs.into_iter().next().expect("one MAC")
        } else {
            address.clone()
        };
        if let Some((id, stored, generation)) = self.db.query_row(
            "SELECT d.id, d.identifier, a.generation FROM assignments a JOIN devices d ON d.id = a.device_id WHERE a.ip = ?1", [&address],
            |row| Ok((row.get::<_, i64>(0)?, row.get::<_, String>(1)?, row.get::<_, String>(2)?))).optional()? {
            if stored == identifier { return Ok(id); }
            if !generation.starts_with("observed:") {
                return Err(ApiError(409, "Your observed MAC conflicts with the DHCP assignment; retry shortly"));
            }
        }
        let assignment = Assignment {
            ip,
            kind: kind.into(),
            identifier,
            generation: format!("observed:{ip}"),
            reported_name: None,
            expires: None,
        };
        let tx = self.db.transaction()?;
        let id = device::bind(&tx, &assignment)
            .map_err(|_| ApiError(500, "Unable to bind your device identity"))?;
        tx.commit()?;
        Ok(id)
    }

    fn view(&self, ip: Ipv4Addr, id: i64) -> ApiResult<Value> {
        let kind = self
            .config
            .kind(ip)
            .ok_or(ApiError(403, "This source address cannot use self-service"))?;
        let identifier: String = self.db.query_row(
            "SELECT identifier FROM devices WHERE id = ?1",
            [id],
            |row| row.get(0),
        )?;
        let activity = if kind == "office" {
            Some(
                activity::view(&self.db, id, &self.config, self.activity.warning)
                    .map_err(|_| ApiError(500, "Unable to read activity history"))?,
            )
        } else {
            None
        };
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
                "SELECT name, custom FROM names WHERE device_id = ?1",
                [id],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .optional()?;
        let routes = self.config.ingresses.iter().filter(|(_, ingress)| ingress.kind == kind).map(|(ingress_id, ingress)| {
            let selected: Option<String> = self.db.query_row("SELECT upstream FROM routes WHERE device_id = ?1 AND ingress = ?2", params![id, ingress_id], |row| row.get(0)).optional()?;
            let selected = selected.unwrap_or_else(|| ingress.default_upstream.clone());
            Ok(json!({"id": ingress_id, "label": ingress.label, "selected": selected, "default": ingress.default_upstream}))
        }).collect::<rusqlite::Result<Vec<_>>>()?;
        let mut upstreams: Vec<_> = self.config.upstreams.iter().map(|(id, upstream)| {
            json!({"id": id, "label": upstream.label, "health": self.health.get(id)})
        }).collect();
        for route in &routes {
            let id = route["selected"].as_str().unwrap_or_default();
            if !self.config.upstreams.contains_key(id)
                && !upstreams.iter().any(|item| item["id"] == id)
            {
                upstreams.push(json!({"id": id, "label": format!("{id} (removed)"), "health": {"ready": false, "detail": "Selected exit was removed; no fallback"}}));
            }
        }
        // Shared DNS records remain public to portal clients, but device MACs
        // and activity history are returned only for the requesting device.
        let mut statement = self.db.prepare("SELECT n.name, a.ip FROM names n JOIN assignments a ON a.device_id = n.device_id ORDER BY n.name, a.ip")?;
        let records = statement
            .query_map([], |row| {
                let name: String = row.get(0)?;
                let address: String = row.get(1)?;
                Ok(json!({"fqdn": format!("{name}.{}", self.config.domain), "ip": address}))
            })?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        let edit_error = self.editable(ip).err().map(|error| error.1);
        Ok(json!({
            "id": id.to_string(), "identifier": identifier, "activity": activity,
            "ip": ip, "kind": kind, "domain": self.config.domain,
            "reported_name": assignment.as_ref().and_then(|(name, _)| name.clone()),
            "expires": assignment.as_ref().and_then(|(_, expires)| *expires),
            "dns": name.map(|(name, custom)| json!({"fqdn": format!("{name}.{}", self.config.domain), "name": name, "custom": custom})),
            "records": records, "routes": routes, "upstreams": upstreams,
            "editable": edit_error.is_none(), "edit_error": edit_error,
            "inventory_warning": self.inventory_error.get(kind), "applied": !self.apply_error,
        }))
    }

    async fn handle(&mut self, request: Request) -> ApiResult<Value> {
        let id = self.observe_source(request.ip).await?;
        self.allocate_names()
            .map_err(|_| ApiError(500, "Unable to allocate the automatic name"))?;
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
                    if !self.available(&name, id)? {
                        return Err(ApiError(409, "This name is already registered"));
                    }
                    self.db.execute("INSERT INTO names(device_id, name, custom) VALUES (?1, ?2, 1) ON CONFLICT(device_id) DO UPDATE SET name = excluded.name, custom = 1", params![id, name])?;
                }
                None => {
                    self.db
                        .execute("DELETE FROM names WHERE device_id = ?1", [id])?;
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
                        "DELETE FROM routes WHERE device_id = ?1 AND ingress = ?2",
                        params![id, ingress],
                    )?;
                } else {
                    self.db.execute("INSERT INTO routes(device_id, ingress, upstream) VALUES (?1, ?2, ?3) ON CONFLICT(device_id, ingress) DO UPDATE SET upstream = excluded.upstream", params![id, ingress, upstream])?;
                }
            }
        }
        self.apply().await;
        self.view(request.ip, id)
    }
}

fn controller_backup(config: &Config, db: &Connection) -> Result<std::path::PathBuf> {
    let path = config.state_dir.join(format!(
        "state-v1-{}-{}.sqlite",
        inventory::now(),
        std::process::id()
    ));
    // Pre-create an empty private file; VACUUM INTO accepts empty targets.
    std::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .open(&path)?;
    if let Err(error) = db.execute(
        "VACUUM INTO ?1",
        [path.to_str().context("invalid backup path")?],
    ) {
        let _ = std::fs::remove_file(&path);
        return Err(error.into());
    }
    Ok(path)
}

pub async fn run(config: Config) -> Result<()> {
    let db_path = config.state_dir.join("state.sqlite");
    let mut db = Connection::open(&db_path)?;
    std::fs::set_permissions(&db_path, std::fs::Permissions::from_mode(0o600))?;
    db.busy_timeout(Duration::from_secs(5))?;
    let version: i64 = db.query_row("PRAGMA user_version", [], |row| row.get(0))?;
    if version == 1 {
        let backup = controller_backup(&config, &db)?;
        tracing::info!(path = %backup.display(), "saved pre-migration database backup");
    }
    device::migrate(&mut db)?;
    let activity = activity::Collector::new(&db)?;
    let mut controller = Controller {
        config,
        db,
        inventory_error: BTreeMap::new(),
        health: BTreeMap::new(),
        applied: String::new(),
        apply_error: true,
        activity,
    };
    // Read renewed leases before considering expiry. Failed inventory snapshots
    // are not evidence that existing assignments have ended.
    controller.office();
    controller.apply().await;
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
    let mut activity_timer = tokio::time::interval(Duration::from_secs(activity::POLL_SECONDS));
    activity_timer.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    loop {
        tokio::select! {
            _ = tokio::signal::ctrl_c() => break,
            _ = timer.tick() => {
                controller.office();
                controller.apply().await;
            }
            _ = activity_timer.tick() => {
                controller.activity.poll(&controller.config, &mut controller.db).await;
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
