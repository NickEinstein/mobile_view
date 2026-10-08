import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/features/onboarding/domain/onboarding_repository.dart';
import 'package:vital_reg_mobile/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_reg_mobile/features/onboarding/presentation/view/onboarding_slide.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

// Layout measured from the Figma frames (375pt wide).
const _buttonHeight = 64.0;
const _dotSize = 8.0;
const _dotsToButton = 56.0;
const _textToDots = 32.0;

/// Space the slide text leaves for the fixed dots and button below it.
const _textBottomInset =
    Spacing.md + _buttonHeight + _dotsToButton + _dotSize + _textToDots;

/// Composition only: provides the cubit. All UI lives in [OnboardingView].
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OnboardingCubit(
        GetIt.instance<OnboardingRepository>(),
        pageCount: OnboardingSlide.values.length,
      ),
      child: const OnboardingView(),
    );
  }
}

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Animates the pager when the cubit moves (Next). Swipes already match.
  void _syncPage(BuildContext context, OnboardingState state) {
    if (!_controller.hasClients || _controller.page?.round() == state.page) {
      return;
    }
    unawaited(
      _controller.animateToPage(
        state.page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFirstPage = context.select(
      (OnboardingCubit cubit) => cubit.state.page == 0,
    );
    return BlocListener<OnboardingCubit, OnboardingState>(
      listenWhen: (previous, current) => previous.page != current.page,
      listener: _syncPage,
      // Back steps through the pages; only the first page lets it close
      // the app.
      child: PopScope(
        canPop: isFirstPage,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.read<OnboardingCubit>().previous();
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              PageView(
                controller: _controller,
                onPageChanged: context.read<OnboardingCubit>().pageChanged,
                children: [
                  for (final slide in OnboardingSlide.values)
                    _SlideView(slide: slide),
                ],
              ),
              // Fixed controls. Empty areas let swipes through to the pager.
              const SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    Spacing.md,
                    Spacing.sm,
                    Spacing.md,
                    Spacing.md,
                  ),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: _SkipButton(),
                      ),
                      Spacer(),
                      _PageDots(),
                      SizedBox(height: _dotsToButton),
                      _NextButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Until the photo is added, the plain background shows instead.
        Image.asset(
          slide.image,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        ColoredBox(color: Colors.white.withValues(alpha: 0.7)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              0,
              Spacing.md,
              _textBottomInset,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slide.title(l10n),
                    style: textTheme.headlineSmall?.copyWith(
                      color: AppPalette.brand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    slide.body(l10n),
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppPalette.ink,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton();

  @override
  Widget build(BuildContext context) {
    final isLastPage = context.select(
      (OnboardingCubit cubit) => cubit.state.isLastPage,
    );
    // Hidden on the last page, where the main button finishes instead.
    // Space is kept so nothing shifts.
    return Visibility(
      visible: !isLastPage,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: TextButton(
        onPressed: () => unawaited(context.read<OnboardingCubit>().finish()),
        child: Text(
          context.l10n.onboardingSkip,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppPalette.ink),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots();

  @override
  Widget build(BuildContext context) {
    final (page, count) = context.select(
      (OnboardingCubit cubit) => (cubit.state.page, cubit.state.pageCount),
    );
    return Semantics(
      label: context.l10n.onboardingPageIndicator(page + 1, count),
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: Spacing.xs),
                width: i == page ? _dotSize * 2.5 : _dotSize,
                height: _dotSize,
                decoration: BoxDecoration(
                  color: i == page
                      ? AppPalette.brand
                      : AppPalette.brand.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(_dotSize / 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-width pill with a white arrow disc on the right, as in the designs.
class _NextButton extends StatelessWidget {
  const _NextButton();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (isLastPage, isFinishing) = context.select(
      (OnboardingCubit cubit) =>
          (cubit.state.isLastPage, cubit.state.isFinishing),
    );
    final cubit = context.read<OnboardingCubit>();
    return Material(
      color: AppPalette.brand,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isFinishing ? null : () => unawaited(cubit.next()),
        child: SizedBox(
          width: double.infinity,
          height: _buttonHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                isLastPage ? l10n.onboardingGetStarted : l10n.onboardingNext,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Positioned(
                right: Spacing.sm + 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 44,
                    child: Icon(Icons.arrow_forward, color: AppPalette.brand),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
