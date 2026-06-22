<?php
/**
 * Flowtriq DDoS Detection - WHM Plugin
 *
 * Displays ftagent status, node info, and service controls
 * within the WHM interface.
 */

// Only allow WHM root access
if (!isset($_ENV['REMOTE_USER']) && php_sapi_name() !== 'cli') {
    // Running inside cPanel CGI context, which handles auth
}

// ─────────────────────────────────────────────
// Service control actions
// ─────────────────────────────────────────────

$action_message = '';
$action_type = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    $action = $_POST['action'];
    $allowed = ['start', 'stop', 'restart'];

    if (in_array($action, $allowed, true)) {
        $cmd = escapeshellcmd("systemctl $action ftagent 2>&1");
        $output = shell_exec($cmd);
        $result = shell_exec("systemctl is-active ftagent 2>&1");
        $action_message = ucfirst($action) . " command executed.";
        $action_type = (trim($result) === 'active') ? 'success' : 'info';
    }
}

// ─────────────────────────────────────────────
// Gather system info
// ─────────────────────────────────────────────

function get_service_status() {
    $status = trim(shell_exec("systemctl is-active ftagent 2>&1") ?? '');
    return $status ?: 'unknown';
}

function get_service_uptime() {
    $raw = shell_exec("systemctl show ftagent --property=ActiveEnterTimestamp 2>/dev/null");
    if ($raw) {
        $parts = explode('=', $raw, 2);
        if (isset($parts[1]) && trim($parts[1]) !== '') {
            $since = strtotime(trim($parts[1]));
            if ($since) {
                $diff = time() - $since;
                if ($diff < 60) return "{$diff}s";
                if ($diff < 3600) return floor($diff / 60) . "m";
                if ($diff < 86400) return floor($diff / 3600) . "h " . floor(($diff % 3600) / 60) . "m";
                return floor($diff / 86400) . "d " . floor(($diff % 86400) / 3600) . "h";
            }
        }
    }
    return '-';
}

function get_ftagent_version() {
    $version = trim(shell_exec("ftagent --version 2>/dev/null") ?? '');
    return $version ?: 'not installed';
}

function get_node_info() {
    $info = [
        'ip' => trim(shell_exec("hostname -I 2>/dev/null | awk '{print \$1}'") ?? ''),
        'hostname' => trim(shell_exec("hostname -f 2>/dev/null") ?? ''),
    ];

    // Try to read config for API key presence
    $config_file = '/etc/ftagent/config.json';
    if (file_exists($config_file)) {
        $config = json_decode(file_get_contents($config_file), true);
        $info['configured'] = !empty($config['api_key']);
        $info['dashboard_id'] = $config['node_id'] ?? '';
    } else {
        $info['configured'] = false;
        $info['dashboard_id'] = '';
    }

    return $info;
}

function get_recent_log_lines($n = 20) {
    $output = shell_exec("journalctl -u ftagent --no-pager -n $n --output=short-iso 2>/dev/null");
    return $output ? trim($output) : 'No logs available';
}

function get_incident_count() {
    // Count lines mentioning incidents/attacks in recent logs
    $output = shell_exec("journalctl -u ftagent --since '24 hours ago' --no-pager 2>/dev/null | grep -ciE 'attack|incident|alert|mitigat' 2>/dev/null");
    return intval(trim($output ?? '0'));
}

$status = get_service_status();
$uptime = get_service_uptime();
$version = get_ftagent_version();
$node = get_node_info();
$incidents_24h = get_incident_count();
$logs = get_recent_log_lines(30);

$status_color = ($status === 'active') ? '#22c55e' : (($status === 'inactive') ? '#ef4444' : '#f59e0b');
$status_label = ($status === 'active') ? 'Running' : (($status === 'inactive') ? 'Stopped' : ucfirst($status));

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Flowtriq DDoS Detection</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            background: #f8fafc;
            color: #1e293b;
            line-height: 1.6;
            padding: 24px;
        }

        .ft-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 24px;
            padding-bottom: 16px;
            border-bottom: 2px solid #e2e8f0;
        }

        .ft-header h1 {
            font-size: 24px;
            font-weight: 700;
            color: #0f172a;
        }

        .ft-header h1 span {
            color: #3b82f6;
        }

        .ft-header-links a {
            display: inline-block;
            padding: 8px 16px;
            background: #3b82f6;
            color: #fff;
            text-decoration: none;
            border-radius: 6px;
            font-size: 14px;
            font-weight: 500;
            transition: background 0.2s;
        }

        .ft-header-links a:hover {
            background: #2563eb;
        }

        .ft-alert {
            padding: 12px 16px;
            border-radius: 8px;
            margin-bottom: 20px;
            font-size: 14px;
        }

        .ft-alert-success { background: #dcfce7; color: #166534; border: 1px solid #bbf7d0; }
        .ft-alert-info    { background: #dbeafe; color: #1e40af; border: 1px solid #bfdbfe; }
        .ft-alert-warning { background: #fef3c7; color: #92400e; border: 1px solid #fde68a; }

        .ft-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }

        .ft-card {
            background: #fff;
            border: 1px solid #e2e8f0;
            border-radius: 10px;
            padding: 20px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.04);
        }

        .ft-card-label {
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: #64748b;
            margin-bottom: 6px;
        }

        .ft-card-value {
            font-size: 22px;
            font-weight: 700;
            color: #0f172a;
        }

        .ft-card-sub {
            font-size: 13px;
            color: #94a3b8;
            margin-top: 4px;
        }

        .ft-status-dot {
            display: inline-block;
            width: 10px;
            height: 10px;
            border-radius: 50%;
            margin-right: 8px;
            vertical-align: middle;
        }

        .ft-section {
            background: #fff;
            border: 1px solid #e2e8f0;
            border-radius: 10px;
            padding: 20px;
            margin-bottom: 24px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.04);
        }

        .ft-section h2 {
            font-size: 16px;
            font-weight: 600;
            color: #0f172a;
            margin-bottom: 16px;
        }

        .ft-controls {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }

        .ft-btn {
            display: inline-block;
            padding: 8px 20px;
            border: none;
            border-radius: 6px;
            font-size: 14px;
            font-weight: 500;
            cursor: pointer;
            transition: opacity 0.2s;
        }

        .ft-btn:hover { opacity: 0.85; }

        .ft-btn-green  { background: #22c55e; color: #fff; }
        .ft-btn-red    { background: #ef4444; color: #fff; }
        .ft-btn-yellow { background: #f59e0b; color: #fff; }

        .ft-info-table {
            width: 100%;
            border-collapse: collapse;
        }

        .ft-info-table td {
            padding: 10px 12px;
            border-bottom: 1px solid #f1f5f9;
            font-size: 14px;
        }

        .ft-info-table td:first-child {
            font-weight: 600;
            color: #475569;
            width: 180px;
        }

        .ft-info-table td:last-child {
            color: #1e293b;
            font-family: "SF Mono", "Cascadia Code", "Fira Code", monospace;
            font-size: 13px;
        }

        .ft-logs {
            background: #0f172a;
            color: #e2e8f0;
            padding: 16px;
            border-radius: 8px;
            font-family: "SF Mono", "Cascadia Code", "Fira Code", monospace;
            font-size: 12px;
            line-height: 1.8;
            max-height: 400px;
            overflow-y: auto;
            white-space: pre-wrap;
            word-break: break-all;
        }

        .ft-footer {
            text-align: center;
            padding-top: 16px;
            color: #94a3b8;
            font-size: 13px;
        }

        .ft-footer a {
            color: #3b82f6;
            text-decoration: none;
        }

        .ft-not-configured {
            background: #fef3c7;
            border: 1px solid #fde68a;
            border-radius: 8px;
            padding: 16px;
            margin-bottom: 20px;
        }

        .ft-not-configured strong { color: #92400e; }
        .ft-not-configured code {
            background: #fff;
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 13px;
        }
    </style>
</head>
<body>

<div class="ft-header">
    <h1><span>Flowtriq</span> DDoS Detection</h1>
    <div class="ft-header-links">
        <a href="https://app.flowtriq.com" target="_blank">Open Dashboard</a>
    </div>
</div>

<?php if ($action_message): ?>
    <div class="ft-alert ft-alert-<?= htmlspecialchars($action_type) ?>">
        <?= htmlspecialchars($action_message) ?>
    </div>
<?php endif; ?>

<?php if (!$node['configured']): ?>
    <div class="ft-not-configured">
        <strong>ftagent is not configured.</strong>
        Run <code>ftagent --setup</code> as root to connect this server to your Flowtriq account.
    </div>
<?php endif; ?>

<!-- Status cards -->
<div class="ft-grid">
    <div class="ft-card">
        <div class="ft-card-label">Service Status</div>
        <div class="ft-card-value">
            <span class="ft-status-dot" style="background: <?= $status_color ?>"></span>
            <?= htmlspecialchars($status_label) ?>
        </div>
        <div class="ft-card-sub">Uptime: <?= htmlspecialchars($uptime) ?></div>
    </div>

    <div class="ft-card">
        <div class="ft-card-label">Agent Version</div>
        <div class="ft-card-value"><?= htmlspecialchars($version) ?></div>
        <div class="ft-card-sub">
            <a href="https://pypi.org/project/ftagent/" target="_blank" style="color:#3b82f6;text-decoration:none;font-size:13px;">Check for updates</a>
        </div>
    </div>

    <div class="ft-card">
        <div class="ft-card-label">Incidents (24h)</div>
        <div class="ft-card-value" style="color: <?= $incidents_24h > 0 ? '#ef4444' : '#22c55e' ?>">
            <?= $incidents_24h ?>
        </div>
        <div class="ft-card-sub"><?= $incidents_24h === 0 ? 'All clear' : 'Check dashboard for details' ?></div>
    </div>

    <div class="ft-card">
        <div class="ft-card-label">Server IP</div>
        <div class="ft-card-value" style="font-size:16px;"><?= htmlspecialchars($node['ip'] ?: 'Unknown') ?></div>
        <div class="ft-card-sub"><?= htmlspecialchars($node['hostname']) ?></div>
    </div>
</div>

<!-- Node info -->
<div class="ft-section">
    <h2>Node Information</h2>
    <table class="ft-info-table">
        <tr>
            <td>Hostname</td>
            <td><?= htmlspecialchars($node['hostname']) ?></td>
        </tr>
        <tr>
            <td>IP Address</td>
            <td><?= htmlspecialchars($node['ip'] ?: 'Unknown') ?></td>
        </tr>
        <tr>
            <td>Agent Version</td>
            <td><?= htmlspecialchars($version) ?></td>
        </tr>
        <tr>
            <td>Configuration</td>
            <td><?= $node['configured'] ? '<span style="color:#22c55e">Connected to Flowtriq</span>' : '<span style="color:#ef4444">Not configured</span>' ?></td>
        </tr>
        <?php if ($node['dashboard_id']): ?>
        <tr>
            <td>Node ID</td>
            <td><?= htmlspecialchars($node['dashboard_id']) ?></td>
        </tr>
        <?php endif; ?>
        <tr>
            <td>Service Status</td>
            <td><span style="color:<?= $status_color ?>"><?= htmlspecialchars($status_label) ?></span></td>
        </tr>
    </table>
</div>

<!-- Service controls -->
<div class="ft-section">
    <h2>Service Controls</h2>
    <div class="ft-controls">
        <form method="POST" style="display:inline">
            <input type="hidden" name="action" value="start">
            <button type="submit" class="ft-btn ft-btn-green" <?= $status === 'active' ? 'disabled style="opacity:0.5;cursor:default;background:#22c55e"' : '' ?>>
                Start
            </button>
        </form>
        <form method="POST" style="display:inline">
            <input type="hidden" name="action" value="stop">
            <button type="submit" class="ft-btn ft-btn-red" <?= $status !== 'active' ? 'disabled style="opacity:0.5;cursor:default;background:#ef4444"' : '' ?>>
                Stop
            </button>
        </form>
        <form method="POST" style="display:inline">
            <input type="hidden" name="action" value="restart">
            <button type="submit" class="ft-btn ft-btn-yellow">Restart</button>
        </form>
    </div>
</div>

<!-- Recent logs -->
<div class="ft-section">
    <h2>Recent Logs</h2>
    <div class="ft-logs"><?= htmlspecialchars($logs) ?></div>
</div>

<div class="ft-footer">
    Flowtriq DDoS Detection &middot;
    <a href="https://flowtriq.com" target="_blank">Website</a> &middot;
    <a href="https://docs.flowtriq.com" target="_blank">Documentation</a> &middot;
    <a href="https://discord.gg/flowtriq" target="_blank">Discord</a>
</div>

</body>
</html>
