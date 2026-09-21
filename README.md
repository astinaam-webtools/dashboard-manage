# 🚀 Services Dashboard & Global Agent Skill

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Raspberry%20Pi-red.svg)](https://www.raspberrypi.com/)
[![Tailscale](https://img.shields.io/badge/Networking-Tailscale%20%2B%20LAN-4B70E2.svg)](https://tailscale.com/)

A modern, ultra-fast, mobile-first web dashboard and unified service registry designed for single-board computers (Raspberry Pi, Orange Pi, home servers) and self-hosted homelabs. 

Includes an **AI Agent Skill (`SKILL.md`)** and global CLI (`dashboard-manage`) enabling developers, sysadmins, and autonomous AI coding agents (such as Antigravity, Claude Code, Cursor, Gemini CLI) to automatically register, update, and monitor hosted ports, containers, and web applications.

---

## ✨ Features

- 📱 **Mobile-First Responsive UI**: Fast (<30ms load time), modern card layout with Dark and Light mode support.
- 🌐 **Dual Network Intelligence**:
  - Automatically generates both **Local LAN** (`http://<ip>:<port>/`) and **Tailscale MagicDNS** (`https://<host>.ts.net:<port>/`) launch and copy links.
  - Automatically detects whether the visiting client is connected via Local Wi-Fi/Ethernet or Tailscale, tailoring the primary launch button accordingly.
- 🔍 **Instant Search & Category Filtering**: Filter across `apps`, `ai`, `games`, `media`, `utilities`, and `apis`.
- 🟢 **Live Health Probing**: Automated periodic TCP & HTTP health checker updates online/offline status indicators in real-time.
- 🤖 **Agent-First Skill**: AI agents can register apps immediately after spinning up Docker containers or web services without manual intervention.
- ⚡ **Zero External Dependencies**: Pure HTML/CSS/Vanilla JS frontend with lightweight standard-library Python backend.

---

## 📸 Dashboard Overview

```text
┌─────────────────────────────────────────────────────────────┐
│  ⚡ Pi Services Hub                    [Theme] [Refresh]    │
│  Active Network: Local LAN (192.168.1.100)                  │
│                                                             │
│  [All (7)] [Apps] [AI & Dev] [Games] [Media] [Utilities]    │
│  [ Search services, ports, badges...                     ]  │
│                                                             │
│  ┌─────────────────────────┐   ┌─────────────────────────┐  │
│  │ 🌐 Next.js Web Portal   │   │ 📊 Grafana Dashboards   │  │
│  │ Port 3000 • [Next.js] 🟢│   │ Port 3002 • [Metrics] 🟢│  │
│  │ Modern web dashboard... │   │ System telemetry...     │  │
│  │                         │   │                         │  │
│  │ 🏠 LAN       [Copy]     │   │ 🏠 LAN       [Copy]     │  │
│  │ 🌐 Tailscale [Copy]     │   │ 🌐 Tailscale [Copy]     │  │
│  │ [ Open Service ↗ ]     │   │ [ Open Service ↗ ]     │  │
│  └─────────────────────────┘   └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start & Installation

### 1. Clone the Repository
```bash
git clone https://github.com/astinaam-webtools/dashboard-manage.git
cd dashboard-manage
```

### 2. Install Globally
Run the automated installer:
```bash
./install.sh
```

#### What `install.sh` Does:
1. **Installs Global CLI**: Makes `dashboard-manage` available system-wide at `/usr/local/bin/dashboard-manage`.
2. **Registers Agent Skill**: Installs `manage-dashboard` into `~/.agents/skills/` and `~/.gemini/config/skills/` for AI agents.
3. **Deploys Web Assets**: Sets up `index.html` and starter `services.json` in `/var/www/html` (leaves existing services intact).
4. **Configures Automated Health Probing**: Adds a 1-minute crontab job probing service ports.

#### Custom Installation Flags:
```bash
./install.sh --help

# Example: Custom web root directory and without crontab
./install.sh --web-dir /srv/http --no-cron
```

---

## 🛠️ CLI Usage (`dashboard-manage`)

### 1. List Registered Services & Status
```bash
dashboard-manage list

# Or run an instant live socket/HTTP probe before listing:
dashboard-manage list --check
```

### 2. Register / Add a New Service
```bash
dashboard-manage add \
  --id "uptime-kuma" \
  --name "Uptime Kuma" \
  --desc "Self-hosted uptime and port monitor" \
  --port 3001 \
  --category utilities \
  --badge "Docker" \
  --icon "health"
```

#### Supported `add` Options:
| Flag | Description | Default |
| :--- | :--- | :--- |
| `--id` *(required)* | Unique lowercase slug (e.g. `ollama-web`) | |
| `--name` *(required)* | Human-friendly title | |
| `--desc` *(required)* | Brief description of the app or tool | |
| `--port` *(required)* | Host TCP port number | |
| `--category` | One of `apps`, `ai`, `games`, `media`, `utilities`, `apis` | `apps` |
| `--path` | URL path if not root (e.g. `/docs` or `/app/`) | `/` |
| `--protocol` | `http` or `https` | `http` |
| `--badge` | Short badge label (e.g. `Next.js`, `Docker`, `FastAPI`) | `Port <port>` |
| `--icon` | Icon name: `gamepad`, `car`, `photos`, `health`, `pilot`, `wallet`, `sparkles`, `chart`, `bell`, `terminal`, `workflow`, `printer`, `server`, `api`, `trending`, `code`, `globe` | `globe` |
| `--tailscale-port` | Dedicated Tailscale Serve HTTPS port (if proxied) | |
| `--lan-url` / `--tailscale-url` | Explicit custom URL overrides | Auto-generated |

### 3. Remove a Service
```bash
dashboard-manage remove "uptime-kuma"
```

### 4. Run Instant Health Checks
```bash
dashboard-manage check
```

### 5. View and Set Network Configuration
```bash
# View active configuration and auto-detected endpoints:
dashboard-manage config show

# Set static custom endpoints:
dashboard-manage config set --lan-host "192.168.1.50" --tailscale-host "my-device.tailnet.ts.net"
```

---

## 🤖 AI Agent Skill Integration

This repository includes [`SKILL.md`](SKILL.md), adhering to the Agent Skill standard.

When an AI assistant (Antigravity, Claude Code, Gemini CLI, Cursor, Windsurf) operates in an environment with this skill installed:
- When the agent builds or starts a service (e.g. `docker run -p 8080:8080 ...` or `npm run start`), it automatically invokes `dashboard-manage add ...`.
- When an agent destroys or decommissions a container, it invokes `dashboard-manage remove ...`.
- When asked "what services are running?" or "how do I view the app?", the agent references the dashboard links.

---

## 📂 Project Architecture

```text
dashboard-manage/
├── bin/
│   └── dashboard-manage        # Executable launcher wrapper
├── scripts/
│   ├── manage_sites.py         # Core Python CLI implementation
│   └── check_status.py         # Fast TCP/HTTP socket health checker
├── web/
│   ├── index.html              # Responsive, static web frontend
│   ├── services.json           # Template/dummy service catalog (sanitized)
│   └── status.json             # Template live status state
├── config/
│   └── config.example.json     # Optional configuration file template
├── SKILL.md                    # AI agent instructions & lifecycle rules
├── install.sh                  # Global installation script
├── uninstall.sh                # Clean uninstaller script
├── LICENSE                     # MIT License
└── README.md                   # Project documentation
```

---

## 🗑️ Uninstallation

To remove the CLI, skill, and cron job from your system:
```bash
./uninstall.sh

# Or to also purge web files and user configurations:
./uninstall.sh --purge
```

---

## 🔒 Privacy & Data Policy

The repository contains **only generic dummy data** and templates. All personal IP addresses, private subnets, device hostnames, and Tailscale authentication parameters are resolved dynamically or stored locally on your machine in `~/.config/dashboard-manage/config.json` and `/var/www/html/services.json`.

---

## 📄 License

[MIT](LICENSE) © 2026 astinaam-webtools
