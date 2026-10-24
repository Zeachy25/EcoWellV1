import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../data/announcement_repository.dart';

class AnnouncementBell extends StatefulWidget {
  const AnnouncementBell({super.key});

  @override
  State<AnnouncementBell> createState() => _AnnouncementBellState();
}

class _AnnouncementBellState extends State<AnnouncementBell> {
  final _repository = AnnouncementRepository();
  List<AnnouncementItem> _items = [];
  Set<String> _readIds = {};
  String? _announcementError;
  String? _releaseError;
  bool _loading = true;
  bool _promptOpen = false;
  Future<void>? _initialLoad;
  StreamSubscription<List<AnnouncementItem>>? _announcementSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialLoad = _refresh();
      _watchAnnouncements();
    });
  }

  @override
  void dispose() {
    _announcementSubscription?.cancel();
    _repository.dispose();
    super.dispose();
  }

  void _watchAnnouncements() {
    _announcementSubscription = _repository.watchAnnouncements().listen(
      (announcements) {
        if (!mounted) return;
        setState(() {
          final releases = _items.where((item) => item.isUpdate);
          _items = [...announcements, ...releases]
            ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
          _announcementError = null;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Announcement realtime stream failed: $error');
        if (!mounted) return;
        setState(
          () => _announcementError =
              'Live announcements are unavailable. Pull to refresh.',
        );
      },
    );
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _loading = true);

    String currentVersion = '';
    try {
      final package = await PackageInfo.fromPlatform();
      currentVersion = package.version;
    } catch (e) {
      debugPrint('Could not read app version: $e');
    }

    List<AnnouncementItem> announcements = [];
    AnnouncementItem? release;
    String? announcementError;
    String? releaseError;
    final results = await Future.wait([
      _repository.fetchAnnouncements().then<Object?>(
        (value) => value,
        onError: (Object error) {
          debugPrint('Announcement fetch failed: $error');
          announcementError = 'Could not load Supabase announcements.';
          return null;
        },
      ),
      _repository
          .fetchLatestRelease(currentVersion: currentVersion)
          .then<Object?>(
            (value) => value,
            onError: (Object error) {
              debugPrint('GitHub release check failed: $error');
              releaseError = 'Could not check GitHub Releases.';
              return null;
            },
          ),
    ]);
    final announcementResult = results[0];
    if (announcementResult is List<AnnouncementItem>) {
      announcements = announcementResult;
    }
    final releaseResult = results[1];
    if (releaseResult is AnnouncementItem) {
      release = releaseResult;
    }
    try {
      _readIds = await _repository.readAnnouncementIds();
    } catch (e) {
      debugPrint('Could not read announcement state: $e');
    }
    if (!mounted) return;
    setState(() {
      _items = [...announcements, ?release]
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      _announcementError = announcementError;
      _releaseError = releaseError;
      _loading = false;
    });

    final update = release;
    if (update != null &&
        update.isUpdate &&
        await _repository.shouldPromptForRelease(update.versionTag)) {
      _showUpdateDialog(update);
    }
  }

  Future<void> _showUpdateDialog(AnnouncementItem release) async {
    if (!mounted || _promptOpen) return;
    _promptOpen = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(release.title),
        content: SingleChildScrollView(child: Text(release.message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: release.downloadUrl == null && release.linkUrl == null
                ? null
                : () {
                    Navigator.pop(dialogContext);
                    _openLink(
                      release.downloadUrl ?? release.linkUrl,
                      release.downloadUrl == null
                          ? 'Could not open the release page.'
                          : 'Could not open the APK download.',
                    );
                  },
            child: Text(
              release.downloadUrl == null ? 'View release' : 'Download',
            ),
          ),
        ],
      ),
    );
    _promptOpen = false;
  }

  Future<void> _openLink(String? value, String errorMessage) async {
    if (value == null) return;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      _showError(errorMessage);
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showError(errorMessage);
      }
    } catch (e) {
      debugPrint('Could not open announcement link: $e');
      _showError(errorMessage);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAnnouncements() async {
    await _initialLoad;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => _AnnouncementList(
          items: _items,
          loading: _loading,
          announcementError: _announcementError,
          releaseError: _releaseError,
          onRefresh: () async {
            final refresh = _refresh();
            setSheetState(() {});
            await refresh;
            if (context.mounted) setSheetState(() {});
          },
          readIds: _readIds,
          onOpen: (item) {
            unawaited(_markRead(item, setSheetState));
            _openItem(item);
          },
        ),
      ),
    );
  }

  Future<void> _markRead(
    AnnouncementItem item,
    StateSetter setSheetState,
  ) async {
    if (!_readIds.add(item.id)) return;
    setState(() {});
    setSheetState(() {});
    try {
      await _repository.markAnnouncementsRead([item.id]);
    } catch (e) {
      debugPrint('Could not save announcement read state: $e');
      if (!mounted) return;
      _readIds.remove(item.id);
      setState(() {});
      setSheetState(() {});
      _showError('Could not save that this announcement was read.');
    }
  }

  Future<void> _openItem(AnnouncementItem item) async {
    final link = item.isUpdate
        ? item.downloadUrl ?? item.linkUrl
        : item.linkUrl;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.title),
        content: SingleChildScrollView(child: Text(item.message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (link != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _openLink(
                  link,
                  item.isUpdate
                      ? 'Could not open the APK download.'
                      : 'Could not open the announcement link.',
                );
              },
              child: Text(
                item.isUpdate
                    ? (item.downloadUrl == null ? 'View release' : 'Download')
                    : 'Open link',
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _items
        .where((item) => !_readIds.contains(item.id))
        .length;
    return IconButton(
      tooltip: 'Announcements and updates',
      onPressed: _openAnnouncements,
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(unreadCount > 9 ? '9+' : '$unreadCount'),
        child: const Icon(Icons.notifications_none, color: Colors.white),
      ),
    );
  }
}

class _AnnouncementList extends StatelessWidget {
  const _AnnouncementList({
    required this.items,
    required this.loading,
    required this.announcementError,
    required this.releaseError,
    required this.onRefresh,
    required this.readIds,
    required this.onOpen,
  });

  final List<AnnouncementItem> items;
  final bool loading;
  final String? announcementError;
  final String? releaseError;
  final Future<void> Function() onRefresh;
  final Set<String> readIds;
  final ValueChanged<AnnouncementItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final errors = [?announcementError, ?releaseError];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Announcements',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          if (errors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                errors.join('\n'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (loading)
            const LinearProgressIndicator()
          else if (items.isEmpty)
            const Expanded(child: Center(child: Text('No announcements yet.')))
          else
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final unread = !readIds.contains(item.id);
                  return ListTile(
                    tileColor: unread
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.08)
                        : null,
                    leading: Icon(
                      item.isUpdate
                          ? Icons.system_update_alt
                          : Icons.campaign_outlined,
                      color: AppColors.primaryGreen,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${item.source} · ${_formatDate(item.publishedAt)}',
                    ),
                    trailing: item.isUpdate
                        ? const Icon(Icons.download_outlined)
                        : item.linkUrl == null
                        ? null
                        : const Icon(Icons.open_in_new),
                    onTap: () => onOpen(item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
