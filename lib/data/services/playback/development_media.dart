import 'dart:convert';

/// A private, expiring loopback source; never accepts external media URLs.
Uri parseDevelopmentMedia(String source, DateTime now) {
  if (source.length > 4096) throw const FormatException('Invalid media source');
  final data = jsonDecode(source);
  if (data is! Map<String, dynamic> ||
      data['uri'] is! String ||
      data['expiresAt'] is! String) {
    throw const FormatException('Invalid media source');
  }
  final uri = Uri.parse(data['uri'] as String);
  final expires = DateTime.parse(data['expiresAt'] as String);
  if (uri.scheme != 'http' ||
      uri.host != '127.0.0.1' ||
      !uri.hasPort ||
      uri.port < 1 ||
      uri.port > 65535 ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      !RegExp(r'^/[A-Za-z0-9_-]{32}$').hasMatch(uri.path) ||
      !expires.isAfter(now) ||
      expires.difference(now) > const Duration(minutes: 20)) {
    throw const FormatException('Invalid media source');
  }
  return uri;
}
