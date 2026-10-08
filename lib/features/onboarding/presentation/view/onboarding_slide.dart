import 'package:vital_reg_mobile/l10n/l10n.dart';

/// The onboarding pages, in order.
enum OnboardingSlide {
  pickService('assets/images/onboarding/onboarding_1.jpg'),
  // Pages 2–4 share one photo in the current designs. If they get their own,
  // add onboarding_3.jpg / onboarding_4.jpg and point to them here.
  fillInformation('assets/images/onboarding/onboarding_2.jpg'),
  trackProgress('assets/images/onboarding/onboarding_2.jpg'),
  receiveRecord('assets/images/onboarding/onboarding_2.jpg');

  const OnboardingSlide(this.image);

  final String image;

  String title(AppLocalizations l10n) => switch (this) {
    OnboardingSlide.pickService => l10n.onboardingPickServiceTitle,
    OnboardingSlide.fillInformation => l10n.onboardingFillInformationTitle,
    OnboardingSlide.trackProgress => l10n.onboardingTrackProgressTitle,
    OnboardingSlide.receiveRecord => l10n.onboardingReceiveRecordTitle,
  };

  String body(AppLocalizations l10n) => switch (this) {
    OnboardingSlide.pickService => l10n.onboardingPickServiceBody,
    OnboardingSlide.fillInformation => l10n.onboardingFillInformationBody,
    OnboardingSlide.trackProgress => l10n.onboardingTrackProgressBody,
    OnboardingSlide.receiveRecord => l10n.onboardingReceiveRecordBody,
  };
}
