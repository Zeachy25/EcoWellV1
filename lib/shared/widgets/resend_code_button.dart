import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/utils/auth_error.dart';

/// "Resend code" button with a countdown. Counting starts right away,
/// because a code was just sent when the screen opens.
class ResendCodeButton extends StatefulWidget {
  const ResendCodeButton({
    super.key,
    required this.onResend,
    this.cooldownSeconds = 60,
  });

  final Future<void> Function() onResend;
  final int cooldownSeconds;

  @override
  State<ResendCodeButton> createState() => _ResendCodeButtonState();
}

class _ResendCodeButtonState extends State<ResendCodeButton> {
  Timer? _timer;
  late int _left;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _left = widget.cooldownSeconds;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_left <= 1) {
        t.cancel();
        setState(() => _left = 0);
      } else {
        setState(() => _left--);
      }
    });
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    try {
      await widget.onResend();
      if (!mounted) return;
      setState(() => _left = widget.cooldownSeconds);
      _startTimer();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('A new code was sent.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyAuthError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: (_left > 0 || _busy) ? null : _resend,
      child: Text(_left > 0 ? 'Resend code in ${_left}s' : 'Resend code'),
    );
  }
}
