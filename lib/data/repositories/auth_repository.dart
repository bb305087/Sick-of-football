import '../datasources/api_client.dart';
import '../datasources/secure_storage_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final SecureStorageService _storage;

  AuthRepository({ApiClient? apiClient, SecureStorageService? storage})
    : _apiClient = apiClient ?? ApiClient(),
      _storage = storage ?? SecureStorageService();

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/api/auth/login',
      body: {'email': email, 'password': password},
    );
    final authResponse = AuthResponse.fromJson(response);
    await _storage.saveTokens(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
    );
    return authResponse.user;
  }

  Future<void> registerCoach({
    required String email,
    required String password,
    required String fullName,
    required String clubName,
  }) async {
    await _apiClient.post(
      '/api/v1/auth/register-coach',
      body: {
        'email': email,
        'password': password,
        'full_name': fullName,
        'club_name': clubName,
      },
    );
  }

  Future<void> registerPlayer({
    required String email,
    required String password,
    required String fullName,
    required String inviteToken,
  }) async {
    final normalizedInviteToken = inviteToken.startsWith('bklasa://invite/')
        ? inviteToken.substring('bklasa://invite/'.length)
        : inviteToken;
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'full_name': fullName,
      'invite_token': normalizedInviteToken,
    };
    await _apiClient.post('/api/v1/auth/register-player', body: body);
  }

  Future<void> logout() {
    return _storage.clearTokens();
  }

  Future<UserModel> fetchCurrentUser() async {
    final token = await _requiredAccessToken();
    final response = await _apiClient.get('/api/auth/me', accessToken: token);
    return UserModel.fromJson(response as Map<String, dynamic>);
  }

  Future<UserModel> updateProfile({
    required String? nationality,
    required DateTime? dateOfBirth,
    required String? position,
    required String? preferredFoot,
  }) async {
    final token = await _requiredAccessToken();
    final response = await _apiClient.patch(
      '/api/auth/me',
      accessToken: token,
      body: {
        'nationality': nationality,
        'date_of_birth': dateOfBirth?.toIso8601String(),
        'position': position,
        'preferred_foot': preferredFoot,
      },
    );
    return UserModel.fromJson(response as Map<String, dynamic>);
  }

  Future<String> _requiredAccessToken() async {
    final token = await _storage.readAccessToken();
    if (token == null || token.isEmpty) {
      throw const ApiException(401, 'Sesja wygasła. Zaloguj się ponownie.');
    }
    return token;
  }
}
