import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user_model.dart';

class DummyJsonAuthResult {
  const DummyJsonAuthResult({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final UserModel user;
  final String accessToken;
  final String refreshToken;
}

class DummyJsonAuthService {
  DummyJsonAuthService({this.client});

  final http.Client? client;

  Future<DummyJsonAuthResult> signIn(String username, String password) async {
    final uri = Uri.https('dummyjson.com', '/auth/login');
    final requestBody = jsonEncode({
      'username': username.trim(),
      'password': password,
    });
    final client = this.client;
    final response = client == null
        ? await http.post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: requestBody,
          )
        : await client.post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: requestBody,
          );
    final decoded = jsonDecode(response.body);
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(payload['message'] as String? ?? 'DummyJSON sign-in failed.');
    }

    final accessToken =
        payload['accessToken'] as String? ?? payload['token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw const FormatException('DummyJSON returned no access token.');
    }

    return DummyJsonAuthResult(
      user: UserModel.fromMap({
        ...payload,
        'loginType': LoginType.dummyJson.name,
      }),
      accessToken: accessToken,
      refreshToken: payload['refreshToken'] as String? ?? '',
    );
  }
}