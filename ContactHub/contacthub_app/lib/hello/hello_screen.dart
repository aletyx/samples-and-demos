import 'package:flutter/material.dart';

import 'greeting.dart';

/// The scaffolding check: "Hello, world!" from the app itself, then the
/// API's greeting, which shows the app reaches the API.
class HelloScreen extends StatefulWidget {
  const HelloScreen({super.key, this.greeter});

  /// Fetches the API's greeting: the app's API unless a test says.
  final Greeter? greeter;

  @override
  State<HelloScreen> createState() => _HelloScreenState();
}

class _HelloScreenState extends State<HelloScreen> {
  late final Greeter _greeter = widget.greeter ?? ApiGreeter();
  late Future<String> _greeting = _greeter.greet();

  void _retry() => setState(() {
    _greeting = _greeter.greet();
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Hello')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Hello, world!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FutureBuilder<String>(
                    future: _greeting,
                    builder: (context, snapshot) => switch (snapshot) {
                      AsyncSnapshot(:final data?) => _ApiLine(
                        icon: Icons.check_circle_outline,
                        color: theme.colorScheme.secondary,
                        text: data,
                      ),
                      AsyncSnapshot(:final error?) => Column(
                        children: [
                          _ApiLine(
                            icon: Icons.error_outline,
                            color: theme.colorScheme.error,
                            text: '$error',
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _retry,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                      _ => const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One line about the API: an icon in the result's color, then the text.
class _ApiLine extends StatelessWidget {
  const _ApiLine({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}
