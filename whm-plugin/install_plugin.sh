#!/usr/bin/env bash
# Flowtriq WHM Plugin Registration Script
# Registers the Flowtriq plugin with WHM's plugin system.
# Normally called by install.sh, but can be run standalone.
set -euo pipefail

PLUGIN_DIR="/usr/local/cpanel/whostmgr/docroot/cgi/flowtriq"
APP_REG_DIR="/var/cpanel/apps"
CGI_DIR="/usr/local/cpanel/whostmgr/docroot/cgi"
ADDON_FEATURES="/usr/local/cpanel/whostmgr/addonfeatures"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[Flowtriq]${NC} $1"; }
warn()  { echo -e "${YELLOW}[Flowtriq]${NC} $1"; }
fatal() { echo -e "${RED}[Flowtriq]${NC} $1" >&2; exit 1; }

# ─────────────────────────────────────────────
# Checks
# ─────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
    fatal "Must be run as root"
fi

if [[ ! -d /usr/local/cpanel ]]; then
    fatal "cPanel not found"
fi

# ─────────────────────────────────────────────
# Install plugin files
# ─────────────────────────────────────────────

log "Creating plugin directory..."
mkdir -p "$PLUGIN_DIR"

log "Copying plugin files..."
cp "$SCRIPT_DIR/flowtriq.php" "$PLUGIN_DIR/flowtriq.php"
chmod 0755 "$PLUGIN_DIR"
chmod 0644 "$PLUGIN_DIR/flowtriq.php"

# ─────────────────────────────────────────────
# Create CGI wrapper
# ─────────────────────────────────────────────

log "Creating CGI wrapper..."
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

# ─────────────────────────────────────────────
# Register with WHM app catalog
# ─────────────────────────────────────────────

log "Registering with WHM..."
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

# ─────────────────────────────────────────────
# Register addon feature
# ─────────────────────────────────────────────

log "Registering addon feature..."
mkdir -p "$ADDON_FEATURES"
echo "flowtriq:Flowtriq DDoS Detection" > "$ADDON_FEATURES/flowtriq"
chmod 0644 "$ADDON_FEATURES/flowtriq"

# ─────────────────────────────────────────────
# Rebuild WHM chrome
# ─────────────────────────────────────────────

log "Rebuilding WHM interface..."
/usr/local/cpanel/bin/rebuild_whm_chrome 2>/dev/null || warn "Could not rebuild WHM chrome"

log "Plugin registered. Access it in WHM under Plugins > Flowtriq DDoS Detection"
