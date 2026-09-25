# Inventory Command Center + Offline POS — v1.5.0

A single offline HTML file (`Inventory_Command_Center_Universal_POS.html`). Open it in Chrome or Edge. Everything is stored in that browser on that computer.

## What's new in v1.5.0

### 1. Offline store ⇄ warehouse transfer files

Each site (the warehouse and every store) runs its own copy of the app. Deliveries travel between them as small files, sent by email or USB:

| Step | Who | What they do |
|---|---|---|
| 1 | Sender (e.g. warehouse) | **Transfers → New transfer** → add items (scan or pick) → **Save and dispatch** → **Download transfer file** (`…_SHIPMENT.transfer.json`) → email it |
| 2 | Receiver (e.g. Store 3) | **Transfers → Import delivery file** (or drag the file onto the page) → review the products and destination → **Add and receive now** |
| 3 | Receiver | Count what arrived (scan barcodes or type), enter damaged units, optionally close a short delivery → **Confirm receipt**. Stock at the store updates automatically. |
| 4 | Receiver | **Download receiving confirmation** (`…_RECEIVED.transfer.json`) → email it back |
| 5 | Sender | **Import delivery file** with the confirmation → the transfer closes; missing and damaged units are written off as a Transfer Variance |

Returns work the same way in reverse: the store creates a **Return** transfer to the warehouse.

**Safeguards**
- Every transfer has a global ID. A shipment file can be imported **once**; a second import is blocked with the date it was first imported.
- A site cannot import its own shipment. That would count the stock twice.
- Files carry a checksum. An edited or damaged file is refused.
- Importing adds nothing to stock. Only confirmed receipt does.
- You cannot receive more than was sent. A closed delivery cannot be received again.
- Confirmations carry running totals. Applying one twice, or an older one after a newer one, can never add stock twice.
- Products missing at the receiving site are created from the file (name, SKU, barcode, cost, price).
- A rejected delivery changes no stock on either side.
- Every file downloaded or imported is kept in the **File exchange log** and the **Access and transfer audit**.

### 2. Checkbox-level user permissions

**Users and Roles** has 18 permissions in 7 groups. Each group has an "All access" box, as in accounting software:

- **Point of Sale:** POS / Checkout · Process returns
- **Products and Inventory:** View products · Edit products · Adjust inventory · Stock count
- **Transfers:** View · Create · Dispatch · Receive · Import delivery files
- **Purchasing** · **Reports**
- **Import / Export:** Import data · Export data · Backups
- **Administration:** Settings · Manage users

**Presets** (Admin, Store Manager, Warehouse Staff, Cashier, Viewer) fill in the boxes. You can then tick or untick boxes for one person, and create your own presets (for example "Junior Accountant").

**Location access** limits a person to specific stores. Selling, counting, adjusting, dispatching and receiving are then only allowed at those locations.

**Rules**
- Anything not ticked is refused, on screen and again when the data is saved.
- Admin alone can restore a backup or reset the workspace.
- People with *Manage users* can only grant permissions they hold. They cannot create or edit Admins, or manage staff at other stores.
- Existing v1.4.5 non-Admin users keep exactly the read-only access they had until an Admin applies a preset.

### 3. Other enhancements
- **This installation is** (in Settings): sets which site this computer works at. Delivery numbers carry that site's code (`WH-DR-000123`), the POS defaults to it, and imported files are checked against it.
- **Site codes** on locations (WH, ST01 … ST08) match locations between installations.
- **Auto sign-out after N idle minutes** for shared tills.
- **Barcode scanning** when building a transfer and when counting a delivery.
- **Action needed** panel on Transfers: deliveries to receive, confirmations to send, files not yet sent, and deliveries awaiting confirmation.
- Stock adjustments can target one specific location.
- Access audit log covering user, permission and role changes and transfer files.
- Badge colours that were missing in v1.4.5 are now styled.

## Setting up the warehouse and 8 stores
1. On the head-office copy, add every location with a **site code** (WH, ST01 … ST08). Add users and their permissions.
2. Export a JSON backup and restore it on each site's computer. Alternatively, set up each computer fresh with the same locations and codes.
3. On each computer, go to **Settings → This installation is** and choose that site.
4. Move stock with transfer files as described above.

Each copy is the authority for its own location's stock. The quantities it shows for other sites are only as current as the last transfer file or confirmation it received.

## Automated checks
Open the file with `?qa=1` in the address bar (served over `http://localhost`) to run the built-in suite: 134 checks, including simulated warehouse → store → confirmation flows between two separate workspaces.
