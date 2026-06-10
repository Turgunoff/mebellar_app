import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/auth/auth_sheet_controller.dart';
import 'package:woody_app/auth/sheets/auth_sheet_kit.dart';
import 'package:woody_app/core/auth/auth_repository.dart';
import 'package:woody_app/core/di/service_locator.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/shared/models/me.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

void main() {
  // The controller drives the real Phone -> OTP -> Profile state machine; the
  // backend is faked through a mock AuthRepository registered in GetIt, exactly
  // as the live sheet resolves it (`sl<AuthRepository>()`). SMS autofill is a
  // no-op off-Android, so the linux test host never touches smart_auth.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAuthRepo repo;

  const tokens = TokenPair(accessToken: 'a', refreshToken: 'r');

  setUp(() {
    repo = _MockAuthRepo();
    when(() => repo.requestOtp(any())).thenAnswer((_) async => 60);
    when(() => repo.verifyOtp(any(), any())).thenAnswer((_) async => tokens);
    when(() => repo.updateProfile(fullName: any(named: 'fullName')))
        .thenAnswer((_) async =>
            const Me(id: 'u1', fullName: 'Ali Valiyev', phone: '+998901234567'));

    if (sl.isRegistered<AuthRepository>()) {
      sl.unregister<AuthRepository>();
    }
    sl.registerSingleton<AuthRepository>(repo);
  });

  tearDown(() => sl.reset());

  AuthSheetController makeController() {
    final c = AuthSheetController();
    addTearDown(c.dispose);
    return c;
  }

  test('rejects an incomplete phone number without calling the backend',
      () async {
    final c = makeController();
    c.phoneCtrl.text = '90123'; // only 5 digits

    await c.sendOtp();

    expect(c.step, AuthStep.phone);
    expect(c.errorMessage, isNotNull);
    verifyNever(() => repo.requestOtp(any()));
  });

  test('a valid phone advances Phone -> OTP and requests the code in E.164',
      () async {
    final c = makeController();
    c.phoneCtrl.text = '90 123 45 67';

    await c.sendOtp();

    expect(c.step, AuthStep.otp);
    expect(c.errorMessage, isNull);
    verify(() => repo.requestOtp('+998901234567')).called(1);
  });

  test('verifying an OTP for a profileless user advances OTP -> Profile',
      () async {
    when(() => repo.fetchMe()).thenAnswer((_) async => const Me(id: 'u1'));
    final c = makeController();
    c.phoneCtrl.text = '901234567';
    await c.sendOtp();
    c.otpCtrl.text = '1234';

    await c.verifyOtp();

    expect(c.step, AuthStep.profile);
    verify(() => repo.verifyOtp('+998901234567', '1234')).called(1);
  });

  test('verifying an OTP for a user who already has a profile completes',
      () async {
    when(() => repo.fetchMe())
        .thenAnswer((_) async => const Me(id: 'u1', fullName: 'Existing User'));
    var completed = false;
    final c = makeController()..onCompleted = () => completed = true;
    c.phoneCtrl.text = '901234567';
    await c.sendOtp();
    c.otpCtrl.text = '1234';

    await c.verifyOtp();

    expect(completed, isTrue);
    expect(c.step, AuthStep.otp); // never advanced to the profile step
  });

  test('saving a profile name persists it and completes the flow', () async {
    var completed = false;
    final c = makeController()..onCompleted = () => completed = true;
    c.nameCtrl.text = 'Ali Valiyev';

    await c.saveProfile();

    expect(completed, isTrue);
    verify(() => repo.updateProfile(fullName: 'Ali Valiyev')).called(1);
  });

  test('rejects a too-short name without calling the backend', () async {
    final c = makeController();
    c.nameCtrl.text = 'A';

    await c.saveProfile();

    expect(c.errorMessage, isNotNull);
    verifyNever(() => repo.updateProfile(fullName: any(named: 'fullName')));
  });
}
