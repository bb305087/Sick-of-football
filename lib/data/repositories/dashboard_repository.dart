import '../datasources/api_client.dart';
import '../datasources/secure_storage_service.dart';
import '../models/dashboard_models.dart';

class DashboardRepository {
  final ApiClient _apiClient;
  final SecureStorageService _storage;

  DashboardRepository({ApiClient? apiClient, SecureStorageService? storage})
    : _apiClient = apiClient ?? ApiClient(),
      _storage = storage ?? SecureStorageService();

  Future<List<EventModel>> fetchEvents() async {
    final token = await _requiredAccessToken();
    final response = await _apiClient.get('/api/events', accessToken: token);
    final items = response is List
        ? response
        : (response as Map<String, dynamic>)['items'];
    return (items as List<dynamic>)
        .map((item) => EventModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<TeamMemberModel>> fetchTeamMembers() async {
    final token = await _requiredAccessToken();
    final response = await _apiClient.get(
      '/api/team/members',
      accessToken: token,
    );
    final items = response is List
        ? response
        : (response as Map<String, dynamic>)['items'];
    return (items as List<dynamic>)
        .map((item) => TeamMemberModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<TacticModel>> fetchTactics() async {
    final token = await _requiredAccessToken();
    final response = await _apiClient.get('/api/tactics', accessToken: token);
    final items = response is List
        ? response
        : (response as Map<String, dynamic>)['items'];
    return (items as List<dynamic>)
        .map((item) => TacticModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<MedicalReportModel>> fetchMedicalReports() async {
    final token = await _requiredAccessToken();
    final response = await _apiClient.get(
      '/api/medical-reports',
      accessToken: token,
    );
    return (response as List<dynamic>)
        .map(
          (item) => MedicalReportModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> setAttendance({
    required String eventId,
    required String status,
    String? reason,
  }) async {
    final token = await _requiredAccessToken();
    final body = <String, dynamic>{'status': status};
    if (reason != null) {
      body['reason'] = reason;
    }
    await _apiClient.post(
      '/api/events/$eventId/attendance',
      accessToken: token,
      body: body,
    );
  }

  Future<String> _requiredAccessToken() async {
    final token = await _storage.readAccessToken();
    if (token == null || token.isEmpty) {
      throw const ApiException(401, 'Sesja wygasła. Zaloguj się ponownie.');
    }
    return token;
  }
}
