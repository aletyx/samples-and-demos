/// One decision asked of the API: what the aityx pilots sense and their
/// rules go out; what each does, with the aityx call behind it, comes back.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../game/race.dart';
import 'strategy.dart';

/// A pilot as the API takes it.
class PilotAsk {
  const PilotAsk(this.id, this.strategy, this.sense);

  final String id;
  final Strategy strategy;
  final Map<String, Object> sense;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': strategy.name,
    'rules': [for (final r in strategy.rules) r.toJson()],
    'sense': sense,
  };
}

/// What aityx decided at one tick, with the call behind it.
class Decision {
  const Decision(
    this.tick,
    this.actions, {
    this.aityxRequest,
    this.aityxResponse,
    this.tookMs,
    this.inputTokens,
  });

  factory Decision.fromJson(Map<String, Object?> json) {
    final aityx = json['aityx'] as Map?;
    final usage = (aityx?['response'] as Map?)?['usage'] as Map?;
    return Decision(
      (json['tick'] as num).toInt(),
      {
        for (final MapEntry(:key, :value)
            in (json['actions'] as Map).cast<String, Object?>().entries)
          key: PilotAction.fromJson((value as Map).cast<String, Object?>()),
      },
      aityxRequest: aityx?['request'],
      aityxResponse: aityx?['response'],
      tookMs: (aityx?['took_ms'] as num?)?.toInt(),
      inputTokens: (usage?['input_tokens'] as num?)?.toInt(),
    );
  }

  final int tick;

  /// By pilot id.
  final Map<String, PilotAction> actions;
  final Object? aityxRequest;
  final Object? aityxResponse;
  final int? tookMs;
  final int? inputTokens;
}

/// Asks what the pilots do: the app's API unless a test says.
abstract interface class Decider {
  Future<Decision> decide(int tick, List<PilotAsk> pilots);
}

/// The app's API, at API_BASE_URL: empty means the app's own origin (the
/// web server's or nginx's /api/ proxy).
class ApiDecider implements Decider {
  ApiDecider({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? _defaultBaseUrl;

  static const _defaultBaseUrl = String.fromEnvironment('API_BASE_URL');

  final http.Client _client;
  final String _baseUrl;

  Uri get _url => _baseUrl.isEmpty
      ? Uri.base.resolve('/api/decide')
      : Uri.parse('$_baseUrl/api/decide');

  /// Throws [DecideException] with a message for the user.
  @override
  Future<Decision> decide(int tick, List<PilotAsk> pilots) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            _url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'tick': tick,
              'pilots': [for (final p in pilots) p.toJson()],
            }),
          )
          .timeout(const Duration(seconds: 40));
    } catch (_) {
      throw const DecideException('The API did not answer.');
    }
    Object? json;
    try {
      json = jsonDecode(response.body);
    } on FormatException {
      json = null;
    }
    if (response.statusCode != 200) {
      final error = json is Map ? json['error'] : null;
      final problems = json is Map ? json['problems'] : null;
      throw DecideException(
        error is String
            ? 'aityx could not decide: $error'
                  '${problems is List && problems.isNotEmpty ? ' (${problems.join('; ')})' : ''}.'
            : 'The API answered HTTP ${response.statusCode}.',
      );
    }
    try {
      return Decision.fromJson((json as Map).cast<String, Object?>());
    } catch (_) {
      throw const DecideException('The API answered without a decision.');
    }
  }
}

class DecideException implements Exception {
  const DecideException(this.message);

  final String message;

  @override
  String toString() => message;
}
