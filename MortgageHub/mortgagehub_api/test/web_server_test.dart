import 'dart:convert';
import 'dart:io';

import 'package:mortgagehub_api/web_server.dart';
import 'package:test/test.dart';

/// A stand-in for the API: /api/health, / redirecting to /app/, and
/// /api/echo, which answers with the method, the query and the body.
Future<HttpServer> fakeApi() async {
  final server = await HttpServer.bind('127.0.0.1', 0);
  server.listen((request) async {
    final response = request.response;
    final path = request.uri.path;
    if (path == '/') {
      response
        ..statusCode = 302
        ..headers.set('location', '/app/');
    } else if (path == '/api/health') {
      response
        ..headers.contentType = ContentType.json
        ..write('{"ok":true,"aityx":false}');
    } else if (path == '/api/echo') {
      final body = await utf8.decoder.bind(request).join();
      response
        ..headers.contentType = ContentType.json
        ..headers.set('x-echo', 'yes')
        ..write(
          jsonEncode({
            'method': request.method,
            'query': request.uri.query,
            'body': body,
            'type': request.headers.contentType?.mimeType,
          }),
        );
    } else {
      response.statusCode = 404;
    }
    await response.close();
  });
  return server;
}

void main() {
  late Directory root;
  late HttpServer api;
  late HttpServer web;
  late HttpClient client;
  late Uri base;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('web_server_test');
    await File('${root.path}/index.html').writeAsString('<html>app</html>');
    await File('${root.path}/main.dart.js').writeAsString('js();');
    await Directory('${root.path}/canvaskit').create();
    await File('${root.path}/canvaskit/a.wasm').writeAsBytes([0, 97, 115, 109]);
    await File('${root.parent.path}/outside.txt').writeAsString('secret');
    api = await fakeApi();
    web = await serveWeb(
      root: root,
      host: '127.0.0.1',
      port: 0,
      api: Uri.parse('http://127.0.0.1:${api.port}'),
    );
    client = HttpClient();
    base = Uri.parse('http://127.0.0.1:${web.port}');
  });

  tearDown(() async {
    client.close(force: true);
    await web.close(force: true);
    await api.close(force: true);
    await root.delete(recursive: true);
  });

  Future<(HttpClientResponse, String)> get(
    String path, {
    String method = 'GET',
    Map<String, String> headers = const {},
    String? body,
  }) async {
    final request = await client.openUrl(method, base.resolve(path));
    request.followRedirects = false;
    headers.forEach(request.headers.set);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(body);
    }
    final response = await request.close();
    return (response, await utf8.decoder.bind(response).join());
  }

  test('serves the build under /app/ with content types', () async {
    final (page, html) = await get('/app/');
    expect(page.statusCode, 200);
    expect(page.headers.contentType?.mimeType, 'text/html');
    expect(html, '<html>app</html>');
    final (js, code) = await get('/app/main.dart.js');
    expect(js.headers.contentType?.mimeType, 'text/javascript');
    expect(code, 'js();');
    final (wasm, _) = await get('/app/canvaskit/a.wasm');
    expect(wasm.headers.contentType?.mimeType, 'application/wasm');
    expect(wasm.contentLength, 4);
  });

  test('falls back to index.html for the app\'s routes', () async {
    for (final path in ['/app/index.html', '/app/some/route', '/app/no.js']) {
      final (response, body) = await get(path);
      expect(response.statusCode, 200, reason: path);
      expect(body, '<html>app</html>', reason: path);
    }
    final (moved, _) = await get('/app');
    expect(moved.statusCode, 301);
    expect(moved.headers.value('location'), '/app/');
  });

  test('never serves a file outside the build', () async {
    for (final path in [
      '/app/../outside.txt',
      '/app/%2e%2e/outside.txt',
      '/app/canvaskit/../../outside.txt',
    ]) {
      final (_, body) = await get(path);
      expect(body, isNot(contains('secret')), reason: path);
    }
    final (other, _) = await get('/outside.txt');
    expect(other.statusCode, 404);
  });

  test('revalidates: no-cache, and 304 for an unchanged file', () async {
    final (first, _) = await get('/app/main.dart.js');
    expect(first.headers.value('cache-control'), 'no-cache');
    final modified = first.headers.value('last-modified')!;
    final (again, body) = await get(
      '/app/main.dart.js',
      headers: {'if-modified-since': modified},
    );
    expect(again.statusCode, 304);
    expect(body, isEmpty);
    final (head, _) = await get('/app/main.dart.js', method: 'HEAD');
    expect(head.statusCode, 200);
    expect(head.contentLength, 5);
  });

  test('proxies /api/ and the bare / to the API', () async {
    final (health, json) = await get('/api/health');
    expect(health.statusCode, 200);
    expect(jsonDecode(json), {'ok': true, 'aityx': false});
    final (echo, echoed) = await get(
      '/api/echo?x=1',
      method: 'POST',
      body: '{"a":1}',
    );
    expect(echo.headers.value('x-echo'), 'yes');
    expect(jsonDecode(echoed), {
      'method': 'POST',
      'query': 'x=1',
      'body': '{"a":1}',
      'type': 'application/json',
    });
    final (rootPage, _) = await get('/');
    expect(rootPage.statusCode, 302);
    expect(rootPage.headers.value('location'), '/app/');
  });

  test('answers 502 when the API is down', () async {
    await api.close(force: true);
    final (response, body) = await get('/api/health');
    expect(response.statusCode, 502);
    expect(body, contains('not answering'));
    api = await fakeApi(); // for tearDown
  });
}
