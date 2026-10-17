import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/auth_constants.dart';
import '../../../core/utils/auth_error.dart';
import '../../../shared/widgets/code_field.dart';
import '../../../shared/widgets/resend_code_button.dart';
import '../data/auth_repository.dart';

/// Shown after sign-up: the user types the 6-digit code from the email.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
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
    try {
      await ref.read(authRepositoryProvider).verifySignupCode(
            email: widget.email,
            code: _code.text.trim(),
          );
      // Signed in now: the router sends the user to Home automatically.
    } catch (e) {
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
        title: const Text('Confirm your email'),
        leading: BackButton(onPressed: () => context.go('/register')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Icon(Icons.mark_email_unread_outlined,
                      size: 64, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text('Enter your code',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a $kEmailCodeLength-digit code to ${widget.email}. It can take '
                    'a minute to arrive. Check your spam folder too.',
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
                        : const Text('Confirm'),
                  ),
                  ResendCodeButton(
                    onResend: () => ref
                        .read(authRepositoryProvider)
                        .resendSignupCode(widget.email),
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
