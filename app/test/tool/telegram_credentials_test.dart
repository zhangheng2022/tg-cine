import 'package:flutter_test/flutter_test.dart';

import '../../tool/support/telegram_credentials.dart';

void main() {
  test('reads only API fields with quoted values and CRLF', () {
    final config = TelegramCredentials.parse(
      '# local fixture\r\nTG_API_ID=123\r\nTG_API_HASH="${'a' * 32}"\r\nRELAY_TOKEN=ignored',
    );
    expect(config.apiId, 123);
    expect(config.apiHash, 'a' * 32);
    expect(config.toString(), isNot(contains('a' * 32)));
  });

  test(
    'missing, malformed or duplicate API fields fail without reflecting input',
    () {
      for (final text in [
        'TG_API_ID=0\nTG_API_HASH=${'a' * 32}',
        'TG_API_ID=123\nTG_API_HASH=secret-invalid',
        'TG_API_ID=123\nTG_API_ID=456\nTG_API_HASH=${'a' * 32}',
      ]) {
        expect(() => TelegramCredentials.parse(text), throwsFormatException);
      }
    },
  );

  test(
    'authentication requests preserve passwords and validate phone and codes',
    () {
      expect(hideLoginInput('authorizationStateWaitPhoneNumber'), isFalse);
      expect(hideLoginInput('authorizationStateWaitEmailAddress'), isFalse);
      expect(hideLoginInput('authorizationStateWaitCode'), isTrue);
      expect(hideLoginInput('authorizationStateWaitEmailCode'), isTrue);
      expect(hideLoginInput('authorizationStateWaitPassword'), isTrue);
      expect(hideLoginInput('unknown'), isTrue);
      expect(
        loginRequest('authorizationStateWaitPhoneNumber', '+15551234567'),
        {
          '@type': 'setAuthenticationPhoneNumber',
          'phone_number': '+15551234567',
        },
      );
      expect(
        loginRequest(
          'authorizationStateWaitPhoneNumber',
          ' +1 555 123 4567 ',
        )['phone_number'],
        '+15551234567',
      );
      expect(
        loginRequest('authorizationStateWaitPassword', ' a 密码 ')['password'],
        ' a 密码 ',
      );
      expect(
        loginRequest('authorizationStateWaitEmailCode', '012345')['code'],
        {'@type': 'emailAddressAuthenticationCode', 'code': '012345'},
      );
      expect(
        () => loginRequest('authorizationStateWaitPhoneNumber', '123'),
        throwsFormatException,
      );
      expect(
        () => loginRequest('authorizationStateWaitCode', 'abc'),
        throwsFormatException,
      );
      expect(
        () => loginRequest('authorizationStateWaitRegistration', 'name'),
        throwsUnsupportedError,
      );
    },
  );
}
