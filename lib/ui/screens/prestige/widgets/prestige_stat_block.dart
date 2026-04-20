import 'package:flutter/material.dart';

class PrestigeStatBlock extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;

  const PrestigeStatBlock({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme.textTheme;
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: cs.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: t.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  color: cs.outline,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: t.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
