import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/auth_error.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/background_pattern.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _email.text.trim(),
            password: _password.text,
          );
      // The router redirects to /home automatically once signed in.
    } catch (e) {
      _showMessage(friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      // The browser opens. After the user finishes, the app returns through
      // the deep link and the router redirects to /home.
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

  // --- design only: old input look, with the new floating label ---
  InputDecoration _inputDecoration(BuildContext context, String label,
      {Widget? suffixIcon}) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(Responsive.radius(context, 14)),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
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

  // --- design only: old look ---
  @override
  Widget build(BuildContext context) {
    final fieldTextStyle = TextStyle(
      color: const Color(0xFF112217),
      fontSize: Responsive.fontSize(context, 15),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: OrganicBackgroundCircles(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.horizontalPadding(context),
                vertical: Responsive.size(context, 24),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: Responsive.size(context, 12)),

                    // Title
                    Text(
                      'Login here',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 30),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2E8B57),
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: Responsive.size(context, 16)),

                    // Subtitle
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width * 0.65,
                      child: Text(
                        'Welcome back you\'ve\nbeen missed!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 20),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF112217),
                          height: 1.3,
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.size(context, 46)),

                    // Email field (floating label)
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      style: fieldTextStyle,
                      decoration: _inputDecoration(context, 'Email'),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Enter a valid email'
                          : null,
                    ),
                    SizedBox(height: Responsive.size(context, 18)),

                    // Password field (floating label)
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      style: fieldTextStyle,
                      decoration: _inputDecoration(
                        context,
                        'Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                            color: const Color(0xFF62776A),
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Enter your password'
                          : null,
                    ),

                    // Forgot password link
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: Responsive.size(context, 8),
                          bottom: Responsive.size(context, 20),
                        ),
                        child: GestureDetector(
                          onTap: () => context.go('/forgot-password'),
                          child: Text(
                            'Forgot password?',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 12),
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF112217),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Log in button
                    Container(
                      width: double.infinity,
                      height: Responsive.size(context, 54),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF75C19F), Color(0xFF1E5241)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(
                            Responsive.radius(context, 14)),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF1E5241).withValues(alpha: 0.35),
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
                                    'Log in',
                                    style: TextStyle(
                                      fontSize:
                                          Responsive.fontSize(context, 18),
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: Responsive.size(context, 38)),

                    // "or" divider
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color:
                                const Color(0xFFD6E8DF).withValues(alpha: 0.9),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: Responsive.size(context, 14)),
                          child: Text(
                            'or',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 13),
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF778D80),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color:
                                const Color(0xFFD6E8DF).withValues(alpha: 0.9),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: Responsive.size(context, 18)),

                    // Google button (old look, same onPressed as before)
                    Container(
                      width: double.infinity,
                      height: Responsive.size(context, 54),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                            Responsive.radius(context, 14)),
                        border: Border.all(color: const Color(0xFFD6E8DF)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _loading ? null : _signInWithGoogle,
                          borderRadius: BorderRadius.circular(
                              Responsive.radius(context, 14)),
                          child: Center(
                            child: _loading
                                ? SizedBox(
                                    width: Responsive.size(context, 24),
                                    height: Responsive.size(context, 24),
                                    child: const CircularProgressIndicator(
                                        color: Color(0xFF2E8B57),
                                        strokeWidth: 2.5),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.network(
                                        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
                                        width: Responsive.size(context, 22),
                                        height: Responsive.size(context, 22),
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Text(
                                          'G',
                                          style: TextStyle(
                                            fontSize: Responsive.fontSize(
                                                context, 22),
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFFEA4335),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                          width: Responsive.size(context, 10)),
                                      Text(
                                        'Continue with Google',
                                        style: TextStyle(
                                          fontSize: Responsive.fontSize(
                                              context, 15),
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF112217),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: Responsive.size(context, 28)),

                    // Bottom row: switch to register
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 14),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF112217),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/register'),
                          child: Text(
                            'Sign up',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 14),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF2E8B57),
                            ),
                          ),
                        ),
                      ],
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