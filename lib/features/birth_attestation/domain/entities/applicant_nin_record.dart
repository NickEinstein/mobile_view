import 'package:equatable/equatable.dart';

enum Sex { male, female }

/// The identity service's record for a NIN; it prefills the applicant.
final class ApplicantNinRecord extends Equatable {
  const ApplicantNinRecord({
    required this.nin,
    required this.surname,
    required this.firstName,
    required this.dateOfBirth,
    this.middleName,
    this.sex,
    this.phone,
    this.stateOfOrigin,
    this.lgaOfOrigin,
  });

  factory ApplicantNinRecord.fromJson(Map<String, Object?> json) =>
      ApplicantNinRecord(
        nin: json['nin']! as String,
        surname: json['surname']! as String,
        firstName: json['firstName']! as String,
        middleName: json['middleName'] as String?,
        dateOfBirth: DateTime.parse(json['dateOfBirth']! as String),
        sex: switch (json['sex']) {
          final String name => Sex.values.asNameMap()[name],
          _ => null,
        },
        phone: json['phone'] as String?,
        stateOfOrigin: json['stateOfOrigin'] as String?,
        lgaOfOrigin: json['lgaOfOrigin'] as String?,
      );

  /// Attestation is for adults; children use Birth Registration.
  static const minAgeYears = 18;

  final String nin;
  final String surname;
  final String firstName;
  final String? middleName;
  final DateTime dateOfBirth;
  final Sex? sex;
  final String? phone;

  /// Names as the identity service gives them, e.g. "Bauchi".
  final String? stateOfOrigin;
  final String? lgaOfOrigin;

  bool isAdultOn(DateTime today) => !today.isBefore(
    DateTime(
      dateOfBirth.year + minAgeYears,
      dateOfBirth.month,
      dateOfBirth.day,
    ),
  );

  Map<String, Object?> toJson() => {
    'nin': nin,
    'surname': surname,
    'firstName': firstName,
    'middleName': middleName,
    'dateOfBirth': dateOfBirth.toIso8601String(),
    'sex': sex?.name,
    'phone': phone,
    'stateOfOrigin': stateOfOrigin,
    'lgaOfOrigin': lgaOfOrigin,
  };

  @override
  List<Object?> get props => [
    nin,
    surname,
    firstName,
    middleName,
    dateOfBirth,
    sex,
    phone,
    stateOfOrigin,
    lgaOfOrigin,
  ];

  /// Personal data: keep it out of logs.
  @override
  String toString() => 'ApplicantNinRecord(…)';
}
