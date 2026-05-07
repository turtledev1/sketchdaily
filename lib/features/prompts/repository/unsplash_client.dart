import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/unsplash_config.dart';

/// Raw Unsplash photo payload we care about for SketchDaily.
///
/// The `imageUrl` preserves the `ixid` query parameter unchanged, which is
/// required by Unsplash's API guidelines so that hotlinked image requests
/// can be attributed back to the photographer and the app.
class UnsplashPhoto {
  const UnsplashPhoto({
    required this.id,
    required this.imageUrl,
    required this.photographerName,
    required this.photographerProfileUrl,
    required this.downloadLocation,
    required this.description,
  });

  final String id;
  final String imageUrl;
  final String photographerName;
  final String photographerProfileUrl;

  /// URL to ping via `GET` when the photo is "used" (session started).
  /// Required by Unsplash API Guidelines.
  final String downloadLocation;

  final String? description;

  factory UnsplashPhoto.fromJson(Map<String, dynamic> json) {
    final urls = json['urls'] as Map<String, dynamic>? ?? const {};
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    final userLinks = user['links'] as Map<String, dynamic>? ?? const {};
    final links = json['links'] as Map<String, dynamic>? ?? const {};
    return UnsplashPhoto(
      id: json['id'] as String,
      imageUrl: urls['regular'] as String,
      photographerName: user['name'] as String? ?? 'Unknown',
      photographerProfileUrl: userLinks['html'] as String? ?? 'https://unsplash.com',
      downloadLocation: links['download_location'] as String? ?? '',
      description: (json['description'] ?? json['alt_description']) as String?,
    );
  }
}

class UnsplashException implements Exception {
  UnsplashException(this.message);
  final String message;
  @override
  String toString() => 'UnsplashException: $message';
}

class UnsplashClient {
  UnsplashClient({
    required UnsplashConfig config,
    http.Client? httpClient,
  })  : _config = config,
        _http = httpClient ?? http.Client();

  final UnsplashConfig _config;
  final http.Client _http;

  static const String _baseUrl = 'https://api.unsplash.com';
  static const Duration _timeout = Duration(seconds: 10);

  /// Fetches a random photo, filtered by [query] and [orientation].
  Future<UnsplashPhoto> randomPhoto({
    required String query,
    String orientation = 'portrait',
  }) async {
    final uri = Uri.parse('$_baseUrl/photos/random').replace(
      queryParameters: {
        'query': query,
        'orientation': orientation,
        'count': '1',
      },
    );

    final response = await _http.get(uri, headers: _headers).timeout(_timeout);
    if (response.statusCode != 200) {
      throw UnsplashException(
        'Unsplash /photos/random failed (${response.statusCode})',
      );
    }

    // `count=1` returns a list even for a single photo.
    final decoded = jsonDecode(response.body);
    final Map<String, dynamic> photoJson;
    if (decoded is List && decoded.isNotEmpty) {
      photoJson = decoded.first as Map<String, dynamic>;
    } else if (decoded is Map<String, dynamic>) {
      photoJson = decoded;
    } else {
      throw UnsplashException('Unexpected Unsplash response shape');
    }

    return UnsplashPhoto.fromJson(photoJson);
  }

  /// Pings the photo's download-tracking endpoint. Required by Unsplash
  /// Guidelines whenever a photo is "used" (we call this on session start,
  /// not on image load, so we don't log an impression the user never sees).
  /// Errors are swallowed — this is best-effort telemetry for Unsplash, and
  /// a failed ping must not block the user.
  Future<void> trackDownload(String downloadLocation) async {
    if (downloadLocation.isEmpty) return;
    try {
      await _http
          .get(Uri.parse(downloadLocation), headers: _headers)
          .timeout(_timeout);
    } catch (_) {
      // Intentionally ignored.
    }
  }

  Map<String, String> get _headers => {
        'Authorization': 'Client-ID ${_config.accessKey}',
        'Accept-Version': 'v1',
      };

  void dispose() => _http.close();
}
