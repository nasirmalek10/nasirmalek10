#!/usr/bin/env bash
# docker-audit.sh: read-only audit of a Docker host.
#
# Usage:   docker-audit.sh            (run as a user in the docker group, or with sudo)
# Example: sudo ./docker-audit.sh | tee docker-audit.txt
#
# Reports containers, health, restart policies, published ports (flags ports
# open on all interfaces), images on "latest" or untagged, privileged
# containers, Docker socket mounts, network subnets next to host addresses,
# compose projects, and disk usage. Makes NO changes.

set -uo pipefail

section() { printf '\n===== %s =====\n' "$1"; }

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not installed or not on PATH." >&2
  exit 2
fi
if ! docker info >/dev/null 2>&1; then
  echo "Cannot talk to the Docker daemon. Is it running, and are you root or in the docker group?" >&2
  exit 2
fi

section "Engine"
docker version --format 'Client {{.Client.Version}} / Server {{.Server.Version}}' 2>&1
docker info --format 'Root dir: {{.DockerRootDir}}  Storage driver: {{.Driver}}  Containers: {{.Containers}} (running {{.ContainersRunning}})' 2>&1

section "Containers"
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' 2>&1

mapfile -t CONTAINERS < <(docker ps -aq 2>/dev/null)

section "Needs attention: unhealthy, restarting, or exited"
problems=0
for c in "${CONTAINERS[@]}"; do
  line="$(docker inspect -f '{{.Name}}|{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}|{{.RestartCount}}|{{.State.ExitCode}}' "$c" 2>/dev/null)"
  IFS='|' read -r name state health restarts exitcode <<<"$line"
  if [ "$health" = "unhealthy" ] || [ "$state" = "restarting" ] || { [ "$state" = "exited" ] && [ "$exitcode" != "0" ]; } || [ "${restarts:-0}" -gt 5 ]; then
    printf '  %-30s state=%s health=%s restarts=%s exit=%s\n' "${name#/}" "$state" "$health" "$restarts" "$exitcode"
    problems=$((problems + 1))
  fi
done
[ "$problems" -eq 0 ] && printf '  none\n'

section "Restart policies"
for c in "${CONTAINERS[@]}"; do
  docker inspect -f '{{.Name}}|{{.HostConfig.RestartPolicy.Name}}' "$c" 2>/dev/null |
    awk -F'|' '{ sub(/^\//, "", $1); p = ($2 == "" ? "no" : $2); printf "  %-30s %s%s\n", $1, p, (p == "no" ? "   <- will not come back after a reboot" : "") }'
done

section "Published ports"
exposed=0
for c in "${CONTAINERS[@]}"; do
  name="$(docker inspect -f '{{.Name}}' "$c" 2>/dev/null)"
  name="${name#/}"
  while read -r mapping; do
    [ -z "$mapping" ] && continue
    flag=""
    case "$mapping" in
      *"-> 0.0.0.0:"* | *"-> [::]:"* | *"-> :::"*)
        flag="   <- all interfaces (bypasses UFW/firewalld)"
        exposed=$((exposed + 1))
        ;;
    esac
    printf '  %-30s %s%s\n' "$name" "$mapping" "$flag"
  done < <(docker port "$c" 2>/dev/null)
done
[ "$exposed" -gt 0 ] && printf '\n  %s mapping(s) listen on all interfaces. Bind to 127.0.0.1 or a specific IP if only local/proxy access is needed.\n' "$exposed"

section "Images on 'latest' or untagged"
flagged=0
for c in "${CONTAINERS[@]}"; do
  line="$(docker inspect -f '{{.Name}}|{{.Config.Image}}' "$c" 2>/dev/null)"
  IFS='|' read -r name image <<<"$line"
  last="${image##*/}"
  if [[ "$image" == *@sha256:* ]]; then
    continue
  elif [[ "$last" != *:* ]] || [[ "$last" == *:latest ]]; then
    printf '  %-30s %s   <- no pinned version; rollback is harder\n' "${name#/}" "$image"
    flagged=$((flagged + 1))
  fi
done
[ "$flagged" -eq 0 ] && printf '  none\n'

section "Privileged containers and Docker socket mounts"
risky=0
for c in "${CONTAINERS[@]}"; do
  line="$(docker inspect -f '{{.Name}}|{{.HostConfig.Privileged}}|{{.HostConfig.NetworkMode}}|{{range .Mounts}}{{.Source}} {{end}}' "$c" 2>/dev/null)"
  IFS='|' read -r name privileged netmode mounts <<<"$line"
  notes=""
  [ "$privileged" = "true" ] && notes="$notes privileged;"
  [[ "$mounts" == *docker.sock* ]] && notes="$notes mounts docker.sock (root-equivalent);"
  [ "$netmode" = "host" ] && notes="$notes host network;"
  if [ -n "$notes" ]; then
    printf '  %-30s%s\n' "${name#/}" "$notes"
    risky=$((risky + 1))
  fi
done
[ "$risky" -eq 0 ] && printf '  none\n'

section "Networks and subnets (check for overlap with host/LAN/VPN subnets)"
for net in $(docker network ls -q 2>/dev/null); do
  docker network inspect -f '  {{.Name}} ({{.Driver}}): {{range .IPAM.Config}}{{.Subnet}} {{end}}' "$net" 2>/dev/null
done
if [ -r /etc/docker/daemon.json ]; then
  printf '\n  /etc/docker/daemon.json:\n'
  sed 's/^/    /' /etc/docker/daemon.json
fi
if command -v ip >/dev/null 2>&1; then
  printf '\n  Host addresses (compare against the subnets above):\n'
  ip -br -4 addr 2>/dev/null | grep -Ev '^(docker|br-|veth)' | sed 's/^/    /'
fi

section "Compose projects"
if docker compose version >/dev/null 2>&1; then
  docker compose ls -a 2>&1
else
  printf '  docker compose plugin not available\n'
fi

section "Disk usage"
docker system df 2>&1

printf '\nDone. No changes were made.\n'
