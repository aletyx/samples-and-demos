import 'package:flutter/material.dart';

import 'api/datyx_api.dart';
import 'app_version.dart';
import 'auth/auth_controller.dart';
import 'dashboard/dashboard_screen.dart';
import 'theme.dart';

void main() {
  runApp(const DatyxDashApp());
}

/// The datyx dashboard: shows what the API answers. The logic and the
/// data live in the API (datyx/); this app only asks and shows. It signs
/// the user in the way the API says (GET /api/auth/config) and sends the ID
/// token with every call.
class DatyxDashApp extends StatefulWidget {
  const DatyxDashApp({super.key, this.api, this.auth});

  /// The API, unless a test passes a fake.
  final DatyxApi? api;

  /// The sign-in, unless a test passes its own.
  final AuthController? auth;

  @override
  State<DatyxDashApp> createState() => _DatyxDashAppState();
}

class _DatyxDashAppState extends State<DatyxDashApp> {
  late final AuthController _auth = widget.auth ?? AuthController();
  late final DatyxApi _api =
      widget.api ?? HttpDatyxApi(token: _auth.token, refreshToken: _auth.refresh);

  @override
  void initState() {
    super.initState();
    _api.authConfig().then(_auth.start).catchError((Object e) {
      // Without the API there is no sign-in either; the screen shows the
      // API's absence.
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
    home: DashboardScreen(api: _api, auth: _auth),
  );
}
