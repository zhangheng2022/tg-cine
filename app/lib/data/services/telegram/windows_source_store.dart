import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'windows_session.dart';

class WindowsSourceStore {
  const WindowsSourceStore(this.directory);
  final Directory directory;

  File _file(int accountId) {
    if (accountId <= 0) throw const FormatException('Invalid account');
    return File.fromUri(directory.uri.resolve('sources-$accountId.dpapi'));
  }

  Future<Set<int>> read(int accountId) async {
    final file = _file(accountId);
    if (!await file.exists()) return {};
    if (await file.length() > 65536) {
      throw const FormatException('Invalid source record');
    }
    final bytes = WindowsSession.unprotect(await file.readAsBytes());
    try {
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map ||
          value['schema'] != 1 ||
          value['accountId'] != accountId ||
          value['ids'] is! List) {
        throw const FormatException('Invalid source record');
      }
      final ids = value['ids'] as List;
      if (ids.length > 1000 ||
          ids.any((id) => id is! int || id == 0) ||
          ids.toSet().length != ids.length) {
        throw const FormatException('Invalid source record');
      }
      return ids.cast<int>().toSet();
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  Future<void> write(int accountId, Set<int> ids) async {
    final file = _file(accountId);
    if (ids.length > 1000 || ids.contains(0)) {
      throw const FormatException('Invalid source record');
    }
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({'schema': 1, 'accountId': accountId, 'ids': ids.toList()}),
      ),
    );
    try {
      final encrypted = WindowsSession.protect(bytes);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsBytes(encrypted, flush: true);
      // Keep the last committed record if replacement fails.
      if (await file.exists()) await file.copy('${file.path}.bak');
      await temporary.rename(file.path);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }
}
