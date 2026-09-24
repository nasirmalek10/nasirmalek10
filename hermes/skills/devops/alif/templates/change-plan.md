# Change Plan: <SHORT TITLE>

**Date / window:** <DATE, TIME, EXPECTED DURATION>
**Risk level:** <Medium / High>, because <REASON>
**Who is affected:** <devices, users, services>

## Goal

<What the change achieves, and the problem it solves.>

## Current State (evidence)

- <What is configured now, with the source: screenshot, config export, command output>

## Risk Gate

| Question | Answer |
|---|---|
| Could it interrupt connectivity? | <yes/no, how> |
| Could it expose a service? | <yes/no, how> |
| Could it corrupt or lose data? | <yes/no, how> |
| Could it lock the user out? | <yes/no, how> |

## Preparation

- [ ] Backup taken: <WHAT, WHERE> and verified readable
- [ ] Out-of-band access confirmed: <METHOD>
- [ ] Timed revert armed (if applicable): <COMMAND>
- [ ] Affected people told

## Steps

1. <Step, where it runs (host / GUI path), and the exact command or setting>
2. <...>

## Verification

| Check | From where | Command / action | Expected result |
|---|---|---|---|
| <e.g. DHCP lease> | <client on VLAN X> | <COMMAND> | <RESULT> |

## Rollback

- Trigger: <when to roll back, e.g. any verification check fails>
- Steps: <exact restore steps>
- Time to roll back: <ESTIMATE>

## Afterwards

- [ ] Environment profile and memory updated
- [ ] Monitoring and alerts still green
- [ ] Temporary changes removed (lease times, test rules, revert timers)
