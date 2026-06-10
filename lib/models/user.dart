class User {
  final String id;
  final String name;
  final String password;
  final String card;
 // final String username;
 // final String email;
 // final String phone;
 // final String website;
  final String role;

  User({
    required this.id,
    required this.name,
    required this.password,
    required this.card,
  //  required this.username,
  //  required this.email,
  //  required this.phone,
  //  required this.website,
    required this.role
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id_'] as String? ?? '',
      name: json['name'] as String? ?? '',
      password: json['apppassword'] as String? ?? '',
      card: json['card'] as String? ?? '',
      role: json['role'] as String? ?? '',
    );
  }
}
