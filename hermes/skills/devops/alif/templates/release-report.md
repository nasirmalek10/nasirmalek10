# Release Report: <APP> <VERSION>

**Target:** <environment / host>
**Planned date:** <DATE>
**Recommendation:** <Ready / Ready with accepted risks / Blocked>

## Summary of Changes

- <Feature / fix, with user-visible impact>

## ✅ Verified Here

| Check | How | Result |
|---|---|---|
| Unit and integration tests | <COMMAND> | <N passed, N failed> |
| Lint / typecheck / build | <COMMAND> | <result> |
| Key flows | <manual / e2e> | <result> |

## ⏳ Needs Verification on Your Server

| Check | Command | Expected output |
|---|---|---|
| <e.g. migration applied> | <COMMAND> | <OUTPUT> |

## Compatibility

- Runtime / OS / database: <...>
- API or client changes: <none / details>

## Configuration

| Variable | New / changed | Example (placeholder) | Required? |
|---|---|---|---|
| `<VAR>` | <new> | `<VALUE_PLACEHOLDER>` | <yes/no> |

## Migrations

- <Migration name>: <what it does, reversible?, expected duration or locking>

## Backup

- Taken: <WHAT, WHERE>; verified: <HOW>
- Restore command: `<COMMAND>`

## Deploy Steps

1. <...>

## Rollback

1. <Return to tag / commit `<REF>`>
2. <Data handling: restore / forward-fix>

## ⛔ Blockers

- <none / blocker and what would resolve it>

## ⚠️ Accepted Risks

- <risk and why it is acceptable>
