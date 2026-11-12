use super::*;

fn controller() -> Controller {
    let config: Config = serde_json::from_value(json!({
        "hostname": "router.scg.sh", "address": "10.0.0.1", "domain": "home.arpa",
        "state_dir": "/unused", "socket": "/unused", "lease_file": "/unused",
        "ip": "/does-not-exist", "nft": "/does-not-exist",
        "activity": {"idle_seconds": 300, "retention_days": 30},
        "reserved_names": [], "internal_networks": [], "upstreams": {},
        "ingresses": {
            "office": {"label": "Office", "interface": "lan", "network": "10.0.0.0/16", "kind": "office", "defaultUpstream": "unused", "returnId": 1, "returnTable": 210},
            "mesh": {"label": "Mesh", "interface": "mesh", "network": "100.64.0.0/24", "kind": "mesh", "defaultUpstream": "unused", "returnId": 2, "returnTable": 211}
        }
    })).unwrap();
    let mut db = Connection::open_in_memory().unwrap();
    device::migrate(&mut db).unwrap();
    let activity = activity::Collector::new(&db).unwrap();
    Controller {
        config,
        db,
        activity,
        inventory_error: BTreeMap::new(),
        health: BTreeMap::new(),
        applied: String::new(),
        apply_error: false,
    }
}

#[tokio::test]
async fn mesh_and_non_lan_devices_cannot_manage_webhooks() {
    let mut c = controller();
    for ip in ["100.64.0.2", "192.0.2.1"] {
        for operation in [
            crate::webhooks::Operation::List,
            crate::webhooks::Operation::Begin {
                url: "https://example.com/hook".into(),
            },
            crate::webhooks::Operation::Delete {
                id: "unknown".into(),
            },
            crate::webhooks::Operation::Finish {
                id: "unknown".into(),
                accepted: true,
            },
        ] {
            let result = c
                .handle(Request {
                    ip: ip.parse().unwrap(),
                    operation: Operation::Webhook { operation },
                })
                .await;
            assert!(matches!(result, Err(ApiError(403, _))));
        }
    }
}

#[tokio::test]
async fn unresolved_lan_identity_does_not_create_subscription() {
    let mut c = controller();
    let result = c
        .handle(Request {
            ip: "10.0.0.2".parse().unwrap(),
            operation: Operation::Webhook {
                operation: crate::webhooks::Operation::Begin {
                    url: "https://example.com/hook".into(),
                },
            },
        })
        .await;
    assert!(matches!(result, Err(ApiError(503, _))));
    assert_eq!(
        c.db.query_row("SELECT COUNT(*) FROM activity_webhooks", [], |r| r
            .get::<_, i64>(0))
            .unwrap(),
        0
    );
}

#[tokio::test]
async fn token_reads_do_not_resolve_or_create_requesting_devices() {
    let mut c = controller();
    let result = c
        .handle(Request {
            ip: "100.64.0.2".parse().unwrap(),
            operation: Operation::Webhook {
                operation: crate::webhooks::Operation::Read {
                    id: "unknown".into(),
                    view: String::new(),
                    query: crate::webhooks::Query::default(),
                },
            },
        })
        .await;
    assert!(matches!(result, Err(ApiError(404, _))));
    assert_eq!(
        c.db.query_row("SELECT COUNT(*) FROM devices", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        0
    );
}

#[test]
fn caller_supplied_identity_fields_are_rejected() {
    let request = json!({"ip": "10.0.0.2", "operation": {"type": "webhook", "operation": {"action": "begin", "url": "https://example.com", "device_id": 42}}});
    assert!(serde_json::from_value::<Request>(request).is_err());
}
