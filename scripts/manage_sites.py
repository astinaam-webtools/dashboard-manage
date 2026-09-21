#!/usr/bin/env python3
"""
manage_sites.py - Manage services displayed on the Port 80 Web Services Dashboard.
Supports adding, updating, listing, removing, and health-checking services.
"""

import argparse
import http.server
import json
import os
import re
import socket
import subprocess
import sys
import threading
import time
import urllib.request
from typing import Dict, Any, List, Optional

CATEGORIES = ["apps", "ai", "games", "media", "utilities", "apis"]

CONFIG_DIR_USER = os.path.expanduser("~/.config/dashboard-manage")
CONFIG_FILE_USER = os.path.join(CONFIG_DIR_USER, "config.json")
CONFIG_FILE_SYSTEM = "/etc/dashboard-manage/config.json"


def detect_lan_ip() -> str:
    """Auto-detect primary outbound LAN IP."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("1.1.1.1", 80))
            return s.getsockname()[0]
    except Exception:
        pass
    try:
        host = socket.gethostname()
        return f"{host}.local"
    except Exception:
        return "127.0.0.1"


def detect_tailscale_host() -> Optional[str]:
    """Auto-detect Tailscale MagicDNS hostname if Tailscale is running."""
    try:
        res = subprocess.run(
            ["tailscale", "status", "--json"],
            capture_output=True,
            text=True,
            timeout=2
        )
        if res.returncode == 0:
            data = json.loads(res.stdout)
            dns = data.get("Self", {}).get("DNSName", "").rstrip(".")
            if dns:
                return dns
    except Exception:
        pass
    return None


def detect_tailscale_ip() -> Optional[str]:
    """Auto-detect Tailscale IPv4 address if Tailscale is running."""
    try:
        res = subprocess.run(
            ["tailscale", "ip", "-4"],
            capture_output=True,
            text=True,
            timeout=2
        )
        if res.returncode == 0:
            ip = res.stdout.strip().split("\n")[0].strip()
            if ip:
                return ip
    except Exception:
        pass
    return None


def load_config() -> Dict[str, Any]:
    """Load configuration from config file or environment, with intelligent fallbacks."""
    config_path = os.environ.get("DASHBOARD_CONFIG_FILE")
    cfg = {}

    paths_to_try = []
    if config_path:
        paths_to_try.append(config_path)
    paths_to_try.extend([CONFIG_FILE_USER, CONFIG_FILE_SYSTEM])

    for p in paths_to_try:
        if os.path.isfile(p):
            try:
                with open(p, "r", encoding="utf-8") as f:
                    cfg = json.load(f)
                    break
            except Exception as e:
                print(f"Warning: Failed to read config {p}: {e}", file=sys.stderr)

    auto_detect = cfg.get("auto_detect", True)
    detected_lan = detect_lan_ip() if auto_detect else "127.0.0.1"
    detected_ts_host = detect_tailscale_host() if auto_detect else None
    detected_ts_ip = detect_tailscale_ip() if auto_detect else None

    web_dir = (
        os.environ.get("DASHBOARD_WEB_DIR")
        or cfg.get("web_dir")
        or "/var/www/html"
    )

    lan_host = (
        os.environ.get("DASHBOARD_LAN_HOST")
        or cfg.get("lan_host")
        or detected_lan
    )

    tailscale_host = (
        os.environ.get("DASHBOARD_TAILSCALE_HOST")
        or cfg.get("tailscale_host")
        or detected_ts_host
        or f"{socket.gethostname()}.tailnet.ts.net"
    )

    tailscale_ip = (
        os.environ.get("DASHBOARD_TAILSCALE_IP")
        or cfg.get("tailscale_ip")
        or detected_ts_ip
        or "100.64.0.1"
    )

    port = int(
        os.environ.get("DASHBOARD_PORT")
        or cfg.get("port")
        or 8080
    )

    return {
        "web_dir": web_dir,
        "port": port,
        "lan_host": lan_host,
        "tailscale_host": tailscale_host,
        "tailscale_ip": tailscale_ip,
        "services_json": os.path.join(web_dir, "services.json"),
        "status_json": os.path.join(web_dir, "status.json"),
        "index_html": os.path.join(web_dir, "index.html"),
    }


def save_user_config(new_values: Dict[str, Any]) -> str:
    """Save user configuration to ~/.config/dashboard-manage/config.json."""
    os.makedirs(CONFIG_DIR_USER, exist_ok=True)
    current = {}
    if os.path.isfile(CONFIG_FILE_USER):
        try:
            with open(CONFIG_FILE_USER, "r", encoding="utf-8") as f:
                current = json.load(f)
        except Exception:
            current = {}

    current.update(new_values)
    with open(CONFIG_FILE_USER, "w", encoding="utf-8") as f:
        json.dump(current, f, indent=2)
    return CONFIG_FILE_USER


def load_services(config: Dict[str, Any]) -> List[Dict[str, Any]]:
    path = config["services_json"]
    if not os.path.exists(path):
        return []
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"Error reading {path}: {e}", file=sys.stderr)
        return []


def save_services(services: List[Dict[str, Any]], config: Dict[str, Any]) -> None:
    path = config["services_json"]
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(services, f, indent=2, ensure_ascii=False)
    print(f"Saved {len(services)} services to {path}")
    sync_index_html(services, config)


def check_single_service(service: Dict[str, Any]) -> str:
    port = service.get("port")
    path = service.get("path", "/")

    # If it's a subpath on port 80 (e.g. /games/ or /printer/)
    if port in (80, "80"):
        url = f"http://127.0.0.1{path}"
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "HubHealth/1.0"}, method="HEAD")
            with urllib.request.urlopen(req, timeout=1.5) as resp:
                return "online" if resp.status < 500 else "offline"
        except urllib.error.HTTPError as e:
            return "online" if e.code < 500 else "offline"
        except Exception:
            return "offline"

    # For standard ports, probe TCP socket
    try:
        port_int = int(port)
        with socket.create_connection(("127.0.0.1", port_int), timeout=1.0):
            return "online"
    except Exception:
        return "offline"


def run_health_check(config: Dict[str, Any]) -> Dict[str, str]:
    services = load_services(config)
    results = {}
    for s in services:
        sid = s.get("id")
        if not sid:
            continue
        results[sid] = check_single_service(s)

    status_data = {
        "updated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "statuses": results
    }
    path = config["status_json"]
    try:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(status_data, f, indent=2)
    except Exception as e:
        print(f"Warning: Failed to write {path}: {e}", file=sys.stderr)
    return results


def sync_index_html(services: List[Dict[str, Any]], config: Dict[str, Any]) -> None:
    """Updates the embedded fallback JSON dataset inside index.html if it exists."""
    path = config["index_html"]
    if not os.path.exists(path):
        return
    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()

        pattern = r'(<script\s+id="initial-services"\s+type="application/json">)(.*?)(</script>)'
        replacement = r'\g<1>\n' + json.dumps(services, indent=2, ensure_ascii=False) + r'\n\g<3>'

        new_content, count = re.subn(pattern, replacement, content, flags=re.DOTALL)
        if count > 0:
            with open(path, "w", encoding="utf-8") as f:
                f.write(new_content)
            print("Successfully updated embedded fallback data in index.html")
    except Exception as e:
        print(f"Note: Embedded sync in index.html skipped: {e}", file=sys.stderr)


def cmd_list(args, config):
    services = load_services(config)
    if not services:
        print(f"No services registered in {config['services_json']}.")
        return

    statuses = {}
    if args.check:
        print("Checking live service statuses...")
        statuses = run_health_check(config)
    elif os.path.exists(config["status_json"]):
        try:
            with open(config["status_json"], "r") as f:
                statuses = json.load(f).get("statuses", {})
        except Exception:
            pass

    print(f"\n{'ID':<18} {'PORT':<8} {'STATUS':<8} {'CATEGORY':<12} {'NAME'}")
    print("-" * 68)
    for s in services:
        sid = s.get("id", "")
        port = str(s.get("port", ""))
        cat = s.get("category", "")
        name = s.get("name", "")
        status = statuses.get(sid, "unknown")
        print(f"{sid:<18} {port:<8} {status:<8} {cat:<12} {name}")
    print(f"\nTotal: {len(services)} services ({config['services_json']})")


def cmd_add(args, config):
    services = load_services(config)
    sid = args.id.strip().lower()

    if any(s.get("id") == sid for s in services):
        print(f"Error: Service with id '{sid}' already exists. Use remove first or pick a unique id.", file=sys.stderr)
        sys.exit(1)

    path = args.path if args.path.startswith("/") else "/" + args.path
    protocol = args.protocol.lower()

    lan_host = args.lan_host or config["lan_host"]
    tailscale_host = args.tailscale_host or config["tailscale_host"]
    tailscale_ip = config["tailscale_ip"]

    # Generate URLs
    if args.lan_url:
        lan_url = args.lan_url
    else:
        if args.port == 80 and path != "/":
            lan_url = f"{protocol}://{lan_host}{path}"
        elif args.port == 80:
            lan_url = f"{protocol}://{lan_host}/"
        else:
            lan_url = f"{protocol}://{lan_host}:{args.port}{path}"

    if args.tailscale_url:
        tailscale_url = args.tailscale_url
    else:
        if args.tailscale_port:
            tailscale_url = f"https://{tailscale_host}:{args.tailscale_port}{path}"
        elif args.port == 80:
            tailscale_url = f"https://{tailscale_host}{path}"
        else:
            tailscale_url = f"{protocol}://{tailscale_host}:{args.port}{path}"

    new_service = {
        "id": sid,
        "name": args.name,
        "description": args.desc,
        "category": args.category,
        "port": args.port,
        "path": path,
        "protocol": protocol,
        "lan_url": lan_url,
        "tailscale_url": tailscale_url,
        "tailscale_ip_url": f"{protocol}://{tailscale_ip}:{args.port}{path}" if args.port != 80 else f"https://{tailscale_host}{path}",
        "badge": args.badge or (f"Port {args.port}" if args.port != 80 else "Port 80"),
        "icon": args.icon or "globe"
    }

    services.append(new_service)
    save_services(services, config)
    run_health_check(config)
    print(f"Added service '{args.name}' ({sid}) successfully.")


def cmd_remove(args, config):
    services = load_services(config)
    sid = args.id.strip().lower()
    initial_len = len(services)
    services = [s for s in services if s.get("id") != sid]

    if len(services) == initial_len:
        print(f"No service found with id '{sid}'.", file=sys.stderr)
        sys.exit(1)

    save_services(services, config)
    run_health_check(config)
    print(f"Removed service '{sid}' successfully.")


def cmd_check(args, config):
    print("Running health checks on all registered services...")
    results = run_health_check(config)
    online_count = sum(1 for v in results.values() if v == "online")
    print(f"Status check completed: {online_count}/{len(results)} online.")
    for sid, status in results.items():
        symbol = "🟢" if status == "online" else "🔴"
        print(f"  {symbol} {sid}: {status}")


def cmd_sync(args, config):
    services = load_services(config)
    save_services(services, config)
    run_health_check(config)
    print("Synchronization complete.")


def cmd_config(args, config):
    if args.action == "show":
        print("\n⚙️  Current Dashboard Configuration:")
        print("-" * 50)
        for k, v in config.items():
            print(f"  {k:<16}: {v}")
        print()
    elif args.action == "set":
        updates = {}
        if args.lan_host:
            updates["lan_host"] = args.lan_host
        if args.tailscale_host:
            updates["tailscale_host"] = args.tailscale_host
        if args.tailscale_ip:
            updates["tailscale_ip"] = args.tailscale_ip
        if args.web_dir:
            updates["web_dir"] = args.web_dir

        if not updates:
            print("No configuration options specified to set.")
            return

        cfg_file = save_user_config(updates)
        print(f"Saved configuration updates to {cfg_file}:")
        for k, v in updates.items():
            print(f"  {k} -> {v}")


def create_request_handler(web_dir: str):
    class DashboardHTTPHandler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=web_dir, **kwargs)

        def end_headers(self):
            # Disable caching for JSON files so updates to services/status are immediately reflected
            if self.path.endswith(".json") or "?" in self.path:
                self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
                self.send_header("Pragma", "no-cache")
                self.send_header("Expires", "0")
            super().end_headers()

        def log_message(self, format, *args):
            sys.stderr.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {format % args}\n")

    return DashboardHTTPHandler


def cmd_serve(args, config):
    web_dir = args.web_dir or config.get("web_dir") or "/var/www/html"
    port = args.port or config.get("port") or 8080
    host = args.host or "0.0.0.0"

    if not os.path.exists(web_dir):
        print(f"Error: Web directory '{web_dir}' does not exist.", file=sys.stderr)
        sys.exit(1)

    # Initial health check run
    try:
        run_health_check(config)
    except Exception as e:
        print(f"Warning: Initial health check failed: {e}", file=sys.stderr)

    # Background health check thread
    def health_worker():
        while True:
            time.sleep(60)
            try:
                run_health_check(config)
            except Exception as ex:
                print(f"Warning: Periodic health check error: {ex}", file=sys.stderr)

    worker_thread = threading.Thread(target=health_worker, daemon=True)
    worker_thread.start()

    handler_class = create_request_handler(web_dir)
    try:
        server = http.server.ThreadingHTTPServer((host, port), handler_class)
    except Exception as e:
        print(f"Error starting server on {host}:{port}: {e}", file=sys.stderr)
        sys.exit(1)

    lan_ip = config.get("lan_host", "localhost")
    print(f"\n⚡ Services Dashboard running on http://{host}:{port}/")
    print(f"📁 Web Directory: {web_dir}")
    print(f"🏠 Local LAN: http://{lan_ip}:{port}/")
    if config.get("tailscale_host"):
        print(f"🌐 Tailscale: http://{config['tailscale_host']}:{port}/")
    print("Press Ctrl+C to stop.\n")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping dashboard server...")
    finally:
        server.server_close()


def main():
    config = load_config()

    parser = argparse.ArgumentParser(
        prog="dashboard-manage",
        description="Services Dashboard Manager - Register and inspect hosted web services & ports"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # serve
    p_serve = subparsers.add_parser("serve", help="Start local web server for the dashboard")
    p_serve.add_argument("--port", type=int, default=8080, help="Port to bind (default: 8080)")
    p_serve.add_argument("--host", default="0.0.0.0", help="Host interface to bind (default: 0.0.0.0)")
    p_serve.add_argument("--web-dir", help="Path to static web directory")
    p_serve.set_defaults(func=lambda args: cmd_serve(args, config))

    # list
    p_list = subparsers.add_parser("list", help="List registered services")
    p_list.add_argument("--check", action="store_true", help="Run live health check")
    p_list.set_defaults(func=lambda args: cmd_list(args, config))

    # add
    p_add = subparsers.add_parser("add", help="Add a new service to the dashboard")
    p_add.add_argument("--id", required=True, help="Unique identifier slug (e.g. my-app)")
    p_add.add_argument("--name", required=True, help="Display title (e.g. My App)")
    p_add.add_argument("--desc", required=True, help="Short description")
    p_add.add_argument("--port", type=int, required=True, help="Port number (e.g. 8080)")
    p_add.add_argument("--category", choices=CATEGORIES, default="apps", help=f"Category ({', '.join(CATEGORIES)})")
    p_add.add_argument("--path", default="/", help="URL subpath (default: /)")
    p_add.add_argument("--protocol", default="http", choices=["http", "https"], help="Protocol (default: http)")
    p_add.add_argument("--lan-url", help="Custom LAN URL override")
    p_add.add_argument("--tailscale-url", help="Custom Tailscale URL override")
    p_add.add_argument("--tailscale-port", type=int, help="Dedicated Tailscale Serve HTTPS port if applicable")
    p_add.add_argument("--lan-host", help="Override LAN host IP/name for this entry")
    p_add.add_argument("--tailscale-host", help="Override Tailscale MagicDNS host for this entry")
    p_add.add_argument("--badge", help="Badge label (e.g. Docker, Next.js, FastAPI)")
    p_add.add_argument("--icon", help="Icon name (gamepad, car, photos, health, pilot, wallet, sparkles, chart, bell, terminal, workflow, printer, server, api, trending, code, globe)")
    p_add.set_defaults(func=lambda args: cmd_add(args, config))

    # remove
    p_remove = subparsers.add_parser("remove", help="Remove a service by id")
    p_remove.add_argument("id", help="Service id slug to remove")
    p_remove.set_defaults(func=lambda args: cmd_remove(args, config))

    # check
    p_check = subparsers.add_parser("check", help="Run health check and update status.json")
    p_check.set_defaults(func=lambda args: cmd_check(args, config))

    # sync
    p_sync = subparsers.add_parser("sync", help="Synchronize services and embedded index.html fallback data")
    p_sync.set_defaults(func=lambda args: cmd_sync(args, config))

    # config
    p_cfg = subparsers.add_parser("config", help="View or update configuration")
    p_cfg.add_argument("action", choices=["show", "set"], help="Action to perform (show or set)")
    p_cfg.add_argument("--lan-host", help="Set default LAN hostname or IP")
    p_cfg.add_argument("--tailscale-host", help="Set default Tailscale hostname")
    p_cfg.add_argument("--tailscale-ip", help="Set default Tailscale IP")
    p_cfg.add_argument("--web-dir", help="Set web root directory (default: /var/www/html)")
    p_cfg.set_defaults(func=lambda args: cmd_config(args, config))

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
