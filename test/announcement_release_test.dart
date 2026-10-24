import 'package:flutter_test/flutter_test.dart';
import 'package:ecowell/features/announcements/data/announcement_repository.dart';

void main() {
  group('AnnouncementItem version comparison', () {
    test('detects a newer GitHub release tag', () {
      expect(AnnouncementItem.isNewerVersion('v1.0.1', '1.0.0'), isTrue);
      expect(AnnouncementItem.isNewerVersion('2.0.0', '1.9.9'), isTrue);
    });

    test('does not prompt for the installed version or an older release', () {
      expect(AnnouncementItem.isNewerVersion('v1.0.0', '1.0.0'), isFalse);
      expect(AnnouncementItem.isNewerVersion('v0.9.9', '1.0.0'), isFalse);
    });

    test('ignores malformed tags', () {
      expect(AnnouncementItem.isNewerVersion('latest', '1.0.0'), isFalse);
    });
  });

  test('parses GitHub notes and APK asset', () {
    final release = AnnouncementItem.fromRelease({
      'tag_name': 'v1.2.0',
      'body': 'New features',
      'published_at': '2026-10-24T08:00:00Z',
      'html_url': 'https://github.com/Zeachy25/EcoWellV1/releases/tag/v1.2.0',
      'assets': [
        {
          'name': 'app-release.apk',
          'browser_download_url':
              'https://github.com/Zeachy25/EcoWellV1/releases/download/v1.2.0/app-release.apk',
        },
      ],
    }, currentVersion: '1.0.0');

    expect(release.isUpdate, isTrue);
    expect(release.message, 'New features');
    expect(release.downloadUrl, endsWith('/app-release.apk'));
  });
}
