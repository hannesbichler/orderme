import 'orderline.dart';

class OrderItem {
  final int id;
  final String id_;
  final int tickettype;
  final int ticketId;
  final String lockby;
//  final String placeId;
  //final String table;
  //final String status;
 // final String note;
  final List<OrderLine> lines;

  OrderItem({
    required this.id,
    required this.id_,
    required this.tickettype,
    required this.ticketId,
    this.lockby = '',
    //required this.placeId,
    //required this.table,
    //required this.status,
    //required this.note,
    this.lines = const [],
  });

  double get total => lines.fold(0, (sum, l) => sum + l.total);

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final rawItems = json['lines'];
    final lines = rawItems is List
        ? rawItems
            .map((e) => OrderLine.fromJson(e as Map<String, dynamic>))
            .toList()
        : <OrderLine>[];

    return OrderItem(
      id:         json['id'] as int? ?? 0,
      id_:        json['id_'] as String? ?? '',
      tickettype: json['tickettype'] as int? ?? 0,
      ticketId:   json['ticketId'] as int? ?? 0,
      lockby:     json['lockby'] as String? ?? '',
     // placeId: json['placeId'] as String? ?? '',
      //table:   json['table'] as String? ?? '',
     // status:  'open', //json['status'] as String? ?? 'open',
      //note:    json['note'] as String? ?? '',
      lines:   lines,
    );
  }
}
