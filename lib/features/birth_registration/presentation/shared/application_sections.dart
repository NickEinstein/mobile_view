import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/informant_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/parent_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

part 'application_sections_content.dart';
part 'application_sections_widgets.dart';

/// An application's five cards (child, mother, father, informant,
/// documents), as on the form's review and on Certificate Details.
class ApplicationSections extends StatelessWidget {
  const ApplicationSections({
    required this.referenceData,
    required this.child,
    required this.mother,
    required this.father,
    required this.informant,
    required this.documents,
    this.childNin,
    this.onEdit,
    this.isIncomplete,
    super.key,
  });

  /// Turns stored option ids into their labels.
  final ReferenceData referenceData;
  final ChildParticulars child;
  final String? childNin;
  final ParentParticulars mother;
  final ParentParticulars father;
  final InformantParticulars informant;
  final SupportingDocuments documents;

  /// Shows an Edit link on each card; null for a read-only record.
  final ValueChanged<RegistrationStep>? onEdit;

  /// Marks cards with missing details.
  final bool Function(RegistrationStep step)? isIncomplete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final content = _ReviewContent(
      l10n: l10n,
      data: referenceData,
      locale: Localizations.localeOf(context).toString(),
    );
    final onEdit = this.onEdit;
    final sections = [
      (
        RegistrationStep.child,
        l10n.brStepChild,
        content.child(child, childNin),
      ),
      (
        RegistrationStep.mother,
        l10n.brStepMother,
        content.parent(mother, ParentRole.mother),
      ),
      (
        RegistrationStep.father,
        l10n.brStepFather,
        content.parent(father, ParentRole.father),
      ),
      (
        RegistrationStep.informant,
        l10n.brStepInformant,
        content.informant(informant),
      ),
      (
        RegistrationStep.documents,
        l10n.brSupportingDocuments,
        content.documents(documents),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, (step, title, rows)) in sections.indexed) ...[
          if (index > 0) const SizedBox(height: Spacing.md),
          _ReviewCard(
            title: title,
            rows: rows,
            incomplete: isIncomplete?.call(step) ?? false,
            onEdit: onEdit == null ? null : () => onEdit(step),
          ),
        ],
      ],
    );
  }
}

/// Display names for [DocumentType].
extension DocumentTypeLabel on DocumentType {
  String label(AppLocalizations l10n) => switch (this) {
    DocumentType.immunizationCard => l10n.brDocImmunizationCard,
    DocumentType.birthNotification => l10n.brDocBirthNotification,
    DocumentType.lgaBirthCertificate => l10n.brDocLgaBirthCertificate,
    DocumentType.baptismalCard => l10n.brDocBaptismalCard,
    DocumentType.idCard => l10n.brDocIdCard,
    DocumentType.fatherPassport => l10n.brDocFatherPassport,
    DocumentType.motherPassport => l10n.brDocMotherPassport,
  };
}
