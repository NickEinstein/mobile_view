import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/dtos/nin_dtos.dart';

const _record = {
  'status': 1,
  'lastname': 'Obi',
  'firstname': 'Ada',
  'middlename': '',
  'dob': '14-06-1990',
  'gender': 'f',
  'photo': 'BASE64',
};

void main() {
  test('reads the record under "nimc", as the backend sends it', () {
    final json = {'nimc': _record};

    final record = ninRecordFromJson(json, nin: '99990000999');

    expect(record?.surname, 'Obi');
    expect(record?.firstName, 'Ada');
    expect(record?.dateOfBirth, DateTime(1990, 6, 14));
    expect(ninPhotoFromJson(json), 'BASE64');
  });

  test('a reply without "nimc" is read as the record itself', () {
    expect(ninRecordFromJson(_record, nin: '1')?.surname, 'Obi');
  });

  test('status 0 means no record', () {
    expect(
      ninRecordFromJson({
        'nimc': {'status': 0},
      }, nin: '1'),
      isNull,
    );
  });
}
