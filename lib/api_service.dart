import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  final String token;
  late final String baseUrl;

  ApiService({required this.token, String? customBaseUrl}) {
    if (customBaseUrl != null && customBaseUrl.isNotEmpty) {
      baseUrl = customBaseUrl;
    } else if (kIsWeb) {
      baseUrl = 'https://paint-shop-backend-52ro.onrender.com/api';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      baseUrl = 'https://paint-shop-backend-52ro.onrender.com/api';
    } else {
      baseUrl = 'https://paint-shop-backend-52ro.onrender.com/api';
    }
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl$endpoint');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 20));

      debugPrint('GET $uri - Status: ${response.statusCode}');
      debugPrint('Response: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network or server error: $e');
    }
  }

  Future<dynamic> post(String endpoint, dynamic body) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 20));

      debugPrint(
        'POST $uri - Body: ${jsonEncode(body)} - Status: ${response.statusCode}',
      );
      debugPrint('Response: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network or server error: $e');
    }
  }

  Future<dynamic> put(String endpoint, dynamic body) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .put(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 20));

      debugPrint(
        'PUT $uri - Body: ${jsonEncode(body)} - Status: ${response.statusCode}',
      );
      debugPrint('Response: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network or server error: $e');
    }
  }

  Future<dynamic> delete(String endpoint) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .delete(uri, headers: _headers)
          .timeout(const Duration(seconds: 20));

      debugPrint('DELETE $uri - Status: ${response.statusCode}');
      debugPrint('Response: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network or server error: $e');
    }
  }

  dynamic _handleResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    String errorMessage = 'Request failed with status ${response.statusCode}';
    if (decoded is Map && decoded['message'] != null) {
      errorMessage = decoded['message'].toString();
    }
    throw Exception(errorMessage);
  }
}
