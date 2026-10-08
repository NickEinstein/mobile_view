import 'package:vital_reg_mobile/features/birth_registration/domain/entities/informant_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/parent_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/person_fields.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';

/// Every Step 1 field filled with a valid value.
ChildParticulars completeChild() {
  var child = const ChildParticulars();
  for (final field in ChildField.values) {
    child = child.set(
      field,
      field == ChildField.dateOfBirth
          ? DateTime(2026, 1, 15).toIso8601String()
          : 'value',
    );
  }
  return child;
}

/// Every mother field that applies, filled with a valid value.
ParentParticulars completeParent() {
  var parent = const ParentParticulars();
  for (final field in ParentField.values) {
    parent = parent.set(field, switch (field) {
      ParentField.nin => '12345678901',
      ParentField.age => '30',
      ParentField.phone => '08130845852',
      ParentField.country || ParentField.nationality => ReferenceData.nigeria,
      ParentField.sameResidenceAsMother => answerNo,
      _ => 'value',
    });
  }
  return parent;
}

/// A signing informant with everything but a NIN or tracking ID.
InformantParticulars informantWithoutId() {
  var informant = const InformantParticulars();
  const skipped = {
    InformantField.nin,
    InformantField.trackingId,
    InformantField.facePhoto,
  };
  for (final field in InformantField.values) {
    if (skipped.contains(field)) continue;
    informant = informant.set(field, switch (field) {
      InformantField.phone => '08130845852',
      InformantField.country => ReferenceData.nigeria,
      InformantField.sameResidenceAsMother => answerNo,
      InformantField.identityMode => IdentityMode.signature.name,
      _ => 'value',
    });
  }
  return informant;
}

/// A draft with every step complete, on the review step.
RegistrationDraft completeDraft(DateTime startedOn) => RegistrationDraft(
  startedOn: startedOn,
  childHasNin: false,
  step: RegistrationStep.review,
  child: completeChild(),
  mother: completeParent(),
  father: completeParent(),
  informant: informantWithoutId(),
  documents: const SupportingDocuments({
    DocumentType.immunizationCard: AttachedFile(
      path: 'imc.jpg',
      name: 'imc.jpg',
      sizeBytes: 1000,
    ),
    DocumentType.birthNotification: AttachedFile(
      path: 'nb.jpg',
      name: 'nb.jpg',
      sizeBytes: 1000,
    ),
  }),
);
