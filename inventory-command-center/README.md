# Inventory Command Center + Offline POS

A single-file, fully offline inventory and point-of-sale app (`index.html`). Open it in a browser
(file:// works; serve over http(s) only if you want Google Drive backup). Data lives in the
browser's IndexedDB.

Run the built-in test suite by opening `index.html?qa=1`: 148 automated checks.

## v1.6.0 — what changed from v1.5.0

v1.5.0 already had offline store ⇄ warehouse transfer files and checkbox permissions with role
presets. v1.6.0 builds on both.

### Transfer files
- **Signed files.** Enter the same *transfer exchange key* in Settings at every site. Files are
  signed with HMAC-SHA-256. On import, a file that was edited (even with a recomputed checksum),
  forged, or signed with another key is refused. Optionally refuse unsigned files altogether. The
  key is never written to spreadsheet/CSV exports or non-Admin JSON exports.
- **✉ Email file.** Shares the file through the system share sheet where supported. Otherwise
  it downloads the file and opens a pre-addressed email with the delivery summary and a short
  file code. Locations now have an email address, which also travels inside the file so
  confirmations go back automatically.
- **Stock requests (store → warehouse).** A store creates a request, or has it suggested from
  min/max levels, and emails the `_REQUEST` file. The warehouse imports it (at most once) and
  turns it into a draft transfer capped at what it holds. The shipment file carries the request
  ID, so the store's request shows *Partially Fulfilled* / *Fulfilled* when the delivery is
  imported.
- **Return reasons** per line on store → warehouse returns, carried in the file and printed on
  paperwork.

### Receiving and variances
- **Over-deliveries.** Extra units can be received once the line is fully counted. Within one
  workspace they move from the origin. Between sites, the store adds them and the sender deducts
  them once, when it applies the confirmation.
- **Blind receiving.** The receiver doesn't see the quantities sent until they review their
  count.
- **Overdue alerts** for deliveries in transit longer than N days, on the dashboard and on the
  Transfers screen.
- **Pick list** sorted by bin, and a **transfer variance report** by route with CSV export.

### Permissions
- Five finer permissions: *Apply discounts*, *Request stock*, *Approve variances*,
  *Receive purchase orders*, *View audit log* (23 in total). Upgrading from v1.5 runs a one-time
  migration: anyone who could already do the thing gets the matching new permission. An
  unticked permission is never re-granted afterwards.
- **Manager PIN approval.** When someone lacks a permission, a colleague who holds it can
  approve that one action with their PIN, for example a discount or a return at the till, or
  writing off a short delivery. The approval is limited to that permission and that person,
  expires after 3 minutes, is used up by the next saved change, and is audited with both names.
- **Temporary access** (an end date per user), **copy permissions from another person**, a
  **who-can-do-what matrix** comparing each person with their preset (CSV export), and a
  **searchable audit log**. Failed sign-ins and lockouts are also audited.

### Fixes
- The QA check "Drive sync refuses to start without configuration" failed when the file was opened
  from file://. It now tests the Client ID check it is named after.
