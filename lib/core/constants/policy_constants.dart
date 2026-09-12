import 'package:url_launcher/url_launcher.dart';

/// Centralized configuration for legal policies, store requirements,
/// and external web links for RBX Rewards.
class PolicyConstants {
  PolicyConstants._();

  static const String appName = 'RBX Rewards';
  static const String appVersion = '1.2.0';
  static const String founder = 'Abdelkrim Salaghe';
  static const String coFounder = 'Youssef';
  static const String copyright = 'Copyright © 2024-2026 Abdelkrim Salaghe & Youssef. All rights reserved.';
  static const String authorshipStatement =
      'Created and engineered by Abdelkrim Salaghe (Founder & Lead Developer) with Youssef (Co-Founder & Publishing Partner).';

  static const String baseWebsiteUrl = 'https://rbxrewardsapp.netlify.app';
  static const String privacyPolicyUrl = '$baseWebsiteUrl/privacy.html';
  static const String termsOfUseUrl = '$baseWebsiteUrl/terms.html';
  static const String rewardsPolicyUrl = '$baseWebsiteUrl/rewards-policy.html';
  static const String helpSupportUrl = '$baseWebsiteUrl/help.html';
  static const String disclaimerUrl = '$baseWebsiteUrl/disclaimer.html';
  static const String dataDeletionUrl = '$baseWebsiteUrl/data-deletion.html';
  static const String contactSupportUrl = '$baseWebsiteUrl/contact.html';
  static const String supportEmail = 'themimo18@gmail.com';

  /// Opens the requested policy or terms URL in the external browser.
  static Future<bool> openUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Dispatches a pre-formatted email to the support team.
  static Future<bool> sendSupportEmail({String subject = 'RBX Rewards Support Inquiry'}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {'subject': subject},
    );
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }
}
