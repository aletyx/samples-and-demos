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

/// A real answer of the API: a tablet returned 20 days after delivery,
/// routed to Customer Service by department rule 3, and refunded less the
/// restocking fee by policy rule 16.
final _fixture = File('test/fixtures/route-tablet.json').readAsStringSync();
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
    expect(r.department.name, 'Customer Service');
    expect(r.department.person, 'Maria Lopez');
    expect(r.departmentRule, 3);
    expect(r.priority, 'normal');
    expect(r.priorityRule, 7);
    expect(r.responseHours, 24);
    expect(r.needsReview, isFalse);
    expect(r.topic, 'customer_service');
    expect(r.topicProbabilities['customer_service'], 1);
    expect(r.policy!.resolution, 'refund');
    expect(r.policy!.rule, 16);
    expect(r.policy!.refundAmount, 279.65);
    expect(r.policy!.refundBy, DateTime(2026, 10, 26));
    expect(r.policy!.daysSinceDelivery, 20);
    expect(r.policy!.order!.item, 'Tablet');
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
      expect(outcome.routing.department.id, 'customer_service');
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

      expect(find.text('Customer Service'), findsWidgets);
      expect(find.text('Maria Lopez'), findsOneWidget);
      expect(
        find.text(
          "Orders, deliveries, returns and refunds are Customer Service's.",
        ),
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

      await tester.tap(find.text('Rule 3'));
      await tester.pumpAndSettle();

      // The request is shown, scrolled so the row's line is the second on
      // screen (one line of context above it), and the row is explained.
      final path = 'decision.decisions.department.table.3';
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

    testWidgets("shows the store's policy, and its rule exactly", (
      tester,
    ) async {
      final outcome = _outcome();
      await pump(tester, FakeRouter(outcome));

      expect(find.text('Refund'), findsOneWidget);
      expect(find.text(r'$279.65, paid by Oct 26, 2026'), findsOneWidget);
      expect(find.text('Order 120-5150 · Tablet'), findsOneWidget);
      expect(find.textContaining('(20 days ago)'), findsOneWidget);

      await tester.tap(find.text('Rule 16'));
      await tester.pumpAndSettle();
      final first = layoutJson(outcome.aityxRequest)
          .ranges['decision.decisions.resolution.table.16']!
          .first;
      final list = tester.widget<ListView>(find.byType(ListView).first);
      expect(list.controller!.offset, 8 + (first - 1) * 22.0);
      expect(find.textContaining('fired for this order'), findsOneWidget);

      // The amount's rule lands exactly too, explained.
      // The card's link, scrolled back into view: the page moved to the
      // call after the first jump.
      final link = find.text('Amount rule 4').first;
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();
      final amount = layoutJson(outcome.aityxRequest)
          .ranges['decision.decisions.refund_amount.table.4']!
          .first;
      expect(
        tester.widget<ListView>(find.byType(ListView).first).controller!.offset,
        8 + (amount - 1) * 22.0,
      );
      expect(find.textContaining('how much is paid back'), findsOneWidget);
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
      await tester.tap(find.text('Rule 3'));
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
      expect(find.text('Maria Lopez'), findsOneWidget);
      expect(router.asked.length, 2);
    });
  });
}
