class Floor {
  final String id;
  final String name;

  Floor({required this.id, required this.name});

  factory Floor.fromJson(Map<String, dynamic> json) {
    return Floor(
      id:   json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}
