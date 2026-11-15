import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../../core/constants/api_constants.dart';

http.Client createApiClient() {
  final uri = Uri.parse(ApiConstants.resolvedBaseUrl);
  final localDevelopmentHost = uri.host == '10.0.2.2' ||
      uri.host == '127.0.0.1' ||
      uri.host == 'localhost';
  final allowLocalSelfSigned = kDebugMode &&
      ApiConstants.allowSelfSignedCertificates &&
      uri.scheme == 'https' &&
      uri.port == 8443 &&
      localDevelopmentHost;

  if (!allowLocalSelfSigned) {
    return http.Client();
  }

  final httpClient = HttpClient()
    ..badCertificateCallback = (X509Certificate _, String host, int port) {
      return port == 8443 &&
          (host == '10.0.2.2' ||
              host == '127.0.0.1' ||
              host == 'localhost');
    };
  return IOClient(httpClient);
}
