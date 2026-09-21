#!/usr/bin/env bash
# ==============================================================================
# uninstall.sh - Clean Uninstaller for Services Dashboard & Global Skill
# ==============================================================================
set -e

PURGE=false
WEB_DIR="/var/www/html"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

show_help() {
  cat << EOF
Usage: ./uninstall.sh [OPTIONS]

Options:
  --purge            Also remove web files (index.html, services.json, status.json)
  --web-dir PATH     Web directory to purge if --purge is specified (default: /var/www/html)
  -h, --help         Show this help message
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --purge)
      PURGE=true
      shift
      ;;
    --web-dir)
      WEB_DIR="$2"
      shift 2
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

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo &>/dev/null; then
    SUDO="sudo"
  fi
fi

echo -e "${BLUE}==>${NC} Uninstalling Services Dashboard & Global Skill..."

# 1. Remove Global CLI and Shared Scripts
if [ -f "/usr/local/bin/dashboard-manage" ] || [ -L "/usr/local/bin/dashboard-manage" ]; then
  $SUDO rm -f "/usr/local/bin/dashboard-manage"
  echo -e "${GREEN}✓${NC} Removed /usr/local/bin/dashboard-manage"
fi

if [ -d "/usr/local/share/dashboard-manage" ]; then
  $SUDO rm -rf "/usr/local/share/dashboard-manage"
  echo -e "${GREEN}✓${NC} Removed /usr/local/share/dashboard-manage"
fi

# 2. Remove Skills from Agent and Gemini directories
SKILL_TARGET_AGENTS="$HOME/.agents/skills/manage-dashboard"
SKILL_TARGET_GEMINI="$HOME/.gemini/config/skills/manage-dashboard"

for TARGET in "$SKILL_TARGET_AGENTS" "$SKILL_TARGET_GEMINI"; do
  if [ -d "$TARGET" ]; then
    rm -rf "$TARGET"
    echo -e "${GREEN}✓${NC} Removed skill from $TARGET"
  fi
done

# 3. Remove Cron Job
CURRENT_CRON="$(crontab -l 2>/dev/null || true)"
if echo "$CURRENT_CRON" | grep -Fq "check_status.py"; then
  echo "$CURRENT_CRON" | grep -Fv "check_status.py" | crontab - || true
  echo -e "${GREEN}✓${NC} Removed health check job from crontab"
fi

# 4. Optional Purge
if [ "$PURGE" = true ]; then
  echo -e "${YELLOW}==>${NC} Purging web assets and user configurations..."
  if [ -f "$WEB_DIR/index.html" ]; then
    $SUDO rm -f "$WEB_DIR/index.html"
    echo -e "${GREEN}✓${NC} Removed $WEB_DIR/index.html"
  fi
  if [ -f "$WEB_DIR/services.json" ]; then
    $SUDO rm -f "$WEB_DIR/services.json"
    echo -e "${GREEN}✓${NC} Removed $WEB_DIR/services.json"
  fi
  if [ -f "$WEB_DIR/status.json" ]; then
    $SUDO rm -f "$WEB_DIR/status.json"
    echo -e "${GREEN}✓${NC} Removed $WEB_DIR/status.json"
  fi
  if [ -d "$HOME/.config/dashboard-manage" ]; then
    rm -rf "$HOME/.config/dashboard-manage"
    echo -e "${GREEN}✓${NC} Removed user config"
  fi
else
  echo -e "${YELLOW}ℹ${NC} Web files in $WEB_DIR preserved (pass --purge to remove)."
fi

echo -e "\n${GREEN}=====================================================${NC}"
echo -e "${GREEN}✓ Uninstallation complete!${NC}"
echo -e "${GREEN}=====================================================${NC}"
