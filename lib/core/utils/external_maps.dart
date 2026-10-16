import 'package:url_launcher/url_launcher.dart';

/// Fallback: opens the Google Maps app with walking directions.
/// Returns false if it could not be opened.
Future<bool> openGoogleMapsDirections(double lat, double lng) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=$lat,$lng&travelmode=walking',
  );
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
