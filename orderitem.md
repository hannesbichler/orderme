# orderitem — API and TableOrderScreen behaviour

The `orderitem` resource is the live order for a restaurant table. It bridges the Flutter `TableOrderScreen` and the `SHAREDTICKETS` Oracle table via Java-serialised `TicketInfo` blobs.

---

## SHAREDTICKETS table

| Column  | Type    | Notes |
|---------|---------|-------|
| ID      | VARCHAR | Place UUID (matches `Place.id` from `/places`) |
| NAME    | VARCHAR | Human-readable table name |
| CONTENT | BLOB    | Java-serialised `TicketInfo` object |
| LOCKBY  | VARCHAR | Reserved (unused by Flutter app) |

---

## API endpoints

### GET `/orderitem/{tableId}/{tableName}`

Returns the current order for a table.

**First access (row not in SHAREDTICKETS):**
1. Creates an empty `TicketInfo`.
2. Serialises it and INSERTs into `SHAREDTICKETS (ID, NAME, CONTENT, LOCKBY)`.
3. Returns an empty `OrderItem` with `id_=tableId` and `lines=[]`.

**Subsequent access:**
1. SELECTs the row by `ID = tableId`.
2. Deserialises `CONTENT` via `ObjectInputStream` with a custom `resolveClass` that resolves `TicketInfo` against the `w4cash.jar` classloader.
3. For each `TicketLineInfo`, looks up attribute IDs in `ATTRIBUTEVALUE` by value.
4. Returns `OrderItem` with all lines.

**Deserialization failure:** if `CONTENT` is corrupt or unparseable, returns an empty `OrderItem` and logs hex/base64 of the first bytes for diagnosis.

**Response shape:**
```json
{
  "id": 0,
  "id_": "place-uuid",
  "tickettype": 0,
  "ticketId": 0,
  "lines": [
    {
      "id": "",
      "orderId": "place-uuid",
      "productId": "product-uuid",
      "productName": "Wiener Schnitzel",
      "pricesell": 14.90,
      "qty": 2,
      "attSetInstDesc": "ohne Sauce",
      "attributes": [
        { "id": "attr-uuid", "name": "ohne Sauce" }
      ]
    }
  ]
}
```

All strings are HTML-escaped by the server (`HtmlUtils.htmlEscape`); the Flutter client un-escapes them via `StringUtils.unescape` in `OrderLine.fromJson`.

---

### PUT `/orderitem/{id}`

Saves the full order state. The server rebuilds `TicketInfo` from scratch on every PUT.

**Empty lines:** if `lines` is null or empty, DELETEs the `SHAREDTICKETS` row instead of updating it. The Flutter client never sends a PUT with empty lines — it calls DELETE directly in that case.

**Non-empty lines:** for each line:
1. Reads `productId`, `productName`, `pricesell` from the request.
2. Fetches full product metadata from `PRODUCTS WHERE ID = ?` (fills `ATTRIBUTESET_ID`, `CATEGORY`, `CODE`, etc.).
3. Constructs `TicketLineInfo(ProductInfoExt, qty, pricesell, null, new Properties(), false, null, null, null, null)`.
4. Sets `attSetInstDesc` from the request line.

Then serialises the whole `TicketInfo` and UPDATEs `SHAREDTICKETS SET CONTENT = ? WHERE ID = ?`.

Returns the request body echoed back (no re-read from DB).

**Known bug:** `TicketLineInfo` constructor NPEs when `discountInfo` (4th argument) is `null` inside `w4cash.jar`. The server passes `null` unconditionally, so any PUT with non-empty lines crashes at runtime. See the disabled test `putOrderItem_withOneLine_lookupsProductAndUpdates` in `TicketInfoControllerTest`.

---

### DELETE `/orderitem/{id}`

`DELETE FROM SHAREDTICKETS WHERE ID = ?`. Returns 200 with no body.

---

## Flutter TableOrderScreen

`lib/screens/table_order_screen.dart` — receives a `Place` and manages the full table order lifecycle.

### Initialisation

On `initState`:
1. `_fetchOrderItem()` — GETs `/orderitem/{place.id}/{place.name}`, parses into `_orderitem`.
2. `_loadGlobalCategories()` / `_loadGlobalProducts()` — reads from `ProductCatalogService` singleton (pre-loaded at app start; network only on cache miss).

### Layout

**Wide (>700 px):**
- Left panel: *Buchungen* (order lines) top + *Produktgruppen* (category tree) bottom, with a draggable horizontal divider between them.
- Right panel: Numpad (collapsible) + product grid, with a draggable vertical divider between left and right.

**Narrow (≤700 px):** Two tabs — *Buchungen* and *Produkte*. Categories shown as a horizontal chip strip above the product grid.

### Adding a product

1. User taps a product card.
2. If the product has an `attributesetid`, `ProductAttributeDialog.show(...)` opens first. If cancelled, nothing is added.
3. `_addProductToOrderItem` runs an **optimistic update** (no server call):
   - Qty to add = numpad input, or 1 if blank; clears numpad input afterwards.
   - If same `productId + attributes` already exists in lines → increments `qty` and `qtyNew`.
   - Otherwise → appends a new `OrderLine` with `qtyNew = qty`.
4. The server is only contacted on explicit **Save**.

### qtyNew field

`qtyNew` is a session-only counter reset to 0 on every GET (hardcoded in `OrderLine.fromJson`). It tracks items added in the current session without having been saved yet. The UI shows it as `"2 (2)"` when `qty != qtyNew`. `_makeOrder()` sets all `qtyNew` to 0 and is called before Save, Checkout, and Split.

### Numpad keys

| Key | Requires selection | Action |
|-----|--------------------|--------|
| 0–9 | — | Append digit to qty input (max 4 digits) |
| ⌫  | — | Delete last digit from qty input |
| C   | — | Clear qty input |
| `-` | yes | Decrement qty of selected line (→ delete confirmation if qty = 1) |
| `+` | yes | Increment qty of selected line |
| `d` | yes | Delete confirmation dialog for selected line |
| `r` | — | Open `CheckoutDialog` (Rechnung) |
| `a` | yes + product has attributes | Open `ProductAttributeDialog` to edit attributes of selected line |

### Appbar actions

| Icon | Action |
|------|--------|
| Delete | Confirmation dialog → `DELETE /orderitem/{id}` → pops screen |
| Save | `PUT /orderitem/{id}` with full order (or DELETE if lines empty) → pops on success |
| Split | `_makeOrder()` → `SplitDialog.show(...)` → deletes + pops if lines become empty after split |
| Swap | `MoveTableDialog.show(...)` → POSTs to `/orderitem/{id}/move-table` (backend endpoint not implemented; error is silently swallowed) → navigates to `TableOrderScreen` for the target table |

### Save flow (`_saveOrderItem`)

```
lines empty?
  yes → DELETE /orderitem/{id} → pop
  no  → _makeOrder() (reset qtyNew)
      → PUT /orderitem/{id}
      → show snackbar "Order saved."
      → pop
```

PUT payload:
```json
{
  "id": 0,
  "placeId": "place-uuid",
  "lines": [
    {
      "id": "", "orderId": "place-uuid",
      "productId": "...", "productName": "...",
      "pricesell": 9.99, "qty": 2, "quantity": 2,
      "attSetInstDesc": "Medium",
      "attributes": [{ "id": "...", "name": "Medium" }]
    }
  ]
}
```

### Checkout flow (`r` key)

`CheckoutDialog.showAndHandle(...)` handles payment. On `onConfirmed`:
1. Clears `_orderitem.lines` in memory.
2. Calls `DELETE /orderitem/{id}` to remove the row from `SHAREDTICKETS`.

### Attribute handling

- `attSetInstDesc` is a comma-separated string of attribute names (e.g. `"Medium, ohne Sauce"`).
- `attributes` is the resolved `[{id, name}]` list — IDs come from `ATTRIBUTEVALUE.ID` looked up on GET.
- On `OrderLine.fromJson`, Flutter tries `attributes` first; if empty, falls back to parsing `attSetInstDesc` by splitting on `,` with bracket-stripping.
- The backend `parseAttributes` splits `attSetInstDesc` on `\n`, `;`, or `,`.
- Matching for optimistic deduplication uses `attributes[].id` comparison (`_attributesMatch`).
