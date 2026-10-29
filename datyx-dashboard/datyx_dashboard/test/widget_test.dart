import 'package:datyx_dashboard/api/datyx_api.dart';
import 'package:datyx_dashboard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// An API that answers from memory, and logs its calls as the real one does.
class FakeDatyxApi implements DatyxApi {
  @override
  final CallLog log = CallLog();
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
      dataSources: _sources.length,
    );
  }
}

void main() {
  testWidgets('shows the health, with the version', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final api = FakeDatyxApi();
    await tester.pumpWidget(DatyxDashApp(api: api));
    await tester.pumpAndSettle();

    // The data sources come first; the health is a tab away.
    expect(find.text('None yet. Add a database, an S3 bucket or a folder.'), findsOneWidget);
    expect(find.text('PostgreSQL 17.0'), findsNothing);
    await tester.tap(find.byKey(const Key('tab-health')));
    await tester.pumpAndSettle();
    expect(find.text('datyx 0.1.202601011200'), findsOneWidget);
    expect(find.text('PostgreSQL 17.0'), findsOneWidget);
    expect(find.text('Connection refused'), findsOneWidget);
    expect(find.text('off: no OIDC_CLIENT_ID on the API'), findsOneWidget);
    expect(find.text('0 data sources'), findsOneWidget);
    // A test build has no version compiled in.
    expect(find.text('no version: not built by the scripts'), findsOneWidget);
  });

  testWidgets('audits every call', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final api = FakeDatyxApi();
    await tester.pumpWidget(DatyxDashApp(api: api));
    await tester.pumpAndSettle();

    // The tab counts the calls made so far: the sign-in config, the status
    // and the data sources.
    expect(find.text('Audit (3)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab-audit')));
    await tester.pumpAndSettle();
    expect(find.text('/api/auth/config'), findsOneWidget);
    expect(find.text('/api/status'), findsOneWidget);
    expect(find.text('/api/datasources'), findsOneWidget);
    expect(find.text('3 of the latest 100 kept'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('No calls yet.'), findsOneWidget);
    expect(find.text('Audit (0)'), findsOneWidget);
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
    await tester.tap(find.byKey(const Key('tab-health')));
    await tester.pumpAndSettle();
    expect(find.text('1 data sources'), findsOneWidget);
    // The audit saw the POST.
    await tester.tap(find.byKey(const Key('tab-audit')));
    await tester.pumpAndSettle();
    expect(find.text('POST'), findsOneWidget);
    expect(find.text('/api/datasources'), findsWidgets);

    await tester.tap(find.byKey(const Key('tab-sources')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ds-remove-1')));
    await tester.pumpAndSettle();
    expect(find.text('Remove exports?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ds-remove-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('/data/exports'), findsNothing);
    await tester.tap(find.byKey(const Key('tab-health')));
    await tester.pumpAndSettle();
    expect(find.text('0 data sources'), findsOneWidget);
  });
}
