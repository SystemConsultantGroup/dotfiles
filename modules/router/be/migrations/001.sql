PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS assignments (
    ip TEXT PRIMARY KEY,
    kind TEXT NOT NULL CHECK (kind IN ('office', 'mesh')),
    generation TEXT NOT NULL,
    reported_name TEXT,
    expires INTEGER
);
CREATE TABLE IF NOT EXISTS names (
    ip TEXT PRIMARY KEY REFERENCES assignments(ip) ON DELETE CASCADE,
    name TEXT NOT NULL UNIQUE,
    custom INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS routes (
    ip TEXT NOT NULL REFERENCES assignments(ip) ON DELETE CASCADE,
    ingress TEXT NOT NULL,
    upstream TEXT NOT NULL,
    PRIMARY KEY (ip, ingress)
);
PRAGMA user_version = 1;
