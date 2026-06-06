import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rbx_rewards_app/main.dart';
import 'package:rbx_rewards_app/state/app_state.dart';
import 'package:rbx_rewards_app/state/ad_state.dart';
import 'package:rbx_rewards_app/services/auth_service.dart';
import 'package:rbx_rewards_app/services/coin_service.dart';
import 'package:rbx_rewards_app/services/reward_service.dart';
import 'package:rbx_rewards_app/services/ad_service.dart';
import 'package:rbx_rewards_app/services/ad_tracker_service.dart';
import 'package:rbx_rewards_app/services/connectivity_service.dart';

// pure in-memory subclass of AppState for testing to bypass secure storage / network calls
class TestAppState extends AppState {
  TestAppState() : super(
    supabaseEnabled: false,
    authService: AuthService(),
    coinService: CoinService(),
    rewardService: RewardService(),
  );

  bool _mockLoaded = false;
  bool _mockOnboardingCompleted = false;

  @override
  bool get isLoaded => _mockLoaded;

  @override
  bool get isOnboardingCompleted => _mockOnboardingCompleted;

  @override
  Future<void> load() async {
    _mockLoaded = true;
    notifyListeners();
  }

  @override
  Future<void> setOnboardingCompleted(bool value) async {
    _mockOnboardingCompleted = value;
    notifyListeners();
  }
}

void main() {
  testWidgets('App onboarding and navigator smoke test',
      (WidgetTester tester) async {
    final adService = AdService();
    final adTrackerService = AdTrackerService();
    final connectivityService = ConnectivityService();
    final appState = TestAppState();

    // Synchronously mark state as loaded
    await appState.load();

    // Build our app wrapped in providers and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(
            value: appState,
          ),
          ChangeNotifierProvider(
            create: (_) => AdState(
              adService: adService,
              trackerService: adTrackerService,
            ),
          ),
          ChangeNotifierProvider.value(value: connectivityService),
        ],
        child: const RbxRewardsApp(),
      ),
    );

    // Verify that onboarding screen is displayed with the 'Get Started' button.
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Play Games'), findsOneWidget);

    // Tap the 'Get Started' button and trigger a frame.
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // Verify that we navigated to the home screen dashboard or another screen.
    expect(find.text('Get Started'), findsNothing);
  });
}
