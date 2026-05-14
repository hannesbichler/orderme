class Product {
  final String id;
  final String name;
  final double price;
  final String categoryId;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id:         json['id'] as String? ?? '',
      name:       json['name'] as String? ?? '',
      price:      (json['price'] as num? ?? 0).toDouble(),
      categoryId: json['categoryId'] as String? ?? '',
    );
  }
}
