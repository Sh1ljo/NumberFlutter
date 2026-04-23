import 'package:flutter/material.dart';

import '../widgets/system_loading_indicator.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'NUMBER',
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 52,
                letterSpacing: 10,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'INITIALIZING SYSTEM',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                letterSpacing: 2.0,
                color: theme.colorScheme.outline.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 64),
            const SystemLoadingIndicator(),
          ],
        ),
      ),
    );
  }
}
