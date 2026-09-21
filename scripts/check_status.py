#!/usr/bin/env python3
"""
check_status.py - Fast health checker for services dashboard.
Probes registered services and updates status.json.
Ideal for 1-minute crontab or systemd timer execution.
"""

import json
import os
import socket
import sys
import time
import urllib.request
from typing import Dict, Any

CONFIG_DIR_USER = os.path.expanduser("~/.config/dashboard-manage")
CONFIG_FILE_USER = os.path.join(CONFIG_DIR_USER, "config.json")
CONFIG_FILE_SYSTEM = "/etc/dashboard-manage/config.json"


def get_paths():
    config_path = os.environ.get("DASHBOARD_CONFIG_FILE")
    web_dir = os.environ.get("DASHBOARD_WEB_DIR")

    if not web_dir:
        paths = []
        if config_path:
            paths.append(config_path)
        paths.extend([CONFIG_FILE_USER, CONFIG_FILE_SYSTEM])
        for p in paths:
            if os.path.isfile(p):
                try:
                    with open(p, "r", encoding="utf-8") as f:
                        data = json.load(f)
                        web_dir = data.get("web_dir")
                        if web_dir:
                            break
                except Exception:
                    pass

    web_dir = web_dir or "/var/www/html"
    return os.path.join(web_dir, "services.json"), os.path.join(web_dir, "status.json")


def check_single(service: Dict[str, Any]) -> str:
    port = service.get("port")
    path = service.get("path", "/")

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

    try:
        port_int = int(port)
        with socket.create_connection(("127.0.0.1", port_int), timeout=1.0):
            return "online"
    except Exception:
        return "offline"


def main():
    services_path, status_path = get_paths()

    if not os.path.exists(services_path):
        print(f"Notice: {services_path} not found. Skipping health check.", file=sys.stderr)
        sys.exit(0)

    try:
        with open(services_path, "r", encoding="utf-8") as f:
            services = json.load(f)
    except Exception as e:
        print(f"Error reading {services_path}: {e}", file=sys.stderr)
        sys.exit(1)

    statuses = {}
    for s in services:
        sid = s.get("id")
        if sid:
            statuses[sid] = check_single(s)

    status_data = {
        "updated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "statuses": statuses
    }

    try:
        os.makedirs(os.path.dirname(os.path.abspath(status_path)), exist_ok=True)
        with open(status_path, "w", encoding="utf-8") as f:
            json.dump(status_data, f, indent=2)
        online = sum(1 for v in statuses.values() if v == "online")
        print(f"Updated {status_path}: {online}/{len(statuses)} services online at {status_data['updated_at']}")
    except Exception as e:
        print(f"Error writing {status_path}: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
