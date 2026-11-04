import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/background_pattern.dart';
import '../data/announcement_repository.dart';
import '../data/release_update_service.dart';

Future<void> showReleaseUpdateDialog(
  BuildContext context,
  AnnouncementItem release,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ReleaseUpdateDialog(release: release),
  );
}

class _ReleaseUpdateDialog extends StatefulWidget {
  const _ReleaseUpdateDialog({required this.release});

  final AnnouncementItem release;

  @override
  State<_ReleaseUpdateDialog> createState() => _ReleaseUpdateDialogState();
}

class _ReleaseUpdateDialogState extends State<_ReleaseUpdateDialog> {
  final _service = ReleaseUpdateService();
  StreamSubscription<ReleaseDownloadProgress>? _progressSubscription;
  ReleaseDownloadProgress? _progress;
  String? _error;
  bool _downloading = false;
  bool _permissionRequired = false;
  bool _installerOpened = false;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  Future<void> _downloadAndInstall() async {
    final apkUrl = widget.release.downloadUrl;
    if (apkUrl == null) return;
    setState(() {
      _downloading = true;
      _permissionRequired = false;
      _error = null;
      _progress = null;
    });
    await _progressSubscription?.cancel();
    _progressSubscription = _service.progress.listen(
      (progress) {
        if (mounted) setState(() => _progress = progress);
      },
      onError: (Object error) {
        debugPrint('Release download progress error: $error');
      },
    );

    try {
      await _service.downloadAndInstall(apkUrl);
      if (mounted) setState(() => _installerOpened = true);
    } on PlatformException catch (error) {
      debugPrint(
        'Release download/install error: ${error.code}: ${error.message}',
      );
      if (!mounted) return;
      setState(() {
        _permissionRequired = error.code == 'install_permission_required';
        _error = _permissionRequired
            ? null
            : error.message ?? 'Could not download or open the APK installer.';
      });
    } catch (error) {
      debugPrint('Release download/install error: $error');
      if (mounted) {
        setState(
          () => _error = 'Could not download or open the APK installer.',
        );
      }
    } finally {
      await _progressSubscription?.cancel();
      _progressSubscription = null;
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _openReleasePage() async {
    final value = widget.release.linkUrl ?? widget.release.downloadUrl;
    if (value == null) return;
    final uri = Uri.tryParse(value);
    const allowedHosts = {
      'github.com',
      'release-assets.githubusercontent.com',
      'objects.githubusercontent.com',
    };
    if (uri == null ||
        uri.scheme != 'https' ||
        !allowedHosts.contains(uri.host)) {
      setState(() => _error = 'The release page link is invalid.');
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        setState(() => _error = 'Could not open the GitHub release page.');
      }
    } catch (error) {
      debugPrint('Could not open release page: $error');
      if (mounted) {
        setState(() => _error = 'Could not open the GitHub release page.');
      }
    }
  }

  String _sizeLabel(int? bytes) {
    if (bytes == null || bytes <= 0) return 'APK update';
    final megabytes = bytes / (1024 * 1024);
    return '${megabytes.toStringAsFixed(1)} MB';
  }

  String _progressLabel() {
    final progress = _progress;
    if (progress == null || progress.totalBytes <= 0) {
      return 'Downloading update...';
    }
    final percent = ((progress.fraction ?? 0) * 100).round();
    final received = _sizeLabel(progress.bytesReceived);
    final total = _sizeLabel(progress.totalBytes);
    return '$percent% · $received of $total';
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.release;
    final canDownload = _isAndroid && release.downloadUrl != null;
    final busy = _downloading;
    final title = release.versionTag == null
        ? 'EcoWell update available'
        : 'EcoWell ${release.versionTag} is available';

    return PopScope(
      canPop: !_downloading,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 460,
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: ColoredBox(
              color: AppColors.background,
              child: OrganicBackgroundCircles(
                child: Stack(
                  children: [
                    if (!_downloading && !_installerOpened)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          tooltip: busy ? 'Please wait' : 'Close',
                          onPressed: busy
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryButtonGradient,
                            ),
                            child: const Icon(
                              Icons.system_update_alt,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.forestDark,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.mintLight,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              '${release.versionTag ?? 'Latest version'}  ·  ${_sizeLabel(release.downloadSizeBytes)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.forestDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (release.message.trim().isNotEmpty)
                            Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxHeight: 220),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "What's new",
                                      style: TextStyle(
                                        color: AppColors.forestDark,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      release.message,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (busy) ...[
                            const SizedBox(height: 20),
                            LinearProgressIndicator(
                              value: _progress?.fraction,
                              minHeight: 7,
                              borderRadius: BorderRadius.circular(10),
                              color: AppColors.primaryGreen,
                              backgroundColor: AppColors.mintLight,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _progressLabel(),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (_permissionRequired) ...[
                            const SizedBox(height: 18),
                            const _StatusMessage(
                              icon: Icons.security,
                              message:
                                  'Allow EcoWell to install apps in Android settings, then return here and tap continue.',
                            ),
                          ],
                          if (_installerOpened) ...[
                            const SizedBox(height: 18),
                            const _StatusMessage(
                              icon: Icons.verified_outlined,
                              message:
                                  'Android installer opened. Follow its prompts to finish updating EcoWell.',
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            _StatusMessage(
                              icon: Icons.error_outline,
                              message: _error!,
                              isError: true,
                            ),
                          ],
                          const SizedBox(height: 22),
                          if (!_installerOpened)
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: FilledButton.icon(
                                onPressed: busy
                                    ? null
                                    : _permissionRequired
                                    ? _downloadAndInstall
                                    : canDownload
                                    ? _downloadAndInstall
                                    : _openReleasePage,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                                icon: busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        _permissionRequired
                                            ? Icons.check
                                            : canDownload
                                            ? Icons.download
                                            : Icons.open_in_new,
                                      ),
                                label: Text(
                                  busy
                                      ? 'Downloading update...'
                                      : _permissionRequired
                                      ? 'I enabled it — continue'
                                      : canDownload
                                      ? 'Download update'
                                      : 'View release',
                                ),
                              ),
                            ),
                          if (_installerOpened)
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Done'),
                              ),
                            )
                          else ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: TextButton(
                                onPressed: busy
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text('Later'),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Wi-Fi or mobile data required',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.scoreLow : AppColors.primaryGreen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF1F0) : AppColors.mintLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? AppColors.scoreLow : AppColors.forestDark,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
