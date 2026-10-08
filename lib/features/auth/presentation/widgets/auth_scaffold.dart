import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

// Layout measured from the Figma "Auth Screen" frames (375pt wide).
const _headerImage = 'assets/images/auth/login_header.jpg';
const _logo = 'assets/images/branding/logo_full.png';
const _headerHeight = 120.0;
const _cardRadius = 32.0;

/// Layout of the sign-in screens: photo header, a card with the form, and
/// actions at the bottom.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.actions,
    this.highlight,
    super.key,
  });

  final String title;

  /// Part of [title] shown in brand green, e.g. "VitalReg" or "Password".
  final String? highlight;
  final String subtitle;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Until the photo is added, a light brand tint shows instead.
          Positioned(
            top: topInset,
            left: 0,
            right: 0,
            height: _headerHeight + _cardRadius,
            child: Image.asset(
              _headerImage,
              fit: BoxFit.cover,
              // The strip shows the head from the portrait photo, as in the
              // designs, rather than its centre.
              alignment: const Alignment(0, -0.8),
              errorBuilder: (_, _, _) =>
                  ColoredBox(color: AppPalette.brand.withValues(alpha: 0.12)),
            ),
          ),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                  child: SizedBox(height: _headerHeight),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(_cardRadius),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Spacing.md,
                          Spacing.xl + Spacing.sm,
                          Spacing.md,
                          Spacing.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Heading(
                              title: title,
                              highlight: highlight,
                              subtitle: subtitle,
                            ),
                            const SizedBox(height: Spacing.xl),
                            body,
                            const Spacer(),
                            const SizedBox(height: Spacing.lg),
                            ...actions,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({
    required this.title,
    required this.highlight,
    required this.subtitle,
  });

  final String title;
  final String? highlight;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final highlight = this.highlight;
    final start = highlight == null ? -1 : title.indexOf(highlight);

    return Column(
      children: [
        Image.asset(_logo, height: 24, semanticLabel: context.l10n.appTitle),
        const SizedBox(height: Spacing.md),
        Text.rich(
          TextSpan(
            children: [
              if (highlight == null || start < 0)
                TextSpan(text: title)
              else ...[
                TextSpan(text: title.substring(0, start)),
                TextSpan(
                  text: highlight,
                  style: const TextStyle(color: AppPalette.brand),
                ),
                TextSpan(text: title.substring(start + highlight.length)),
              ],
            ],
          ),
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(
            color: AppPalette.inkStrong,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(color: AppPalette.muted),
        ),
      ],
    );
  }
}
