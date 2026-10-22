import 'dart:convert';
import 'dart:io';

import 'package:contacthub_api/orders.dart';
import 'package:contacthub_api/reading.dart';
import 'package:contacthub_api/routing.dart';
import 'package:test/test.dart';

Map<String, Object?> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

/// A real answer of the API: the aityx call is under `aityx`.
Map<String, Object?> _call(String fixture, String side) =>
    ((_json('test/fixtures/$fixture.json')['aityx'] as Map)[side] as Map)
        .cast<String, Object?>();

/// A clear, civil request about a return.
const _reading = {
  'request_kind': 'return_refund',
  'urgent_probability': 0.02,
  'sensitive_data_probability': 0.01,
  'abusive_probability': 0.0,
  'topic': 'customer_service',
  'topic_confidence': 0.95,
};

void main() {
  final model = _json('models/routing.json');

  group('messageFrom', () {
    test('takes the trimmed message', () {
      expect(
        messageFrom({'message': '  Where is my order?  '}),
        'Where is my order?',
      );
    });

    test('refuses a missing, empty or too long message', () {
      expect(() => messageFrom([]), throwsA(isA<InvalidRequest>()));
      expect(() => messageFrom({}), throwsA(isA<InvalidRequest>()));
      expect(
        () => messageFrom({'message': '   '}),
        throwsA(isA<InvalidRequest>()),
      );
      expect(
        () => messageFrom({'message': 'x' * (maxMessageLength + 1)}),
        throwsA(isA<InvalidRequest>()),
      );
    });
  });

  group('the model', () {
    test('names a department for every topic the local model can pick', () {
      final topics = (model['questions'] as Map)['topic']['criteria'] as Map;
      final departmentType =
          ((model['decision'] as Map)['types'] as Map)['Department'] as String;
      final ids = departmentType.split('|').toSet();
      expect(ids, departments.keys.toSet());
      for (final topic in topics.keys) {
        if (topic == 'other') continue;
        expect(ids, contains(topic), reason: '$topic has no department');
      }
    });

    test('the department table has a row for every department', () {
      final table =
          ((model['decision'] as Map)['decisions']
                  as Map)['department']['table']
              as List;
      final targets = {for (final row in table.skip(1)) (row as Map)['then']};
      expect(targets, departments.keys.toSet());
    });
  });

  group('the order book', () {
    final today = DateTime.utc(2026, 10, 21);

    test('finds the order number in a message', () {
      expect(orderNumberIn('Return order 113-2045 please'), '113-2045');
      expect(orderNumberIn('No number here, call 555-12345'), isNull);
    });

    test('dates count back from today', () {
      final jacket = orderState('order 114-7781', today);
      expect(jacket['placed_on'], '2026-09-01');
      expect(jacket['delivered_on'], '2026-09-06');
      expect(jacket['amount'], 240);
      expect(jacket['status'], 'delivered');
    });

    test('an undelivered order is expected 5 days after it was placed', () {
      final lamp = orderState('order 112-8834', today);
      expect(lamp['status'], 'shipped');
      expect(lamp['placed_on'], '2026-10-09');
      expect(lamp['delivered_on'], '2026-10-14');
    });

    test('a message without a known order gets status none', () {
      expect(orderState('I lost the number', today)['status'], 'none');
      expect(orderState('order 999-0000', today)['status'], 'none');
      expect(orderState('order 999-0000', today)['number'], '999-0000');
    });
  });

  test('routingRequest sends the rules, and as the state the message, what '
      'the local model read, today and the order', () {
    final sent = routingRequest(
      model,
      'Return order 113-2045',
      _reading,
      today: DateTime.utc(2026, 10, 21),
    );
    expect(sent.keys, ['decision', 'state']);
    expect(sent['decision'], model['decision']);
    final state = sent['state'] as Map;
    expect(state['message'], 'Return order 113-2045');
    for (final name in factNames) {
      expect(state[name], _reading[name], reason: name);
    }
    expect(state['today'], '2026-10-21');
    expect((state['order'] as Map)['item'], 'Running shoes');
    // Every input of the rules is in the state, and nothing else.
    final inputs = ((model['decision'] as Map)['inputs'] as Map).keys;
    expect(state.keys.toSet(), inputs.toSet());
  });

  test('the resolution table covers every resolution it can give', () {
    final decisions = (model['decision'] as Map)['decisions'] as Map;
    final table = decisions['resolution']['table'] as List;
    final given = {for (final row in table.skip(1)) (row as Map)['then']};
    final type =
        ((model['decision'] as Map)['types'] as Map)['Resolution'] as String;
    expect(given, type.split('|').toSet());
  });

  group('toRouting, from real aityx answers', () {
    Map<String, Object?> routing(String fixture) =>
        toRouting(_call(fixture, 'request'), _call(fixture, 'response'));

    test('an electronics return after 14 days goes to Customer Service, '
        'refunded less 15%', () {
      final r = routing('route-tablet');
      expect((r['department'] as Map)['id'], 'customer_service');
      expect((r['department'] as Map)['person'], 'Maria Lopez');
      expect(r['department_rule'], 3);
      expect(r['reason'], contains('Customer Service'));
      expect(r['priority'], 'normal');
      expect(r['response_hours'], 24);
      expect(r['needs_review'], isFalse);
      expect((r['topic'] as Map)['choice'], 'customer_service');
      expect((r['topic'] as Map)['confidence'], inInclusiveRange(0.6, 1));
      expect(r['request_kind'], 'return_refund');
      expect([
        for (final c in r['checks'] as List)
          if (c['flagged']) c['id'],
      ], isEmpty);
      final policy = r['policy'] as Map;
      expect(policy['request_kind'], 'return_refund');
      expect(policy['resolution'], 'refund');
      expect(policy['resolution_rule'], 16);
      expect(policy['reason'], contains('30 days'));
      expect(policy['refund_amount'], 279.65);
      expect(policy['amount_rule'], 4);
      expect(policy['amount_reason'], contains('15% restocking fee'));
      expect(policy['days_since_delivery'], 20);
      expect((policy['order'] as Map)['item'], 'Tablet');
    });

    test("the checks' probabilities are what the local model read", () {
      final sent = _call('route-tablet', 'request');
      final state = sent['state'] as Map;
      final checks = routing('route-tablet')['checks'] as List;
      for (final check in checks) {
        final id = check['id'];
        expect(
          check['probability'],
          state[id == 'clear_topic' ? 'topic_confidence' : '${id}_probability'],
          reason: '$id',
        );
      }
    });

    test('a card number makes it high priority, for review', () {
      final r = routing('route-card-number');
      expect((r['department'] as Map)['id'], 'billing');
      expect(r['priority'], 'high');
      expect(r['priority_rule'], 2);
      expect(r['priority_reason'], contains('Card numbers'));
      expect(r['response_hours'], 4);
      expect(r['needs_review'], isTrue);
      expect([
        for (final c in r['checks'] as List)
          if (c['flagged']) c['id'],
      ], contains('sensitive_data'));
    });

    test('abuse goes to Trust & Safety, whatever the topic', () {
      final r = routing('route-abusive');
      expect((r['topic'] as Map)['choice'], 'customer_service');
      expect((r['department'] as Map)['id'], 'trust_safety');
      expect(r['department_rule'], 1);
      expect(r['priority'], 'high');
    });

    test('a return after 45 days gets store credit', () {
      final policy = routing('route-jacket')['policy'] as Map;
      expect(policy['resolution'], 'store_credit');
      expect(policy['refund_amount'], 240);
      expect(policy['days_since_delivery'], 45);
    });

    test('a package late after 12 days is investigated, high priority', () {
      final r = routing('route-lamp-late');
      expect((r['policy'] as Map)['resolution'], 'investigate_late');
      expect(r['priority'], 'high');
      expect(r['priority_reason'], contains('late package'));
    });

    test('fails on a decision error', () {
      expect(
        () => toRouting(_call('route-tablet', 'request'), {
          'answers': {},
          'decision_error': {'code': 'evaluation_failed', 'detail': 'x'},
        }),
        throwsA(isA<RoutingFailed>()),
      );
    });
  });

  test('apiAnswer carries both calls, but not the aityx call if its answer '
      'contains the key', () {
    Map<String, Object?> answer(String text, String key) => apiAnswer(
      routing: {},
      readingSent: {'model': 'm'},
      readingAnswer: {'message': {}},
      sent: {},
      answer: {},
      text: text,
      key: key,
    );
    final leaked = answer('body with sk_123', 'sk_123');
    expect(leaked.containsKey('aityx'), isFalse);
    expect(leaked['reading'], {
      'request': {'model': 'm'},
      'response': {'message': {}},
    });
    expect(answer('clean', 'sk_123')['aityx'], {'request': {}, 'response': {}});
  });
}
