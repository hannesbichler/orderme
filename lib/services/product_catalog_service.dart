import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:orderme/models/category.dart';

import '../models/product.dart';
import 'app_settings_service.dart';

class ProductCatalogService {
  ProductCatalogService._();

  static final ProductCatalogService instance = ProductCatalogService._();

  Uri get _productsUri => Uri.parse('${AppSettingsService.baseUrl}/products');
  Uri get _categoriesUri =>
      Uri.parse('${AppSettingsService.baseUrl}/categories');

  List<Product>? _cachedProducts;
  List<Category>? _cachedCategories;

  List<Product>? get cachedProducts => _cachedProducts;
  List<Category>? get cachedCategories => _cachedCategories;

  void invalidateCache() {
    _cachedProducts = null;
    _cachedCategories = null;
  }

  Future<List<Product>> preloadProducts() async {
    return fetchProducts();
  }

  Future<List<Category>> preloadCategories() async {
    return fetchCategories();
  }

  Future<List<Product>> fetchProducts({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedProducts != null) {
      return _cachedProducts!;
    }

    final response = await http.get(_productsUri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load products (HTTP ${response.statusCode})');
    }

    if (response.body.isEmpty ||
        response.body == '{}' ||
        response.body == '[]' ||
        response.body == 'null') {
      _cachedProducts = <Product>[];
      return _cachedProducts!;
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final embedded = decoded['_embedded'];
    if (embedded == null || embedded['productList'] == null) {
      _cachedProducts = <Product>[];
      return _cachedProducts!;
    }

    final data = embedded['productList'] as List<dynamic>;
    _cachedProducts = data
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cachedProducts!;
  }

  Future<List<Category>> fetchCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCategories != null) {
      return _cachedCategories!;
    }

    final response = await http.get(_categoriesUri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load categories (HTTP ${response.statusCode})');
    }

    if (response.body.isEmpty ||
        response.body == '{}' ||
        response.body == '[]' ||
        response.body == 'null') {
      _cachedCategories = <Category>[];
      return _cachedCategories!;
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final embedded = decoded['_embedded'];
    if (embedded == null || embedded['categoryList'] == null) {
      _cachedCategories = <Category>[];
      return _cachedCategories!;
    }

    final data = embedded['categoryList'] as List<dynamic>;
    _cachedCategories = data
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cachedCategories!;
  }
}
