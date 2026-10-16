/// True while the user is in the "reset password" flow (after tapping the
/// link in the reset email). The router uses it to keep them on the
/// Reset Password screen instead of sending them to Home.
bool passwordRecoveryActive = false;
