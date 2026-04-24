import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final List<GlobalKey?>? itemKeys;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    this.itemKeys,
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
          for (var i = 0; i < 5; i++)
            Expanded(
              child: _NavItem(
                key: itemKeys != null && i < itemKeys!.length
                    ? itemKeys![i]
                    : null,
                icon: _navIcon(i),
                label: _navLabel(i),
                isActive: currentIndex == i,
                onTap: () => onIndexChanged(i),
              ),
            ),
        ],
      ),
    );
  }
}

IconData _navIcon(int i) {
  switch (i) {
    case 0:
      return Icons.memory;
    case 1:
      return Icons.trending_up;
    case 2:
      return Icons.auto_awesome;
    case 3:
      return Icons.leaderboard;
    default:
      return Icons.more_horiz;
  }
}

String _navLabel(int i) {
  switch (i) {
    case 0:
      return 'GENERATORS';
    case 1:
      return 'UPGRADES';
    case 2:
      return 'PRESTIGE';
    case 3:
      return 'RANKS';
    default:
      return 'MORE';
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
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
