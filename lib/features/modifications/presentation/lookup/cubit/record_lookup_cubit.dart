import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_record.dart';
import 'package:vital_reg_mobile/features/modifications/domain/modifications_repository.dart';

/// "Certificate Number": finds the record to correct, after payment.
class RecordLookupCubit extends Cubit<RecordLookupState> {
  RecordLookupCubit(this._repository, this.kind)
    : super(const RecordLookupState());

  final ModificationsRepository _repository;
  final ModificationKind kind;

  /// Letters and digits only, in capitals.
  void numberChanged(String value) => emit(
    RecordLookupState(
      number: value.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase(),
    ),
  );

  Future<void> lookUp() async {
    if (state.number.isEmpty || state.isLoading) return;
    emit(RecordLookupState(number: state.number, isLoading: true));
    final result = await _repository.findRecord(kind, state.number);
    if (isClosed) return;
    emit(switch (result) {
      Ok(value: final record) => RecordLookupState(
        number: state.number,
        record: record,
      ),
      Err(:final failure) => RecordLookupState(
        number: state.number,
        failure: failure,
      ),
    });
  }
}

final class RecordLookupState extends Equatable {
  const RecordLookupState({
    this.number = '',
    this.isLoading = false,
    this.record,
    this.failure,
  });

  final String number;
  final bool isLoading;

  /// Found: the screen moves on with it.
  final ModificationRecord? record;
  final Failure? failure;

  bool get notFound => failure is NotFoundFailure;

  @override
  List<Object?> get props => [number, isLoading, record, failure];
}
