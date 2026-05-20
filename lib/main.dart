import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/spin_screen.dart';
import 'screens/games_screen.dart';
import 'screens/offers_screen.dart';
import 'screens/rewards_screen.dart';
import 'screens/profile_screen.dart';
import 'state/app_state.dart';

void main() {
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

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..load(),
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

    switch (_currentTab) {
      case 0:
        return HomeScreen(
          onNavTap: _onNavTap,
          onSpinTap: _goToSpin,
        );
      case 1:
        return GamesScreen(onNavTap: _onNavTap);
      case 2:
        return OffersScreen(onNavTap: _onNavTap);
      case 3:
        return RewardsScreen(onNavTap: _onNavTap);
      case 4:
        return ProfileScreen(onNavTap: _onNavTap);
      default:
        return HomeScreen(
          onNavTap: _onNavTap,
          onSpinTap: _goToSpin,
        );
    }
  }
}
