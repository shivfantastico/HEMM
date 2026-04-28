import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://45.114.143.183:5005';
  static const Duration _requestTimeout = Duration(seconds: 20);

  static Future<Map<String, String>> _buildHeaders({bool auth = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (auth && token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  static Future<void> _attachAuthHeader(http.MultipartRequest request) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
  }

  static Future<http.Response> _runRequest(
    Future<http.Response> Function() execute,
  ) async {
    try {
      return await execute().timeout(_requestTimeout);
    } on SocketException {
      return _errorResponse(
        503,
        'Unable to connect to the server. Please check your internet connection.',
      );
    } on HttpException {
      return _errorResponse(
        503,
        'The server connection was interrupted. Please try again.',
      );
    } on FormatException {
      return _errorResponse(
        500,
        'The server returned an unexpected response.',
      );
    } on FileSystemException catch (error) {
      return _errorResponse(
        400,
        error.message.isNotEmpty ? error.message : 'Unable to read the selected file.',
      );
    } on TimeoutException {
      return _errorResponse(
        408,
        'The request timed out. Please try again.',
      );
    } catch (_) {
      return _errorResponse(
        500,
        'Something went wrong while contacting the server.',
      );
    }
  }

  static http.Response _errorResponse(int statusCode, String message) {
    return http.Response(
      jsonEncode({'message': message}),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }

  static String messageFromResponse(
    http.Response response, {
    String fallbackMessage = 'Something went wrong',
  }) {
    if (response.body.isEmpty) return fallbackMessage;

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } catch (_) {}

    return fallbackMessage;
  }

  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final headers = await _buildHeaders(auth: auth);

    return _runRequest(
      () => http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      ),
    );
  }

  static Future<http.Response> get(
    String endpoint, {
    bool auth = false,
  }) async {
    final headers = await _buildHeaders(auth: auth);

    return _runRequest(
      () => http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      ),
    );
  }

  static Future<http.Response> patch(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final headers = await _buildHeaders(auth: auth);

    return _runRequest(
      () => http.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      ),
    );
  }

  static Future<http.Response> delete(
    String endpoint, {
    bool auth = false,
  }) async {
    final headers = await _buildHeaders(auth: auth);

    return _runRequest(
      () => http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      ),
    );
  }

  static Future<http.Response> multipartPost(
    String endpoint,
    Map<String, String> fields, {
    required File file,
    required String fileField,
    bool auth = false,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final request = http.MultipartRequest('POST', uri);

    if (auth) {
      await _attachAuthHeader(request);
    }

    request.fields.addAll(fields);
    request.files.add(await http.MultipartFile.fromPath(fileField, file.path));

    return _runRequest(() async {
      final streamedResponse = await request.send().timeout(_requestTimeout);
      return http.Response.fromStream(streamedResponse);
    });
  }

  static Future<http.Response> multipartRequest({
    required String method,
    required String endpoint,
    Map<String, String> fields = const {},
    List<http.MultipartFile> files = const [],
    bool auth = false,
  }) async {
    final request = http.MultipartRequest(
      method,
      Uri.parse('$baseUrl$endpoint'),
    );

    if (auth) {
      await _attachAuthHeader(request);
    }

    request.fields.addAll(fields);
    request.files.addAll(files);

    return _runRequest(() async {
      final streamedResponse = await request.send().timeout(_requestTimeout);
      return http.Response.fromStream(streamedResponse);
    });
  }
}
