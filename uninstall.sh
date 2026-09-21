#!/usr/bin/env bash
# ==============================================================================
# uninstall.sh - Clean Uninstaller for Services Dashboard & Global Skill
# ==============================================================================
set -e

PURGE=false
WEB_DIR=""

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

show_help() {
  cat << EOF
Usage: ./uninstall.sh [OPTIONS]

Options:
  --purge            Also remove web files and user configuration
  --web-dir PATH     Web directory to purge if --purge is specified
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
if [ "$(id -u)" -ne 0 ] && command -v sudo &>/dev/null; then
  if sudo -n true 2>/dev/null; then
    SUDO="sudo"
  fi
fi

echo -e "${BLUE}==>${NC} Uninstalling Services Dashboard & Global Skill..."

# 1. Stop and remove systemd user service
if command -v systemctl &>/dev/null; then
  if systemctl --user is-active --quiet dashboard-manage.service 2>/dev/null; then
    systemctl --user stop dashboard-manage.service 2>/dev/null || true
    echo -e "${GREEN}✓${NC} Stopped dashboard-manage.service"
  fi
  if systemctl --user is-enabled --quiet dashboard-manage.service 2>/dev/null; then
    systemctl --user disable dashboard-manage.service 2>/dev/null || true
    echo -e "${GREEN}✓${NC} Disabled dashboard-manage.service"
  fi
  if [ -f "$HOME/.config/systemd/user/dashboard-manage.service" ]; then
    rm -f "$HOME/.config/systemd/user/dashboard-manage.service"
    systemctl --user daemon-reload 2>/dev/null || true
    echo -e "${GREEN}✓${NC} Removed ~/.config/systemd/user/dashboard-manage.service"
  fi
fi

# 2. Remove CLI binaries
if [ -f "$HOME/.local/bin/dashboard-manage" ] || [ -L "$HOME/.local/bin/dashboard-manage" ]; then
  rm -f "$HOME/.local/bin/dashboard-manage"
  echo -e "${GREEN}✓${NC} Removed ~/.local/bin/dashboard-manage"
fi

if [ -d "$HOME/.local/share/dashboard-manage" ]; then
  rm -rf "$HOME/.local/share/dashboard-manage/scripts"
  echo -e "${GREEN}✓${NC} Removed ~/.local/share/dashboard-manage/scripts"
fi

if [ -f "/usr/local/bin/dashboard-manage" ] || [ -L "/usr/local/bin/dashboard-manage" ]; then
  if [ -n "$SUDO" ] || [ "$(id -u)" -eq 0 ]; then
    $SUDO rm -f "/usr/local/bin/dashboard-manage"
    echo -e "${GREEN}✓${NC} Removed /usr/local/bin/dashboard-manage"
  fi
fi

if [ -d "/usr/local/share/dashboard-manage" ]; then
  if [ -n "$SUDO" ] || [ "$(id -u)" -eq 0 ]; then
    $SUDO rm -rf "/usr/local/share/dashboard-manage"
    echo -e "${GREEN}✓${NC} Removed /usr/local/share/dashboard-manage"
  fi
fi

# 3. Remove Skills from Agent and Gemini directories
SKILL_TARGET_AGENTS="$HOME/.agents/skills/manage-dashboard"
SKILL_TARGET_GEMINI="$HOME/.gemini/config/skills/manage-dashboard"

for TARGET in "$SKILL_TARGET_AGENTS" "$SKILL_TARGET_GEMINI"; do
  if [ -d "$TARGET" ]; then
    rm -rf "$TARGET"
    echo -e "${GREEN}✓${NC} Removed skill from $TARGET"
  fi
done

# 4. Remove Cron Job (if any)
if command -v crontab &>/dev/null; then
  CURRENT_CRON="$(crontab -l 2>/dev/null || true)"
  if echo "$CURRENT_CRON" | grep -Fq "check_status.py"; then
    echo "$CURRENT_CRON" | grep -Fv "check_status.py" | crontab - || true
    echo -e "${GREEN}✓${NC} Removed health check job from crontab"
  fi
fi

# 5. Optional Purge
if [ "$PURGE" = true ]; then
  echo -e "${YELLOW}==>${NC} Purging web assets and configurations..."
  rm -rf "$HOME/.local/share/dashboard-manage"
  rm -rf "$HOME/.config/dashboard-manage"
  if [ -n "$WEB_DIR" ] && [ -d "$WEB_DIR" ]; then
    rm -rf "$WEB_DIR"
    echo -e "${GREEN}✓${NC} Removed $WEB_DIR"
  fi
  echo -e "${GREEN}✓${NC} Purged dashboard files and configurations"
fi

echo -e "\n${GREEN}=====================================================${NC}"
echo -e "${GREEN}✓ Uninstallation complete!${NC}"
echo -e "${GREEN}=====================================================${NC}"
