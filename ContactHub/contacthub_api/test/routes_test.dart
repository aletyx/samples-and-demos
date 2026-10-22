import 'package:contacthub_api/routes.dart';
import 'package:test/test.dart';

void main() {
  test('the root redirects to the app', () {
    final answer = route('GET', '/');
    expect(answer.status, 302);
    expect(answer.location, '/app/');
  });

  test('health answers ok, whether the key is set, and whether the local '
      'model is ready', () {
    final without = route('GET', '/api/health');
    expect(without.status, 200);
    expect(without.body, {
      'ok': true,
      'aityx': false,
      'local_model': {'name': '', 'ready': false},
    });

    final ready = route(
      'GET',
      '/api/health',
      aityx: true,
      localModel: (name: 'qwen3:1.7b', ready: true),
    );
    expect(ready.body, {
      'ok': true,
      'aityx': true,
      'local_model': {'name': 'qwen3:1.7b', 'ready': true},
    });
  });

  test('a preflight answers 204', () {
    expect(route('OPTIONS', '/api/health').status, 204);
  });

  test('anything else is not found', () {
    expect(route('GET', '/api/nothing').status, 404);
    expect(route('POST', '/api/health').status, 404);
    expect(route('GET', '/api/hello').status, 404);
  });
}
