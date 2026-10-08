import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_code_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_dialog.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_text_field.dart';
import 'package:vital_reg_mobile/features/auth/domain/value_objects/credentials.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/reissuance_repository.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

enum EmailStatus { unverified, sending, codeSent, confirming, verified }

/// An email confirmed with a one-time code (not saved across resumes).
class EmailCodeCubit extends Cubit<EmailCodeState> {
  EmailCodeCubit(this._repository, {String initial = ''})
    : super(
        EmailCodeState(
          email: initial.isEmpty ? const Email.pure() : Email.dirty(initial),
        ),
      );

  /// The codes are six digits.
  static const codeLength = 6;

  final ReissuanceRepository _repository;

  /// A new address must be confirmed again.
  void emailChanged(String value) =>
      emit(EmailCodeState(email: Email.dirty(value.trim())));

  /// "Validate": emails a one-time code to the address.
  Future<void> send() async {
    if (state.email.isNotValid || state.status != EmailStatus.unverified) {
      return;
    }
    emit(state.copyWith(status: EmailStatus.sending, code: ''));
    final result = await _repository.sendEmailCode(state.email.value);
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(status: EmailStatus.codeSent));
      case Err(:final failure):
        emit(state.copyWith(status: EmailStatus.unverified, failure: failure));
    }
  }

  void codeChanged(String code) => emit(state.copyWith(code: code));

  Future<void> resend() async {
    if (state.status != EmailStatus.codeSent) return;
    final result = await _repository.resendEmailCode(state.email.value);
    if (isClosed) return;
    if (result case Err(:final failure)) {
      emit(state.copyWith(failure: failure));
    }
  }

  Future<void> confirm() async {
    if (state.status != EmailStatus.codeSent ||
        state.code.length != codeLength) {
      return;
    }
    emit(state.copyWith(status: EmailStatus.confirming));
    final result = await _repository.confirmEmailCode(
      email: state.email.value,
      code: state.code,
    );
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(status: EmailStatus.verified));
      case Err(:final failure):
        emit(state.copyWith(status: EmailStatus.codeSent, failure: failure));
    }
  }

  /// The code dialog was closed without confirming.
  void cancelled() {
    if (state.status == EmailStatus.codeSent) {
      emit(state.copyWith(status: EmailStatus.unverified, code: ''));
    }
  }
}

final class EmailCodeState extends Equatable {
  const EmailCodeState({
    this.email = const Email.pure(),
    this.status = EmailStatus.unverified,
    this.code = '',
    this.failure,
  });

  final Email email;
  final EmailStatus status;

  /// The one-time code being typed.
  final String code;
  final Failure? failure;

  bool get verified => status == EmailStatus.verified;

  /// The confirmed address, or null.
  String? get verifiedEmail => verified ? email.value : null;

  /// [failure] is cleared unless passed, so a new attempt starts clean.
  EmailCodeState copyWith({
    EmailStatus? status,
    String? code,
    Failure? failure,
  }) => EmailCodeState(
    email: email,
    status: status ?? this.status,
    code: code ?? this.code,
    failure: failure,
  );

  @override
  List<Object?> get props => [email, status, code, failure];

  /// Keeps the address out of logs and test output.
  @override
  String toString() => 'EmailCodeState(${status.name})';
}

/// An email field with "Validate", which emails a code to confirm.
class EmailCodeField extends StatelessWidget {
  const EmailCodeField({
    required this.label,
    this.title,
    this.note,
    this.showErrors = false,
    this.notVerifiedText,
    this.onChanged,
    super.key,
  });

  final String label;

  /// A heading above the field, e.g. "Recipient's Email Address".
  final String? title;
  final String? note;

  /// Says the address still needs confirming.
  final bool showErrors;

  /// What that says; defaults to the recipient's wording.
  final String? notVerifiedText;

  /// Also told of every change (e.g. to keep it in the form).
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<EmailCodeCubit>();
    final state = context.watch<EmailCodeCubit>().state;
    final status = state.status;
    final failure = state.failure;
    final error = state.email.displayError != null
        ? l10n.baInvalidEmail
        : status != EmailStatus.codeSent && failure != null
        ? failure.localize(l10n)
        : showErrors && !state.verified
        ? notVerifiedText ?? l10n.crEmailNotVerified
        : null;

    return BlocListener<EmailCodeCubit, EmailCodeState>(
      // Once per code sent; a failed confirm stays in the dialog.
      listenWhen: (previous, current) =>
          previous.status == EmailStatus.sending &&
          current.status == EmailStatus.codeSent,
      listener: (context, _) => unawaited(_showEmailCodeDialog(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title case final title?)
            Text(
              title,
              style: textTheme.titleSmall?.copyWith(
                color: AppPalette.inkStrong,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (note case final note?)
            Text(
              note,
              style: textTheme.labelSmall?.copyWith(color: AppPalette.muted),
            ),
          if (title != null || note != null) const SizedBox(height: Spacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: label,
                  hintText: l10n.crEmailHint,
                  initialValue: state.email.value,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  errorText: error,
                  onChanged: (value) {
                    cubit.emailChanged(value);
                    onChanged?.call(value.trim());
                  },
                  onSubmitted: (_) => unawaited(cubit.send()),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Padding(
                // Level with the field, under its label.
                padding: const EdgeInsets.only(top: 28),
                child: state.verified
                    ? Tooltip(
                        message: l10n.crEmailVerified,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.check_circle,
                            color: AppPalette.brand,
                          ),
                        ),
                      )
                    : FilledButton(
                        onPressed:
                            state.email.isValid &&
                                status == EmailStatus.unverified
                            ? () => unawaited(cubit.send())
                            : null,
                        child: status == EmailStatus.sending
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.brValidate),
                      ),
              ),
            ],
          ),
          if (state.verified)
            Text(
              l10n.crEmailVerified,
              style: textTheme.labelSmall?.copyWith(color: AppPalette.brand),
            ),
        ],
      ),
    );
  }
}

/// The emailed code. Closes itself once confirmed (or when the user backs
/// out).
Future<void> _showEmailCodeDialog(BuildContext context) {
  final cubit = context.read<EmailCodeCubit>();
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) cubit.cancelled();
        },
        child: const _EmailCodeDialog(),
      ),
    ),
  );
}

bool _isCodeStep(EmailStatus status) =>
    status == EmailStatus.codeSent || status == EmailStatus.confirming;

class _EmailCodeDialog extends StatelessWidget {
  const _EmailCodeDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<EmailCodeCubit>();
    final state = context.watch<EmailCodeCubit>().state;
    final failure = state.failure;
    final confirming = state.status == EmailStatus.confirming;

    return BlocListener<EmailCodeCubit, EmailCodeState>(
      listenWhen: (previous, current) =>
          _isCodeStep(previous.status) && !_isCodeStep(current.status),
      listener: (context, _) => Navigator.of(context).pop(),
      child: AppDialog(
        children: [
          Text(
            l10n.crEmailCodeTitle,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(
              color: AppPalette.inkStrong,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            l10n.crEmailCodeMessage(state.email.masked),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppPalette.ink),
          ),
          const SizedBox(height: Spacing.lg),
          AppCodeField(
            length: EmailCodeCubit.codeLength,
            semanticLabel: l10n.baOtpFieldLabel,
            hasError: failure != null,
            onChanged: cubit.codeChanged,
            onSubmitted: (_) => unawaited(cubit.confirm()),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: confirming ? null : () => unawaited(cubit.resend()),
              child: Text('${l10n.resendPrompt} ${l10n.resendAction}'),
            ),
          ),
          if (failure != null)
            Text(
              failure.localize(l10n),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: Spacing.lg),
          AppButton(
            label: l10n.crConfirm,
            isLoading: confirming,
            onPressed:
                state.code.length == EmailCodeCubit.codeLength && !confirming
                ? cubit.confirm
                : null,
          ),
          TextButton(
            onPressed: confirming ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.baCancel),
          ),
        ],
      ),
    );
  }
}
