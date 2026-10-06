import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_select_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_text_field.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_form.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Builds a step's inputs, keyed by field so none inherits another's text.
class ReissuanceFields<F extends Enum> {
  const ReissuanceFields({
    required this.l10n,
    required this.valueOf,
    required this.errorOf,
    required this.onChanged,
  });

  final AppLocalizations l10n;
  final String? Function(F field) valueOf;

  /// Localized error to show now, if any.
  final String? Function(F field) errorOf;
  final void Function(F field, String? value) onChanged;

  /// Letters, spaces, apostrophes and hyphens, as names allow.
  static final name = [
    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'-]")),
  ];

  /// No special characters, for addresses and places.
  static final plain = [
    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9\s,.'/-]")),
  ];

  Widget text(
    F field,
    String label,
    String hint, {
    String? note,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.words,
    // Rebuilds the field when its value is set from elsewhere (e.g. "same
    // as mother's").
    Object? version,
  }) => AppTextField(
    key: _key(field, version),
    label: label,
    optionalLabel: note,
    hintText: hint,
    initialValue: valueOf(field),
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    textCapitalization: textCapitalization,
    textInputAction: TextInputAction.next,
    errorText: errorOf(field),
    onChanged: (value) => onChanged(field, value.trim()),
  );

  Widget digits(F field, String label, String hint, {required int maxLength}) =>
      text(
        field,
        label,
        hint,
        keyboardType: TextInputType.number,
        textCapitalization: TextCapitalization.none,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(maxLength),
        ],
      );

  Widget select(
    F field,
    String label,
    List<Option> options, {
    String? note,
    bool enabled = true,
    // Tells apart two people's same field on one step (e.g. each parent's).
    Object? version,
  }) => AppSelectField<String>(
    key: _key(field, version),
    label: label,
    optionalLabel: note,
    hint: l10n.brSelectOption,
    items: {for (final o in options) o.id: o.label},
    value: valueOf(field),
    errorText: errorOf(field),
    // Nothing to choose yet (e.g. no state picked for an LGA).
    onChanged: !enabled || options.isEmpty
        ? null
        : (value) => onChanged(field, value),
  );
}

/// A field's key; with a [version], one per person or per filled-in value.
/// (A key's type is part of its identity, so a plain one stays `ValueKey<F>`.)
Key _key<F extends Enum>(F field, Object? version) =>
    version == null ? ValueKey<F>(field) : ValueKey((field, version));

/// Localized [error], or null. "Required" waits until the user tries to
/// continue; invalid values show straight away.
String? reissuanceErrorText(
  BuildContext context,
  ReissuanceFieldError? error, {
  required bool showRequired,
  (int, int)? ageRange,
}) {
  final l10n = context.l10n;
  return switch (error) {
    null => null,
    ReissuanceFieldError.required when !showRequired => null,
    ReissuanceFieldError.required => l10n.brRequired,
    ReissuanceFieldError.tooLate => l10n.crBirthDateTooLate(
      DateFormat.yMMMMd(
        Localizations.localeOf(context).toString(),
      ).format(ReissuanceCodes.latestBirthDate),
    ),
    ReissuanceFieldError.invalidAge => l10n.brInvalidAge(
      ageRange?.$1 ?? 0,
      ageRange?.$2 ?? 0,
    ),
    ReissuanceFieldError.invalidPhone => l10n.crInvalidPhone,
    ReissuanceFieldError.underAge => l10n.crApplicantUnderAge,
    ReissuanceFieldError.invalidEmail => l10n.baInvalidEmail,
  };
}

/// A green section heading, e.g. "Place of Usual Residence", as the
/// designs draw it.
class ReissuanceSectionTitle extends StatelessWidget {
  const ReissuanceSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppPalette.brand,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
