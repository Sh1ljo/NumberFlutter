import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/game_state.dart';
import '../widgets/app_background.dart';
import '../widgets/offline_gains_dialog.dart';
import 'main_game_screen.dart';
import 'upgrades_screen.dart';
import 'prestige/prestige_screen.dart';
import 'settings_screen.dart';
import '../widgets/bottom_nav_bar.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  bool _offlineDialogQueued = false;

  final List<Widget> _screens = [
    const MainGameScreen(),
    const UpgradesScreen(),
    const PrestigeScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isPrestigeAnimating =
        context.select<GameState, bool>((gs) => gs.isPrestigeAnimating);
    final offlineGains = context.select<GameState, BigInt>(
      (gs) => gs.offlineGainsThisSession,
    );

    if (offlineGains > BigInt.zero && !_offlineDialogQueued) {
      _offlineDialogQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        OfflineGainsDialog.show(
          context,
          offlineGains,
          onAcknowledge: () {
            if (!mounted) return;
            context.read<GameState>().clearOfflineGains();
          },
        );
      });
    } else if (offlineGains == BigInt.zero && _offlineDialogQueued) {
      _offlineDialogQueued = false;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: Stack(
          children: [
            _screens[_currentIndex],
            if (!isPrestigeAnimating)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: BottomNavBar(
                  currentIndex: _currentIndex,
                  onIndexChanged: (index) {
                    if (index == _currentIndex) return;
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
