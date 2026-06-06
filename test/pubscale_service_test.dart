import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PubScale App ID and Secret are loaded from environment', () {
    const appId = String.fromEnvironment('PUBSCALE_APP_ID');
    const secret = String.fromEnvironment('PUBSCALE_SECRET');

    expect(
      appId,
      '15742041',
      reason: 'PUBSCALE_APP_ID should match the configured App ID in .env',
    );
    expect(
      secret,
      '8dfb619a-7ede-4486-8e3c-b82885f3dda3',
      reason: 'PUBSCALE_SECRET should match the configured secret in .env',
    );
  });
}
