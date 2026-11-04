import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

class MyDaySelectedPhoto {
  const MyDaySelectedPhoto({required this.file, this.previewBytes});

  final XFile file;
  final Uint8List? previewBytes;
}

class MyDayMediaPickerScreen extends StatefulWidget {
  const MyDayMediaPickerScreen({super.key});

  @override
  State<MyDayMediaPickerScreen> createState() => _MyDayMediaPickerScreenState();
}

class _MyDayMediaPickerScreenState extends State<MyDayMediaPickerScreen> {
  static const _pageSize = 80;
  static const _thumbnailSize = ThumbnailSize.square(240);

  final _scrollController = ScrollController();
  List<AssetPathEntity> _albums = [];
  List<AssetEntity> _assets = [];
  AssetPathEntity? _album;
  AssetEntity? _selected;
  PermissionState? _permission;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _loadError;
  int _page = 0;
  int _request = 0;

  bool get _isAndroid => Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreWhenNearEnd);
    _loadGallery();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreWhenNearEnd)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadGallery() async {
    if (!_isAndroid) {
      await _openSystemPicker();
      return;
    }

    final request = ++_request;
    setState(() {
      _loading = true;
      _loadError = null;
      _assets = [];
      _selected = null;
    });
    try {
      final permission = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.image,
            mediaLocation: false,
          ),
        ),
      );
      if (!mounted || request != _request) return;
      setState(() => _permission = permission);
      if (!permission.hasAccess) {
        setState(() => _loading = false);
        return;
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
        filterOption: FilterOptionGroup(
          orders: const [
            OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );
      if (!mounted || request != _request) return;
      if (albums.isEmpty) {
        setState(() {
          _albums = [];
          _album = null;
          _loading = false;
          _hasMore = false;
        });
        return;
      }
      final allPhotos = albums.where((album) => album.isAll).firstOrNull;
      final initialAlbum = allPhotos ?? albums.first;
      setState(() {
        _albums = albums;
        _album = initialAlbum;
      });
      await _loadPage(reset: true);
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadPage({required bool reset}) async {
    final album = _album;
    if (album == null || _loadingMore) return;
    final request = _request;
    if (reset) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _loadError = null;
        _assets = [];
        _page = 0;
        _hasMore = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final page = reset ? 0 : _page;
      final assets = await album.getAssetListPaged(
        page: page,
        size: _pageSize,
        type: RequestType.image,
      );
      if (!mounted || request != _request || album != _album) return;
      setState(() {
        _assets = reset ? assets : [..._assets, ...assets];
        _page = page + 1;
        _hasMore = assets.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _loadError = error;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _loadMoreWhenNearEnd() {
    if (_scrollController.position.extentAfter < 500 &&
        !_loading &&
        !_loadingMore &&
        _hasMore) {
      _loadPage(reset: false);
    }
  }

  Future<void> _chooseAlbum() async {
    if (_albums.isEmpty) return;
    final selected = await showModalBottomSheet<AssetPathEntity>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final album in _albums)
              FutureBuilder<int>(
                future: album.assetCountAsync,
                builder: (context, snapshot) => ListTile(
                  title: Text(album.name),
                  trailing: Text('${snapshot.data ?? ''}'),
                  selected: album == _album,
                  onTap: () => Navigator.pop(context, album),
                ),
              ),
          ],
        ),
      ),
    );
    if (selected == null || selected == _album) return;
    setState(() {
      _album = selected;
      _selected = null;
      _request++;
    });
    await _loadPage(reset: true);
  }

  Future<void> _openSystemPicker() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (!mounted) return;
      if (photo != null) {
        Navigator.pop(context, MyDaySelectedPhoto(file: photo));
      } else {
        setState(() => _loading = false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _openCamera() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (mounted && photo != null) {
        Navigator.pop(context, MyDaySelectedPhoto(file: photo));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the camera.')),
      );
    }
  }

  Future<void> _openSettings() async {
    await PhotoManager.openSetting();
    if (mounted) await _loadGallery();
  }

  Future<void> _selectPhoto() async {
    final asset = _selected;
    if (asset == null) return;
    try {
      final bytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize(1600, 1600),
        quality: 80,
      );
      if (bytes == null) throw StateError('Selected photo is not available.');
      if (mounted) {
        Navigator.pop(
          context,
          MyDaySelectedPhoto(
            file: XFile.fromData(
              bytes,
              name: 'my_day.jpg',
              mimeType: 'image/jpeg',
            ),
            previewBytes: bytes,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load this photo. Try another.'),
        ),
      );
    }
  }

  List<_PhotoGroup> _groupByDate() {
    final groups = <_PhotoGroup>[];
    for (final asset in _assets) {
      final date = asset.createDateTime;
      final key = DateTime(date.year, date.month, date.day);
      if (groups.isEmpty || groups.last.date != key) {
        groups.add(_PhotoGroup(key, [asset]));
      } else {
        groups.last.assets.add(asset);
      }
    }
    return groups;
  }

  String _dateLabel(DateTime date) {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final yesterday = todayKey.subtract(const Duration(days: 1));
    if (date == todayKey) return 'TODAY';
    if (date == yesterday) return 'YESTERDAY';
    const months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final permission = _permission;
    final groups = _groupByDate();
    return Scaffold(
      backgroundColor: const Color(0xFF0A1121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1121),
        foregroundColor: Colors.white,
        title: const Text('Create Story'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Camera',
            onPressed: _openCamera,
            icon: const Icon(Icons.photo_camera_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _chooseAlbum,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _album?.name ?? 'Recents',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Choose one photo',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(child: _buildGallery(permission, groups)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected == null ? null : _selectPhoto,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2CB8EB),
                    foregroundColor: const Color(0xFF071422),
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: Text(
                    _selected == null ? 'Select a photo' : 'Use this photo',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGallery(PermissionState? permission, List<_PhotoGroup> groups) {
    if (permission != null && !permission.hasAccess) {
      return _MessageState(
        icon: Icons.photo_library_outlined,
        title: 'Allow photo access',
        message:
            'EcoWell needs access to the photos you choose for your story. '
            'Your gallery is only used to select an image.',
        actionLabel: 'Open settings',
        onAction: _openSettings,
      );
    }
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2CB8EB)),
      );
    }
    if (_loadError != null) {
      return _MessageState(
        icon: Icons.error_outline,
        title: 'Could not load photos',
        message: 'Check photo access and try again.',
        actionLabel: 'Retry',
        onAction: _loadGallery,
      );
    }
    if (groups.isEmpty) {
      final limited = permission?.isLimited ?? false;
      return _MessageState(
        icon: Icons.photo_outlined,
        title: 'No photos found',
        message: limited
            ? 'No photos are currently selected for EcoWell.'
            : 'Add photos to your device to create a story.',
        actionLabel: limited ? 'Choose photos' : null,
        onAction: limited
            ? () async {
                await PhotoManager.presentLimited(type: RequestType.image);
                if (mounted) await _loadGallery();
              }
            : null,
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: groups.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == groups.length) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF2CB8EB)),
            ),
          );
        }
        final group = groups[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Text(
                _dateLabel(group.date),
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: group.assets.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemBuilder: (context, photoIndex) {
                final asset = group.assets[photoIndex];
                final selected = asset.id == _selected?.id;
                return GestureDetector(
                  onTap: () => setState(() => _selected = asset),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _AssetThumbnail(
                        key: ValueKey(asset.id),
                        asset: asset,
                        size: _thumbnailSize,
                      ),
                      if (selected)
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF2CB8EB),
                              width: 3,
                            ),
                          ),
                        ),
                      Positioned(
                        top: 7,
                        right: 7,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF2CB8EB)
                                : Colors.black38,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white70),
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check,
                                  size: 15,
                                  color: Color(0xFF071422),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _PhotoGroup {
  _PhotoGroup(this.date, this.assets);

  final DateTime date;
  final List<AssetEntity> assets;
}

class _AssetThumbnail extends StatefulWidget {
  const _AssetThumbnail({super.key, required this.asset, required this.size});

  final AssetEntity asset;
  final ThumbnailSize size;

  @override
  State<_AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<_AssetThumbnail> {
  late Future<Uint8List?> _bytes = _load();

  Future<Uint8List?> _load() => widget.asset.thumbnailDataWithSize(widget.size);

  @override
  void didUpdateWidget(covariant _AssetThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) _bytes = _load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return Container(
            color: Colors.white10,
            child: snapshot.connectionState == ConnectionState.waiting
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  )
                : const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                  ),
          );
        }
        return Image.memory(bytes, fit: BoxFit.cover);
      },
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.white54),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.white70, height: 1.4),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
