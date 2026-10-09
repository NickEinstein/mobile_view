import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/features/onboarding/domain/onboarding_repository.dart';

part 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit(this._repository, {required int pageCount})
    : super(OnboardingState(pageCount: pageCount));

  final OnboardingRepository _repository;

  /// Called when the user swipes.
  void pageChanged(int page) => emit(state.copyWith(page: page));

  /// System Back: previous page. On the first page the view lets Back close
  /// the app instead.
  void previous() {
    if (state.page == 0) return;
    emit(state.copyWith(page: state.page - 1));
  }

  /// Next page, or finish on the last one.
  Future<void> next() async {
    if (state.isLastPage) return finish();
    emit(state.copyWith(page: state.page + 1));
  }

  /// Skip or "Get started". Marks onboarding as seen; the router then
  /// redirects to login, so this cubit never navigates.
  Future<void> finish() async {
    if (state.isFinishing) return;
    emit(state.copyWith(isFinishing: true));
    await _repository.markCompleted();
  }
}
