import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// "Reason for query", in red, on a queried record.
class QueryReasonCard extends StatelessWidget {
  const QueryReasonCard({required this.reason, super.key});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.08),
        border: Border.all(color: error),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sm + Spacing.xs),
        child: MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.brQueryReasonTitle,
                style: textTheme.labelMedium?.copyWith(
                  color: error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Text(reason, style: textTheme.bodySmall?.copyWith(color: error)),
            ],
          ),
        ),
      ),
    );
  }
}
