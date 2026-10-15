import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../domain/models/telegram_account.dart';
import 'telegram_target_policy.dart';

class PublicRelayConfiguration {
  const PublicRelayConfiguration(this.relay, this.policy);
  final Uri relay;
  final TelegramTargetPolicy policy;
}

/// Only the installation refresh credential enters the platform vault.
class PublicRelayService {
  PublicRelayService(this._storage, {Uri? origin})
    : origin = origin ?? Uri.https('tg-cine.zhangheng.eu.org', '');
  final FlutterSecureStorage _storage;
  final Uri origin;
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  String get credentialKey =>
      'tg-cine.public-relay.${origin.host}.${origin.port}.refresh.v1';
  String? _access;
  DateTime? _expires;
  Future<String>? _refreshing;
  bool _closed = false;
  PublicRelayConfiguration? _configuration;
  Future<PublicRelayConfiguration>? _configuring;

  Future<String?> targetFor(String host, int port) async {
    final cached = _configuration;
    final config =
        cached != null &&
            cached.policy.expiresAt.isAfter(
              DateTime.now().add(const Duration(seconds: 30)),
            )
        ? cached
        : await configuration();
    return config.policy.targetFor(host, port);
  }

  Future<PublicRelayConfiguration> configuration() {
    if (_configuring case final pending?) return pending;
    final operation = _configurationRequest();
    _configuring = operation;
    return operation.whenComplete(() {
      if (identical(_configuring, operation)) _configuring = null;
    });
  }

  Future<PublicRelayConfiguration> _configurationRequest() async {
    final value = await _request('/v1/config');
    try {
      if (value['protocolVersion'] != 1 ||
          value['relay'] is! String ||
          value['targetPolicy'] is! Map) {
        throw const FormatException('Invalid public configuration');
      }
      final relay = Uri.parse(value['relay'] as String);
      if (relay.host != origin.host ||
          (relay.hasPort ? relay.port : (relay.scheme == 'wss' ? 443 : 80)) !=
              origin.port ||
          relay.path != '/v1/tunnel' ||
          relay.hasQuery ||
          relay.hasFragment ||
          relay.userInfo.isNotEmpty ||
          (relay.scheme != 'wss' &&
              !(relay.scheme == 'ws' && origin.host == '127.0.0.1'))) {
        throw const FormatException('Untrusted relay origin');
      }
      final policy = TelegramTargetPolicy.parse(value['targetPolicy']);
      return _configuration = PublicRelayConfiguration(relay, policy);
    } catch (_) {
      throw const TelegramException(TelegramFailure.unavailable);
    }
  }

  Future<String> accessToken() {
    if (_closed) {
      return Future.error(const TelegramException(TelegramFailure.connection));
    }
    if (_access != null &&
        _expires!.isAfter(DateTime.now().add(const Duration(seconds: 30)))) {
      return Future.value(_access!);
    }
    if (_refreshing case final operation?) return operation;
    final operation = _credentials();
    _refreshing = operation;
    return operation.whenComplete(() {
      if (identical(_refreshing, operation)) _refreshing = null;
    });
  }

  Future<String> _credentials() async {
    final refresh = await _storage.read(key: credentialKey);
    final value = await _request(
      refresh == null ? '/v1/devices' : '/v1/devices/refresh',
      token: refresh,
      post: true,
    );
    final token = value['accessToken'];
    final expires = value['expiresAt'];
    if (!_validToken(token, 'a') ||
        expires is! int ||
        expires <= DateTime.now().millisecondsSinceEpoch + 30_000 ||
        expires > DateTime.now().millisecondsSinceEpoch + 15 * 60 * 1000) {
      throw const TelegramException(TelegramFailure.unavailable);
    }
    final refreshValue = refresh ?? value['refreshToken'];
    if (!_validToken(refreshValue, 'r') ||
        (token as String).split('.')[1] !=
            (refreshValue as String).split('.')[1]) {
      throw const TelegramException(TelegramFailure.unavailable);
    }
    if (refresh == null) {
      if (!_validToken(value['refreshToken'], 'r')) {
        throw const TelegramException(TelegramFailure.unavailable);
      }
      await _storage.write(
        key: credentialKey,
        value: value['refreshToken'] as String,
      );
    }
    if (_closed) throw const TelegramException(TelegramFailure.connection);
    _access = token;
    _expires = DateTime.fromMillisecondsSinceEpoch(expires);
    return _access!;
  }

  bool _validToken(Object? value, String type) =>
      value is String &&
      RegExp('^$type\\.[0-9a-f-]{36}\\.[A-Za-z0-9_-]{43}\\.[A-Za-z0-9_-]{43}\$')
          .hasMatch(value);

  Future<void> revoke() async {
    final refresh = await _storage.read(key: credentialKey);
    try {
      if (refresh != null) {
        await _request('/v1/devices/revoke', token: refresh, post: true);
      }
    } on TelegramException catch (error) {
      if (error.failure != TelegramFailure.authentication) rethrow;
    }
    await _storage.delete(key: credentialKey);
    _access = null;
    _expires = null;
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    String? token,
    bool post = false,
  }) async {
    if (_closed ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        origin.path.isNotEmpty ||
        (origin.scheme != 'https' &&
            !(origin.scheme == 'http' && origin.host == '127.0.0.1'))) {
      throw const TelegramException(TelegramFailure.unavailable);
    }
    if (token != null && !_validToken(token, 'r')) {
      throw const TelegramException(TelegramFailure.authentication);
    }
    try {
      final request = await _client
          .openUrl(post ? 'POST' : 'GET', origin.resolve(path))
          .timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (post) {
        request.headers.contentType = ContentType.json;
        request.write('{}');
      }
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode == 401) {
        throw const TelegramException(TelegramFailure.authentication);
      }
      if (response.statusCode == 429) {
        throw const TelegramException(TelegramFailure.serviceLimited);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const TelegramException(TelegramFailure.unavailable);
      }
      if (response.statusCode == 204) return {};
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        if (bytes.length + chunk.length > 32768) {
          throw const FormatException('Oversized service response');
        }
        bytes.addAll(chunk);
      }
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } on TelegramException {
      rethrow;
    } catch (_) {
      throw const TelegramException(TelegramFailure.connection);
    }
  }

  void close() {
    _closed = true;
    _client.close(force: true);
  }
}
