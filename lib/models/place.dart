class Place {
  final String id;
  final String name;
  final String floor;

  Place({required this.id, required this.name, required this.floor});

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id:      json['id'] as String? ?? '',
      name:    json['name'] as String? ?? '',
      floor: json['floor'] as String? ?? '',
    );
  }
}
