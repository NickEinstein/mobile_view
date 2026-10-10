import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/offline/offline_mode.dart';
import 'package:vital_reg_mobile/core/offline/pending_sends.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/core/storage/outbox.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/birth_registration_repository.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/informant_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/parent_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';

/// Whose identity a sync check was about.
enum SyncPerson { child, mother, father, informant }

enum SyncCheck {
  ninNotFound,
  ninNameMismatch,
  trackingIdNotFound,
  trackingIdNameMismatch,
}

/// A check that failed during sync, kept as the entry's message.
final class SyncProblem {
  const SyncProblem(this.check, this.person);

  /// The problem a [message] holds, or null for a server's own message.
  static SyncProblem? of(String? message) {
    final parts = message?.split(':');
    if (parts == null || parts.length != 3 || parts.first != _prefix) {
      return null;
    }
    final check = SyncCheck.values.asNameMap()[parts[1]];
    final person = SyncPerson.values.asNameMap()[parts[2]];
    return check == null || person == null ? null : SyncProblem(check, person);
  }

  static const _prefix = 'check';

  final SyncCheck check;
  final SyncPerson person;

  String get message => '$_prefix:${check.name}:${person.name}';
}

/// Sends the outbox's applications, oldest first, one at a time. Each is
/// checked first (NINs and tracking ID against the names given), then its
/// files are uploaded and it is sent. It tries again every [interval],
/// when the app comes back to the foreground and when offline mode is
/// switched.
class OutboxSync extends ChangeNotifier implements PendingSends {
  OutboxSync(
    this._repository,
    this._offlineMode, {
    required bool Function() isSignedIn,
    this.interval = const Duration(minutes: 2),
    DateTime Function()? now,
  }) : _isSignedIn = isSignedIn,
       _now = now ?? DateTime.now;

  final BirthRegistrationRepository _repository;
  final OfflineMode _offlineMode;
  final bool Function() _isSignedIn;
  final Duration interval;
  final DateTime Function() _now;

  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  Future<void>? _running;

  /// Set by the server's rate limit; nothing is sent before then.
  DateTime? _pausedUntil;

  String? _sendingId;

  /// The entry being sent, if any.
  String? get sendingId => _sendingId;

  bool get isRunning => _running != null;

  /// Starts the automatic retries.
  void start() {
    _timer ??= Timer.periodic(interval, (_) => unawaited(_retry()));
    _lifecycle ??= AppLifecycleListener(onResume: () => unawaited(_retry()));
    _offlineMode.addListener(_modeChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
    _offlineMode.removeListener(_modeChanged);
    super.dispose();
  }

  void _modeChanged() => unawaited(syncAll());

  @override
  Future<int> count() async => (await _repository.outbox()).length;

  @override
  Future<void> sendNow() => syncAll();

  Future<void> _retry() async {
    if (_isSignedIn()) await syncAll();
  }

  /// Sends every entry waiting or due for a retry. A run already under way
  /// is joined, not repeated.
  Future<void> syncAll() => _run(
    (entry) =>
        entry.status == OutboxStatus.waiting ||
        entry.status == OutboxStatus.retryLater,
  );

  /// Sends one entry, even one that needed fixing (e.g. after a check
  /// service was down). A possible duplicate is never sent again.
  Future<void> syncOne(String id) => _run(
    (entry) => entry.id == id && entry.status != OutboxStatus.possibleDuplicate,
  );

  Future<void> _run(bool Function(OutboxEntry<RegistrationDraft>) which) {
    if (_running case final running?) return running;
    if (!_isSignedIn()) return Future.value();
    if (_pausedUntil case final until? when _now().isBefore(until)) {
      return Future.value();
    }
    final run = _sendAll(which).whenComplete(() {
      _running = null;
      _sendingId = null;
      notifyListeners();
    });
    _running = run;
    notifyListeners();
    return run;
  }

  Future<void> _sendAll(
    bool Function(OutboxEntry<RegistrationDraft>) which,
  ) async {
    for (final entry in await _repository.outbox()) {
      if (!which(entry)) continue;
      if (!_isSignedIn()) return;
      _sendingId = entry.id;
      notifyListeners();
      if (!await _send(entry)) return;
    }
  }

  /// Returns whether to go on with the next entry.
  Future<bool> _send(OutboxEntry<RegistrationDraft> entry) async {
    var current = entry;
    Future<void> save(OutboxEntry<RegistrationDraft> next) {
      current = next;
      return _repository.updateOutbox(next);
    }

    for (final check in _checksOf(entry.item)) {
      if (current.progress.containsKey(check.key)) continue;
      final result = await check.run(_repository);
      switch (result) {
        case Ok(value: final name):
          if (!_sameName(name, check.expected)) {
            await save(_needsFix(current, check.mismatch.message));
            return true;
          }
          await save(
            current.copyWith(progress: {...current.progress, check.key: 'ok'}),
          );
        case Err(failure: NotFoundFailure() || ValidationFailure()):
          await save(_needsFix(current, check.notFound.message));
          return true;
        case Err(:final failure):
          return _failed(current, failure, save);
      }
    }

    final result = await _repository.submit(
      current.item,
      uploaded: current.progress,
      onUploaded: (path, key) => unawaited(
        save(current.copyWith(progress: {...current.progress, path: key})),
      ),
    );
    switch (result) {
      case Ok():
        await _repository.removeFromOutbox(entry.id);
        return true;
      case Err(:final failure):
        return _failed(current, failure, save);
    }
  }

  static OutboxEntry<RegistrationDraft> _needsFix(
    OutboxEntry<RegistrationDraft> entry,
    String? message,
  ) => entry.copyWith(status: OutboxStatus.needsFix, message: () => message);

  /// Records why [entry] wasn't sent. Returns whether to go on with the
  /// next entry: not without a connection, a session or the server's leave.
  Future<bool> _failed(
    OutboxEntry<RegistrationDraft> entry,
    Failure failure,
    Future<void> Function(OutboxEntry<RegistrationDraft>) save,
  ) async {
    switch (failure) {
      case ValidationFailure(:final message)
          when message != null && _duplicate.hasMatch(message):
        await save(
          entry.copyWith(
            status: OutboxStatus.possibleDuplicate,
            message: () => message,
          ),
        );
        return true;
      case ValidationFailure(:final message) ||
          ForbiddenFailure(:final message) ||
          NotFoundFailure(:final message):
        await save(_needsFix(entry, message));
        return true;
      case ServerFailure(:final message) || UnexpectedFailure(:final message):
        await save(
          entry.copyWith(
            status: OutboxStatus.retryLater,
            message: () => message,
          ),
        );
        return true;
      case RateLimitedFailure(:final retryAfter):
        _pausedUntil = _now().add(retryAfter);
        await save(entry.copyWith(status: OutboxStatus.retryLater));
        return false;
      case NetworkFailure() || TimeoutFailure() || CancelledFailure():
        await save(
          entry.copyWith(status: OutboxStatus.retryLater, message: () => null),
        );
        return false;
      case UnauthorizedFailure():
        return false;
    }
  }

  /// The server's answer when a matching record exists (its unique key).
  static final _duplicate = RegExp('must be unique', caseSensitive: false);

  static String _normal(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Both the surname and the first name must match.
  static bool _sameName(PersonName found, PersonName given) =>
      _normal(found.surname) == _normal(given.surname) &&
      _normal(found.firstName) == _normal(given.firstName);

  static List<_Check> _checksOf(RegistrationDraft draft) {
    final informant = draft.informant;
    PersonName parentName(ParentRole role) => (
      surname: draft.parentOf(role)[ParentField.surname] ?? '',
      firstName: draft.parentOf(role)[ParentField.firstName] ?? '',
    );
    final informantName = (
      surname: informant[InformantField.surname] ?? '',
      firstName: informant[InformantField.firstName] ?? '',
    );
    return [
      if (draft.childNin case final nin? when draft.childHasNin ?? false)
        _Check.nin(SyncPerson.child, nin, (
          surname: draft.child[ChildField.surname] ?? '',
          firstName: draft.child[ChildField.firstName] ?? '',
        )),
      if (_given(draft.mother[ParentField.nin]) case final nin?)
        _Check.nin(SyncPerson.mother, nin, parentName(ParentRole.mother)),
      if (_given(draft.father[ParentField.nin]) case final nin?)
        _Check.nin(SyncPerson.father, nin, parentName(ParentRole.father)),
      if (_given(informant[InformantField.nin]) case final nin?)
        _Check.nin(SyncPerson.informant, nin, informantName),
      if (_given(informant[InformantField.trackingId]) case final id?)
        _Check.trackingId(id, informantName),
    ];
  }

  static String? _given(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

/// One identity check: the record found must carry the [expected] name.
final class _Check {
  _Check.nin(SyncPerson person, String nin, this.expected)
    : key = 'check:nin:$nin:${_keyOf(expected)}',
      run = ((repository) async => switch (await repository.verifyNin(nin)) {
        Ok(value: final record) => Ok((
          surname: record.surname,
          firstName: record.firstName,
        )),
        Err(:final failure) => Err(failure),
      }),
      notFound = SyncProblem(SyncCheck.ninNotFound, person),
      mismatch = SyncProblem(SyncCheck.ninNameMismatch, person);

  _Check.trackingId(String id, this.expected)
    : key = 'check:tracking:$id:${_keyOf(expected)}',
      run = ((repository) => repository.verifyTrackingId(id)),
      notFound = const SyncProblem(
        SyncCheck.trackingIdNotFound,
        SyncPerson.informant,
      ),
      mismatch = const SyncProblem(
        SyncCheck.trackingIdNameMismatch,
        SyncPerson.informant,
      );

  /// Includes the names, so editing them checks again.
  final String key;
  final PersonName expected;
  final Future<Result<PersonName>> Function(BirthRegistrationRepository) run;
  final SyncProblem notFound;
  final SyncProblem mismatch;

  static String _keyOf(PersonName name) =>
      '${name.surname.trim().toLowerCase()}:'
      '${name.firstName.trim().toLowerCase()}';
}
