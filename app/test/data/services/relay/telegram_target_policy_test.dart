import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/data/services/relay/telegram_target_policy.dart';

Map<String, Object> policyJson() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return {
    'kind': 'telegram-cidr',
    'port': 443,
    'cidrs': ['91.108.56.0/22', '2001:b28:f23f::/48'],
    'updatedAt': now,
    'expiresAt': now + 3600000,
  };
}

void main() {
  test('rotating IPv4 and IPv6 use canonical IP tokens, not fixed aliases', () {
    final policy = TelegramTargetPolicy.parse(policyJson());
    expect(policy.targetFor('91.108.56.139', 443), 'ip4_5b6c388b');
    expect(policy.targetFor('91.108.59.254', 443), isNotNull);
    expect(policy.targetFor('91.108.60.1', 443), isNull);
    expect(
      policy.targetFor('2001:b28:f23f::1', 443),
      'ip6_20010b28f23f00000000000000000001',
    );
    for (final host in [
      '127.0.0.1',
      '10.0.0.1',
      '::1',
      '::ffff:91.108.56.139',
      '8.8.8.8',
      'evil.example',
      '2001:b28:f23e::1',
    ]) {
      expect(policy.targetFor(host, 443), isNull);
    }
    expect(policy.targetFor('91.108.56.139', 80), isNull);
    expect(encodeTelegramTarget('host.example', 443), isNull);
  });
  test('rejects malformed, stale, overbroad and oversized policies', () {
    for (final patch in [
      {'kind': 'fixed'},
      {'port': 80},
      {'cidrs': <String>[]},
      {
        'cidrs': ['invalid'],
      },
      {
        'cidrs': ['0.0.0.0/0'],
      },
      {
        'cidrs': ['91.108.56.0/33'],
      },
      {
        'cidrs': ['::/0'],
      },
      {'cidrs': List.filled(129, '91.108.56.0/22')},
      {'expiresAt': 0},
    ]) {
      expect(
        () => TelegramTargetPolicy.parse({...policyJson(), ...patch}),
        throwsFormatException,
      );
    }
  });
}
