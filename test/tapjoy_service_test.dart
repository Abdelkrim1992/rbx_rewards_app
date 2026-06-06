import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Tapjoy SDK and Reporting keys are loaded from environment', () {
    const iosKey = String.fromEnvironment('TAPJOY_SDK_KEY_IOS');
    const androidKey = String.fromEnvironment('TAPJOY_SDK_KEY_ANDROID');
    const reportingKey = String.fromEnvironment('TAPJOY_REPORTING_API_KEY');
    const secretKey = String.fromEnvironment('TAPJOY_SECRET');
    const placementName = String.fromEnvironment('TAPJOY_PLACEMENT_NAME');

    expect(
      iosKey,
      'ltMDYFKBTkeCC88ZRcG4AQECgloxVh5uvM0aA7SB10ErymvuEa2WxpzNoiqc',
      reason: 'TAPJOY_SDK_KEY_IOS should match the configured key in .env',
    );
    expect(
      androidKey,
      'ltMDYFKBTkeCC88ZRcG4AQECgloxVh5uvM0aA7SB10ErymvuEa2WxpzNoiqc',
      reason: 'TAPJOY_SDK_KEY_ANDROID should match the configured key in .env',
    );
    expect(
      reportingKey,
      'YjcyZDdhNDEtZjdmNy00YzVkLWExOTktZjczZTkyZTllNGM1OitZR1dxR1V4RVpMRTV4TEtmK1B1TW5teUc3b1dneC9ReElZZEZ5cU1jWklTS0JSVHRQQVZzeWM3cUkrUHRKQUNGbEVjSEZvQnAzOW84N3BmM1VLSnVBPT0=',
      reason:
          'TAPJOY_REPORTING_API_KEY should match the configured key in .env',
    );
    expect(
      secretKey,
      'SKYkIDICCiEH4afGPXza',
      reason: 'TAPJOY_SECRET should match the secret key in .env',
    );
    expect(
      placementName,
      'Offerwall',
      reason: 'TAPJOY_PLACEMENT_NAME should match the placement name in .env',
    );
  });
}
