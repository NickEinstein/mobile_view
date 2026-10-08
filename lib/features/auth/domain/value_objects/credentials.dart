import 'package:formz/formz.dart';

enum EmailError { empty, invalid }

final class Email extends FormzInput<String, EmailError> {
  const Email.pure() : super.pure('');
  const Email.dirty([super.value = '']) : super.dirty();

  /// Shape check only (something@domain.tld). The server decides whether
  /// the account exists.
  static final _pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  EmailError? validator(String value) {
    final email = value.trim();
    if (email.isEmpty) return EmailError.empty;
    if (!_pattern.hasMatch(email)) return EmailError.invalid;
    return null;
  }

  /// Partly hidden for display: `michealjames@mail.com` becomes
  /// `mic*********@mail.com`.
  String get masked {
    final email = value.trim();
    final at = email.indexOf('@');
    if (at <= 1) return email;
    final local = email.substring(0, at);
    final visible = local.length > 3 ? 3 : 1;
    final hidden = '*' * (local.length - visible);
    return '${local.substring(0, visible)}$hidden${email.substring(at)}';
  }
}

enum OtpCodeError { incomplete }

/// The verification code emailed during password reset.
final class OtpCode extends FormzInput<String, OtpCodeError> {
  const OtpCode.pure() : super.pure('');
  const OtpCode.dirty([super.value = '']) : super.dirty();

  static const length = 4;
  static final _pattern = RegExp('^\\d{$length}\$');

  @override
  OtpCodeError? validator(String value) =>
      _pattern.hasMatch(value) ? null : OtpCodeError.incomplete;
}

enum PasswordError { empty, tooShort }

final class Password extends FormzInput<String, PasswordError> {
  const Password.pure() : super.pure('');
  const Password.dirty([super.value = '']) : super.dirty();

  static const minLength = 8;

  @override
  PasswordError? validator(String value) {
    if (value.isEmpty) return PasswordError.empty;
    if (value.length < minLength) return PasswordError.tooShort;
    return null;
  }
}

enum ConfirmedPasswordError { empty, mismatch }

/// "Confirm password": valid when it matches [original].
final class ConfirmedPassword
    extends FormzInput<String, ConfirmedPasswordError> {
  const ConfirmedPassword.pure({this.original = ''}) : super.pure('');
  const ConfirmedPassword.dirty({required this.original, String value = ''})
    : super.dirty(value);

  final String original;

  @override
  ConfirmedPasswordError? validator(String value) {
    if (value.isEmpty) return ConfirmedPasswordError.empty;
    if (value != original) return ConfirmedPasswordError.mismatch;
    return null;
  }

  // FormzInput equality ignores [original]; include it so state updates
  // when only the new password changes.
  @override
  bool operator ==(Object other) =>
      other is ConfirmedPassword &&
      other.original == original &&
      super == other;

  @override
  int get hashCode => Object.hash(super.hashCode, original);
}
