import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/design_system/icons/app_icons.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';

/// Count card with a tinted icon, as on the dashboards. Selected cards are
/// green; tapping one usually filters what's shown below the grid.
class AppStatCard extends StatelessWidget {
  const AppStatCard({
    required this.icon,
    required this.color,
    required this.count,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final AppIcons icon;
  final Color color;
  final int count;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppPalette.selectedCardFill : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Spacing.sm),
          side: BorderSide(
            color: selected
                ? AppPalette.selectedCardBorder
                : AppPalette.cardBorder,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.sm + Spacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: AppIcon(icon, size: 17, color: color),
                ),
                const Spacer(),
                Text(
                  '$count',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppPalette.inkStrong,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppPalette.ink,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
