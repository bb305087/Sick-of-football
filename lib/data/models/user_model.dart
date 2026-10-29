class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? clubId;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.clubId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      email: json['email'] as String,
      fullName: (json['full_name'] ?? json['name']) as String,
      role: json['role'] as String,
      clubId: json['club_id']?.toString(),
    );
  }
}

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final UserModel user;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
