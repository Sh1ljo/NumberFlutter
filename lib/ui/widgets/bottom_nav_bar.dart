import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final List<GlobalKey?>? itemKeys;

  /// Shows a small dot on the PRESTIGE item — something is waiting there
  /// (e.g. an artifact choice) even while the player is on another tab.
  final bool showPrestigeBadge;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    this.itemKeys,
    this.showPrestigeBadge = false,
  });

  /// Height of the bar's own chrome, excluding any system inset.
  ///
  /// The bar is laid out as a `Positioned(bottom: 0)` sibling **on top of**
  /// the active screen, so screens do not automatically lose this space.
  /// [MainLayout] adds it to the screens' `MediaQuery` bottom padding — without
  /// that, anything centring itself in its own viewport (the neural canvas
  /// most visibly) centres into a region ~85px taller than what the player
  /// can actually see, and the bottom of tall content hides behind the bar.
  static const double chromeHeight = _itemHeight + _verticalPadding * 2 + 1;

  static const double _itemHeight = 56;
  static const double _verticalPadding = 14;

  /// Total space the bar occupies, including the bottom system inset it pads
  /// itself by (gesture bar, home indicator).
  static double totalHeight(BuildContext context) =>
      chromeHeight + MediaQuery.of(context).viewPadding.bottom;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
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
      padding: EdgeInsets.fromLTRB(
        12,
        _verticalPadding,
        12,
        _verticalPadding + safeBottom,
      ),
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
                showBadge: i == 2 && showPrestigeBadge,
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
      return Icons.share_outlined;
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
      return 'NEURAL';
    default:
      return 'MORE';
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool showBadge;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    this.showBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        isActive ? theme.colorScheme.primary : theme.colorScheme.outlineVariant;
    final scale = isActive ? 1.1 : 1.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: BottomNavBar._itemHeight,
        width: double.infinity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          transform: Matrix4.identity()..scale(scale),
          transformAlignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: color, size: 22),
                  if (showBadge)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
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
