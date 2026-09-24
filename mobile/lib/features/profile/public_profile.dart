import 'package:garagem_mobile/core/config/app_config.dart';

final class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.projectCount,
    required this.followerCount,
    required this.followingCount,
    required this.followedByMe,
    this.blockedByMe = false,
    this.avatarUrl,
    this.bio,
    this.city,
    this.state,
  });

  factory PublicProfile.fromJson(Map<String, Object?> json) {
    return PublicProfile(
      id: json['id']! as String,
      name: json['nome']! as String,
      username: json['username']! as String,
      avatarUrl: AppConfig.resolveApiUrl(json['avatar_url'] as String?),
      bio: json['bio'] as String?,
      city: json['cidade'] as String?,
      state: json['estado'] as String?,
      projectCount: json['total_projetos']! as int,
      followerCount: json['total_seguidores']! as int,
      followingCount: json['total_seguindo']! as int,
      followedByMe: json['seguido_por_mim']! as bool,
      blockedByMe: json['bloqueado_por_mim'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
  final String? bio;
  final String? city;
  final String? state;
  final int projectCount;
  final int followerCount;
  final int followingCount;
  final bool followedByMe;
  final bool blockedByMe;
}

final class SocialUser {
  const SocialUser({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
  });

  factory SocialUser.fromJson(Map<String, Object?> json) {
    return SocialUser(
      id: json['id']! as String,
      name: json['nome']! as String,
      username: json['username']! as String,
      avatarUrl: AppConfig.resolveApiUrl(json['avatar_url'] as String?),
    );
  }

  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
}
