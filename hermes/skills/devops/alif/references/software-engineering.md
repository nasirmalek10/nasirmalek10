# Software Engineering Standards

Standards Alif applies when building, modifying, reviewing, or testing applications. Follow the existing codebase's conventions first; use these where the codebase is silent.

## Contents

- Before writing code
- Frontend: UI, accessibility, responsive design
- Backend and APIs
- Authentication and authorization
- Databases and migrations
- Background jobs
- File handling
- Integrations
- Testing
- Performance
- Logging and observability
- Secure deployment
- Preserving existing behavior

## Before Writing Code

- Read the README, package manifests, lockfiles, framework config, `.env.example`, schema and migrations, tests, and CI config.
- Identify the conventions: language and runtime version, lint and format rules, folder layout, state management, ORM, test framework. Match them.
- Map every place the change touches: routes, UI, API, database, jobs, config, docs, deployment.
- List the existing features the change must preserve.

## Frontend

### Accessibility (target WCAG 2.2 AA)

- Use semantic HTML first: `<button>` for actions, `<a>` for navigation, a `<label>` for every input, headings in order, landmarks (`header`, `nav`, `main`, `footer`).
- Everything works with a keyboard alone, with a visible focus indicator. Manage focus in dialogs (trap it, then return it on close) and after client-side route changes.
- Text contrast at least 4.5:1 (3:1 for large text and UI component boundaries).
- Meaningful `alt` text on images; `alt=""` on decorative ones.
- Use ARIA only where native semantics can't express the pattern. Link form errors to their fields with `aria-describedby` and announce them.
- Respect `prefers-reduced-motion`. Pointer targets at least 24×24 CSS px.

### Responsive design

- Mobile-first, fluid layouts with flexbox and grid; no fixed heights around text.
- No horizontal scroll at 320 px wide. Check 320, 768, 1024, and 1440 px.
- Responsive images (`srcset`, `sizes`, explicit width and height to prevent layout shift).

### UI behavior

- Every async view has loading, empty, error, and success states.
- Prevent double submission; show progress for long operations.
- Validate on the client for convenience and on the server for correctness.
- Never put user-controlled data into `innerHTML` or `dangerouslySetInnerHTML`.
- Prefer httpOnly cookies over `localStorage` for session tokens.

## Backend and APIs

- **Validate every input at the boundary** with a schema library (zod, pydantic, joi, or the framework's validator). Enforce types, lengths, ranges, and allowed values; reject unexpected fields where sensible.
- **Errors:** one consistent error shape. Correct status codes: 400 invalid input, 401 not authenticated, 403 not allowed, 404 not found, 409 conflict, 422 if the codebase uses it for validation, 429 rate limited, 500 server fault. Never return stack traces or SQL to clients; log them server-side with a request ID.
- **REST conventions:** plural resource nouns, correct methods, idempotent `PUT` and `DELETE`, pagination on lists (cursor-based for large or changing sets), filtering and sorting parameters, a versioning approach consistent with the codebase.
- **Idempotency keys** for create operations a client may retry (payments, orders, messages).
- **CORS:** an explicit origin allowlist; never `*` together with credentials.
- **Secrets** come from environment variables or a secret store, never from code, logs, or client bundles. Keep `.env.example` current with labeled placeholders.

## Authentication and Authorization

- Use proven libraries or the framework's auth, not hand-rolled crypto.
- Hash passwords with Argon2id (bcrypt or scrypt are acceptable where already used).
- Session cookies: `HttpOnly`, `Secure`, `SameSite=Lax` or `Strict`. Rotate the session ID on login and on privilege change.
- CSRF protection on state-changing requests when auth is cookie-based.
- Rate-limit login, registration, and password reset. Return the same generic message for "no such user" and "wrong password".
- Password reset tokens: single use, short expiry, stored hashed.
- Offer MFA where the stack supports it.
- **Authorize on the server for every request, at the object level:** "may this user act on *this* record?", not only "may this user reach this route?". Deny by default.

## Databases and Migrations

- Every schema change is a migration in version control. Never edit a migration that has already been applied anywhere.
- **Back up production before migrating**, and confirm the backup is readable.
- **Expand, migrate, contract** for changes that must survive a rolling or zero-downtime deploy:
  1. Add the new column or table (nullable or with a default).
  2. Deploy code that writes both old and new.
  3. Backfill.
  4. Switch reads to the new structure.
  5. Drop the old structure in a later release.
- Watch for locks on large tables: build indexes concurrently where the engine supports it (PostgreSQL `CREATE INDEX CONCURRENTLY`), and batch large backfills.
- Enforce integrity in the database (foreign keys, unique, not null, check constraints), not only in application code.
- Parameterized queries only. Index columns used in `WHERE`, `JOIN`, and `ORDER BY`; watch for ORM N+1 queries.
- Wrap multi-step writes in transactions.
- Provide a down migration or a written manual rollback.

## Background Jobs

- Handlers are idempotent (safe to run twice).
- Retries use exponential backoff with jitter and a maximum attempt count; exhausted jobs land in a visible failed or dead-letter state.
- Every job has a timeout. Never hold a database transaction open across an external call.
- Prevent duplicate scheduled runs across replicas (a lock or a single scheduler).

## File Handling

- Enforce size limits at the reverse proxy and in the application.
- Check file type by content (magic bytes), not by extension or the client's `Content-Type`.
- Generate server-side file names; never build paths from user input (path traversal).
- Store uploads outside the web root or in object storage.
- Serve downloads with the correct `Content-Type`, `Content-Disposition`, and `X-Content-Type-Options: nosniff`.
- Clean up temporary files; keep image and document processing libraries patched.

## Integrations

- A timeout on every outbound call. Retry only safe or idempotent operations.
- Honor `429` and `Retry-After`; back off on repeated failures.
- Verify webhook signatures and reject stale timestamps.
- Store external IDs so you can reconcile records later.
- Keep sandbox and production credentials separate.

## Testing

- Unit tests for logic, integration tests for API plus database, end-to-end tests for critical user flows (sign-in, core create/edit/delete, payments, uploads).
- Test the failure cases: invalid input, unauthenticated, forbidden (another user's record), not found, conflict, dependency timeout, empty data.
- Add a regression test for every bug you fix.
- Before calling work done, run the full test suite, lint, typecheck, and build, and report the results.

## Performance

- Measure before optimizing: profiler, `EXPLAIN ANALYZE`, browser devtools, Lighthouse.
- Paginate lists, compress responses, cache with explicit invalidation.
- Move slow work (email, image processing, reports) out of the request path into background jobs.

## Logging and Observability

- Structured logs (JSON where the stack supports it) with timestamp, level, request ID, and actor ID.
- Never log passwords, tokens, session cookies, full card numbers, or unnecessary personal data.
- Separate health endpoints: liveness (process is up) and readiness (dependencies reachable).
- Track error rate and latency; rotate logs.

## Secure Deployment

- Run as a non-root user in minimal images with pinned base image and dependency versions (lockfiles committed).
- Audit dependencies for known vulnerabilities before release.
- HTTPS everywhere. Enable HSTS only after HTTPS works on every affected host (and all subdomains if using `includeSubDomains`).
- Security headers: `Content-Security-Policy`, `X-Content-Type-Options`, `Referrer-Policy`, `frame-ancestors` (or `X-Frame-Options`).
- Trust `X-Forwarded-*` headers only from your own reverse proxy.
- Debug mode off in production; least-privilege database user; separate production secrets.

## Preserving Existing Behavior

- Before refactoring or replacing a component, list its features and confirm each still works afterwards.
- Keep API contracts stable. Deprecate before removing, and tell the user which clients are affected.
- Data migrations must not lose data. If a lossy change is unavoidable, stop, explain, and get agreement after a backup.
