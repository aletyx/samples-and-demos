import 'package:flutter/material.dart';

import 'app_version.dart';
import 'request/voice_input.dart';
import 'theme.dart';
import 'welcome/welcome_screen.dart';

export 'request/request_box.dart' show RequestBox;
export 'welcome/welcome_screen.dart' show WelcomeScreen;

void main() {
  runApp(const ContactHubApp());
}

class ContactHubApp extends StatelessWidget {
  const ContactHubApp({super.key, this.voice});

  /// Dictation in the request box: the browser's unless a test says.
  final VoiceInput? voice;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppVersion.title,
      debugShowCheckedModeBanner: false,
      theme: aityxDarkTheme(),
      home: WelcomeScreen(voice: voice),
    );
  }
}
