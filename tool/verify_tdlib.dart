import 'dart:io';

import 'support/tdlib_probe.dart';

/// Loads a locally built native library without credentials, databases or login.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run tool/verify_tdlib.dart <tdjson-library>');
    exitCode = 64;
    return;
  }
  TdlibProbe? client;
  try {
    client = TdlibProbe(arguments.single);
    final version = client.sync({'@type': 'getOption', 'name': 'version'});
    if (version['@type'] != 'optionValueString' ||
        version['value'] is! String) {
      throw StateError('Native version unavailable');
    }
    await client.request({'@type': 'getAuthorizationState'});
    await client.awaitState('authorizationStateWaitTdlibParameters');
    await client.close();
    stdout.writeln(
      'Verified TDLib ${version['value']}: JSON ABI, initial state and clean close. No account login.',
    );
  } catch (_) {
    stderr.writeln(
      'Native TDLib verification failed; sensitive details omitted.',
    );
    exitCode = 1;
  } finally {
    try {
      await client?.close();
    } catch (_) {
      stderr.writeln('Native close failed; sensitive details omitted.');
      exitCode = 1;
    }
  }
}
