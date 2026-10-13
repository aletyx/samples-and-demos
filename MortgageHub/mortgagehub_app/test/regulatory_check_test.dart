import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mortgagehub_app/proposal/proposal_check.dart';
import 'package:mortgagehub_app/proposal/proposal_summary_screen.dart';
import 'package:mortgagehub_app/proposal/random_proposal.dart';
import 'package:faker/faker.dart';

import 'fake_checker.dart';

final request = randomProposal(Faker(seed: 7));

Future<void> showSummary(WidgetTester tester, ProposalChecker checker) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: ProposalSummaryScreen(request: request, checker: checker),
    ),
  );
}

void main() {
  testWidgets('shows the verdict, the figures and every check', (tester) async {
    final checker = FakeChecker();
    await showSummary(tester, checker);
    expect(find.textContaining('Checking against'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(checker.calls, 1);
    expect(checker.last, same(request));
    expect(find.text('Regulatory check'), findsOneWidget);
    expect(find.byKey(const Key('checkStatus')), findsOneWidget);
    expect(find.text('Requires review'), findsOneWidget);
    expect(find.text('Loan-to-value (max 97.0%)'), findsOneWidget);
    expect(find.text(r'$3,091'), findsOneWidget);
    expect(find.text('35.9%'), findsOneWidget);
    final card = find.byType(RegulatoryCheckCard);
    for (final label in [
      'Program eligibility',
      'Loan-to-value',
      'Loan limits (2026)',
      'Credit score',
      'Debt-to-income',
    ]) {
      expect(
        find.descendant(of: card, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(find.text('Too high.'), findsOneWidget);
  });

  testWidgets('shows an error with a retry', (tester) async {
    final checker = FakeChecker(error: ProposalCheckException('aityx is down'));
    await showSummary(tester, checker);
    await tester.pumpAndSettle();
    expect(find.text("Couldn't run the check: aityx is down"), findsOneWidget);

    checker.error = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(checker.calls, 2);
    expect(find.text('Requires review'), findsOneWidget);
  });

  test('the API client posts the request and parses the answer', () async {
    late http.Request sent;
    final client = MockClient((call) async {
      sent = call;
      return http.Response(
        jsonEncode({
          'status': 'not_processable',
          'figures': {
            'loanAmount': 400000,
            'ltv': 80,
            'maxLtv': 0,
            'principalAndInterest': 2528.27,
            'housingPayment': 3090.77,
            'dti': 35.91,
            'assumedRate': 6.5,
          },
          'checks': [
            {'id': 'program', 'result': 'fail', 'reason': 'Not eligible.'},
          ],
        }),
        200,
      );
    });
    final check = await ApiProposalChecker(
      client: client,
      baseUrl: 'http://api.test',
    ).check(request);

    expect(sent.url.toString(), 'http://api.test/api/proposals/check');
    expect(jsonDecode(sent.body), request.toJson());
    expect(check.status, CheckStatus.notProcessable);
    expect(check.checks.single.result, CheckResult.fail);
    expect(check.maxLtv, 0);
  });

  test('the API client reports the API\'s error', () async {
    final client = MockClient(
      (_) async =>
          http.Response(jsonEncode({'error': 'aityx is not set up'}), 503),
    );
    expect(
      ApiProposalChecker(
        client: client,
        baseUrl: 'http://api.test',
      ).check(request),
      throwsA(
        isA<ProposalCheckException>().having(
          (e) => e.message,
          'message',
          'aityx is not set up',
        ),
      ),
    );
  });

  test('an empty base URL calls the app\'s own origin', () async {
    late Uri url;
    final client = MockClient((call) async {
      url = call.url;
      return http.Response('{"error":"x"}', 500);
    });
    await expectLater(
      ApiProposalChecker(client: client, baseUrl: '').check(request),
      throwsA(isA<ProposalCheckException>()),
    );
    expect(url, Uri.base.resolve('/api/proposals/check'));
  });
}
