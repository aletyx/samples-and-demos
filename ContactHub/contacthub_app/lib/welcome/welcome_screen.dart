import 'package:flutter/material.dart';

import '../app_version.dart';
import '../hello/greeting.dart';
import '../hello/hello_screen.dart';

/// The app's home: the name, a one-line welcome, the button to the Hello
/// page and, when the build sets it, the version.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.greeter});

  /// Passed on to the Hello page.
  final Greeter? greeter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.forum_outlined,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to Contact Hub',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ask anything, and we get it to the right person.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => HelloScreen(greeter: greeter),
                      ),
                    ),
                    icon: const Icon(Icons.waving_hand_outlined),
                    label: const Text('Say hello'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                  if (AppVersion.version.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Text(
                      AppVersion.version,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
