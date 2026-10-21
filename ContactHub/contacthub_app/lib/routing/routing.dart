import 'dart:convert';

import 'package:http/http.dart' as http;

/// The department a request went to, and who there handles it.
class Department {
  const Department({
    required this.id,
    required this.name,
    required this.person,
    required this.role,
    required this.email,
  });

  factory Department.fromJson(Map<String, Object?> json) => Department(
    id: json['id'] as String,
    name: json['name'] as String,
    person: json['person'] as String,
    role: json['role'] as String,
    email: json['email'] as String,
  );

  final String id;
  final String name;
  final String person;
  final String role;
  final String email;
}

/// One of the checks run on the message, and whether it raised a flag.
class RoutingCheck {
  const RoutingCheck({
    required this.id,
    required this.label,
    required this.flagged,
    this.probability,
  });

  factory RoutingCheck.fromJson(Map<String, Object?> json) => RoutingCheck(
    id: json['id'] as String,
    label: json['label'] as String,
    flagged: json['flagged'] as bool,
    probability: (json['probability'] as num?)?.toDouble(),
  );

  /// `urgent`, `sensitive_data`, `abusive` or `clear_topic`.
  final String id;
  final String label;
  final bool flagged;

  /// aityx's probability behind it (for `clear_topic`, its confidence in the
  /// topic).
  final double? probability;
}

/// Where the API routed a request: aityx's decision, read for the app.
class Routing {
  const Routing({
    required this.department,
    required this.reason,
    required this.departmentRule,
    required this.priority,
    required this.priorityReason,
    required this.priorityRule,
    required this.responseHours,
    required this.needsReview,
    required this.topic,
    required this.topicConfidence,
    required this.topicProbabilities,
    required this.checks,
  });

  factory Routing.fromJson(Map<String, Object?> json) {
    final topic = (json['topic'] as Map?)?.cast<String, Object?>() ?? {};
    return Routing(
      department: Department.fromJson(
        (json['department'] as Map).cast<String, Object?>(),
      ),
      reason: json['reason'] as String?,
      departmentRule: json['department_rule'] as int?,
      priority: json['priority'] as String,
      priorityReason: json['priority_reason'] as String?,
      priorityRule: json['priority_rule'] as int?,
      responseHours: (json['response_hours'] as num).toInt(),
      needsReview: json['needs_review'] as bool,
      topic: topic['choice'] as String?,
      topicConfidence: (topic['confidence'] as num?)?.toDouble(),
      topicProbabilities: {
        for (final MapEntry(:key, :value)
            in ((topic['probabilities'] as Map?) ?? const {}).entries)
          '$key': (value as num).toDouble(),
      },
      checks: [
        for (final check in (json['checks'] as List?) ?? const [])
          RoutingCheck.fromJson((check as Map).cast<String, Object?>()),
      ],
    );
  }

  final Department department;

  /// Why: the `# why` of the department table's row that fired.
  final String? reason;

  /// That row's number in the table (1-based; row 0 is the header).
  final int? departmentRule;

  /// `low`, `normal` or `high`.
  final String priority;
  final String? priorityReason;
  final int? priorityRule;
  final int responseHours;
  final bool needsReview;

  /// aityx's choice of topic, its confidence, and every topic's probability.
  final String? topic;
  final double? topicConfidence;
  final Map<String, double> topicProbabilities;
  final List<RoutingCheck> checks;
}

/// A routed request: the [routing], and the aityx call behind it, when the
/// API sent it.
class RoutingOutcome {
  const RoutingOutcome(this.routing, {this.aityxRequest, this.aityxResponse});

  factory RoutingOutcome.fromJson(Map<String, Object?> json) {
    final aityx = json['aityx'] as Map?;
    return RoutingOutcome(
      Routing.fromJson((json['routing'] as Map).cast<String, Object?>()),
      aityxRequest: aityx?['request'],
      aityxResponse: aityx?['response'],
    );
  }

  final Routing routing;
  final Object? aityxRequest;
  final Object? aityxResponse;
}

/// Routes a request: the app's API unless a test says.
abstract interface class RequestRouter {
  Future<RoutingOutcome> route(String message);
}

/// The app's API, at API_BASE_URL: empty means the app's own origin (the
/// dev server's or nginx's /api/ proxy).
class ApiRequestRouter implements RequestRouter {
  ApiRequestRouter({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? _defaultBaseUrl;

  static const _defaultBaseUrl = String.fromEnvironment('API_BASE_URL');

  final http.Client _client;
  final String _baseUrl;

  Uri get _routeUrl => _baseUrl.isEmpty
      ? Uri.base.resolve('/api/route')
      : Uri.parse('$_baseUrl/api/route');

  /// Throws [RoutingException] with a message for the user.
  @override
  Future<RoutingOutcome> route(String message) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            _routeUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'message': message}),
          )
          .timeout(const Duration(seconds: 100));
    } catch (_) {
      throw const RoutingException('The API did not answer.');
    }
    Object? json;
    try {
      json = jsonDecode(response.body);
    } on FormatException {
      json = null;
    }
    if (response.statusCode != 200) {
      final error = json is Map ? json['error'] : null;
      throw RoutingException(
        error is String
            ? 'Could not route it: $error.'
            : 'The API answered HTTP ${response.statusCode}.',
      );
    }
    try {
      return RoutingOutcome.fromJson((json as Map).cast<String, Object?>());
    } catch (_) {
      throw const RoutingException('The API answered without a routing.');
    }
  }
}

class RoutingException implements Exception {
  const RoutingException(this.message);

  final String message;

  @override
  String toString() => message;
}
