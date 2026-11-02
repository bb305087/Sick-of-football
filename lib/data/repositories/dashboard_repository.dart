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

  Future<InvitationModel> createInvitation({
    int expiresInHours = 72,
    int maxUses = 1,
  }) async {
    final token = await _requiredAccessToken();
    final response = await _apiClient.post(
      '/api/v1/club/invitations',
      accessToken: token,
      body: {'expires_in_hours': expiresInHours, 'max_uses': maxUses},
    );
    return InvitationModel.fromJson(response as Map<String, dynamic>);
  }

  Future<List<TacticModel>> fetchTactics() async {
    final token = await _requiredAccessToken();
    dynamic response;
    try {
      response = await _apiClient.get('/api/tactics', accessToken: token);
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      response = await _apiClient.get('/api/v1/tactics', accessToken: token);
    }

    final items = response is List
        ? response
        : (response as Map<String, dynamic>)['items'];
    if (items is! List<dynamic>) {
      throw const FormatException('Nieprawidłowy format listy taktyk.');
    }
    return items
        .map((item) => TacticModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<TacticModel> createTactic({
    required String title,
    required String content,
    required bool published,
  }) async {
    final token = await _requiredAccessToken();
    final response = await _apiClient.post(
      '/api/v1/tactics',
      accessToken: token,
      body: {
        'title': title,
        'description': content,
        'formation': '4-3-3',
        'lineup': const [],
      },
    );
    return TacticModel.fromJson(response as Map<String, dynamic>);
  }

  Future<TacticModel> createSquadTactic({
    required String title,
    required String formation,
    required List<Map<String, dynamic>> lineup,
    required bool published,
  }) async {
    final token = await _requiredAccessToken();
    final response = await _apiClient.post(
      '/api/v1/tactics',
      accessToken: token,
      body: {
        'title': title,
        'formation': formation,
        'lineup': lineup,
        'description': 'Skład $formation',
        'published': published,
      },
    );
    return TacticModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteTactic(String tacticId) async {
    final token = await _requiredAccessToken();
    try {
      await _apiClient.delete('/api/v1/tactics/$tacticId', accessToken: token);
    } on ApiException catch (error) {
      if (error.statusCode != 405 && error.statusCode != 404) rethrow;
      await _apiClient.delete('/api/tactics/$tacticId', accessToken: token);
    }
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

  Future<MedicalReportModel> createMedicalReport({
    required String playerId,
    required String diagnosis,
    String? details,
    DateTime? occurredOn,
    DateTime? clearedOn,
  }) async {
    final token = await _requiredAccessToken();
    final response = await _apiClient.post(
      '/api/medical-reports',
      accessToken: token,
      body: {
        'player_id': playerId,
        'diagnosis': diagnosis,
        if (details != null && details.isNotEmpty) 'details': details,
        if (occurredOn != null) 'occurred_on': occurredOn.toIso8601String(),
        if (clearedOn != null) 'cleared_on': clearedOn.toIso8601String(),
      },
    );
    return MedicalReportModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteMedicalReport(String reportId) async {
    final token = await _requiredAccessToken();
    try {
      await _apiClient.delete(
        '/api/medical-reports/$reportId',
        accessToken: token,
      );
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      await _apiClient.delete(
        '/api/v1/medical-reports/$reportId',
        accessToken: token,
      );
    }
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
