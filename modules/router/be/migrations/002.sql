CREATE TABLE devices (
    id INTEGER PRIMARY KEY,
    kind TEXT NOT NULL CHECK (kind IN ('office', 'mesh')),
    identifier TEXT NOT NULL,
    UNIQUE (kind, identifier)
);
ALTER TABLE assignments ADD COLUMN device_id INTEGER REFERENCES devices(id);
ALTER TABLE names RENAME TO legacy_names;
ALTER TABLE routes RENAME TO legacy_routes;
CREATE TABLE names (
    device_id INTEGER PRIMARY KEY REFERENCES devices(id) ON DELETE CASCADE,
    name TEXT NOT NULL UNIQUE,
    custom INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE routes (
    device_id INTEGER NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    ingress TEXT NOT NULL,
    upstream TEXT NOT NULL,
    PRIMARY KEY (device_id, ingress)
);
CREATE INDEX assignments_device ON assignments(device_id);
CREATE TABLE activity_sessions (
    id INTEGER PRIMARY KEY,
    device_id INTEGER NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    started_at INTEGER NOT NULL,
    last_activity INTEGER NOT NULL,
    ended_at INTEGER,
    end_reason TEXT CHECK (end_reason IN ('inactivity', 'monitoring_gap')),
    CHECK (last_activity >= started_at),
    CHECK (ended_at IS NULL OR ended_at >= last_activity),
    CHECK ((ended_at IS NULL) = (end_reason IS NULL))
);
CREATE UNIQUE INDEX activity_open ON activity_sessions(device_id) WHERE ended_at IS NULL;
CREATE INDEX activity_history ON activity_sessions(device_id, started_at DESC);
CREATE INDEX activity_retention ON activity_sessions(ended_at) WHERE ended_at IS NOT NULL;
