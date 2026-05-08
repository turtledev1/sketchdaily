import '../../../core/config/unsplash_config.dart';
import 'unsplash_client.dart';

/// A reference image prompt ready to be shown to the user.
class ImagePrompt {
  const ImagePrompt({
    required this.photoId,
    required this.imageUrl,
    required this.photographerName,
    required this.photographerProfileUrl,
    required this.downloadLocation,
    this.description,
  });

  final String photoId;
  final String imageUrl;
  final String photographerName;
  final String photographerProfileUrl;
  final String downloadLocation;
  final String? description;

  /// Unsplash attribution link per their brand guidelines
  /// (https://help.unsplash.com/en/articles/2511315-guideline-attribution).
  Uri unsplashAttributionUri() => UnsplashConfig.unsplashHomepageUri();

  Uri photographerUri() => UnsplashConfig.photographerUri(photographerProfileUrl);
}

class PromptRepository {
  PromptRepository({required UnsplashClient client}) : _client = client;

  final UnsplashClient _client;

  /// Curated queries for drawing practice. Picked deterministically by day
  /// so the user sees variety without jarring RNG.
  static const List<String> allCategories = [
    'portrait',
    'still life',
    'landscape',
    'animal',
    'hands',
    'architecture',
    'flower',
    'fruit',
    'trees',
    'shells',
    'cups',
  ];

  Future<ImagePrompt> getTodayPrompt({
    DateTime? now,
    List<String>? enabledCategories,
  }) async {
    final date = now ?? DateTime.now();
    final pool = (enabledCategories == null || enabledCategories.isEmpty) ? allCategories : enabledCategories;
    final query = pool[_dayOfYear(date) % pool.length];
    final photo = await _client.randomPhoto(query: query);
    return ImagePrompt(
      photoId: photo.id,
      imageUrl: photo.imageUrl,
      photographerName: photo.photographerName,
      photographerProfileUrl: photo.photographerProfileUrl,
      downloadLocation: photo.downloadLocation,
      description: photo.description,
    );
  }

  /// Best-effort ping of Unsplash's download-tracking endpoint. Call this
  /// when the user actually starts the session (image is being used), not
  /// on prefetch. See Unsplash API Guidelines.
  Future<void> trackUsage(ImagePrompt prompt) => _client.trackDownload(prompt.downloadLocation);

  static int _dayOfYear(DateTime date) {
    final startOfYear = DateTime(date.year);
    return date.difference(startOfYear).inDays;
  }
}
