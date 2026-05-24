import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/spin_screen.dart';
import 'screens/games_screen.dart';
import 'screens/offers_screen.dart';
import 'screens/rewards_screen.dart';
import 'screens/profile_screen.dart';
import 'services/auth_service.dart';
import 'services/coin_service.dart';
import 'services/reward_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Initialize Supabase if available; app works offline without it
  bool supabaseInitialized = false;
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    debugPrint(
        '⚠️ SUPABASE_URL or SUPABASE_ANON_KEY not provided. Pass them via --dart-define or the app will run in offline mode.');
  } else {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      supabaseInitialized = true;
      debugPrint('✅ Supabase initialized: $supabaseUrl');
    } catch (e) {
      debugPrint('❌ Supabase initialization failed: $e');
    }
  }

  final authService = AuthService();
  final coinService = CoinService();
  final rewardService = RewardService();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(
        supabaseEnabled: supabaseInitialized,
        authService: authService,
        coinService: coinService,
        rewardService: rewardService,
      )..load(),
      child: const RbxRewardsApp(),
    ),
  );
}

class RbxRewardsApp extends StatelessWidget {
  const RbxRewardsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RBX Rewards',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF664DFF),
        ),
        fontFamily: 'Inter',
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const AppNavigator(),
    );
  }
}

class AppNavigator extends StatefulWidget {
  const AppNavigator({super.key});

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  int _currentTab = 0;
  bool _showSpin = false;

  Future<void> _onGetStarted() async {
    await context.read<AppState>().setOnboardingCompleted(true);
  }

  void _onNavTap(int index) {
    if (index == 1 && _currentTab == 0) {
      // From home, Spin & Win quick action -> go to Games tab
      setState(() {
        _currentTab = index;
        _showSpin = false;
      });
    } else {
      setState(() {
        _currentTab = index;
        _showSpin = false;
      });
    }
  }

  void _goToSpin() {
    setState(() => _showSpin = true);
  }

  void _backFromSpin() {
    setState(() => _showSpin = false);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (!appState.isLoaded) {
      return const SizedBox.shrink();
    }

    if (!appState.isOnboardingCompleted) {
      return OnboardingScreen(onGetStarted: _onGetStarted);
    }

    if (_showSpin) {
      return SpinScreen(onBack: _backFromSpin);
    }

    final screen = switch (_currentTab) {
      0 => HomeScreen(onNavTap: _onNavTap, onSpinTap: _goToSpin),
      1 => GamesScreen(onNavTap: _onNavTap),
      2 => OffersScreen(onNavTap: _onNavTap),
      3 => RewardsScreen(onNavTap: _onNavTap),
      4 => ProfileScreen(onNavTap: _onNavTap),
      _ => HomeScreen(onNavTap: _onNavTap, onSpinTap: _goToSpin),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_showSpin) {
          _backFromSpin();
          return;
        }
        final shouldQuit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Quit App?'),
            content: const Text('Are you sure you want to exit RBX Rewards?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Quit'),
              ),
            ],
          ),
        );
        if (shouldQuit == true && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: screen,
    );
  }
}
