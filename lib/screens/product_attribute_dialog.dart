import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:orderme/utils/string_utils.dart' as string_utils;

import '../models/product.dart';

class ProductAttributeDialog {
  static Future<List<Attribute>?> show({
    required BuildContext context,
    required Product product,
    required String baseUrl,
    String? attributeSetId,
    List<Attribute>? preselectedAttributes,
  }) async {
    final fetchedGroups = await _fetchAttributeGroups(
      baseUrl: baseUrl,
      attributeSetId: attributeSetId ?? product.attributesetid,
    );

    final List<_AttributeGroupTab> groups = fetchedGroups ?? const <_AttributeGroupTab>[];

    final selectedByGroup = <String, Set<String>>{
      for (final g in groups) g.name: <String>{},
    };

    if (preselectedAttributes != null && preselectedAttributes.isNotEmpty) {
      final selectedIds = preselectedAttributes.map((a) => a.id).toSet();
      for (final group in groups) {
        selectedByGroup[group.name] = group.options
            .where((option) => selectedIds.contains(option.id))
            .map((option) => option.id)
            .toSet();
      }
    }

    final result = await showDialog<List<Attribute>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF3A6FFF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.tune, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Produkt Attribute',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              content: SizedBox(
                width: 380,
                child: DefaultTabController(
                  length: groups.length,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '€${product.pricesell.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3A6FFF),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TabBar(
                        isScrollable: true,
                        tabs: [
                          for (final group in groups) Tab(text: group.name),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 220,
                        child: TabBarView(
                          children: groups.map((group) {
                            final selected = selectedByGroup[group.name]!;
                            if (group.options.isEmpty) {
                              return const Center(
                                child: Text(
                                  'keine Attribute gefunden',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              );
                            }

                            return ListView(
                              shrinkWrap: true,
                              children: group.options
                                  .map(
                                    (attr) => CheckboxListTile(
                                      value: selected.contains(attr.id),
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      title: Text(attr.name),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      onChanged: (checked) {
                                        setDialogState(() {
                                          if (checked == true) {
                                            selected.add(attr.id);
                                          } else {
                                            selected.remove(attr.id);
                                          }
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Selected: ${selectedByGroup.values.fold<int>(0, (sum, set) => sum + set.length)}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final selectedOrdered = <Attribute>[
                      for (final group in groups)
                        ...group.options.where(
                          (option) => selectedByGroup[group.name]!.contains(option.id),
                        ).map((option) => option),
                    ];
                    Navigator.of(ctx).pop(selectedOrdered);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  static Future<List<_AttributeGroupTab>?> _fetchAttributeGroups({
    required String baseUrl,
    required String? attributeSetId,
  }) async {
    if (attributeSetId == null || attributeSetId.trim().isEmpty) {
      return null;
    }

    final setId = attributeSetId.trim();
    final endpoints = <String>[
      '$baseUrl/attribute-groups/$setId',
      '$baseUrl/attributesets/$setId/groups',
      '$baseUrl/attributes?attributeSetId=$setId',
      '$baseUrl/attributes?setId=$setId',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await http.get(Uri.parse(endpoint));
        if (response.statusCode != 200) {
          continue;
        }

        final parsed = _parseAttributeGroups(response.body);
        if (parsed != null && parsed.isNotEmpty) {
          return parsed;
        }
      } catch (_) {
        // Try next endpoint.
      }
    }

    return null;
  }

  static List<_AttributeGroupTab>? _parseAttributeGroups(String body) {
    if (body.trim().isEmpty) return null;

    final decoded = json.decode(body);
    final groups = <_AttributeGroupTab>[];

    List<Attribute> readOptions(dynamic value) {
      if (value is! List) return const <Attribute>[];
      return value
          .map((e) {
            if (e is String) {
              final name = e.trim();
              if (name.isEmpty) return null;
              return Attribute(id: name, name: name);
            }
            if (e is Map) {
              final m = e.cast<String, dynamic>();
              final name = (m['name'] ?? m['value'] ?? m['text'] ?? '').toString()
                  .trim();
              if (name.isEmpty) return null;
              final id = (m['id'] ?? m['id_'] ?? m['valueId'] ?? m['valueid'] ?? name)
                  .toString()
                  .trim();
              return Attribute(id: id.isEmpty ? name : id, name: name);
            }
            return null;
          })
          .whereType<Attribute>()
          .fold(<String, Attribute>{}, (acc, option) {
            acc[option.id] = option;
            return acc;
          })
          .values
          .toList();
    }

    if (decoded is Map<String, dynamic>) {
      if (decoded['_embedded'] is Map<String, dynamic>) {
        final embedded = decoded['_embedded'] as Map<String, dynamic>;
        if (embedded['attributeGroupList'] is List) {
          for (final entry in embedded['attributeGroupList'] as List) {
            if (entry is! Map) continue;
            final map = entry.cast<String, dynamic>();
            final name = (map['name'] ?? map['title'] ?? 'Group').toString().trim();
            final options = readOptions(map['options'] ?? map['attributes'] ?? map['values']);
            if (name.isNotEmpty) {
              groups.add(_AttributeGroupTab(name: string_utils.unescape(name), options: options));
            }
          }
        }
      }
    }

    if (groups.isEmpty) return null;

    final byName = <String, Map<String, Attribute>>{};
    for (final group in groups) {
      final bucket = byName.putIfAbsent(group.name, () => <String, Attribute>{});
      for (final option in group.options) {
        bucket[option.id] = option;
      }
    }
    return byName.entries
        .map((e) => _AttributeGroupTab(name: e.key, options: e.value.values.toList()))
        .toList();
  }
}

class _AttributeGroupTab {
  final String name;
  final List<Attribute> options;

  const _AttributeGroupTab({
    required this.name,
    required this.options,
  });
}

class Attribute {
  final String id;
  final String name;

  const Attribute({required this.id, required this.name});
}