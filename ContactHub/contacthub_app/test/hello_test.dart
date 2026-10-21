import 'dart:convert';

import 'package:contacthub_app/hello/greeting.dart';
import 'package:contacthub_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Answers with [answer], or fails with it when it's an exception.
class FakeGreeter implements Greeter {
  FakeGreeter(this.answer);

  Object answer;
  int calls = 0;

  @override
  Future<String> greet() async {
    calls++;
    final answer = this.answer;
    if (answer is Exception) throw answer;
    return answer as String;
  }
}

void main() {
  group('Hello page', () {
    testWidgets('opens from the welcome screen', (tester) async {
      await tester.pumpWidget(
        ContactHubApp(greeter: FakeGreeter('Hello from the API')),
      );

      await tester.tap(find.text('Say hello'));
      await tester.pumpAndSettle();

      expect(find.byType(HelloScreen), findsOneWidget);
      expect(find.text('Hello, world!'), findsOneWidget);
    });

    testWidgets("shows the API's greeting", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HelloScreen(greeter: FakeGreeter('Hello from the API')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hello from the API'), findsOneWidget);
    });

    testWidgets('says when the API fails, and tries again', (tester) async {
      final greeter = FakeGreeter(
        const GreetingException('The API did not answer.'),
      );
      await tester.pumpWidget(MaterialApp(home: HelloScreen(greeter: greeter)));
      await tester.pumpAndSettle();

      expect(find.text('The API did not answer.'), findsOneWidget);

      greeter.answer = 'Hello again';
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(greeter.calls, 2);
      expect(find.text('Hello again'), findsOneWidget);
    });
  });

  group('ApiGreeter', () {
    test("returns the API's message from /api/hello", () async {
      late Uri asked;
      final greeter = ApiGreeter(
        baseUrl: 'http://localhost:8891',
        client: MockClient((request) async {
          asked = request.url;
          return http.Response(jsonEncode({'message': 'Hi'}), 200);
        }),
      );

      expect(await greeter.greet(), 'Hi');
      expect(asked, Uri.parse('http://localhost:8891/api/hello'));
    });

    test('fails on an HTTP error', () {
      final greeter = ApiGreeter(
        baseUrl: 'http://localhost:8891',
        client: MockClient((_) async => http.Response('', 502)),
      );

      expect(
        greeter.greet(),
        throwsA(
          isA<GreetingException>().having(
            (e) => e.message,
            'message',
            'The API answered HTTP 502.',
          ),
        ),
      );
    });

    test('fails on an answer without a message', () {
      final greeter = ApiGreeter(
        baseUrl: 'http://localhost:8891',
        client: MockClient((_) async => http.Response('not json', 200)),
      );

      expect(greeter.greet(), throwsA(isA<GreetingException>()));
    });
  });
}
