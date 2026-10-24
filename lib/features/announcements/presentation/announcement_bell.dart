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
  StreamSubscription<String?>? _userSubscription;
  String? _readUserId;

  @override
  void initState() {
    super.initState();
    _readUserId = _repository.currentUserId;
    _userSubscription = _repository.watchCurrentUserId().listen(
      _handleUserChanged,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Could not watch announcement account changes: $error');
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialLoad = _refresh();
      _watchAnnouncements();
    });
  }

  @override
  void dispose() {
    _announcementSubscription?.cancel();
    _userSubscription?.cancel();
    _repository.dispose();
    super.dispose();
  }

  void _handleUserChanged(String? userId) {
    if (userId == _readUserId) return;
    _readUserId = userId;
    if (!mounted) return;
    setState(() => _readIds = {});
    unawaited(_loadReadIdsForUser(userId));
  }

  Future<void> _loadReadIdsForUser(String? userId) async {
    try {
      final readIds = await _repository.readAnnouncementIds();
      if (!mounted || userId != _repository.currentUserId) return;
      setState(() => _readIds = readIds);
    } catch (e) {
      debugPrint('Could not read announcement state: $e');
    }
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
          () => _announcementError = 'Live announcements are unavailable.',
        );
      },
    );
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final readUserId = _repository.currentUserId;
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
      final readIds = await _repository.readAnnouncementIds();
      if (readUserId == _repository.currentUserId) _readIds = readIds;
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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => _AnnouncementList(
          items: _items,
          loading: _loading,
          announcementError: _announcementError,
          releaseError: _releaseError,
          readIds: _readIds,
          onMarkAllRead: () => _markAllRead(setSheetState, sheetContext),
          onOpen: (item) {
            unawaited(_markRead(item, setSheetState));
            _openItem(item);
          },
        ),
      ),
    );
  }

  Future<void> _markAllRead(
    StateSetter setSheetState,
    BuildContext sheetContext,
  ) async {
    final unreadIds = _items
        .where((item) => !_readIds.contains(item.id))
        .map((item) => item.id)
        .toList();
    if (unreadIds.isEmpty) return;

    _readIds.addAll(unreadIds);
    setState(() {});
    setSheetState(() {});
    try {
      await _repository.markAnnouncementsRead(unreadIds);
    } catch (e) {
      debugPrint('Could not save announcement read state: $e');
      if (!mounted) return;
      _readIds.removeAll(unreadIds);
      setState(() {});
      if (sheetContext.mounted) setSheetState(() {});
      _showError('Could not mark announcements as read.');
    }
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
    final attachmentName = item.downloadUrl == null
        ? null
        : Uri.tryParse(item.downloadUrl!)?.pathSegments.lastOrNull;
    final actionLabel = item.isUpdate
        ? (item.downloadUrl == null ? 'View release' : 'Download update')
        : 'Open announcement link';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.mintLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.notifications_outlined,
                                  size: 16,
                                  color: AppColors.primaryGreen,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Notification',
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: AppColors.forestDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_outline, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Read-only',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.mintSoft,
                              foregroundColor: AppColors.forestDark,
                              child: Icon(
                                item.isUpdate
                                    ? Icons.system_update_alt
                                    : Icons.campaign_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.source,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.isUpdate
                                        ? 'App update'
                                        : 'Announcement',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatPublishedAt(item.publishedAt),
                              textAlign: TextAlign.end,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        item.message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.55,
                        ),
                      ),
                      if (link != null) ...[
                        const SizedBox(height: 20),
                        Material(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.pop(dialogContext);
                              _openLink(
                                link,
                                item.isUpdate
                                    ? 'Could not open the APK download.'
                                    : 'Could not open the announcement link.',
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: AppColors.mintLight,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      item.isUpdate
                                          ? Icons.android
                                          : Icons.link,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          attachmentName ??
                                              (item.isUpdate
                                                  ? item.versionTag ??
                                                        'App release'
                                                  : actionLabel),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.downloadUrl != null
                                              ? 'APK file · ${item.versionTag ?? 'Latest version'}'
                                              : item.isUpdate
                                              ? 'Release details'
                                              : 'Related link',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.open_in_new,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mintLight.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                item.isUpdate
                                    ? 'App update information'
                                    : 'Announcement from ${item.source}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPublishedAt(DateTime date) {
    final today = DateUtils.isSameDay(date, DateTime.now());
    final yesterday = DateUtils.isSameDay(
      date,
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final day = today
        ? 'Today'
        : yesterday
        ? 'Yesterday'
        : '${date.month}/${date.day}/${date.year}';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'AM' : 'PM';
    return '$day · $hour:$minute $period';
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

enum _AnnouncementFilter { all, unread, updates }

class _AnnouncementList extends StatefulWidget {
  const _AnnouncementList({
    required this.items,
    required this.loading,
    required this.announcementError,
    required this.releaseError,
    required this.readIds,
    required this.onMarkAllRead,
    required this.onOpen,
  });

  final List<AnnouncementItem> items;
  final bool loading;
  final String? announcementError;
  final String? releaseError;
  final Set<String> readIds;
  final Future<void> Function() onMarkAllRead;
  final ValueChanged<AnnouncementItem> onOpen;

  @override
  State<_AnnouncementList> createState() => _AnnouncementListState();
}

class _AnnouncementListState extends State<_AnnouncementList> {
  _AnnouncementFilter _filter = _AnnouncementFilter.all;

  @override
  Widget build(BuildContext context) {
    final errors = [
      if (widget.announcementError != null) widget.announcementError!,
      if (widget.releaseError != null) widget.releaseError!,
    ];
    final unreadCount = widget.items
        .where((item) => !widget.readIds.contains(item.id))
        .length;
    final filteredItems = widget.items.where((item) {
      return switch (_filter) {
        _AnnouncementFilter.all => true,
        _AnnouncementFilter.unread => !widget.readIds.contains(item.id),
        _AnnouncementFilter.updates => item.isUpdate,
      };
    }).toList();
    final notificationRows = <Widget>[];
    for (final group in _groupItems(filteredItems)) {
      notificationRows.add(_buildGroupHeader(context, group));
      for (final item in group.value) {
        notificationRows.add(_buildCard(context, item));
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final requestedHeight = MediaQuery.sizeOf(context).height * 0.86;
        final height =
            constraints.maxHeight.isFinite &&
                constraints.maxHeight < requestedHeight
            ? constraints.maxHeight
            : requestedHeight;
        return SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Notifications',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _CountBadge(count: unreadCount, label: 'new'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: unreadCount == 0 ? null : widget.onMarkAllRead,
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('Mark all as read'),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _filterChip(
                      _AnnouncementFilter.all,
                      'All',
                      widget.items.length,
                    ),
                    _filterChip(
                      _AnnouncementFilter.unread,
                      'Unread',
                      unreadCount,
                    ),
                    _filterChip(
                      _AnnouncementFilter.updates,
                      'Updates',
                      widget.items.where((item) => item.isUpdate).length,
                    ),
                  ],
                ),
              ),
              if (errors.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      errors.join('\n'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              if (widget.loading) const LinearProgressIndicator(),
              Expanded(
                child: widget.loading && widget.items.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : filteredItems.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.items.isEmpty
                                    ? Icons.notifications_none
                                    : Icons.filter_alt_off_outlined,
                                size: 40,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.items.isEmpty
                                    ? 'No notifications yet.'
                                    : 'No notifications in this filter.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: notificationRows.length,
                        itemBuilder: (context, index) =>
                            notificationRows[index],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(_AnnouncementFilter filter, String label, int count) {
    final selected = _filter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$label ($count)'),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() => _filter = filter),
        backgroundColor: const Color(0xFFEAF0FA),
        selectedColor: AppColors.primaryGreen,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildGroupHeader(
    BuildContext context,
    MapEntry<DateTime, List<AnnouncementItem>> group,
  ) {
    final unreadCount = group.value
        .where((item) => !widget.readIds.contains(item.id))
        .length;
    final readCount = group.value.length - unreadCount;
    final today = DateUtils.dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final label = DateUtils.isSameDay(group.key, today)
        ? 'Today'
        : DateUtils.isSameDay(group.key, yesterday)
        ? 'Yesterday'
        : _formatDate(group.key);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          const Spacer(),
          if (unreadCount > 0)
            Text(
              '$unreadCount Unread',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (unreadCount > 0 && readCount > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 5),
              child: Text('·'),
            ),
          if (readCount > 0)
            Text(
              '$readCount Read',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, AnnouncementItem item) {
    final unread = !widget.readIds.contains(item.id);
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: unread ? const Color(0xFFF0F5FF) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => widget.onOpen(item),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: unread
                    ? AppColors.primaryGreen.withValues(alpha: 0.16)
                    : AppColors.cardBorder,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: unread ? AppColors.primaryGreen : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(15),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: item.isUpdate
                                ? const Color(0xFFDDF7EB)
                                : const Color(0xFFE7EDFF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            item.isUpdate
                                ? Icons.system_update_alt
                                : Icons.campaign_outlined,
                            color: item.isUpdate
                                ? AppColors.primaryGreen
                                : colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.source.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                            letterSpacing: 0.35,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  if (unread) ...[
                                    const SizedBox(width: 5),
                                    _CountBadge(count: 0, label: 'Unread'),
                                  ],
                                  const SizedBox(width: 7),
                                  Text(
                                    _formatTimeAgo(item.publishedAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: unread
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.35,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          item.isUpdate
                              ? Icons.download_outlined
                              : item.linkUrl == null
                              ? Icons.chevron_right
                              : Icons.open_in_new,
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<MapEntry<DateTime, List<AnnouncementItem>>> _groupItems(
    List<AnnouncementItem> items,
  ) {
    final groups = <DateTime, List<AnnouncementItem>>{};
    for (final item in items) {
      final day = DateUtils.dateOnly(item.publishedAt);
      groups.putIfAbsent(day, () => []).add(item);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final day in days) MapEntry(day, groups[day]!)];
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _formatTimeAgo(DateTime date) {
    final elapsed = DateTime.now().difference(date);
    if (elapsed.isNegative || elapsed.inMinutes < 1) return 'Just now';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';
    if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
    if (elapsed.inDays == 1) return 'Yesterday';
    if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
    return '${date.month}/${date.day}';
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: count == 0
            ? AppColors.primaryGreen
            : AppColors.primaryGreen.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        count == 0 ? label : '$count $label',
        style: TextStyle(
          color: count == 0 ? Colors.white : AppColors.primaryGreen,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
