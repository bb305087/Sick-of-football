import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.resolvedBaseUrl}$endpoint'),
      headers: _headers(accessToken),
      body: body == null ? null : jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Future<dynamic> get(String endpoint, {String? accessToken}) async {
    final response = await _client.get(
      Uri.parse('${ApiConstants.resolvedBaseUrl}$endpoint'),
      headers: _headers(accessToken),
    );
    return _decodeResponse(response);
  }

  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    final response = await _client.put(
      Uri.parse('${ApiConstants.resolvedBaseUrl}$endpoint'),
      headers: _headers(accessToken),
      body: body == null ? null : jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    final response = await _client.patch(
      Uri.parse('${ApiConstants.resolvedBaseUrl}$endpoint'),
      headers: _headers(accessToken),
      body: body == null ? null : jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Future<void> delete(String endpoint, {String? accessToken}) async {
    final response = await _client.delete(
      Uri.parse('${ApiConstants.resolvedBaseUrl}$endpoint'),
      headers: _headers(accessToken),
    );
    _decodeResponse(response);
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
      throw ApiException(
        response.statusCode,
        detail is String ? detail : 'Wystąpił błąd komunikacji z serwerem.',
      );
    }
    return payload;
  }
}
