import 'package:contacthub_api/routes.dart';
import 'package:test/test.dart';

void main() {
  test('the root redirects to the app', () {
    final answer = route('GET', '/');
    expect(answer.status, 302);
    expect(answer.location, '/app/');
  });

  test('health answers ok', () {
    final answer = route('GET', '/api/health');
    expect(answer.status, 200);
    expect(answer.body, {'ok': true});
  });

  test('hello answers the greeting', () {
    final answer = route('GET', '/api/hello');
    expect(answer.status, 200);
    expect(answer.body, {'message': helloMessage});
  });

  test('a preflight answers 204', () {
    expect(route('OPTIONS', '/api/hello').status, 204);
  });

  test('anything else is not found', () {
    expect(route('GET', '/api/nothing').status, 404);
    expect(route('POST', '/api/hello').status, 404);
  });
}
