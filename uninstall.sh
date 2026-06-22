#!/usr/bin/env bash
# Flowtriq cPanel/WHM DDoS Detection Plugin - Uninstaller
set -euo pipefail

PLUGIN_DIR="/usr/local/cpanel/whostmgr/docroot/cgi/flowtriq"
APP_REG_DIR="/var/cpanel/apps"
CGI_DIR="/usr/local/cpanel/whostmgr/docroot/cgi"
ADDON_FEATURES="/usr/local/cpanel/whostmgr/addonfeatures"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[Flowtriq]${NC} $1"; }
warn()  { echo -e "${YELLOW}[Flowtriq]${NC} $1"; }
error() { echo -e "${RED}[Flowtriq]${NC} $1" >&2; }

# ─────────────────────────────────────────────
# Preflight
# ─────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
    error "This uninstaller must be run as root. Use: sudo bash uninstall.sh"
    exit 1
fi

echo ""
echo -e "${CYAN}Flowtriq cPanel Plugin - Uninstaller${NC}"
echo ""

read -rp "This will remove the Flowtriq WHM plugin and ftagent. Continue? [y/N]: " CONFIRM
if [[ "${CONFIRM,,}" != "y" ]]; then
    echo "Aborted."
    exit 0
fi

# ─────────────────────────────────────────────
# Stop and remove ftagent
# ─────────────────────────────────────────────

log "Stopping ftagent service..."
systemctl stop ftagent 2>/dev/null || true
systemctl disable ftagent 2>/dev/null || true

log "Removing ftagent..."
pip3 uninstall -y ftagent 2>/dev/null || warn "ftagent was not installed via pip"

# ─────────────────────────────────────────────
# Remove WHM plugin
# ─────────────────────────────────────────────

log "Removing WHM plugin files..."

rm -rf "$PLUGIN_DIR"
rm -f "$CGI_DIR/addon_flowtriq.cgi"
rm -f "$APP_REG_DIR/flowtriq.conf"
rm -f "$ADDON_FEATURES/flowtriq"

# Rebuild WHM chrome
/usr/local/cpanel/bin/rebuild_whm_chrome 2>/dev/null || warn "Could not rebuild WHM chrome"

# ─────────────────────────────────────────────
# Optionally remove config
# ─────────────────────────────────────────────

if [[ -d /etc/ftagent ]]; then
    read -rp "Remove ftagent configuration (/etc/ftagent)? [y/N]: " RMCONF
    if [[ "${RMCONF,,}" == "y" ]]; then
        rm -rf /etc/ftagent
        log "Configuration removed"
    else
        log "Configuration preserved at /etc/ftagent"
    fi
fi

echo ""
echo -e "${GREEN}Flowtriq has been removed from this server.${NC}"
echo ""
