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
