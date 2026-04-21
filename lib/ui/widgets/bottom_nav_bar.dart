import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE6131313), // #131313 at 90% opacity
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.memory,
              label: 'GENERATORS',
              isActive: currentIndex == 0,
              onTap: () => onIndexChanged(0),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.trending_up,
              label: 'UPGRADES',
              isActive: currentIndex == 1,
              onTap: () => onIndexChanged(1),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.auto_awesome,
              label: 'PRESTIGE',
              isActive: currentIndex == 2,
              onTap: () => onIndexChanged(2),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.leaderboard,
              label: 'RANKS',
              isActive: currentIndex == 3,
              onTap: () => onIndexChanged(3),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.settings,
              label: 'SYSTEM',
              isActive: currentIndex == 4,
              onTap: () => onIndexChanged(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive ? theme.colorScheme.primary : theme.colorScheme.outlineVariant;
    final scale = isActive ? 1.1 : 1.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          transform: Matrix4.identity()..scale(scale),
          transformAlignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontSize: 9,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
