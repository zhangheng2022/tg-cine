import 'dart:io';

String? encodeTelegramTarget(String host, int port) {
  final address = InternetAddress.tryParse(host);
  if (address == null || host.contains('%') || port != 443) return null;
  final bytes = address.rawAddress;
  return 'ip${bytes.length == 4 ? 4 : 6}_${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
}

class TelegramTargetPolicy {
  TelegramTargetPolicy._(this._networks, this.expiresAt);
  final List<(List<int>, int)> _networks;
  final DateTime expiresAt;

  factory TelegramTargetPolicy.parse(Object? value) {
    if (value is! Map ||
        value['kind'] != 'telegram-cidr' ||
        value['port'] != 443 ||
        value['cidrs'] is! List ||
        value['updatedAt'] is! int ||
        value['expiresAt'] is! int) {
      throw const FormatException('Invalid Telegram target policy');
    }
    final expiry = value['expiresAt'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (expiry <= now ||
        expiry > now + 3900000 ||
        expiry - (value['updatedAt'] as int) != 3600000) {
      throw const FormatException('Expired Telegram target policy');
    }
    final entries = value['cidrs'] as List;
    if (entries.isEmpty || entries.length > 128) {
      throw const FormatException('Invalid Telegram networks');
    }
    final networks = <(List<int>, int)>[];
    for (final cidr in entries) {
      if (cidr is! String) {
        throw const FormatException('Invalid Telegram network');
      }
      final parts = cidr.split('/');
      if (parts.length != 2) {
        throw const FormatException('Invalid Telegram network');
      }
      final address = InternetAddress.tryParse(parts[0]);
      final prefix = int.tryParse(parts[1]);
      if (address == null ||
          parts[0].contains('%') ||
          prefix == null ||
          prefix < (address.rawAddress.length == 4 ? 8 : 16) ||
          prefix > address.rawAddress.length * 8) {
        throw const FormatException('Invalid Telegram network');
      }
      networks.add((address.rawAddress, prefix));
    }
    return TelegramTargetPolicy._(
      List.unmodifiable(networks),
      DateTime.fromMillisecondsSinceEpoch(expiry),
    );
  }

  String? targetFor(String host, int port) {
    final address = InternetAddress.tryParse(host);
    if (address == null || !expiresAt.isAfter(DateTime.now())) return null;
    final bytes = address.rawAddress;
    for (final (network, prefix) in _networks) {
      if (network.length != bytes.length) continue;
      var matches = true;
      for (var bit = 0; bit < prefix; bit++) {
        final mask = 1 << (7 - bit % 8);
        if ((network[bit ~/ 8] & mask) != (bytes[bit ~/ 8] & mask)) {
          matches = false;
          break;
        }
      }
      if (matches) return encodeTelegramTarget(host, port);
    }
    return null;
  }
}
