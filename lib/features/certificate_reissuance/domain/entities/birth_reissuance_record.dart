import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/attestation_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';

/// The certificate being replaced and whose it is.
typedef CertificateFacts = ({
  ReissuanceKind kind,
  String number,
  DateTime issuedOn,
  String nin,
});

/// Why a request was queried, as the approver wrote it.
final class ReissuanceQuery extends Equatable {
  const ReissuanceQuery({this.title, this.reason});

  final String? title;
  final String? reason;

  @override
  List<Object?> get props => [title, reason];
}

/// A birth request as sent.
typedef BirthReissuanceRecord = ReissuanceRecord<BirthReissuanceForm>;

/// An attestation request as sent.
typedef AttestationReissuanceRecord =
    ReissuanceRecord<AttestationReissuanceForm>;

/// A reissuance request as sent; [F] is the kind's form.
final class ReissuanceRecord<F extends Object> extends Equatable {
  const ReissuanceRecord({
    required this.id,
    required this.status,
    required this.reference,
    required this.nin,
    required this.certificateNumber,
    required this.issuedOn,
    required this.certificateKey,
    required this.form,
    this.faceKey,
    this.faceUrl,
    this.query,
    this.createdOn,
  });

  final String id;
  final ReissuanceStatus status;

  /// The payment reference; a correction is sent with the same one.
  final String reference;
  final String nin;
  final String certificateNumber;
  final DateTime issuedOn;

  /// The old certificate's copy, in storage.
  final String certificateKey;

  /// The answers, with files already sent as [KeptFile]s.
  final F form;

  /// The child's or applicant's face, in storage, and a link to show it
  /// (it expires).
  final String? faceKey;
  final Uri? faceUrl;

  /// Only for a queried request.
  final ReissuanceQuery? query;
  final DateTime? createdOn;

  ReissuanceRecord<F> withForm(F form) => ReissuanceRecord(
    id: id,
    status: status,
    reference: reference,
    nin: nin,
    certificateNumber: certificateNumber,
    issuedOn: issuedOn,
    certificateKey: certificateKey,
    form: form,
    faceKey: faceKey,
    faceUrl: faceUrl,
    query: query,
    createdOn: createdOn,
  );

  @override
  List<Object?> get props => [
    id,
    status,
    reference,
    nin,
    certificateNumber,
    issuedOn,
    certificateKey,
    form,
    faceKey,
    faceUrl,
    query,
    createdOn,
  ];

  /// Personal data: keep it out of logs.
  @override
  String toString() => 'ReissuanceRecord<$F>($id, ${status.name})';
}
