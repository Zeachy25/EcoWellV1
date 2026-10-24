import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/legal.dart';
import '../../../core/offline/json_cache.dart';

class AuthRepository {
  AuthRepository(this._client, {JsonCache? cache}) : _cache = cache;
  final SupabaseClient _client;
  final JsonCache? _cache;

  static const minAge = 18;
  static const maxAge = 60;

  /// Must match the Redirect URL in Supabase and the Android intent-filter.
  /// Used for Google sign-in and for the password reset link.
  static const deepLinkRedirect = 'io.supabase.ecowell://login-callback/';

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required DateTime birthdate,
  }) {
    // The database trigger reads these values to create the profile,
    // enforce the 18-60 age rule and record consent.
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'birthdate': _formatDate(birthdate),
        'consent_version': kConsentVersion,
      },
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Opens the browser for Google sign-in; the app is reopened by deep link.
  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: deepLinkRedirect,
    );
  }

  /// Sends the "reset your password" email.
  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(
      email,
      redirectTo: deepLinkRedirect,
    );
  }

  /// Sets a new password (used after the user opens the reset link).
  Future<UserResponse> updatePassword(String newPassword) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// For Google users (and old accounts): saves consent, and the birthdate
  /// when it is still missing. The database rejects ages outside 18-60.
  Future<void> completeProfile({DateTime? birthdate}) async {
    final uid = _client.auth.currentUser!.id;
    await _client.from('profiles').update({
      if (birthdate != null) 'birthdate': _formatDate(birthdate),
      'consented_at': DateTime.now().toUtc().toIso8601String(),
      'consent_version': kConsentVersion,
    }).eq('id', uid);
  }

  /// Confirms a new account with the 6-digit code from the email.
  Future<AuthResponse> verifySignupCode({
    required String email,
    required String code,
  }) {
    return _client.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.signup,
    );
  }

  Future<void> resendSignupCode(String email) async {
    await _client.auth.resend(type: OtpType.signup, email: email);
  }

  /// Checks the 6-digit password reset code. On success the user gets a
  /// temporary session and the app moves on to "Set a new password".
  Future<AuthResponse> verifyRecoveryCode({
    required String email,
    required String code,
  }) {
    return _client.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.recovery,
    );
  }

  /// Signs out and removes the personal snapshots kept for offline use
  /// (profile, dashboard, feed, weather). Queued visits are left alone so
  /// they can still be synced when this user is online again.
  Future<void> signOut() async {
    await _cache?.clearPersonal();
    await _client.auth.signOut();
  }

  static String _formatDate(DateTime d) => d.toIso8601String().substring(0, 10);

  static int ageOf(DateTime birthdate) {
    final now = DateTime.now();
    var age = now.year - birthdate.year;
    final hadBirthday = now.month > birthdate.month ||
        (now.month == birthdate.month && now.day >= birthdate.day);
    if (!hadBirthday) age--;
    return age;
  }

  static bool isEligibleAge(DateTime birthdate) {
    final age = ageOf(birthdate);
    return age >= minAge && age <= maxAge;
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    Supabase.instance.client,
    cache: ref.watch(jsonCacheProvider),
  ),
);
