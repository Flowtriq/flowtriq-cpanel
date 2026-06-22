# Flowtriq DDoS Detection for cPanel/WHM

One-click DDoS detection and traffic analysis for cPanel servers. Installs the Flowtriq agent and adds a WHM plugin so you can monitor protection status without leaving your hosting panel.

cPanel servers are high-value DDoS targets: shared hosting, game servers, ecommerce, and high-traffic sites all live on cPanel infrastructure. Flowtriq gives you real-time visibility into attacks the moment they start.

## How It Works

```
┌─────────────────────────────────────────────┐
│              cPanel Server                   │
│                                              │
│   ┌──────────┐         ┌──────────────────┐ │
│   │  ftagent  │────────>│  Flowtriq Cloud  │ │
│   │ (monitor) │<────────│   Dashboard      │ │
│   └──────────┘         └──────────────────┘ │
│        │                                     │
│   ┌────┴─────┐                               │
│   │ WHM      │                               │
│   │ Plugin   │  Status, controls, logs       │
│   └──────────┘                               │
└─────────────────────────────────────────────┘
```

**ftagent** runs as a lightweight systemd service on your server. It monitors network traffic in real time and reports to the Flowtriq dashboard. The WHM plugin gives you at-a-glance status and service controls directly in your hosting panel.

## Quick Install

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

If you prefer to install step by step:

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

## What You Get

- **Real-time attack detection** with sub-second alerting
- **Traffic classification** identifying volumetric floods, SYN floods, DNS amplification, and more
- **PCAP evidence capture** for every incident
- **Automated mitigation** via upstream integration or local blocking rules
- **WHM dashboard** showing service status, incident count, and logs
- **Full web dashboard** at [app.flowtriq.com](https://app.flowtriq.com) with historical data, analytics, and reports

## WHM Plugin

The plugin appears in WHM under **Plugins > Flowtriq DDoS Detection** and shows:

- Service status (running/stopped) with uptime
- Agent version
- Incidents detected in the last 24 hours
- Server IP and hostname
- Start / Stop / Restart controls
- Recent ftagent logs

## Requirements

| Requirement | Details |
|---|---|
| **cPanel/WHM** | Version 100+ (tested on 108, 110, 114) |
| **OS** | CentOS 7+, AlmaLinux 8+, CloudLinux 7+, Rocky Linux 8+ |
| **Python** | 3.8 or later |
| **Access** | Root (WHM) |
| **Account** | Free Flowtriq account at [flowtriq.com](https://flowtriq.com) |

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

**Does this slow down my server?**
No. ftagent uses less than 2% CPU and under 50 MB of RAM. It passively monitors network traffic and does not intercept or modify packets in normal operation.

**Does it work with CloudLinux?**
Yes. ftagent monitors at the network level, below the CloudLinux LVE container layer. No special configuration needed.

**Does it work with LiteSpeed?**
Yes. ftagent operates independently of your web server software. It works with LiteSpeed, Apache, Nginx, or any other web server running on the machine.

**Can I use this on a VPS?**
Yes, as long as your VPS runs cPanel/WHM. Works on dedicated servers and VPS alike.

**What attacks does it detect?**
Volumetric floods (UDP, ICMP), SYN floods, DNS amplification, NTP reflection, HTTP floods, and dozens of other attack vectors. See the [Flowtriq docs](https://docs.flowtriq.com) for the full list.

**Where do I get my API key?**
Sign up at [flowtriq.com](https://flowtriq.com), then go to **Settings > API** in your dashboard.

**How do I update ftagent?**
```sh
pip3 install --upgrade ftagent
systemctl restart ftagent
```

## Links

- [Flowtriq Website](https://flowtriq.com)
- [Dashboard](https://app.flowtriq.com)
- [Documentation](https://docs.flowtriq.com)
- [Discord Community](https://discord.gg/flowtriq)
- [ftagent on PyPI](https://pypi.org/project/ftagent/)

## License

MIT. See [LICENSE](LICENSE).
