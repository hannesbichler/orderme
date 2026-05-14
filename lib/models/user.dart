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
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      password: json['passwd'] as String? ?? 'hannes',
      card: json['card'] as String? ?? '',
  //      username: json['username'] as String,
  //      email: json['email'] as String,
  //      phone: json['phone'] as String,
  //      website: json['website'] as String,
      role: json['role'] as String? ?? '',
    );
  }
}
