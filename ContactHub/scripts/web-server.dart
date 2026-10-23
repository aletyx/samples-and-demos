/// Serves a release build of the app, for scripts/flutter-web.sh when
/// FLUTTER_WEB_MODE=release (the dev containers set it): the build at
/// /app/, gzipped when the browser accepts it, and /api/ and the bare
/// root sent on to the API, as the dev server's proxy does in debug mode.
/// A codespace's forwarded port carries a release build (a few MB) in
/// seconds, where a debug build's dart_sdk.js alone takes minutes.
///
/// Plain Dart, no packages: `dart scripts/web-server.dart`. Settings, from
/// the environment:
///   WEB_ROOT   the build (flutter build web); until WEB_ROOT/.ready
///              exists, /app/ answers 503 with a page that says the app is
///              building and reloads itself
///   WEB_HOST   the address to bind (default 127.0.0.1)
///   WEB_PORT   the port (default 8080)
///   API_PORT   the API on 127.0.0.1 that /api/ and / go to
library;

import 'dart:async';
import 'dart:io';

const _types = {
  'html': 'text/html; charset=utf-8',
  'js': 'text/javascript; charset=utf-8',
  'mjs': 'text/javascript; charset=utf-8',
  'json': 'application/json',
  'css': 'text/css; charset=utf-8',
  'wasm': 'application/wasm',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'svg': 'image/svg+xml',
  'ico': 'image/x-icon',
  'ttf': 'font/ttf',
  'otf': 'font/otf',
  'woff': 'font/woff',
  'woff2': 'font/woff2',
  'txt': 'text/plain; charset=utf-8',
  'map': 'application/json',
};

/// Worth gzipping: text and wasm, not images or fonts already compressed.
const _compressible = {
  'html',
  'js',
  'mjs',
  'json',
  'css',
  'wasm',
  'svg',
  'txt',
  'map',
  'ttf',
  'otf',
};

/// Not passed on between the browser and the API.
const _hopByHop = {
  'connection',
  'keep-alive',
  'proxy-connection',
  'transfer-encoding',
  'upgrade',
  'te',
  'trailer',
  'host',
  'content-length',
};

const _building = '''<!doctype html>
<html><head><meta charset="utf-8"><meta http-equiv="refresh" content="5">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Building…</title>
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#17161A;color:#F3F1EE;font:15px system-ui,sans-serif}p{color:#A09C97}</style>
</head><body><div><h1>Building the app…</h1><p>A release build, the first time this codespace starts it. This page reloads itself.</p></div></body></html>
''';

/// The gzipped bytes of each file served, by path and modification time.
final _gzipped = <String, (DateTime, List<int>)>{};

Future<void> main() async {
  final env = Platform.environment;
  final root = Directory(env['WEB_ROOT'] ?? 'build/web').absolute;
  final host = env['WEB_HOST'] ?? '127.0.0.1';
  final port = int.parse(env['WEB_PORT'] ?? '8080');
  final apiPort = int.parse(env['API_PORT'] ?? '8081');
  final client = HttpClient()..autoUncompress = false;
  final server = await HttpServer.bind(host, port);
  server.autoCompress = false;
  stdout.writeln(
    'web-server on http://$host:$port/app/ (${root.path}; API on $apiPort)',
  );
  await for (final request in server) {
    unawaited(_handle(request, root, client, apiPort));
  }
}

Future<void> _handle(
  HttpRequest request,
  Directory root,
  HttpClient client,
  int apiPort,
) async {
  final path = request.uri.path;
  try {
    final response = request.response;
    if (path == '/' || path.startsWith('/api/')) {
      await _proxy(request, client, apiPort);
    } else if (path == '/app') {
      response
        ..statusCode = HttpStatus.movedPermanently
        ..headers.set(HttpHeaders.locationHeader, '/app/');
    } else if (!path.startsWith('/app/') || path.split('/').contains('..')) {
      response
        ..statusCode = HttpStatus.notFound
        ..write('not found');
    } else if (!File('${root.path}/.ready').existsSync()) {
      response
        ..statusCode = HttpStatus.serviceUnavailable
        ..headers.contentType = ContentType.html
        ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
        ..write(_building);
    } else {
      await _file(request, root, path.substring('/app/'.length));
    }
  } catch (error) {
    stderr.writeln('web-server: ${request.method} $path: $error');
    try {
      request.response.statusCode = HttpStatus.badGateway;
    } catch (_) {}
  }
  await request.response.close();
}

/// A file of the build. A path with no file extension is one of the app's
/// own routes, so it gets index.html; a missing file is a 404.
Future<void> _file(HttpRequest request, Directory root, String relative) async {
  final response = request.response;
  var file = File('${root.path}/$relative');
  if (!file.existsSync()) {
    if (relative.split('/').last.contains('.')) {
      response
        ..statusCode = HttpStatus.notFound
        ..write('not found');
      return;
    }
    file = File('${root.path}/index.html');
  }
  final name = file.path.split('/').last;
  final ext = name.contains('.') ? name.split('.').last : '';
  response.headers
    ..set(
      HttpHeaders.contentTypeHeader,
      _types[ext] ?? 'application/octet-stream',
    )
    // The entry points change with every build; the rest is fetched again
    // only when it has changed.
    ..set(HttpHeaders.cacheControlHeader, 'no-cache')
    ..set(HttpHeaders.varyHeader, 'Accept-Encoding');
  final modified = file.lastModifiedSync();
  final gzip =
      _compressible.contains(ext) &&
      (request.headers.value(HttpHeaders.acceptEncodingHeader) ?? '').contains(
        'gzip',
      );
  if (!gzip) {
    response.headers.contentLength = file.lengthSync();
    if (request.method != 'HEAD') await response.addStream(file.openRead());
    return;
  }
  final cached = _gzipped[file.path];
  final List<int> bytes;
  if (cached != null && cached.$1 == modified) {
    bytes = cached.$2;
  } else {
    bytes = GZipCodec(level: 6).encode(await file.readAsBytes());
    _gzipped[file.path] = (modified, bytes);
  }
  response.headers
    ..set(HttpHeaders.contentEncodingHeader, 'gzip')
    ..contentLength = bytes.length;
  if (request.method != 'HEAD') response.add(bytes);
}

/// The request as it came, to the API, and its answer as it came back.
Future<void> _proxy(HttpRequest request, HttpClient client, int apiPort) async {
  final target = Uri(
    scheme: 'http',
    host: '127.0.0.1',
    port: apiPort,
    path: request.uri.path,
    query: request.uri.hasQuery ? request.uri.query : null,
  );
  final outgoing = await client.openUrl(request.method, target);
  outgoing.followRedirects = false;
  request.headers.forEach((name, values) {
    if (_hopByHop.contains(name)) return;
    for (final value in values) {
      outgoing.headers.add(name, value);
    }
  });
  await outgoing.addStream(request);
  final answer = await outgoing.close();
  final response = request.response..statusCode = answer.statusCode;
  // set, not add: the API's headers replace this server's defaults of the
  // same name instead of repeating them.
  answer.headers.forEach((name, values) {
    if (!_hopByHop.contains(name)) response.headers.set(name, values);
  });
  await response.addStream(answer);
}
