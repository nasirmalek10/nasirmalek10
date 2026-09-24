# Backups and Disaster Recovery

## Principles

- **3-2-1:** three copies, on two different media, one offsite. Keep at least one copy offline or immutable so ransomware or a bad script can't reach it.
- **A backup you haven't restored is a hope, not a backup.** Schedule restore tests and record how long they took.
- Agree on a **recovery point objective** (how much data loss is acceptable) and a **recovery time objective** (how long it may be down) for each system, and size backup frequency to match.
- **Snapshots (ZFS, Btrfs, LVM, VM) are not backups** until they are replicated to another machine.
- Encrypt offsite backups. Keep the encryption keys and passwords somewhere other than the systems being backed up (a password manager plus a printed break-glass copy).
- Monitor backup jobs with a heartbeat check so a silent failure raises an alert.

## What to Back Up

| System | What | How |
|---|---|---|
| OPNsense | `config.xml` (includes secrets) | System → Configuration → Backups, before every change; plus scheduled automatic backups (built-in or plugin options, depending on version) |
| Pi-hole | Settings, lists, local DNS records | Teleporter export; `/etc/pihole` |
| Docker stacks | Compose files, `.env`, bind-mount directories, named volumes | App-consistent dump or copy with the service stopped (below) |
| Databases | Logical dumps | `pg_dump -Fc`, `mysqldump --single-transaction --routines --triggers`, `sqlite3 <DB> ".backup '<FILE>'"` |
| Portainer | Its data volume | Volume backup (below) |
| Linux hosts | `/etc`, crontabs, custom scripts, installed package list | etckeeper, `dpkg --get-selections`, file-level backup |
| Certificates and keys | ACME account data, private keys, VPN keys | Encrypted backup |
| Documentation | Environment profile, network diagram, runbooks | In the repo or notes, plus offsite |

Tools: restic or borg (deduplicated and encrypted), rclone (offsite transfer), Proxmox Backup Server (VMs), and filesystem snapshot replication (ZFS send/receive).

## Consistent Backups

Copying a live database's files can produce a corrupt backup. Use the engine's dump tool, or stop the service first.

Named-volume backup with the service stopped (placeholders labeled):

```sh
docker compose stop <SERVICE>
docker run --rm \
  -v <VOLUME_NAME>:/data:ro \
  -v "$PWD":/backup \
  alpine tar czf "/backup/<VOLUME_NAME>-$(date +%F).tgz" -C /data .
docker compose start <SERVICE>
```

Restore into an **empty** volume (never over live data without a fresh backup of it):

```sh
docker compose stop <SERVICE>
docker run --rm \
  -v <VOLUME_NAME>:/data \
  -v "$PWD":/backup \
  alpine sh -c 'cd /data && tar xzf /backup/<BACKUP_FILE>.tgz'
docker compose start <SERVICE>
```

Check that a backup is readable before relying on it:

```sh
tar tzf <FILE>.tgz > /dev/null && echo "archive OK"
pg_restore --list <FILE>.dump > /dev/null && echo "dump OK"
restic check        # or: borg check <REPO>
```

## Restore Test Procedure

1. Restore into a scratch location, container, or VM, never over production.
2. Start the application against the restored data.
3. Check real content: recent records, uploaded files, user logins.
4. Record the date, what was tested, how long it took, and any problems.
5. Fix gaps in the backup set, then update the runbook.

## Disaster Recovery Runbook Skeleton

Recover in dependency order, because everything above a layer needs the layer below:

1. **Network edge:** firewall/gateway (restore `config.xml`), WAN, core switching.
2. **Name resolution and addressing:** DHCP, DNS (Pi-hole/Unbound).
3. **Compute:** hypervisor or Docker hosts.
4. **Storage:** NAS, volumes, mounts.
5. **Data:** databases, then application volumes.
6. **Applications:** compose stacks, in dependency order.
7. **Edge services:** reverse proxy, certificates, tunnels, VPN.
8. **Monitoring and backups:** re-enable, and confirm the first new backup succeeds.

For each step, the runbook states where the backup is, how to restore it, which credentials are needed and where they are kept, and how to verify the step before moving on. Include ISP and hardware-vendor contacts and the out-of-band access methods.

## Before a Risky Change

- Take a targeted backup of exactly what the change touches, and verify it's readable.
- Write down the restore command before applying the change, not after it fails.
