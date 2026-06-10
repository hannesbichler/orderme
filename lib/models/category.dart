import 'package:orderme/utils/string_utils.dart' as string_utils;

class Category {
  final String id;
  final String name;
  final String? parentId;
  final List<Category>? children;

  Category({required this.id, required this.name, this.parentId, this.children});

  factory Category.fromJson(Map<String, dynamic> json) {
    final raw = json['parent'];
    final pid = raw is String && raw.isNotEmpty ? raw : null;
    return Category(
      id:       json['id_'] as String? ?? '',
      name:     string_utils.unescape(json['name'] as String? ?? ''),
      parentId: pid,
      children: (json['children'] as List<dynamic>?)
          ?.map((child) => Category.fromJson(child as Map<String, dynamic>))
          .toList(),
    );
  }
}
