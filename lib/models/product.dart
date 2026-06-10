import 'package:orderme/utils/string_utils.dart' as string_utils;

class Product {
  final String id;
  final String name;
  final double pricesell;
  final String categoryId;
  final String? attributesetid;

  Product({
    required this.id,
    required this.name,
    required this.pricesell,
    required this.categoryId,
    required this.attributesetid,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id:         json['id_'] as String? ?? '',
      name:       string_utils.unescape(json['name'] as String? ?? ''),
      pricesell:  (json['pricesell'] as num? ?? 0).toDouble(),
      categoryId: json['categoryId'] as String? ?? '',
      attributesetid: json['attributeSetId'] as String?,
    );
  }
}
