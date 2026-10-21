import 'dart:convert';
import 'dart:io';

import 'package:contacthub_app/main.dart';
import 'package:contacthub_app/routing/aityx_call_view.dart';
import 'package:contacthub_app/routing/json_layout.dart';
import 'package:contacthub_app/routing/routing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A real answer of the API: a job question about Berlin, routed to HR by
/// department rule 8 and priority rule 6.
final _fixture = File('test/fixtures/route-hr.json').readAsStringSync();
RoutingOutcome _outcome() => RoutingOutcome.fromJson(
  (jsonDecode(_fixture) as Map).cast<String, Object?>(),
);

class FakeRouter implements RequestRouter {
  FakeRouter([this.answer]);

  Object? answer;
  final asked = <String>[];

  @override
  Future<RoutingOutcome> route(String message) async {
    asked.add(message);
    final answer = this.answer;
    if (answer is Exception) throw answer;
    return answer as RoutingOutcome? ?? _outcome();
  }
}

void main() {
  test('reads the API\'s answer', () {
    final o = _outcome();
    final r = o.routing;
    expect(r.department.name, 'Human Resources');
    expect(r.department.person, 'Sofia Rossi');
    expect(r.departmentRule, 8);
    expect(r.priority, 'normal');
    expect(r.priorityRule, 6);
    expect(r.responseHours, 24);
    expect(r.needsReview, isFalse);
    expect(r.topic, 'hr');
    expect(r.topicProbabilities['hr'], 1);
    expect(r.checks.map((c) => c.id), [
      'urgent',
      'sensitive_data',
      'abusive',
      'clear_topic',
    ]);
    expect(o.aityxRequest, isA<Map>());
    expect(o.aityxResponse, isA<Map>());
  });

  group('ApiRequestRouter', () {
    test('posts the message to /api/route', () async {
      late http.Request sent;
      final router = ApiRequestRouter(
        baseUrl: 'http://localhost:8891',
        client: MockClient((request) async {
          sent = request;
          return http.Response(_fixture, 200);
        }),
      );

      final outcome = await router.route('Any jobs?');
      expect(sent.url, Uri.parse('http://localhost:8891/api/route'));
      expect(jsonDecode(sent.body), {'message': 'Any jobs?'});
      expect(outcome.routing.department.id, 'hr');
    });

    test("says the API's error", () {
      final router = ApiRequestRouter(
        baseUrl: 'http://localhost:8891',
        client: MockClient(
          (_) async => http.Response('{"error":"message is empty"}', 400),
        ),
      );
      expect(
        router.route(' '),
        throwsA(
          isA<RoutingException>().having(
            (e) => e.message,
            'message',
            'Could not route it: message is empty.',
          ),
        ),
      );
    });
  });

  group('the routing screen', () {
    Future<void> pump(WidgetTester tester, RequestRouter router) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: RoutingScreen(message: 'Any jobs in Berlin?', router: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the department, the person and why', (tester) async {
      await pump(tester, FakeRouter());

      expect(find.text('Human Resources'), findsWidgets);
      expect(find.text('Sofia Rossi'), findsOneWidget);
      expect(
        find.text("Job applications and careers are Human Resources'."),
        findsOneWidget,
      );
      expect(
        find.textContaining('Normal · answer within 24 h'),
        findsOneWidget,
      );
      expect(find.text('Goes straight to the department'), findsOneWidget);
    });

    testWidgets('a rule link lands exactly on the row that fired', (
      tester,
    ) async {
      final outcome = _outcome();
      await pump(tester, FakeRouter(outcome));

      await tester.tap(find.text('Rule 8'));
      await tester.pumpAndSettle();

      // The request is shown, scrolled so the row's line is the second on
      // screen (one line of context above it), and the row is explained.
      final path = 'decision.decisions.department.table.8';
      final first = layoutJson(outcome.aityxRequest).ranges[path]!.first;
      final list = tester.widget<ListView>(find.byType(ListView).first);
      expect(list.controller!.offset, 8 + (first - 1) * 22.0);
      expect(
        find.textContaining('The row of the department table that fired'),
        findsOneWidget,
      );
      final segmented = tester.widget<SegmentedButton<CallSide>>(
        find.byType(SegmentedButton<CallSide>),
      );
      expect(segmented.selected, {CallSide.request});
    });

    testWidgets('an answer link switches to the response', (tester) async {
      final outcome = _outcome();
      await pump(tester, FakeRouter(outcome));

      await tester.tap(find.text('Receipt'));
      await tester.pumpAndSettle();

      final first = layoutJson(outcome.aityxResponse)
          .ranges['receipt.decisions.department']!
          .first;
      final list = tester.widget<ListView>(find.byType(ListView).last);
      expect(list.controller!.offset, 8 + (first - 1) * 22.0);
      final segmented = tester.widget<SegmentedButton<CallSide>>(
        find.byType(SegmentedButton<CallSide>),
      );
      expect(segmented.selected, {CallSide.response});
    });

    testWidgets('fits a phone screen', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: RoutingScreen(message: 'Any jobs?', router: FakeRouter()),
        ),
      );
      await tester.pumpAndSettle();

      // Overflows would have been reported as exceptions.
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Rule 8'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('The row of the department table'),
        findsOneWidget,
      );
    });

    testWidgets('says when routing failed, and tries again', (tester) async {
      final router = FakeRouter(
        const RoutingException('The API did not answer.'),
      );
      await pump(tester, router);
      expect(find.text('The API did not answer.'), findsOneWidget);

      router.answer = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Sofia Rossi'), findsOneWidget);
      expect(router.asked.length, 2);
    });
  });
}
