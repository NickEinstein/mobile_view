import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_draft.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/reissuance_repository.dart';

enum CertificateError {
  typeRequired,
  numberRequired,
  numberInvalid,
  issuedDateRequired,
  issuedDateTooLate,
  fileRequired,
}

/// The old certificate: type (which picks the form), number, issue date
/// and a copy.
class LegacyCertificateCubit extends Cubit<LegacyCertificateState> {
  LegacyCertificateCubit(this._repository)
    : super(const LegacyCertificateState());

  /// The e-CRVS commission date: only certificates issued before it are
  /// reissued here.
  static final latestIssueDate = DateTime(2023, 11, 8);

  static final _numberPattern = RegExp(r'^[A-Za-z0-9/-]+$');

  final ReissuanceRepository _repository;
  ReissuanceDraft? _draft;

  Future<void> load() async {
    final draft = _draft = await _repository.loadDraft();
    if (isClosed) return;
    final saved = draft?.certificate;
    emit(
      LegacyCertificateState(
        isLoading: false,
        missingApplication: draft == null,
        kind: saved?.kind,
        number: saved?.number ?? '',
        issuedOn: saved?.issuedOn,
        file: saved == null
            ? null
            : (
                path: saved.filePath,
                name: saved.fileName,
                sizeBytes: saved.sizeBytes,
              ),
      ),
    );
  }

  void kindChanged(ReissuanceKind? kind) =>
      emit(state.copyWith(kind: () => kind));

  void numberChanged(String number) =>
      emit(state.copyWith(number: number.trim()));

  void issuedOnChanged(DateTime date) =>
      emit(state.copyWith(issuedOn: () => date));

  /// Why the file can't be attached, if it can't.
  Future<DocumentError?> filePicked({
    required String path,
    required String name,
    required int sizeBytes,
  }) async {
    final error = SupportingDocuments.check(name, sizeBytes);
    if (error != null) return error;
    final kept = await _repository.keepDocument(
      path,
      replacing: _unsaved(state.file?.path),
    );
    if (isClosed) {
      await _repository.deleteFile(kept);
      return null;
    }
    emit(
      state.copyWith(
        file: () => (path: kept, name: name, sizeBytes: sizeBytes),
      ),
    );
    return null;
  }

  Future<void> fileRemoved() async {
    final path = _unsaved(state.file?.path);
    emit(state.copyWith(file: () => null));
    if (path != null) await _repository.deleteFile(path);
  }

  /// "Validate": keeps the certificate in the request, or shows what's
  /// missing.
  Future<void> validate() async {
    final draft = _draft;
    if (draft == null || state.isSaving || state.isDone) return;
    if (state.errors.isNotEmpty) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    emit(state.copyWith(isSaving: true));
    final file = state.file!;
    final previous = draft.certificate?.filePath;
    final next = draft.withCertificate(
      LegacyCertificate(
        kind: state.kind!,
        number: state.number,
        issuedOn: state.issuedOn!,
        filePath: file.path,
        fileName: file.name,
        sizeBytes: file.sizeBytes,
      ),
    );
    await _repository.saveDraft(next);
    _draft = next;
    if (previous != null && previous != file.path) {
      await _repository.deleteFile(previous);
    }
    if (isClosed) return;
    emit(state.copyWith(isSaving: false, isDone: true));
  }

  /// [path], unless the request already keeps it.
  String? _unsaved(String? path) =>
      path == null || path == _draft?.certificate?.filePath ? null : path;

  /// A copy picked but never kept in the request isn't needed once the
  /// user leaves.
  @override
  Future<void> close() async {
    final path = _unsaved(state.file?.path);
    if (path != null && !state.isDone) await _repository.deleteFile(path);
    return super.close();
  }
}

typedef PickedFile = ({String path, String name, int sizeBytes});

final class LegacyCertificateState extends Equatable {
  const LegacyCertificateState({
    this.isLoading = true,
    this.missingApplication = false,
    this.kind,
    this.number = '',
    this.issuedOn,
    this.file,
    this.showErrors = false,
    this.isSaving = false,
    this.isDone = false,
  });

  final bool isLoading;

  /// No request was started (e.g. a deep link); the page can't continue.
  final bool missingApplication;
  final ReissuanceKind? kind;
  final String number;
  final DateTime? issuedOn;

  /// The old certificate's copy, in private storage.
  final PickedFile? file;

  /// After a "Validate" with something missing.
  final bool showErrors;
  final bool isSaving;

  /// Kept in the request; the page moves on to the form.
  final bool isDone;

  Set<CertificateError> get errors {
    final date = issuedOn;
    return {
      if (kind == null) CertificateError.typeRequired,
      if (number.isEmpty)
        CertificateError.numberRequired
      else if (!LegacyCertificateCubit._numberPattern.hasMatch(number))
        CertificateError.numberInvalid,
      if (date == null)
        CertificateError.issuedDateRequired
      else if (date.isAfter(LegacyCertificateCubit.latestIssueDate))
        CertificateError.issuedDateTooLate,
      if (file == null) CertificateError.fileRequired,
    };
  }

  /// [kind], [issuedOn] and [file] are functions so they can be cleared.
  LegacyCertificateState copyWith({
    ReissuanceKind? Function()? kind,
    String? number,
    DateTime? Function()? issuedOn,
    PickedFile? Function()? file,
    bool? showErrors,
    bool? isSaving,
    bool? isDone,
  }) => LegacyCertificateState(
    isLoading: isLoading,
    missingApplication: missingApplication,
    kind: kind != null ? kind() : this.kind,
    number: number ?? this.number,
    issuedOn: issuedOn != null ? issuedOn() : this.issuedOn,
    file: file != null ? file() : this.file,
    showErrors: showErrors ?? this.showErrors,
    isSaving: isSaving ?? this.isSaving,
    isDone: isDone ?? this.isDone,
  );

  @override
  List<Object?> get props => [
    isLoading,
    missingApplication,
    kind,
    number,
    issuedOn,
    file,
    showErrors,
    isSaving,
    isDone,
  ];
}
