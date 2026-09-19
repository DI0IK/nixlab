#!/usr/bin/env python3
import http.client
import json
import re
import socket
import sys
import urllib.error
import urllib.request

DOCKER_SOCKET = "/var/run/docker.sock"
ROUTER_API = "http://127.0.0.1:8081"
DOMAIN_ENV_KEY = "SERVER_DOMAIN"
BASE_DOMAIN_SUFFIX = ".dominikstahl.dev"  # Automatically append if only subdomain provided
FALLBACK_BACKEND = "127.0.0.1:25564"

class UnixHTTPConnection(http.client.HTTPConnection):
    def __init__(self, socket_path):
        super().__init__("localhost")
        self.socket_path = socket_path

    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(self.socket_path)

class DockerClient:
    def __init__(self, socket_path):
        self.socket_path = socket_path

    def request(self, method, path):
        conn = UnixHTTPConnection(self.socket_path)
        try:
            conn.request(method, path)
            resp = conn.getresponse()
            return resp.read()
        finally:
            conn.close()

    def stream_events(self):
        """Stream Docker events indefinitely."""
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect(self.socket_path)
        req = (
            "GET /events?filters=%7B%22type%22%3A%5B%22container%22%5D%7D HTTP/1.1\r\n"
            "Host: localhost\r\nConnection: keep-alive\r\n\r\n"
        )
        sock.sendall(req.encode("utf-8"))

        buffer = ""
        while True:
            chunk = sock.recv(4096).decode("utf-8", errors="ignore")
            if not chunk:
                break
            buffer += chunk
            while "\r\n" in buffer:
                line, buffer = buffer.split("\r\n", 1)
                line = line.strip()
                if line and not re.match(r"^[0-9a-fA-F]+$", line):  # Skip chunk-encoding headers
                    try:
                        yield json.loads(line)
                    except json.JSONDecodeError:
                        continue

docker = DockerClient(DOCKER_SOCKET)

def router_request(path, method="GET", payload=None):
    url = f"{ROUTER_API}{path}"
    data = json.dumps(payload).encode("utf-8") if payload else None
    headers = {"Content-Type": "application/json"} if data else {}
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status in (200, 201, 204)
    except urllib.error.URLError as e:
        print(f"[ERROR] Failed {method} {url}: {e}", file=sys.stderr)
        return False

def get_container_info(container_id):
    try:
        raw = docker.request("GET", f"/containers/{container_id}/json")
        return json.loads(raw.decode("utf-8"))
    except Exception as e:
        print(f"[ERROR] Inspect failed for {container_id}: {e}", file=sys.stderr)
        return None

def extract_route_metadata(info):
    if not info:
        return None, None

    # 1. Look for SERVER_DOMAIN in container env
    env_vars = info.get("Config", {}).get("Env", [])
    domain = None
    for entry in env_vars:
        if entry.startswith(f"{DOMAIN_ENV_KEY}="):
            domain = entry.split("=", 1)[1].strip()
            break

    if not domain:
        return None, None

    if "." not in domain:
        domain = f"{domain}{BASE_DOMAIN_SUFFIX}"

    # 2. Look for primary Minecraft port mapping (Wings binds container 25565 to an external host port)
    port_bindings = info.get("NetworkSettings", {}).get("Ports", {})
    host_port = None
    host_ip = "127.0.0.1"

    for container_port, bindings in port_bindings.items():
        if container_port.startswith("25565/") and bindings:
            host_port = bindings[0].get("HostPort")
            ip = bindings[0].get("HostIp")
            if ip and ip != "0.0.0.0":
                host_ip = ip
            break

    # Fallback: take the first available mapped TCP port
    if not host_port:
        for _, bindings in port_bindings.items():
            if bindings and bindings[0].get("HostPort"):
                host_port = bindings[0].get("HostPort")
                ip = bindings[0].get("HostIp")
                if ip and ip != "0.0.0.0":
                    host_ip = ip
                break

    if not host_port:
        return None, None

    return domain, f"{host_ip}:{host_port}"

def sync_all_running():
    print("[INFO] Reconciling default fallback route and running containers...")
    router_request("/defaultRoute", method="POST", payload={"backend": FALLBACK_BACKEND})
    try:
        raw = docker.request("GET", "/containers/json")
        containers = json.loads(raw.decode("utf-8"))
        for c in containers:
            domain, target = extract_route_metadata(get_container_info(c["Id"]))
            if domain and target:
                print(f"[SYNC] Mapping {domain} -> {target}")
                router_request("/routes", method="POST", payload={
                    "serverAddress": domain,
                    "backend": target
                })
    except Exception as e:
        print(f"[WARN] Initial reconciliation failed: {e}", file=sys.stderr)

def main():
    sync_all_running()
    print("[INFO] Listening to Docker event stream...")

    for event in docker.stream_events():
        action = event.get("Action")
        container_id = event.get("id") or event.get("Actor", {}).get("ID")
        if not container_id:
            continue

        if action == "start":
            info = get_container_info(container_id)
            domain, target = extract_route_metadata(info)
            if domain and target:
                print(f"[EVENT] Container started: Registering {domain} -> {target}")
                router_request("/routes", method="POST", payload={
                    "serverAddress": domain,
                    "backend": target
                })

        elif action in ("die", "stop", "destroy"):
            attributes = event.get("Actor", {}).get("Attributes", {})
            domain = attributes.get(f"env:{DOMAIN_ENV_KEY}")
            if domain:
                if "." not in domain:
                    domain = f"{domain}{BASE_DOMAIN_SUFFIX}"
                print(f"[EVENT] Container stopped: Deregistering {domain}")
                router_request(f"/routes/{domain}", method="DELETE")

if __name__ == "__main__":
    main()
