import 'package:flutter/material.dart';

class MoreMenuScreen extends StatelessWidget {
  final Function(int) onMenuItemSelected;

  const MoreMenuScreen({
    super.key,
    required this.onMenuItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MORE',
                style: theme.textTheme.displayLarge?.copyWith(fontSize: 48),
              ),
              const SizedBox(height: 28),
              _MenuItem(
                title: 'Shop',
                description: 'Unlock boosts and upgrades',
                icon: Icons.storefront_outlined,
                onTap: () => onMenuItemSelected(4), // Shop index
                theme: theme,
              ),
              const SizedBox(height: 12),
              _MenuItem(
                title: 'Settings',
                description: 'Customize your experience',
                icon: Icons.settings_outlined,
                onTap: () => onMenuItemSelected(5), // Settings index
                theme: theme,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final ThemeData theme;

  const _MenuItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow.withValues(alpha: 0.55),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: cs.outlineVariant,
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                size: 22,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.outline,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_outlined,
              size: 18,
              color: cs.outline,
            ),
          ],
        ),
      ),
    );
  }
}
