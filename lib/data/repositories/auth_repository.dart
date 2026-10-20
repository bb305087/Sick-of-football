import '../datasources/api_client.dart';
import '../datasources/secure_storage_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final SecureStorageService _storage;

  AuthRepository({
    ApiClient? apiClient,
    SecureStorageService? storage,
  })  : _apiClient = apiClient ?? ApiClient(),
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

  Future<void> logout() {
    return _storage.clearTokens();
  }
}
