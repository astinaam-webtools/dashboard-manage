# Services Dashboard Setup & Agent Notify Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Set up the Services Dashboard to run on unprivileged port 8080 as a systemd user service, register Agent Notify (port 4173) as the primary service, and send the live link via Telegram.

**Architecture:** Extend `manage_sites.py` with a standard library `serve` subcommand that serves static assets and runs background health probing. Deploy user configuration, CLI wrapper, systemd user service, and agent skills. Verify HTTP status and push notification via `agent-notify`.

**Tech Stack:** Python 3 (standard library `http.server`, `threading`, `socket`), Systemd User Units, Bash, JSON.

## Global Constraints
- No sudo or root privileges required.
- Dashboard served on Port 8080 (`0.0.0.0:8080`).
- User configuration in `~/.config/dashboard-manage/config.json`.
- CLI in `~/.local/bin/dashboard-manage`.
- Initial service: Agent Notify on port 4173 (`utilities` category, `bell` icon).

---

### Task 1: Add `serve` Subcommand to `scripts/manage_sites.py`

**Files:**
- Modify: `scripts/manage_sites.py`
- Test: `tests/test_serve.py`

**Interfaces:**
- CLI: `dashboard-manage serve [--port 8080] [--host 0.0.0.0] [--web-dir PATH]`
- Background thread: `run_health_check(config)` every 60 seconds.

- [ ] **Step 1: Write test for serve argument parsing and handler**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement `cmd_serve` and HTTP request handler with cache-control headers in `scripts/manage_sites.py`**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit changes to git**

---

### Task 2: Enhance `install.sh` and `uninstall.sh` for User-Space Support

**Files:**
- Modify: `install.sh`
- Modify: `uninstall.sh`

**Interfaces:**
- Flag `--user`: Installs CLI to `~/.local/bin`, web assets to `~/.local/share/dashboard-manage/web`, config to `~/.config/dashboard-manage/config.json`, and configures systemd user service.
- Auto-fallback: If running non-root and `sudo` requires password or fails, automatically switches to user-space install.

- [ ] **Step 1: Update `install.sh` with `--user` flag and unprivileged fallback**
- [ ] **Step 2: Update `uninstall.sh` with `--user` cleanup support**
- [ ] **Step 3: Commit changes to git**

---

### Task 3: Deploy Assets, CLI, and User Configuration

**Files:**
- Create: `~/.config/dashboard-manage/config.json`
- Create: `~/.local/share/dashboard-manage/web/index.html`
- Create: `~/.local/share/dashboard-manage/web/services.json`
- Create: `~/.local/share/dashboard-manage/web/status.json`
- Symlink: `~/.local/bin/dashboard-manage` -> repository wrapper or script
- Skill: `~/.agents/skills/manage-dashboard/` and `~/.gemini/config/skills/manage-dashboard/`

- [ ] **Step 1: Create directories and write `config.json`**
- [ ] **Step 2: Deploy web frontend assets (`index.html`, `services.json`, `status.json`)**
- [ ] **Step 3: Link `dashboard-manage` to `~/.local/bin/` and install agent skills**
- [ ] **Step 4: Verify `dashboard-manage` CLI works from terminal**

---

### Task 4: Register Agent Notify and Run Initial Health Check

**Files:**
- Modify: `~/.local/share/dashboard-manage/web/services.json`
- Modify: `~/.local/share/dashboard-manage/web/status.json`

- [ ] **Step 1: Configure `services.json` with only `agent-notify` on port 4173**
- [ ] **Step 2: Run `dashboard-manage check` to probe port 4173**
- [ ] **Step 3: Verify `dashboard-manage list` displays `agent-notify` as `online`**

---

### Task 5: Set Up and Enable Systemd User Service

**Files:**
- Create: `~/.config/systemd/user/dashboard-manage.service`

- [ ] **Step 1: Write `dashboard-manage.service` unit file**
- [ ] **Step 2: Reload systemd user daemon and enable/start the service**
- [ ] **Step 3: Verify service is active and running**

---

### Task 6: End-to-End Verification & Telegram Notification

- [ ] **Step 1: Query `curl -I http://localhost:8080/` to confirm HTTP 200 OK**
- [ ] **Step 2: Query `curl -s http://localhost:8080/services.json` and verify `agent-notify` entry**
- [ ] **Step 3: Query `curl -s http://localhost:8080/status.json` and verify `online` status**
- [ ] **Step 4: Send the live dashboard links to Telegram via `agent-notify send`**
