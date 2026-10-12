// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:canizares_advmobprog/models/user_model.dart';
import 'package:canizares_advmobprog/services/dummy_json_auth_service.dart';
import 'package:canizares_advmobprog/models/chat_message.dart';
import 'package:canizares_advmobprog/screens/cart_screen.dart';
import 'package:canizares_advmobprog/widgets/username_edit_dialog.dart';

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

  test('chat profile projection excludes private profile fields', () {
    final user = UserModel(
      uid: 'firebase-uid',
      firstName: 'Ada',
      lastName: 'Lovelace',
      age: 36,
      contactNumber: '+1 555 0100',
      username: 'ada',
      email: 'ada@example.com',
    );

    final chatProfile = user.toChatProfileMap();
    expect(chatProfile, {
      'uid': 'firebase-uid',
      'firstName': 'Ada',
      'lastName': 'Lovelace',
      'username': 'ada',
      'email': 'ada@example.com',
    });
    expect(chatProfile.containsKey('age'), isFalse);
    expect(chatProfile.containsKey('contactNumber'), isFalse);
  });

  test('chat user search matches names and emails case-insensitively', () {
    final user = UserModel(
      uid: 'firebase-uid',
      firstName: 'Ada',
      lastName: 'Lovelace',
      age: 36,
      contactNumber: '+1 555 0100',
      username: 'ada',
      email: 'ada.lovelace@example.com',
    );

    expect(user.matchesChatSearch('ada'), isTrue);
    expect(user.matchesChatSearch('LOVELACE'), isTrue);
    expect(user.matchesChatSearch('example.com'), isTrue);
    expect(user.matchesChatSearch('  ada   lovelace  '), isTrue);
    expect(user.matchesChatSearch('grace@example.com'), isFalse);
    expect(user.matchesChatSearch('   '), isTrue);
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

  test('pending chat messages expose the sending state', () {
    final timestamp = DateTime(2026, 10, 11);
    final message = ChatMessage.pending(
      id: 'pending-1',
      senderId: 'sender',
      senderEmail: 'sender@example.com',
      receiverId: 'receiver',
      message: 'Hello',
      timestamp: timestamp,
    );

    expect(message.status, ChatMessageStatus.sending);
    expect(message.message, 'Hello');
    expect(message.timestamp, timestamp);
  });

  test(
    'DummyJSON auth posts credentials and maps the returned session',
    () async {
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
    },
  );

  testWidgets('username dialog validates and returns the trimmed username', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<String>(
                context: context,
                builder: (_) =>
                    const UsernameEditDialog(initialUsername: 'existing'),
              );
            },
            child: const Text('Edit username'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edit username'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a username.'), findsOneWidget);
    expect(result, isNull);

    await tester.enterText(find.byType(TextFormField), '  new-name  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, 'new-name');
  });

  testWidgets('cart quantity updates for a DummyJSON account', (tester) async {
    SharedPreferences.setMockInitialValues({
      'localCartProducts_42': [
        jsonEncode({
          'id': 7,
          'title': 'Test product',
          'price': 10.0,
          'quantity': 1,
          'total': 10.0,
          'discountPercentage': 0.0,
          'discountedTotal': 10.0,
          'thumbnail': '',
        }),
      ],
    });

    await tester.pumpWidget(
      const MaterialApp(home: CartScreen(userId: '42')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Qty 1 | Total \$10.00'), findsOneWidget);

    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pumpAndSettle();

    expect(find.text('Qty 2 | Total \$20.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
