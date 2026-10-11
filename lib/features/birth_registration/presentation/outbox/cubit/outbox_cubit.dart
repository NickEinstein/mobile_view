import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/storage/outbox.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/birth_registration_repository.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/outbox_sync.dart';

/// Applications saved offline, as they are sent.
class OutboxCubit extends Cubit<OutboxState> {
  OutboxCubit(this._repository, this._sync) : super(const OutboxState()) {
    _sync.addListener(_syncChanged);
  }

  final BirthRegistrationRepository _repository;
  final OutboxSync _sync;

  Future<void> load() async {
    final entries = await _repository.outbox();
    if (isClosed) return;
    emit(
      state.copyWith(
        isLoaded: true,
        entries: entries,
        sendingId: () => _sync.sendingId,
        isSending: _sync.isRunning,
      ),
    );
  }

  /// Each entry sent or turned down changes the list.
  void _syncChanged() => unawaited(load());

  Future<void> sendAll() => _sync.syncAll();

  Future<void> send(String id) => _sync.syncOne(id);

  Future<void> remove(String id) async {
    await _repository.removeFromOutbox(id);
    await load();
  }

  @override
  Future<void> close() {
    _sync.removeListener(_syncChanged);
    return super.close();
  }
}

final class OutboxState extends Equatable {
  const OutboxState({
    this.isLoaded = false,
    this.entries = const [],
    this.sendingId,
    this.isSending = false,
  });

  final bool isLoaded;
  final List<OutboxEntry<RegistrationDraft>> entries;

  /// The entry being sent right now.
  final String? sendingId;
  final bool isSending;

  OutboxState copyWith({
    bool? isLoaded,
    List<OutboxEntry<RegistrationDraft>>? entries,
    String? Function()? sendingId,
    bool? isSending,
  }) => OutboxState(
    isLoaded: isLoaded ?? this.isLoaded,
    entries: entries ?? this.entries,
    sendingId: sendingId != null ? sendingId() : this.sendingId,
    isSending: isSending ?? this.isSending,
  );

  @override
  List<Object?> get props => [isLoaded, entries, sendingId, isSending];
}
