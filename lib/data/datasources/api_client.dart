import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import 'secure_storage_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  final http.Client _client;
  final SecureStorageService _storage;
  Future<void>? _refreshInProgress;

  ApiClient({
    http.Client? client,
    SecureStorageService? storage,
  }) : _client = client ?? http.Client(),
       _storage = storage ?? SecureStorageService();

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    return _send(
      'POST',
      endpoint,
      body: body,
      accessToken: accessToken,
    );
  }

  Future<dynamic> get(String endpoint, {String? accessToken}) async {
    return _send('GET', endpoint, accessToken: accessToken);
  }

  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    return _send(
      'PUT',
      endpoint,
      body: body,
      accessToken: accessToken,
    );
  }

  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    return _send(
      'PATCH',
      endpoint,
      body: body,
      accessToken: accessToken,
    );
  }

  Future<void> delete(String endpoint, {String? accessToken}) async {
    await _send('DELETE', endpoint, accessToken: accessToken);
  }

  Future<dynamic> _send(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    String? accessToken,
    bool retryAfterRefresh = true,
  }) async {
    final request = http.Request(
      method,
      Uri.parse('${ApiConstants.resolvedBaseUrl}$endpoint'),
    )..headers.addAll(_headers(accessToken));
    if (body != null) {
      request.body = jsonEncode(body);
    }
    final response = await _client.send(request);
    final responseWithBody = await http.Response.fromStream(response);

    if (responseWithBody.statusCode == 401 &&
        retryAfterRefresh &&
        accessToken != null &&
        endpoint != '/api/auth/refresh' &&
        endpoint != '/api/auth/logout') {
      final refreshedToken = await _refreshAccessToken();
      return _send(
        method,
        endpoint,
        body: body,
        accessToken: refreshedToken,
        retryAfterRefresh: false,
      );
    }

    return _decodeResponse(responseWithBody);
  }

  Future<String> _refreshAccessToken() async {
    final inProgress = _refreshInProgress;
    if (inProgress != null) {
      await inProgress;
      return _requiredAccessToken();
    }

    final refresh = _performRefresh();
    _refreshInProgress = refresh;
    try {
      await refresh;
    } finally {
      _refreshInProgress = null;
    }
    return _requiredAccessToken();
  }

  Future<void> _performRefresh() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _storage.clearTokens();
      throw const ApiException(401, 'Sesja wygasła. Zaloguj się ponownie.');
    }

    dynamic response;
    try {
      response = await _send(
        'POST',
        '/api/auth/refresh',
        body: {'refresh_token': refreshToken},
        retryAfterRefresh: false,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _storage.clearTokens();
      }
      rethrow;
    }
    if (response is! Map<String, dynamic> ||
        response['access_token'] is! String ||
        response['refresh_token'] is! String) {
      await _storage.clearTokens();
      throw const FormatException('Nieprawidłowa odpowiedź odświeżania sesji.');
    }
    await _storage.saveTokens(
      accessToken: response['access_token'] as String,
      refreshToken: response['refresh_token'] as String,
    );
  }

  Future<String> _requiredAccessToken() async {
    final token = await _storage.readAccessToken();
    if (token == null || token.isEmpty) {
      throw const ApiException(401, 'Sesja wygasła. Zaloguj się ponownie.');
    }
    return token;
  }

  Map<String, String> _headers(String? accessToken) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null) {
      headers['Authorization'] =
          'Bear'
          'er $accessToken';
    }
    return headers;
  }

  dynamic _decodeResponse(http.Response response) {
    dynamic payload;
    if (response.body.isNotEmpty) {
      payload = jsonDecode(response.body);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = payload is Map<String, dynamic> ? payload['detail'] : null;
      final message = switch (detail) {
        String value => value,
        List<dynamic> values =>
          values
              .map((value) {
                if (value is Map<String, dynamic> && value['msg'] is String) {
                  return value['msg'] as String;
                }
                return value.toString();
              })
              .join(', '),
        _ => 'Wystąpił błąd komunikacji z serwerem.',
      };
      throw ApiException(response.statusCode, message);
    }
    return payload;
  }
}
