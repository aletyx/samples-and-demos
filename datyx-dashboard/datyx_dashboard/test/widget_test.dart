import 'package:datyx_dashboard/api/datyx_api.dart';
import 'package:datyx_dashboard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// An API that answers from memory, and logs its calls as the real one does.
class FakeDatyxApi implements DatyxApi {
  @override
  final CallLog log = CallLog();
  final List<Greeting> _greetings = [];
  final List<DataSource> _sources = [];

  @override
  Future<AuthConfig> authConfig() async {
    final call = log.start('GET', '/api/auth/config');
    log.finish(call, status: 200, body: '{"enabled":false}');
    return const AuthConfig(enabled: false, issuer: 'https://accounts.google.com');
  }

  @override
  Future<Me> me() async => const Me(authenticated: false);

  @override
  Future<List<DataSource>> dataSources({int limit = 100}) async {
    final call = log.start('GET', '/api/datasources');
    log.finish(call, status: 200, body: '[]');
    return _sources.reversed.toList();
  }

  @override
  Future<DataSource> addDataSource(NewDataSource source) async {
    final call = log.start('POST', '/api/datasources');
    log.finish(call, status: 201, body: '{}');
    final s = DataSource(
      id: _sources.length + 1,
      name: source.name,
      type: source.type,
      description: source.description,
      createdAt: DateTime(2026),
      createdBy: 'tests@example.com',
      details: source.details,
    );
    _sources.add(s);
    return s;
  }

  @override
  Future<void> removeDataSource(int id) async {
    _sources.removeWhere((s) => s.id == id);
  }

  @override
  Future<SystemStatus> status() async {
    final call = log.start('GET', '/api/status');
    log.finish(call, status: 200, body: '{"name":"datyx"}');
    return SystemStatus(
      name: 'datyx',
      version: '0.1.202601011200',
      startedAt: DateTime(2026),
      uptime: const Duration(minutes: 3),
      database: const Dependency(ok: true, version: 'PostgreSQL 17.0'),
      openMetadata: const Dependency(
        ok: false,
        error: 'Connection refused',
        url: 'http://localhost:9902',
      ),
      greetings: _greetings.length,
      dataSources: _sources.length,
    );
  }

  @override
  Future<String> hello({String? name}) async {
    final call = log.start('GET', '/api/hello');
    log.finish(call, status: 200, body: '{}');
    return 'Hello, ${name == null || name.isEmpty ? 'World' : name}!';
  }

  @override
  Future<List<Greeting>> greetings({int limit = 50}) async =>
      _greetings.reversed.toList();

  @override
  Future<Greeting> addGreeting(String message) async {
    final g = Greeting(id: _greetings.length + 1, message: message);
    _greetings.add(g);
    return g;
  }
}

void main() {
  testWidgets('shows the status and says hello', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final api = FakeDatyxApi();
    await tester.pumpWidget(DatyxDashApp(api: api));
    await tester.pumpAndSettle();

    expect(find.text('datyx 0.1.202601011200'), findsOneWidget);
    expect(find.text('PostgreSQL 17.0'), findsOneWidget);
    expect(find.text('Connection refused'), findsOneWidget);
    expect(find.text('0 greetings'), findsOneWidget);
    expect(find.text('off: no OIDC_CLIENT_ID on the API'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'tests');
    await tester.tap(find.text('Say hello'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, tests!'), findsOneWidget);
    // The calls panel lists the calls.
    expect(find.text('/api/hello'), findsOneWidget);
  });

  testWidgets('adds a greeting', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final api = FakeDatyxApi();
    await tester.pumpWidget(DatyxDashApp(api: api));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'Hi there');
    await tester.tap(find.text('Add greeting'));
    await tester.pumpAndSettle();
    expect(find.text('Hi there'), findsOneWidget);
    expect(find.text('1 greetings'), findsOneWidget);
  });

  testWidgets('adds and removes a data source', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final api = FakeDatyxApi();
    await tester.pumpWidget(DatyxDashApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('None yet. Add a database, an S3 bucket or a folder.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ds-add')));
    await tester.pumpAndSettle();
    expect(find.text('Add a data source'), findsOneWidget);
    await tester.tap(find.text('Filesystem'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ds-name')), 'exports');
    await tester.enterText(find.byKey(const Key('ds-path')), '/data/exports');
    await tester.tap(find.byKey(const Key('ds-submit')));
    await tester.pumpAndSettle();

    expect(find.text('exports'), findsOneWidget);
    expect(find.text('/data/exports'), findsOneWidget);
    expect(find.text('by tests@example.com'), findsOneWidget);
    expect(find.text('1 data sources'), findsOneWidget);
    // The calls panel saw the POST.
    expect(find.text('/api/datasources'), findsWidgets);

    await tester.tap(find.byKey(const Key('ds-remove-1')));
    await tester.pumpAndSettle();
    expect(find.text('Remove exports?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ds-remove-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('/data/exports'), findsNothing);
    expect(find.text('0 data sources'), findsOneWidget);
  });
}
