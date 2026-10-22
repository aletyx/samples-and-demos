/// Contact Hub's API. Holds the aityx.ai key, which must never reach the
/// app, and answers:
///
///   GET  /             302 to /app/, so a forwarded port's bare URL opens
///                      the app (the dev server proxies the root here)
///   GET  /api/health   {"ok": true, "aityx": true when the key is set,
///                      "local_model": {"name", "ready"}}
///   POST /api/route    {"message": "..."} → the routing (see
///                      lib/routing.dart), in two calls: the local model
///                      reads the message on Ollama's /api/chat
///                      (lib/reading.dart), then the routing model picks
///                      the department from what it read, on aityx's
///                      /v1/systemone; with both calls, the bodies sent
///                      and the answers, under "reading" and "aityx" (the
///                      key, a header, is in neither); 504 when either
///                      runs out of time
///
/// Settings, from the environment (scripts/api.sh loads .env):
///   AITYX_API_KEY         the key (secret)
///   AITYX_URL             aityx's base URL (default https://api.aityx.ai)
///   OLLAMA_URL            where Ollama answers (default
///                         http://127.0.0.1:11434)
///   OLLAMA_MODEL          the local model (default qwen3:1.7b)
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

import 'package:contacthub_api/reading.dart';
import 'package:contacthub_api/routes.dart';
import 'package:contacthub_api/routing.dart';

const _maxBody = 16 * 1024;

/// How long a routing waits for aityx, and for the local model (which may
/// be loading into memory on its first call); docker/nginx.conf's proxy
/// waits longer than both.
const _aityxDeadline = Duration(seconds: 90);
const _readingDeadline = Duration(seconds: 120);

/// How long /api/health trusts its last look at Ollama's model list.
const _localModelCheck = Duration(seconds: 10);

/// What a routing call needs: the key, where aityx and Ollama are, the
/// model and a client.
class _Services {
  _Services(this.key, this.url, this.model, this.ollama, this.localModel);

  final String key;
  final Uri url;
  final Map<String, Object?> model;
  final Uri ollama;
  final String localModel;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);

  bool _ready = false;
  DateTime? _checked;

  /// Whether Ollama answers and lists the local model, looked up at most
  /// every [_localModelCheck].
  Future<LocalModel> status() async {
    final now = DateTime.now();
    if (_checked == null || now.difference(_checked!) > _localModelCheck) {
      _checked = now;
      try {
        final request = await client.getUrl(ollama.resolve('/api/tags'));
        final response = await request.close().timeout(
          const Duration(seconds: 3),
        );
        final text = await response.transform(utf8.decoder).join();
        _ready =
            response.statusCode == 200 &&
            listsModel(jsonDecode(text), localModel);
      } catch (_) {
        _ready = false;
      }
    }
    return (name: localModel, ready: _ready);
  }
}

Future<void> main(List<String> args) async {
  if (args.firstOrNull == 'healthcheck') exit(await _healthcheck());
  final env = Platform.environment;
  final key = env['AITYX_API_KEY'] ?? '';
  final url = Uri.parse(
    (env['AITYX_URL'] ?? '').isEmpty
        ? 'https://api.aityx.ai'
        : env['AITYX_URL']!,
  );
  if (url.scheme != 'https') {
    stderr.writeln('error: AITYX_URL must be https');
    exit(1);
  }
  final ollama = Uri.parse(
    (env['OLLAMA_URL'] ?? '').isEmpty ? defaultOllamaUrl : env['OLLAMA_URL']!,
  );
  if (ollama.scheme != 'http' && ollama.scheme != 'https') {
    stderr.writeln('error: OLLAMA_URL must be http or https');
    exit(1);
  }
  final localModel = (env['OLLAMA_MODEL'] ?? '').isEmpty
      ? defaultLocalModel
      : env['OLLAMA_MODEL']!;
  final port = int.parse(env['API_PORT'] ?? '8891');
  final host = env['CONTACTHUB_BIND_HOST'] ?? '127.0.0.1';
  final origins = (env['ALLOWED_ORIGINS'] ?? 'http://localhost:8890')
      .split(',')
      .map((origin) => origin.trim())
      .where((origin) => origin.isNotEmpty)
      .toSet();
  final modelFile = File.fromUri(
    Platform.script.resolve('../models/routing.json'),
  );
  final model =
      jsonDecode(await modelFile.readAsString()) as Map<String, Object?>;
  if (key.isEmpty) stderr.writeln('warning: AITYX_API_KEY is not set');

  final services = _Services(key, url, model, ollama, localModel);
  final server = await HttpServer.bind(host, port);
  stdout.writeln(
    'contacthub_api on http://$host:$port (aityx: ${url.host}; '
    'local model: $localModel on ${ollama.host}:${ollama.port})',
  );
  if (!(await services.status()).ready) {
    stderr.writeln(
      'warning: Ollama at $ollama does not list $localModel yet; '
      'routing answers 503 until it does',
    );
  }

  await for (final request in server) {
    unawaited(_handle(request, origins, services));
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

Future<void> _handle(
  HttpRequest request,
  Set<String> origins,
  _Services services,
) async {
  final response = request.response;
  final origin = request.headers.value('origin');
  if (origin != null && origins.contains(origin)) {
    response.headers
      ..set('Access-Control-Allow-Origin', origin)
      ..set('Vary', 'Origin')
      ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
      ..set('Access-Control-Allow-Headers', 'Content-Type');
  }
  try {
    if (request.method == 'POST' && request.uri.path == '/api/route') {
      await _route(request, services);
    } else {
      final answer = route(
        request.method,
        request.uri.path,
        aityx: services.key.isNotEmpty,
        localModel: request.uri.path == '/api/health'
            ? await services.status()
            : (name: services.localModel, ready: false),
      );
      response.statusCode = answer.status;
      if (answer.location case final location?) {
        response.headers.set(HttpHeaders.locationHeader, location);
      }
      if (answer.body case final body?) _json(response, answer.status, body);
    }
  } catch (error) {
    stderr.writeln('error: ${request.method} ${request.uri.path}: $error');
    _json(response, 500, {'error': 'internal error'});
  } finally {
    await response.close();
  }
}

/// What a call to a model service came back with.
typedef _Reply = ({int status, String text});

/// POSTs [body] to [url] and reads the whole answer within [deadline],
/// aborting the call when it runs out.
Future<_Reply> _post(
  HttpClient client,
  Uri url,
  Map<String, Object?> body,
  Duration deadline, {
  String? bearer,
}) async {
  final call = await client.postUrl(url);
  if (bearer != null) call.headers.set('Authorization', 'Bearer $bearer');
  call.headers.contentType = ContentType.json;
  call.write(jsonEncode(body));
  try {
    return await () async {
      final answer = await call.close();
      final text = await answer.transform(utf8.decoder).join();
      return (status: answer.statusCode, text: text);
    }().timeout(deadline);
  } on TimeoutException {
    call.abort(TimeoutException('no answer in time'));
    rethrow;
  }
}

/// POST /api/route: the message → the local model → aityx → the routing.
Future<void> _route(HttpRequest request, _Services services) async {
  final response = request.response;
  if (services.key.isEmpty) {
    return _json(response, 503, {'error': 'aityx is not set up'});
  }
  final String message;
  try {
    message = messageFrom(jsonDecode(await _readBody(request)));
  } on InvalidRequest catch (error) {
    return _json(response, 400, {'error': error.message});
  } on FormatException {
    return _json(response, 400, {'error': 'invalid JSON'});
  }

  // 1. The local model reads the message.
  final readingSent = readingRequest(
    services.model,
    message,
    localModel: services.localModel,
  );
  final _Reply read;
  try {
    read = await _post(
      services.client,
      services.ollama.resolve('/api/chat'),
      readingSent,
      _readingDeadline,
    );
  } on TimeoutException {
    return _json(response, 504, {
      'error': 'the local model did not answer in time',
    });
  } on SocketException catch (error) {
    stderr.writeln('ollama: $error');
    return _json(response, 503, {
      'error':
          'the local model is not running: start Ollama at '
          '${services.ollama} and pull ${services.localModel}',
    });
  }
  if (read.status == 404) {
    stderr.writeln('ollama: HTTP 404: ${read.text}');
    return _json(response, 503, {
      'error':
          'the local model ${services.localModel} is not pulled: run '
          '"ollama pull ${services.localModel}"',
    });
  }
  if (read.status != 200) {
    stderr.writeln('ollama: HTTP ${read.status}: ${read.text}');
    return _json(response, 502, {
      'error': 'the local model answered HTTP ${read.status}',
    });
  }
  final Map<String, Object?> readingAnswer;
  final Map<String, Object?> reading;
  try {
    readingAnswer = jsonDecode(read.text) as Map<String, Object?>;
    reading = factsFrom(readingSent, readingAnswer);
  } on FormatException catch (error) {
    stderr.writeln('ollama: $error');
    return _json(response, 502, {
      'error': 'unexpected answer from the local model',
    });
  } on ReadingFailed catch (error) {
    stderr.writeln('ollama: $error');
    return _json(response, 502, {
      'error': 'the local model could not read it: $error',
    });
  }

  // 2. aityx runs the rules on what it read.
  final sent = routingRequest(services.model, message, reading);
  final _Reply decided;
  try {
    decided = await _post(
      services.client,
      services.url.resolve('/v1/systemone'),
      sent,
      _aityxDeadline,
      bearer: services.key,
    );
  } on TimeoutException {
    return _json(response, 504, {'error': 'aityx did not answer in time'});
  }
  if (decided.status != 200) {
    // aityx's problem details never include the key.
    stderr.writeln('aityx: HTTP ${decided.status}: ${decided.text}');
    return _json(response, 502, {
      'error': 'aityx answered HTTP ${decided.status}',
    });
  }
  try {
    final json = jsonDecode(decided.text) as Map<String, Object?>;
    final routing = toRouting(sent, json);
    _json(
      response,
      200,
      apiAnswer(
        routing: routing,
        readingSent: readingSent,
        readingAnswer: readingAnswer,
        sent: sent,
        answer: json,
        text: decided.text,
        key: services.key,
      ),
    );
  } on FormatException catch (error) {
    stderr.writeln('aityx: $error');
    _json(response, 502, {'error': 'unexpected answer from aityx'});
  } on RoutingFailed catch (error) {
    stderr.writeln('aityx: $error');
    _json(response, 502, {'error': 'aityx could not route it: $error'});
  }
}

Future<String> _readBody(HttpRequest request) async {
  final bytes = <int>[];
  await for (final chunk in request) {
    bytes.addAll(chunk);
    if (bytes.length > _maxBody) throw InvalidRequest('request too large');
  }
  return utf8.decode(bytes);
}

void _json(HttpResponse response, int status, Object body) {
  response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
}
