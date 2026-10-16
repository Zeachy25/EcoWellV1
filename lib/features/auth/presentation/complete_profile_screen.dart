import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/auth_error.dart';
import '../../../shared/widgets/consent_checkbox_field.dart';
import '../data/auth_repository.dart';

/// Shown after login when the profile is missing the birthdate (Google
/// sign-in) and/or the Privacy Policy consent.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key, this.needsBirthdate = true});

  /// false when the birthdate is already saved and only consent is missing.
  final bool needsBirthdate;

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _birthdateText = TextEditingController();
  DateTime? _birthdate;
  bool _loading = false;

  @override
  void dispose() {
    _birthdateText.dispose();
    super.dispose();
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select your birthdate',
    );
    if (picked == null) return;
    setState(() {
      _birthdate = picked;
      _birthdateText.text = picked.toIso8601String().substring(0, 10);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).completeProfile(
            birthdate: widget.needsBirthdate ? _birthdate : null,
          );
      if (mounted) context.go('/home');
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Icon(Icons.verified_user_outlined,
                      size: 64, color: scheme.primary),
                  const SizedBox(height: 8),
                  Text('One last step',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    widget.needsBirthdate
                        ? 'EcoWell is for users aged 18 to 60. Please enter '
                            'your birthdate and review our privacy terms.'
                        : 'Please review and accept our privacy terms to '
                            'continue.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (widget.needsBirthdate) ...[
                    TextFormField(
                      controller: _birthdateText,
                      readOnly: true,
                      onTap: _pickBirthdate,
                      decoration: const InputDecoration(
                        labelText: 'Birthdate',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      validator: (_) {
                        if (_birthdate == null) return 'Select your birthdate';
                        if (!AuthRepository.isEligibleAge(_birthdate!)) {
                          return 'EcoWell is only for users aged 18 to 60';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  ConsentCheckboxField(),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Continue'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => ref.read(authRepositoryProvider).signOut(),
                    child: const Text('Log out'),
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
