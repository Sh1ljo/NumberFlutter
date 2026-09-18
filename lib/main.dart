import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'logic/game_state.dart';
import 'logic/backend_service.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/main_layout.dart';
import 'ui/screens/loading_screen.dart';
import 'ui/widgets/auth_session_listener.dart';
import 'ui/widgets/system_loading_indicator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The theme's font variants ship in assets/google_fonts, so never hit the
  // network for them.
  GoogleFonts.config.allowRuntimeFetching = false;
  // The bundled fonts are OFL-licensed, which asks for the licence to ship
  // with them; this lists it on Flutter's licences page.
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in [
      ('Space Grotesk', 'OFL-spacegrotesk.txt'),
      ('Manrope', 'OFL-manrope.txt'),
    ]) {
      final text = await rootBundle.loadString('assets/google_fonts/$file');
      yield LicenseEntryWithLineBreaks(['google_fonts: $family'], text);
    }
  });
  await AppConfig.load();
  // Firebase starts on the loading screen (AppInitializer) rather than here,
  // so the first frame isn't held back by the network.
  runApp(const NumberApp());
}

class NumberApp extends StatelessWidget {
  const NumberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameState(),
      child: MaterialApp(
        title: 'Number',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        builder: (context, child) {
          return AuthSessionListener(child: child ?? const SizedBox.shrink());
        },
        home: const AppInitializer(),
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

enum _BootStep { save, cloud }

class _AppInitializerState extends State<AppInitializer> {
  /// Cloud boot never holds the player back longer than this; past it the
  /// game opens offline and Firebase keeps connecting in the background.
  static const Duration _cloudBootTimeout = Duration(seconds: 4);

  final Map<_BootStep, BootTaskStatus> _status = {
    for (final step in _BootStep.values) step: BootTaskStatus.running,
  };
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  /// Runs the real startup work in parallel. The loading screen shows each
  /// step as it finishes, so it takes exactly as long as the work does.
  Future<void> _boot() async {
    final gameState = context.read<GameState>();
    await Future.wait([
      _track(_BootStep.save, gameState.ready),
      _track(
        _BootStep.cloud,
        BackendService.initialize().timeout(_cloudBootTimeout),
      ),
    ]);
    // Let the bar finish easing to 100% before the screen changes.
    await Future<void>.delayed(SystemLoadingIndicator.progressEase);
    if (!mounted) return;
    setState(() => _ready = true);

    if (BackendService.instance.isSignedIn && gameState.tutorialCompleted) {
      // Sync in background so offline players never get stuck on loading.
      unawaited(gameState.syncWithCloud());
    }
  }

  Future<void> _track(_BootStep step, Future<void> work) async {
    var status = BootTaskStatus.done;
    try {
      await work;
    } catch (_) {
      // Only the cloud step can fail; the game then runs local-only and
      // cloud sync recovers later.
      status = BootTaskStatus.offline;
    }
    if (!mounted) return;
    setState(() => _status[step] = status);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _ready
          ? const MainLayout()
          : LoadingScreen(
              tasks: [
                BootTask(
                  label: 'LOCAL SAVE',
                  status: _status[_BootStep.save]!,
                ),
                BootTask(
                  label: 'CLOUD LINK',
                  status: _status[_BootStep.cloud]!,
                ),
              ],
            ),
    );
  }
}
