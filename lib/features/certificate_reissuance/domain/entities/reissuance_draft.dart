import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/attestation_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';

/// "Mode of validation". Every mode asks for the
/// applicant's NIN.
enum ValidationMode {
  nin('nin'),
  vitalRegPro('vital reg pro'),
  legacyCertificate('Legacy Certificate');

  const ValidationMode(this.apiValue);

  final String apiValue;
}

/// The certificate being replaced, from the "Certificate" step.
final class LegacyCertificate extends Equatable {
  const LegacyCertificate({
    required this.kind,
    required this.number,
    required this.issuedOn,
    required this.filePath,
    required this.fileName,
    required this.sizeBytes,
  });

  factory LegacyCertificate.fromJson(Map<String, Object?> json) =>
      LegacyCertificate(
        kind: ReissuanceKind.values.byName(json['kind']! as String),
        number: json['number']! as String,
        issuedOn: DateTime.parse(json['issuedOn']! as String),
        filePath: json['filePath']! as String,
        fileName: json['fileName']! as String,
        sizeBytes: json['sizeBytes']! as int,
      );

  final ReissuanceKind kind;
  final String number;
  final DateTime issuedOn;

  /// A copy of the old certificate, in private storage until it is sent.
  final String filePath;
  final String fileName;
  final int sizeBytes;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'number': number,
    'issuedOn': issuedOn.toIso8601String(),
    'filePath': filePath,
    'fileName': fileName,
    'sizeBytes': sizeBytes,
  };

  @override
  List<Object?> get props => [
    kind,
    number,
    issuedOn,
    filePath,
    fileName,
    sizeBytes,
  ];
}

/// Where an unfinished request picks up again.
enum ReissuanceStep { face, certificate, form }

/// A reissuance request in progress, kept on the device between steps:
/// the verified NIN, the matched face, then the old certificate.
final class ReissuanceDraft extends Equatable {
  const ReissuanceDraft({
    required this.startedOn,
    required this.mode,
    required this.ninRecord,
    this.facePhoto,
    this.certificate,
    this.birthForm,
    this.attestationForm,
  });

  factory ReissuanceDraft.fromJson(Map<String, Object?> json) =>
      ReissuanceDraft(
        startedOn: DateTime.parse(json['startedOn']! as String),
        mode: ValidationMode.values.byName(json['mode']! as String),
        ninRecord: ApplicantNinRecord.fromJson(
          (json['ninRecord']! as Map).cast<String, Object?>(),
        ),
        facePhoto: json['facePhoto'] as String?,
        certificate: switch (json['certificate']) {
          final Map<Object?, Object?> map => LegacyCertificate.fromJson(
            map.cast<String, Object?>(),
          ),
          _ => null,
        },
        birthForm: switch (json['birthForm']) {
          final Map<Object?, Object?> map => BirthReissuanceForm.fromJson(
            map.cast<String, Object?>(),
          ),
          _ => null,
        },
        attestationForm: switch (json['attestationForm']) {
          final Map<Object?, Object?> map => AttestationReissuanceForm.fromJson(
            map.cast<String, Object?>(),
          ),
          _ => null,
        },
      );

  final DateTime startedOn;
  final ValidationMode mode;

  /// Whose certificate it is; it prefills the form.
  final ApplicantNinRecord ninRecord;

  /// Matched against the NIN photo; in private storage.
  final String? facePhoto;
  final LegacyCertificate? certificate;

  /// Once a birth certificate's form is opened.
  final BirthReissuanceForm? birthForm;

  /// Once an attestation certificate's form is opened.
  final AttestationReissuanceForm? attestationForm;

  ReissuanceDraft withFace(String photo) => ReissuanceDraft(
    startedOn: startedOn,
    mode: mode,
    ninRecord: ninRecord,
    facePhoto: photo,
    certificate: certificate,
    birthForm: birthForm,
    attestationForm: attestationForm,
  );

  ReissuanceDraft withCertificate(LegacyCertificate certificate) =>
      ReissuanceDraft(
        startedOn: startedOn,
        mode: mode,
        ninRecord: ninRecord,
        facePhoto: facePhoto,
        certificate: certificate,
        birthForm: birthForm,
        attestationForm: attestationForm,
      );

  ReissuanceDraft withBirthForm(BirthReissuanceForm form) => ReissuanceDraft(
    startedOn: startedOn,
    mode: mode,
    ninRecord: ninRecord,
    facePhoto: facePhoto,
    certificate: certificate,
    birthForm: form,
    attestationForm: attestationForm,
  );

  ReissuanceDraft withAttestationForm(AttestationReissuanceForm form) =>
      ReissuanceDraft(
        startedOn: startedOn,
        mode: mode,
        ninRecord: ninRecord,
        facePhoto: facePhoto,
        certificate: certificate,
        birthForm: birthForm,
        attestationForm: form,
      );

  ReissuanceStep get nextStep => facePhoto == null
      ? ReissuanceStep.face
      : certificate == null
      ? ReissuanceStep.certificate
      : ReissuanceStep.form;

  /// Every file the draft keeps, to delete with it.
  List<String> get files => [
    ?facePhoto,
    ?certificate?.filePath,
    ...?birthForm?.files,
    ...?attestationForm?.files,
  ];

  Map<String, Object?> toJson() => {
    'startedOn': startedOn.toIso8601String(),
    'mode': mode.name,
    'ninRecord': ninRecord.toJson(),
    'facePhoto': facePhoto,
    'certificate': certificate?.toJson(),
    'birthForm': birthForm?.toJson(),
    'attestationForm': attestationForm?.toJson(),
  };

  @override
  List<Object?> get props => [
    startedOn,
    mode,
    ninRecord,
    facePhoto,
    certificate,
    birthForm,
    attestationForm,
  ];

  /// Personal data: keep it out of logs.
  @override
  String toString() =>
      'ReissuanceDraft(face: ${facePhoto != null}, '
      'certificate: ${certificate?.kind.name})';
}
