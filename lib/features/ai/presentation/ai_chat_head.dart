import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import 'ai_assets.dart';

/// A messenger-style floating button that opens the AI chat.
///
/// It sits inside the main app frame, so it appears on Home, Explore, Map and
/// Dashboard. The user can drag it around; the last position is remembered on
/// this phone. This is an in-app bubble, not a system overlay, so it needs no
/// extra Android permission.
class AiChatHead extends StatefulWidget {
  const AiChatHead({super.key, required this.area});

  final Size area;

  @override
  State<AiChatHead> createState() => _AiChatHeadState();
}

class _AiChatHeadState extends State<AiChatHead>
    with SingleTickerProviderStateMixin {
  static const _bubbleSize = 58.0;
  static const _edge = 12.0;
  static const _prefsX = 'ai_chat_head_x';
  static const _prefsY = 'ai_chat_head_y';

  late final AnimationController _idle;
  late final Animation<double> _bounce;

  SharedPreferences? _prefs;
  double? _left;
  double? _top;
  bool _dragging = false;
  bool _touched = false;
  double _dragDistance = 0;
  Offset _dragStart = Offset.zero;
  double _startLeft = 0;
  double _startTop = 0;

  double get _maxLeft =>
      math.max(_edge, widget.area.width - _bubbleSize - _edge);
  double get _maxTop =>
      math.max(_edge, widget.area.height - _bubbleSize - _edge);

  double get _resolvedLeft =>
      (_left ?? _maxLeft).clamp(_edge, _maxLeft).toDouble();

  double get _resolvedTop =>
      (_top ?? widget.area.height * 0.68).clamp(_edge, _maxTop).toDouble();

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _bounce = Tween<double>(begin: 1, end: 1.035).animate(
      CurvedAnimation(parent: _idle, curve: Curves.easeInOut),
    );
    _loadPosition();
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final x = prefs.getDouble(_prefsX);
    final y = prefs.getDouble(_prefsY);
    setState(() {
      _prefs = prefs;
      if (_touched) return;
      _left = x == null ? null : x * _maxLeft;
      _top = y == null ? null : y * _maxTop;
    });
    if (_touched) await _savePosition();
  }

  Future<void> _savePosition() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final x = _maxLeft <= 0 ? 0.0 : _resolvedLeft / _maxLeft;
    final y = _maxTop <= 0 ? 0.0 : _resolvedTop / _maxTop;
    await prefs.setDouble(_prefsX, x.clamp(0, 1).toDouble());
    await prefs.setDouble(_prefsY, y.clamp(0, 1).toDouble());
  }

  void _onPanStart(DragStartDetails details) {
    _touched = true;
    _dragStart = details.globalPosition;
    _startLeft = _resolvedLeft;
    _startTop = _resolvedTop;
    _dragDistance = 0;
    setState(() => _dragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _dragDistance += details.delta.distance;
    final nextLeft = (_startLeft + details.globalPosition.dx - _dragStart.dx)
        .clamp(_edge, _maxLeft)
        .toDouble();
    final nextTop = (_startTop + details.globalPosition.dy - _dragStart.dy)
        .clamp(_edge, _maxTop)
        .toDouble();
    setState(() {
      _left = nextLeft;
      _top = nextTop;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _dragging = false);
    _savePosition();
  }

  void _openChat() {
    final wasDrag = _dragDistance > 8;
    _dragDistance = 0;
    if (wasDrag) return;
    context.push('/ai');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.area.width <= _bubbleSize || widget.area.height <= _bubbleSize) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: _resolvedLeft,
      top: _resolvedTop,
      child: Semantics(
        button: true,
        label: 'Open EcoWell AI assistant',
        child: Tooltip(
          message: 'Ask EcoWell AI',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openChat,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: AnimatedBuilder(
              animation: _bounce,
              builder: (context, child) => Transform.scale(
                scale: _bounce.value,
                child: child,
              ),
              child: AnimatedScale(
                scale: _dragging ? 1.08 : 1,
                duration: const Duration(milliseconds: 120),
                child: Container(
                  width: _bubbleSize,
                  height: _bubbleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryButtonGradient,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.forestDark.withValues(alpha: 0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipOval(
                        child: Image.asset(
                          AiAssets.icon,
                          width: _bubbleSize,
                          height: _bubbleSize,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 9,
                        top: 9,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: AppColors.mintGreen,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
