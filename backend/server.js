'use strict';

const express = require('express');
const oracledb = require('oracledb');
const { exec } = require('child_process');
const { promisify } = require('util');
const fs = require('fs');
const path = require('path');
const os = require('os');

const execAsync = promisify(exec);

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// ── Oracle connection config ──────────────────────────────────────────────────
// Adjust DB_CONNECT_STRING if your Oracle listener is on a different host/port/service.
// Format: "host:port/serviceName"  or just "//host/service"
const DB_CONFIG = {
  user: process.env.DB_USER || 'w4cash',
  password: process.env.DB_PASSWORD || 'w4cash',
  connectString: process.env.DB_CONNECT_STRING || 'localhost:1521/xe',
};

// Use thin mode – no Oracle Client libraries required
oracledb.initOracleClient === undefined; // thin mode is default in v6+

// ── Routes ────────────────────────────────────────────────────────────────────

/**
 * GET /users
 * Returns all rows from the PEOPLE table mapped to:
 * { id, name, username, email, phone, website }
 *
 * Adjust the SELECT column names below to match your actual PEOPLE table.
 */
app.get('/users', async (req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(DB_CONFIG);

    // Fetch rows as plain objects (key names become lowercase automatically)
    const result = await connection.execute(
      `SELECT id, name, username, email, phone, website FROM people ORDER BY id`,
      [],
      { outFormat: oracledb.OUT_FORMAT_OBJECT }
    );

    const users = result.rows.map((row) => ({
      id:       Number(row.ID),
      name:     row.NAME     ?? '',
      username: row.USERNAME ?? '',
      email:    row.EMAIL    ?? '',
      phone:    row.PHONE    ?? '',
      website:  row.WEBSITE  ?? '',
    }));

    res.json(users);
  } catch (err) {
    console.error('Database error:', err.message);
    res.status(500).json({ error: 'Failed to fetch users', detail: err.message });
  } finally {
    if (connection) {
      try { await connection.close(); } catch (_) {}
    }
  }
});

/**
 * GET /users/:id
 * Returns a single user by ID.
 */
app.get('/users/:id', async (req, res) => {
  const id = parseInt(req.params.id, 10);
  if (isNaN(id)) return res.status(400).json({ error: 'Invalid id' });

  let connection;
  try {
    connection = await oracledb.getConnection(DB_CONFIG);

    const result = await connection.execute(
      `SELECT id, name, username, email, phone, website FROM people WHERE id = :id`,
      [id],
      { outFormat: oracledb.OUT_FORMAT_OBJECT }
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const row = result.rows[0];
    res.json({
      id:       Number(row.ID),
      name:     row.NAME     ?? '',
      username: row.USERNAME ?? '',
      email:    row.EMAIL    ?? '',
      phone:    row.PHONE    ?? '',
      website:  row.WEBSITE  ?? '',
    });
  } catch (err) {
    console.error('Database error:', err.message);
    res.status(500).json({ error: 'Failed to fetch user', detail: err.message });
  } finally {
    if (connection) {
      try { await connection.close(); } catch (_) {}
    }
  }
});

/**
 * GET /places/floor/:floorId
 * Returns all places on a given floor.
 */
app.get('/places/floor/:floorId', async (req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(DB_CONFIG);

    const result = await connection.execute(
      `SELECT id, name, floor_id FROM places WHERE floor_id = :floorId ORDER BY id`,
      [req.params.floorId],
      { outFormat: oracledb.OUT_FORMAT_OBJECT }
    );

    const places = result.rows.map((row) => ({
      id:      String(row.ID),
      name:    row.NAME     ?? '',
      floorId: String(row.FLOOR_ID ?? ''),
    }));

    res.json({ places });
  } catch (err) {
    console.error('Database error:', err.message);
    res.status(500).json({ error: 'Failed to fetch places', detail: err.message });
  } finally {
    if (connection) {
      try { await connection.close(); } catch (_) {}
    }
  }
});

/**
 * GET /places?floorId=<id>
 * Returns all rows from the PLACES table (optionally filtered by floor).
 * { id, name, floorId }
 */
app.get('/places', async (req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(DB_CONFIG);

    const floorId = req.query.floorId;
    let sql, binds;
    if (floorId !== undefined) {
      sql    = `SELECT id, name, floor_id FROM places WHERE floor_id = :floorId ORDER BY id`;
      binds  = [floorId];
    } else {
      sql    = `SELECT id, name, floor_id FROM places ORDER BY id`;
      binds  = [];
    }

    const result = await connection.execute(sql, binds,
      { outFormat: oracledb.OUT_FORMAT_OBJECT });

    const places = result.rows.map((row) => ({
      id:      String(row.ID),
      name:    row.NAME     ?? '',
      floorId: String(row.FLOOR_ID ?? ''),
    }));

    res.json({ places });
  } catch (err) {
    console.error('Database error:', err.message);
    res.status(500).json({ error: 'Failed to fetch places', detail: err.message });
  } finally {
    if (connection) {
      try { await connection.close(); } catch (_) {}
    }
  }
});

/**
 * GET /floors
 * Returns all rows from the FLOORS table mapped to:
 * { id, name }
 */
app.get('/floors', async (_req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(DB_CONFIG);

    const result = await connection.execute(
      `SELECT id, name FROM floors ORDER BY id`,
      [],
      { outFormat: oracledb.OUT_FORMAT_OBJECT }
    );

    const floors = result.rows.map((row) => ({
      id:   String(row.ID),
      name: row.NAME ?? '',
    }));

    res.json({ floors });
  } catch (err) {
    console.error('Database error:', err.message);
    res.status(500).json({ error: 'Failed to fetch floors', detail: err.message });
  } finally {
    if (connection) {
      try { await connection.close(); } catch (_) {}
    }
  }
});

// Health check
app.get('/health', (_req, res) => res.json({ status: 'ok' }));

/**
 * GET /ticketinfo?placeId=<id>
 * Returns open ticketinfos for a place (table), each with embedded line items.
 * { id, placeId, status, note, items: [{id, orderId, productId, productName, price, qty}] }
 */
app.get('/ticketinfo', async (req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(DB_CONFIG);

    const placeId = req.query.placeId;
    let sql, binds;
    if (placeId !== undefined) {
      sql   = `SELECT id, place_id, status, note FROM ticketinfo WHERE place_id = :placeId ORDER BY id`;
      binds = [placeId];
    } else {
      sql   = `SELECT id, place_id, status, note FROM ticketinfo ORDER BY id`;
      binds = [];
    }

    const result = await connection.execute(sql, binds,
      { outFormat: oracledb.OUT_FORMAT_OBJECT });

    // For each ticketinfo, fetch its line items
    const ticketinfos = await Promise.all(result.rows.map(async (row) => {
      const ticketinfoId = String(row.ID);
      const linesResult = await connection.execute(
        `SELECT ol.id, ol.order_id, ol.product_id, p.name AS product_name, ol.price, ol.qty
           FROM order_lines ol
           JOIN products p ON p.id = ol.product_id
          WHERE ol.order_id = :orderId
          ORDER BY ol.id`,
        [ticketinfoId],
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );
      const items = linesResult.rows.map((lr) => ({
        id:          String(lr.ID),
        orderId:     String(lr.ORDER_ID),
        productId:   String(lr.PRODUCT_ID),
        productName: lr.PRODUCT_NAME ?? '',
        price:       Number(lr.PRICE ?? 0),
        qty:         Number(lr.QTY ?? 1),
      }));
      return {
        id:      ticketinfoId,
        placeId: String(row.PLACE_ID ?? ''),
        status:  row.STATUS ?? '',
        note:    row.NOTE   ?? '',
        items,
      };
    }));

    res.json({ orders });
  } catch (err) {
    console.error('Database error:', err.message);
    res.status(500).json({ error: 'Failed to fetch orders', detail: err.message });
  } finally {
    if (connection) {
      try { await connection.close(); } catch (_) {}
    }
  }
});

/**
 * GET /order-lines?orderId=<id>
 * Returns line items for a single order.
 * { id, orderId, productId, productName, price, qty }
 */
app.get('/order-lines', async (req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(DB_CONFIG);

    const orderId = req.query.orderId;
    let sql, binds;
    if (orderId !== undefined) {
      sql   = `SELECT ol.id, ol.order_id, ol.product_id, p.name AS product_name, ol.price, ol.qty
                 FROM order_lines ol
                 JOIN products p ON p.id = ol.product_id
                WHERE ol.order_id = :orderId
                ORDER BY ol.id`;
      binds = [orderId];
    } else {
      sql   = `SELECT ol.id, ol.order_id, ol.product_id, p.name AS product_name, ol.price, ol.qty
                 FROM order_lines ol
                 JOIN products p ON p.id = ol.product_id
                ORDER BY ol.id`;
      binds = [];
    }

    const result = await connection.execute(sql, binds,
      { outFormat: oracledb.OUT_FORMAT_OBJECT });

    const lines = result.rows.map((row) => ({
      id:          String(row.ID),
      orderId:     String(row.ORDER_ID),
      productId:   String(row.PRODUCT_ID),
      productName: row.PRODUCT_NAME ?? '',
      price:       Number(row.PRICE ?? 0),
      qty:         Number(row.QTY ?? 1),
    }));

    res.json({ lines });
  } catch (err) {
    console.error('Database error:', err.message);
    res.status(500).json({ error: 'Failed to fetch order lines', detail: err.message });
  } finally {
    if (connection) {
      try { await connection.close(); } catch (_) {}
    }
  }
});

/**
 * GET /categories
 * Returns all product categories in HAL format.
 * { _embedded: { categoryList: [{ id_, name, parent }] } }
 */
app.get('/categories', async (_req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(DB_CONFIG);

    const result = await connection.execute(
      `SELECT ID, NAME, PARENT FROM CATEGORIES ORDER BY ID`,
      [],
      { outFormat: oracledb.OUT_FORMAT_OBJECT }
    );

    const categoryList = result.rows.map((row) => ({
      id_:    String(row.ID),
      name:   row.NAME ?? '',
      parent: row.PARENT != null ? String(row.PARENT) : null,
    }));

    res.json({ _embedded: { categoryList } });
  } catch (err) {
    console.error('Database error:', err.message);
    res.status(500).json({ error: 'Failed to fetch categories', detail: err.message });
  } finally {
    if (connection) {
      try { await connection.close(); } catch (_) {}
    }
  }
});

/**
 * GET /products
 * Returns all products in HAL format (used by Flutter client).
 * { _embedded: { productList: [{ id_, name, pricesell, categoryId }] } }
 */
app.get('/products', async (_req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(DB_CONFIG);

    const result = await connection.execute(
      `SELECT ID, NAME, PRICESELL, CATEGORY, ATTRIBUTESET_ID
         FROM PRODUCTS
        ORDER BY ID`,
      [],
      { outFormat: oracledb.OUT_FORMAT_OBJECT }
    );

    const productList = result.rows.map((row) => ({
      id_:        String(row.ID),
      name:       row.NAME ?? '',
      pricesell:  Number(row.PRICESELL ?? 0),
      categoryId: String(row.CATEGORY ?? ''),
      attributeSetId: row.ATTRIBUTESET_ID != null ? String(row.ATTRIBUTESET_ID) : null,
    }));

    res.json({ _embedded: { productList } });
  } catch (err) {
    console.error('Database error:', err.message);
    res.status(500).json({ error: 'Failed to fetch products', detail: err.message });
  } finally {
    if (connection) {
      try { await connection.close(); } catch (_) {}
    }
  }
});

/**
 * GET /products/:categoryId
 * Returns products for a category in HAL format (used by Flutter client).
 * { _embedded: { productList: [{ id_, name, pricesell, categoryId }] } }
 */
app.get('/products/:categoryId', async (req, res) => {
  const { categoryId } = req.params;
  let connection;
  try {
    connection = await oracledb.getConnection(DB_CONFIG);

    const result = await connection.execute(
      `SELECT ID, NAME, PRICESELL, CATEGORY, ATTRIBUTESET_ID
         FROM PRODUCTS
        WHERE CATEGORY = :catId
        ORDER BY ID`,
      [categoryId],
      { outFormat: oracledb.OUT_FORMAT_OBJECT }
    );

    const productList = result.rows.map((row) => ({
      id_:        String(row.ID),
      name:       row.NAME ?? '',
      pricesell:  Number(row.PRICESELL ?? 0),
      categoryId: String(row.CATEGORY ?? ''),
      attributeSetId: row.ATTRIBUTESET_ID != null ? String(row.ATTRIBUTESET_ID) : null,
    }));

    res.json({ _embedded: { productList } });
  } catch (err) {
    console.error('Database error:', err.message);
    res.status(500).json({ error: 'Failed to fetch products', detail: err.message });
  } finally {
    if (connection) {
      try { await connection.close(); } catch (_) {}
    }
  }
});

/**
 * GET /attributes?attributeSetId=<id>
 * Returns attribute names and possible values for a product attribute set.
 * {
 *   attributes: ["Size", "Sauce"],
 *   additionalAttributes: ["Small", "Medium", "Hot", "Mild"]
 * }
 */
app.get('/attributes', async (req, res) => {
  const attributeSetId = req.query.attributeSetId || req.query.setId;
  if (!attributeSetId) {
    return res.status(400).json({ error: 'attributeSetId (or setId) is required' });
  }

  let connection;
  try {
    connection = await oracledb.getConnection(DB_CONFIG);

    const attrResult = await connection.execute(
      `SELECT a.name
         FROM attributeuse au
         JOIN attribute a ON a.id = au.attribute_id
        WHERE au.attributeset_id = :setId
        ORDER BY au.lineno, a.name`,
      [String(attributeSetId)],
      { outFormat: oracledb.OUT_FORMAT_OBJECT }
    );

    const valueResult = await connection.execute(
      `SELECT av.value
         FROM attributeuse au
         JOIN attributevalue av ON av.attribute_id = au.attribute_id
        WHERE au.attributeset_id = :setId
        ORDER BY av.lineno, av.value`,
      [String(attributeSetId)],
      { outFormat: oracledb.OUT_FORMAT_OBJECT }
    );

    const attributes = [...new Set(
      attrResult.rows
        .map((row) => (row.NAME ?? '').trim())
        .filter((name) => name.length > 0)
    )];

    const additionalAttributes = [...new Set(
      valueResult.rows
        .map((row) => (row.VALUE ?? '').trim())
        .filter((value) => value.length > 0)
    )];

    res.json({ attributes, additionalAttributes });
  } catch (err) {
    console.error('Database error:', err.message);
    res.status(500).json({ error: 'Failed to fetch attributes', detail: err.message });
  } finally {
    if (connection) {
      try { await connection.close(); } catch (_) {}
    }
  }
});

/**
 * GET /products?categoryId=<id>
 * Returns products, optionally filtered by category.
 * { id, name, price, categoryId }
 */
app.get('/products', async (req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(DB_CONFIG);

    const categoryId = req.query.categoryId;
    let sql, binds;
    if (categoryId !== undefined) {
      sql   = `SELECT id, name, price, category_id FROM products WHERE category_id = :categoryId ORDER BY id`;
      binds = [categoryId];
    } else {
      sql   = `SELECT id, name, price, category_id FROM products ORDER BY id`;
      binds = [];
    }

    const result = await connection.execute(sql, binds,
      { outFormat: oracledb.OUT_FORMAT_OBJECT });

    const products = result.rows.map((row) => ({
      id:         String(row.ID),
      name:       row.NAME ?? '',
      price:      Number(row.PRICE ?? 0),
      categoryId: String(row.CATEGORY_ID ?? ''),
    }));

    res.json({ products });
  } catch (err) {
    console.error('Database error:', err.message);
    res.status(500).json({ error: 'Failed to fetch products', detail: err.message });
  } finally {
    if (connection) {
      try { await connection.close(); } catch (_) {}
    }
  }
});



/**
 * POST /order-lines
 * Adds a product to an order. If the product is already in the order, increments qty.
 * Body: { "orderId": "1", "productId": "2", "price": 2.50, "qty": 1 }
 */
app.post('/order-lines', async (req, res) => {
  const { orderId, productId, price, qty = 1 } = req.body;
  if (!orderId || !productId) {
    return res.status(400).json({ error: '"orderId" and "productId" are required' });
  }
  let connection;
  try {
    connection = await oracledb.getConnection(DB_CONFIG);

    const existing = await connection.execute(
      `SELECT id FROM order_lines WHERE order_id = :orderId AND product_id = :productId`,
      [String(orderId), String(productId)],
      { outFormat: oracledb.OUT_FORMAT_OBJECT }
    );

    if (existing.rows.length > 0) {
      const lineId = String(existing.rows[0].ID);
      await connection.execute(
        `UPDATE order_lines SET qty = qty + :qty WHERE id = :id`,
        [Number(qty), lineId]
      );
      await connection.commit();
      res.json({ success: true, action: 'updated', id: lineId });
    } else {
      const result = await connection.execute(
        `INSERT INTO order_lines (order_id, product_id, price, qty)
         VALUES (:orderId, :productId, :price, :qty)
         RETURNING id INTO :newId`,
        {
          orderId:   String(orderId),
          productId: String(productId),
          price:     Number(price ?? 0),
          qty:       Number(qty),
          newId:     { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
        }
      );
      await connection.commit();
      const newId = String(result.outBinds.newId[0]);
      res.json({ success: true, action: 'inserted', id: newId });
    }
  } catch (err) {
    console.error('Database error:', err.message);
    res.status(500).json({ error: 'Failed to add order line', detail: err.message });
  } finally {
    if (connection) {
      try { await connection.close(); } catch (_) {}
    }
  }
});


// ── Printers ──────────────────────────────────────────────────────────────────

/**
 * GET /printers
 * Returns all locally installed printers.
 */
app.get('/printers', async (_req, res) => {
  try {
    const { stdout } = await execAsync(
      `powershell -NoProfile -Command "Get-Printer | Select-Object Name,DriverName,PortName,PrinterStatus,Default | ConvertTo-Json -Compress"`
    );
    let printers = JSON.parse(stdout.trim());
    // PowerShell returns an object (not array) when there is only one printer
    if (!Array.isArray(printers)) printers = [printers];
    res.json(printers);
  } catch (err) {
    console.error('Printer list error:', err.message);
    res.status(500).json({ error: 'Failed to list printers', detail: err.message });
  }
});

/**
 * GET /printers/default
 * Returns the name of the default printer.
 */
app.get('/printers/default', async (_req, res) => {
  try {
    const { stdout } = await execAsync(
      `powershell -NoProfile -Command "(Get-Printer | Where-Object Default -eq $true | Select-Object -First 1 -ExpandProperty Name)"`
    );
    res.json({ name: stdout.trim() });
  } catch (err) {
    console.error('Default printer error:', err.message);
    res.status(500).json({ error: 'Failed to get default printer', detail: err.message });
  }
});

/**
 * POST /print/text
 * Prints plain text to a printer.
 *
 * Body: { "text": "Hello World", "printer": "My Printer" }
 *       "printer" is optional – omit to use the default printer.
 */
app.post('/print/text', async (req, res) => {
  const { text, printer } = req.body;
  if (typeof text !== 'string' || text.trim() === '') {
    return res.status(400).json({ error: '"text" field is required' });
  }

  // Write text to a temp file so PowerShell can read it safely
  const tmpFile = path.join(os.tmpdir(), `orderme_print_${Date.now()}.txt`);
  try {
    fs.writeFileSync(tmpFile, text, 'utf8');

    const printerArg = printer
      ? `-PrinterName "${printer.replace(/"/g, '')}"`
      : '';

    await execAsync(
      `powershell -NoProfile -Command "Get-Content -Path '${tmpFile}' -Raw | Out-Printer ${printerArg}"`
    );

    res.json({ success: true });
  } catch (err) {
    console.error('Print error:', err.message);
    res.status(500).json({ error: 'Print failed', detail: err.message });
  } finally {
    try { fs.unlinkSync(tmpFile); } catch (_) {}
  }
});

/**
 * POST /print/file
 * Prints a file (PDF, TXT, etc.) using the associated application.
 *
 * Body: { "filePath": "C:\\path\\to\\file.pdf", "printer": "My Printer" }
 *       "printer" is optional – omit to use the default printer.
 */
app.post('/print/file', async (req, res) => {
  const { filePath, printer } = req.body;
  if (typeof filePath !== 'string' || filePath.trim() === '') {
    return res.status(400).json({ error: '"filePath" field is required' });
  }
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'File not found' });
  }

  try {
    const safeFile = filePath.replace(/"/g, '');
    const printerArg = printer
      ? `-ArgumentList '/pt","${safeFile}","${printer.replace(/"/g, '')}'`
      : `-ArgumentList '/p","${safeFile}'`;

    // Use Acrobat / shell print verb; falls back to system default handler
    await execAsync(
      `powershell -NoProfile -Command "Start-Process -FilePath '${safeFile}' -Verb PrintTo ${printer ? `'${printer.replace(/'/g, '')}'` : ''} -Wait" 2>&1 || true`
    );

    res.json({ success: true });
  } catch (err) {
    console.error('File print error:', err.message);
    res.status(500).json({ error: 'File print failed', detail: err.message });
  }
});


// ── Start ─────────────────────────────────────────────────────────────────────
app.listen(PORT, '0.0.0.0', () => {
  console.log(`OrderMe user service running on http://0.0.0.0:${PORT}`);
  console.log(`  GET  /users            – all users from PEOPLE table`);
  console.log(`  GET  /users/:id        – single user`);
  console.log(`  GET  /health           – health check`);
  console.log(`  GET  /printers         – list local printers`);
  console.log(`  GET  /printers/default – default printer name`);
  console.log(`  POST /print/text       – print plain text`);
  console.log(`  POST /print/file       – print a local file`);
  console.log(`Oracle: ${DB_CONFIG.user}@${DB_CONFIG.connectString}`);
});
