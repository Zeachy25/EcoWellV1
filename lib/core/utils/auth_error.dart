import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _noInternet = 'No internet connection. Check your network and try again.';

/// Turns any error from sign-up / login / reset into a short, friendly
/// message. The raw error is only printed to the debug console.
String friendlyAuthError(Object error) {
  debugPrint('Auth error: $error');

  if (error is SocketException) return _noInternet;

  final String raw;
  if (error is AuthException) {
    raw = error.message;
  } else if (error is PostgrestException) {
    raw = error.message;
  } else {
    raw = error.toString();
  }
  final m = raw.toLowerCase();

  if (m.contains('invalid login credentials')) {
    return 'Incorrect email or password. Please try again.';
  }
  if (m.contains('email not confirmed')) {
    return 'Please confirm your email first. Check your inbox for the link.';
  }
  if (m.contains('already registered') || m.contains('already exists')) {
    return 'An account with this email already exists. Try logging in instead.';
  }
  if (m.contains('password should be') || m.contains('weak password')) {
    return 'Your password is too weak. Use at least 8 characters with '
        'letters and numbers.';
  }
  if (m.contains('different from the old password')) {
    return 'Your new password must be different from your old one.';
  }
  if (m.contains('rate limit') ||
      m.contains('for security purposes') ||
      m.contains('too many')) {
    return 'Too many attempts. Please wait a few minutes and try again.';
  }
  if (m.contains('invalid format') ||
      (m.contains('email') && m.contains('invalid'))) {
    return 'Please enter a valid email address.';
  }
  if (m.contains('aged 18 to 60') || m.contains('database error')) {
    return 'We could not create your account. Please make sure you are '
        'aged 18 to 60 and have agreed to the Privacy Policy.';
  }
  if (m.contains('signup is disabled') || m.contains('signups not allowed')) {
    return 'Sign-ups are currently turned off.';
  }
  if (m.contains('socketexception') ||
      m.contains('failed host lookup') ||
      m.contains('clientexception') ||
      m.contains('timeout') ||
      m.contains('network')) {
    return _noInternet;
  }
  return 'Something went wrong. Please try again.';
}
