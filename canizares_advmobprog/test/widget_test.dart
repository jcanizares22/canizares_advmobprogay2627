// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:canizares_advmobprog/models/user_model.dart';
import 'package:canizares_advmobprog/services/dummy_json_auth_service.dart';

void main() {
  test('UserModel maps profile data in both directions', () {
    final user = UserModel(
      uid: 'firebase-uid',
      firstName: 'Ada',
      lastName: 'Lovelace',
      age: 36,
      contactNumber: '+1 555 0100',
      username: 'ada',
      email: 'ada@example.com',
    );

    expect(UserModel.fromMap(user.toMap()).toMap(), user.toMap());
  });

  test('UserModel reads DummyJSON login type', () {
    final user = UserModel.fromMap({
      'id': 42,
      'firstName': 'Ada',
      'lastName': 'Lovelace',
      'age': 36,
      'phone': '5550100',
      'username': 'ada',
      'email': 'ada@example.com',
      'loginType': 'dummyJson',
    });

    expect(user.loginType, LoginType.dummyJson);
    expect(user.uid, '42');
    expect(user.contactNumber, '5550100');
    expect(user.toMap()['loginType'], 'dummyJson');
  });

  test('DummyJSON auth posts credentials and maps the returned session', () async {
    final service = DummyJsonAuthService(
      client: MockClient((request) async {
        expect(request.url, Uri.https('dummyjson.com', '/auth/login'));
        expect(jsonDecode(request.body), {
          'username': 'emilys',
          'password': 'emilyspass',
        });
        return http.Response(
          jsonEncode({
            'id': 1,
            'username': 'emilys',
            'email': 'emily@example.com',
            'firstName': 'Emily',
            'lastName': 'Johnson',
            'age': 28,
            'phone': '555-0100',
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
          }),
          200,
        );
      }),
    );

    final result = await service.signIn(' emilys ', 'emilyspass');

    expect(result.user.loginType, LoginType.dummyJson);
    expect(result.user.uid, '1');
    expect(result.user.contactNumber, '555-0100');
    expect(result.accessToken, 'access-token');
    expect(result.refreshToken, 'refresh-token');
  });
}
