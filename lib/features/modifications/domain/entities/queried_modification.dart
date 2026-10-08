import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_documents.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_record.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_request.dart';

/// A modification request sent back by a reviewer, with why. It is
/// corrected and sent again under the same [paymentReference]; no new fee.
final class QueriedModification extends Equatable {
  const QueriedModification({
    required this.id,
    required this.request,
    required this.record,
    required this.paymentReference,
    required this.queryReason,
    this.documents = const {},
  });

  /// The modification request's own id.
  final String id;
  final ModificationRequest request;

  /// The record, holding the values the request was sent with.
  final ModificationRecord record;
  final String paymentReference;

  /// What the reviewer said.
  final String queryReason;
  final Map<ModificationDocument, UploadedFile> documents;

  @override
  List<Object?> get props => [
    id,
    request,
    record,
    paymentReference,
    queryReason,
    documents,
  ];

  @override
  String toString() => 'QueriedModification(${request.kind.name})';
}
