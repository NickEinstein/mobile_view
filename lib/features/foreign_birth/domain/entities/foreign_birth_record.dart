import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_draft.dart';

/// The ids of the people a notification points to, which
/// `PATCH /birth-notification/update` needs with the record's own id.
typedef ForeignBirthPartyIds = ({
  int child,
  int mother,
  int father,
  int informant,
});

/// One notification from the server, in the form's shape (files as stored
/// keys).
final class ForeignBirthRecord extends Equatable {
  const ForeignBirthRecord({
    required this.id,
    required this.status,
    required this.draft,
    required this.partyIds,
    this.notificationNumber,
    this.queryReason,
    this.fileUrls = const {},
  });

  /// The backend's numeric id.
  final int id;
  final ApplicationStatus status;
  final ForeignBirthDraft draft;
  final ForeignBirthPartyIds partyIds;
  final String? notificationNumber;

  /// Why it was queried.
  final String? queryReason;

  /// Storage key → a viewable (presigned) URL, for files on record.
  final Map<String, String> fileUrls;

  @override
  List<Object?> get props => [
    id,
    status,
    draft,
    partyIds,
    notificationNumber,
    queryReason,
    fileUrls,
  ];

  /// Contains personal data: keep it out of logs.
  @override
  String toString() => 'ForeignBirthRecord(status: ${status.name})';
}
