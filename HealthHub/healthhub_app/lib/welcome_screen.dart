import 'package:flutter/material.dart';

import 'api/health_hub_api.dart';
import 'app_version.dart';
import 'auth/auth_controller.dart';
import 'auth/sign_in_button.dart';
import 'theme.dart';

/// The one screen so far: the greeting read from the database through the
/// API, addressed to the signed-in user, with where it came from and the
/// API's health; then what datyx makes of the same user, through this
/// API, which passes the user's token on. A button asks again; signing in
/// or out asks again too.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.api, required this.auth});

  final HealthHubApi api;
  final AuthController auth;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late Future<(Greeting, Health)> _loading = _load();
  late Future<_Datyx> _datyx = _loadDatyx();
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_authChanged);
  }

  @override
  void dispose() {
    widget.auth.removeListener(_authChanged);
    super.dispose();
  }

  void _authChanged() {
    if (widget.auth.signedIn != _signedIn) {
      _signedIn = widget.auth.signedIn;
      _reload();
    }
  }

  Future<(Greeting, Health)> _load() async {
    final health = await widget.api.health();
    final greeting = await widget.api.hello();
    return (greeting, health);
  }

  /// What datyx sees, or why it can't be asked.
  Future<_Datyx> _loadDatyx() async {
    final me = await widget.api.datyxMe();
    final sources = await widget.api.datyxDataSources();
    return _Datyx(me, sources);
  }

  void _reload() {
    final loading = _load();
    final datyx = _loadDatyx();
    setState(() {
      _loading = loading;
      _datyx = datyx;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppVersion.title),
        actions: [
          _UserMenu(auth: widget.auth),
          const SizedBox(width: 8),
          IconButton(
            key: const Key('reload'),
            tooltip: 'Ask again',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              shrinkWrap: true,
              children: [
                FutureBuilder<(Greeting, Health)>(
              future: _loading,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _Card(
                    icon: Icons.cloud_off,
                    color: Aityx.red,
                    title: 'No greeting',
                    body:
                        'The API or its database did not answer: '
                        '${snapshot.error}',
                    footer: const Text(
                      'Start them with `devbox services up` in HealthHub/, '
                      'or `docker compose up`.',
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const _Card(
                    icon: Icons.hourglass_empty,
                    color: Aityx.muted,
                    title: 'Asking the API…',
                    body: 'The greeting comes from PostgreSQL, through the API.',
                  );
                }
                final (greeting, health) = snapshot.data!;
                return _Card(
                  icon: Icons.favorite,
                  color: Aityx.orange,
                  title: greeting.message,
                  body:
                      'Read from ${greeting.postgresShort} through the API'
                      '${greeting.since != null ? ', where it has been since ${_date(greeting.since!)}' : ''}.',
                  footer: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Chip('API', ok: health.ok),
                      _Chip('PostgreSQL', ok: health.db),
                      _Chip('aityx key', ok: health.aityx, neutral: true),
                      _Chip(
                        greeting.user == null ? 'sign-in' : 'signed in as ${greeting.user!.label}',
                        ok: greeting.user != null,
                        neutral: !health.auth,
                        state: greeting.user == null
                            ? (health.auth ? 'nobody' : 'off')
                            : '',
                      ),
                    ],
                  ),
                );
              },
            ),
                const SizedBox(height: 16),
                _DatyxCard(datyx: _datyx, auth: widget.auth),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppVersion.version.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'HealthHub ${AppVersion.version}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Aityx.muted,
                ),
              ),
            )
          : null,
    );
  }

  static String _date(DateTime at) {
    final local = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _Card extends StatelessWidget {
  const _Card({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.footer,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Aityx.bg1,
        border: Border.all(color: Aityx.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Aityx.fg0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyLarge),
          if (footer != null) ...[const SizedBox(height: 20), footer!],
        ],
      ),
    );
  }
}

/// What datyx makes of the user, and how many data sources it keeps.
class _Datyx {
  const _Datyx(this.me, this.dataSources);
  final Me me;
  final int dataSources;
}

/// The datyx card: the same user as the datyx API sees them, through this
/// API, which asks datyx with the user's own token, and the data sources
/// datyx keeps.
class _DatyxCard extends StatelessWidget {
  const _DatyxCard({required this.datyx, required this.auth});

  final Future<_Datyx> datyx;
  final AuthController auth;

  @override
  Widget build(BuildContext context) => FutureBuilder<_Datyx>(
    future: datyx,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        final error = snapshot.error;
        final signIn = error is ApiException && error.status == 401;
        return _Card(
          icon: signIn ? Icons.lock_outline : Icons.cloud_off,
          color: signIn ? Aityx.muted : Aityx.red,
          title: 'datyx',
          body: signIn
              ? 'Sign in to reach datyx as yourself: HealthHub passes your token on.'
              : 'datyx did not answer through the API: $error',
        );
      }
      if (!snapshot.hasData) {
        return const _Card(
          icon: Icons.hourglass_empty,
          color: Aityx.muted,
          title: 'datyx',
          body: 'Asking datyx, through the API…',
        );
      }
      final d = snapshot.data!;
      return _Card(
        key: const Key('datyx-card'),
        icon: Icons.hub_outlined,
        color: Aityx.green,
        title: 'datyx',
        body: d.me.authenticated
            ? 'datyx sees you as ${d.me.email ?? d.me.label}: the token HealthHub '
                'got from your sign-in went on to the datyx API unchanged.'
            : 'datyx answers anonymously: authentication is off there.',
        footer: Text(
          '${d.dataSources} data source${d.dataSources == 1 ? '' : 's'} on record in datyx',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    },
  );
}

/// The app bar's account corner: nothing while the API has authentication
/// off; the sign-in button while nobody is signed in; the user's picture,
/// name and a sign-out button once someone is.
class _UserMenu extends StatelessWidget {
  const _UserMenu({required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: auth,
    builder: (context, _) {
      if (!auth.enabled) return const SizedBox.shrink();
      final user = auth.user;
      if (user == null) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (auth.error != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Tooltip(
                  message: auth.error!,
                  child: const Icon(Icons.error_outline, color: Aityx.red, size: 18),
                ),
              ),
            if (auth.ready) GoogleSignInButton(auth: auth),
          ],
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (user.picture != null)
            CircleAvatar(radius: 14, backgroundImage: NetworkImage(user.picture!))
          else
            const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
          const SizedBox(width: 8),
          Text(user.label, style: const TextStyle(fontSize: 13)),
          IconButton(
            tooltip: 'Sign out',
            onPressed: auth.signOut,
            icon: const Icon(Icons.logout, size: 18),
          ),
        ],
      );
    },
  );
}

/// A service and whether it answers: green when it does, red when it
/// doesn't, or gray when [neutral] (missing, but nothing is broken).
/// [state] replaces the "ok", "down" or "not set" word when given.
class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.ok, this.neutral = false, this.state});

  final String label;
  final bool ok;
  final bool neutral;
  final String? state;

  @override
  Widget build(BuildContext context) {
    final color = ok ? Aityx.green : (neutral ? Aityx.muted : Aityx.red);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Aityx.bg2,
        border: Border.all(color: Aityx.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 6),
          Text(
            state == null
                ? '$label ${ok ? 'ok' : (neutral ? 'not set' : 'down')}'
                : '$label${state!.isEmpty ? '' : ' $state'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
