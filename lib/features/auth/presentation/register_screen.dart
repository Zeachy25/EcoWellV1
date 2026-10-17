import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/auth_error.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/background_pattern.dart';
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
        // Email confirmation is ON in Supabase: ask for the 6-digit code.
        context.go('/verify-email', extra: _email.text.trim());
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

  // --- design only: login input look, with floating label ---
  InputDecoration _inputDecoration(
    BuildContext context,
    String label, {
    Widget? suffixIcon,
    String? helperText,
  }) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(Responsive.radius(context, 14)),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      helperText: helperText,
      helperMaxLines: 2,
      helperStyle: TextStyle(
        color: const Color(0xFF62776A),
        fontSize: Responsive.fontSize(context, 12),
      ),
      labelStyle: TextStyle(
        color: const Color(0xFF62776A),
        fontSize: Responsive.fontSize(context, 14),
      ),
      floatingLabelStyle: TextStyle(
        color: const Color(0xFF2E8B57),
        fontSize: Responsive.fontSize(context, 14),
        fontWeight: FontWeight.w600,
      ),
      fillColor: const Color(0xFFFBFDFB),
      filled: true,
      suffixIcon: suffixIcon,
      contentPadding: EdgeInsets.symmetric(
        horizontal: Responsive.size(context, 18),
        vertical: Responsive.size(context, 16),
      ),
      border: border(const Color(0xFF90D5B7), 1.6),
      enabledBorder: border(const Color(0xFF90D5B7), 1.6),
      focusedBorder: border(const Color(0xFF2E8B57), 2.0),
      errorBorder: border(Colors.red, 1.6),
      focusedErrorBorder: border(Colors.red, 2.0),
    );
  }

  // --- design only: login look ---
  @override
  Widget build(BuildContext context) {
    final fieldTextStyle = TextStyle(
      color: const Color(0xFF112217),
      fontSize: Responsive.fontSize(context, 15),
    );
    final gap = SizedBox(height: Responsive.size(context, 18));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF2E8B57)),
        title: Text(
          'Create account',
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 22),
            fontWeight: FontWeight.w800,
            color: const Color(0xFF2E8B57),
            letterSpacing: -0.5,
          ),
        ),
        leading: BackButton(onPressed: () => context.go('/login')),
      ),
      body: OrganicBackgroundCircles(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.horizontalPadding(context),
              vertical: Responsive.size(context, 24),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    style: fieldTextStyle,
                    decoration: _inputDecoration(context, 'Full name'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your name'
                        : null,
                  ),
                  gap,
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    style: fieldTextStyle,
                    decoration: _inputDecoration(context, 'Email'),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Enter a valid email'
                        : null,
                  ),
                  gap,
                  TextFormField(
                    controller: _birthdateText,
                    readOnly: true,
                    onTap: _pickBirthdate,
                    style: fieldTextStyle,
                    decoration: _inputDecoration(
                      context,
                      'Birthdate',
                      suffixIcon: const Icon(Icons.calendar_today,
                          color: Color(0xFF62776A)),
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
                  gap,
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    style: fieldTextStyle,
                    decoration: _inputDecoration(
                      context,
                      'Password',
                      helperText:
                          'At least 8 characters, with letters and numbers',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                          color: const Color(0xFF62776A),
                        ),
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
                  gap,
                  TextFormField(
                    controller: _confirm,
                    obscureText: _obscure,
                    style: fieldTextStyle,
                    decoration:
                        _inputDecoration(context, 'Confirm password'),
                    validator: (v) =>
                        v != _password.text ? 'Passwords do not match' : null,
                  ),
                  gap,
                  ConsentCheckboxField(),
                  SizedBox(height: Responsive.size(context, 20)),

                  // Sign up button (login gradient button)
                  Container(
                    width: double.infinity,
                    height: Responsive.size(context, 54),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF75C19F), Color(0xFF1E5241)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius:
                          BorderRadius.circular(Responsive.radius(context, 14)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E5241).withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _loading ? null : _submit,
                        borderRadius: BorderRadius.circular(
                            Responsive.radius(context, 14)),
                        child: Center(
                          child: _loading
                              ? SizedBox(
                                  width: Responsive.size(context, 24),
                                  height: Responsive.size(context, 24),
                                  child: const CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(
                                  'Sign up',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 18),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.size(context, 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}