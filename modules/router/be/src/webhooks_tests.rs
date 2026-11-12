use super::*;

struct Fixture {
    db: Connection,
    collector: activity::Collector,
    owner: i64,
    other: i64,
}

impl Fixture {
    fn new() -> Self {
        let mut db = Connection::open_in_memory().unwrap();
        crate::device::migrate(&mut db).unwrap();
        let owner = crate::device::ensure_device(&db, "office", "02:00:00:00:00:01").unwrap();
        let other = crate::device::ensure_device(&db, "office", "02:00:00:00:00:02").unwrap();
        let mut collector = activity::Collector::new(&db).unwrap();
        collector.warning = None;
        collector.sampled_at = Some(300);
        Self {
            db,
            collector,
            owner,
            other,
        }
    }

    fn call(&mut self, owner: Option<i64>, op: Operation) -> ApiResult {
        let expected_status = match op {
            Operation::Finish { accepted: true, .. } => 201,
            Operation::Delete { .. } => 204,
            _ => 200,
        };
        handle(&mut self.db, owner, op, 60, 30, &self.collector).map(|reply| {
            assert_eq!(reply.status, expected_status);
            reply.data
        })
    }

    fn begin(&mut self) -> String {
        self.call(
            Some(self.owner),
            Operation::Begin {
                url: "https://example.com/hook".into(),
            },
        )
        .unwrap()["id"]
            .as_str()
            .unwrap()
            .into()
    }

    fn activate(&mut self) -> String {
        let id = self.begin();
        let result = self
            .call(
                Some(self.owner),
                Operation::Finish {
                    id: id.clone(),
                    accepted: true,
                },
            )
            .unwrap();
        assert_eq!(result["id"], id);
        id
    }

    fn read(&mut self, id: &str, view: &str, query: Query) -> ApiResult {
        self.call(
            None,
            Operation::Read {
                id: id.into(),
                view: view.into(),
                query,
            },
        )
    }

    fn session(&self, owner: i64, start: i64, last: i64, end: Option<i64>) {
        self.db.execute("INSERT INTO activity_sessions(device_id, started_at, last_activity, ended_at, end_reason) VALUES (?1, ?2, ?3, ?4, CASE WHEN ?4 IS NULL THEN NULL ELSE 'inactivity' END)", params![owner, start, last, end]).unwrap();
    }
}

#[test]
fn verification_gates_reads_and_failure_cancels() {
    let mut f = Fixture::new();
    let id = f.begin();
    assert_eq!(id.len(), 64);
    assert!(id.bytes().all(|v| v.is_ascii_hexdigit()));
    assert_eq!(f.read(&id, "", Query::default()).unwrap_err().0, 404);
    assert_eq!(
        f.call(
            Some(f.owner),
            Operation::Finish {
                id: id.clone(),
                accepted: false
            }
        )
        .unwrap_err()
        .0,
        422
    );
    assert_eq!(
        f.db.query_row("SELECT COUNT(*) FROM activity_webhooks", [], |r| r
            .get::<_, i64>(0))
            .unwrap(),
        0
    );
    assert_eq!(f.read(&id, "", Query::default()).unwrap_err().0, 404);
}

#[test]
fn ownership_duplicates_limits_and_revocation() {
    let mut f = Fixture::new();
    let id = f.activate();
    let duplicate = f
        .call(
            Some(f.owner),
            Operation::Begin {
                url: "https://example.com/hook".into(),
            },
        )
        .unwrap();
    assert_eq!(duplicate["id"], id);
    assert_eq!(duplicate["existing"], true);
    assert_eq!(f.call(Some(f.other), Operation::List).unwrap(), json!([]));
    assert_eq!(
        f.call(Some(f.other), Operation::Delete { id: id.clone() })
            .unwrap_err()
            .0,
        404
    );
    assert_eq!(
        f.call(
            Some(f.other),
            Operation::Finish {
                id: id.clone(),
                accepted: true
            }
        )
        .unwrap_err()
        .0,
        404
    );
    f.call(Some(f.owner), Operation::Delete { id: id.clone() })
        .unwrap();
    assert_eq!(f.read(&id, "", Query::default()).unwrap_err().0, 404);
    assert_eq!(f.call(None, Operation::Jobs).unwrap(), json!([]));
    for n in 0..16 {
        f.call(
            Some(f.owner),
            Operation::Begin {
                url: format!("https://example.com/{n}"),
            },
        )
        .unwrap();
    }
    assert_eq!(
        f.call(
            Some(f.owner),
            Operation::Begin {
                url: "https://example.com/overflow".into()
            }
        )
        .unwrap_err()
        .0,
        409
    );
}

#[test]
fn pending_duplicates_and_expiry() {
    let mut f = Fixture::new();
    let old = f.begin();
    assert_eq!(
        f.call(
            Some(f.owner),
            Operation::Begin {
                url: "https://example.com/hook".into()
            }
        )
        .unwrap_err()
        .0,
        409
    );
    f.db.execute("UPDATE activity_webhooks SET created_at = 0", [])
        .unwrap();
    let new = f.begin();
    assert_ne!(old, new);
}

#[test]
fn notifications_coalesce_retry_and_ignore_stale_results() {
    let mut f = Fixture::new();
    let id = f.activate();
    let jobs = f.call(None, Operation::Jobs).unwrap();
    assert_eq!(jobs.as_array().unwrap().len(), 1);
    assert_eq!(jobs[0]["revision"], 1);
    f.call(
        None,
        Operation::Delivered {
            id: id.clone(),
            revision: 1,
            success: false,
        },
    )
    .unwrap();
    assert_eq!(f.call(None, Operation::Jobs).unwrap(), json!([]));
    let now = inventory::now();
    f.session(f.owner, now, now, None);
    refresh(&f.db, false, now, 60).unwrap();
    let jobs = f.call(None, Operation::Jobs).unwrap();
    assert_eq!(jobs[0]["revision"], 2);
    f.call(
        None,
        Operation::Delivered {
            id: id.clone(),
            revision: 1,
            success: false,
        },
    )
    .unwrap();
    assert_eq!(f.call(None, Operation::Jobs).unwrap()[0]["revision"], 2);
    f.call(
        None,
        Operation::Delivered {
            id: id.clone(),
            revision: 1,
            success: true,
        },
    )
    .unwrap();
    assert_eq!(f.call(None, Operation::Jobs).unwrap()[0]["revision"], 2);
    f.call(
        None,
        Operation::Delivered {
            id,
            revision: 2,
            success: true,
        },
    )
    .unwrap();
    assert_eq!(f.call(None, Operation::Jobs).unwrap(), json!([]));
    refresh(&f.db, false, now + 1, 60).unwrap();
    assert_eq!(f.call(None, Operation::Jobs).unwrap(), json!([]));
    refresh(&f.db, true, now + 2, 60).unwrap();
    assert_eq!(f.call(None, Operation::Jobs).unwrap()[0]["revision"], 3);
}

#[test]
fn checkpoint_and_notification_rollback_together() {
    let mut f = Fixture::new();
    let id = f.activate();
    f.call(
        None,
        Operation::Delivered {
            id,
            revision: 1,
            success: true,
        },
    )
    .unwrap();
    let now = inventory::now();
    {
        let tx = f.db.transaction().unwrap();
        tx.execute("INSERT INTO activity_sessions(device_id, started_at, last_activity) VALUES (?1, ?2, ?2)", params![f.owner, now]).unwrap();
        refresh(&tx, false, now, 60).unwrap();
        // Drop without commit simulates a failed checkpoint.
    }
    assert_eq!(f.call(None, Operation::Jobs).unwrap(), json!([]));
}

#[test]
fn current_uses_existing_names_and_milliseconds() {
    let mut f = Fixture::new();
    let now = inventory::now();
    f.collector.sampled_at = Some(now);
    f.session(f.owner, now - 10, now - 1, None);
    let id = f.activate();
    let value = f.read(&id, "", Query::default()).unwrap();
    assert_eq!(value["status"], "online");
    assert_eq!(value["last_activity"], (now - 1) * 1000);
    assert_eq!(value["session_started_at"], (now - 10) * 1000);
    assert_eq!(value["sampled_at"], now * 1000);
    assert!(value.get("state").is_none());
    f.collector.warning = Some("Monitoring unavailable");
    assert_eq!(
        f.read(&id, "", Query::default()).unwrap()["status"],
        "unknown"
    );
}

#[test]
fn sessions_overlap_paginate_and_never_cross_devices() {
    let mut f = Fixture::new();
    f.session(f.owner, 100, 110, Some(120));
    f.session(f.owner, 200, 210, Some(220));
    f.session(f.other, 250, 260, Some(270));
    let id = f.activate();
    let page = f
        .read(
            &id,
            "sessions",
            Query {
                from: Some(100500),
                to: Some(220000),
                limit: Some(1),
                cursor: None,
            },
        )
        .unwrap();
    assert_eq!(page["sessions"].as_array().unwrap().len(), 1);
    assert_eq!(page["sessions"][0]["started_at"], 200000);
    let cursor = page["next_cursor"].as_str().unwrap().to_owned();
    let next = f
        .read(
            &id,
            "sessions",
            Query {
                from: Some(100500),
                to: Some(220000),
                limit: Some(1),
                cursor: Some(cursor),
            },
        )
        .unwrap();
    assert_eq!(next["sessions"][0]["started_at"], 100000);
    assert!(next["next_cursor"].is_null());
    let boundary = f
        .read(
            &id,
            "sessions",
            Query {
                from: Some(120000),
                to: Some(200000),
                ..Query::default()
            },
        )
        .unwrap();
    assert_eq!(boundary["sessions"], json!([]));
}

#[test]
fn summary_clips_at_millisecond_bounds_and_observation() {
    let mut f = Fixture::new();
    f.session(f.owner, 100, 110, Some(120));
    f.session(f.owner, 200, 250, None);
    f.session(f.other, 100, 200, Some(300));
    let id = f.activate();
    let value = f
        .read(
            &id,
            "summary",
            Query {
                from: Some(110501),
                to: Some(280999),
                ..Query::default()
            },
        )
        .unwrap();
    assert_eq!(value["total_ms"], 9499 + 80999);
    let value = f
        .read(
            &id,
            "summary",
            Query {
                from: Some(0),
                to: Some(999999),
                ..Query::default()
            },
        )
        .unwrap();
    assert_eq!(value["total_ms"], 20000 + 100000);
    f.collector.sampled_at = None;
    let value = f
        .read(
            &id,
            "summary",
            Query {
                from: Some(0),
                to: Some(999999),
                ..Query::default()
            },
        )
        .unwrap();
    assert_eq!(value["total_ms"], 20000);
}

#[test]
fn invalid_queries_are_rejected() {
    let mut f = Fixture::new();
    let id = f.activate();
    for query in [
        Query {
            from: Some(-1),
            ..Query::default()
        },
        Query {
            from: Some(20),
            to: Some(10),
            ..Query::default()
        },
        Query {
            limit: Some(101),
            ..Query::default()
        },
        Query {
            limit: Some(0),
            ..Query::default()
        },
        Query {
            cursor: Some("bad".into()),
            ..Query::default()
        },
    ] {
        assert_eq!(f.read(&id, "sessions", query).unwrap_err().0, 400);
    }
    assert_eq!(f.read(&id, "summary", Query::default()).unwrap_err().0, 400);
    assert_eq!(f.read(&id, "unknown", Query::default()).unwrap_err().0, 404);
}

#[test]
fn migration_preserves_version_two_data_and_is_repeatable() {
    let mut f = Fixture::new();
    f.session(f.owner, 100, 110, Some(120));
    f.db.execute_batch("DROP TABLE activity_webhooks; PRAGMA user_version = 2;")
        .unwrap();
    crate::device::migrate(&mut f.db).unwrap();
    crate::device::migrate(&mut f.db).unwrap();
    assert_eq!(
        f.db.query_row("PRAGMA user_version", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        3
    );
    assert_eq!(
        f.db.query_row("SELECT COUNT(*) FROM activity_sessions", [], |r| r
            .get::<_, i64>(0))
            .unwrap(),
        1
    );
}

#[test]
fn callback_validation_and_acknowledgements() {
    for url in [
        "http://example.com",
        "https://user:pass@example.com",
        "https://example.com/#fragment",
        "file:///etc/passwd",
    ] {
        assert!(callback_url(url).is_err());
    }
    assert!(callback_url("https://example.com/hook?key=value").is_ok());
    assert!(acknowledges(br#"{"id":"test"}"#, "test"));
    for body in [
        br#"{"id":"wrong"}"#.as_slice(),
        br#"{"id":5}"#,
        b"test",
        b"{}",
    ] {
        assert!(!acknowledges(body, "test"));
    }
    assert!(!acknowledges(&vec![b' '; 1025], "test"));
}

#[test]
fn rejects_non_public_destinations_including_transition_addresses() {
    for address in [
        "0.0.0.0",
        "10.0.0.1",
        "127.0.0.1",
        "100.64.0.1",
        "169.254.169.254",
        "172.16.0.1",
        "192.168.0.1",
        "192.0.2.1",
        "198.18.0.1",
        "198.51.100.1",
        "203.0.113.1",
        "224.0.0.1",
        "255.255.255.255",
        "::",
        "::1",
        "::ffff:127.0.0.1",
        "64:ff9b::7f00:1",
        "fc00::1",
        "fe80::1",
        "2001:db8::1",
        "2001::1",
        "2002:7f00:1::",
        "3fff::1",
    ] {
        assert!(!public_ip(address.parse().unwrap()), "{address}");
    }
    for address in [
        "1.1.1.1",
        "8.8.8.8",
        "2606:4700:4700::1111",
        "2001:4860:4860::8888",
    ] {
        assert!(public_ip(address.parse().unwrap()), "{address}");
    }
}

#[tokio::test]
async fn callback_never_connects_to_loopback() {
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!(
        "https://127.0.0.1:{}/",
        listener.local_addr().unwrap().port()
    );
    assert!(!callback(&url, Some("test")).await);
    assert!(
        tokio::time::timeout(Duration::from_millis(20), listener.accept())
            .await
            .is_err()
    );
}
