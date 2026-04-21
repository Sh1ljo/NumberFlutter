import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'logic/game_state.dart';
import 'logic/supabase_service.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/main_layout.dart';
import 'ui/screens/loading_screen.dart';
import 'ui/widgets/auth_session_listener.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await SupabaseService.initialize();
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

class _AppInitializerState extends State<AppInitializer> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeGame();
  }

  Future<void> _initializeGame() async {
    final gameState = context.read<GameState>();
    await Future.wait([
      gameState.ready,
      // Smooth branded loading sequence before entering app.
      Future<void>.delayed(const Duration(milliseconds: 2500)),
    ]);
    if (SupabaseService.instance.currentSession != null) {
      await gameState.syncWithCloud();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const MainLayout();
        }
        return const LoadingScreen();
      },
    );
  }
}
