import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

final class _Blob extends Struct {
  @Uint32()
  external int length;
  external Pointer<Uint8> data;
}

typedef _CryptNative = Int32 Function(
  Pointer<_Blob>,
  Pointer<Void>,
  Pointer<_Blob>,
  Pointer<Void>,
  Pointer<Void>,
  Uint32,
  Pointer<_Blob>,
);
typedef _CryptDart = int Function(
  Pointer<_Blob>,
  Pointer<Void>,
  Pointer<_Blob>,
  Pointer<Void>,
  Pointer<Void>,
  int,
  Pointer<_Blob>,
);

/// Windows session protected by DPAPI and an exclusive database lock.
// shortcut: Windows keystore only; add platform keystores before enabling other native clients.
class WindowsSession {
  WindowsSession._(this.directory, this.key, this._lock);

  final Directory directory;
  final Uint8List key;
  final RandomAccessFile _lock;

  static Future<WindowsSession> open(
    Directory directory, {
    required File permissionsScript,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows development probe');
    }
    final permissions = await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      permissionsScript.absolute.path,
      '-Path',
      directory.absolute.path,
    ]);
    if (permissions.exitCode != 0) {
      throw StateError('Session permissions failed');
    }
    final lock = await File.fromUri(directory.uri.resolve('.session.lock'))
        .open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.exclusive);
      final file = File.fromUri(directory.uri.resolve('key.dpapi'));
      final Uint8List key;
      if (await file.exists()) {
        key = _crypt(await file.readAsBytes(), protect: false);
        if (key.length != 32) throw StateError('Invalid session key');
      } else {
        // Never replace a missing key belonging to an existing database.
        if ((await directory.list().toList()).any(
          (entry) => entry.path != lock.path,
        )) {
          throw StateError('Session exists without its key');
        }
        final random = Random.secure();
        key = Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
        final protected = _crypt(key, protect: true);
        final temp = File.fromUri(directory.uri.resolve('key.dpapi.tmp'));
        await temp.writeAsBytes(protected, flush: true);
        await temp.rename(file.path);
      }
      return WindowsSession._(directory, key, lock);
    } catch (_) {
      await lock.close();
      rethrow;
    }
  }

  Future<void> close() async {
    key.fillRange(0, key.length, 0);
    await _lock.close();
  }

  static Uint8List protect(Uint8List bytes) => _crypt(bytes, protect: true);
  static Uint8List unprotect(Uint8List bytes) => _crypt(bytes, protect: false);

  static Uint8List _crypt(Uint8List bytes, {required bool protect}) {
    final function = DynamicLibrary.open('crypt32.dll')
        .lookupFunction<_CryptNative, _CryptDart>(
          protect ? 'CryptProtectData' : 'CryptUnprotectData',
        );
    final free = DynamicLibrary.open('kernel32.dll')
        .lookupFunction<
          Pointer<Void> Function(Pointer<Void>),
          Pointer<Void> Function(Pointer<Void>)
        >('LocalFree');
    final input = calloc<_Blob>();
    final output = calloc<_Blob>();
    final data = calloc<Uint8>(bytes.length);
    data.asTypedList(bytes.length).setAll(0, bytes);
    input.ref
      ..length = bytes.length
      ..data = data;
    try {
      if (function(input, nullptr, nullptr, nullptr, nullptr, 1, output) == 0) {
        throw StateError('Windows session protection failed');
      }
      return Uint8List.fromList(output.ref.data.asTypedList(output.ref.length));
    } finally {
      if (output.ref.data != nullptr) {
        if (!protect) {
          output.ref.data
              .asTypedList(output.ref.length)
              .fillRange(0, output.ref.length, 0);
        }
        free(output.ref.data.cast());
      }
      data.asTypedList(bytes.length).fillRange(0, bytes.length, 0);
      calloc.free(data);
      calloc.free(input);
      calloc.free(output);
    }
  }
}
