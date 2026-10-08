import 'package:dio/dio.dart';

part 'fake_backend_data.dart';

/// DEV FLAVOR ONLY. Answers the auth endpoints locally so the app can be
/// demoed without a backend. Enabled by `USE_FAKE_API=true` in
/// config/dev.json; `AppConfig` refuses it in staging and prod.
///
/// Demo behaviour:
/// - any email and password (8+ characters) signs in as a registrar;
/// - password reset always sends a code, and the code is `1234`;
/// - the dashboard and Birth Registration show sample figures;
/// - any 11-digit NIN validates except `00000000000`; `11111111111` is a
///   child born in 2016, so Birth Registration asks for the fee;
/// - Birth Registration answers in the backend's shapes; only its
///   places come from `/option/*` (LGAs state by state),
///   and submitting succeeds when the fields the API requires are there;
/// - Modifications list sample requests in the backend's shapes, and
///   find a record for any certificate number except `000000`; sending a
///   modification always succeeds (documents "upload" to nowhere); the
///   queried birth request is a date of birth change missing its request
///   letter (attestation: a misspelled name; death: the age at death), and
///   answering it always succeeds.
/// - Still Birth lists sample registrations in the backend's shapes, and
///   registering one always succeeds (the signature "uploads" to nowhere).
/// - Certificate Reissuance lists sample requests in the backend's shapes,
///   every face matches, and every birth request is accepted (files
///   "upload" to nowhere; the email code is the payment one). Its form's
///   places come from `/option/*` (three countries; Nigeria and Ghana have
///   states).
/// - Death Registration lists sample records in the backend's shapes, and
///   registering one always succeeds. The queried record has the wrong
///   documents; correcting it always succeeds.
/// - Surrogacy Birth lists sample applications in the backend's shapes;
///   starting one, recording the child's NIN (or a skip), attaching the
///   payment and saving each section always succeed.
/// - Adopted Child Registration works the same way as Surrogacy Birth.
/// The face service's URL in the dev config (`config/dev.json`).
const demoFaceUrl = 'https://face.demo.test/api/v1/matchWithSelfie';

class FakeBackendInterceptor extends Interceptor {
  /// [latency] is long enough by default to see loading states; tests
  /// pass zero.
  FakeBackendInterceptor({this.latency = const Duration(milliseconds: 700)});

  final Duration latency;

  static const demoCode = '1234';

  /// The payment code the demo accepts.
  static const demoPaymentOtp = '123456';

  /// A reference the demo treats as already paid ("Enter Reference").
  static const demoPaidReference = 'PAIDDEMO';

  /// References "paid" through `DemoPaymentCheckout`, for this app run.
  static final Set<String> paidReferences = {};

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final body = options.data;
    final fields = body is Map<String, Object?>
        ? body
        : const <String, Object?>{};

    final path = options.path;

    switch ((options.method, path)) {
      // As the backend answers: the profile comes with the token.
      case ('POST', '/auth/login'):
        _ok(handler, options, {
          'success': true,
          'message': 'Welcome',
          'user': {
            'User_ID': 1,
            'UserName': 'favour.allison',
            'Email': 'favour.allison@demo.test',
            'First_Name': 'Favour',
            'Last_Name': 'Allison',
            'Role_ID': 3,
            'Reg_Center_ID': 12,
          },
          'access_token': 'fake-access-token',
        });
      case ('POST', '/auth/logout' || '/auth/password/forgot'):
        _ok(handler, options, null);
      case ('POST', '/auth/password/verify-code'):
        if (fields['code'] == demoCode) {
          _ok(handler, options, {'resetToken': 'fake-reset-token'});
        } else {
          _fail(handler, options, 422, 'The code is incorrect or expired.');
        }
      case ('POST', '/auth/password/reset'):
        _ok(handler, options, null);
      // Birth Attestation, on the backend's paths. It serves
      // the same sample records as Birth Registration.
      case ('GET', '/birth-attestation/stats/self'):
        // SQL sums arrive as strings.
        _ok(handler, options, {
          'Pending': '2',
          'Approved': '3',
          'Queried': '1',
          'Printed': '4',
          'total': '6',
        });
      case ('GET', '/birth-attestation/list'):
        _ok(handler, options, _attestations(options.queryParameters));
      case ('GET', _) when path.startsWith('/payments/price/'):
        _ok(handler, options, {'amount': 2100, 'currency': 'NGN'});
      case ('GET', _) when path.startsWith('/can-receive-email/'):
        _ok(handler, options, {'valid': !path.contains('invalid')});
      case ('POST', '/validation/send-otp' || '/validation/resend-otp'):
        _ok(handler, options, null);
      case ('POST', '/validation/validate-otp'):
        if (fields['otp'] == demoPaymentOtp) {
          _ok(handler, options, null);
        } else {
          _fail(handler, options, 422, 'The code is incorrect or expired.');
        }
      case ('POST', '/payments/initiate'):
        final reference =
            'BRT${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
                .toUpperCase();
        // The backend currently starts every payment with ALATPay.
        _ok(handler, options, {
          'gateway': 'alatpay',
          'success': true,
          'reference': reference,
          'url': 'https://demo.test/checkout/$reference',
        });
      // As the backend: only a completed, unused payment is found.
      case ('GET', '/payments/verify'):
        final reference = options.queryParameters['reference'];
        if (paidReferences.contains(reference) ||
            reference == demoPaidReference) {
          _ok(handler, options, {
            'success': true,
            'status': 'completed',
            'reference': reference,
          });
        } else {
          _fail(
            handler,
            options,
            404,
            'Payment reference not found or has been used',
          );
        }
      // ALATPay's check after its checkout: asks the gateway, so a payment
      // still in progress is pending.
      case ('POST', '/payments/alat/verify'):
        final reference = fields['reference'];
        final paid = paidReferences.contains(reference);
        _ok(handler, options, {
          'success': paid,
          'status': paid ? 'completed' : 'pending',
          'reference': reference,
        });
      case ('GET', _) when path.startsWith('/verify-nin/'):
        _ok(handler, options, _ninRecord(path.substring(12)));
      // As the backend: `/add` returns the new record, `/no-nin` its
      // number. Both need the uploaded face's key.
      case ('POST', '/birth-attestation/add' || '/self-attestation/no-nin')
          when fields['face'] == null:
        _fail(handler, options, 400, 'face is required.');
      case ('POST', '/birth-attestation/add'):
        _ok(handler, options, {
          'success': true,
          'message': 'Record added successfully',
          'item': {'id': 7999, 'attestation_number': _newAttestationNumber()},
        });
      case ('POST', '/self-attestation/no-nin'):
        _ok(handler, options, {
          'message': 'Request submitted',
          'attestationNumber': _newAttestationNumber(),
        });
      case ('GET', _) when path.startsWith('/birth-attestation/cert/'):
        final record = _attestationRecord(
          path.substring(path.lastIndexOf('/') + 1),
        );
        if (record == null) {
          _fail(handler, options, 404, 'No such attestation.');
        } else {
          _ok(handler, options, record);
        }
      case ('PATCH', '/birth-attestation/update'):
        _ok(handler, options, {'success': true});
      // The face service, at the dev config's FACE_VERIFICATION_URL.
      case ('POST', demoFaceUrl):
        _ok(handler, options, {'possibleMatch': true, 'score': 0.93});
      // Postgres SUMs arrive as strings.
      case ('GET', '/birth-registration/stats/self'):
        _ok(handler, options, {
          'Pending': '2',
          'Approved': '3',
          'Queried': '1',
          'Printed': '4',
          'total': '6',
        });
      case ('GET', '/birth-registration/list'):
        _ok(handler, options, _birthRegistrations(options.queryParameters));
      case ('POST', '/birth-registration/add'):
        final missing = _missingRegistrationFields(fields);
        if (missing.isEmpty) {
          _ok(handler, options, {
            'success': true,
            'message': 'Record added successfully',
            'reject': false,
            'record': null,
          });
        } else {
          _fail(handler, options, 400, '${missing.join(', ')} missing.');
        }
      // `/birth-registration/{id}`; other paths (e.g. the reissuance's
      // `selfservice/print`) fall through.
      case ('GET', _) when RegExp(r'^/birth-registration/\d+$').hasMatch(path):
        final record = _birthRegistration(path.substring(20));
        if (record == null) {
          _fail(handler, options, 404, 'No certificate with this number.');
        } else {
          _ok(handler, options, record);
        }
      case ('GET', _) when path.startsWith('/file-upload-url/'):
        final name = path.substring('/file-upload-url/'.length);
        _ok(handler, options, {
          'url': 'https://demo.test/upload/$name',
          'key': 'modifications/$name',
        });
      case ('PUT', _) when path.startsWith('https://demo.test/upload/'):
        _ok(handler, options, null);
      case ('GET', '/option/states/63'):
        _ok(handler, options, [
          for (final (id, name) in _optionStates)
            {
              'State_ID': id,
              'State_Name': name,
              'State_Code': name.substring(0, 2).toUpperCase(),
              'country_id': 63,
            },
        ]);
      // Other countries' states (Certificate Reissuance asks per country).
      case ('GET', _) when path.startsWith('/option/states/'):
        _ok(handler, options, [
          if (path.endsWith('/31'))
            for (final (id, name) in [(901, 'Greater Accra'), (902, 'Ashanti')])
              {'State_ID': id, 'State_Name': name},
          if (path.endsWith('/181'))
            for (final (id, name) in [(951, 'England'), (952, 'Scotland')])
              {'State_ID': id, 'State_Name': name},
        ]);
      case ('GET', '/option/country'):
        _ok(handler, options, [
          for (final (code, name, nationality, iso) in [
            (63, 'Nigeria', 'Nigerian', 'NG'),
            (31, 'Ghana', 'Ghanaian', 'GH'),
            (181, 'United Kingdom', 'British', 'GB'),
          ])
            {
              'Country_Code': code,
              'Country_Name': name,
              'Country_Nationality_Name': nationality,
              'Alpfa_2_Code': iso,
            },
        ]);
      case ('GET', '/option/registration-centres'):
        _ok(handler, options, [
          for (final lgas in _optionLgas.values)
            for (final (lga, name) in lgas)
              {
                'Reg_Center_id': lga * 10,
                'Reg_Center_Name': '$name Registration Centre',
                'LGA_ID': lga,
              },
        ]);
      case ('GET', _) when path.startsWith('/option/lga/'):
        final state = int.tryParse(path.substring(path.lastIndexOf('/') + 1));
        _ok(handler, options, [
          for (final (id, name)
              in _optionLgas[state] ?? const <(int, String)>[])
            {
              'LGA_ID': '$id',
              'LGA_Code': '$id',
              'LGA_Name': name,
              'State_ID': '$state',
            },
        ]);
      case ('GET', final path)
          when path.startsWith('/modification/') && path.contains('/single/'):
        final id = path.substring(path.lastIndexOf('/') + 1);
        _ok(handler, options, switch (path.split('/')[2]) {
          'birth-attestation' => _queriedAttestation(id),
          'death-registration' => _queriedDeath(id),
          _ => _queriedModification(id),
        });
      case ('POST' || 'PATCH', final path)
          when path.startsWith('/modification/') && path.split('/').length == 3:
        _ok(handler, options, {
          'message': 'Modification request submitted successfully.',
        });
      case ('GET', final path)
          when path.startsWith('/modification/') && path.contains('/cert/'):
        final number = path.substring(path.lastIndexOf('/') + 1);
        if (number == '000000') {
          _fail(handler, options, 404, 'No record found.');
        } else {
          _ok(handler, options, {
            'data': _modificationRecord(path.split('/')[2], number),
          });
        }
      case ('GET', final path)
          when path.startsWith('/modification/') && path.endsWith('/stats'):
        _ok(handler, options, {
          // An SQL sum, which arrives as a string.
          'total': '${_modificationCounts.values.reduce((a, b) => a + b)}',
        });
      case ('GET', final path)
          when path.startsWith('/modification/') && path.endsWith('/list'):
        _ok(
          handler,
          options,
          _modifications(path.split('/')[2], options.queryParameters),
        );
      // Death Registration, on the backend's paths.
      // SQL sums arrive as strings.
      case ('GET', '/death-registration/stats'):
        _ok(handler, options, {
          'Pending': '2',
          'Approved': '3',
          'Printed': '1',
          'Queried': '1',
          'total': '6',
        });
      case ('GET', '/death-registration/list/'):
        _ok(handler, options, _deaths(options.queryParameters));
      case ('GET', _)
          when path.startsWith('/death-registration/') &&
              int.tryParse(path.substring(path.lastIndexOf('/') + 1)) != null:
        final record = _death(path.substring(path.lastIndexOf('/') + 1));
        if (record == null) {
          _fail(handler, options, 404, 'No such death registration.');
        } else {
          _ok(handler, options, record);
        }
      case ('PATCH', '/death-registration/update'):
        _ok(handler, options, {'message': 'Record updated'});
      // As the backend: the new record and its registration number.
      case ('POST', '/death-registration/add'):
        final number = 'D${DateTime.now().millisecondsSinceEpoch}N';
        _ok(handler, options, {
          'success': true,
          'message': 'Record added successfully',
          'item': {'id': 40999, 'registration_number': number},
          'registrationNumber': number,
        });
      // Certificate Reissuance, on the backend's paths.
      case ('GET', _)
          when path.startsWith('/certificate-reissuance-assisted/') &&
              path.endsWith('-stats'):
        _ok(handler, options, {
          'Total': _people.length,
          'Pending': 1,
          'Approved': 2,
          'Queried': 1,
        });
      case ('GET', _)
          when path.startsWith('/certificate-reissuance-assisted/') &&
              path.endsWith('-list'):
        _ok(handler, options, _reissuances(options.queryParameters));
      case ('GET', _)
          when path.startsWith(
            '/certificate-reissuance-assisted/single-birth-reg/',
          ):
        final record = _birthReissuance(
          path.substring(path.lastIndexOf('/') + 1),
        );
        if (record == null) {
          _fail(handler, options, 404, 'No certificate found');
        } else {
          _ok(handler, options, record);
        }
      case ('GET', _)
          when path.startsWith(
            '/certificate-reissuance-assisted/single-birth-attest/',
          ):
        final record = _attestationReissuance(
          path.substring(path.lastIndexOf('/') + 1),
        );
        if (record == null) {
          _fail(handler, options, 404, 'No certificate found');
        } else {
          _ok(handler, options, record);
        }
      case ('POST', '/certificate-reissuance-assisted/add-birth-attest'):
        _ok(handler, options, {
          'success': true,
          'message': 'Application submitted successfully.',
        });
      case ('PATCH', '/certificate-reissuance-assisted/update-birth-attest'):
        _ok(handler, options, {
          'success': true,
          'message': 'Record updated successfully.',
        });
      case ('PATCH', '/certificate-reissuance-assisted/update-birth-reg'):
        _ok(handler, options, {
          'success': true,
          'message': 'Record updated successfully.',
        });
      case ('GET', _)
          when path.startsWith('/birth-registration/selfservice/print/') ||
              path.startsWith('/self-attestation/print/'):
        // A tiny PNG stands in for the printed JPEG.
        _ok(handler, options, _demoCertificatePng);
      case ('POST', '/certificate-reissuance-assisted/add-birth-reg'):
        _ok(handler, options, {
          'success': true,
          'message': 'Application submitted successfully.',
        });
      // Still Birth, on the backend's paths.
      case ('GET', '/stillbirth/stats'):
        _ok(handler, options, 3);
      case ('GET', '/stillbirth/list/'):
        _ok(handler, options, _stillBirths(options.queryParameters));
      // After the fixed paths, as the backend's `GET /stillbirth/:id`.
      case ('GET', _)
          when path.startsWith('/stillbirth/') &&
              path.indexOf('/', '/stillbirth/'.length) < 0:
        final record = _stillBirth(path.substring(path.lastIndexOf('/') + 1));
        if (record == null) {
          _fail(handler, options, 404, 'No such still birth.');
        } else {
          // As the backend's `single`: without the record's id.
          _ok(handler, options, {
            'data': {...record}..remove('id'),
          });
        }
      // As the backend: the new record.
      case ('POST', '/stillbirth/add'):
        _ok(handler, options, {
          'success': true,
          'message': 'Record added successfully',
          'item': {'id': 30087999},
        });
      // Surrogacy Birth, on the backend's paths.
      // As the backend's typed-in reference check.
      case ('GET', '/surrogacy-birth-registration/payment'):
        final reference = options.queryParameters['reference'];
        _ok(handler, options, {
          'valid':
              paidReferences.contains(reference) ||
              reference == demoPaidReference,
          'reference': reference,
        });
      case ('GET', '/surrogacy-birth-registration/stats'):
        _ok(handler, options, {
          'Pending': 2,
          'Approved': 3,
          'Queried': 1,
          'Printed': 4,
        });
      case ('GET', '/surrogacy-birth-registration'):
        _ok(handler, options, _surrogacyRegistrations(options.queryParameters));
      case ('POST', '/surrogacy-birth-registration/initiate'):
        final serial = DateTime.now().millisecondsSinceEpoch % 10000000;
        _ok(handler, options, {
          'success': true,
          'referenceId':
              'SBR-${DateTime.now().year}-${'$serial'.padLeft(7, '0')}',
        });
      case ('POST' || 'PATCH', _)
          when path.startsWith('/surrogacy-birth-registration/'):
        _ok(handler, options, {'success': true});
      case ('GET', _)
          when path.startsWith('/surrogacy-birth-registration/') &&
              path.endsWith('/resume'):
        final reference = path.split('/')[2];
        _ok(handler, options, {
          'success': true,
          'lastCompletedSection': 2,
          'data': _surrogacyRecord(Uri.decodeComponent(reference)),
        });
      case ('GET', _) when path.startsWith('/surrogacy-birth-registration/'):
        final record = _surrogacyRecord(
          Uri.decodeComponent(path.substring(path.lastIndexOf('/') + 1)),
        );
        if (record == null) {
          _fail(handler, options, 404, 'No such application.');
        } else {
          // As the backend's `single`: without the record's id.
          _ok(handler, options, {
            'data': {...record}..remove('id'),
          });
        }
      // Adopted Child Registration, on the backend's paths.
      // As the backend's typed-in reference check.
      case ('GET', '/adopted-child-registration/payment'):
        final reference = options.queryParameters['reference'];
        _ok(handler, options, {
          'valid':
              paidReferences.contains(reference) ||
              reference == demoPaidReference,
          'reference': reference,
        });
      case ('GET', '/adopted-child-registration/stats'):
        _ok(handler, options, {
          'Pending': 3,
          'Approved': 2,
          'Queried': 1,
          'Printed': 2,
        });
      case ('GET', '/adopted-child-registration'):
        _ok(handler, options, _adoptions(options.queryParameters));
      case ('POST', '/adopted-child-registration/initiate'):
        final serial = DateTime.now().millisecondsSinceEpoch % 10000000;
        _ok(handler, options, {
          'success': true,
          'referenceId':
              'ACR-${DateTime.now().year}-${'$serial'.padLeft(7, '0')}',
        });
      case ('GET', _)
          when path.startsWith('/adopted-child-registration/') &&
              path.endsWith('/resume'):
        final reference = path.split('/')[2];
        _ok(handler, options, {
          'success': true,
          'lastCompletedSection': 2,
          'data': _adoptionRecord('adoption-drafted-0', referenceId: reference),
        });
      case ('GET', _) when path.startsWith('/adopted-child-registration/'):
        final record = _adoptionRecord(
          path.substring(path.lastIndexOf('/') + 1),
        );
        if (record == null) {
          _fail(handler, options, 404, 'No such application.');
        } else {
          // As the backend's `single`: without the record's id.
          _ok(handler, options, {
            'data': {...record}..remove('id'),
          });
        }
      case ('POST' || 'PATCH', _)
          when path.startsWith('/adopted-child-registration/'):
        _ok(handler, options, {'success': true});
      // The home dashboard, on the backend's paths.
      case ('GET', '/statistics/counts'):
        _ok(handler, options, {
          for (final MapEntry(:key, :value) in _monthlyBase.entries)
            // All time, as SQL counts arrive: strings.
            key: '${value.reduce((a, b) => a + b) * 7}',
        });
      case ('GET', _)
          when path.startsWith('/statistics/') &&
              _monthlyBase.containsKey(path.substring('/statistics/'.length)):
        _ok(
          handler,
          options,
          _monthly(
            path.substring('/statistics/'.length),
            options.queryParameters['period'],
          ),
        );
      case _:
        _fail(handler, options, 404, 'Not available in the demo backend.');
    }
  }

  /// `/birth-attestation/cert/{number}` for a [_attestations] row.
  static Map<String, Object?>? _attestationRecord(String number) {
    final code = number.length == 8 && number.startsWith('ATT')
        ? int.tryParse(number.substring(3, 4))
        : null;
    final index = int.tryParse(number.substring(number.length - 4));
    if (code == null ||
        code >= _attestationStatuses.length ||
        index == null ||
        index >= _people.length) {
      return null;
    }
    final status = _attestationStatuses[code];
    final (name, _, date) = _people[index];
    final [firstName, surname] = name.split(' ');
    return {
      'data': {
        'id': 7000 + code * 10 + index,
        'attestation_number': number,
        'date_created': date,
        // Queried and printed are approval codes 2 and 1.
        'approval_status': switch (status) {
          'pending' => 0,
          'queried' => 2,
          _ => 1,
        },
        'marital_status': 2,
        'id_type': 2,
        'id_number': 'A12345678',
        'applicant_email': 'applicant@mail.com',
        'applicant_phone': null,
        'place_of_birth': 1,
        'request_reason': 2,
        'request_required_for': 'job in nigeria',
        'requester_address': 'Federal Secretariat, Abuja',
        'mother_surname': surname,
        'mother_firstname': 'Amina',
        'mother_maiden_name': 'Musa',
        'mother_nationality': 63,
        'mother_state': 15,
        'mother_lga': 151,
        'mother_town': 'Garki',
        'mother_passport': null,
        'father_surname': surname,
        'father_firstname': 'Ibrahim',
        'father_nationality': 63,
        'father_state': 15,
        'father_lga': 151,
        'father_town': 'Garki',
        'father_passport': null,
        'nin': null,
        'face': 'https://demo.test/files/face.jpg',
        'SupportingDocument': [
          {'type': 'affidavit', 'file': 'https://demo.test/files/aff.jpg'},
        ],
        // The same files' storage keys.
        'rawFace': 'attestation/face.jpg',
        'rawSupportingDocument': [
          {
            'type': 'affidavit',
            'file': 'attestation/aff.jpg',
            'mimeType': 'image/jpeg',
          },
        ],
        'rawMotherPassport': null,
        'rawFatherPassport': null,
        'personData': {
          'surname': surname,
          'firstname': firstName,
          'middle_name': null,
          'genderData': {'Gender_ID': 1, 'gender': 'Male'},
          'birth_date': '1988-04-12',
          'birth_state': 25,
          'birth_lga': 251,
          'town_of_birth': 'Ikeja',
          'origin_state': 15,
          'origin_lga': 152,
          'town_of_origin': 'Bwari',
          'current_address': 'No 2 Agwada Str',
          'current_education_level': 7,
          'current_occupation': 101,
          'work_address': 'Central Market, Abuja',
        },
      },
      'reason': status == 'queried'
          ? {'reason': 'Wrong document uploaded'}
          : null,
    };
  }

  /// The identity service's answer.
  /// `00000000000` has no record; `11111111111` belongs to a 10-year-old.
  static Map<String, Object?> _ninRecord(String nin) => switch (nin) {
    '00000000000' => {'status': 0},
    _ => {
      'status': 1,
      'lastname': 'Ogunlade',
      'firstname': 'Bolaji',
      'middlename': 'Favour',
      'dob': nin == '11111111111' ? '12-03-2016' : '14-06-1990',
      'gender': 'm',
      'phone': '08130845852',
      'state_orgin': 'Bauchi',
      'lga_orgin': 'Bogoro',
      // A 1×1 JPEG stands in for the NIN photo.
      'photo':
          '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==',
    },
  };

  /// Sample monthly numbers per `/statistics/<type>`.
  static const _monthlyBase = {
    'birth': [4, 6, 5, 8, 7, 9, 11, 10, 12, 9, 8, 10],
    'attestation': [1, 2, 1, 3, 2, 2, 4, 3, 2, 3, 2, 1],
    'death': [2, 1, 3, 2, 2, 1, 3, 2, 1, 2, 3, 2],
    'stillbirth': [0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0],
  };

  /// So the chart has something to draw. Earlier years have more records;
  /// the current year is still filling up.
  static List<int> _monthly(String type, Object? rawPeriod) {
    final now = DateTime.now();
    final year = int.tryParse('$rawPeriod') ?? now.year;
    final scale = (now.year - year).clamp(0, 4) + 1;
    final monthsSoFar = year < now.year ? 12 : now.month;
    return [
      for (var m = 0; m < 12; m++)
        m < monthsSoFar ? _monthlyBase[type]![m] * scale : 0,
    ];
  }

  static const _people = [
    ('Michael Lee', 'FA30087677', '2026-09-23'),
    ('Sofia Martinez', 'FA30087678', '2025-10-15'),
    ('David Kim', 'FA30087679', '2024-11-02'),
    ('Amina Garba', 'FA30087680', '2026-08-30'),
  ];

  /// List row [id] (4100–4103) as `/single-birth-attest` sends it, in the
  /// API's field names. 4103 is queried, with a reason.
  static Map<String, Object?>? _attestationReissuance(String id) {
    final index = (int.tryParse(id) ?? 0) - 4100;
    if (index < 0 || index >= _people.length) return null;
    const statuses = [0, 1, 1, 2];
    final (name, reference, date) = _people[index];
    final [firstName, surname] = name.split(' ');
    return {
      'data': {
        'id': 4100 + index,
        'reference': 'BRT$reference',
        'applicantNin': '12345678901',
        'approvedStatus': statuses[index],
        'dateCreated': date,
        'legacyCertNumber': 'AT60326091$index',
        'legacyCertIssuedDate': '2012-05-14',
        'rawLegacyCertLink': 'reissuance/cert-$index.jpg',
        'rawFace': 'reissuance/face-$index.jpg',
        'rawSignature': 'reissuance/sign-$index.png',
        'rawSupportingDocument': [
          {
            'type': 'court-affidavit',
            'file': 'reissuance/affidavit-$index.png',
            'mimeType': 'image/png',
          },
        ],
        'applicantSurname': surname,
        'applicantFirstName': firstName,
        'applicantMiddleName': null,
        'applicantSex': 1,
        'applicantDateOfBirth': '1988-04-12',
        'applicantMaritalStatus': 1,
        'applicantOriginState': 1,
        'applicantOriginLga': 11,
        'applicantTown': 'Isiukwuato',
        'applicantPhone': '08130845852',
        'applicantEmail': 'applicant@mail.com',
        'idType': 2,
        'idNumber': 'A12345678',
        'placeOfBirth': 1,
        'stateOfBirth': 1,
        'lgaOfBirth': 11,
        'townOfBirth': 'Isiukwuato',
        'applicantRegCenter': 110,
        'applicantRegCenterData': {
          'Reg_Center_id': 110,
          'LGAs': {'LGA_ID': 11, 'State_ID': 1},
        },
        'currentAddress': 'No 2 Agwada Str',
        'educationLevel': 7,
        'occupation': 2,
        'workAddress': 'Central Market, Umuahia',
        'requestReason': 3,
        'requestRequiredFor': 'job in nigeria',
        'requesterAddress': 'Federal Secretariat, Abuja',
        'fatherName': '$surname Musa',
        'fatherState': 1,
        'fatherLga': 11,
        'fatherTown': 'Isiukwuato',
        'motherName': '$surname Amina Bello',
        'motherState': 1,
        'motherLga': 11,
        'motherTown': 'Isiukwuato',
      },
      'queried': statuses[index] == 2
          ? {
              'title': 'Unclear affidavit',
              'reason': 'The court affidavit is not readable.',
            }
          : null,
    };
  }

  /// A tiny PNG, base64, standing in for a printed certificate.
  static const _demoCertificatePng =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwAD'
      'hgGAWjR9awAAAABJRU5ErkJggg==';

  /// List row [id] (4100–4103) as `/single-birth-reg` sends it, in the
  /// API's field names. 4103 is queried, with a reason.
  static Map<String, Object?>? _birthReissuance(String id) {
    final index = (int.tryParse(id) ?? 0) - 4100;
    if (index < 0 || index >= _people.length) return null;
    const statuses = [0, 1, 1, 2];
    final (name, reference, date) = _people[index];
    final [firstName, surname] = name.split(' ');
    Map<String, Object?> parent(String prefix, String first) => {
      '${prefix}Surname': surname,
      '${prefix}FirstName': first,
      '${prefix}CountryOfResidence': 63,
      '${prefix}StateOfResidence': 1,
      '${prefix}LgaOfResidence': 11,
      '${prefix}ResidenceAddress': 'No 2 Agwada Str',
      '${prefix}AgeAtBirth': prefix == 'mother' ? 30 : 34,
      '${prefix}MaritalStatus': 1,
      '${prefix}Nationality': 63,
      '${prefix}OriginState': 1,
      '${prefix}OriginLga': 11,
      '${prefix}EthnicGroup': 4,
      '${prefix}LiteracyLevel': 1,
      '${prefix}EducationLevel': 7,
      '${prefix}Occupation': 3,
      '${prefix}PhoneNumber': '08130845852',
    };
    return {
      'data': {
        'id': 4100 + index,
        'reference': 'BRT$reference',
        'nin': '12345678901',
        'approvedStatus': statuses[index],
        'dateCreated': date,
        'legacyCertNumber': 'CR60326091$index',
        'legacyCertIssuedDate': '2010-03-01',
        'rawLegacyCertLink': 'reissuance/cert-$index.jpg',
        'rawChildFace': 'reissuance/face-$index.jpg',
        'rawSignature': 'reissuance/sign-$index.png',
        'rawSupportingDocument': [
          {
            'type': 'support-document',
            'file': 'reissuance/doc-$index.png',
            'mimeType': 'image/png',
          },
        ],
        'childSurname': surname,
        'childFirstName': firstName,
        'childMiddleName': null,
        'childSex': 1,
        'dateOfBirth': '2016-03-12',
        'birthType': 1,
        'birthOrder': 1,
        'placeOfBirth': 1,
        'stateOfBirth': 1,
        'lgaOfBirth': 11,
        'townOfBirth': 'Isiukwuato',
        'townOfOrigin': null,
        'localityOfBirth': 2,
        'regCenter': 110,
        'regCenterData': {
          'Reg_Center_id': 110,
          'LGAs': {'LGA_ID': 11, 'State_ID': 1},
        },
        ...parent('mother', 'Amina'),
        'motherMaidenName': 'Bello',
        ...parent('father', 'Musa'),
      },
      'queried': statuses[index] == 2
          ? {
              'title': 'Age mismatch',
              'reason':
                  "The mother's age at birth doesn't match the old "
                  'certificate.',
            }
          : null,
    };
  }

  /// Reissuance requests in the backend's list shape: one pending, two
  /// approved, one queried, filtered by `type` and `search`.
  static Map<String, Object?> _reissuances(Map<String, Object?> query) {
    const statuses = [0, 1, 1, 2];
    const types = ['pending', 'approved', 'approved', 'queried'];
    final search = '${query['search'] ?? ''}'.toLowerCase();
    final rows = [
      for (final (i, (name, reference, date)) in _people.indexed)
        if ((query['type'] == null || query['type'] == types[i]) &&
            (search.isEmpty ||
                name.toLowerCase().contains(search) ||
                reference.toLowerCase().contains(search)))
          {
            'id': 4100 + i,
            'firstName': name.split(' ').first,
            'surname': name.split(' ').last,
            'middleName': null,
            'reference': 'BRT$reference',
            'date_created': date,
            'approvedStatus': statuses[i],
          },
    ];
    return {
      'result': rows,
      'pagination': {'page': 1, 'pages': 1},
    };
  }

  /// A sample still birth for list row [id], in the backend's field names
  /// and the demo's option ids. The first is approved.
  static Map<String, Object?>? _stillBirth(String id) {
    final index = (int.tryParse(id) ?? -1) - 30087677;
    if (index < 0 || index >= 3) return null;
    final (name, trackingId, date) = _people[index];
    return {
      'id': 30087677 + index,
      'tracking_id': trackingId,
      // Approval codes: pending 0, approved 1.
      'approved_status': index == 0 ? 1 : 0,
      'date_created': date,
      'birth_place': 1,
      'deceased_village': 'Amaba',
      'deceased_date_of_delivery': '2026-09-21',
      'birth_type': 1,
      'deceased_sex': 2,
      'mother_fullname': name,
      'mother_country': 63,
      'mother_state_residence': 1,
      'mother_lga': 11,
      'mother_settlement': 2,
      'mother_street_name': 'AMABA 2',
      'mother_age': 23,
      'mother_nationality': 63,
      'mother_state_of_origin': 1,
      'mother_ethnic_group': 2,
      'informant_relationship_with_mother': 2,
      'informant_fullname': name,
      'informant_country': 63,
      'informant_state': 1,
      'informant_lga': 11,
      'informant_street_name': 'No 2 Agwada street',
      'informant_settlement': 2,
      'informant_acknowledgement': 'stillbirth/sign-$index.png',
    };
  }

  /// `GET /death-registration/{id}`: files as URLs plus `raw…` keys, the
  /// place of death by description only.
  static Map<String, Object?>? _death(String id) {
    final number = int.tryParse(id) ?? -1;
    final statusIndex = (number - 40000) ~/ 100;
    final row = (number - 40000) % 100;
    const statuses = ['pending', 'approved', 'printed', 'queried'];
    if (statusIndex < 0 ||
        statusIndex >= statuses.length ||
        row >= _people.length) {
      return null;
    }
    final status = statuses[statusIndex];
    final (name, trackingId, _) = _people[row];
    final documents = [
      ('police-report', 'death/police-$number.jpg'),
      ('next-of-kin', 'death/kin-$number.jpg'),
      ('affidavit', 'death/affidavit-$number.jpg'),
    ];
    return {
      'data': {
        'id': number,
        'death_certificate_number': 'DC${trackingId.substring(2)}',
        // Approval codes: pending 0, approved (and printed) 1, queried 2.
        'approved_status': switch (status) {
          'pending' => 0,
          'queried' => 2,
          _ => 1,
        },
        'deceased_date_of_death': '2026-09-22',
        'deceased_age_at_death': 90,
        'deceased_cause_of_death': 3,
        'deceased_certified_by_doctor': 1,
        'informant_relationship_with_deceased': 3,
        'deceased_place_of_deathData': {'BirthPlace_Desc': 'At Home'},
        'informant_signature': 'https://demo.test/files/sign-$number.png',
        'rawInformantSignature': 'death/sign-$number.png',
        'SupportingDocument': [
          for (final (type, key) in documents)
            {'type': type, 'file': 'https://demo.test/files/$key'},
        ],
        'rawSupportingDocument': [
          for (final (type, key) in documents) {'type': type, 'file': key},
        ],
        'deceasedData': {
          'surname': name.split(' ').last,
          'firstname': name.split(' ').first,
          'gender': 2,
          'current_residence_country': 63,
          'current_residence_state': 1,
          'current_residence_lga': 11,
          'current_address': 'No.3 Owerri street',
          'birth_settlement_type': 2,
          'current_literacy_level': 1,
          'current_education_level': 6,
          'current_occupation': 100,
          'current_nationality': 63,
          'origin_state': 1,
          'origin_lga': 11,
          'ethnic_group': 2,
          'current_marital_status': 1,
        },
        'informantData': {
          'nin': '12342567890',
          'surname': 'Doe',
          'firstname': 'John',
          'current_phone_number': '08045365780',
          'current_residence_country': 63,
          'current_residence_state': 1,
          'current_residence_lga': 11,
          'current_address': 'No.3 Owerri street',
          'birth_settlement_type': 2,
        },
      },
      'queried': status == 'queried'
          ? {'reason': 'Wrong document uploaded'}
          : null,
    };
  }

  /// `{result, pagination}`, as `/death-registration/list/` answers.
  static Map<String, Object?> _deaths(Map<String, dynamic> query) {
    final status = query['type'] as String? ?? 'pending';
    final count = switch (status) {
      'pending' => 2,
      'approved' => 3,
      _ => 1,
    };
    final search = (query['search'] as String? ?? '').toLowerCase();
    final rows = [
      for (final (i, (name, trackingId, date)) in _people.indexed.take(count))
        if (search.isEmpty || name.toLowerCase().contains(search))
          {
            'id':
                40000 +
                100 *
                    const [
                      'pending',
                      'approved',
                      'printed',
                      'queried',
                    ].indexOf(status) +
                i,
            'death_certificate_number': 'DC${trackingId.substring(2)}',
            'deceasedData': {
              'surname': name.split(' ').last,
              'firstname': name.split(' ').first,
            },
            'date_created': date,
          },
    ];
    return {
      'result': rows,
      'pagination': {'page': 1, 'pages': 1, 'total': rows.length},
    };
  }

  /// `{result, pagination}`, as `/stillbirth/list/` answers.
  static Map<String, Object?> _stillBirths(Map<String, dynamic> query) {
    final search = (query['search'] as String? ?? '').toLowerCase();
    final rows = [
      for (final (i, (name, trackingId, date)) in _people.indexed.take(3))
        if (search.isEmpty || name.toLowerCase().contains(search))
          {
            'id': 30087677 + i,
            'mother_fullname': name,
            'tracking_id': trackingId,
            'deceased_date_of_delivery': date,
            'deceased_sex': 2,
            'birth_type': 1,
            'date_created': date,
            'status': i == 0 ? 'approved' : 'pending',
          },
    ];
    return {
      'result': rows,
      'pagination': {'page': 1, 'pages': 1, 'total': rows.length},
    };
  }

  /// `/birth-attestation/list?type=…`. A row's number encodes its status
  /// and sample person, for [_attestationRecord].
  static Map<String, Object?> _attestations(Map<String, dynamic> query) {
    final status = query['type'] as String? ?? 'pending';
    final count = switch (status) {
      'pending' => 2,
      'approved' => 3,
      'printed' => 4,
      _ => 1,
    };
    final search = (query['search'] as String? ?? '').toLowerCase();
    final rows = [
      for (final (i, (name, _, date)) in _people.indexed.take(count))
        if (search.isEmpty || name.toLowerCase().contains(search))
          {
            'id': 7000 + _attestationStatuses.indexOf(status) * 10 + i,
            'attestation_number': _attestationNumber(status, i),
            'date_created': date,
            'personData': {
              'surname': name.split(' ').last,
              'firstname': name.split(' ').first,
              'middle_name': null,
            },
          },
    ];
    return {
      'result': rows,
      'pagination': {'page': 1, 'pages': 1, 'total': rows.length},
    };
  }

  static const _attestationStatuses = [
    'pending',
    'approved',
    'queried',
    'printed',
  ];

  static String _newAttestationNumber() =>
      'FC${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}A'
          .toUpperCase();

  static String _attestationNumber(String status, int index) =>
      'ATT${_attestationStatuses.indexOf(status)}${'$index'.padLeft(4, '0')}';

  static const _modificationCounts = {
    'pending': 3,
    'approved': 2,
    'queried': 1,
  };

  /// Rows; each kind names its fields
  /// differently.
  static Map<String, Object?> _modifications(
    String kind,
    Map<String, dynamic> query,
  ) {
    final status = query['type'] as String? ?? 'pending';
    final search = (query['search'] as String? ?? '').toLowerCase();
    final rows = <Map<String, Object?>>[];
    for (final (i, (name, number, date)) in _people.indexed.take(
      _modificationCounts[status] ?? 0,
    )) {
      if (search.isNotEmpty &&
          !name.toLowerCase().contains(search) &&
          !number.toLowerCase().contains(search)) {
        continue;
      }
      final [firstname, surname] = name.split(' ');
      final person = {'firstname': firstname, 'surname': surname};
      final modified = [
        {'datetime_modified': date},
      ];
      rows.add(switch (kind) {
        'birth-attestation' => {
          'id': '$status-$i',
          'personData': person,
          'attestation_number': 'BA$number',
          'date_created': date,
        },
        'death-registration' => {
          'id': '$status-$i',
          'deceasedData': person,
          'death_certificate_number': 'DR$number',
          'Modification': modified,
        },
        _ => {
          'id': '$status-$i',
          'childData': person,
          'birth_number': number,
          'Modification': modified,
        },
      });
    }
    return {
      'result': rows,
      'pagination': {'page': 1, 'pages': 1, 'limit': 10},
    };
  }

  static const _optionStates = [(1, 'Abia'), (15, 'FCT'), (25, 'Lagos')];
  static const _optionLgas = {
    1: [(11, 'Isiukwuato'), (12, 'Umuahia North')],
    15: [(151, 'AMAC'), (152, 'Bwari')],
    25: [(251, 'Ikeja'), (252, 'Surulere')],
  };

  /// A queried birth modification as `single` returns it.
  static Map<String, Object?> _queriedModification(String id) => {
    'data': {
      'Birth_Reg_ID': 40,
      'Certificate_No': 'FA30087677',
      'child_surname': 'Lee',
      'child_firstname': 'Michael',
      'mother_surname': 'Lee',
      'mother_firstname': 'Grace',
      'father_surname': 'Lee',
      'father_firstname': 'Daniel',
      'Modification': [
        {
          'id': id,
          'reference': 'BRTDEMOQUERIED',
          'mod_type': 'child particulars',
          'mod_field': 'applicant_dob',
          'mod_reason': 'incorrect age entered',
          'comment': 'Hospital record shows a different date.',
          'child_age': '2020-09-08T00:00:00.000Z',
          'supportingDocument': [
            {
              'type': 'date-of-birth-affidavit',
              'file': 'modifications/demo-affidavit',
              'mimeType': 'image/jpeg',
            },
          ],
        },
      ],
    },
    'queried': {
      'type': 'modification',
      'reason': 'The request letter is missing. Upload it and resend.',
    },
  };

  /// Queried attestation and death modifications: the values sent are on
  /// `Modification[0]`.
  static Map<String, Object?> _queriedAttestation(String id) => {
    'data': {
      'id': 41,
      'attestation_number': 'BAFA30087677',
      'Modification': [
        {
          'id': id,
          'reference': 'BRTDEMOQUERIEDBA',
          'mod_type': 'particulars_of_applicant',
          'mod_field': 'applicant_name',
          'mod_reason': 'misspelling of name',
          'applicant_surname': 'Hasan',
          'applicant_firstname': 'Suleiman',
        },
      ],
    },
    'queried': {
      'reason':
          'The surname still looks misspelled. Check it against the '
          'birth certificate.',
    },
  };

  static Map<String, Object?> _queriedDeath(String id) => {
    'data': {
      'id': 42,
      'death_certificate_number': 'DRFA30087677',
      'Modification': [
        {
          'id': id,
          'reference': 'BRTDEMOQUERIEDDR',
          'mod_type': 'deceased_age_at_death',
          'mod_field': 'deceased_age_at_death',
          'mod_reason': 'incorrect age at entered',
          'deceased_age_at_death': 170,
        },
      ],
    },
    'queried': {'reason': 'The age at death is not possible.'},
  };

  /// A registered record as the lookup returns it.
  static Map<String, Object?> _modificationRecord(String kind, String number) {
    final person = {
      'surname': 'Hassan',
      'firstname': 'Suleiman',
      'middle_name': '',
      'birth_date': '2020-09-09T00:00:00.000Z',
      'gender': 1,
      'birth_state': 1,
      'birth_lga': 11,
      'town_of_birth': 'Ovim',
    };
    final parent = {'surname': 'Ikemefuna', 'firstname': 'Devine'};
    return switch (kind) {
      'birth-attestation' => {
        'id': 41,
        'personData': {
          ...person,
          'birth_date': '1990-03-14T00:00:00.000Z',
          'origin_state': 25,
          'origin_lga': 251,
          'town_of_origin': 'Ikeja',
        },
        'attestation_number': number,
        'mother_surname': 'Hassan',
        'mother_firstname': 'Amina',
        'mother_maiden_name': 'Bello',
        'father_surname': 'Hassan',
        'father_firstname': 'Musa',
      },
      'death-registration' => {
        'id': 42,
        'deceasedData': person,
        'death_certificate_number': number,
        'deceased_age_at_death': 70,
        'deceased_date_of_death': '2025-02-04',
      },
      _ => {
        'Birth_Reg_ID': 40,
        'Certificate_No': number,
        'childData': person,
        'motherData': parent,
        'fatherData': parent,
      },
    };
  }

  void _ok(
    RequestInterceptorHandler handler,
    RequestOptions options,
    Object? data,
  ) => handler.resolve(
    Response<Object?>(requestOptions: options, statusCode: 200, data: data),
  );

  void _fail(
    RequestInterceptorHandler handler,
    RequestOptions options,
    int statusCode,
    String message,
  ) => handler.reject(
    DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response<Object?>(
        requestOptions: options,
        statusCode: statusCode,
        data: {'message': message},
      ),
    ),
  );
}
