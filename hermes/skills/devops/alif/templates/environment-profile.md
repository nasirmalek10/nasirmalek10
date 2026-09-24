# Environment Profile

What Alif keeps track of about the user's environment. Fill it in from evidence the user shares, save the confirmed facts to persistent memory, and update them when they change. Mark anything not yet confirmed as `UNCONFIRMED`.

**Never record passwords, keys, tokens, or recovery codes here.** Note only where they are kept (e.g. "in password manager").

## Access

| Item | Value |
|---|---|
| How the user reaches the firewall/gateway | <e.g. LAN GUI, SSH, console available? yes/no> |
| Out-of-band access | <physical console / IPMI / hypervisor console / none> |
| Remote access method | <WireGuard / Tailscale / Cloudflare Tunnel / none> |
| User's own privileges | <root/admin on which systems> |

## Hardware and Platforms

| Device | Role | OS / firmware + version | Notes |
|---|---|---|---|
| <DEVICE> | Firewall/gateway | <e.g. OPNsense 2x.x> | <interfaces, NIC names> |
| <DEVICE> | Switch | <model / firmware> | <managed? VLAN-capable?> |
| <DEVICE> | Access point | <model / firmware> | <SSID → VLAN mapping> |
| <DEVICE> | Docker host | <distro + version, Docker version> | <CPU/RAM/disk> |

## Network

| Network | VLAN ID | Subnet | Gateway | DHCP range | Purpose / rules summary |
|---|---|---|---|---|---|
| LAN | <untagged> | <SUBNET> | <GW_IP> | <RANGE> | <trusted> |
| <NAME> | <ID> | <SUBNET> | <GW_IP> | <RANGE> | <e.g. IoT, isolated> |

- WAN type: <DHCP / PPPoE / static>; public IPv4 or CGNAT: <...>; IPv6: <yes/no, prefix delegation?>
- DHCP service in use: <ISC / Kea / Dnsmasq / other>
- Static reservations of note: <host → IP>
- VPN subnets: <...>
- Docker address pools / bridge subnets: <...>

## DNS

- Chain: `clients → <RESOLVER> → <UPSTREAM> → <...>`
- Pi-hole: version <v5/v6>, host <HOST/IP>, install method <bare metal / Docker bridge / Docker host network / macvlan>
- Upstream encryption: <none / Unbound DoT / dnscrypt-proxy / ...>
- DNSSEC validation done by: <Unbound / Pi-hole / upstream provider>
- Local names come from: <Unbound DHCP registration / Pi-hole local DNS / ...>
- Split-horizon overrides: <name → internal IP>
- Enforcement: <port 53 redirect? DoT blocked? DoH lists?>

## Services

| Service | Host | Managed by | Compose file / stack | Exposed how | State location |
|---|---|---|---|---|---|
| <APP> | <HOST> | <CLI compose / Portainer / systemd> | <PATH or STACK NAME> | <LAN only / proxy / tunnel> | <VOLUME or PATH> |

- Reverse proxy: <Caddy / Traefik / nginx / NPM>, TLS via <HTTP-01 / DNS-01 provider>
- Domains: <DOMAIN(s)> (DNS hosted at <PROVIDER>)
- Monitoring and alert channel: <...>

## Applications Under Development

| App | Stack | Repo / path | Deploy method | Database | Test command |
|---|---|---|---|---|---|
| <APP> | <framework, language, version> | <...> | <...> | <engine + version> | <...> |

## Backups

| What | Tool | Schedule | Destination (onsite / offsite) | Last restore test |
|---|---|---|---|---|
| <...> | <...> | <...> | <...> | <DATE or never> |

## Preferences and Decisions

- Preferred tools, languages, frameworks: <...>
- Style preferences for explanations or code: <...>
- Decisions already made (and why): <...>
- Things not to change without asking: <...>
