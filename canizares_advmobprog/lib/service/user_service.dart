import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../constants.dart';
import '../model/user.dart';

class UserService {
  final http.Client _client;

  UserService([http.Client? client]) : _client = client ?? http.Client();

  Future<User> login({
    required String username,
    required String password,
  }) async {
    final base = await _loadApiBase();
    final response = await _client.post(
      Uri.parse('$base/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to sign in: ${response.statusCode}');
    }

    try {
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a user response object');
      }
      return User.fromJson(decoded);
    } on FormatException catch (error) {
      throw Exception('Invalid sign-in API response: $error');
    }
  }

  Future<String> _loadApiBase() async {
    var base = Constants.apiBase;

    try {
      final env = await rootBundle.loadString('assets/.env');
      for (final line in env.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final parts = trimmed.split('=');
        if (parts.length >= 2 && parts[0].trim() == 'HOST') {
          base = parts.sublist(1).join('=').trim();
          break;
        }
      }
    } catch (_) {
      // Use the configured fallback when the optional environment asset is unavailable.
    }

    final uri = Uri.tryParse(base);
    if (uri == null || uri.host.isEmpty) {
      throw Exception('Invalid API base URL: $base');
    }

    final path = uri.path.endsWith('/products')
        ? uri.path.substring(0, uri.path.length - '/products'.length)
        : uri.path;
    return uri.replace(path: path).toString().replaceFirst(RegExp(r'/$'), '');
  }
}
