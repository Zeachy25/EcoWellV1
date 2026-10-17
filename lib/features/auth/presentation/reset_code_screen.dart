import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth_flags.dart';
import '../../../core/constants/auth_constants.dart';
import '../../../core/utils/auth_error.dart';
import '../../../shared/widgets/code_field.dart';
import '../../../shared/widgets/resend_code_button.dart';
import '../data/auth_repository.dart';

/// Step 2 of "forgot password": the user types the 6-digit code from the
/// email. If it is right, the app moves on to "Set a new password".
class ResetCodeScreen extends ConsumerStatefulWidget {
  const ResetCodeScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ResetCodeScreen> createState() => _ResetCodeScreenState();
}

class _ResetCodeScreenState extends ConsumerState<ResetCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    // Set the flag BEFORE verifying, so the router sends the user to the
    // "Set a new password" screen (not Home) when the session starts.
    passwordRecoveryActive = true;
    try {
      await ref.read(authRepositoryProvider).verifyRecoveryCode(
            email: widget.email,
            code: _code.text.trim(),
          );
      if (mounted) context.go('/reset-password');
    } catch (e) {
      passwordRecoveryActive = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyAuthError(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset your password'),
        leading: BackButton(onPressed: () => context.go('/forgot-password')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Icon(Icons.pin_outlined, size: 64, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text('Enter your code',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'If an account exists for ${widget.email}, we sent a '
                    '$kEmailCodeLength-digit code to it. Check your spam folder too.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  CodeField(controller: _code),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _verify,
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Continue'),
                  ),
                  ResendCodeButton(
                    onResend: () => ref
                        .read(authRepositoryProvider)
                        .sendPasswordReset(widget.email),
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Back to log in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
