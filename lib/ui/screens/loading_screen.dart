import 'package:flutter/material.dart';

import '../widgets/system_loading_indicator.dart';

enum BootTaskStatus { running, done, offline }

/// One real piece of startup work shown on the loading screen.
class BootTask {
  const BootTask({required this.label, required this.status});

  final String label;
  final BootTaskStatus status;

  bool get finished => status != BootTaskStatus.running;
}

/// Startup screen. The progress bar and checklist reflect the actual boot
/// work in [tasks]; nothing here is timed.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, this.tasks = const []});

  final List<BootTask> tasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finished = tasks.where((task) => task.finished).length;
    final progress = tasks.isEmpty ? null : finished / tasks.length;

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
            SystemLoadingIndicator(progress: progress),
            const SizedBox(height: 20),
            SizedBox(
              width: 208,
              child: Column(
                children: [
                  for (final task in tasks) _BootTaskRow(task: task),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BootTaskRow extends StatelessWidget {
  const _BootTaskRow({required this.task});

  final BootTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    final (String state, Color color) = switch (task.status) {
      BootTaskStatus.running => ('...', outline.withValues(alpha: 0.6)),
      BootTaskStatus.done => ('OK', theme.colorScheme.primary),
      BootTaskStatus.offline => ('OFFLINE', outline),
    };
    final style = theme.textTheme.labelSmall?.copyWith(
      fontSize: 9,
      letterSpacing: 2.0,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            task.label,
            style: style?.copyWith(
              color: task.finished ? outline : outline.withValues(alpha: 0.6),
            ),
          ),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              state,
              key: ValueKey(state),
              style: style?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
