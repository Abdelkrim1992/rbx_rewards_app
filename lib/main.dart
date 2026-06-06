import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/loading_screen.dart';
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
import 'services/ad_service.dart';
import 'services/ad_tracker_service.dart';
import 'services/lucky_bonus_service.dart';
import 'services/connectivity_service.dart';
import 'services/tapjoy_service.dart';
import 'state/app_state.dart';
import 'state/ad_state.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'widgets/quit_confirmation_dialog.dart';

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
  final adService = AdService();
  final adTrackerService = AdTrackerService();
  final connectivityService = ConnectivityService()..startListening();
  LuckyBonusService()..load();
  TapjoyService()..initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppState(
            supabaseEnabled: supabaseInitialized,
            authService: authService,
            coinService: coinService,
            rewardService: rewardService,
          )..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => AdState(
            adService: adService,
            trackerService: adTrackerService,
          )..initialize(),
        ),
        ChangeNotifierProvider.value(value: connectivityService),
      ],
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
      builder: (context, child) {
        return Container(
          color: const Color(
              0xFFF0F0F0), // Subtle background color outside the app area
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: ClipRect(child: child),
            ),
          ),
        );
      },
      home: const AppNavigator(),
    );
  }
}

class AppNavigator extends StatefulWidget {
  const AppNavigator({super.key});

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator>
    with WidgetsBindingObserver {
  int _currentTab = 0;
  bool _showSpin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App lifecycle tracking can be handled here if needed in the future
  }

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
      return const LoadingScreen();
    }

    Widget destination;
    if (!appState.isOnboardingCompleted) {
      destination = OnboardingScreen(
        key: const ValueKey('onboarding'),
        onGetStarted: _onGetStarted,
      );
    } else if (_showSpin) {
      destination = SpinScreen(
        key: const ValueKey('spin'),
        onBack: _backFromSpin,
      );
    } else {
      final screen = switch (_currentTab) {
        0 => HomeScreen(onNavTap: _onNavTap, onSpinTap: _goToSpin),
        1 => GamesScreen(onNavTap: _onNavTap),
        2 => OffersScreen(onNavTap: _onNavTap),
        3 => RewardsScreen(onNavTap: _onNavTap),
        4 => ProfileScreen(onNavTap: _onNavTap),
        _ => HomeScreen(onNavTap: _onNavTap, onSpinTap: _goToSpin),
      };
      destination = PopScope(
        key: ValueKey('tab_$_currentTab'),
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (_showSpin) {
            _backFromSpin();
            return;
          }
          final shouldQuit = await showQuitConfirmationDialog(
            context,
            title: 'Quit App?',
            message: 'Are you sure you want to exit RBX Rewards?',
          );
          if (shouldQuit && mounted) {
            if (!kIsWeb && Platform.isAndroid) {
              SystemNavigator.pop();
            } else if (!kIsWeb) {
              Navigator.of(context).pop();
            }
          }
        },
        child: screen,
      );
    }

    // Return directly without the forced loading overlay
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: destination,
    );
  }
}
