import 'dart:convert';

import 'package:http/http.dart' as http;

import 'proposal_request.dart';

/// The regulatory check of a proposal request: aityx.ai's verdict under
/// current US rules, through the app's API (mortgagehub_api), which holds
/// the aityx key.
class ProposalCheck {
  const ProposalCheck({
    required this.status,
    required this.checks,
    required this.ltv,
    required this.maxLtv,
    required this.dti,
    required this.housingPayment,
    required this.assumedRate,
  });

  factory ProposalCheck.fromJson(Map<String, Object?> json) {
    final figures = json['figures'] as Map<String, Object?>;
    num figure(String key) => figures[key] as num;
    return ProposalCheck(
      status: CheckStatus.parse(json['status'] as String),
      checks: [
        for (final check in json['checks'] as List)
          CheckItem.fromJson(check as Map<String, Object?>),
      ],
      ltv: figure('ltv').toDouble(),
      maxLtv: figure('maxLtv').toDouble(),
      dti: figure('dti').toDouble(),
      housingPayment: figure('housingPayment').toDouble(),
      assumedRate: figure('assumedRate').toDouble(),
    );
  }

  final CheckStatus status;
  final List<CheckItem> checks;
  final double ltv;
  final double maxLtv;
  final double dti;

  /// Estimated: principal, interest, taxes, insurance and HOA dues.
  final double housingPayment;

  /// The annual rate, in percent, the payment is estimated with.
  final double assumedRate;
}

enum CheckStatus {
  processable('processable', 'Processable'),
  needsReview('needs_review', 'Needs review'),
  notProcessable('not_processable', 'Not processable');

  const CheckStatus(this.wireName, this.label);

  /// The model's name for it.
  final String wireName;
  final String label;

  static CheckStatus parse(String name) =>
      values.firstWhere((status) => status.wireName == name);
}

enum CheckResult { pass, review, fail }

class CheckItem {
  const CheckItem({
    required this.id,
    required this.result,
    required this.reason,
  });

  factory CheckItem.fromJson(Map<String, Object?> json) => CheckItem(
    id: json['id'] as String,
    result: CheckResult.values.byName(json['result'] as String),
    reason: json['reason'] as String,
  );

  final String id;
  final CheckResult result;
  final String reason;

  String get label => switch (id) {
    'program' => 'Program eligibility',
    'ltv' => 'Loan-to-value',
    'limit' => 'Loan limits (2026)',
    'credit' => 'Credit score',
    'dti' => 'Debt-to-income',
    _ => id,
  };
}

/// Checks a proposal request; a fake one in tests.
abstract interface class ProposalChecker {
  Future<ProposalCheck> check(ProposalRequest request);
}

/// The app's API, at API_BASE_URL (scripts/flutter-web.sh sets it to the
/// local API).
class ApiProposalChecker implements ProposalChecker {
  ApiProposalChecker({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? _defaultBaseUrl;

  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8881',
  );

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<ProposalCheck> check(ProposalRequest request) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/api/proposals/check'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(request.toJson()),
        )
        .timeout(const Duration(seconds: 90));
    if (response.statusCode != 200) {
      final error = switch (_tryDecode(response.body)) {
        {'error': final String message} => message,
        _ => 'HTTP ${response.statusCode}',
      };
      throw ProposalCheckException(error);
    }
    return ProposalCheck.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  static Object? _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}

class ProposalCheckException implements Exception {
  ProposalCheckException(this.message);
  final String message;
  @override
  String toString() => message;
}
