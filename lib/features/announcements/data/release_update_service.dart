import 'package:flutter/services.dart';

class ReleaseDownloadProgress {
  const ReleaseDownloadProgress({
    required this.bytesReceived,
    required this.totalBytes,
  });

  final int bytesReceived;
  final int totalBytes;

  double? get fraction => totalBytes > 0
      ? (bytesReceived / totalBytes).clamp(0, 1).toDouble()
      : null;
}

class ReleaseUpdateService {
  static const _methods = MethodChannel('aar.ecowell.app/release_update');
  static const _events = EventChannel(
    'aar.ecowell.app/release_update_progress',
  );

  Stream<ReleaseDownloadProgress> get progress =>
      _events.receiveBroadcastStream().map((event) {
        final value = Map<Object?, Object?>.from(event as Map);
        return ReleaseDownloadProgress(
          bytesReceived: value['received']! as int,
          totalBytes: value['total']! as int,
        );
      });

  Future<void> downloadAndInstall(String url) async {
    final uri = Uri.tryParse(url);
    const allowedHosts = {
      'github.com',
      'release-assets.githubusercontent.com',
      'objects.githubusercontent.com',
    };
    if (uri == null ||
        uri.scheme != 'https' ||
        !allowedHosts.contains(uri.host)) {
      throw const FormatException('The APK download link is invalid.');
    }
    await _methods.invokeMethod<void>('downloadAndInstallRelease', {
      'url': uri.toString(),
    });
  }
}
