import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/core/session/auth_tokens.dart';
import 'package:vital_reg_mobile/core/session/device_id.dart';
import 'package:vital_reg_mobile/core/session/session_manager.dart';
import 'package:vital_reg_mobile/core/session/user_scope.dart';
import 'package:vital_reg_mobile/core/storage/draft_files.dart';
import 'package:vital_reg_mobile/core/storage/user_storage.dart';
import 'package:vital_reg_mobile/features/auth/data/auth_api.dart';
import 'package:vital_reg_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:vital_reg_mobile/features/auth/data/dtos/sign_in_dto.dart';
import 'package:vital_reg_mobile/features/auth/data/dtos/user_dto.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/permission.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/user.dart';
import 'package:vital_reg_mobile/features/auth/domain/value_objects/credentials.dart';

import '../../helpers/fakes.dart';

class _MockAuthApi extends Mock implements AuthApi {}

class _MockCrashReporter extends Mock implements CrashReporter {}

/// The `user` of a sign-in response, as the backend sends it.
Map<String, Object?> _backendUser({Object? roleId = 3}) => {
  'User_ID': 41,
  'UserName': 'ada.l',
  'Email': 'ada@example.com',
  'First_Name': 'Ada',
  'Last_Name': 'Lovelace',
  'Role_ID': roleId,
};

SignInDto _signIn({Object? roleId = 3}) => SignInDto.fromJson({
  'success': true,
  'user': _backendUser(roleId: roleId),
  'access_token': 'token-1',
});

const _email = Email.dirty('ada@example.com');
const _password = Password.dirty('correct-horse');
const _draftKey = 'birth_registration_draft';

void main() {
  late Directory root;
  late _MockAuthApi api;
  late UserScope scope;
  late UserStorage userStorage;
  late InMemoryTokenStorage tokens;
  late SessionManager session;
  late AuthRepositoryImpl repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('auth_repository_test');
    api = _MockAuthApi();
    final crashReporter = _MockCrashReporter();
    when(() => crashReporter.setUser(any())).thenAnswer((_) async {});
    when(
      () => api.logout(user: any(named: 'user')),
    ).thenAnswer((_) async => const Ok(null));
    scope = UserScope();
    userStorage = UserStorage(
      const FlutterSecureStorage(),
      scope,
      files: DraftFiles(scope, root: () async => root),
    );
    tokens = InMemoryTokenStorage();
    session = SessionManager(tokens);
    repository = AuthRepositoryImpl(
      api: api,
      sessionManager: session,
      storage: const FlutterSecureStorage(),
      userStorage: userStorage,
      deviceId: DeviceId(const FlutterSecureStorage()),
      crashReporter: crashReporter,
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  void answerSignIn(SignInDto dto) => when(
    () => api.login(
      user: any(named: 'user'),
      password: any(named: 'password'),
      device: any(named: 'device'),
    ),
  ).thenAnswer((_) async => Ok(dto));

  group('signIn', () {
    test('sends the login, password and this device', () async {
      answerSignIn(_signIn());

      await repository.signIn(email: _email, password: _password);
      await repository.signIn(email: _email, password: _password);

      final devices = verify(
        () => api.login(
          user: 'ada@example.com',
          password: 'correct-horse',
          device: captureAny(named: 'device'),
        ),
      ).captured;
      expect(devices, hasLength(2));
      expect(devices.first, isNotEmpty);
      expect(devices.last, devices.first, reason: 'one id per install');
    });

    test('starts the session and keeps the user from the response', () async {
      answerSignIn(_signIn());

      expect(
        await repository.signIn(email: _email, password: _password),
        const Ok<void>(null),
      );
      expect(await tokens.read(), const AuthTokens(accessToken: 'token-1'));

      final user = (await repository.currentUser() as Ok<User>).value;
      expect(user.id, '41');
      expect(user.fullName, 'Ada Lovelace');
      expect(user.role, UserRole.registrar);
      expect(scope.userId, '41');
    });

    test('refuses roles this app does not serve, with no session', () async {
      answerSignIn(_signIn(roleId: 2)); // A DCR.

      final result = await repository.signIn(
        email: _email,
        password: _password,
      );

      expect(result, isA<Err<void>>());
      expect((result as Err).failure, isA<ForbiddenFailure>());
      expect(await tokens.read(), isNull);
    });

    test('passes on what the server said, e.g. a second device', () async {
      when(
        () => api.login(
          user: any(named: 'user'),
          password: any(named: 'password'),
          device: any(named: 'device'),
        ),
      ).thenAnswer(
        (_) async => const Err(
          ValidationFailure(message: 'You can only use the first device'),
        ),
      );

      final result = await repository.signIn(
        email: _email,
        password: _password,
      );

      expect(
        (result as Err).failure,
        const ValidationFailure(message: 'You can only use the first device'),
      );
    });
  });

  test('with no signed-in user, currentUser fails', () async {
    expect(
      await repository.currentUser(),
      const Err<User>(UnauthorizedFailure()),
    );
  });

  group('signOut', () {
    setUp(() async {
      answerSignIn(_signIn());
      await repository.signIn(email: _email, password: _password);
      await repository.currentUser();
      await userStorage.write(key: _draftKey, value: 'draft');
    });

    test('on purpose records it and removes the drafts', () async {
      await repository.signOut(reason: SessionEndReason.userInitiated);

      verify(() => api.logout(user: 'ada.l')).called(1);
      expect(await userStorage.read(key: _draftKey), isNull);
      expect(await tokens.read(), isNull);
    });

    test('after expiry does not call the server', () async {
      await repository.signOut(reason: SessionEndReason.expired);
      verifyNever(() => api.logout(user: any(named: 'user')));
    });

    for (final reason in [
      SessionEndReason.inactivity,
      SessionEndReason.expired,
      SessionEndReason.invalid,
    ]) {
      test('after ${reason.name} keeps the drafts', () async {
        await repository.signOut(reason: reason);
        expect(await userStorage.read(key: _draftKey), 'draft');
      });
    }
  });

  group('UserDto.fromSignIn', () {
    test('is null for an account with no role this app serves', () {
      expect(UserDto.fromSignIn({'User_ID': '7', 'UserName': 'reg7'}), isNull);
    });

    test('reads names, and the user name when there are none', () {
      final named = UserDto.fromSignIn(_backendUser())!;
      final unnamed = UserDto.fromSignIn({
        'User_ID': 7,
        'UserName': 'reg7',
        'Role_ID': '4',
      })!;

      expect(named.fullName, 'Ada Lovelace');
      expect(named.login, 'ada.l');
      expect(unnamed.fullName, 'reg7');
      expect(unnamed.role, UserRole.registrar);
    });

    test('keeps the account\'s state and LGA, also on the device', () {
      final dto = UserDto.fromSignIn({
        'User_ID': 7,
        'UserName': 'reg7',
        'Role_ID': '4',
        'State_ID': 19,
        'LGA_ID': '249',
      })!;
      final kept = UserDto.fromJson(dto.toJson()).toDomain();

      expect((kept.stateId, kept.lgaId), ('19', '249'));
    });

    test("keeps the profile's details, also on the device", () {
      final dto = UserDto.fromSignIn({
        'User_ID': 7,
        'UserName': 'reg7',
        'Email': 'reg7@npc.gov.ng',
        'Phone_No': '08130845852',
        'Role_ID': 3,
        'roles': {'id': 3, 'name': 'Registrar'},
        'Registration_Centres': {'Reg_Center_Name': 'Ikeja Centre'},
      })!;
      final kept = UserDto.fromJson(dto.toJson()).toDomain();

      expect(kept.userName, 'reg7');
      expect(kept.email, 'reg7@npc.gov.ng');
      expect(kept.phone, '08130845852');
      expect(kept.roleName, 'Registrar');
      expect(kept.centreName, 'Ikeja Centre');
    });

    test('a copy saved before they were kept reads without them', () {
      final user = UserDto.fromJson({
        'id': '7',
        'fullName': 'reg7',
        'role': 'registrar',
        'login': 'reg7',
      }).toDomain();

      expect((user.stateId, user.lgaId), (null, null));
    });
  });

  test('a configured device id is used as is, and not stored', () async {
    final configured = DeviceId(const FlutterSecureStorage(), override: 'abc');
    expect(await configured.read(), 'abc');

    final generated = await DeviceId(const FlutterSecureStorage()).read();
    expect(generated, isNot('abc'));
  });

  test('the device id survives a fresh app start and a sign-out', () async {
    final first = await DeviceId(const FlutterSecureStorage()).read();
    await userStorage.clearDrafts();
    final again = await DeviceId(const FlutterSecureStorage()).read();
    expect(again, first);
  });
}
