<h1 align="center">Flowtriq for cPanel/WHM</h1>

<h3 align="center">DDoS detection for your hosting server.</h3>

<p align="center">
  <a href="#quick-start">Quick Start</a> &bull;
  <a href="#whm-plugin">WHM Plugin</a> &bull;
  <a href="#what-you-get">Features</a> &bull;
  <a href="#troubleshooting">Troubleshooting</a> &bull;
  <a href="https://discord.gg/SsTWMYuyGG">Discord</a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License"></a>
  <a href="https://flowtriq.com"><img src="https://img.shields.io/badge/flowtriq-dashboard-00d4aa?style=flat-square" alt="Dashboard"></a>
  <a href="https://pypi.org/project/ftagent/"><img src="https://img.shields.io/pypi/v/ftagent?style=flat-square&label=ftagent&color=3776AB" alt="ftagent"></a>
  <a href="https://discord.gg/SsTWMYuyGG"><img src="https://img.shields.io/badge/discord-join-5865F2?style=flat-square" alt="Discord"></a>
</p>

<p align="center">
  <b><a href="https://flowtriq.com/integrations/cpanel">Integration Guide</a></b> | <b><a href="https://flowtriq.com/docs">Documentation</a></b> | <b><a href="https://flowtriq.com/signup">Sign Up</a></b>
</p>

---

<p align="center">
  <img src="https://raw.githubusercontent.com/Flowtriq/flowtriq-cpanel/main/.github/architecture.svg" alt="Architecture" width="680">
</p>

---

cPanel servers are high-value DDoS targets: shared hosting, game servers, ecommerce, and high-traffic sites all live on cPanel infrastructure. This integration installs [ftagent](https://github.com/Flowtriq/ftagent) as a lightweight systemd service on your server, monitors traffic in real time, and reports to the [Flowtriq dashboard](https://flowtriq.com). A WHM plugin gives you at-a-glance status and service controls directly in your hosting panel.

## Quick Start

SSH into your cPanel server as root and run:

```sh
curl -fsSL https://raw.githubusercontent.com/Flowtriq/flowtriq-cpanel/main/install.sh | bash
```

The installer will:

1. Verify you are on a cPanel server
2. Install ftagent via pip
3. Run interactive setup (you will need your Flowtriq API key)
4. Start the ftagent service
5. Register the WHM plugin

After install, find **Flowtriq DDoS Detection** in WHM under **Plugins**.

## Manual Install

```sh
# 1. Install ftagent
pip3 install ftagent

# 2. Configure (have your API key ready)
ftagent --setup

# 3. Start the service
systemctl enable ftagent
systemctl start ftagent

# 4. Install the WHM plugin
git clone https://github.com/Flowtriq/flowtriq-cpanel.git /tmp/flowtriq-cpanel
bash /tmp/flowtriq-cpanel/whm-plugin/install_plugin.sh

# 5. Verify
systemctl status ftagent
```

## WHM Plugin

The plugin appears in WHM under **Plugins > Flowtriq DDoS Detection** and shows:

| | |
|---|---|
| **Service Status** | Running/stopped indicator with uptime |
| **Agent Version** | Currently installed ftagent version |
| **Incidents** | Attacks detected in the last 24 hours |
| **Server Info** | IP address and hostname |
| **Controls** | Start, stop, and restart buttons |
| **Logs** | Recent ftagent log output |

## What You Get

| | |
|---|---|
| **Attack Detection** | Volumetric floods, SYN floods, DNS amplification, and dozens of other vectors |
| **Alerting** | Sub-second notifications when an incident is detected |
| **PCAP Evidence** | Packet captures for every incident |
| **Auto-Mitigation** | Upstream integration or local blocking rules |
| **WHM Dashboard** | Service status, incident count, and logs in your hosting panel |
| **Web Dashboard** | Full analytics at [app.flowtriq.com](https://app.flowtriq.com) |

## Requirements

| Requirement | Details |
|---|---|
| **cPanel/WHM** | Version 100+ (tested on 108, 110, 114) |
| **OS** | CentOS 7+, AlmaLinux 8+, CloudLinux 7+, Rocky Linux 8+ |
| **Python** | 3.8 or later |
| **Access** | Root (WHM) |
| **Account** | Free Flowtriq account at [flowtriq.com](https://flowtriq.com) |

## Troubleshooting

<details>
<summary><b>ftagent service not starting</b></summary>

```sh
# Check service status
systemctl status ftagent

# View recent logs
journalctl -u ftagent --no-pager -n 30

# Verify the binary is installed
which ftagent
```

</details>

<details>
<summary><b>WHM plugin not appearing</b></summary>

```sh
# Re-register the plugin
bash /tmp/flowtriq-cpanel/whm-plugin/install_plugin.sh

# Rebuild WHM chrome
/usr/local/cpanel/bin/rebuild_whm_chrome

# Verify plugin files exist
ls -la /usr/local/cpanel/whostmgr/docroot/cgi/flowtriq/
```

</details>

<details>
<summary><b>No incidents showing in dashboard</b></summary>

- Verify the agent is running: `systemctl status ftagent`
- Check that your API key is correct: `cat /etc/ftagent/config.json`
- Confirm the server can reach the Flowtriq API: `curl -s https://api.flowtriq.com/health`

</details>

<details>
<summary><b>CloudLinux or LiteSpeed compatibility</b></summary>

ftagent monitors at the network level, below the CloudLinux LVE container layer. No special configuration is needed. It works with LiteSpeed, Apache, Nginx, or any other web server running on the machine.

</details>

## Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/Flowtriq/flowtriq-cpanel/main/uninstall.sh | bash
```

Or manually:

```sh
systemctl stop ftagent
systemctl disable ftagent
pip3 uninstall ftagent
rm -rf /usr/local/cpanel/whostmgr/docroot/cgi/flowtriq
rm -f /usr/local/cpanel/whostmgr/docroot/cgi/addon_flowtriq.cgi
rm -f /var/cpanel/apps/flowtriq.conf
rm -f /usr/local/cpanel/whostmgr/addonfeatures/flowtriq
/usr/local/cpanel/bin/rebuild_whm_chrome
```

## FAQ

<details>
<summary><b>Does this slow down my server?</b></summary>

No. ftagent uses less than 2% CPU and under 50 MB of RAM. It passively monitors network traffic and does not intercept or modify packets in normal operation.

</details>

<details>
<summary><b>Can I use this on a VPS?</b></summary>

Yes, as long as your VPS runs cPanel/WHM. Works on dedicated servers and VPS alike.

</details>

<details>
<summary><b>What attacks does it detect?</b></summary>

Volumetric floods (UDP, ICMP), SYN floods, DNS amplification, NTP reflection, HTTP floods, and dozens of other attack vectors. See the [Flowtriq docs](https://flowtriq.com/docs) for the full list.

</details>

<details>
<summary><b>Where do I get my API key?</b></summary>

Sign up at [flowtriq.com](https://flowtriq.com), then go to **Settings > API** in your dashboard.

</details>

<details>
<summary><b>How do I update ftagent?</b></summary>

```sh
pip3 install --upgrade ftagent
systemctl restart ftagent
```

</details>

## Links

- [Flowtriq Website](https://flowtriq.com)
- [Dashboard](https://app.flowtriq.com)
- [Documentation](https://flowtriq.com/docs)
- [Discord Community](https://discord.gg/SsTWMYuyGG)
- [ftagent on PyPI](https://pypi.org/project/ftagent/)

## Get Started

Start your free 14-day trial at [flowtriq.com/signup](https://flowtriq.com/signup).

## License

MIT. See [LICENSE](LICENSE).

---

Built by [Flowtriq](https://flowtriq.com) - Real-time DDoS detection and mitigation.
