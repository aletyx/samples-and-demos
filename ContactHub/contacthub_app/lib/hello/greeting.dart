import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fetches the API's greeting: the Hello page's proof that the app reaches
/// the API.
abstract interface class Greeter {
  Future<String> greet();
}

/// The app's API, at API_BASE_URL: empty means the app's own origin (the
/// dev server's or nginx's /api/ proxy).
class ApiGreeter implements Greeter {
  ApiGreeter({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? _defaultBaseUrl;

  static const _defaultBaseUrl = String.fromEnvironment('API_BASE_URL');

  final http.Client _client;
  final String _baseUrl;

  Uri get _helloUrl => _baseUrl.isEmpty
      ? Uri.base.resolve('/api/hello')
      : Uri.parse('$_baseUrl/api/hello');

  /// The API's `message`; throws [GreetingException] when it doesn't answer
  /// with one.
  @override
  Future<String> greet() async {
    final http.Response response;
    try {
      response = await _client
          .get(_helloUrl)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const GreetingException('The API did not answer.');
    }
    if (response.statusCode != 200) {
      throw GreetingException('The API answered HTTP ${response.statusCode}.');
    }
    try {
      final json = jsonDecode(response.body);
      final message = json is Map ? json['message'] : null;
      if (message is String && message.isNotEmpty) return message;
    } on FormatException {
      // Falls through to the exception below.
    }
    throw const GreetingException('The API answered without a greeting.');
  }
}

class GreetingException implements Exception {
  const GreetingException(this.message);

  final String message;

  @override
  String toString() => message;
}
