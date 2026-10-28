import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthhub_app/api/health_hub_api.dart';
import 'package:healthhub_app/main.dart';

/// An API whose database answers, or one whose doesn't.
class FakeApi implements HealthHubApi {
  FakeApi({this.dbUp = true});

  final bool dbUp;
  int hellos = 0;

  @override
  Future<Health> health() async => Health(ok: true, db: dbUp, aityx: false);

  @override
  Future<AuthConfig> authConfig() async =>
      const AuthConfig(enabled: false, issuer: 'https://accounts.google.com');

  @override
  Future<Me> me() async => const Me(authenticated: false);

  @override
  Future<Me> datyxMe() async => const Me(authenticated: false);

  @override
  Future<int> datyxDataSources() async => 3;

  @override
  Future<Greeting> hello() async {
    hellos++;
    if (!dbUp) throw const ApiException(503, 'the database is not answering');
    return Greeting(
      message: 'Hello, world',
      since: DateTime.utc(2026, 10, 28, 12),
      postgres: 'PostgreSQL 17.6 on x86_64-pc-linux-gnu, compiled by gcc',
    );
  }
}

void main() {
  testWidgets('shows the greeting from the database and the health', (
    tester,
  ) async {
    final api = FakeApi();
    await tester.pumpWidget(HealthHubApp(api: api));
    await tester.pumpAndSettle();

    expect(find.text('HealthHub'), findsOneWidget);
    expect(find.text('Hello, world'), findsOneWidget);
    expect(find.textContaining('Read from PostgreSQL 17.6'), findsOneWidget);
    expect(find.text('API ok'), findsOneWidget);
    expect(find.text('PostgreSQL ok'), findsOneWidget);
    expect(find.text('aityx key not set'), findsOneWidget);
    expect(find.text('sign-in off'), findsOneWidget);
    expect(find.byKey(const Key('datyx-card')), findsOneWidget);
    expect(find.text('3 data sources on record in datyx'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reload')));
    await tester.pumpAndSettle();
    expect(api.hellos, 2);
  });

  testWidgets('says so when the database is down', (tester) async {
    await tester.pumpWidget(HealthHubApp(api: FakeApi(dbUp: false)));
    await tester.pumpAndSettle();

    expect(find.text('No greeting'), findsOneWidget);
    expect(
      find.textContaining('the database is not answering'),
      findsOneWidget,
    );
  });
}
