import 'dart:convert';
import 'dart:io';

import 'package:contacthub_api/routing.dart';
import 'package:test/test.dart';

Map<String, Object?> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

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
    test('names a department for every topic Jev can pick', () {
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

  test('routingRequest sends the questions, the model and the message', () {
    final sent = routingRequest(model, 'Hi');
    expect(sent['questions'], model['questions']);
    expect(sent['decision'], model['decision']);
    expect(sent['state'], {'message': 'Hi'});
  });

  group('toRouting, from real aityx answers', () {
    final sent = routingRequest(model, 'a message');

    test('an order goes to Customer Service', () {
      final routing = toRouting(sent, _json('test/fixtures/order.json'));
      expect((routing['department'] as Map)['id'], 'customer_service');
      expect((routing['department'] as Map)['person'], 'Maria Lopez');
      expect(routing['department_rule'], 3);
      expect(routing['reason'], contains('Customer Service'));
      expect(routing['priority'], 'normal');
      expect(routing['response_hours'], 24);
      expect(routing['needs_review'], isFalse);
      expect((routing['topic'] as Map)['choice'], 'customer_service');
      expect([
        for (final c in routing['checks'] as List)
          if (c['flagged']) c['id'],
      ], isEmpty);
    });

    test('a card number makes it high priority, for review', () {
      final routing = toRouting(
        sent,
        _json('test/fixtures/billing-card-number.json'),
      );
      expect((routing['department'] as Map)['id'], 'billing');
      expect(routing['priority'], 'high');
      expect(routing['priority_rule'], 2);
      expect(routing['priority_reason'], contains('Card numbers'));
      expect(routing['response_hours'], 4);
      expect(routing['needs_review'], isTrue);
      expect([
        for (final c in routing['checks'] as List)
          if (c['flagged']) c['id'],
      ], containsAll(['urgent', 'sensitive_data']));
    });

    test('abuse goes to Trust & Safety, whatever the topic', () {
      final routing = toRouting(sent, _json('test/fixtures/abusive.json'));
      expect((routing['topic'] as Map)['choice'], 'customer_service');
      expect((routing['department'] as Map)['id'], 'trust_safety');
      expect(routing['department_rule'], 1);
    });

    test('fails on a decision error', () {
      expect(
        () => toRouting(sent, {
          'answers': {},
          'decision_error': {'code': 'evaluation_failed', 'detail': 'x'},
        }),
        throwsA(isA<RoutingFailed>()),
      );
    });
  });

  test('withAityx leaves out the call if the answer contains the key', () {
    final out = withAityx({}, {}, {}, 'body with sk_123', 'sk_123');
    expect(out.containsKey('aityx'), isFalse);
    expect(withAityx({}, {}, {}, 'clean', 'sk_123')['aityx'], isNotNull);
  });
}
