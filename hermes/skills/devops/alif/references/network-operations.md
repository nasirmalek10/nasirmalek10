# Network Operations

Troubleshooting method and working knowledge for gateways, OPNsense, routing, NAT, VLANs, firewalls, DHCP, DNS, DNSSEC, Pi-hole, encrypted DNS, and remote access.

Menu paths and CLI details change between releases. **Confirm the user's platform and version before giving exact paths or commands**, and say so when you are going from general knowledge.

## Contents

- Layered troubleshooting
- OPNsense
- VLANs
- DHCP
- Routing and MTU
- IPv6
- DNS, DNSSEC, and Pi-hole
- Encrypted DNS and enforcing the resolver
- Remote access and VPN
- Linux host networking

## Layered Troubleshooting

Stop at the first layer that fails; that is where the cause is.

| Layer | Question | Linux | Windows (PowerShell) |
|---|---|---|---|
| Link | Is the interface up with carrier? | `ip -br link`, `ethtool <IF>` | `Get-NetAdapter` |
| Address | Correct IP, mask, VLAN? Got a DHCP lease? | `ip -br addr` | `ipconfig /all` |
| Gateway | Is the default gateway reachable? | `ip route`, `ping -c3 <GW_IP>` | `Get-NetRoute -DestinationPrefix 0.0.0.0/0`, `ping <GW_IP>` |
| Path | Where does traffic stop? | `tracepath -n <HOST>`, `mtr -n <HOST>` | `tracert -d <HOST>` |
| Firewall/NAT | Is it being blocked or not translated? | firewall live log, packet capture | same |
| DNS | Does the name resolve, and via which server? | `dig <NAME>`, `dig @<DNS_IP> <NAME>`, `resolvectl status` | `Resolve-DnsName <NAME> -Server <DNS_IP>` |
| Port | Is the service reachable? | `nc -zv <HOST> <PORT>`, `curl -v <URL>` | `Test-NetConnection <HOST> -Port <PORT>` |
| TLS | Right certificate and chain? | `openssl s_client -connect <HOST>:443 -servername <HOST>` | browser certificate viewer |
| App | What does the service log say? | `journalctl -u <UNIT>`, `docker logs <NAME>` | Event Viewer |

Symptoms that point straight at a layer:

- **Works by IP, fails by name** → DNS.
- **Works from LAN, fails from a VLAN** → inter-VLAN firewall rules, or DHCP handing out the wrong DNS or gateway.
- **Outbound works, inbound doesn't** → port forward, WAN rules, the service's bind address, or CGNAT (WAN IP in `100.64.0.0/10`, or WAN IP differs from your public IP).
- **Some sites or large transfers hang, small requests work** → MTU/MSS (PPPoE, VPN tunnels).
- **One domain fails with SERVFAIL** → DNSSEC or that domain's authoritative servers.
- **Worked until a reboot or lease renewal** → DHCP options, static mapping, or a service not enabled at boot.

## OPNsense

### Configuration safety

- Active config lives in `/conf/config.xml`. Every save keeps a revision under **System → Configuration → History**, where you can diff and revert.
- Download a backup from **System → Configuration → Backups** before any change. Tell the user to store it safely: it contains password hashes, VPN keys, and certificates.
- On ZFS installs, recent releases can also take a boot-environment snapshot (**System → Snapshots**) before upgrades.
- **Console recovery** (physical, serial, IPMI, or hypervisor console): the console menu can reassign interfaces, set interface IPs, reset the root password, and restore a previous configuration from history. Confirm the user has console access before changes that could cut off the GUI.
- The **anti-lockout rule** on LAN keeps the GUI and SSH reachable from LAN. Do not disable it until an explicit management rule exists and has been tested.

### Firewall rule processing

- Evaluation order: **Floating rules → interface group rules → interface rules**. On interface rules the first match wins.
- Rules apply on the interface where traffic **enters** the firewall. To control what a VLAN can reach, put the rules on that VLAN's interface.
- The firewall is stateful: return traffic is allowed automatically, so never add rules for replies.
- A new interface or VLAN has **no pass rules**, so everything from it is blocked until you add them. Fresh installs include default allow rules on LAN only.
- Use aliases (hosts, networks, ports) so rules stay readable.
- To see what a rule is actually doing: **Firewall → Log Files → Live View** filtered by source IP (enable logging on the rule first), packet capture under **Interfaces → Diagnostics**, and from the shell `pfctl -s rules` and `pfctl -s states | grep <IP>`.
- `pfctl -d` disables the packet filter entirely (all rules **and NAT** stop). It is a console-only emergency tool; re-enable with `pfctl -e` and tell the user the exposure.

### NAT

- **Port forwards** (Firewall → NAT → Port Forward) need a matching pass rule; OPNsense can create an associated filter rule automatically.
- **Outbound NAT** modes are automatic, hybrid, manual, or disabled. In **manual** mode a newly added VLAN or VPN subnet has no outbound translation, which shows up as "new network has no internet".
- To reach internal services by their public name from inside, prefer **split-horizon DNS** (an Unbound host override or Pi-hole local DNS record pointing at the internal IP) over NAT reflection.
- Before opening any port forward, run the Risk Gate: what is exposed, is it authenticated, is it patched, could a VPN or authenticated tunnel do the job instead?

## VLANs

Checklist for a new VLAN on OPNsense:

1. Create the VLAN device (parent interface plus tag). Recent releases put this under **Interfaces → Devices → VLAN**; older ones under **Interfaces → Other Types → VLAN**.
2. Assign it, enable it, and give it a static IP (the VLAN's gateway address).
3. Enable DHCP for it (range, DNS server, gateway).
4. Add firewall rules on the new interface (see below).
5. Check outbound NAT if it is in manual mode.
6. Switch: the port to OPNsense is a **trunk** carrying the tagged VLANs; client ports are **access** ports (untagged, with the port VLAN ID/PVID set). Many smart switches need both membership and PVID set.
7. Wi-Fi: map the SSID to the VLAN, and make the AP's uplink port a trunk.
8. Test from a client on the VLAN: DHCP lease, gateway ping, DNS query, internet, and that blocked networks really are blocked.

Isolated VLAN (IoT, guest) rule pattern, top to bottom on that VLAN's interface:

1. Pass `<VLAN_NET>` → `<DNS_SERVER_IP>` TCP/UDP 53
2. Pass `<VLAN_NET>` → `<NTP_SERVER_IP>` UDP 123 (if the firewall serves NTP)
3. Block `<VLAN_NET>` → **This Firewall** (otherwise the GUI stays reachable via the WAN address)
4. Block `<VLAN_NET>` → `RFC1918` alias (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`)
5. Pass `<VLAN_NET>` → any (internet)

Add explicit pass rules above the blocks for anything the VLAN legitimately needs, such as a trusted LAN reaching IoT devices. That rule goes on the **LAN** interface, and state handles the replies.

## DHCP

- Find out which DHCP service is actually running. Depending on release and setup, OPNsense may use ISC DHCP, Kea, or Dnsmasq. Don't give settings for the wrong one.
- The **DNS server option** decides which resolver clients use. For Pi-hole filtering, hand out the Pi-hole IP, or clients will bypass it.
- Use static mappings (reservations) for servers, printers, the Pi-hole, and access points, and keep them outside the dynamic range.
- After changing options, clients keep the old ones until renewal: `sudo dhclient -r && sudo dhclient <IF>`, `sudo networkctl renew <IF>`, `nmcli connection up <CON>`, or `ipconfig /release` then `ipconfig /renew`.
- Before a planned DHCP or DNS change, lower the lease time a day ahead so clients pick up the new options quickly.

## Routing and MTU

- A static route's gateway must be on a directly connected subnet. The **return path** must exist too; asymmetric routing breaks stateful firewalls.
- Policy routing (a firewall rule that sets a gateway) also catches traffic for local networks and VPNs. Put a pass rule for local destinations, without a gateway, above it.
- Multi-WAN: gateway groups with tiers, and monitor IPs that really reflect upstream health.
- MTU test: Linux `ping -M do -s 1472 <HOST>`, Windows `ping -f -l 1472 <HOST>` (1472 + 28 bytes of headers = 1500). Lower the size until it passes. Fix with the correct interface MTU or MSS clamping on PPPoE and tunnel interfaces.

## IPv6

- Clients can learn DNS servers from router advertisements (RDNSS) or DHCPv6 and bypass the IPv4 Pi-hole. Check `resolvectl status` or `ipconfig /all`.
- Firewall rules must cover IPv6 as well. Allow the ICMPv6 that neighbor discovery and path MTU discovery need.
- If IPv6 is half-configured, clients may try it first and stall. Either configure it properly or disable it consistently, and tell the user which you chose.

## DNS, DNSSEC, and Pi-hole

### Map the chain first

`client → resolver from DHCP (e.g. Pi-hole) → upstream (Unbound on OPNsense, local Unbound, or a public DoT/DoH provider) → authoritative servers`

- **Avoid loops.** If OPNsense Unbound forwards to Pi-hole, Pi-hole must not use OPNsense as its upstream. Pick one direction.
- Pi-hole **conditional forwarding** (local reverse lookups and hostnames to OPNsense) is fine, as long as OPNsense doesn't forward those names back to Pi-hole.
- **Local names:** register DHCP leases in Unbound, or use Pi-hole local DNS records. Keep one source of truth.

### Tests

```sh
dig @<PIHOLE_IP> example.com              # resolve through Pi-hole directly
dig @<PIHOLE_IP> <A_BLOCKED_DOMAIN>        # blocked: 0.0.0.0 or NXDOMAIN, depending on blocking mode
dig @<RESOLVER_IP> example.com +dnssec     # "ad" flag = validated by the resolver
dig @<RESOLVER_IP> dnssec-failed.org       # validating resolver: SERVFAIL
dig @<RESOLVER_IP> dnssec-failed.org +cd   # answer returned: the SERVFAIL was DNSSEC
delv @<RESOLVER_IP> example.com            # validate locally, with the reason for failures
```

Windows: `Resolve-DnsName example.com -Server <DNS_IP>`, `Get-DnsClientServerAddress`, `ipconfig /flushdns`.

Flush caches when testing a fix: `resolvectl flush-caches` (systemd-resolved), `pihole reloaddns` (Pi-hole v6) or `pihole restartdns` (v5), the browser's DNS cache, and any Unbound cache on OPNsense.

### DNSSEC

- **SERVFAIL for one domain, and it resolves with `+cd`** → a DNSSEC failure. Usually the domain's problem; confirm with an external validator before changing anything locally.
- **SERVFAIL for many signed domains** → check the resolver's **clock** first (signatures have validity windows), then trust anchors, then whether a middlebox strips DNSSEC records.
- Validate in one place, normally the recursive resolver (Unbound). Enabling DNSSEC in Pi-hole as well is redundant when the upstream already validates. It helps with debugging but isn't needed.

### Pi-hole

- Check the version first (`pihole -v`). **v6 differs substantially from v5:** built-in web server (no lighttpd), config in `/etc/pihole/pihole.toml`, a REST API, and `pihole-FTL --config <key> <value>` for settings.
- **"A site or app is broken"** → watch the Query Log for that client while reproducing, find the blocked domain, and allowlist only what's needed. `pihole -q <domain>` shows which list blocks it.
- **Pi-hole in Docker on a systemd-resolved host:** port 53 conflicts with the stub listener. Check with `sudo ss -lunp 'sport = :53'`. Set `DNSStubListener=no` in `/etc/systemd/resolved.conf`, point `/etc/resolv.conf` at a working resolver, and restart systemd-resolved. Warn the user this changes the host's own DNS.
- **Pi-hole in Docker with bridge networking** sees every query as coming from the Docker gateway, so per-client stats and rules stop working. Use host networking or macvlan if per-client visibility matters.
- Give Pi-hole a static IP (reservation or static config) and a secondary plan: a second Pi-hole, or a documented fallback. When the only DNS server goes down, "the internet is down" for everyone.

## Encrypted DNS and Enforcing the Resolver

### Encrypted upstream

- **Unbound DNS over TLS** (OPNsense: Services → Unbound DNS → DNS over TLS; or `forward-tls-upstream: yes` with `forward-addr: <IP>@853#<TLS_HOSTNAME>` in `unbound.conf`). The hostname is needed for certificate verification.
- **dnscrypt-proxy** as a local DoH/DNSCrypt client, with Pi-hole's upstream set to `127.0.0.1#<PORT>`.
- Cloudflare has deprecated `cloudflared`'s DNS-proxy mode. Check its current status before recommending it.
- Explain the trade-off: forwarding to a public encrypted resolver hides queries from the ISP but trusts that provider; full recursion (Unbound without forwarding) trusts no single provider but sends queries to authoritative servers unencrypted.

### Keeping clients on the local resolver

- NAT redirect on each internal interface: TCP/UDP 53 **not destined to** the Pi-hole → Pi-hole. Exclude the Pi-hole itself as a source so its upstream queries don't loop.
- Block outbound TCP 853 (DoT) from clients, except from the resolver itself.
- DoH can only be reduced, not fully blocked: use DoH-provider blocklists. Pi-hole answers Firefox's canary domain (`use-application-dns.net`) so Firefox disables its automatic DoH.
- Verify from a client: `dig @1.1.1.1 <A_BLOCKED_DOMAIN>` should now return the Pi-hole's blocked answer, and the query should appear in Pi-hole's log.

## Remote Access and VPN

- Never expose admin interfaces (OPNsense, Portainer, Pi-hole, hypervisors, NAS) directly to the internet. Use a VPN or an authenticated tunnel.
- **WireGuard:** `AllowedIPs` is both routing and access control. Home and remote subnets must not overlap. Use `PersistentKeepalive` behind NAT. Add firewall rules on the WireGuard interface, and outbound NAT for the tunnel subnet if clients should reach the internet through it. Tell clients which DNS server to use.
- **CGNAT** (WAN IP in `100.64.0.0/10`): inbound port forwards cannot work. Use a VPN with an outbound connection, a tunnel, a VPS relay, or IPv6.
- Changing the VPN you are connected through is a lockout risk; see `change-safety-and-release.md`.

## Linux Host Networking

- Find which component manages the interfaces before editing anything: netplan (`/etc/netplan/`), NetworkManager (`nmcli`), systemd-networkd (`networkctl`), or ifupdown (`/etc/network/interfaces`).
- `sudo netplan try` applies a change and reverts automatically after 120 seconds unless confirmed. Use it for remote changes on netplan hosts.
- Find which firewall is active (nftables, iptables, UFW, firewalld) and remember Docker adds its own rules (see `containers-and-services.md`).
- **SSH changes:** validate with `sudo sshd -t` before reloading, keep the current session open, and test a new login in a second terminal. On Ubuntu 22.10 and later, sshd is socket-activated by default: changing `Port` or `ListenAddress` needs `sudo systemctl daemon-reload && sudo systemctl restart ssh.socket`.
- Time sync (`timedatectl`) matters for TLS, DNSSEC, TOTP, and log correlation. Check it early.
