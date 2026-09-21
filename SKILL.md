---
name: manage-dashboard
description: Manage, register, update, or remove hosted web services and ports on the Raspberry Pi / Linux Port 80 mobile dashboard. Use whenever deploying, spinning up, modifying, or decommissioning a web service, docker container, or port, or when inspecting running services.
---

# 🚀 Web Services Dashboard Manager

The host runs a unified, mobile-friendly web dashboard served on **Port 80**, accessible over both **Local LAN** and **Tailscale**:
- **Local LAN**: `http://<device-lan-ip>/` or `http://<hostname>.local/`
- **Tailscale**: `https://<device>.<tailnet>.ts.net/` or `http://<tailscale-ip>/`

This dashboard displays interactive cards for all hosted web sites, containers, and services, providing direct launch buttons, quick copy buttons for both LAN and Tailscale links, category filtering, search, and live online/offline status badges.

---

## 📌 Agent Rules & When to Use

Any AI agent operating on this system **MUST** adhere to the following lifecycle rules:

1. **When Deploying a New Web Service / Site**:
   - Immediately register the new service with the dashboard so the user does not have to remember or look up the port number.
   - Example triggers: Running a new Docker container with a web UI, launching a web server (Next.js, Vite, Streamlit, Flask, FastAPI, Go, etc.), adding an Nginx reverse-proxy location, or spinning up a dev tool.

2. **When Decommissioning / Removing a Service**:
   - Immediately remove the service from the dashboard so stale or broken links do not remain visible to the user.

3. **When Changing Ports, Paths, or Tailscale Serve**:
   - Update or re-add the service entry to reflect the new port, subpath, or Tailscale proxy URL.

4. **When Answering User Questions**:
   - Reference the dashboard URLs when the user asks "what sites are hosted?", "what port is app X on?", or "how do I access service Y from my phone?".

---

## ⚡ Quick CLI Commands

The management CLI tool is available globally as `dashboard-manage` (or via Python at `scripts/manage_sites.py`):

### 1. List All Registered Services & Live Status
```bash
dashboard-manage list

# Or with an instant live connectivity check:
dashboard-manage list --check
```

### 2. Register / Add a New Service
```bash
dashboard-manage add \
  --id "my-app" \
  --name "My Awesome App" \
  --desc "Short 1-2 sentence description of what the app does" \
  --port 8080 \
  --category apps \
  --badge "Docker" \
  --icon "globe"
```

#### Supported Arguments:
- `--id` *(required)*: Unique lowercase slug (e.g. `uptime-kuma`, `ollama-web`)
- `--name` *(required)*: Display title on the card
- `--desc` *(required)*: Clear description of the service
- `--port` *(required)*: Host port number (e.g. `8080`, `3000`)
- `--category`: One of `apps`, `ai`, `games`, `media`, `utilities`, `apis` (default: `apps`)
- `--path`: URL path if not root (e.g. `/docs` or `/app/`, default `/`)
- `--protocol`: `http` or `https` (default: `http`)
- `--badge`: Short badge label (e.g. `Next.js`, `Docker`, `FastAPI`, `Go Web`)
- `--icon`: Icon name (`gamepad`, `car`, `photos`, `health`, `pilot`, `wallet`, `sparkles`, `chart`, `bell`, `terminal`, `workflow`, `printer`, `server`, `api`, `trending`, `code`, `globe`)
- `--tailscale-port`: If proxied via a dedicated Tailscale Serve port (e.g. `8443`)
- `--lan-url` / `--tailscale-url`: Optional explicit URL overrides

### 3. Remove a Service
```bash
dashboard-manage remove "my-app"
```

### 4. Run Instant Health Checks
```bash
dashboard-manage check
```

### 5. Inspect or Update Configuration
```bash
# View active configuration (detected LAN IP, Tailscale domain, and web root path)
dashboard-manage config show

# Set custom static LAN IP or Tailscale domain
dashboard-manage config set --lan-host "192.168.1.50" --tailscale-host "my-device.tailnet.ts.net"
```

---

## 📂 Configuration & Data Architecture

The dashboard is completely static, ultra-fast (<30ms load time), and requires no heavy runtime:

| Component | Path | Description |
| :--- | :--- | :--- |
| **Service Inventory** | `/var/www/html/services.json` | JSON list of all registered services and metadata |
| **Live Health State** | `/var/www/html/status.json` | Health status (`online`/`offline`) probed periodically |
| **Dashboard UI** | `/var/www/html/index.html` | Responsive, mobile-first card interface on Port 80 |
| **CLI Tool** | `/usr/local/bin/dashboard-manage` | Global CLI helper tool |
| **Health Check Script**| `check_status.py` | Standalone TCP/HTTP port prober for crontab/systemd |

---

## 🌐 Network Topology Reference for Agents

- **Port 80**: Served by Nginx or lighttpd, accessible across local LAN and reverse-proxied over Tailscale.
- **Smart Launch**: The UI detects whether the client is connecting via Tailscale or local network and automatically prioritizes the appropriate connection link.
