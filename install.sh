#!/usr/bin/env bash
# Flowtriq cPanel/WHM DDoS Detection Plugin - Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/Flowtriq/flowtriq-cpanel/main/install.sh | bash
set -euo pipefail

PLUGIN_DIR="/usr/local/cpanel/whostmgr/docroot/cgi/flowtriq"
APP_REG_DIR="/var/cpanel/apps"
CGI_DIR="/usr/local/cpanel/whostmgr/docroot/cgi"
ADDON_FEATURES="/usr/local/cpanel/whostmgr/addonfeatures"
VERSION="1.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[Flowtriq]${NC} $1"; }
warn()  { echo -e "${YELLOW}[Flowtriq]${NC} $1"; }
error() { echo -e "${RED}[Flowtriq]${NC} $1" >&2; }
fatal() { error "$1"; exit 1; }

header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       Flowtriq DDoS Detection for cPanel        ║${NC}"
    echo -e "${CYAN}║              Installer v${VERSION}                  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ─────────────────────────────────────────────
# Preflight checks
# ─────────────────────────────────────────────

check_root() {
    if [[ $EUID -ne 0 ]]; then
        fatal "This installer must be run as root. Use: sudo bash install.sh"
    fi
}

check_cpanel() {
    if [[ ! -d /usr/local/cpanel ]]; then
        fatal "cPanel not detected. This plugin requires a cPanel/WHM server."
    fi
    log "cPanel detected at /usr/local/cpanel"

    # Check cPanel version (require 100+)
    if command -v /usr/local/cpanel/cpanel &>/dev/null; then
        CPANEL_VERSION=$(/usr/local/cpanel/cpanel -V 2>/dev/null | head -1 | grep -oP '[\d]+' | head -1 || echo "0")
        if [[ "$CPANEL_VERSION" -lt 100 ]]; then
            warn "cPanel version $CPANEL_VERSION detected. This plugin is tested with cPanel 100+."
            warn "Proceeding anyway, but some features may not work correctly."
        else
            log "cPanel version $CPANEL_VERSION confirmed"
        fi
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        log "OS detected: $PRETTY_NAME"
    elif [[ -f /etc/redhat-release ]]; then
        log "OS detected: $(cat /etc/redhat-release)"
    fi
}

check_python() {
    if command -v python3 &>/dev/null; then
        PY_VERSION=$(python3 --version 2>&1 | grep -oP '[\d]+\.[\d]+')
        PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
        PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)
        if [[ "$PY_MAJOR" -lt 3 ]] || [[ "$PY_MAJOR" -eq 3 && "$PY_MINOR" -lt 8 ]]; then
            fatal "Python 3.8+ required, found Python $PY_VERSION"
        fi
        log "Python $PY_VERSION detected"
    else
        fatal "Python 3 not found. Install Python 3.8+ before continuing."
    fi

    if ! command -v pip3 &>/dev/null; then
        warn "pip3 not found, attempting to install..."
        if command -v dnf &>/dev/null; then
            dnf install -y python3-pip || fatal "Failed to install pip3"
        elif command -v yum &>/dev/null; then
            yum install -y python3-pip || fatal "Failed to install pip3"
        else
            fatal "pip3 not found and could not install automatically"
        fi
    fi
}

# ─────────────────────────────────────────────
# Install ftagent
# ─────────────────────────────────────────────

install_ftagent() {
    if command -v ftagent &>/dev/null; then
        log "ftagent already installed, upgrading..."
        pip3 install --upgrade ftagent
    else
        log "Installing ftagent..."
        pip3 install ftagent
    fi

    if ! command -v ftagent &>/dev/null; then
        fatal "ftagent installation failed. Check pip output above."
    fi

    FTAGENT_VERSION=$(ftagent --version 2>/dev/null || echo "unknown")
    log "ftagent installed: $FTAGENT_VERSION"
}

configure_ftagent() {
    if [[ -f /etc/ftagent/config.json ]]; then
        log "ftagent configuration already exists at /etc/ftagent/config.json"
        read -rp "Reconfigure ftagent? [y/N]: " RECONF
        if [[ "${RECONF,,}" != "y" ]]; then
            return 0
        fi
    fi

    log "Running ftagent setup..."
    echo ""
    echo "You will need your Flowtriq API key from https://app.flowtriq.com/settings/api"
    echo ""
    ftagent --setup
}

start_ftagent() {
    log "Enabling ftagent systemd service..."

    systemctl daemon-reload
    systemctl enable ftagent
    systemctl start ftagent

    if systemctl is-active --quiet ftagent; then
        log "ftagent service is running"
    else
        warn "ftagent service failed to start. Check: systemctl status ftagent"
    fi
}

# ─────────────────────────────────────────────
# Install WHM plugin
# ─────────────────────────────────────────────

install_whm_plugin() {
    log "Installing WHM plugin..."

    # Create plugin directory
    mkdir -p "$PLUGIN_DIR"

    # Determine the source directory (if running from repo or via curl)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd 2>/dev/null || echo "")"

    if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/whm-plugin/flowtriq.php" ]]; then
        # Running from local repo
        cp "$SCRIPT_DIR/whm-plugin/flowtriq.php" "$PLUGIN_DIR/flowtriq.php"
        log "Plugin files copied from local repo"
    else
        # Running via curl pipe, download plugin file
        log "Downloading plugin files..."
        curl -fsSL "https://raw.githubusercontent.com/Flowtriq/flowtriq-cpanel/main/whm-plugin/flowtriq.php" \
            -o "$PLUGIN_DIR/flowtriq.php" || fatal "Failed to download plugin files"
    fi

    chmod 0755 "$PLUGIN_DIR"
    chmod 0644 "$PLUGIN_DIR/flowtriq.php"

    # Create CGI wrapper
    cat > "$CGI_DIR/addon_flowtriq.cgi" << 'CGIWRAPPER'
#!/usr/local/cpanel/3rdparty/bin/perl
use strict;
use warnings;

print "Content-Type: text/html\r\n\r\n";

my $php = "/usr/local/cpanel/3rdparty/bin/php";
$php = "/usr/bin/php" unless -x $php;

my $plugin_path = "/usr/local/cpanel/whostmgr/docroot/cgi/flowtriq/flowtriq.php";

if (-f $plugin_path && -x $php) {
    exec($php, $plugin_path);
} else {
    print "<h1>Flowtriq Plugin Error</h1>";
    print "<p>Plugin files not found. Please reinstall the Flowtriq cPanel plugin.</p>";
}
CGIWRAPPER

    chmod 0755 "$CGI_DIR/addon_flowtriq.cgi"

    # Register with WHM app catalog (cPanel 100+ method)
    mkdir -p "$APP_REG_DIR"
    cat > "$APP_REG_DIR/flowtriq.conf" << 'APPCONF'
apptype=whostmgr
name=Flowtriq DDoS Detection
url=cgi/addon_flowtriq.cgi
itemdesc=Flowtriq DDoS Detection
itemorder=100
group=Plugins
APPCONF

    chmod 0644 "$APP_REG_DIR/flowtriq.conf"

    # Register addon feature
    mkdir -p "$ADDON_FEATURES"
    echo "flowtriq:Flowtriq DDoS Detection" >> "$ADDON_FEATURES/flowtriq" 2>/dev/null || true
    chmod 0644 "$ADDON_FEATURES/flowtriq" 2>/dev/null || true

    # Rebuild WHM chrome (registers the plugin in the sidebar)
    /usr/local/cpanel/bin/rebuild_whm_chrome 2>/dev/null || warn "Could not rebuild WHM chrome. Plugin may not appear until next WHM restart."

    log "WHM plugin installed and registered"
}

# ─────────────────────────────────────────────
# Post-install
# ─────────────────────────────────────────────

show_success() {
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "YOUR_SERVER_IP")
    WHM_PORT="2087"

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          Installation Complete!                  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  WHM Plugin:    ${CYAN}https://${SERVER_IP}:${WHM_PORT}/cgi/addon_flowtriq.cgi${NC}"
    echo -e "  Dashboard:     ${CYAN}https://app.flowtriq.com${NC}"
    echo ""
    echo -e "  Service status:  systemctl status ftagent"
    echo -e "  View logs:       journalctl -u ftagent -f"
    echo -e "  Uninstall:       curl -fsSL https://raw.githubusercontent.com/Flowtriq/flowtriq-cpanel/main/uninstall.sh | bash"
    echo ""
    echo -e "  ${GREEN}Your server is now protected by Flowtriq.${NC}"
    echo ""
}

# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────

main() {
    header
    check_root
    check_cpanel
    check_os
    check_python
    install_ftagent
    configure_ftagent
    start_ftagent
    install_whm_plugin
    show_success
}

main "$@"
