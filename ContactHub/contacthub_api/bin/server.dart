/// Contact Hub's API. For now it only proves the app reaches it, and
/// answers:
///
///   GET  /             302 to /app/, so a forwarded port's bare URL opens
///                      the app (the dev server proxies the root here)
///   GET  /api/health   {"ok": true}
///   GET  /api/hello    {"message": "Hello from Contact Hub's API"}
///
/// Settings, from the environment (scripts/api.sh sets them):
///   API_PORT              the port (default 8891)
///   CONTACTHUB_BIND_HOST  the address to bind (default 127.0.0.1)
///   ALLOWED_ORIGINS       comma-separated origins allowed by CORS
///                         (default http://localhost:8890)
///
/// `server healthcheck` instead asks a running server's /api/health on
/// 127.0.0.1:API_PORT and exits 0 when it answers ok: the Docker health
/// check, since the image has no shell or curl.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:contacthub_api/routes.dart';

Future<void> main(List<String> args) async {
  if (args.firstOrNull == 'healthcheck') exit(await _healthcheck());
  final env = Platform.environment;
  final port = int.parse(env['API_PORT'] ?? '8891');
  final host = env['CONTACTHUB_BIND_HOST'] ?? '127.0.0.1';
  final origins = (env['ALLOWED_ORIGINS'] ?? 'http://localhost:8890')
      .split(',')
      .map((origin) => origin.trim())
      .where((origin) => origin.isNotEmpty)
      .toSet();

  final server = await HttpServer.bind(host, port);
  stdout.writeln('contacthub_api on http://$host:$port');

  await for (final request in server) {
    unawaited(_handle(request, origins));
  }
}

/// 0 when the server on this machine answers /api/health with ok, else 1.
Future<int> _healthcheck() async {
  final port = int.parse(Platform.environment['API_PORT'] ?? '8891');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:$port/api/health'),
    );
    final response = await request.close().timeout(const Duration(seconds: 3));
    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body);
    return response.statusCode == 200 && json is Map && json['ok'] == true
        ? 0
        : 1;
  } catch (error) {
    stderr.writeln('healthcheck: $error');
    return 1;
  } finally {
    client.close(force: true);
  }
}

Future<void> _handle(HttpRequest request, Set<String> origins) async {
  final response = request.response;
  final origin = request.headers.value('origin');
  if (origin != null && origins.contains(origin)) {
    response.headers
      ..set('Access-Control-Allow-Origin', origin)
      ..set('Vary', 'Origin')
      ..set('Access-Control-Allow-Methods', 'GET, OPTIONS')
      ..set('Access-Control-Allow-Headers', 'Content-Type');
  }
  try {
    final answer = route(request.method, request.uri.path);
    response.statusCode = answer.status;
    if (answer.location case final location?) {
      response.headers.set(HttpHeaders.locationHeader, location);
    }
    if (answer.body case final body?) {
      response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
    }
  } catch (error) {
    stderr.writeln('error: ${request.method} ${request.uri.path}: $error');
    response
      ..statusCode = HttpStatus.internalServerError
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'error': 'internal error'}));
  } finally {
    await response.close();
  }
}
