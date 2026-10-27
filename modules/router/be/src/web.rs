use crate::{
    config::Config,
    controller::{Operation, Reply, Request as ControlRequest},
};
use anyhow::Result;
use axum::{
    Json, Router,
    extract::{ConnectInfo, DefaultBodyLimit, Request, State},
    http::{HeaderValue, StatusCode, header},
    middleware::{self, Next},
    response::{IntoResponse, Response},
    routing::get,
};
use axum_server::tls_rustls::RustlsConfig;
use serde::Deserialize;
use serde_json::{Value, json};
use std::{
    net::{IpAddr, Ipv4Addr, SocketAddr},
    path::PathBuf,
    sync::Arc,
    time::Duration,
};
use tokio::{
    io::{AsyncBufReadExt, AsyncWriteExt, BufReader},
    net::UnixStream,
};
use tower_http::services::ServeDir;

#[derive(Clone)]
struct WebState {
    config: Arc<Config>,
}

fn error(status: StatusCode, message: &'static str) -> Response {
    (status, Json(json!({"error": message}))).into_response()
}

async fn guard(State(state): State<WebState>, request: Request, next: Next) -> Response {
    // HTTP/2 carries the hostname in :authority rather than a Host header.
    let host = request
        .headers()
        .get(header::HOST)
        .and_then(|value| value.to_str().ok())
        .or_else(|| {
            request
                .uri()
                .authority()
                .map(|authority| authority.as_str())
        })
        .unwrap_or_default();
    if host != state.config.hostname && host != format!("{}:443", state.config.hostname) {
        return error(
            StatusCode::MISDIRECTED_REQUEST,
            "Unexpected portal hostname",
        );
    }
    let ip = request
        .extensions()
        .get::<ConnectInfo<SocketAddr>>()
        .map(|info| info.0.ip());
    if !matches!(ip, Some(IpAddr::V4(ip)) if state.config.kind(ip).is_some() && ip != state.config.address)
    {
        return error(
            StatusCode::FORBIDDEN,
            "This source address cannot use self-service",
        );
    }
    if request.uri().path().starts_with("/api/")
        && request
            .headers()
            .get("sec-fetch-site")
            .is_some_and(|value| value == "cross-site")
    {
        return error(
            StatusCode::FORBIDDEN,
            "Cross-site API requests are not allowed",
        );
    }
    if !matches!(
        *request.method(),
        axum::http::Method::GET | axum::http::Method::HEAD
    ) {
        let origin = request
            .headers()
            .get(header::ORIGIN)
            .and_then(|value| value.to_str().ok());
        let expected = format!("https://{}", state.config.hostname);
        let content_type = request
            .headers()
            .get(header::CONTENT_TYPE)
            .and_then(|value| value.to_str().ok())
            .unwrap_or_default();
        if origin != Some(expected.as_str())
            || !content_type
                .split(';')
                .next()
                .is_some_and(|value| value.trim() == "application/json")
        {
            return error(
                StatusCode::FORBIDDEN,
                "A same-origin JSON request is required",
            );
        }
    }
    let mut response = next.run(request).await;
    for (name, value) in [
        ("strict-transport-security", "max-age=31536000"),
        ("x-content-type-options", "nosniff"),
        ("x-frame-options", "DENY"),
        ("referrer-policy", "same-origin"),
        (
            "permissions-policy",
            "camera=(), microphone=(), geolocation=()",
        ),
        (
            "content-security-policy",
            "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'; object-src 'none'",
        ),
        ("cache-control", "no-store"),
    ] {
        response
            .headers_mut()
            .insert(name, HeaderValue::from_static(value));
    }
    response
}

async fn control(state: &WebState, ip: Ipv4Addr, operation: Operation) -> Response {
    let result: Result<Reply> = async {
        let mut stream = UnixStream::connect(&state.config.socket).await?;
        let mut bytes = serde_json::to_vec(&ControlRequest { ip, operation })?;
        bytes.push(b'\n');
        stream.write_all(&bytes).await?;
        let mut read = BufReader::new(tokio::io::AsyncReadExt::take(stream, 65537));
        let mut bytes = Vec::new();
        read.read_until(b'\n', &mut bytes).await?;
        anyhow::ensure!(
            bytes.len() <= 65536 && bytes.last() == Some(&b'\n'),
            "invalid controller response"
        );
        Ok(serde_json::from_slice(&bytes)?)
    }
    .await;
    match result {
        Ok(reply) => (
            StatusCode::from_u16(reply.status).unwrap_or(StatusCode::INTERNAL_SERVER_ERROR),
            Json(reply.data),
        )
            .into_response(),
        Err(_) => error(
            StatusCode::SERVICE_UNAVAILABLE,
            "The controller is unavailable; existing policy remains in effect",
        ),
    }
}

async fn request(state: WebState, peer: SocketAddr, operation: Operation) -> Response {
    let IpAddr::V4(ip) = peer.ip() else {
        return error(StatusCode::FORBIDDEN, "IPv4 is required");
    };
    tokio::time::timeout(Duration::from_secs(25), control(&state, ip, operation))
        .await
        .unwrap_or_else(|_| {
            error(
                StatusCode::SERVICE_UNAVAILABLE,
                "The controller is busy; retry shortly",
            )
        })
}

async fn me(State(state): State<WebState>, ConnectInfo(peer): ConnectInfo<SocketAddr>) -> Response {
    request(state, peer, Operation::View).await
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Dns {
    name: Option<String>,
}
async fn dns(
    State(state): State<WebState>,
    ConnectInfo(peer): ConnectInfo<SocketAddr>,
    Json(body): Json<Dns>,
) -> Response {
    request(state, peer, Operation::Dns { name: body.name }).await
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Route {
    ingress: String,
    upstream: String,
}
async fn route(
    State(state): State<WebState>,
    ConnectInfo(peer): ConnectInfo<SocketAddr>,
    Json(body): Json<Route>,
) -> Response {
    request(
        state,
        peer,
        Operation::Route {
            ingress: body.ingress,
            upstream: body.upstream,
        },
    )
    .await
}

pub async fn run(
    config: Config,
    assets: PathBuf,
    cert: PathBuf,
    key: PathBuf,
    port: u16,
) -> Result<()> {
    let address = SocketAddr::from((config.address, port));
    let tls = RustlsConfig::from_pem_file(cert, key).await?;
    let state = WebState {
        config: Arc::new(config),
    };
    let api = Router::new()
        .route("/me", get(me))
        .route("/me/dns", axum::routing::patch(dns))
        .route("/me/routes", axum::routing::patch(route))
        .fallback(|| async {
            (
                StatusCode::NOT_FOUND,
                Json::<Value>(json!({"error": "Unknown API endpoint"})),
            )
        });
    let app = Router::new()
        .nest("/api", api)
        .fallback_service(ServeDir::new(assets))
        .layer(DefaultBodyLimit::max(4096))
        .layer(middleware::from_fn_with_state(state.clone(), guard))
        .with_state(state);
    let handle = axum_server::Handle::new();
    let shutdown = handle.clone();
    tokio::spawn(async move {
        let mut terminate =
            tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
                .expect("SIGTERM handler");
        tokio::select! { _ = tokio::signal::ctrl_c() => {}, _ = terminate.recv() => {} }
        shutdown.graceful_shutdown(Some(Duration::from_secs(5)));
    });
    tracing::info!(%address, "be HTTPS ready");
    axum_server::bind_rustls(address, tls)
        .handle(handle)
        .serve(app.into_make_service_with_connect_info::<SocketAddr>())
        .await?;
    Ok(())
}
