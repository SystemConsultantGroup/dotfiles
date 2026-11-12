# Activity webhooks

The portal is reachable only through the existing LAN/Mesh networks. This API
adds no public listener, DNS record, tunnel, or firewall exception.

All timestamps below are integer Unix milliseconds, compatible with `Date.now()`.
Storage currently has second precision. Duration units are explicit in field
names. Existing `/api/me` responses remain unchanged, including their seconds-based
timestamps.

## Subscription management

These routes identify the requesting device through its controller-resolved LAN
MAC binding (`office` devices). Mesh/IP-only devices cannot manage subscriptions.
Never send a device ID or MAC. A neighbor MAC is an identity hint within the
existing trusted LAN model, not protection against a hostile LAN participant.

Writes require `Content-Type: application/json` and an `Origin` header matching
`https://router.scg.sh`, as with the existing self-service API. Cross-site browser
API requests are forbidden.

### POST /api/me/activity/webhooks

Request:

```json
{"url":"https://example.com/hooks/activity/local-registration-id"}
```

The URL must be HTTPS, without user information or a fragment. Verification and
every subsequent delivery resolve DNS afresh, reject non-public destinations,
and pin the validated addresses to the connection. Redirects and environment HTTP
proxies are disabled. Callback URLs are limited to 2048 bytes. Private/LAN callback
destinations are deliberately unsupported even though reads require LAN/Mesh
connectivity.

The router first POSTs JSON to the callback:

```json
{"type":"verify","id":"<token>"}
```

The endpoint must store the ID, then respond within five seconds with HTTP 200
and a JSON body echoing it:

```json
{"id":"<token>"}
```

The entire verification, including DNS, must complete within five seconds. The
response body is limited to 1024 bytes. Failed verification cancels registration.
Pending tokens cannot read activity and abandoned pending registrations expire.

Successful registration returns HTTP 201:

```json
{"id":"<token>"}
```

The token is 32 cryptographically random bytes encoded as 64 lowercase hex
characters. It is a bearer credential, not a public device identifier.

An identical URL already active for this device returns the same ID with HTTP
200. Concurrent registration while verification is pending returns HTTP 409.
Each device may have up to 16 subscriptions, including pending registrations.

### GET /api/me/activity/webhooks

Returns only this device's active subscriptions:

```json
[{"id":"<token>","url":"https://example.com/hooks/activity/local-registration-id","created_at":1775044800000}]
```

### DELETE /api/me/activity/webhooks/<token>

Returns HTTP 204. The requesting device must own the subscription. Deletion
immediately revokes reads and cancels queued notifications; an already in-flight
callback can still arrive. Unknown or unowned subscriptions return HTTP 404.

## Notifications

After activation, the router sends an initial empty POST to the callback, then
another when `status` changes. Updates to `last_activity` alone do not notify.
The receiver maps its callback URL to the token saved during verification; use a
distinct local callback URL for each subscription.

Any 2xx response acknowledges an empty notification. Failures retry with
exponential backoff starting at five seconds and capped at one hour, up to 12
failed attempts for a queued status. A subsequent status change resets retries.
One durable pending notification per subscription coalesces changes and bounds
queue storage. Work survives process restarts. Notifications may be duplicated.

Notifications carry no signature or trusted data. Treat them only as refresh
hints, debounce/rate-limit fetches, and trust the fetched HTTPS response. This is
not a transition log: several changes before a fetch may yield only the latest
status.

## Capability reads

The following routes are available to LAN/Mesh callers possessing an active
subscription token. No additional headers, cookies, or signatures authorize the
read. Tokens grant access only to their device's activity, never its identity or
network settings. Keep tokens out of logs, analytics, and error reports. The
server does not log request URLs or callback failures containing credentials.
All responses use `Cache-Control: no-store`.

### GET /api/activity/<token>

```json
{
  "status":"online",
  "warning":null,
  "last_activity":1775045070000,
  "session_started_at":1775044800000,
  "idle_seconds":300,
  "retention_days":30,
  "sampled_at":1775045075000
}
```

- `status`: existing values `online`, `offline`, or `unknown`.
- `warning`: monitoring warning, or null.
- `last_activity`: last retained observed activity, or null if none is known.
- `session_started_at`: current session start, or null if none is known.
- `sampled_at`: last successful collector snapshot time, or null before the first
  successful snapshot in this controller process. It is not the HTTP request time.

Activity is sampled every 15 seconds. Monitoring failures produce `unknown`, not
`offline`. Activity is network traffic, not proof of human presence or screen use.

### GET /api/activity/<token>/sessions

Optional query parameters:

- `from`: inclusive lower time bound, default 0.
- `to`: exclusive upper time bound, default request time.
- `limit`: default 50, minimum 1, maximum 100.
- `cursor`: continuation cursor from the previous response; keep the same filters.

Sessions overlapping `[from, to)` are newest first, with ID as a stable tie-breaker.
Timestamps are actual session timestamps, not clipped to the query range.

```json
{
  "sessions":[{
    "started_at":1775044800000,
    "last_activity":1775045070000,
    "ended_at":null,
    "end_reason":null
  }],
  "next_cursor":null,
  "sampled_at":1775045075000,
  "retention_days":30
}
```

`end_reason` is `inactivity`, `monitoring_gap`, or null for an open session. An
inactivity-ended session includes its configured idle window. A monitoring gap
closes the session at the last evidence of activity instead of counting an outage.
Pages are live views, not a frozen historical snapshot. Set an explicit `to` for
more stable pagination.

### GET /api/activity/<token>/summary?from=<ms>&to=<ms>

Both bounds are required; pagination parameters are unsupported.

```json
{
  "from":1775001600000,
  "to":1775088000000,
  "total_ms":7200000,
  "sampled_at":1775088005000,
  "retention_days":30,
  "warning":null
}
```

`total_ms` sums retained activity-session duration overlapping `[from, to)`.
Open sessions are capped at the last successful observation; completed sessions
use their recorded end. Millisecond query bounds are applied without rounding.

This is not a coverage report: absent history, retention expiry, and monitoring
gaps are not confirmed offline time. The database does not persist a complete
monitoring-availability timeline. Only retained records contribute to the total.

## Errors

Errors are JSON, for example `{"error":"Callback verification failed"}`.

| Status | Meaning |
| --- | --- |
| 400 | Invalid registration body, URL syntax, or activity query |
| 403 | Source cannot use the portal, or management caller is not a MAC-bound LAN device |
| 404 | Unknown resource, unowned subscription, or unknown/pending/revoked token |
| 409 | Verification already pending, subscription limit, or device-binding conflict |
| 422 | Callback verification failed |
| 500 | Internal database or activity-query failure |
| 503 | Controller or device identity resolution temporarily unavailable |

## Implementation and recovery

The controller remains the sole SQLite owner. Session checkpoints and queued
status notifications are committed together. Verification and callback delivery
run in the unprivileged HTTPS process and never block the controller on remote
HTTP requests.

Schema migration from version 1 or 2 creates a private SQLite backup before
migration. Rolling back to a backend that supports only schema 2 requires stopping
the controller and restoring the pre-migration database backup; do not attempt to
run the old controller against schema 3.
