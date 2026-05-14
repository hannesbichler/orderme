import 'order_line.dart';

class OrderItem {
  final String id;
  final String placeId;
  final String status;
  final String note;
  final List<OrderLine> items;

  OrderItem({
    required this.id,
    required this.placeId,
    required this.status,
    required this.note,
    this.items = const [],
  });

  double get total => items.fold(0, (sum, l) => sum + l.total);

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .map((e) => OrderLine.fromJson(e as Map<String, dynamic>))
            .toList()
        : <OrderLine>[];

    return OrderItem(
      id:      json['id'] as String? ?? '',
      placeId: json['placeId'] as String? ?? '',
      status:  json['status'] as String? ?? '',
      note:    json['note'] as String? ?? '',
      items:   items,
    );
  }
}
