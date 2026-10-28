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
    _api.authConfig().then(_auth.start).catchError((Object e) {
      // Without the API there is no sign-in either; the screen says so.
    });
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
