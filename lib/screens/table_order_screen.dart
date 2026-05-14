import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/category.dart';
import '../models/order_item.dart';
import '../models/place.dart';
import '../models/product.dart';

class TableOrderScreen extends StatefulWidget {
  final Place place;
  const TableOrderScreen({super.key, required this.place});

  @override
  State<TableOrderScreen> createState() => _TableOrderScreenState();
}

class _TableOrderScreenState extends State<TableOrderScreen> {
  static const _base = 'http://172.17.0.36:3000';

  // Orders (top-left)
  List<OrderItem>? _orders;
  String? _ordersError;

  // Categories (bottom-left)
  List<Category>? _categories;
  String? _categoriesError;
  Category? _selectedCategory;

  // Products (bottom-right)
  List<Product>? _products;
  String? _productsError;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _fetchCategories();
  }

  // ── Data fetchers ────────────────────────────────────────────────────────

  Future<void> _fetchOrders() async {
    setState(() { _ordersError = null; _orders = null; });
    try {
      final uri = Uri.parse('$_base/orders')
          .replace(queryParameters: {'placeId': widget.place.id});
      final res = await http.get(uri);
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final body = json.decode(res.body);
      final List<dynamic> raw =
          (body is Map && body.containsKey('orders')) ? body['orders'] : body;
      setState(() {
        _orders =
            raw.map((e) => OrderItem.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (e) {
      setState(() => _ordersError = e.toString());
    }
  }

  Future<void> _fetchCategories() async {
    setState(() { _categoriesError = null; _categories = null; });
    try {
      final res = await http.get(Uri.parse('$_base/categories'));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final body = json.decode(res.body);
      final List<dynamic> raw = (body is Map && body.containsKey('categories'))
          ? body['categories']
          : body;
      final categories =
          raw.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
      setState(() {
        _categories = categories;
        if (categories.isNotEmpty) {
          _selectedCategory = categories.first;
          _fetchProducts(categories.first.id);
        }
      });
    } catch (e) {
      setState(() => _categoriesError = e.toString());
    }
  }

  Future<void> _fetchProducts(String categoryId) async {
    setState(() { _productsError = null; _products = null; });
    try {
      final uri = Uri.parse('$_base/products')
          .replace(queryParameters: {'categoryId': categoryId});
      final res = await http.get(uri);
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final body = json.decode(res.body);
      final List<dynamic> raw =
          (body is Map && body.containsKey('products')) ? body['products'] : body;
      setState(() {
        _products =
            raw.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (e) {
      setState(() => _productsError = e.toString());
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Table: ${widget.place.name}'),
        backgroundColor: const Color(0xFF3A6FFF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              _fetchOrders();
              if (_selectedCategory != null) {
                _fetchProducts(_selectedCategory!.id);
              }
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF0F4FF),
      body: Row(
        children: [
          // ── Left panel ─────────────────────────────────────────────────
          SizedBox(
            width: 260,
            child: Column(
              children: [
                // Top-left: booked orders
                Expanded(
                  child: _SectionCard(
                    title: 'Booked Orders',
                    icon: Icons.receipt_long,
                    child: _buildOrdersList(),
                  ),
                ),
                // Bottom-left: categories
                Expanded(
                  child: _SectionCard(
                    title: 'Categories',
                    icon: Icons.category_outlined,
                    child: _buildCategoriesList(),
                  ),
                ),
              ],
            ),
          ),

          const VerticalDivider(width: 1),

          // ── Right panel: products ───────────────────────────────────────
          Expanded(
            child: _SectionCard(
              title: _selectedCategory != null
                  ? 'Products – ${_selectedCategory!.name}'
                  : 'Products',
              icon: Icons.fastfood_outlined,
              child: _buildProductsGrid(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Orders list (top-left) ───────────────────────────────────────────────

  Widget _buildOrdersList() {
    if (_ordersError != null) {
      return _ErrorRetry(
          message: _ordersError!, onRetry: _fetchOrders);
    }
    if (_orders == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_orders!.isEmpty) {
      return const Center(
          child: Text('No orders yet.',
              style: TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _orders!.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final order = _orders![i];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.circle, size: 10, color: Color(0xFF3A6FFF)),
          title: Text(order.note.isNotEmpty ? order.note : '#${order.id}',
              style: const TextStyle(fontSize: 13)),
          trailing: _StatusChip(status: order.status),
        );
      },
    );
  }

  // ── Categories list (bottom-left) ────────────────────────────────────────

  Widget _buildCategoriesList() {
    if (_categoriesError != null) {
      return _ErrorRetry(
          message: _categoriesError!, onRetry: _fetchCategories);
    }
    if (_categories == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_categories!.isEmpty) {
      return const Center(
          child: Text('No categories.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _categories!.length,
      itemBuilder: (context, i) {
        final cat = _categories![i];
        final selected = _selectedCategory?.id == cat.id;
        return ListTile(
          dense: true,
          selected: selected,
          selectedTileColor: const Color(0xFFE3EAFF),
          selectedColor: const Color(0xFF1A237E),
          leading: Icon(
            Icons.label_outline,
            size: 18,
            color: selected
                ? const Color(0xFF3A6FFF)
                : Colors.grey,
          ),
          title: Text(cat.name,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal)),
          onTap: () {
            setState(() => _selectedCategory = cat);
            _fetchProducts(cat.id);
          },
        );
      },
    );
  }

  // ── Products grid (right) ────────────────────────────────────────────────

  Widget _buildProductsGrid() {
    if (_productsError != null) {
      return _ErrorRetry(
          message: _productsError!,
          onRetry: () => _selectedCategory != null
              ? _fetchProducts(_selectedCategory!.id)
              : null);
    }
    if (_selectedCategory == null) {
      return const Center(
          child: Text('Select a category.',
              style: TextStyle(color: Colors.grey)));
    }
    if (_products == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_products!.isEmpty) {
      return const Center(
          child: Text('No products in this category.',
              style: TextStyle(color: Colors.grey)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemCount: _products!.length,
      itemBuilder: (context, i) {
        final p = _products![i];
        return _ProductCard(product: p);
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
  const _ProductCard({required this.product});

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
        padding: const EdgeInsets.all(10),
      ),
      onPressed: () {
        // TODO: add product to current order
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added: ${product.name}')),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fastfood, size: 32, color: Color(0xFF3A6FFF)),
          const SizedBox(height: 6),
          Text(product.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            '\$${product.price.toStringAsFixed(2)}',
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

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'open':
        color = Colors.green;
        break;
      case 'closed':
        color = Colors.grey;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      default:
        color = const Color(0xFF3A6FFF);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600)),
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
