import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class FarmApi {
  FarmApi({required this.baseUrl, this.token});

  String baseUrl;
  String? token;

  Uri _uri(String path) {
    final root = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$root$path');
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static const _wait = Duration(seconds: 12);

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(_uri(path), headers: _headers(), body: jsonEncode(body)).timeout(_wait);
    return _decode(response);
  }

  Future<dynamic> get(String path) async {
    final response = await http.get(_uri(path), headers: _headers()).timeout(_wait);
    return _decodeAny(response);
  }

  dynamic _decodeAny(http.Response response) {
    final text = response.body;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (text.isEmpty) return null;
      return jsonDecode(text);
    }
    throw ApiException(_message(response.statusCode, text));
  }

  Map<String, dynamic> _decode(http.Response response) {
    final value = _decodeAny(response);
    if (value is Map<String, dynamic>) return value;
    throw ApiException('Unexpected response from the server');
  }

  String _message(int status, String text) {
    try {
      final body = jsonDecode(text);
      if (body is Map) {
        final violations = body['violations'];
        if (violations is List) {
          for (final item in violations) {
            if (item is Map && item['message'] is String && (item['message'] as String).isNotEmpty) {
              final field = item['field'];
              if (field == 'lactationStage') return 'Choose a lactation stage';
              return item['message'] as String;
            }
          }
        }
        if (body['message'] is String && (body['message'] as String).isNotEmpty) {
          return body['message'] as String;
        }
      }
    } catch (_) {}
    if (status == 401) return 'Sign in again';
    return 'The server returned $status';
  }
}
