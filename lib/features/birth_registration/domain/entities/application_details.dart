import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/informant_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/parent_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';

/// A submitted application as recorded on the server.
final class ApplicationDetails extends Equatable {
  const ApplicationDetails({
    required this.summary,
    required this.child,
    required this.mother,
    required this.father,
    required this.informant,
    required this.documents,
    this.childNin,
    this.queryReason,
    this.paymentReference,
    this.faceKey,
    this.documentKeys = const {},
  });

  final BirthApplicationSummary summary;
  final String? childNin;
  final ChildParticulars child;
  final ParentParticulars mother;
  final ParentParticulars father;
  final InformantParticulars informant;
  final SupportingDocuments documents;

  /// The registrar's reason, when [summary]'s status is queried.
  final String? queryReason;

  /// The fee paid with the application, if there was one.
  final String? paymentReference;

  /// Storage keys of the child's face and each document, which a
  /// correction sends back unless they are replaced.
  final String? faceKey;
  final Map<DocumentType, String> documentKeys;

  /// The record as a form to correct and send back, opened on the review.
  /// [now] dates the correction (`dateInitiated`).
  RegistrationDraft toQueriedDraft(DateTime now) => RegistrationDraft(
    startedOn: now,
    childHasNin: childNin != null,
    childNin: childNin,
    step: RegistrationStep.review,
    child: child.set(
      ChildField.facePhoto,
      faceKey == null ? null : serverPath(faceKey!),
    ),
    mother: mother,
    father: father,
    informant: informant
        .set(InformantField.identityMode, IdentityMode.signature.name)
        .set(InformantField.signature, serverPath('')),
    documents: SupportingDocuments({
      for (final MapEntry(key: type, value: key) in documentKeys.entries)
        type: AttachedFile(
          path: serverPath(key),
          name: documents[type]?.name ?? type.apiType,
          sizeBytes: 0,
        ),
    }),
    queried: QueriedRecord(
      recordId: summary.id,
      certificateNumber: summary.trackingId,
      paymentReference: paymentReference,
      reason: queryReason,
    ),
  );

  @override
  List<Object?> get props => [
    summary,
    childNin,
    child,
    mother,
    father,
    informant,
    documents,
    queryReason,
    paymentReference,
    faceKey,
    documentKeys,
  ];

  /// Contains personal data: keep it out of logs.
  @override
  String toString() => 'ApplicationDetails(${summary.id})';
}
