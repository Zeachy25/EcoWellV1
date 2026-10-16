import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/auth_error.dart';
import '../../../shared/widgets/consent_checkbox_field.dart';
import '../data/auth_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _birthdateText = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  DateTime? _birthdate;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _birthdateText.dispose();
    _password.dispose();
    _confirm.dispose();
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
      final res = await ref.read(authRepositoryProvider).signUp(
            email: _email.text.trim(),
            password: _password.text,
            fullName: _name.text.trim(),
            birthdate: _birthdate!,
          );
      if (res.session == null && mounted) {
        // Email confirmation is ON in Supabase: user must confirm first.
        _showMessage('Account created. Check your email to confirm, then log in.');
        context.go('/login');
      }
      // If a session exists, the router redirects to /home automatically.
    } catch (e) {
      _showMessage(friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
        leading: BackButton(onPressed: () => context.go('/login')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter your name'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _birthdateText,
                  readOnly: true,
                  onTap: _pickBirthdate,
                  decoration: const InputDecoration(
                    labelText: 'Birthdate',
                    suffixIcon: Icon(Icons.calendar_today),
                    helperText: 'EcoWell is for users aged 18 to 60',
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
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    helperText: 'At least 8 characters, with letters and numbers',
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 8) {
                      return 'Use at least 8 characters';
                    }
                    if (!RegExp(r'[A-Za-z]').hasMatch(v) ||
                        !RegExp(r'\d').hasMatch(v)) {
                      return 'Include at least one letter and one number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  decoration:
                      const InputDecoration(labelText: 'Confirm password'),
                  validator: (v) =>
                      v != _password.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 16),
                ConsentCheckboxField(),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Sign up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
