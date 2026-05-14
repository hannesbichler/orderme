class OrderLine {
  final String id;
  final String orderId;
  final String productId;
  final String productName;
  final double price;
  final int qty;

  OrderLine({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.price,
    required this.qty,
  });

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    return OrderLine(
      id:          json['id'] as String? ?? '',
      orderId:     json['orderId'] as String? ?? '',
      productId:   json['productId'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      price:       (json['price'] as num? ?? 0).toDouble(),
      qty:         (json['qty'] as num? ?? 1).toInt(),
    );
  }

  double get total => price * qty;
}
