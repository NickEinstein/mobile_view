import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';

/// Outcome of an operation that can fail in an expected way; callers must
/// handle both branches.
sealed class Result<T> extends Equatable {
  const Result();

  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  List<Object?> get props => [value];
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
