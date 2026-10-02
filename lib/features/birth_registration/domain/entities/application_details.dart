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
  });

  final BirthApplicationSummary summary;
  final String? childNin;
  final ChildParticulars child;
  final ParentParticulars mother;
  final ParentParticulars father;
  final InformantParticulars informant;
  final SupportingDocuments documents;

  @override
  List<Object?> get props => [
    summary,
    childNin,
    child,
    mother,
    father,
    informant,
    documents,
  ];

  /// Contains personal data: keep it out of logs.
  @override
  String toString() => 'ApplicationDetails(${summary.id})';
}
