#!/usr/bin/env bash
# ==============================================================================
# install.sh - Installer for Services Dashboard & Global Agent Skill
# ==============================================================================
set -e

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
WEB_DIR="/var/www/html"
INSTALL_CRON=true
INSTALL_WEB=true
FORCE_WEB=false

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
  --web-dir PATH     Target web directory for dashboard UI (default: /var/www/html)
  --no-cron          Do not configure the 1-minute health check crontab
  --no-web           Skip copying web frontend assets (index.html, services.json)
  --force-web        Overwrite existing index.html in the target web directory
  -h, --help         Show this help message
EOF
  exit 0
}

# Parse command line flags
while [[ $# -gt 0 ]]; do
  case $1 in
    --web-dir)
      WEB_DIR="$2"
      shift 2
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

# 2. Sudo helper
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo &>/dev/null; then
    SUDO="sudo"
  else
    echo -e "${YELLOW}Warning: Running as non-root without sudo. Some global locations may require elevated privileges.${NC}"
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

# 4. Install Global CLI Command
echo -e "${BLUE}==>${NC} Installing global 'dashboard-manage' CLI command..."
GLOBAL_BIN="/usr/local/bin/dashboard-manage"
CLI_TARGET_DIR="/usr/local/share/dashboard-manage"

$SUDO mkdir -p "$CLI_TARGET_DIR/scripts"
$SUDO cp "$REPO_DIR/scripts/manage_sites.py" "$CLI_TARGET_DIR/scripts/"
$SUDO cp "$REPO_DIR/scripts/check_status.py" "$CLI_TARGET_DIR/scripts/"
$SUDO chmod +x "$CLI_TARGET_DIR/scripts/"*.py

# Create symlink or executable wrapper in /usr/local/bin
$SUDO ln -sf "$CLI_TARGET_DIR/scripts/manage_sites.py" "$GLOBAL_BIN"
$SUDO chmod +x "$GLOBAL_BIN"
echo -e "${GREEN}✓${NC} Global command available at $GLOBAL_BIN"

# 5. Install Web Frontend Assets
if [ "$INSTALL_WEB" = true ]; then
  echo -e "${BLUE}==>${NC} Setting up web assets in $WEB_DIR..."
  $SUDO mkdir -p "$WEB_DIR"

  # index.html
  if [ ! -f "$WEB_DIR/index.html" ] || [ "$FORCE_WEB" = true ]; then
    $SUDO cp "$REPO_DIR/web/index.html" "$WEB_DIR/index.html"
    echo -e "${GREEN}✓${NC} Installed $WEB_DIR/index.html"
  else
    echo -e "${YELLOW}ℹ${NC} $WEB_DIR/index.html already exists. Preserving existing file (use --force-web to overwrite)."
  fi

  # services.json
  if [ ! -f "$WEB_DIR/services.json" ]; then
    $SUDO cp "$REPO_DIR/web/services.json" "$WEB_DIR/services.json"
    echo -e "${GREEN}✓${NC} Installed initial $WEB_DIR/services.json"
  else
    echo -e "${YELLOW}ℹ${NC} Existing $WEB_DIR/services.json preserved."
  fi

  # status.json
  if [ ! -f "$WEB_DIR/status.json" ]; then
    $SUDO cp "$REPO_DIR/web/status.json" "$WEB_DIR/status.json"
    echo -e "${GREEN}✓${NC} Installed template $WEB_DIR/status.json"
  fi

  # Fix permissions so current user and webserver can read/write services
  $SUDO chown -R "$(id -un):$(id -gn)" "$WEB_DIR" 2>/dev/null || true
  $SUDO chmod 755 "$WEB_DIR" 2>/dev/null || true
  $SUDO chmod 664 "$WEB_DIR/services.json" "$WEB_DIR/status.json" 2>/dev/null || true
fi

# 6. Configure Health Check Cron
if [ "$INSTALL_CRON" = true ]; then
  echo -e "${BLUE}==>${NC} Setting up automated health check cron job..."
  CRON_CMD="* * * * * /usr/bin/python3 $CLI_TARGET_DIR/scripts/check_status.py >/dev/null 2>&1"

  # Check if cron line already exists
  CURRENT_CRON="$(crontab -l 2>/dev/null || true)"
  if echo "$CURRENT_CRON" | grep -Fq "check_status.py"; then
    echo -e "${YELLOW}ℹ${NC} Crontab already contains check_status.py job."
  else
    (echo "$CURRENT_CRON"; echo "$CRON_CMD") | crontab -
    echo -e "${GREEN}✓${NC} Added health check job to crontab (runs every minute)."
  fi
fi

# 7. Initial Health Check Run
echo -e "${BLUE}==>${NC} Running initial service health check..."
python3 "$CLI_TARGET_DIR/scripts/check_status.py" || true

echo -e "\n${GREEN}=====================================================${NC}"
echo -e "${GREEN}🎉 Services Dashboard successfully installed!${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo -e "You can now run:"
echo -e "  ${BLUE}dashboard-manage list${NC}        # List all registered services"
echo -e "  ${BLUE}dashboard-manage add --help${NC}  # Register a new service"
echo -e "  ${BLUE}dashboard-manage check${NC}       # Run live connectivity probe"
echo -e "  ${BLUE}dashboard-manage config show${NC} # View detected network endpoints"
