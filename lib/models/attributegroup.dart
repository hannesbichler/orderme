import 'package:orderme/utils/string_utils.dart' as string_utils;

class AttributeGroup {
  final String id;
  final String name;

  AttributeGroup({
    required this.id,
    required this.name,
  });

  factory AttributeGroup.fromJson(Map<String, dynamic> json) {
    return AttributeGroup(
      id:         json['id_'] as String? ?? '',
      name:       string_utils.unescape(json['name'] as String? ?? ''),
    );
  }
}
