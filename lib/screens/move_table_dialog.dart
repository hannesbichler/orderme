import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/place.dart';

class MoveTableDialog {
  static Future<Place?> show({
    required BuildContext context,
    required Place currentPlace,
    required String baseUrl,
  }) async {
    final places = await _fetchPlaces(baseUrl);
    final targets =
        places.where((p) => p.id != currentPlace.id).toList(growable: false);

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other table available.')),
      );
      return null;
    }

    String selectedPlaceId = targets.first.id;

    return showDialog<Place>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Move Table'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current: ${currentPlace.name}'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedPlaceId,
                    decoration: const InputDecoration(
                      labelText: 'Target table',
                      border: OutlineInputBorder(),
                    ),
                    items: targets
                        .map(
                          (p) => DropdownMenuItem<String>(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedPlaceId = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final selected =
                        targets.firstWhere((p) => p.id == selectedPlaceId);
                    Navigator.of(ctx).pop(selected);
                  },
                  child: const Text('Move'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Future<List<Place>> _fetchPlaces(String baseUrl) async {
    final response = await http.get(Uri.parse('$baseUrl/places'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load tables (HTTP ${response.statusCode})');
    }

    final decoded = json.decode(response.body);
    List<dynamic> rawPlaces;
    if (decoded is List) {
      rawPlaces = decoded;
    } else if (decoded is Map<String, dynamic>) {
      if (decoded['_embedded'] is Map<String, dynamic> &&
          decoded['_embedded']['placeList'] is List) {
        rawPlaces = decoded['_embedded']['placeList'] as List<dynamic>;
      } else if (decoded['places'] is List) {
        rawPlaces = decoded['places'] as List<dynamic>;
      } else {
        rawPlaces = <dynamic>[];
      }
    } else {
      rawPlaces = <dynamic>[];
    }

    return rawPlaces
        .whereType<Map>()
        .map((raw) {
          final map = raw.cast<String, dynamic>();
          return Place(
            id: (map['id_'] ?? map['id'] ?? '').toString(),
            name: (map['name'] ?? '').toString(),
            floor: (map['floor'] ?? map['floorId'] ?? '').toString(),
          );
        })
        .where((p) => p.id.isNotEmpty && p.name.isNotEmpty)
        .toList();
  }
}
