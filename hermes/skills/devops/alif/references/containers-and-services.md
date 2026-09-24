# Containers and Services

Docker, Compose, Portainer, reverse proxies, tunnels, monitoring, and Linux host administration.

## Contents

- Discover before changing
- Compose standards
- Updating and rolling back
- Docker networking pitfalls
- Portainer
- Reverse proxies
- Tunnels
- Monitoring and alerting
- Linux host administration

## Discover Before Changing

Read-only commands to establish the current state (or run `scripts/docker-audit.sh`):

```sh
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
docker compose ls                           # compose projects and their config files
docker compose -f <COMPOSE_FILE> config     # rendered config with .env values substituted
docker inspect <CONTAINER>                  # mounts, networks, restart policy, env
docker logs --tail 200 <CONTAINER>
docker network ls && docker network inspect <NETWORK>
docker system df                            # disk used by images, containers, volumes
```

**Find out how each stack is managed** (a compose file on disk, a Portainer stack, or bare `docker run`) and change it the same way. Mixing methods causes drift.

## Compose Standards

- **Pin image versions** (a specific tag or digest). Avoid `latest` for anything you might need to roll back.
- `restart: unless-stopped` for long-running services.
- Healthchecks, plus `depends_on` with `condition: service_healthy` where start order matters.
- Secrets in `.env` (mode `600`, never committed) or Docker secrets. Commit an `.env.example` with labeled placeholders.
- Know where state lives: named volumes or bind mounts under a documented, backed-up path.
- **Publish ports only where needed**, and bind them to a specific address when only local or proxy access is required: `"127.0.0.1:8080:8080"`.
- Cap container logs to avoid filling disks:

  ```yaml
  logging:
    driver: json-file
    options:
      max-size: "10m"
      max-file: "3"
  ```

- Use user-defined networks; services reach each other by service name.
- Validate before applying: `docker compose config -q`.

## Updating and Rolling Back

1. Back up the stack's state (see `backup-and-recovery.md`), plus the compose file and `.env`.
2. Record what is running now: `docker compose images` (tags and image IDs).
3. Read the release notes for breaking changes and required migrations.
4. `docker compose pull && docker compose up -d`
5. Verify: `docker compose ps`, healthchecks, logs, and the application's key flows.
6. **Rollback:** set the previous tag in the compose file, run `docker compose up -d`, and restore data if the new version migrated it. Many applications cannot downgrade migrated data, which is why the backup comes first.

## Docker Networking Pitfalls

- **Published ports bypass UFW and firewalld.** Docker writes its own iptables rules, which are evaluated before the host firewall's rules. To restrict access, bind the port to `127.0.0.1` or a specific IP, don't publish it at all (reach it over a shared network from the reverse proxy), or add rules to the `DOCKER-USER` chain.
- **Subnet collisions.** Docker's default address pools can overlap LAN, VLAN, or VPN subnets, which makes some hosts unreachable from the Docker host. Fix it with `default-address-pools` in `/etc/docker/daemon.json`, then restart Docker and recreate the affected networks (a disruptive change; schedule it):

  ```json
  {
    "default-address-pools": [
      { "base": "<UNUSED_PRIVATE_RANGE e.g. 10.200.0.0/16>", "size": 24 }
    ]
  }
  ```

  Check the chosen range against every subnet in the environment profile first.
- **`localhost` inside a container is the container itself.** A proxy container must reach upstreams by service name on a shared network, or by the host's IP.
- **macvlan/ipvlan:** containers get LAN addresses, but the host cannot reach its own macvlan containers without an extra macvlan "shim" interface on the host.
- **Container DNS:** containers on user-defined networks use Docker's embedded resolver (`127.0.0.11`), which forwards to the host's resolvers. If the host's only resolver is a Pi-hole container on the same host, name resolution can fail during boot. Give the host a fallback resolver, or set `dns:` on the critical services.
- `network_mode: host` ignores `ports:`; the service binds directly on the host.

## Portainer

- Stacks created in Portainer are stored in Portainer's data volume. Stacks deployed from the CLI show up with limited control. Edit each stack where it was created.
- Back up Portainer's data volume.
- Never expose the Portainer UI to the internet. Reach it over LAN, VPN, or an authenticated tunnel.
- A new Portainer instance must have its admin user created within a few minutes of first start, or it stops for security. Restart the container if that window was missed.
- Portainer controls the Docker socket, so anyone with Portainer admin effectively has root on the host.

## Reverse Proxies

Caddy, Traefik, nginx, and Nginx Proxy Manager all follow the same flow: `hostname → proxy → upstream (container:port on a shared network)`.

| Symptom | Usual cause |
|---|---|
| 502 Bad Gateway | Proxy can't reach the upstream: wrong host or port, not on a shared network, upstream down |
| 504 Gateway Timeout | Upstream too slow, or proxy timeout too short |
| 404 from the proxy itself | No host rule matches the requested hostname |
| Redirect loop | TLS terminated at the proxy but the app forces HTTPS without trusting `X-Forwarded-Proto` (or Cloudflare "Flexible" SSL) |
| 413 Request Entity Too Large | Body size limit, e.g. nginx `client_max_body_size` (default 1 MB) |
| WebSockets fail | Missing `Upgrade`/`Connection` headers (automatic in Caddy and Traefik, explicit in nginx) |
| Wrong client IPs in app logs | App doesn't trust the proxy's `X-Forwarded-For` |

- Configure the application to trust forwarded headers **only from the proxy's IP or network**.
- TLS: ACME HTTP-01 needs port 80 reachable from the internet. For internal-only services use DNS-01 with a DNS API token scoped to the one zone.
- Enable HSTS only after HTTPS works everywhere it will apply.
- Put authentication (app login, forward-auth, SSO) in front of admin tools that are proxied.

## Tunnels

- **Cloudflare Tunnel:** outbound-only, no port forward needed. Still put authentication in front of anything sensitive (Cloudflare Access or the app's own login). `cloudflared` resolves origin hostnames from its own container or host, so use names it can resolve. Use `noTLSVerify` only for internal origins you control with self-signed certificates.
- **Tailscale:** subnet routers need IP forwarding enabled and the advertised routes approved in the admin console. MagicDNS and global nameserver settings decide whether tailnet clients use the Pi-hole, which must be reachable over the tailnet.
- **WireGuard:** see `network-operations.md`.

## Monitoring and Alerting

- **Uptime:** check public services from outside the network and internal services from inside (Uptime Kuma, Gatus). Use heartbeat checks (e.g. Healthchecks-style pings) for cron and backup jobs, so silence triggers an alert.
- **Metrics:** Prometheus with node_exporter and cAdvisor, shown in Grafana. Alert on disk usage, memory pressure, container restart loops, certificate expiry, and backup job failures.
- **Logs:** centralize them if there are several hosts (e.g. Loki), and always rotate.
- Alerts must reach a channel the user actually watches (email, ntfy, Telegram, Discord), and must be tested.

## Linux Host Administration

- **Services:** `systemctl status <UNIT>`, `journalctl -u <UNIT> -b --since "1 hour ago"`.
- **Disk:** `df -h`, `sudo du -xh --max-depth=1 / | sort -h`, `docker system df`, `journalctl --disk-usage`. Clean up deliberately; `docker system prune` removes stopped containers and unused networks, and `--volumes` also deletes unused volumes (data loss). Confirm with the user first.
- **Updates:** `apt list --upgradable` (Debian/Ubuntu). Enable unattended security updates. A pending reboot shows as `/var/run/reboot-required`.
- **Time:** `timedatectl`. NTP sync matters for TLS, DNSSEC, TOTP, and logs.
- **SSH:** key authentication; disable password authentication only after key login is confirmed in a second session; `sudo sshd -t` before every reload.
- **Bind mount permissions:** container UID/GID must match host ownership (many images take `PUID`/`PGID`). Check with `ls -ln` and `docker exec <CONTAINER> id`.
