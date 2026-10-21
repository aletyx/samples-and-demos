/// What the API answers, by method and path, apart from the HTTP plumbing in
/// bin/server.dart, so it can be tested without a server.
library;

/// The greeting the Hello page shows.
const helloMessage = "Hello from Contact Hub's API";

/// An answer: a status, and a JSON body or a redirect.
class Answer {
  const Answer(this.status, {this.body, this.location});

  final int status;
  final Object? body;

  /// The Location of a redirect.
  final String? location;
}

Answer route(String method, String path) {
  if (method == 'OPTIONS') return const Answer(204);
  if (method == 'GET') {
    switch (path) {
      // The site root, which the dev server proxies here
      // (scripts/flutter-web.sh), so a forwarded port's bare URL opens the
      // app. Relative, so it keeps the forwarded host and port.
      case '/':
        return const Answer(302, location: '/app/');
      case '/api/health':
        return const Answer(200, body: {'ok': true});
      case '/api/hello':
        return const Answer(200, body: {'message': helloMessage});
    }
  }
  return const Answer(404, body: {'error': 'not found'});
}
