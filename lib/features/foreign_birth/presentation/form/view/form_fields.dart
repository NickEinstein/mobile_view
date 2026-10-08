part of 'foreign_birth_form_page.dart';

/// Builds a step's labelled inputs. Each input is keyed by its field, so
/// when fields appear or disappear none inherits another's typed text.
class _Fields<F extends Enum> {
  const _Fields({
    required this.l10n,
    required this.valueOf,
    required this.errorOf,
    required this.onChanged,
    this.isLocked = _unlocked,
    this.generation,
  });

  static bool _unlocked(Object? field) => false;

  final AppLocalizations l10n;
  final String? Function(F field) valueOf;

  /// Localized error to show now, if any.
  final String? Function(F field) errorOf;
  final void Function(F field, String? value) onChanged;

  /// Filled from the NIN, so not editable.
  final bool Function(F field) isLocked;

  /// Changes when values are filled in from outside (a validated NIN), so
  /// the inputs show them.
  final Object? generation;

  static final digits = [FilteringTextInputFormatter.digitsOnly];

  /// Letters, spaces, apostrophes and hyphens, as names allow.
  static final name = [
    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'-]")),
    LengthLimitingTextInputFormatter(50),
  ];

  /// No special characters, for places and references.
  static final plain = [
    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9\s,.'/-]")),
    LengthLimitingTextInputFormatter(100),
  ];

  Widget text(
    F field,
    String label,
    String hint, {
    String? note,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) => AppTextField(
    key: ValueKey((field, generation)),
    label: label,
    optionalLabel: note,
    hintText: hint,
    initialValue: valueOf(field),
    enabled: !isLocked(field),
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    textCapitalization: textCapitalization,
    textInputAction: TextInputAction.next,
    errorText: errorOf(field),
    onChanged: (value) => onChanged(field, value.trim()),
  );

  Widget select(F field, String label, List<Option> options, {String? note}) =>
      AppSelectField<String>(
        key: ValueKey(field),
        label: label,
        optionalLabel: note,
        hint: l10n.brSelectOption,
        items: {for (final o in options) o.id: o.label},
        value: valueOf(field),
        errorText: errorOf(field),
        // Nothing to choose yet (e.g. no state picked for an LGA), or
        // locked.
        onChanged: options.isEmpty || isLocked(field)
            ? null
            : (value) => onChanged(field, value),
      );
}

/// Localized [error]: "Required" only after trying to continue. [ages] is
/// the allowed range.
String? _errorText(
  AppLocalizations l10n,
  ForeignBirthFieldError? error, {
  required bool showRequired,
  (int, int)? ages,
}) => switch (error) {
  null => null,
  ForeignBirthFieldError.required when !showRequired => null,
  ForeignBirthFieldError.required => l10n.brRequired,
  ForeignBirthFieldError.futureDate => l10n.brFutureDate,
  ForeignBirthFieldError.invalidNin => l10n.brNinInvalid,
  ForeignBirthFieldError.ninNotVerified => l10n.srNinNotVerified,
  ForeignBirthFieldError.invalidPhone => l10n.fbInvalidPhone,
  ForeignBirthFieldError.invalidEmail => l10n.emailInvalid,
  ForeignBirthFieldError.invalidAge => l10n.srInvalidAge(
    ages?.$1 ?? 0,
    ages?.$2 ?? 0,
  ),
};

/// "Legally Required Fields" / "Additional Fields".
class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppPalette.inkStrong,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
