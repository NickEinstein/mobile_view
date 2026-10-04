import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_request.dart';

/// The request screen's answers. Proceed is offered once they're complete.
class ModificationRequestCubit extends Cubit<ModificationRequest> {
  ModificationRequestCubit(ModificationKind kind)
    : super(ModificationRequest(kind: kind));

  void typeSelected(ModificationType type) {
    if (type != state.type) emit(state.withType(type));
  }

  void fieldSelected(ModificationField field) {
    if (field != state.field) emit(state.withField(field));
  }

  void reasonSelected(ModificationReason reason) =>
      emit(state.withReason(reason));

  void commentChanged(String comment) => emit(state.withComment(comment));
}
