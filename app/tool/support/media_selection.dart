import 'tdlib_probe.dart';

/// Development selection only; titles stay in the user's local console.
Future<Map<String, int>?> selectMedia({
  required Future<Map<String, dynamic>> Function(Map<String, dynamic>) request,
  required Future<String?> Function() readLine,
  required void Function(String) writeLine,
}) async {
  final chats = <int, Map<String, dynamic>>{};
  final exhausted = <String>{};
  var limit = 0;
  Map<String, dynamic>? selectedChat;
  while (selectedChat == null) {
    writeLine('正在加载聊天列表，请稍候…');
    limit += 100;
    for (final list in ['chatListMain', 'chatListArchive']) {
      if (!exhausted.contains(list)) {
        try {
          await request({
            '@type': 'loadChats',
            'chat_list': {'@type': list},
            'limit': 100,
          });
        } on TdlibRequestError catch (error) {
          if (error.code != 404) rethrow;
          exhausted.add(list);
        }
      }
      final response = await request({
        '@type': 'getChats',
        'chat_list': {'@type': list},
        'limit': limit,
      });
      for (final id in (response['chat_ids'] as List).cast<int>()) {
        if (!chats.containsKey(id)) {
          chats[id] = await request({'@type': 'getChat', 'chat_id': id});
        }
      }
    }
    final choices = chats.values.toList();
    writeLine('可选择的聊天（主列表与归档，不按类型过滤；仅在本机显示）：');
    for (var index = 0; index < choices.length; index++) {
      writeLine(
        '${index + 1}. ${consoleLabel(choices[index]['title'] as String)}',
      );
    }
    if (choices.isEmpty) writeLine('当前批次没有聊天。');
    while (selectedChat == null) {
      writeLine('输入聊天序号；m 加载更多聊天；q 取消：');
      final input = (await readLine())?.trim().toLowerCase();
      if (input == null || input == 'q') return null;
      if (input == 'm') {
        if (exhausted.length == 2) {
          writeLine('全部聊天已加载。');
          continue;
        }
        break;
      }
      final index = int.tryParse(input);
      if (index == null || index < 1 || index > choices.length) {
        writeLine('请输入列表中的序号。');
        continue;
      }
      selectedChat = choices[index - 1];
    }
  }

  final cursors = {
    'searchMessagesFilterVideo': 0,
    'searchMessagesFilterDocument': 0,
  };
  final finished = <String>{};
  while (true) {
    writeLine('正在查询所选聊天的视频，请稍候…');
    final messages = <int, Map<String, dynamic>>{};
    for (final filter in cursors.keys) {
      if (finished.contains(filter)) continue;
      final response = await request({
        '@type': 'searchChatMessages',
        'chat_id': selectedChat['id'],
        'topic_id': null,
        'query': '',
        'sender_id': null,
        'from_message_id': cursors[filter],
        'offset': 0,
        'limit': 20,
        'filter': {'@type': filter},
      });
      for (final message
          in (response['messages'] as List).cast<Map<String, dynamic>>()) {
        if (videoFile(message) != null) {
          messages[message['id'] as int] = message;
        }
      }
      final next = response['next_from_message_id'] as int;
      if (next == 0 || next == cursors[filter]) finished.add(filter);
      cursors[filter] = next;
    }
    final videos = messages.values.toList()
      ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    writeLine('该聊天的视频（包含以文件发送的视频）：');
    for (var index = 0; index < videos.length; index++) {
      final content = videos[index]['content'] as Map<String, dynamic>;
      final media = (content['video'] ?? content['document']) as Map;
      final caption = (content['caption'] as Map?)?['text'] as String?;
      final name = media['file_name'] as String?;
      final label = name?.isNotEmpty == true ? name! : caption ?? '视频消息';
      writeLine('${index + 1}. ${consoleLabel(label)}');
    }
    if (videos.isEmpty) writeLine('当前批次没有可选择的视频。');
    while (true) {
      writeLine('输入视频序号；m 更早的视频；q 取消：');
      final input = (await readLine())?.trim().toLowerCase();
      if (input == null || input == 'q') return null;
      if (input == 'm') {
        if (finished.length == cursors.length) {
          writeLine('该聊天的视频已查询完毕。');
          continue;
        }
        break;
      }
      final index = int.tryParse(input);
      if (index == null || index < 1 || index > videos.length) {
        writeLine('请输入列表中的序号。');
        continue;
      }
      final message = videos[index - 1];
      return {
        'chatId': selectedChat['id'] as int,
        'messageId': message['id'] as int,
      };
    }
  }
}

Map<String, dynamic>? videoFile(Map<String, dynamic> message) {
  final content = message['content'] as Map<String, dynamic>;
  if (content['@type'] == 'messageVideo' && content['is_secret'] != true) {
    return content['video']['video'] as Map<String, dynamic>;
  }
  if (content['@type'] == 'messageDocument') {
    final document = content['document'] as Map<String, dynamic>;
    final mime = document['mime_type'] as String;
    final name = (document['file_name'] as String).toLowerCase();
    if (mime.startsWith('video/') ||
        RegExp(r'\.(mp4|mkv|mov|webm|avi|m4v|ts)$').hasMatch(name)) {
      return document['document'] as Map<String, dynamic>;
    }
  }
  return null;
}

String consoleLabel(String value) {
  final clean = value
      .replaceAll(
        RegExp(r'[\x00-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069]'),
        ' ',
      )
      .trim();
  return clean.runes.length <= 80
      ? clean
      : '${String.fromCharCodes(clean.runes.take(80))}…';
}
