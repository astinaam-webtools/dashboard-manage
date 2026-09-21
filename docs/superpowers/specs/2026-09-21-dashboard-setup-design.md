# Services Dashboard Setup & Agent Notify Integration Design

- **Date:** 2026-09-21
- **Status:** Approved
- **Project:** dashboard-manage
- **Target Port:** 8080 (unprivileged user space)
- **Primary Integrated Service:** Agent Notify (`http://localhost:4173`)

## 1. Overview & Objectives

Set up the Services Dashboard (`dashboard-manage`) for unprivileged, user-space execution on Linux/systemd. The setup enables:
1. Running the web dashboard without root/sudo privileges on Port 8080 (`http://192.168.0.154:8080`).
2. Providing a native `serve` CLI sub-command in `dashboard-manage` with built-in background health probing.
3. Automatically running the dashboard server 24/7 as a `systemd --user` background service.
4. Installing the `dashboard-manage` CLI into `~/.local/bin/dashboard-manage` and agent skills into `~/.agents/skills/` and `~/.gemini/config/skills/`.
5. Initializing the service registry clean with `agent-notify` on port 4173.
6. Sending the live dashboard links to the user via Telegram using `agent-notify send`.

## 2. Architecture & Components

### 2.1 CLI Server (`dashboard-manage serve`)
- Added to `scripts/manage_sites.py`.
- Arguments:
  - `--port`: Default `8080` (or configured via `config.json`).
  - `--host`: Default `0.0.0.0` (binds to all interfaces so accessible via LAN / Tailscale / localhost).
  - `--web-dir`: Overridable static web directory path.
- Implementation:
  - Standard library `http.server.ThreadingHTTPServer` and custom `SimpleHTTPRequestHandler` subclass.
  - Adds `Cache-Control: no-cache, no-store, must-revalidate` for `services.json` and `status.json` so updates immediately reflect in the frontend.
  - Background daemon thread runs `run_health_check(config)` every 60 seconds (and once on startup).

### 2.2 Systemd User Service (`dashboard-manage.service`)
- Location: `~/.config/systemd/user/dashboard-manage.service`
- Service configuration:
  - `ExecStart=%h/.local/bin/dashboard-manage serve --port 8080`
  - `Restart=always`
  - `RestartSec=5`
  - Enabled and started via `systemctl --user enable --now dashboard-manage.service`.

### 2.3 User Installation & Asset Deployment
- CLI binary linked to `~/.local/bin/dashboard-manage`.
- Web assets deployed to `~/.local/share/dashboard-manage/web/`:
  - `index.html`
  - `services.json`
  - `status.json`
- Configuration stored at `~/.config/dashboard-manage/config.json`:
  ```json
  {
    "web_dir": "/home/astinaam/.local/share/dashboard-manage/web",
    "port": 8080,
    "lan_host": "192.168.0.154",
    "auto_detect": true
  }
  ```
- Skill installed to:
  - `~/.agents/skills/manage-dashboard/`
  - `~/.gemini/config/skills/manage-dashboard/`
- `install.sh` updated to support `--user` mode and auto-fallback when running non-root without passwordless sudo.

### 2.4 Service Registry Initialization
- Initial `services.json` contains:
  - `id`: `agent-notify`
  - `name`: `Agent Notify Gateway`
  - `description`: `Telegram & Web Notification Gateway for AI Coding Agents`
  - `port`: 4173
  - `category`: `utilities`
  - `icon`: `bell`
  - `badge`: `Gateway`
  - `lan_url`: `http://192.168.0.154:4173/`

### 2.5 Telegram Notification
- Push live dashboard links via:
  ```bash
  agent-notify send "🚀 Services Dashboard is live at http://192.168.0.154:8080 (monitoring Agent Notify on port 4173)" --agent "Antigravity" --level success
  ```

## 3. Verification Plan
1. Test `dashboard-manage serve` directly via socket connection.
2. Verify `systemctl --user status dashboard-manage.service` is active and running.
3. Query `curl -s http://localhost:8080/` and verify HTTP 200 OK.
4. Query `curl -s http://localhost:8080/services.json` and verify `agent-notify` entry.
5. Query `curl -s http://localhost:8080/status.json` and verify `agent-notify` status is `online`.
6. Run `agent-notify send` and verify exit code 0.
