import 'dart:async';

import 'package:flutter/material.dart';

import '../api/datyx_api.dart';
import '../app_version.dart';
import '../auth/auth_controller.dart';
import '../theme.dart';
import 'calls_panel.dart';
import 'card_title.dart';
import 'data_sources_card.dart';
import 'user_menu.dart';

/// The dashboard: the system's status as the API reports it, the data
/// sources on record, a hello call, the greetings on record, and every call
/// made, in a side panel. Refreshes the status, the data sources and the
/// greetings every [refreshEvery]. With authentication on, the data sources
/// wait for a signed-in user ([auth]); the rest is open.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.api,
    required this.auth,
    this.refreshEvery = const Duration(seconds: 15),
  });

  final DatyxApi api;
  final AuthController auth;
  final Duration refreshEvery;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  SystemStatus? _status;
  String? _statusError;
  List<Greeting> _greetings = const [];
  List<DataSource> _sources = const [];
  Me? _me;
  String? _hello;
  bool _busy = false;
  bool _signedIn = false;
  Timer? _timer;
  final _name = TextEditingController();
  final _message = TextEditingController();

  /// Whether the API would refuse the secured calls right now.
  bool get _locked => widget.auth.enabled && !widget.auth.signedIn;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_authChanged);
    _refresh();
    if (widget.refreshEvery > Duration.zero) {
      _timer = Timer.periodic(widget.refreshEvery, (_) => _refresh());
    }
  }

  @override
  void dispose() {
    widget.auth.removeListener(_authChanged);
    _timer?.cancel();
    _name.dispose();
    _message.dispose();
    super.dispose();
  }

  void _authChanged() {
    // Signing in or out changes what the API shows: ask again.
    if (widget.auth.signedIn != _signedIn || widget.auth.config != null && _me == null) {
      _signedIn = widget.auth.signedIn;
      if (!_signedIn) _me = null;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final status = await widget.api.status();
      if (!mounted) return;
      setState(() {
        _status = status;
        _statusError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusError = e.toString());
    }
    if (!_locked) {
      try {
        final sources = await widget.api.dataSources();
        if (mounted) setState(() => _sources = sources);
      } catch (_) {
        // The call is in the panel; the list keeps what it had.
      }
    }
    if (widget.auth.enabled && widget.auth.signedIn && _me == null) {
      try {
        final me = await widget.api.me();
        if (mounted) setState(() => _me = me);
      } catch (_) {
        // In the panel.
      }
    }
    try {
      final greetings = await widget.api.greetings();
      if (mounted) setState(() => _greetings = greetings);
    } catch (_) {
      // Likewise.
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _sayHello() async {
    try {
      final message = await widget.api.hello(name: _name.text.trim());
      if (mounted) setState(() => _hello = message);
    } catch (e) {
      if (mounted) setState(() => _hello = e.toString());
    }
  }

  Future<void> _addGreeting() async {
    final message = _message.text.trim();
    if (message.isEmpty) return;
    try {
      await widget.api.addGreeting(message);
      _message.clear();
      await _refresh();
    } catch (e) {
      _tell('$e');
    }
  }

  Future<void> _addSource(NewDataSource source) async {
    try {
      await widget.api.addDataSource(source);
      await _refresh();
    } catch (e) {
      _tell('$e');
    }
  }

  Future<void> _removeSource(DataSource source) async {
    try {
      await widget.api.removeDataSource(source.id);
      await _refresh();
    } catch (e) {
      _tell('$e');
    }
  }

  void _tell(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final main = _MainColumn(
      status: _status,
      statusError: _statusError,
      auth: widget.auth,
      me: _me,
      sources: _sources,
      locked: _locked,
      greetings: _greetings,
      hello: _hello,
      name: _name,
      message: _message,
      onHello: _sayHello,
      onAddGreeting: _addGreeting,
      onAddSource: _addSource,
      onRemoveSource: _removeSource,
    );
    final calls = CallsPanel(log: widget.api.log);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppVersion.title),
        actions: [
          UserMenu(auth: widget.auth),
          const SizedBox(width: 12),
          if (AppVersion.version.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  'dash ${AppVersion.version}',
                  style: const TextStyle(color: Aityx.muted, fontSize: 12),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : _refresh,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: main),
                const VerticalDivider(width: 1),
                SizedBox(width: 420, child: calls),
              ],
            )
          : Column(
              children: [
                Expanded(child: main),
                const Divider(height: 1),
                SizedBox(height: 280, child: calls),
              ],
            ),
    );
  }
}

class _MainColumn extends StatelessWidget {
  const _MainColumn({
    required this.status,
    required this.statusError,
    required this.auth,
    required this.me,
    required this.sources,
    required this.locked,
    required this.greetings,
    required this.hello,
    required this.name,
    required this.message,
    required this.onHello,
    required this.onAddGreeting,
    required this.onAddSource,
    required this.onRemoveSource,
  });

  final SystemStatus? status;
  final String? statusError;
  final AuthController auth;
  final Me? me;
  final List<DataSource> sources;
  final bool locked;
  final List<Greeting> greetings;
  final String? hello;
  final TextEditingController name;
  final TextEditingController message;
  final VoidCallback onHello;
  final VoidCallback onAddGreeting;
  final ValueChanged<NewDataSource> onAddSource;
  final ValueChanged<DataSource> onRemoveSource;

  @override
  Widget build(BuildContext context) {
    final s = status;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (statusError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'The API did not answer: $statusError',
              style: const TextStyle(color: Aityx.red),
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            StatusCard(
              title: 'API',
              ok: s != null,
              lines: s == null
                  ? const ['waiting for /api/status']
                  : [
                      '${s.name} ${s.version}',
                      'up ${_uptime(s.uptime)}',
                      if (s.startedAt != null)
                        'since ${s.startedAt!.toLocal().toString().substring(0, 19)}',
                    ],
            ),
            StatusCard(
              title: 'PostgreSQL',
              ok: s?.database.ok ?? false,
              lines: _dependency(s?.database),
            ),
            StatusCard(
              title: 'OpenMetadata',
              ok: s?.openMetadata.ok ?? false,
              lines: [
                ..._dependency(s?.openMetadata),
                if (s?.openMetadata.url != null) s!.openMetadata.url!,
              ],
            ),
            ListenableBuilder(
              listenable: auth,
              builder: (context, _) => StatusCard(
                title: 'Sign-in',
                ok: auth.config != null && (!auth.enabled || auth.signedIn),
                lines: auth.config == null
                    ? const ['waiting for /api/auth/config']
                    : !auth.enabled
                        ? const ['off: no OIDC_CLIENT_ID on the API', 'every call is anonymous']
                        : auth.signedIn
                            ? [
                                'OpenID Connect, ${Uri.tryParse(auth.config!.issuer)?.host ?? auth.config!.issuer}',
                                me == null
                                    ? 'the API has not confirmed yet'
                                    : 'the API sees ${me!.email ?? me!.subject}',
                              ]
                            : ['on: ${Uri.tryParse(auth.config!.issuer)?.host ?? auth.config!.issuer}', 'nobody signed in'],
              ),
            ),
            StatusCard(
              title: 'Records',
              ok: s != null,
              lines: s == null
                  ? const ['…']
                  : ['${s.dataSources} data sources', '${s.greetings} greetings'],
            ),
          ],
        ),
        const SizedBox(height: 16),
        DataSourcesCard(
          sources: sources,
          locked: locked,
          onAdd: onAddSource,
          onRemove: onRemoveSource,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CardTitle('Hello', 'GET /api/hello'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: name,
                        decoration: const InputDecoration(
                          hintText: 'A name, or nothing for the world',
                        ),
                        onSubmitted: (_) => onHello(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(onPressed: onHello, child: const Text('Say hello')),
                  ],
                ),
                if (hello != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    hello!,
                    key: const Key('hello-message'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CardTitle('Greetings on record', 'GET and POST /api/greetings'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: message,
                        decoration: const InputDecoration(
                          hintText: 'A greeting to keep',
                        ),
                        onSubmitted: (_) => onAddGreeting(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(onPressed: onAddGreeting, child: const Text('Add greeting')),
                  ],
                ),
                const SizedBox(height: 12),
                if (greetings.isEmpty)
                  const Text('None yet.', style: TextStyle(color: Aityx.muted))
                else
                  for (final g in greetings)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Text(
                            '#${g.id}',
                            style: const TextStyle(
                              color: Aityx.muted,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(g.message)),
                          if (g.createdAt != null)
                            Text(
                              g.createdAt!.toLocal().toString().substring(0, 19),
                              style: const TextStyle(color: Aityx.muted, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static List<String> _dependency(Dependency? d) => d == null
      ? const ['…']
      : d.ok
          ? [d.version ?? 'ok']
          : [d.error ?? 'not answering'];

  static String _uptime(Duration d) {
    if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
    if (d.inMinutes > 0) return '${d.inMinutes} min ${d.inSeconds % 60} s';
    return '${d.inSeconds} s';
  }
}

/// One of the status cards: a title, a green or red dot, a few lines.
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.title,
    required this.ok,
    required this.lines,
  });

  final String title;
  final bool ok;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 260,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ok ? Aityx.green : Aityx.red,
                  ),
                ),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in lines)
              Text(
                line,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Aityx.muted, fontSize: 13),
              ),
          ],
        ),
      ),
    ),
  );
}
