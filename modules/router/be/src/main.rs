mod activity;
mod config;
mod controller;
mod device;
mod inventory;
mod network;
mod web;

use anyhow::Result;
use clap::{Parser, Subcommand};
use std::{net::Ipv4Addr, path::PathBuf};

#[derive(Parser)]
#[command(name = "router-be")]
struct Cli {
    #[command(subcommand)]
    command: Mode,
}

#[derive(Subcommand)]
enum Mode {
    Web {
        #[arg(long)]
        config: PathBuf,
        #[arg(long)]
        assets: PathBuf,
        #[arg(long)]
        cert: PathBuf,
        #[arg(long)]
        key: PathBuf,
        #[arg(long, default_value_t = 443)]
        port: u16,
    },
    Controller {
        #[arg(long)]
        config: PathBuf,
    },
    Observe {
        #[arg(long)]
        directory: PathBuf,
        action: String,
        mac: String,
        ip: Ipv4Addr,
        #[arg(default_value = "*")]
        hostname: String,
    },
    PrepareLeases {
        #[arg(long)]
        lease_file: PathBuf,
        #[arg(long)]
        directory: PathBuf,
    },
    Render {
        #[arg(long)]
        config: PathBuf,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    rustls::crypto::ring::default_provider()
        .install_default()
        .map_err(|_| anyhow::anyhow!("installing TLS provider"))?;
    tracing_subscriber::fmt().with_target(false).init();
    match Cli::parse().command {
        Mode::Web {
            config,
            assets,
            cert,
            key,
            port,
        } => web::run(config::Config::load(&config)?, assets, cert, key, port).await,
        Mode::Controller { config } => controller::run(config::Config::load(&config)?).await,
        Mode::Observe {
            directory,
            action,
            mac,
            ip,
            hostname,
        } => inventory::observe(&directory, &action, &mac, ip, &hostname),
        Mode::PrepareLeases {
            lease_file,
            directory,
        } => inventory::prepare_leases(&lease_file, &directory),
        Mode::Render { config } => {
            let config = config::Config::load(&config)?;
            let mut db = rusqlite::Connection::open_in_memory()?;
            device::migrate(&mut db)?;
            print!("{}", network::rules(&config, &db)?);
            Ok(())
        }
    }
}
