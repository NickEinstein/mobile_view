import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_documents.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_request.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/record_edit.dart';

/// A modification request; with a [modificationId], a queried request's
/// resend.
final class ModificationSubmission extends Equatable {
  const ModificationSubmission({
    required this.request,
    required this.edit,
    required this.paymentReference,
    this.documents = const ModificationDocuments(),
    this.modificationId,
  });

  final ModificationRequest request;
  final RecordEdit edit;
  final String paymentReference;
  final ModificationDocuments documents;

  /// The queried request this corrects; null for a new one.
  final String? modificationId;

  @override
  List<Object?> get props => [
    request,
    edit,
    paymentReference,
    documents,
    modificationId,
  ];

  @override
  String toString() => 'ModificationSubmission(${request.kind.name})';
}
