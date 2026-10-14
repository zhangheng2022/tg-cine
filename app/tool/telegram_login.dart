import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tg_cine/data/services/relay/relay_bridge.dart';

import 'relay_bridge.dart' as bridge_tool;
import 'support/media_probe.dart';
import 'support/local_media_server.dart';
import 'support/media_selection.dart';
import 'support/playback_probe.dart';
import 'support/playback_session_probe.dart';
import 'support/tdlib_probe.dart';
import 'support/telegram_credentials.dart';
import 'support/windows_session.dart';
import 'support/playback_trace.dart';

/// Local development harness. Released Flutter builds never load this config.
Future<void> main(List<String> arguments) async {
  if (arguments.length < 3 ||
      arguments.length > 4 ||
      (arguments.length == 4 &&
          ![
            '--login',
            '--select-media',
            '--verify-media',
            '--verify-playback',
            '--verify-session',
            '--serve-media',
          ].contains(arguments.last))) {
    stderr.writeln(
      'Usage: dart run tool/telegram_login.dart <tdjson-library> <local-config.json> <api-env-file> [--login|--select-media|--verify-media|--verify-playback|--verify-session|--serve-media]',
    );
    exitCode = 64;
    return;
  }
  final playbackSession =
      arguments.length == 4 && arguments.last == '--verify-session';
  final serving = arguments.length == 4 && arguments.last == '--serve-media';
  final playback =
      playbackSession ||
      (arguments.length == 4 && arguments.last == '--verify-playback');
  final verifying =
      serving ||
      playback ||
      (arguments.length == 4 && arguments.last == '--verify-media');
  final interactive = arguments.length == 4 && !verifying;
  final selecting = interactive && arguments.last == '--select-media';
  if (interactive && !stdin.hasTerminal) {
    stderr.writeln(
      'Login requires a local terminal. Never send codes or passwords to chat.',
    );
    exitCode = 64;
    return;
  }
  RelayBridge? bridge;
  TdlibProbe? client;
  WindowsSession? session;
  MediaProbe? activeMedia;
  LocalMediaServer? mediaServer;
  File? mediaManifest;
  Timer? manifestTimer;
  StreamIterator<String>? lines;
  StreamSubscription<ProcessSignal>? signals;
  File? resultFile;
  Map<String, dynamic>? mediaFileState;
  final cancelled = Completer<bool>();
  var phase = 'API configuration';
  final mediaTrace = PlaybackTrace();
  final statusClock = Stopwatch()..start();
  var lastStatusMs = -1000;
  try {
    final credentials = TelegramCredentials.parse(
      await File(arguments[2]).readAsString(),
    );
    phase = 'local session protection';
    session = await WindowsSession.open(
      Directory.fromUri(
        Platform.script.resolve('../../.cache/native/accounts/dev-account/'),
      ),
      permissionsScript: File.fromUri(
        Platform.script.resolve('support/private_directory.ps1'),
      ),
    );
    resultFile = File.fromUri(
      session.directory.uri.resolve('probe-result.json'),
    );
    phase = 'relay configuration';
    bridge = await bridge_tool.startConfiguredBridge(arguments[1]);
    phase = 'native library';
    client = TdlibProbe(arguments[0]);
    final proxy = {
      '@type': 'proxy',
      'server': '127.0.0.1',
      'port': bridge.port,
      'type': {'@type': 'proxyTypeSocks5', 'username': '', 'password': ''},
    };
    // Queued in this order; TDLib applies network-none and the proxy before networking starts.
    phase = 'native initialization';
    final initialized = await client.initialize([
      {
        '@type': 'setNetworkType',
        'type': {'@type': 'networkTypeNone'},
      },
      {
        '@type': 'addProxy',
        'proxy': proxy,
        'enable': true,
        'comment': 'TG Cine local bridge',
      },
      {
        '@type': 'setTdlibParameters',
        'use_test_dc': false,
        'database_directory': session.directory.path,
        'files_directory': session.directory.uri.resolve('files/').toFilePath(),
        'database_encryption_key': base64Encode(session.key),
        'use_file_database': false,
        'use_chat_info_database': false,
        'use_message_database': false,
        'use_secret_chats': false,
        'api_id': credentials.apiId,
        'api_hash': credentials.apiHash,
        'system_language_code': 'zh',
        'device_model': 'TG Cine development probe',
        'system_version': Platform.operatingSystemVersion,
        'application_version': '0.1.0',
      },
    ]);
    if (initialized[0]['@type'] != 'ok' ||
        initialized[1]['@type'] != 'addedProxy' ||
        initialized[1]['is_enabled'] != true ||
        initialized[2]['@type'] != 'ok') {
      throw StateError('Native initialization failed');
    }
    final enabled = await client.request({'@type': 'getProxies'});
    final entries = enabled['proxies'] as List;
    if (!entries.any(
      (entry) =>
          entry['is_enabled'] == true &&
          entry['proxy']['server'] == '127.0.0.1' &&
          entry['proxy']['port'] == bridge!.port,
    )) {
      throw StateError('Local proxy not enabled');
    }
    phase = 'native proxy ping';
    final ping = await client.request({
      '@type': 'pingProxy',
      'proxy': proxy,
    }, timeout: const Duration(seconds: 25));
    if (ping['@type'] != 'seconds' || ping['seconds'] is! num) {
      throw StateError('Unexpected ping response');
    }
    stdout.writeln('TDLib initialization and enabled loopback relay verified.');
    stdout.writeln(
      'Encrypted local database; DPAPI key bound to this Windows user.',
    );
    await resultFile.writeAsString(
      jsonEncode({
        'checkedAt': DateTime.now().toUtc().toIso8601String(),
        'status': interactive || verifying
            ? 'awaiting-local-login'
            : 'preflight',
      }),
      flush: true,
    );
    if (!interactive && !verifying) {
      phase = 'pre-login state';
      final state = await client.request({'@type': 'getAuthorizationState'});
      if (state['@type'] != 'authorizationStateWaitPhoneNumber' &&
          state['@type'] != 'authorizationStateReady') {
        throw StateError('Unexpected pre-login state');
      }
      stdout.writeln(
        'Preflight passed. No phone number sent or login initiated.',
      );
      return;
    }
    phase = 'local interactive login';
    await client.request({
      '@type': 'setNetworkType',
      'type': {'@type': 'networkTypeOther'},
    });
    if (interactive) {
      lines = StreamIterator(
        stdin.transform(utf8.decoder).transform(const LineSplitter()),
      );
    }
    signals = ProcessSignal.sigint.watch().listen((_) {
      if (!cancelled.isCompleted) cancelled.complete(false);
    });
    while (true) {
      final state = await client.request({'@type': 'getAuthorizationState'});
      final type = state['@type'] as String;
      if (type == 'authorizationStateReady') {
        final me = await client.request({
          '@type': 'getMe',
        }, timeout: const Duration(seconds: 45));
        if (me['@type'] != 'user') {
          throw StateError('Authorized API request failed');
        }
        await resultFile.writeAsString(
          jsonEncode({
            'checkedAt': DateTime.now().toUtc().toIso8601String(),
            'status': 'ready',
            'getMeVerified': true,
          }),
          flush: true,
        );
        stdout.writeln('Telegram 登录成功；会话仅保存在本机，未读取或导入媒体。');
        if (verifying) {
          phase = 'selected media configuration';
          final selection = jsonDecode(
            await File.fromUri(
              session.directory.uri.resolve('media-selection.json'),
            ).readAsString(),
          ) as Map<String, dynamic>;
          final media = await MediaProbe.open(selection, (request) async {
            if (request['@type'] == 'cancelDownloadFile') {
              return client!.request(
                request,
                timeout: const Duration(seconds: 60),
              );
            }
            phase = 'media verification ${request['@type']}';
            final rpcClock = Stopwatch()..start();
            final response = await client!.request(
              request,
              timeout: const Duration(seconds: 60),
            );
            final rpcStage = switch (request['@type']) {
              'getFileDownloadedPrefixSize' => PlaybackStage.rpcPrefix,
              'readFilePart' => PlaybackStage.rpcRead,
              'downloadFile' => PlaybackStage.rpcDownload,
              _ => null,
            };
            if (rpcStage != null) {
              mediaTrace.record(
                rpcStage,
                durationUs: rpcClock.elapsedMicroseconds,
                offset: request['offset'] as int?,
                bytes: request['count'] as int? ?? 0,
              );
            }
            if (response['@type'] == 'file') {
              mediaFileState = {
                'size': response['size'],
                'downloadedBytes': response['local']['downloaded_size'],
                'downloadedPrefix': response['local']['downloaded_prefix_size'],
                'downloadOffset': response['local']['download_offset'],
                'isDownloading': response['local']['is_downloading_active'],
                'canBeDownloaded': response['local']['can_be_downloaded'],
              };
            }
            if (request['@type'] == 'downloadFile' &&
                response['@type'] == 'file') {
              stdout.writeln(
                jsonEncode({
                  'status': 'download-started',
                  'size': response['size'],
                  'offset': request['offset'],
                  'downloadedBytes': response['local']['downloaded_size'],
                  'readablePrefix': response['local']['downloaded_prefix_size'],
                  'isDownloading': response['local']['is_downloading_active'],
                }),
              );
            }
            if (statusClock.elapsedMilliseconds - lastStatusMs >= 1000) {
              lastStatusMs = statusClock.elapsedMilliseconds;
              await resultFile!.writeAsString(
                jsonEncode({
                  'checkedAt': DateTime.now().toUtc().toIso8601String(),
                  'status': 'verifying-media',
                  'phase': phase,
                  'responseType': response['@type'],
                  if (request['offset'] is int) 'offset': request['offset'],
                  if (response['@type'] == 'file') 'fileSize': response['size'],
                  if (response['@type'] == 'file')
                    'downloadedBytes': response['local']['downloaded_size'],
                  if (response['@type'] == 'file')
                    'downloadedPrefix':
                        response['local']['downloaded_prefix_size'],
                  if (response['@type'] == 'file')
                    'downloadOffset': response['local']['download_offset'],
                  'activeConnections': bridge!.activeConnections,
                  'capacityRejections': bridge.capacityRejections,
                  'traffic': bridge.traffic,
                  if (response['@type'] == 'fileDownloadedPrefixSize')
                    'readableBytes': response['size'],
                  'getMeVerified': true,
                }),
              );
            }
            return response;
          }, trace: mediaTrace);
          activeMedia = media;
          if (serving) {
            phase = 'Flutter media preparation';
            await media.preparePlayback();
            for (
              var offset = 0;
              offset < 8 * 1024 * 1024 && offset < media.size;
              offset += MediaProbe.chunkSize
            ) {
              final count = (media.size - offset).clamp(
                0,
                MediaProbe.chunkSize,
              );
              await media.read(offset, count);
            }
            mediaServer = await LocalMediaServer.start(
              size: media.size,
              mimeType: media.mimeType,
              read: media.read,
              readReady: media.readReady,
              cancelRead: media.cancelPendingRead,
              maxBytes: 128 * 1024 * 1024,
              maxRanges: 512,
              separateStreams: true,
              trace: mediaTrace,
            );
            mediaManifest = File.fromUri(
              session.directory.uri.resolve('flutter-media.json'),
            );
            await mediaManifest.writeAsString(
              jsonEncode({
                'uri': mediaServer.uri.toString(),
                'expiresAt': DateTime.now()
                    .toUtc()
                    .add(const Duration(minutes: 20))
                    .toIso8601String(),
              }),
              flush: true,
            );
            stdout.writeln(
              'Flutter 私有媒体源已就绪，有效期 20 分钟；本次限流 128 MiB / 512 次请求。',
            );
            // Removing the private bootstrap revokes this development session.
            manifestTimer = Timer.periodic(const Duration(seconds: 1), (
              _,
            ) async {
              if (!await mediaManifest!.exists() && !cancelled.isCompleted) {
                cancelled.complete(false);
              }
            });
            await cancelled.future.timeout(
              const Duration(minutes: 20),
              onTimeout: () => false,
            );
          }
          if (!playback && !serving) {
            final report = await media.verify();
            await File.fromUri(
              session.directory.uri.resolve('media-probe.json'),
            ).writeAsString(jsonEncode(report), flush: true);
            await resultFile.writeAsString(
              jsonEncode({
                'checkedAt': DateTime.now().toUtc().toIso8601String(),
                'status': 'media-ranges-verified',
                'getMeVerified': true,
              }),
              flush: true,
            );
            stdout.writeln(jsonEncode(report));
          }
          if (playback) {
            phase = 'local decoder verification';
            final Map<String, dynamic> decoded;
            try {
              decoded = playbackSession
                  ? await verifyPlaybackSession(media, session.directory)
                  : await verifyPlayback(media, session.directory);
            } catch (_) {
              phase = 'local decoder verification';
              rethrow;
            }
            await File.fromUri(
              session.directory.uri.resolve(
                playbackSession
                    ? 'playback-session-probe.json'
                    : 'playback-probe.json',
              ),
            ).writeAsString(jsonEncode(decoded), flush: true);
            await resultFile.writeAsString(
              jsonEncode({
                'checkedAt': DateTime.now().toUtc().toIso8601String(),
                'status': decoded['status'],
                'getMeVerified': true,
              }),
              flush: true,
            );
            stdout.writeln(jsonEncode(decoded));
          }
        }
        if (selecting) {
          phase = 'local media selection';
          await resultFile.writeAsString(
            jsonEncode({
              'checkedAt': DateTime.now().toUtc().toIso8601String(),
              'status': 'awaiting-media-selection',
              'getMeVerified': true,
            }),
            flush: true,
          );
          final selected = await selectMedia(
            request: (request) {
              phase = 'media query ${request['@type']}';
              return client!.request(
                request,
                timeout: const Duration(seconds: 45),
              );
            },
            readLine: () async {
              phase = 'local media choice input';
              await resultFile!.writeAsString(
                jsonEncode({
                  'checkedAt': DateTime.now().toUtc().toIso8601String(),
                  'status': 'awaiting-media-selection',
                  'phase': phase,
                  'getMeVerified': true,
                }),
                flush: true,
              );
              return await Future.any([lines!.moveNext(), cancelled.future])
                      .timeout(const Duration(minutes: 15))
                  ? lines!.current
                  : null;
            },
            writeLine: stdout.writeln,
          );
          if (selected != null) {
            await File.fromUri(
              session.directory.uri.resolve('media-selection.json'),
            ).writeAsString(
              jsonEncode({
                'selectedAt': DateTime.now().toUtc().toIso8601String(),
                ...selected,
              }),
              flush: true,
            );
            stdout.writeln('已保存本机验收视频选择，未下载视频。');
            await resultFile.writeAsString(
              jsonEncode({
                'checkedAt': DateTime.now().toUtc().toIso8601String(),
                'status': 'media-selected',
                'getMeVerified': true,
              }),
              flush: true,
            );
          } else {
            stdout.writeln('已取消选择。');
          }
        }
        break;
      }
      if (selecting || verifying) {
        stderr.writeln('会话尚未授权；请先运行本机登录入口。');
        exitCode = 1;
        break;
      }
      final prompt = switch (type) {
        'authorizationStateWaitPhoneNumber' => '输入国际格式手机号（含 + 国家码）：',
        'authorizationStateWaitCode' => '输入 Telegram 发送的验证码：',
        'authorizationStateWaitPassword' => '输入两步验证密码：',
        'authorizationStateWaitEmailAddress' => '输入登录邮箱：',
        'authorizationStateWaitEmailCode' => '输入邮箱验证码：',
        _ => null,
      };
      if (prompt == null) {
        stderr.writeln('当前登录方式需要官方客户端处理；本工具不会注册账号或发起购买。');
        exitCode = 1;
        break;
      }
      stdout.writeln(prompt);
      final hidden = hideLoginInput(type);
      stdout.writeln(
        hidden ? '为保护验证信息，输入的字符不会显示。输入完成后按回车提交。' : '输入的字符会正常显示。输入完成后按回车提交。',
      );
      final echo = stdin.echoMode;
      String input;
      try {
        phase = 'local authentication input';
        stdin.echoMode = !hidden;
        if (!await Future.any([lines!.moveNext(), cancelled.future])
            .timeout(const Duration(minutes: 5))) {
          break;
        }
        input = lines.current;
      } finally {
        stdin.echoMode = echo;
      }
      try {
        final request = loginRequest(type, input);
        phase = 'local authentication request';
        stdout.writeln('正在提交验证信息，等待 Telegram 响应（最多 45 秒）…');
        await client.request(request, timeout: const Duration(seconds: 45));
      } on FormatException {
        stderr.writeln('输入格式不正确，请重试。');
      } on TdlibRequestError catch (error) {
        if (error.code != 400) rethrow;
        stderr.writeln('Telegram 未接受此输入，请重试。');
      }
    }
  } catch (error) {
    stderr.writeln(
      'Local Telegram verification failed during $phase; sensitive details omitted.',
    );
    if (error is TdlibRequestError) {
      stderr.writeln('Native error code: ${error.code}');
    }
    if (error is TimeoutException) {
      stderr.writeln(
        phase == 'local decoder verification'
            ? '本机播放验收超时；媒体范围与解码结果分别记录。'
            : phase.endsWith(' input')
            ? '等待本机输入超时；请重新运行后完成选择或登录。'
            : '等待 Telegram 响应超时；请检查连接后重新运行。',
      );
    }
    final failure = <String, dynamic>{
      'checkedAt': DateTime.now().toUtc().toIso8601String(),
      'status': 'failed',
      'phase': phase,
      if (error is TdlibRequestError) 'nativeErrorCode': error.code,
      if (error is TimeoutException) 'timedOut': true,
      if (client != null) 'recentResponseTypes': client.recentResponses,
      if (bridge != null) 'activeConnections': bridge.activeConnections,
      if (bridge != null) 'capacityRejections': bridge.capacityRejections,
      if (bridge != null) 'traffic': bridge.traffic,
      'mediaFileState': ?mediaFileState,
    };
    final rejected = bridge?.lastRejectedTarget;
    if (rejected != null &&
        !phase.endsWith(' input') &&
        InternetAddress.tryParse(rejected.$1) != null) {
      failure['missingTarget'] = '${rejected.$1}:${rejected.$2}';
      stderr.writeln(
        'Missing fixed Telegram target mapping: ${rejected.$1}:${rejected.$2}',
      );
    }
    try {
      await resultFile?.writeAsString(jsonEncode(failure), flush: true);
    } catch (_) {
      stderr.writeln(
        'Unable to save verification status; sensitive details omitted.',
      );
    }
    exitCode = 1;
  } finally {
    manifestTimer?.cancel();
    await signals?.cancel();
    await lines?.cancel();
    try {
      await mediaServer?.close();
      if (mediaServer != null && session != null) {
        await File.fromUri(
          session.directory.uri.resolve('flutter-media-result.json'),
        ).writeAsString(
          jsonEncode({
            'bytesServed': mediaServer.bytesServed,
            'rangeCount': mediaServer.ranges.length,
            'ranges': mediaServer.ranges,
            'failedRequests': mediaServer.failedRequests,
            'queuedRequests': mediaServer.queuedRequests,
            'rejectedRequests': mediaServer.rejectedRequests,
            'trace': mediaTrace.snapshot(),
            'bridgeTraffic': bridge?.traffic,
            'relayTraceIds': bridge?.traceIds,
            'budgetExhausted':
                mediaServer.bytesServed >= mediaServer.maxBytes ||
                mediaServer.ranges.length >= mediaServer.maxRanges,
          }),
          flush: true,
        );
      }
      if (mediaManifest != null && await mediaManifest.exists()) {
        await mediaManifest.delete();
      }
    } catch (_) {
      stderr.writeln(
        'Private media source cleanup failed; sensitive details omitted.',
      );
      exitCode = 1;
    }
    try {
      await activeMedia?.close();
    } catch (_) {
      stderr.writeln('Media cleanup failed; sensitive details omitted.');
      exitCode = 1;
    }
    try {
      await client?.close();
    } catch (_) {
      stderr.writeln('Native close failed; sensitive details omitted.');
      exitCode = 1;
    }
    await bridge?.close();
    await session?.close();
  }
}
