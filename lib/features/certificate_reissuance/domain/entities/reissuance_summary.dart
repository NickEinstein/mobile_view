import 'package:equatable/equatable.dart';

/// Which certificate is reissued: the home's two tabs, and the
/// "Certificate Type" of a new request.
enum ReissuanceKind {
  birth('birth-reg', 'birth_reissuance'),
  attestation('birth-attest', 'attest_reissuance');

  const ReissuanceKind(this.apiPath, this.certType);

  /// In the API's paths, e.g. `/certificate-reissuance-assisted/birth-reg-list`.
  final String apiPath;

  /// The API's `certType`.
  final String certType;
}

/// Where a reissuance request is. The API sends 0, 1 or 2.
enum ReissuanceStatus { pending, approved, queried }

/// The home's four cards.
final class ReissuanceCounts extends Equatable {
  const ReissuanceCounts({
    this.total = 0,
    this.pending = 0,
    this.approved = 0,
    this.queried = 0,
  });

  final int total;
  final int pending;
  final int approved;
  final int queried;

  /// [status] null is the total.
  int of(ReissuanceStatus? status) => switch (status) {
    null => total,
    ReissuanceStatus.pending => pending,
    ReissuanceStatus.approved => approved,
    ReissuanceStatus.queried => queried,
  };

  @override
  List<Object?> get props => [total, pending, approved, queried];
}

/// One row in the Reissuance list.
final class ReissuanceSummary extends Equatable {
  const ReissuanceSummary({
    required this.id,
    required this.name,
    required this.reference,
    required this.status,
    this.createdOn,
  });

  final String id;

  /// The child's or applicant's name.
  final String name;

  /// The payment reference; the certificate is downloaded by it.
  final String reference;
  final ReissuanceStatus status;
  final DateTime? createdOn;

  @override
  List<Object?> get props => [id, name, reference, status, createdOn];
}
