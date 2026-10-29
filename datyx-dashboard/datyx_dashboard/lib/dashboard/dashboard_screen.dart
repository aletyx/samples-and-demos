import 'dart:async';

import 'package:flutter/material.dart';

import '../api/datyx_api.dart';
import '../app_version.dart';
import '../auth/auth_controller.dart';
import 'calls_panel.dart';
import 'data_sources_card.dart';
import 'health_tab.dart';
import 'user_menu.dart';

/// The dashboard, in three tabs: Data sources, the ones on record; Health,
/// the system's status as the API reports it and this build's version;
/// Audit, every call made to the API. Refreshes the status and the data
/// sources every [refreshEvery]. With authentication on, the data sources
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
  List<DataSource> _sources = const [];
  Me? _me;
  bool _busy = false;
  bool _signedIn = false;
  Timer? _timer;

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
        // The call is in the audit; the list keeps what it had.
      }
    }
    if (widget.auth.enabled && widget.auth.signedIn && _me == null) {
      try {
        final me = await widget.api.me();
        if (mounted) setState(() => _me = me);
      } catch (_) {
        // In the audit.
      }
    }
    if (mounted) setState(() => _busy = false);
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
    final log = widget.api.log;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppVersion.title),
          actions: [
            UserMenu(auth: widget.auth),
            const SizedBox(width: 12),
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kTextTabBarHeight),
            // The Audit tab counts the calls as they happen.
            child: ListenableBuilder(
              listenable: log,
              builder: (context, _) => TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.only(left: 4),
                tabs: [
                  const Tab(key: Key('tab-sources'), text: 'Data sources'),
                  const Tab(key: Key('tab-health'), text: 'Health'),
                  Tab(key: const Key('tab-audit'), text: 'Audit (${log.calls.length})'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_statusError != null) ApiDownLine(_statusError!),
                DataSourcesCard(
                  sources: _sources,
                  locked: _locked,
                  onAdd: _addSource,
                  onRemove: _removeSource,
                ),
              ],
            ),
            HealthTab(
              status: _status,
              statusError: _statusError,
              auth: widget.auth,
              me: _me,
              refreshEvery: widget.refreshEvery,
            ),
            CallsPanel(log: log),
          ],
        ),
      ),
    );
  }
}
