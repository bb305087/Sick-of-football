import '../datasources/api_client.dart';
import '../datasources/secure_storage_service.dart';
import '../models/dashboard_models.dart';

class DashboardRepository {
  final ApiClient _apiClient;
  final SecureStorageService _storage;

  DashboardRepository({
    ApiClient? apiClient,
    SecureStorageService? storage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _storage = storage ?? SecureStorageService();

  Future<List<EventModel>> fetchEvents() async {
    final token = await _requiredAccessToken();
    final response = await _apiClient.get('/api/events', accessToken: token);
    return (response as List<dynamic>)
        .map((item) => EventModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<TeamMemberModel>> fetchTeamMembers() async {
    final token = await _requiredAccessToken();
    final response = await _apiClient.get(
      '/api/team/members',
      accessToken: token,
    );
    return (response as List<dynamic>)
        .map((item) => TeamMemberModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<String> _requiredAccessToken() async {
    final token = await _storage.readAccessToken();
    if (token == null || token.isEmpty) {
      throw const ApiException(401, 'Sesja wygasła. Zaloguj się ponownie.');
    }
    return token;
  }
}
