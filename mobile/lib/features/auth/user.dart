final class User {
  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.bio,
    this.city,
    this.state,
  });

  factory User.fromJson(Map<String, Object?> json) => User(
        id: json['id']! as String,
        name: json['nome']! as String,
        username: json['username']! as String,
        email: json['email']! as String,
        avatarUrl: json['avatar_url'] as String?,
        bio: json['bio'] as String?,
        city: json['cidade'] as String?,
        state: json['estado'] as String?,
      );

  final String id;
  final String name;
  final String username;
  final String email;
  final String? avatarUrl;
  final String? bio;
  final String? city;
  final String? state;
}
