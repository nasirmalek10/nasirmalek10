# Change Safety and Releases

## Risk Levels

| Level | Examples | Required |
|---|---|---|
| Low | Read-only diagnostics, a new isolated service, UI text changes | Normal care |
| Medium | Config change to one service, app deploy with a backward-compatible migration, container update with pinned rollback tag | Backup and a rollback step |
| High | Firewall, NAT, routing, or VLAN changes on the management path; network-wide DNS or DHCP; authentication, SSO, or MFA; SSH config; storage, RAID, or filesystems; destructive migrations; VPN or remote access; gateway or OS upgrades | Change plan (`templates/change-plan.md`), verified backup, recovery path, the user's go-ahead, and a maintenance window if other people depend on it |

## Lockout Prevention

- **Keep a second admin session open** while changing access controls. Test the new access in a fresh session before closing the old one.
- **Change the management path last**, and confirm it works first.
- **Know the out-of-band path:** physical console, serial, IPMI/iDRAC/iLO, hypervisor console, or a second WAN or cellular link. If none exists, say so and reduce the risk accordingly.

### Timed automatic revert (Linux)

If the change cuts you off, the old state comes back by itself.

**netplan:**

```sh
sudo netplan try          # reverts after 120 s unless you confirm
```

**nftables:**

```sh
sudo nft list ruleset | sudo tee /root/nft-rollback.nft > /dev/null
sudo systemd-run --unit=fw-rollback --on-active=5m \
  /bin/sh -c 'nft flush ruleset && nft -f /root/nft-rollback.nft'
sudo nft -f <NEW_RULESET_FILE>
# Still connected and everything works? Cancel the rollback:
sudo systemctl stop fw-rollback.timer
```

**iptables:**

```sh
sudo sh -c 'iptables-save > /root/iptables-rollback.rules'
sudo systemd-run --unit=fw-rollback --on-active=5m \
  /bin/sh -c 'iptables-restore < /root/iptables-rollback.rules'
# apply the change, test, then:
sudo systemctl stop fw-rollback.timer
```

If the transient unit name is already taken from an earlier run, clear it with `sudo systemctl reset-failed fw-rollback` or pick another name.

**SSH daemon:**

```sh
sudo sshd -t && sudo systemctl reload ssh   # the unit is "sshd" on some distributions
# keep this session open; test login from a second terminal
```

### OPNsense

The web GUI has no commit-confirm. Instead:

1. Download a config backup.
2. Confirm console access works.
3. Make the change that affects your own access **last**.
4. If you get locked out, use the console to restore the previous revision, or revert it under System → Configuration → History from a host that can still reach the GUI.

### DNS and DHCP

- Lower DHCP lease times a day before a planned change.
- Keep a static IP on the admin machine during the change.
- Know the resolver IPs to query directly (`dig @<IP>`), so you can test without depending on the change.

## Order of Operations for Infrastructure Changes

1. Export or back up the current config and verify the backup.
2. Confirm the out-of-band access path.
3. Tell the user the expected impact and duration.
4. Apply to one test client, VLAN, or host first where possible.
5. Apply the change.
6. Verify from the affected clients: DHCP lease, gateway, DNS, internet, internal services, remote access.
7. Watch logs for a while (firewall live view, service logs, Pi-hole query log).
8. Record the new state in memory and the environment profile.

## Release Checklist

**Compatibility**

- [ ] Runtime, OS, and database versions supported on the target
- [ ] Dependency upgrades reviewed for breaking changes
- [ ] API contracts kept for existing clients (mobile apps, integrations, scripts)
- [ ] Browser support unchanged, or the change is intended and noted

**Configuration**

- [ ] New or renamed environment variables documented with labeled placeholders
- [ ] Safe defaults; secrets supplied through the secret mechanism, not the repo
- [ ] Feature flags set correctly for the target environment

**Migrations**

- [ ] Reviewed for locking and duration on production-sized data
- [ ] Reversible, or a manual rollback is written down
- [ ] Order relative to the code deploy is correct (expand and contract)
- [ ] Tested against a copy of production data where possible

**Backups**

- [ ] Fresh backup taken right before release
- [ ] Backup verified readable, and the restore command written down

**Build and Tests**

- [ ] Tests, lint, typecheck, and build pass
- [ ] Dependency vulnerability audit reviewed
- [ ] Images built from pinned base images, and tagged with a version

**Deploy and Rollback**

- [ ] Deploy steps, expected downtime, and timing agreed
- [ ] Rollback steps: which tag or commit to return to, and what happens to data written by the new version
- [ ] Post-deploy smoke tests and health checks defined

## Reporting Results

Always separate these categories:

- ✅ **Verified here:** what was tested and how (commands, test suites, results)
- ⏳ **Needs verification on your server:** exact commands and the expected output
- ⛔ **Blockers:** what prevents release, and what would resolve it
- ⚠️ **Accepted risks:** known issues shipping anyway, with the reason
