import 'package:flutter/material.dart';

import 'api/health_hub_api.dart';
import 'app_version.dart';
import 'auth/auth_controller.dart';
import 'theme.dart';
import 'welcome_screen.dart';

void main() {
  runApp(const HealthHubApp());
}

/// HealthHub. Signs the user in the way the API says (GET /api/auth/config)
/// and sends the ID token with every call; the API passes it on to datyx.
class HealthHubApp extends StatefulWidget {
  const HealthHubApp({super.key, this.api, this.auth});

  /// The app's API unless a test says.
  final HealthHubApi? api;

  /// The sign-in, unless a test passes its own.
  final AuthController? auth;

  @override
  State<HealthHubApp> createState() => _HealthHubAppState();
}

class _HealthHubAppState extends State<HealthHubApp> {
  late final AuthController _auth = widget.auth ?? AuthController();
  late final HealthHubApi _api =
      widget.api ?? HttpHealthHubApi(token: _auth.token, refreshToken: _auth.refresh);

  @override
  void initState() {
    super.initState();
    _startAuth();
  }

  /// Asks the API how to sign in, again and again while it doesn't answer
  /// (it may still be starting), backing off up to half a minute, so the
  /// sign-in comes up without a reload once the API is there.
  Future<void> _startAuth() async {
    var delay = const Duration(seconds: 3);
    while (mounted) {
      try {
        final config = await _api.authConfig();
        if (mounted) await _auth.start(config);
        return;
      } catch (_) {
        await Future<void>.delayed(delay);
        if (delay < const Duration(seconds: 30)) delay *= 2;
      }
    }
  }

  @override
  void dispose() {
    if (widget.auth == null) _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: AppVersion.title,
    debugShowCheckedModeBanner: false,
    theme: aityxDarkTheme(),
    home: WelcomeScreen(api: _api, auth: _auth),
  );
}
