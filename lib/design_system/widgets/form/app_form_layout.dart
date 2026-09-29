import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';

/// Title, start date, segmented progress bar, "Step n of N · Step name".
class AppFormHeader extends StatelessWidget {
  const AppFormHeader({
    required this.title,
    required this.startedOn,
    required this.step,
    required this.stepCount,
    required this.stepOf,
    required this.stepName,
    super.key,
  });

  final String title;
  final DateTime startedOn;

  /// 1-based.
  final int step;
  final int stepCount;

  /// "Step 2 of 4".
  final String stepOf;
  final String stepName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleLarge?.copyWith(
              color: AppPalette.inkStrong,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            DateFormat.yMMMMd(locale).format(startedOn),
            style: textTheme.labelSmall?.copyWith(color: AppPalette.muted),
          ),
          const SizedBox(height: Spacing.md),
          Semantics(
            label: stepOf,
            child: ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 1; i <= stepCount; i++) ...[
                    if (i > 1) const SizedBox(width: Spacing.xs),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= step
                              ? AppPalette.brand
                              : AppPalette.cardBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Row(
            children: [
              Text(
                stepOf,
                style: textTheme.labelSmall?.copyWith(
                  color: AppPalette.inkStrong,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  stepName,
                  textAlign: TextAlign.end,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppPalette.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A step's title and the line under it.
class AppStepTitle extends StatelessWidget {
  const AppStepTitle({required this.title, required this.hint, super.key});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            color: AppPalette.inkStrong,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          hint,
          style: textTheme.labelSmall?.copyWith(color: AppPalette.muted),
        ),
      ],
    );
  }
}

/// A heading inside a step, e.g. "Place of Residence".
class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle(this.text, {super.key});

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

/// Stacks a step's inputs under its header with even spacing.
class AppFieldColumn extends StatelessWidget {
  const AppFieldColumn({required this.header, required this.fields, super.key});

  final Widget header;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      header,
      const SizedBox(height: Spacing.lg),
      for (final field in fields) ...[
        field,
        const SizedBox(height: Spacing.md),
      ],
    ],
  );
}

/// The buttons under each step: Previous (after the first), the primary
/// button, and "Exit Application".
class AppFormActions extends StatelessWidget {
  const AppFormActions({
    required this.primaryLabel,
    required this.onPrimary,
    required this.exitLabel,
    required this.onExit,
    this.previousLabel,
    this.onPrevious,
    this.primaryMuted = false,
    this.isLoading = false,
    this.progress,
    this.progressLabel,
    super.key,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;

  /// Looks disabled but still responds, so a tap can show what's missing.
  final bool primaryMuted;
  final bool isLoading;

  /// Null on the first step, which has no Previous.
  final String? previousLabel;
  final VoidCallback? onPrevious;
  final String exitLabel;
  final VoidCallback onExit;

  /// Upload progress, 0–1, shown above the buttons while [isLoading].
  final double? progress;
  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    final primary = AppButton(
      label: primaryLabel,
      muted: primaryMuted,
      isLoading: isLoading,
      onPressed: onPrimary,
    );
    final previousLabel = this.previousLabel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading) ...[
            LinearProgressIndicator(
              value: progress,
              semanticsLabel: progressLabel,
            ),
            const SizedBox(height: Spacing.sm),
          ],
          if (previousLabel == null)
            primary
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.inkStrong,
                    ),
                    onPressed: isLoading ? null : onPrevious,
                    child: Text(previousLabel),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(child: primary),
              ],
            ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppPalette.inkStrong),
            onPressed: isLoading ? null : onExit,
            child: Text(exitLabel),
          ),
        ],
      ),
    );
  }
}
