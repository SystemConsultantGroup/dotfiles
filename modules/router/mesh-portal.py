#!/usr/bin/env python3
"""Self-service selection of DHCP clients routed through Cloudflare Mesh."""

import argparse
import http.cookies
import http.server
import ipaddress
import json
import logging
import os
import pathlib
import re
import secrets
import socket
import socketserver
import subprocess
import tempfile
from typing import Any

MAX_REQUEST = 4096
MAC_RE = re.compile(r"^[0-9a-f]{2}(?::[0-9a-f]{2}){5}$")


class PortalError(Exception):
    def __init__(self, status: int, message: str):
        super().__init__(message)
        self.status = status
        self.message = message


def read_json_request(connection: socket.socket) -> dict[str, Any]:
    data = bytearray()
    while len(data) <= MAX_REQUEST:
        chunk = connection.recv(MAX_REQUEST + 1 - len(data))
        if not chunk:
            break
        data.extend(chunk)
        if b"\n" in chunk:
            break
    if len(data) > MAX_REQUEST:
        raise PortalError(400, "Request is too large")
    try:
        value = json.loads(bytes(data).split(b"\n", 1)[0])
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        raise PortalError(400, "Invalid request") from error
    if not isinstance(value, dict):
        raise PortalError(400, "Invalid request")
    return value


def send_json(connection: socket.socket, value: dict[str, Any]) -> None:
    connection.sendall(json.dumps(value, separators=(",", ":")).encode() + b"\n")


class RoutingState:
    def __init__(self, state_file: pathlib.Path, lease_file: pathlib.Path, lan_cidr: str):
        self.state_file = state_file
        self.lease_file = lease_file
        self.lan = ipaddress.IPv4Network(lan_cidr)
        self.enabled_macs: set[str] = set()
        self.last_addresses: set[str] = set()
        self.load()

    def load(self) -> None:
        try:
            value = json.loads(self.state_file.read_text())
            macs = value.get("enabled_macs", [])
            if not isinstance(macs, list):
                raise ValueError("enabled_macs is not a list")
            self.enabled_macs = {
                str(mac).lower() for mac in macs if MAC_RE.fullmatch(str(mac).lower())
            }
        except FileNotFoundError:
            self.enabled_macs = set()
        except (json.JSONDecodeError, OSError, ValueError) as error:
            raise RuntimeError(f"Cannot load {self.state_file}: {error}") from error

    def save(self) -> None:
        self.state_file.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        descriptor, temporary_name = tempfile.mkstemp(
            dir=self.state_file.parent, prefix="clients.", suffix=".json"
        )
        try:
            with os.fdopen(descriptor, "w") as temporary:
                json.dump({"enabled_macs": sorted(self.enabled_macs)}, temporary)
                temporary.write("\n")
                temporary.flush()
                os.fsync(temporary.fileno())
            os.chmod(temporary_name, 0o600)
            os.replace(temporary_name, self.state_file)
        except BaseException:
            try:
                os.unlink(temporary_name)
            except FileNotFoundError:
                pass
            raise

    def leases(self) -> dict[str, tuple[str, str]]:
        leases: dict[str, tuple[str, str]] = {}
        try:
            lines = self.lease_file.read_text().splitlines()
        except FileNotFoundError:
            return leases
        for line in lines:
            fields = line.split()
            if len(fields) < 4:
                continue
            mac = fields[1].lower()
            try:
                address = ipaddress.IPv4Address(fields[2])
            except ipaddress.AddressValueError:
                continue
            if MAC_RE.fullmatch(mac) and address in self.lan:
                hostname = "" if fields[3] == "*" else fields[3]
                leases[str(address)] = (mac, hostname)
        return leases

    def client(self, address_text: str) -> tuple[str, str, str]:
        try:
            address = ipaddress.IPv4Address(address_text)
        except ipaddress.AddressValueError as error:
            raise PortalError(400, "Invalid client address") from error
        if address not in self.lan:
            raise PortalError(403, "The portal is only available to LAN clients")
        lease = self.leases().get(str(address))
        if lease is None:
            raise PortalError(403, "No active DHCP lease was found for this device")
        mac, hostname = lease
        return str(address), mac, hostname

    def sync_nft(self, force: bool = False) -> None:
        addresses = {
            address
            for address, (mac, _hostname) in self.leases().items()
            if mac in self.enabled_macs
        }
        if not force and addresses == self.last_addresses:
            return
        rules = "flush set ip mesh_policy clients\n"
        if addresses:
            elements = "{ " + ", ".join(sorted(addresses)) + " }"
            rules += f"add element ip mesh_policy clients {elements}\n"
        subprocess.run(["nft", "-f", "-"], input=rules, text=True, check=True)
        self.last_addresses = addresses

    def handle(self, request: dict[str, Any]) -> dict[str, Any]:
        operation = request.get("operation")
        address, mac, hostname = self.client(str(request.get("address", "")))
        if operation == "set":
            enabled = request.get("enabled")
            if not isinstance(enabled, bool):
                raise PortalError(400, "enabled must be a boolean")
            if enabled:
                self.enabled_macs.add(mac)
            else:
                self.enabled_macs.discard(mac)
            self.save()
            self.sync_nft(force=True)
        elif operation != "status":
            raise PortalError(400, "Unknown operation")
        return {
            "ok": True,
            "address": address,
            "hostname": hostname,
            "enabled": mac in self.enabled_macs,
        }


def run_control(args: argparse.Namespace) -> None:
    socket_path = pathlib.Path(args.socket)
    socket_path.unlink(missing_ok=True)
    state = RoutingState(
        pathlib.Path(args.state_file), pathlib.Path(args.lease_file), args.lan_cidr
    )
    state.sync_nft(force=True)

    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
        server.bind(str(socket_path))
        os.chmod(socket_path, 0o660)
        server.listen(16)
        server.settimeout(10)
        while True:
            try:
                connection, _ = server.accept()
            except TimeoutError:
                state.sync_nft()
                continue
            with connection:
                try:
                    send_json(connection, state.handle(read_json_request(connection)))
                except PortalError as error:
                    send_json(
                        connection,
                        {"ok": False, "status": error.status, "error": error.message},
                    )
                except Exception:
                    logging.exception("Mesh routing control request failed")
                    send_json(
                        connection,
                        {"ok": False, "status": 500, "error": "Internal error"},
                    )


def control_request(socket_path: str, request: dict[str, Any]) -> dict[str, Any]:
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
            connection.settimeout(5)
            connection.connect(socket_path)
            send_json(connection, request)
            response = read_json_request(connection)
    except OSError as error:
        raise PortalError(503, "Routing control is temporarily unavailable") from error
    if not response.get("ok"):
        raise PortalError(int(response.get("status", 500)), str(response.get("error")))
    return response


PAGE = """<!doctype html>
<html lang=en>
<meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1">
<title>SCG Router</title>
<style>
:root { color-scheme: light dark; font: 16px system-ui, sans-serif; }
body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #111827; color: #f9fafb; }
main { width: min(32rem, calc(100% - 3rem)); padding: 2rem; border: 1px solid #374151; border-radius: 1rem; background: #1f2937; box-shadow: 0 1rem 3rem #0006; }
h1 { margin-top: 0; } p { color: #d1d5db; line-height: 1.5; }
button { width: 100%; padding: .9rem; border: 0; border-radius: .6rem; font: inherit; font-weight: 700; cursor: pointer; }
button.on { background: #dc2626; color: white; } button.off { background: #22c55e; color: #052e16; }
button:disabled { opacity: .55; cursor: wait; }
#message { min-height: 1.5rem; } code { color: #93c5fd; }
</style>
<main>
<h1>Cloudflare Mesh</h1>
<p id=device>Checking this device…</p>
<p id=message></p>
<button id=toggle disabled>Loading…</button>
</main>
<script>
const button = document.querySelector('#toggle');
const device = document.querySelector('#device');
const message = document.querySelector('#message');
const csrf = document.cookie.split('; ').find(v => v.startsWith('csrf='))?.split('=')[1];
let enabled = false;
function render(data) {
  enabled = data.enabled;
  device.textContent = `${data.hostname || 'This device'} (${data.address})`;
  message.textContent = enabled ? 'Internet traffic is routed through Cloudflare Mesh.' : 'Internet traffic uses the normal router WAN.';
  button.textContent = enabled ? 'Use normal WAN' : 'Use Cloudflare Mesh';
  button.className = enabled ? 'on' : 'off';
  button.disabled = false;
}
async function request(path, options = {}) {
  const response = await fetch(path, {cache: 'no-store', ...options});
  const data = await response.json();
  if (!response.ok) throw new Error(data.error || 'Request failed');
  return data;
}
request('/api/status').then(render).catch(error => { message.textContent = error.message; });
button.addEventListener('click', async () => {
  button.disabled = true;
  try {
    render(await request('/api/toggle', {method: 'POST', headers: {'Content-Type': 'application/json', 'X-CSRF-Token': csrf}, body: JSON.stringify({enabled: !enabled})}));
  } catch (error) {
    message.textContent = error.message;
    button.disabled = false;
  }
});
</script>
"""


class UnixHTTPServer(socketserver.UnixStreamServer):
    allow_reuse_address = True

    def server_bind(self) -> None:
        pathlib.Path(self.server_address).unlink(missing_ok=True)
        super().server_bind()
        os.chmod(self.server_address, 0o660)


class PortalHandler(http.server.BaseHTTPRequestHandler):
    server_version = "mesh-portal"

    def log_message(self, fmt: str, *values: object) -> None:
        print(f"portal - {fmt % values}")

    def request_address(self) -> str:
        value = self.headers.get("X-Real-IP", "")
        try:
            return str(ipaddress.IPv4Address(value))
        except ipaddress.AddressValueError as error:
            raise PortalError(400, "Invalid client address") from error

    def reply_json(self, status: int, value: dict[str, Any]) -> None:
        body = json.dumps(value, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def backend(self, operation: str, enabled: bool | None = None) -> dict[str, Any]:
        request: dict[str, Any] = {
            "operation": operation,
            "address": self.request_address(),
        }
        if enabled is not None:
            request["enabled"] = enabled
        return control_request(self.server.control_socket, request)  # type: ignore[attr-defined]

    def do_GET(self) -> None:
        try:
            if self.path == "/":
                token = secrets.token_urlsafe(32)
                body = PAGE.encode()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.send_header("Cache-Control", "no-store")
                self.send_header(
                    "Set-Cookie", f"csrf={token}; Path=/; Secure; SameSite=Strict"
                )
                self.send_header(
                    "Content-Security-Policy",
                    "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'",
                )
                self.send_header("X-Content-Type-Options", "nosniff")
                self.end_headers()
                self.wfile.write(body)
            elif self.path == "/api/status":
                self.reply_json(200, self.backend("status"))
            else:
                self.reply_json(404, {"error": "Not found"})
        except PortalError as error:
            self.reply_json(error.status, {"error": error.message})

    def do_POST(self) -> None:
        try:
            if self.path != "/api/toggle":
                raise PortalError(404, "Not found")
            origin = self.headers.get("Origin")
            if origin != "https://router.scg.sh":
                raise PortalError(403, "Invalid request origin")
            cookies = http.cookies.SimpleCookie(self.headers.get("Cookie", ""))
            cookie = cookies.get("csrf")
            supplied = self.headers.get("X-CSRF-Token", "")
            if cookie is None or not secrets.compare_digest(cookie.value, supplied):
                raise PortalError(403, "Invalid CSRF token")
            try:
                length = int(self.headers.get("Content-Length", "0"))
            except ValueError as error:
                raise PortalError(400, "Invalid request") from error
            if length < 1 or length > MAX_REQUEST:
                raise PortalError(400, "Invalid request")
            try:
                request = json.loads(self.rfile.read(length))
            except (json.JSONDecodeError, UnicodeDecodeError) as error:
                raise PortalError(400, "Invalid request") from error
            enabled = request.get("enabled") if isinstance(request, dict) else None
            if not isinstance(enabled, bool):
                raise PortalError(400, "enabled must be a boolean")
            self.reply_json(200, self.backend("set", enabled))
        except PortalError as error:
            self.reply_json(error.status, {"error": error.message})


def run_web(args: argparse.Namespace) -> None:
    with UnixHTTPServer(args.socket, PortalHandler) as server:
        server.control_socket = args.control_socket
        server.serve_forever()


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="mode", required=True)

    control = subparsers.add_parser("control")
    control.add_argument("--socket", required=True)
    control.add_argument("--state-file", required=True)
    control.add_argument("--lease-file", required=True)
    control.add_argument("--lan-cidr", required=True)
    control.set_defaults(function=run_control)

    web = subparsers.add_parser("web")
    web.add_argument("--socket", required=True)
    web.add_argument("--control-socket", required=True)
    web.set_defaults(function=run_web)

    args = parser.parse_args()
    args.function(args)


if __name__ == "__main__":
    main()
