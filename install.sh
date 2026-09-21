#!/usr/bin/env bash
# ==============================================================================
# install.sh - Installer for Services Dashboard & Global Agent Skill
# ==============================================================================
set -e

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
USER_MODE=auto
PORT=""
WEB_DIR=""
INSTALL_CRON=auto
INSTALL_WEB=true
FORCE_WEB=false
START_SERVICE=true

# Color helpers
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

show_help() {
  cat << EOF
Usage: ./install.sh [OPTIONS]

Options:
  --user             Install in user-space (~/.local/bin, ~/.local/share/dashboard-manage)
  --system           Install system-wide (/usr/local/bin, /var/www/html) [requires sudo]
  --port PORT        Port to serve the dashboard on (default: 8080 for user, 80 for system)
  --web-dir PATH     Target web directory for dashboard UI
  --no-service       Do not enable/start the systemd user service
  --no-cron          Do not configure crontab health checks (for system mode)
  --no-web           Skip copying web frontend assets (index.html, services.json)
  --force-web        Overwrite existing index.html in the target web directory
  -h, --help         Show this help message
EOF
  exit 0
}

# Parse command line flags
while [[ $# -gt 0 ]]; do
  case $1 in
    --user)
      USER_MODE=true
      shift
      ;;
    --system)
      USER_MODE=false
      shift
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --web-dir)
      WEB_DIR="$2"
      shift 2
      ;;
    --no-service)
      START_SERVICE=false
      shift
      ;;
    --no-cron)
      INSTALL_CRON=false
      shift
      ;;
    --no-web)
      INSTALL_WEB=false
      shift
      ;;
    --force-web)
      FORCE_WEB=true
      shift
      ;;
    -h|--help)
      show_help
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      show_help
      ;;
  esac
done

echo -e "${BLUE}==>${NC} Installing Services Dashboard & Global Skill..."

# 1. Check Python 3
if ! command -v python3 &>/dev/null; then
  echo -e "${RED}Error: python3 is required but not installed.${NC}" >&2
  exit 1
fi

# 2. Determine User vs System Mode
if [ "$USER_MODE" = "auto" ]; then
  if [ "$(id -u)" -eq 0 ]; then
    USER_MODE=false
  elif sudo -n true 2>/dev/null; then
    USER_MODE=false
  else
    USER_MODE=true
    echo -e "${YELLOW}ℹ${NC} Running without passwordless sudo. Auto-selecting user-space installation mode."
  fi
fi

if [ "$USER_MODE" = true ]; then
  echo -e "${BLUE}==>${NC} Installation Mode: ${GREEN}User Space (~/.local/bin)${NC}"
  GLOBAL_BIN="$HOME/.local/bin/dashboard-manage"
  CLI_TARGET_DIR="$HOME/.local/share/dashboard-manage"
  WEB_DIR="${WEB_DIR:-$HOME/.local/share/dashboard-manage/web}"
  PORT="${PORT:-8080}"
  SUDO=""
else
  echo -e "${BLUE}==>${NC} Installation Mode: ${GREEN}System Wide (/usr/local/bin)${NC}"
  GLOBAL_BIN="/usr/local/bin/dashboard-manage"
  CLI_TARGET_DIR="/usr/local/share/dashboard-manage"
  WEB_DIR="${WEB_DIR:-/var/www/html}"
  PORT="${PORT:-80}"
  if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
  else
    SUDO=""
  fi
fi

# 3. Install Skill for AI Agents
echo -e "${BLUE}==>${NC} Installing agent skill..."
SKILL_TARGET_AGENTS="$HOME/.agents/skills/manage-dashboard"
SKILL_TARGET_GEMINI="$HOME/.gemini/config/skills/manage-dashboard"

for TARGET in "$SKILL_TARGET_AGENTS" "$SKILL_TARGET_GEMINI"; do
  mkdir -p "$TARGET/scripts"
  cp "$REPO_DIR/SKILL.md" "$TARGET/SKILL.md"
  cp "$REPO_DIR/scripts/manage_sites.py" "$TARGET/scripts/manage_sites.py"
  cp "$REPO_DIR/scripts/check_status.py" "$TARGET/scripts/check_status.py"
  chmod +x "$TARGET/scripts/"*.py
done
echo -e "${GREEN}✓${NC} Agent skill installed into ~/.agents/skills/ and ~/.gemini/config/skills/"

# 4. Install CLI Command & Executable Wrapper
echo -e "${BLUE}==>${NC} Installing 'dashboard-manage' CLI command to $GLOBAL_BIN..."
if [ "$USER_MODE" = true ]; then
  mkdir -p "$HOME/.local/bin"
  mkdir -p "$CLI_TARGET_DIR/scripts"
  cp "$REPO_DIR/scripts/manage_sites.py" "$CLI_TARGET_DIR/scripts/"
  cp "$REPO_DIR/scripts/check_status.py" "$CLI_TARGET_DIR/scripts/"
  chmod +x "$CLI_TARGET_DIR/scripts/"*.py
  ln -sf "$CLI_TARGET_DIR/scripts/manage_sites.py" "$GLOBAL_BIN"
  chmod +x "$GLOBAL_BIN"
else
  $SUDO mkdir -p "$CLI_TARGET_DIR/scripts"
  $SUDO cp "$REPO_DIR/scripts/manage_sites.py" "$CLI_TARGET_DIR/scripts/"
  $SUDO cp "$REPO_DIR/scripts/check_status.py" "$CLI_TARGET_DIR/scripts/"
  $SUDO chmod +x "$CLI_TARGET_DIR/scripts/"*.py
  $SUDO ln -sf "$CLI_TARGET_DIR/scripts/manage_sites.py" "$GLOBAL_BIN"
  $SUDO chmod +x "$GLOBAL_BIN"
fi
echo -e "${GREEN}✓${NC} Command available at $GLOBAL_BIN"

# 5. Install Web Frontend Assets
if [ "$INSTALL_WEB" = true ]; then
  echo -e "${BLUE}==>${NC} Setting up web assets in $WEB_DIR..."
  if [ "$USER_MODE" = true ]; then
    mkdir -p "$WEB_DIR"
    if [ ! -f "$WEB_DIR/index.html" ] || [ "$FORCE_WEB" = true ]; then
      cp "$REPO_DIR/web/index.html" "$WEB_DIR/index.html"
      echo -e "${GREEN}✓${NC} Installed $WEB_DIR/index.html"
    else
      echo -e "${YELLOW}ℹ${NC} $WEB_DIR/index.html already exists. Preserving existing file."
    fi

    if [ ! -f "$WEB_DIR/services.json" ]; then
      cp "$REPO_DIR/web/services.json" "$WEB_DIR/services.json"
      echo -e "${GREEN}✓${NC} Installed initial $WEB_DIR/services.json"
    else
      echo -e "${YELLOW}ℹ${NC} Existing $WEB_DIR/services.json preserved."
    fi

    if [ ! -f "$WEB_DIR/status.json" ]; then
      cp "$REPO_DIR/web/status.json" "$WEB_DIR/status.json"
      echo -e "${GREEN}✓${NC} Installed template $WEB_DIR/status.json"
    fi
  else
    $SUDO mkdir -p "$WEB_DIR"
    if [ ! -f "$WEB_DIR/index.html" ] || [ "$FORCE_WEB" = true ]; then
      $SUDO cp "$REPO_DIR/web/index.html" "$WEB_DIR/index.html"
      echo -e "${GREEN}✓${NC} Installed $WEB_DIR/index.html"
    else
      echo -e "${YELLOW}ℹ${NC} $WEB_DIR/index.html already exists. Preserving existing file."
    fi

    if [ ! -f "$WEB_DIR/services.json" ]; then
      $SUDO cp "$REPO_DIR/web/services.json" "$WEB_DIR/services.json"
      echo -e "${GREEN}✓${NC} Installed initial $WEB_DIR/services.json"
    else
      echo -e "${YELLOW}ℹ${NC} Existing $WEB_DIR/services.json preserved."
    fi

    if [ ! -f "$WEB_DIR/status.json" ]; then
      $SUDO cp "$REPO_DIR/web/status.json" "$WEB_DIR/status.json"
      echo -e "${GREEN}✓${NC} Installed template $WEB_DIR/status.json"
    fi

    $SUDO chown -R "$(id -un):$(id -gn)" "$WEB_DIR" 2>/dev/null || true
    $SUDO chmod 755 "$WEB_DIR" 2>/dev/null || true
    $SUDO chmod 664 "$WEB_DIR/services.json" "$WEB_DIR/status.json" 2>/dev/null || true
  fi
fi

# 6. Save Default User Configuration
CONFIG_DIR="$HOME/.config/dashboard-manage"
mkdir -p "$CONFIG_DIR"
python3 -c "
import json, os
cfg_file = os.path.expanduser('~/.config/dashboard-manage/config.json')
data = {}
if os.path.isfile(cfg_file):
    try:
        with open(cfg_file, 'r') as f: data = json.load(f)
    except Exception: pass
data['web_dir'] = '$WEB_DIR'
data['port'] = int('$PORT')
with open(cfg_file, 'w') as f: json.dump(data, f, indent=2)
"
echo -e "${GREEN}✓${NC} Configured ~/.config/dashboard-manage/config.json (web_dir=$WEB_DIR, port=$PORT)"

# 7. Setup Background Service or Health Probing
if [ "$USER_MODE" = true ] && [ "$START_SERVICE" = true ] && command -v systemctl &>/dev/null; then
  echo -e "${BLUE}==>${NC} Setting up systemd user service..."
  SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
  mkdir -p "$SYSTEMD_USER_DIR"
  cat << EOF > "$SYSTEMD_USER_DIR/dashboard-manage.service"
[Unit]
Description=Services Dashboard Web Server
After=network.target

[Service]
Type=simple
ExecStart=$GLOBAL_BIN serve --port $PORT --web-dir $WEB_DIR
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable --now dashboard-manage.service 2>/dev/null || true
  echo -e "${GREEN}✓${NC} Systemd user service enabled and started (dashboard-manage.service)"
elif [ "$USER_MODE" = false ] && [ "$INSTALL_CRON" = true ] && command -v crontab &>/dev/null; then
  echo -e "${BLUE}==>${NC} Setting up automated health check cron job..."
  CRON_CMD="* * * * * /usr/bin/python3 $CLI_TARGET_DIR/scripts/check_status.py >/dev/null 2>&1"
  CURRENT_CRON="$(crontab -l 2>/dev/null || true)"
  if echo "$CURRENT_CRON" | grep -Fq "check_status.py"; then
    echo -e "${YELLOW}ℹ${NC} Crontab already contains check_status.py job."
  else
    (echo "$CURRENT_CRON"; echo "$CRON_CMD") | crontab -
    echo -e "${GREEN}✓${NC} Added health check job to crontab."
  fi
fi

# 8. Run initial service health check
echo -e "${BLUE}==>${NC} Running initial service health check..."
"$GLOBAL_BIN" check || true

echo -e "\n${GREEN}=====================================================${NC}"
echo -e "${GREEN}🎉 Services Dashboard successfully installed!${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo -e "Dashboard is accessible at:"
LAN_IP=$(python3 -c "import scripts.manage_sites as m; print(m.detect_lan_ip())" 2>/dev/null || echo "127.0.0.1")
echo -e "  🏠 Local LAN: ${BLUE}http://$LAN_IP:$PORT/${NC}"
echo -e "  💻 Localhost: ${BLUE}http://localhost:$PORT/${NC}\n"
echo -e "Commands:"
echo -e "  ${BLUE}dashboard-manage list${NC}        # List registered services"
echo -e "  ${BLUE}dashboard-manage add --help${NC}  # Register a new service"
echo -e "  ${BLUE}dashboard-manage check${NC}       # Run live connectivity probe"
echo -e "  ${BLUE}dashboard-manage serve${NC}       # Start standalone dashboard web server"
