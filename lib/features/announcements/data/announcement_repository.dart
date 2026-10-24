import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnnouncementItem {
  const AnnouncementItem({
    required this.id,
    required this.title,
    required this.message,
    required this.publishedAt,
    required this.source,
    this.linkUrl,
    this.downloadUrl,
    this.versionTag,
    this.isUpdate = false,
  });

  final String id;
  final String title;
  final String message;
  final DateTime publishedAt;
  final String source;
  final String? linkUrl;
  final String? downloadUrl;
  final String? versionTag;
  final bool isUpdate;

  factory AnnouncementItem.fromSupabase(Map<String, dynamic> json) {
    final publishedAt = DateTime.tryParse(
      json['published_at'] as String? ?? '',
    )?.toLocal();
    return AnnouncementItem(
      id: 'announcement:${json['id']}',
      title: json['title'] as String,
      message: json['message'] as String,
      publishedAt: publishedAt ?? DateTime.now(),
      source: 'EcoWell',
      linkUrl: json['link_url'] as String?,
    );
  }

  factory AnnouncementItem.fromRelease(
    Map<String, dynamic> json, {
    required String currentVersion,
  }) {
    final tag = json['tag_name'] as String? ?? '';
    final assets = json['assets'] as List<dynamic>? ?? const [];
    String? apkUrl;
    for (final asset in assets) {
      if (asset is Map<String, dynamic> &&
          (asset['name'] as String? ?? '').toLowerCase().endsWith('.apk')) {
        apkUrl = asset['browser_download_url'] as String?;
        if (apkUrl != null) break;
      }
    }

    final releaseUrl = json['html_url'] as String?;
    return AnnouncementItem(
      id: 'release:$tag',
      title: 'EcoWell $tag is available',
      message: (json['body'] as String?)?.trim().isNotEmpty == true
          ? (json['body'] as String).trim()
          : 'See the release details and download the latest APK.',
      publishedAt:
          DateTime.tryParse(json['published_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      source: 'GitHub Release',
      linkUrl: releaseUrl,
      downloadUrl: apkUrl,
      versionTag: tag,
      isUpdate: isNewerVersion(tag, currentVersion),
    );
  }

  static bool isNewerVersion(String releaseTag, String currentVersion) {
    final release = _versionParts(releaseTag);
    final current = _versionParts(currentVersion);
    if (release == null || current == null) return false;

    final length = release.length > current.length
        ? release.length
        : current.length;
    for (var i = 0; i < length; i++) {
      final releasePart = i < release.length ? release[i] : 0;
      final currentPart = i < current.length ? current[i] : 0;
      if (releasePart != currentPart) return releasePart > currentPart;
    }
    return false;
  }

  static List<int>? _versionParts(String value) {
    final normalized = value.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final match = RegExp(r'^(\d+(?:\.\d+)*)(?:\+\d+)?$').firstMatch(normalized);
    if (match == null) return null;
    return match
        .group(1)!
        .split('.')
        .map(int.tryParse)
        .whereType<int>()
        .toList();
  }
}

class AnnouncementRepository {
  AnnouncementRepository({SupabaseClient? supabase, http.Client? httpClient})
    : _supabase = supabase ?? Supabase.instance.client,
      _http = httpClient ?? http.Client(),
      _ownsHttpClient = httpClient == null;

  static const _githubLatestRelease =
      'https://api.github.com/repos/Zeachy25/EcoWellV1/releases/latest';
  static const _readItemsKey = 'read_announcement_ids';
  static const _promptedReleaseKey = 'prompted_release_tag';

  final SupabaseClient _supabase;
  final http.Client _http;
  final bool _ownsHttpClient;

  Future<List<AnnouncementItem>> fetchAnnouncements() async {
    final rows = await _supabase
        .from('announcements')
        .select('id, title, message, link_url, published_at')
        .eq('published', true)
        .order('published_at', ascending: false)
        .limit(50);
    return [
      for (final row in rows)
        AnnouncementItem.fromSupabase(Map<String, dynamic>.from(row)),
    ];
  }

  Stream<List<AnnouncementItem>> watchAnnouncements() {
    return _supabase
        .from('announcements')
        .stream(primaryKey: ['id'])
        .eq('published', true)
        .order('published_at', ascending: false)
        .limit(50)
        .map(
          (rows) => [
            for (final row in rows)
              AnnouncementItem.fromSupabase(Map<String, dynamic>.from(row)),
          ],
        );
  }

  Future<AnnouncementItem?> fetchLatestRelease({
    required String currentVersion,
  }) async {
    final response = await _http
        .get(
          Uri.parse(_githubLatestRelease),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
            'User-Agent': 'EcoWell-Android-App',
          },
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw http.ClientException(
        'GitHub Releases returned HTTP ${response.statusCode}.',
        Uri.parse(_githubLatestRelease),
      );
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('GitHub returned an invalid release.');
    }
    return AnnouncementItem.fromRelease(data, currentVersion: currentVersion);
  }

  Future<Set<String>> readAnnouncementIds() async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_readItemsKey) ?? const <String>[])
        .toSet();
  }

  Future<void> markAnnouncementsRead(Iterable<String> ids) async {
    final preferences = await SharedPreferences.getInstance();
    final read = await readAnnouncementIds();
    read.addAll(ids);
    await preferences.setStringList(_readItemsKey, read.toList());
  }

  Future<bool> shouldPromptForRelease(String? tag) async {
    if (tag == null || tag.isEmpty) return false;
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getString(_promptedReleaseKey) == tag) return false;
    await preferences.setString(_promptedReleaseKey, tag);
    return true;
  }

  void dispose() {
    if (_ownsHttpClient) _http.close();
  }
}
