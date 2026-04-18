import 'package:http/http.dart' as http;

/// Fetches MusicXML files from Google Cloud Storage (or any public URL).
class CloudService {
  /// Downloads a MusicXML file from the given [url].
  ///
  /// For Google Cloud Storage, [url] should be a public object URL:
  ///   https://storage.googleapis.com/BUCKET_NAME/OBJECT_PATH
  ///
  /// Returns the raw XML string on success, throws on failure.
  Future<String> fetchXml(String url) async {
    final uri = Uri.parse(url);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return response.body;
    }
    throw HttpException(
      'Failed to fetch file: HTTP ${response.statusCode}',
      uri: uri,
    );
  }

  /// Validates whether a URL looks like a Google Cloud Storage URL.
  static bool isGcsUrl(String url) {
    final lower = url.toLowerCase();
    return lower.startsWith('https://storage.googleapis.com/') ||
        lower.startsWith('gs://');
  }

  /// Converts a gs:// URL to an https:// URL.
  static String gsToHttps(String gsUrl) {
    if (!gsUrl.startsWith('gs://')) return gsUrl;
    final withoutScheme = gsUrl.substring(5);
    final slashIndex = withoutScheme.indexOf('/');
    if (slashIndex < 0) return gsUrl;
    final bucket = withoutScheme.substring(0, slashIndex);
    final path = withoutScheme.substring(slashIndex + 1);
    return 'https://storage.googleapis.com/$bucket/$path';
  }
}

class HttpException implements Exception {
  final String message;
  final Uri? uri;
  const HttpException(this.message, {this.uri});

  @override
  String toString() => uri != null ? '$message (${uri!})' : message;
}
