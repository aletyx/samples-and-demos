import 'package:flutter/material.dart';

import 'app_version.dart';
import 'hello/greeting.dart';
import 'request/voice_input.dart';
import 'theme.dart';
import 'welcome/welcome_screen.dart';

export 'hello/hello_screen.dart' show HelloScreen;
export 'request/request_box.dart' show RequestBox;
export 'welcome/welcome_screen.dart' show WelcomeScreen;

void main() {
  runApp(const ContactHubApp());
}

class ContactHubApp extends StatelessWidget {
  const ContactHubApp({super.key, this.greeter, this.voice});

  /// Fetches the Hello page's greeting: the app's API unless a test says.
  final Greeter? greeter;

  /// Dictation in the request box: the browser's unless a test says.
  final VoiceInput? voice;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppVersion.title,
      debugShowCheckedModeBanner: false,
      theme: aityxDarkTheme(),
      home: WelcomeScreen(greeter: greeter, voice: voice),
    );
  }
}
