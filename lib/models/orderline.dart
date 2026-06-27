import 'package:orderme/screens/product_attribute_dialog.dart';
import 'package:orderme/utils/string_utils.dart' as string_utils;

class OrderLine {
  final String id;
  final String orderId;
  final String productId;
  final String productName;
  final double pricesell;
  final int qty;
  final String? attSetInstDesc;
  final List<Attribute>? attributes;
  int newQty;

  OrderLine({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.pricesell,
    required this.qty,
    required this.attSetInstDesc,
    required this.attributes,
    required this.newQty,
  });

  int getNewQty() => newQty;
  setNewQty(int value) => newQty = value;

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    final parsedAttributes = _parseAttributes(
      json['attributes'] ?? json['attributeList'] ?? json['attList'],
    );

    final attSetInstDesc =
        string_utils.unescape(json['attSetInstDesc'] as String? ?? '');

    final fallbackAttributes = parsedAttributes.isNotEmpty
        ? parsedAttributes
        : _parseAttributesFromDescription(attSetInstDesc);

    return OrderLine(
      id:          json['id'] as String? ?? '',
      orderId:     json['orderId'] as String? ?? '',
      productId:   json['productId'] as String? ?? '',
      productName: string_utils.unescape(json['productName'] as String? ?? ''),
      pricesell:   (json['pricesell'] as num? ?? 0).toDouble(),
      qty:         (json['quantity'] as num? ?? json['qty'] as num? ?? 1).toInt(),
      newQty:      0, // (json['newQty'] as num? ?? 0).toInt(),
      attSetInstDesc: attSetInstDesc,
      attributes: fallbackAttributes,
    );
  }

  static List<Attribute> _parseAttributes(dynamic raw) {
    if (raw is! List) return const <Attribute>[];

    final byId = <String, Attribute>{};
    for (final entry in raw) {
      if (entry is String) {
        final name = string_utils.unescape(entry).trim();
        if (name.isNotEmpty) {
          byId[name] = Attribute(id: name, name: name);
        }
        continue;
      }

      if (entry is Map) {
        final map = entry.cast<String, dynamic>();
        final name = string_utils
            .unescape((map['name'] ?? map['value'] ?? map['text'] ?? '').toString())
            .trim();
        if (name.isEmpty) continue;

        final id = ((map['id'] ?? map['id_'] ?? map['valueId'] ?? map['valueid'])
                    ?.toString() ??
                name)
            .trim();
        byId[id.isEmpty ? name : id] = Attribute(
          id: id.isEmpty ? name : id,
          name: name,
        );
      }
    }
    return byId.values.toList();
  }

  static List<Attribute> _parseAttributesFromDescription(String description) {
    if (description.trim().isEmpty) return const <Attribute>[];

    final insideBrackets = RegExp(r'\[(.*)\]').firstMatch(description)?.group(1);
    final source = (insideBrackets ?? description).trim();
    if (source.isEmpty) return const <Attribute>[];

    return source
        .split(',')
        .map((part) => string_utils.unescape(part).trim())
        .where((name) => name.isNotEmpty)
        .fold(<String, Attribute>{}, (acc, name) {
          acc[name] = Attribute(id: name, name: name);
          return acc;
        })
        .values
        .toList();
  }

  double get total => pricesell * qty;
}
