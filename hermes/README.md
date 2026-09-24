# Alif: Hermes Agent Skill

**Alif** is a [Hermes Agent](https://github.com/NousResearch/hermes-agent) skill that turns the agent into a full-stack software engineer, IT administrator, network administrator, systems engineer, and troubleshooting partner.

It covers two areas as one connected environment:

- **Software:** UI and accessibility, responsive web, frontend frameworks, backend services, REST APIs, authentication and authorization, databases and migrations, background jobs, file handling, integrations, automated tests, performance, logging, and secure deployment.
- **Infrastructure and networking:** Linux, OPNsense, gateways, routing, NAT, VLANs, firewalls, DHCP, DNS and DNSSEC, Pi-hole, encrypted DNS, Docker, Docker Compose, Portainer, reverse proxies, tunnels, monitoring, backups, and disaster recovery.

## What's Included

```
hermes/
├── README.md                      this file
├── SOUL.md                        optional always-on persona ("Your name is Alif…")
└── skills/devops/alif/
    ├── SKILL.md                   core workflow, principles, risk gate, playbooks
    ├── references/                loaded on demand
    │   ├── software-engineering.md
    │   ├── network-operations.md
    │   ├── containers-and-services.md
    │   ├── backup-and-recovery.md
    │   └── change-safety-and-release.md
    ├── templates/
    │   ├── environment-profile.md what Alif remembers about your setup
    │   ├── change-plan.md         for risky changes
    │   ├── incident-report.md     troubleshooting write-ups
    │   └── release-report.md      release readiness
    └── scripts/                   read-only diagnostics for Linux hosts
        ├── netdiag.sh             interfaces, routes, gateway, DNS, reachability, ports, firewall
        ├── dnscheck.sh            compares resolvers, blocking, DNSSEC validation
        └── docker-audit.sh        health, restart policies, exposed ports, tags, risky mounts, subnets
```

`SKILL.md` stays short. Hermes loads the reference files only when a task needs them, so the full depth doesn't cost context on every turn.

## Install

On the machine where Hermes Agent runs:

```sh
git clone https://github.com/nasirmalek10/nasirmalek10.git
mkdir -p ~/.hermes/skills/devops
cp -r nasirmalek10/hermes/skills/devops/alif ~/.hermes/skills/devops/
chmod +x ~/.hermes/skills/devops/alif/scripts/*.sh
```

Start a new Hermes session so the skill index is refreshed. Then invoke it directly with `/alif`, or just describe a task; the skill's description tells Hermes when to load it.

### Optional: make Alif the default persona

A skill loads when it is relevant. To have Hermes *always* answer as Alif, add the persona to Hermes's `SOUL.md`. **Back up your existing file first**, then append rather than overwrite if you already have one:

```sh
[ -f ~/.hermes/SOUL.md ] && cp ~/.hermes/SOUL.md ~/.hermes/SOUL.md.bak
cat nasirmalek10/hermes/SOUL.md >> ~/.hermes/SOUL.md
```

## Update

```sh
cd nasirmalek10 && git pull
rsync -a --delete hermes/skills/devops/alif/ ~/.hermes/skills/devops/alif/
```

`--delete` removes files from the installed copy that no longer exist in the repo. If Alif has edited the installed skill itself (it's told it may add pitfalls it learns), copy those edits back into the repo before running this, or leave out `--delete` and merge by hand.

## Using the Diagnostic Scripts

All three scripts are **read-only**: they make no configuration changes.

```sh
~/.hermes/skills/devops/alif/scripts/netdiag.sh example.com
~/.hermes/skills/devops/alif/scripts/dnscheck.sh example.com <PIHOLE_IP> 1.1.1.1
sudo ~/.hermes/skills/devops/alif/scripts/docker-audit.sh
```

`dnscheck.sh` needs `dig` (`bind9-dnsutils` on Debian/Ubuntu, `bind-utils` on Fedora/RHEL, `bind-tools` on Alpine). `netdiag.sh` skips tools that aren't installed. Run it with `sudo` to include firewall rules.

## First Session Tip

Ask Alif to build your environment profile: *"Alif, let's fill in the environment profile."* It will walk through `templates/environment-profile.md` (hardware, VLANs, DNS chain, how your Docker stacks are managed, backups, preferences) and save the confirmed facts to memory, so later answers fit your actual setup. Secrets are never stored.
