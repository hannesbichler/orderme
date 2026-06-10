import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/category.dart';
import '../models/orderitem.dart';
import '../models/orderline.dart';
import '../models/place.dart';
import '../models/product.dart';
import '../services/product_catalog_service.dart';
import 'checkout_dialog.dart';
import 'move_table_dialog.dart';
import 'product_attribute_dialog.dart';
import 'split_dialog.dart';

class TableOrderScreen extends StatefulWidget {
  final Place place;
  const TableOrderScreen({super.key, required this.place});

  @override
  State<TableOrderScreen> createState() => _TableOrderScreenState();
}

class _TableOrderScreenState extends State<TableOrderScreen> {
  static const _base = 'http://172.17.0.36:3000';
  static const double _productButtonHeight = 80;
  static const double _panelDividerHeight = 8;
  static const double _leftMinPaneHeight = 140;
  static const double _numpadMinHeight = 170;
  static const double _productsMinHeight = 120;
  final buttonsEnabledInLine = false; // set to false to hide + and - buttons in order lines
  // OrderItem (top-left)
  OrderItem? _orderitem;
  String? _orderitemError;

  // Panel sizing
  double _leftWidth = 260;
  double _ordersPaneHeight = 260;
  double _numpadPaneHeight = 250;

  // Categories (bottom-left)
  List<Category>? _categories;
  String? _categoriesError;
  Category? _selectedCategory;

  // Products (bottom-right)
  List<Product>? _allProducts;
  List<Product>? _products;
  String? _productsError;

  // Numpad input
  String _numInput = '';

  // Selected order line
  int? _selectedLineIdx;

  @override
  void initState() {
    super.initState();
    _fetchOrderItem();
//    _fetchCategories();
    _loadGlobalCategories();
    _loadGlobalProducts();
  }

  // ── Data fetchers ────────────────────────────────────────────────────────

  Future<void> _fetchOrderItem() async {
    setState(() { _orderitemError = null; _orderitem = null; });
    try {
      final uri = Uri.parse('$_base/orderitem/${widget.place.id}');
      final res = await http.get(uri);
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final body = json.decode(res.body) as Map<String, dynamic>;
      final orderitemMap = body;// as Map<String, dynamic>;
      setState(() {
        _orderitem = OrderItem.fromJson(orderitemMap);
      });
    } catch (e) {
      setState(() => _orderitemError = e.toString());
    }
  }

  // ── Add product to orderitem ────────────────────────────────────────────────

  bool _attributesMatch(OrderLine line, List<Attribute> selected) {
    final lineAtts = line.attributes ?? [];
    if (lineAtts.length != selected.length) return false;
    for (final sel in selected) {
      if (!lineAtts.any((a) => a.id == sel.id)) return false;
    }
    return true;
  }

  Future<void> _addProductToOrderItem(
    Product p, {
    List<Attribute>? selectedAttributes,
    OrderLine? orderLine,
  }) async {
    if (_orderitem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No open orderitem for this table.')),
      );
      return;
    }

    final attributes = (selectedAttributes ?? <Attribute>[])
        .map((a) => a.name.trim())
        .where((a) => a.isNotEmpty)
        .toList();

    final qty = int.tryParse(_numInput) ?? 1;
    setState(() => _numInput = '');

    // Optimistic update: increment qty or add a new line immediately
    final idx = _orderitem!.lines.indexWhere(
      (l) => l.productId == p.id && l.productName == p.name && _attributesMatch(l, selectedAttributes ?? <Attribute>[]),
    );
    if(orderLine != null) {
      final idx2 = _orderitem!.lines.indexWhere((l) => l == orderLine);
      if(idx2 >= 0) {
        _orderitem!.lines[idx2] = OrderLine(
          id: orderLine.id, orderId: orderLine.orderId,
          productId: orderLine.productId, productName: orderLine.productName,
          pricesell: orderLine.pricesell, qty: orderLine.qty, attSetInstDesc: attributes.join(', '), qtyNew: orderLine.qtyNew, attributes: selectedAttributes,
        );
      }
    }
    else if (idx >= 0) {
      final old = _orderitem!.lines[idx];
      _orderitem!.lines[idx] = OrderLine(
        id: old.id, orderId: old.orderId,
        productId: old.productId, productName: old.productName,
        pricesell: old.pricesell, qty: old.qty + qty, attSetInstDesc: old.attSetInstDesc, qtyNew: old.qtyNew + qty, attributes: old.attributes,
      );
    } else {
      _orderitem!.lines.add(OrderLine(
        id: '', orderId: _orderitem!.id_,
        productId: p.id, productName: p.name,
        pricesell: p.pricesell, qty: qty, attSetInstDesc: attributes.join(', '), qtyNew: qty, attributes: selectedAttributes,
      ));
    }
    setState(() {});

    // Sync with server
   /* try {
      final res = await http.post(
        Uri.parse('$_base/order-lines'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'orderId':   _orderitem!.id_,
          'productId': p.id,
          'pricesell': p.pricesell,
          'qty':       1,
        }),
      );
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      await _fetchOrderItem(); // refresh with server-confirmed data
    } catch (e) {
      await _fetchOrderItem(); // revert optimistic update
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding item: $e')),
        );
      }
    }*/
  }

  Future<void> _openAttributesAndAddProduct(Product? p, {OrderLine? line}) async {
    if(p == null) return;
    if(p.attributesetid == null || p.attributesetid!.isEmpty) {
      await _addProductToOrderItem(p);
      return;
    }
    final preselectedAttributes = line?.attributes;
    final selectedAttributes = await ProductAttributeDialog.show(
      context: context,
      product: p,
      baseUrl: _base,
      attributeSetId: p.attributesetid,
      preselectedAttributes: preselectedAttributes,
    );
    if (!mounted || selectedAttributes == null) return;
    await _addProductToOrderItem(
      p,
      selectedAttributes: selectedAttributes,
      orderLine: line,
    );
  }

  void _incrementLine(int idx) {
    final old = _orderitem!.lines[idx];
    _orderitem!.lines[idx] = OrderLine(
      id: old.id, orderId: old.orderId,
      productId: old.productId, productName: old.productName,
      pricesell: old.pricesell, qty: old.qty + 1, attSetInstDesc: old.attSetInstDesc, qtyNew: old.qtyNew + 1, attributes: old.attributes,
    );
    setState(() {});
  }

  void _decrementLine(int idx) {
    final old = _orderitem!.lines[idx];
    if (old.qty <= 1) {
      _orderitem!.lines.removeAt(idx);
      setState(() => _selectedLineIdx = null);
    } else {
      _orderitem!.lines[idx] = OrderLine(
        id: old.id, orderId: old.orderId,
        productId: old.productId, productName: old.productName,
        pricesell: old.pricesell, qty: old.qty - 1, attSetInstDesc: old.attSetInstDesc, qtyNew: old.qtyNew - 1, attributes: old.attributes,
      );
      setState(() {});
    }
  }

 /* Future<void> _fetchCategories() async {
    setState(() { _categoriesError = null; _categories = null; });
    try {
      final res = await http.get(
        Uri.parse('$_base/categories'));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final List<dynamic> data = json.decode(res.body)['_embedded']['categoryList'] as List<dynamic>;
    final categories = data
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
      
      setState(() {
        _categories = categories;
        _selectedCategory = null;
      });
      _applyProductFilter();
    } catch (e) {
      setState(() => _categoriesError = e.toString());
    }
  }*/
  
  void _applyProductFilter() {
    final products = _allProducts;
    if (products == null) return;

    setState(() {
      _products = _selectedCategory == null
          ? products
          : products.where((p) => p.categoryId == _selectedCategory!.id).toList();
    });
  }

  Future<void> _loadGlobalProducts() async {
    setState(() { _productsError = null; _products = null; });
    try {
      final products = await ProductCatalogService.instance.fetchProducts();
      setState(() {
        _allProducts = products;
      });
      _applyProductFilter();
    } catch (e) {
      setState(() => _productsError = e.toString());
    }
  }

  Future<void> _loadGlobalCategories() async {
    setState(() { _categoriesError = null; _categories = null; });
    try {
      final categories = await ProductCatalogService.instance.fetchCategories();
      final previousSelectedId = _selectedCategory?.id;
      final defaultCategory = categories.isEmpty
          ? null
          : categories.firstWhere(
              (c) => c.id == previousSelectedId,
              orElse: () => categories.first,
            );
      setState(() {
        _categories = categories;
        _selectedCategory = defaultCategory;
      });
      _applyProductFilter();
    } catch (e) {
      setState(() => _categoriesError = e.toString());
    }
  }

  void _makeOrder() {
    if (_orderitem == null) return;

    // Reset "new" quantity marker after checkout is completed.
    setState(() {
      for (var i = 0; i < _orderitem!.lines.length; i++) {
        _orderitem!.lines[i].setQtyNew( 0);
      }
    });
  }
  // ── Checkout dialog ──────────────────────────────────────────────────────

  Future<void> _showCheckoutDialog() async {
    if (_orderitem == null || _orderitem!.lines.isEmpty) return;

    final confirmed = await CheckoutDialog.show(
      context: context,
      orderitem: _orderitem!,
      placeName: widget.place.name,
    );

    if (!mounted || !confirmed) return;

    setState(() {
      _orderitem!.lines.clear();
      _selectedLineIdx = null;
      _numInput = '';
    });
  }

  Future<void> _showMoveTableDialog() async {
    try {
      final Place? chosenPlace = await MoveTableDialog.show(
        context: context,
        currentPlace: widget.place,
        baseUrl: _base,
      );

      if (!mounted || chosenPlace == null) return;

      if (_orderitem != null && _orderitem!.id_.isNotEmpty) {
        try {
          await http.post(
            Uri.parse('$_base/orderitem/${_orderitem!.id_}/move-table'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'fromPlaceId': widget.place.id,
              'toPlaceId': chosenPlace.id,
            }),
          );
        } catch (_) {
          // Keep UX responsive even if backend move endpoint is unavailable.
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TableOrderScreen(place: chosenPlace),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open move dialog: $e')),
      );
    }
  }

  Future<void> _saveOrderItem() async {
    if (_orderitem == null) return;

    _makeOrder();

    final payload = {
      'id': _orderitem!.id,
      'placeId': widget.place.id,
     // 'status': _orderitem!.status,
      'lines': _orderitem!.lines
          .map((line) => {
                'id': line.id,
                'orderId': line.orderId,
                'productId': line.productId,
                'productName': line.productName,
                'pricesell': line.pricesell,
                'qty': line.qty,
                'quantity': line.qty,
                'attSetInstDesc': line.attSetInstDesc ?? '',
                'attributes': (line.attributes ?? const <Attribute>[])
                    .map((a) => {
                          'id': a.id,
                          'name': a.name,
                        })
                    .toList(),
              })
          .toList(),
    };

    try {
      final response = await http.put(
        Uri.parse('$_base/orderitem/${_orderitem!.id_}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order saved.')),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save order: $e')),
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Table: ${widget.place.name}'),
        backgroundColor: const Color(0xFF3A6FFF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'speichern',
            onPressed: _orderitem == null ? null : _saveOrderItem,
          ),
          IconButton(
            icon: const Icon(Icons.call_split),
            tooltip: 'Beleg aufteilen',
            onPressed: _orderitem == null || _orderitem!.lines.isEmpty
                ? null
                : () async {
                    _makeOrder();
                    final splitTotal = await SplitDialog.show(
                      context: context,
                      orderitem: _orderitem!,
                      placeName: widget.place.name,
                    );

                    if (splitTotal == null) return;

                    _selectedLineIdx = null;
                    setState(() {});

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Geteilter Beleg Gesamt: €${splitTotal.toStringAsFixed(2)}',
                        ),
                      ),
                    );
                  },
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Move table',
            onPressed: _showMoveTableDialog,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF0F4FF),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxLeft = constraints.maxWidth - 180;
          return Row(
            children: [
              // ── Left panel ─────────────────────────────────────────────────
              SizedBox(
                width: _leftWidth.clamp(180, maxLeft),
                child: LayoutBuilder(
                  builder: (context, leftConstraints) {
                    final maxOrders =
                        leftConstraints.maxHeight - _panelDividerHeight - _leftMinPaneHeight;
                    final ordersHeight =
                        _ordersPaneHeight.clamp(_leftMinPaneHeight, maxOrders);
                    final categoriesHeight =
                        leftConstraints.maxHeight - _panelDividerHeight - ordersHeight;

                    return Column(
                      children: [
                        SizedBox(
                          height: ordersHeight,
                          child: _SectionCard(
                            title: 'Buchungen',
                            icon: Icons.receipt_long,
                            child: _buildOrdersList(),
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onVerticalDragUpdate: (d) {
                            setState(() {
                              _ordersPaneHeight = (_ordersPaneHeight + d.delta.dy)
                                  .clamp(_leftMinPaneHeight, maxOrders);
                            });
                          },
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeRow,
                            child: Container(
                              height: _panelDividerHeight,
                              color: Colors.transparent,
                              child: Center(
                                child: Container(
                                  height: 2,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 24),
                                  color: const Color(0xFFBBCCFF),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: categoriesHeight,
                          child: _SectionCard(
                            title: 'Produktgruppen',
                            icon: Icons.category_outlined,
                            child: _buildCategoriesList(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // ── Draggable divider ─────────────────────────────────────────
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (d) {
                  setState(() {
                    _leftWidth =
                        (_leftWidth + d.delta.dx).clamp(180, maxLeft);
                  });
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: Container(
                    width: 8,
                    color: Colors.transparent,
                    child: Center(
                      child: Container(
                        width: 2,
                        color: const Color(0xFFBBCCFF),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Right panel: products ───────────────────────────────────────
              Expanded(
                child: _SectionCard(
                  title: _selectedCategory != null
                      ? 'Produkte – ${_selectedCategory!.name}'
                      : 'Produkte',
                  icon: Icons.fastfood_outlined,
                  child: _buildProductsGrid(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Orders list (top-left) ───────────────────────────────────────────────

  Widget _buildOrdersList() {
    if (_orderitemError != null) {
      return _ErrorRetry(message: _orderitemError!, onRetry: _fetchOrderItem);
    }
    if (_orderitem == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final lines = _orderitem!.lines;
    if (lines.isEmpty) {
      return const Center(
          child: Text('No items in order.', style: TextStyle(color: Colors.grey)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Row(
            children: [
              const Text(
                'Gesamt',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '€${_orderitem!.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3A6FFF),
                ),
              ),
            ],
          ),
        ),
       /* Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Text('Order #${_orderitem!.id}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              _StatusChip(status: _orderitem!.status),
            ],
          ),
        ),*/
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: lines.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final line = lines[i];
              final selected = _selectedLineIdx == i;
              return GestureDetector(
                onTap: () => setState(
                    () => _selectedLineIdx = selected ? null : i),
                child: Container(
                  color: selected
                      ? const Color(0xFFE3EAFF)
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          (line.attSetInstDesc ?? '').trim().isEmpty
                              ? line.productName
                              : '${line.productName}\n[${line.attSetInstDesc}]',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: selected
                                ? const Color(0xFF1A237E)
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // ─ button (visible only when selected)
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: selected && buttonsEnabledInLine
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF3A6FFF),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  shape: const CircleBorder(),
                                  elevation: 1,
                                ),
                                onPressed: () => _decrementLine(i),
                                child: const Icon(Icons.remove,
                                    size: 14),
                              )
                            : null,
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 5),
                        child: Text(
                          line.qty == line.qtyNew
                              ? '${line.qty}'
                              : '${line.qty} (${line.qtyNew})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      // + button (visible only when selected)
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: selected && buttonsEnabledInLine
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF3A6FFF),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  shape: const CircleBorder(),
                                  elevation: 1,
                                ),
                                onPressed: () => _incrementLine(i),
                                child:
                                    const Icon(Icons.add, size: 14),
                              )
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '€${line.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: selected
                              ? const Color(0xFF1A237E)
                              : const Color(0xFF3A6FFF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (selected && buttonsEnabledInLine) ...[
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              shape: const CircleBorder(),
                              elevation: 1,
                            ),
                            onPressed: () {
                              _orderitem!.lines.removeAt(i);
                              setState(() => _selectedLineIdx = null);
                            },
                            child: const Icon(Icons.delete_outline, size: 14),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Categories tree (bottom-left) ────────────────────────────────────────

  Widget _buildCategoriesList() {
    if (_categoriesError != null) {
      return _ErrorRetry(
          message: _categoriesError!, /*onRetry: _loadGlobalCategories()*/);
    }
    if (_categories == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_categories!.isEmpty) {
      return const Center(
          child: Text('No categories.', style: TextStyle(color: Colors.grey)));
    }

    // Build parent-id → children map
    final Map<String, List<Category>> childrenOf = {};
   // final List<Category> roots = [];

  /*  for (final cat in _categories!) {
      final pid = cat.parentId;
      if (pid == null || pid.isEmpty) {
        roots.add(cat);
      } else {
        childrenOf.putIfAbsent(pid, () => []).add(cat);
      }
    }*/

    // Fall back to flat list when no parent info is available
   // if (roots.isEmpty) roots.addAll(_categories!);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: _categories!
          .map((cat) => _buildCategoryNode(cat, childrenOf, 0))
          .toList(),
    );
  }

  Widget _buildCategoryNode(
      Category cat, Map<String, List<Category>> childrenOf, int depth) {
    final children = cat.children ?? [];
    final selected = _selectedCategory?.id == cat.id;

    void select() {
      setState(() => _selectedCategory = cat);
      _applyProductFilter();
    }

    if (children.isEmpty) {
      return _CategoryTreeTile(
        category: cat,
        depth: depth,
        selected: selected,
        isParent: false,
        onSelect: select,
        children: const [],
      );
    }

    return _CategoryTreeTile(
      category: cat,
      depth: depth,
      selected: selected,
      isParent: true,
      onSelect: select,
      children: children
          .map((c) => _buildCategoryNode(c, childrenOf, depth + 1))
          .toList(),
    );
  }

  // ── Numpad ───────────────────────────────────────────────────────────────

  Widget _buildNumpad() {
    final display = _numInput.isEmpty ? '1' : _numInput;

    bool canEditSelectedLineAttributes() {
      if (_selectedLineIdx == null || _orderitem == null) return false;
      if (_selectedLineIdx! < 0 || _selectedLineIdx! >= _orderitem!.lines.length) {
        return false;
      }

      final selectedLine = _orderitem!.lines[_selectedLineIdx!];
      final productsSource = _allProducts ?? _products ?? const <Product>[];
      Product? product;
      try {
        product = productsSource.firstWhere(
          (p) => p.id.toUpperCase() == selectedLine.productId.toUpperCase(),
        );
      } catch (_) {
        return false;
      }

      final attributeSetId = product.attributesetid?.trim() ?? '';
      return attributeSetId.isNotEmpty;
    }

    final keys = [
      ['7', '8', '9', '-'],
      ['4', '5', '6', '+'],
      ['1', '2', '3', 'd'],
      ['⌫', '0', 'C', 'r'],
      ['a'],
    //  ['-', 'd', '+'],
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: const BoxDecoration(
        color: Color(0xFFEEF2FF),
        border: Border(bottom: BorderSide(color: Color(0xFFBBCCFF))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Display
          Container(
            width:  double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF3A6FFF), width: 1.2),
            ),
            child: Row(
              children: [
                const Icon(Icons.tag, size: 18, color: Color(0xFF3A6FFF)),
                const SizedBox(width: 4),
                Text(
                  display,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _numInput.isEmpty
                        ? Colors.grey.shade400
                        : const Color(0xFF1A237E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Key rows
          ...keys.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: row.map((key) {
                    final isAction = key == '⌫' || key == 'C';
                    final needsSelection = key == '-' || key == '+' || key == 'd';
                    final isAttributeKey = key == 'a';
                    final isDisabled =
                        (needsSelection && _selectedLineIdx == null) ||
                        (isAttributeKey && !canEditSelectedLineAttributes());
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDisabled
                                  ? Colors.grey.shade200
                                  : isAction
                                      ? const Color(0xFFD0D8FF)
                                      : Colors.white,
                              foregroundColor: isDisabled
                                  ? Colors.grey.shade400
                                  : const Color(0xFF1A237E),
                              elevation: isDisabled ? 0 : 1,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                    color: isDisabled
                                        ? Colors.grey.shade300
                                        : const Color(0xFF3A6FFF),
                                    width: 0.8),
                              ),
                            ),
                            onPressed: isDisabled ? null : () {
                              setState(() {
                                if (key == 'C') {
                                  _numInput = '';
                                } else if (key == '⌫') {
                                  if (_numInput.isNotEmpty) {
                                    _numInput = _numInput.substring(
                                        0, _numInput.length - 1);
                                  }
                                } else if(key == '-') {
                                  _decrementLine(_selectedLineIdx!);
                                } else if(key == '+') {
                                  _incrementLine(_selectedLineIdx!);
                                } else if(key == 'd') {
                                  _orderitem!.lines.removeAt(_selectedLineIdx!);
                                  _selectedLineIdx = null;
                                } else if(key == 'r') {
                                  _orderitem == null || _orderitem!.lines.isEmpty
                                  ? null
                                  : _showCheckoutDialog();
                                } else if(key == 'a') {
                                  Product? product;
                                  String? prodid;
                                  OrderLine? line;
                                  _products == null || _products!.isEmpty || _selectedLineIdx == null
                                  ? null
                                   : 
                                    line = _orderitem!.lines[_selectedLineIdx!];
                                    prodid = line?.productId;
                                    product = _products?.firstWhere(
                                      (p) { 
                                        return p.id.toUpperCase() == prodid?.toUpperCase();
                                      }
                                    );
                                    _openAttributesAndAddProduct(product, line: line);
                                   
                                } else {
                                  if (_numInput.length < 4) {
                                    _numInput += key;
                                  }
                                }
                              });
                            },
                            child: key == '⌫'
                                ? const Icon(Icons.backspace_outlined, size: 18)
                                : key == 'd'
                                  ?  const Icon(Icons.delete_outline, size: 18)
                                  : key == 'r'
                                    ? //const Icon(Icons.receipt, size: 18)
                                    Text("Rechnung",
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold))
                                    :
                                  Text(key,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              )),
        ],
      ),
    );
  }

  // ── Products grid (right) ────────────────────────────────────────────────

  Widget _buildProductsGrid() {
    if (_productsError != null) {
      return _ErrorRetry(
          message: _productsError!,
          onRetry: _loadGlobalProducts);
    }
    if (_products == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxNumpad =
            constraints.maxHeight - _panelDividerHeight - _productsMinHeight;
        final numpadHeight =
            _numpadPaneHeight.clamp(_numpadMinHeight, maxNumpad);
        final productsHeight =
            constraints.maxHeight - _panelDividerHeight - numpadHeight;

        return Column(
          children: [
            SizedBox(
              height: numpadHeight,
              child: _buildNumpad(),
            ),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: (d) {
                setState(() {
                  _numpadPaneHeight = (_numpadPaneHeight + d.delta.dy)
                      .clamp(_numpadMinHeight, maxNumpad);
                });
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeRow,
                child: Container(
                  height: _panelDividerHeight,
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      color: const Color(0xFFBBCCFF),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: productsHeight,
              child: _products!.isEmpty
                  ? const Center(
                      child: Text(
                        'Keine Produkte in dieser Kategorie.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 160,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        mainAxisExtent: _productButtonHeight,
                      ),
                      itemCount: _products!.length,
                      itemBuilder: (context, i) {
                        final p = _products![i];
                        return _ProductCard(
                          product: p,
                          onTap: () => _openAttributesAndAddProduct(p),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF3A6FFF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  const _ProductCard({required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF3A6FFF), width: 1),
        ),
        padding: const EdgeInsets.all(5),
      ),
      onPressed: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
         // const Icon(Icons.fastfood, size: 32, color: Color(0xFF3A6FFF)),
          const SizedBox(height: 6),
          Text(product.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            '€${product.pricesell.toStringAsFixed(2)}',
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF3A6FFF),
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CategoryTreeTile extends StatefulWidget {
  final Category category;
  final int depth;
  final bool selected;
  final bool isParent;
  final VoidCallback onSelect;
  final List<Widget> children;

  const _CategoryTreeTile({
    required this.category,
    required this.depth,
    required this.selected,
    required this.isParent,
    required this.onSelect,
    required this.children,
  });

  @override
  State<_CategoryTreeTile> createState() => _CategoryTreeTileState();
}

class _CategoryTreeTileState extends State<_CategoryTreeTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final indent = widget.depth * 16.0;
    final color =
        widget.selected ? const Color(0xFF3A6FFF) : Colors.grey.shade500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            widget.onSelect();
            if (widget.isParent) setState(() => _expanded = !_expanded);
          },
          child: Container(
            color: widget.selected ? const Color(0xFFE3EAFF) : null,
            padding: EdgeInsets.only(
                left: 8 + indent, right: 8, top: 7, bottom: 7),
            child: Row(
              children: [
                Icon(
                  widget.isParent
                      ? (_expanded
                          ? Icons.folder_open_outlined
                          : Icons.folder_outlined)
                      : Icons.label_outline,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.category.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: widget.selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: widget.selected
                          ? const Color(0xFF1A237E)
                          : null,
                    ),
                  ),
                ),
                if (widget.isParent)
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
              ],
            ),
          ),
        ),
        if (_expanded) ...widget.children,
      ],
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _ErrorRetry({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 32),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 11, color: Colors.red)),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
