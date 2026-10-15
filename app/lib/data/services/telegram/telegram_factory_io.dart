import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../domain/ports/telegram_repository.dart';
import '../../repositories/tdlib_telegram_repository.dart';
import 'mobile_telegram.dart';
import 'windows_telegram.dart';
import '../relay/public_relay_service.dart';

TelegramRepository? createTelegramRepository() {
  const path = String.fromEnvironment('TG_CINE_TELEGRAM_CONFIG');
  const mobile = String.fromEnvironment('TG_CINE_TELEGRAM_MOBILE_CONFIG');
  if (kDebugMode &&
      (Platform.isAndroid || Platform.isIOS) &&
      mobile.isNotEmpty) {
    return TdlibTelegramRepository(() => openNativeTelegram(mobile));
  }
  if (kDebugMode && Platform.isWindows && path.isNotEmpty) {
    const useDefault = bool.fromEnvironment('TG_CINE_USE_DEFAULT_SERVICE');
    return TdlibTelegramRepository(
      () => openWindowsTelegram(path, defaultService: useDefault),
      defaultService: useDefault,
      resetDefaultAccess: useDefault ? _resetDefaultAccess : null,
    );
  }
  if (!(Platform.isAndroid || Platform.isIOS || Platform.isWindows)) {
    return null;
  }
  const apiId = String.fromEnvironment('TG_CINE_API_ID');
  const apiHash = String.fromEnvironment('TG_CINE_API_HASH');
  if (apiId.isEmpty || apiHash.isEmpty) return null;
  return TdlibTelegramRepository(
    () => openNativeTelegram(
      jsonEncode({'apiId': int.tryParse(apiId), 'apiHash': apiHash}),
      defaultService: true,
    ),
    defaultService: true,
    resetDefaultAccess: _resetDefaultAccess,
  );
}

Future<void> _resetDefaultAccess() async {
  final service = PublicRelayService(
    const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  );
  try {
    await service.revoke();
  } finally {
    service.close();
  }
}
