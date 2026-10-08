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
///   and submitting succeeds when the fields the API requires are there.
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

  static const _optionStates = [(1, 'Abia'), (15, 'FCT'), (25, 'Lagos')];
  static const _optionLgas = {
    1: [(11, 'Isiukwuato'), (12, 'Umuahia North')],
    15: [(151, 'AMAC'), (152, 'Bwari')],
    25: [(251, 'Ikeja'), (252, 'Surulere')],
  };

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
