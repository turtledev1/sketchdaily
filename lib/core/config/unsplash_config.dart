import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads Unsplash API credentials from a bundled `.env` asset.
///
/// Only [accessKey] is required for public `/photos/random` reads. The
/// application ID and secret key are loaded for future OAuth flows but
/// are not used by v1.
class UnsplashConfig {
  const UnsplashConfig({
    required this.applicationId,
    required this.accessKey,
    required this.secretKey,
  });

  final String applicationId;
  final String accessKey;
  final String secretKey;

  static const String utmSource = 'sketchdaily';
  static const String utmMedium = 'referral';

  static Uri photographerUri(String profileUrl) => Uri.parse('$profileUrl?utm_source=$utmSource&utm_medium=$utmMedium');

  static Uri unsplashHomepageUri() => Uri.parse(
    'https://unsplash.com/?utm_source=$utmSource&utm_medium=$utmMedium',
  );

  factory UnsplashConfig.fromEnv() {
    final accessKey = dotenv.env['UNSPLASH_ACCESS_KEY'];
    if (accessKey == null || accessKey.isEmpty || accessKey == 'YOUR_ACCESS_KEY') {
      throw StateError(
        'UNSPLASH_ACCESS_KEY is missing from .env. Copy .env.example to .env '
        'and fill in your Unsplash credentials from '
        'https://unsplash.com/oauth/applications.',
      );
    }
    return UnsplashConfig(
      applicationId: dotenv.env['UNSPLASH_APPLICATION_ID'] ?? '',
      accessKey: accessKey,
      secretKey: dotenv.env['UNSPLASH_SECRET_KEY'] ?? '',
    );
  }
}
