class TelegramCredentials {
  TelegramCredentials._(this.apiId, this.apiHash);

  final int apiId;
  final String apiHash;

  factory TelegramCredentials.parse(String text) {
    final values = <String, String>{};
    for (final line in text.split('\n')) {
      final source = line.trim();
      final split = source.indexOf('=');
      if (split < 1 || source.startsWith('#')) continue;
      final name = source.substring(0, split).trim();
      if (name != 'TG_API_ID' && name != 'TG_API_HASH') continue;
      if (values.containsKey(name)) {
        throw const FormatException('Duplicate API key');
      }
      var value = source.substring(split + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      values[name] = value;
    }
    final id = int.tryParse(values['TG_API_ID'] ?? '');
    final hash = values['TG_API_HASH'] ?? '';
    if (id == null ||
        id <= 0 ||
        id > 2147483647 ||
        !RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(hash)) {
      throw const FormatException('Invalid Telegram API configuration');
    }
    return TelegramCredentials._(id, hash);
  }
}

Map<String, dynamic> loginRequest(String state, String input) {
  final value = input.trim();
  switch (state) {
    case 'authorizationStateWaitPhoneNumber':
      final phone = value.replaceAll(' ', '');
      if (!RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(phone)) {
        throw const FormatException('Use an international phone number');
      }
      return {'@type': 'setAuthenticationPhoneNumber', 'phone_number': phone};
    case 'authorizationStateWaitCode':
      if (!RegExp(r'^[0-9]{3,12}$').hasMatch(value)) {
        throw const FormatException('Invalid code format');
      }
      return {'@type': 'checkAuthenticationCode', 'code': value};
    case 'authorizationStateWaitPassword':
      if (input.isEmpty) throw const FormatException('Password required');
      return {'@type': 'checkAuthenticationPassword', 'password': input};
    case 'authorizationStateWaitEmailAddress':
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
        throw const FormatException('Invalid email format');
      }
      return {'@type': 'setAuthenticationEmailAddress', 'email_address': value};
    case 'authorizationStateWaitEmailCode':
      if (!RegExp(r'^[0-9]{3,12}$').hasMatch(value)) {
        throw const FormatException('Invalid email code format');
      }
      return {
        '@type': 'checkAuthenticationEmailCode',
        'code': {'@type': 'emailAddressAuthenticationCode', 'code': value},
      };
    default:
      throw UnsupportedError('Unsupported local authentication state');
  }
}

bool hideLoginInput(String state) =>
    state != 'authorizationStateWaitPhoneNumber' &&
    state != 'authorizationStateWaitEmailAddress';
