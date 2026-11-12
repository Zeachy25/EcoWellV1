import 'config.dart';

String? pendingDeepLink;

String? postRouteFromUri(Uri uri) {
  if (uri.scheme != 'https') return null;

  final configured = Uri.tryParse(kShareBaseUrl);
  final host = configured?.host;
  if (host == null || host.isEmpty || uri.host != host) return null;

  final segments = uri.pathSegments;
  if (segments.length != 2 || segments.first != 'post') return null;

  final id = segments.last.trim();
  if (id.isEmpty) return null;
  return '/post/$id';
}

String? consumePendingDeepLink() {
  final route = pendingDeepLink;
  pendingDeepLink = null;
  return route;
}
