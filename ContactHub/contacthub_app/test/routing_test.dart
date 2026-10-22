import 'dart:convert';
import 'dart:io';

import 'package:contacthub_app/main.dart';
import 'package:contacthub_app/routing/json_layout.dart';
import 'package:contacthub_app/routing/routing.dart';
import 'package:contacthub_app/routing/routing_screen.dart'
    show Call, decisionDigest, readingDigest;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A real answer of the API: a tablet returned 20 days after delivery,
/// read by qwen3:1.7b, routed to Customer Service by department rule 3,
/// and refunded less the restocking fee by policy rule 16.
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

/// One call's pane rows for [o], as the routing screen lays them out.
CallLayout _pane(RoutingOutcome o, Call call) => switch (call) {
  Call.reading => layoutCall(
    o.readingRequest,
    readingDigest(o.readingResponse),
  ),
  Call.aityx => layoutCall(o.aityxRequest, decisionDigest(o.aityxResponse)),
};

/// How far one call's pane is scrolled.
double _offset(WidgetTester tester, Call call) => tester
    .widget<ListView>(
      find.descendant(
        of: find.byKey(call.key),
        matching: find.byType(ListView),
      ),
    )
    .controller!
    .offset;

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
    expect(r.topicConfidence, 1);
    expect(r.requestKind, 'return_refund');
    expect(r.policy!.resolution, 'refund');
    expect(r.policy!.rule, 16);
    expect(r.policy!.refundAmount, 279.65);
    expect(r.policy!.refundBy, DateTime(2026, 10, 27));
    expect(r.policy!.daysSinceDelivery, 20);
    expect(r.policy!.order!.item, 'Tablet');
    expect(r.checks.map((c) => c.id), [
      'urgent',
      'sensitive_data',
      'abusive',
      'clear_topic',
    ]);
    expect(o.readingRequest, isA<Map>());
    expect(o.readingResponse, isA<Map>());
    expect(o.localModel, 'qwen3:1.7b');
    expect(o.readingSeconds, inExclusiveRange(0, 60));
    expect(o.aityxRequest, isA<Map>());
    expect(o.aityxResponse, isA<Map>());
  });

  test("the digests keep what decides, and parse the local model's answer", () {
    final o = _outcome();
    final decision = decisionDigest(o.aityxResponse);
    final answers = decision['answers'] as Map;
    expect(answers.keys, contains('department'));
    expect(answers.keys, contains('resolution'));
    expect(
      (answers['department'] as Map).keys,
      isNot(contains('probabilities')),
    );
    expect((answers['department'] as Map)['choice'], 'customer_service');
    final receipt = decision['receipt'] as Map;
    expect((receipt['decisions'] as Map).keys, [
      'department',
      'resolution',
      'refund_amount',
      'priority',
      'response_hours',
    ]);
    expect(((receipt['decisions'] as Map)['department'] as Map)['rule'], 3);
    expect((receipt['provenance'] as Map)['topic'], 'state');

    final reading = readingDigest(o.readingResponse);
    final content = (reading['message'] as Map)['content'] as Map;
    expect(content['topic'], 'customer_service');
    expect(content['request_kind'], 'return_refund');
    expect(reading['model'], 'qwen3:1.7b');
    // An answer that isn't JSON is kept as it is.
    expect(
      (readingDigest({
            'message': {'content': 'not json'},
          })['message']
          as Map)['content'],
      'not json',
    );
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

    testWidgets('shows what the local model read, and how long it took', (
      tester,
    ) async {
      await pump(tester, FakeRouter());

      expect(find.text('READ ON THIS MACHINE'), findsOneWidget);
      expect(find.textContaining('qwen3:1.7b · '), findsOneWidget);
      expect(find.text('Customer Service, 100% sure'), findsOneWidget);
      expect(find.text('A return or a refund'), findsOneWidget);
      expect(
        find.text('None raised: not urgent, no sensitive data, civil'),
        findsOneWidget,
      );
      // Both calls are on the page, each under its heading.
      expect(find.text('1. The local model reads'), findsOneWidget);
      expect(find.text('2. aityx decides'), findsOneWidget);
      expect(find.byKey(Call.reading.key), findsOneWidget);
      expect(find.byKey(Call.aityx.key), findsOneWidget);
    });

    testWidgets('a rule link lands exactly on the row that fired', (
      tester,
    ) async {
      final outcome = _outcome();
      await pump(tester, FakeRouter(outcome));

      await tester.tap(find.text('Rule 3'));
      await tester.pumpAndSettle();

      // The aityx request is shown, scrolled so the row's line is the
      // second on screen (one line of context above it), and the row is
      // explained.
      final path = 'decision.decisions.department.table.3';
      final first = _pane(outcome, Call.aityx).range('request', path)!.first;
      expect(_offset(tester, Call.aityx), 8 + (first - 1) * 22.0);
      expect(
        find.textContaining('The row of the department table that fired'),
        findsOneWidget,
      );
    });

    testWidgets("a reading link lands in the local model's pane", (
      tester,
    ) async {
      final outcome = _outcome();
      await pump(tester, FakeRouter(outcome));

      await tester.tap(find.text('The schema (local)'));
      await tester.pumpAndSettle();
      final pane = _pane(outcome, Call.reading);
      final first = pane.range('request', 'format')!.first;
      expect(_offset(tester, Call.reading), 8 + (first - 1) * 22.0);
      expect(
        find.textContaining('Ollama makes the model follow this JSON schema'),
        findsOneWidget,
      );

      // A fact it read is a row of its own in the response. The card's
      // link, scrolled back into view: the page moved to the pane.
      final link = find.text('All it read (local)');
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();
      final content = pane.range('response', 'message.content')!;
      expect(_offset(tester, Call.reading), 8 + (content.first - 1) * 22.0);
      expect(pane.range('response', 'message.content.topic'), isNotNull);
      // The prompt is shown as prose: wrapped, on unnumbered rows.
      final prompt = pane.range('request', 'messages.0.content')!;
      expect(prompt.last - prompt.first, greaterThan(10));
      expect(pane.rows[prompt.first + 1].line!.continuation, isTrue);
    });

    testWidgets('the jumped-to part stays selected when the page rebuilds', (
      tester,
    ) async {
      await pump(tester, FakeRouter());
      await tester.tap(find.text('Rule 3'));
      await tester.pumpAndSettle();
      ChoiceChip chip() => tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Department rule 3'),
      );
      expect(chip().selected, isTrue);

      // A resize rebuilds the page, and with it the targets.
      tester.view.physicalSize = const Size(1200, 1500);
      await tester.pumpAndSettle();
      expect(chip().selected, isTrue);
    });

    testWidgets("shows the store's policy, and its rule exactly", (
      tester,
    ) async {
      final outcome = _outcome();
      await pump(tester, FakeRouter(outcome));

      expect(find.text('Refund'), findsOneWidget);
      expect(find.text(r'$279.65, paid by Oct 27, 2026'), findsOneWidget);
      expect(find.text('Order 120-5150 · Tablet'), findsOneWidget);
      expect(find.textContaining('(20 days ago)'), findsOneWidget);

      await tester.tap(find.text('Rule 16'));
      await tester.pumpAndSettle();
      final first = _pane(
        outcome,
        Call.aityx,
      ).range('request', 'decision.decisions.resolution.table.16')!.first;
      expect(_offset(tester, Call.aityx), 8 + (first - 1) * 22.0);
      expect(find.textContaining('fired for this order'), findsOneWidget);

      // The amount's rule lands exactly too, explained.
      // The card's link, scrolled back into view: the page moved to the
      // call after the first jump.
      final link = find.text('Amount rule 4').first;
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();
      final amount = _pane(
        outcome,
        Call.aityx,
      ).range('request', 'decision.decisions.refund_amount.table.4')!.first;
      expect(_offset(tester, Call.aityx), 8 + (amount - 1) * 22.0);
      expect(find.textContaining('how much is paid back'), findsOneWidget);
    });

    testWidgets('an answer link lands in the response, below the request', (
      tester,
    ) async {
      final outcome = _outcome();
      await pump(tester, FakeRouter(outcome));

      await tester.tap(find.text('Receipt'));
      await tester.pumpAndSettle();

      final pane = _pane(outcome, Call.aityx);
      final first = pane
          .range('response', 'receipt.decisions.department')!
          .first;
      expect(first, greaterThan(pane.range('request', '')!.last));
      expect(_offset(tester, Call.aityx), 8 + (first - 1) * 22.0);
      expect(
        find.textContaining("The department table's trace"),
        findsOneWidget,
      );
    });

    testWidgets('the aityx response shows the answers that decide', (
      tester,
    ) async {
      final outcome = _outcome();
      await pump(tester, FakeRouter(outcome));

      final decision = decisionDigest(outcome.aityxResponse);
      expect(
        (decision['answers'] as Map).keys,
        isNot(contains('urgent_probability')),
      );
      // Links to response parts the pane shows stay...
      expect(find.text('Hours'), findsOneWidget);
      expect(find.text('Hours table'), findsOneWidget);
      // ...and each pane copies all of its answer.
      expect(find.text('Copy full response'), findsNWidgets(2));
      // Key parts are labeled in the panes before anything is jumped to.
      expect(find.text('The routing decision'), findsWidgets);
      expect(find.text('What it read'), findsWidgets);
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
      await tester.ensureVisible(find.text('Rule 3'));
      await tester.pumpAndSettle();
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
