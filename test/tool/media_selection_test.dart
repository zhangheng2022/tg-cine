import 'package:flutter_test/flutter_test.dart';

import '../../tool/support/media_selection.dart';
import '../../tool/support/tdlib_probe.dart';

Map<String, dynamic> video(int id) => {
  'id': id,
  'content': {
    '@type': 'messageVideo',
    'is_secret': false,
    'video': {
      'file_name': '\x1b[2Jtest.mp4\n',
      'video': {'id': 7, 'size': 1024},
    },
  },
};

void main() {
  for (final type in [
    {'@type': 'chatTypeSupergroup', 'is_channel': true},
    {'@type': 'chatTypeSupergroup', 'is_channel': false},
    {'@type': 'chatTypeBasicGroup'},
    {'@type': 'chatTypePrivate'},
    {'@type': 'chatTypeSecret'},
  ]) {
    test(
      'selects $type across main and archive; only searches the selected chat',
      () async {
        final inputs = ['0', '3', '1'].iterator;
        final output = <String>[];
        final requests = <Map<String, dynamic>>[];
        final selected = await selectMedia(
          request: (request) async {
            requests.add(request);
            switch (request['@type']) {
              case 'loadChats':
                throw const TdlibRequestError(404);
              case 'getChats':
                return {
                  'chat_ids': request['chat_list']['@type'] == 'chatListMain'
                      ? [1, 2]
                      : [1, 3],
                };
              case 'getChat':
                final id = request['chat_id'] as int;
                return {
                  'id': id,
                  'title': 'Chat $id',
                  'type': id == 3
                      ? type
                      : {'@type': 'chatTypeSupergroup', 'is_channel': id != 2},
                };
              case 'searchChatMessages':
                expect(request['chat_id'], 3);
                return {
                  'messages':
                      request['filter']['@type'] == 'searchMessagesFilterVideo'
                      ? [video(20)]
                      : [],
                  'next_from_message_id': 0,
                };
              default:
                fail('Unexpected request');
            }
          },
          readLine: () async => inputs.moveNext() ? inputs.current : null,
          writeLine: output.add,
        );
        expect(selected, {'chatId': 3, 'messageId': 20});
        expect(
          requests.where((request) => request['@type'] == 'getChat'),
          hasLength(3),
        );
        expect(output.join(), isNot(contains('\x1b')));
        expect(output, containsAll(['1. Chat 1', '2. Chat 2', '3. Chat 3']));
        expect(output, contains('请输入列表中的序号。'));
      },
    );
  }

  test('video pagination uses each returned cursor and cancellation selects nothing', () async {
    final inputs = ['1', 'm', 'q'].iterator;
    final offsets = <int>[];
    final selected = await selectMedia(
      request: (request) async {
        switch (request['@type']) {
          case 'loadChats':
            return {'@type': 'ok'};
          case 'getChats':
            return {
              'chat_ids': [1],
            };
          case 'getChat':
            return {
              'id': 1,
              'title': 'Channel',
              'type': {'@type': 'chatTypeSupergroup', 'is_channel': true},
            };
          case 'searchChatMessages':
            final offset = request['from_message_id'] as int;
            offsets.add(offset);
            return {
              'messages': [video(offset == 0 ? 20 : 10)],
              'next_from_message_id': offset == 0 ? 10 : 0,
            };
          default:
            fail('Unexpected request');
        }
      },
      readLine: () async => inputs.moveNext() ? inputs.current : null,
      writeLine: (_) {},
    );
    expect(selected, isNull);
    expect(offsets, [0, 0, 10, 10]);
  });

  test('filters video documents and ephemeral videos; console labels have no controls', () {
    expect(videoFile(video(1)), {'id': 7, 'size': 1024});
    final ephemeral = video(1);
    ephemeral['content']['is_secret'] = true;
    expect(videoFile(ephemeral), isNull);
    final document = {
      'content': {
        '@type': 'messageDocument',
        'document': {
          'file_name': 'test.MKV',
          'mime_type': 'application/octet-stream',
          'document': {'id': 8},
        },
      },
    };
    expect(videoFile(document), {'id': 8});
    (document['content']!['document'] as Map)['file_name'] = 'test.pdf';
    expect(videoFile(document), isNull);
    expect(consoleLabel('title\n\x1b\u202eend'), 'title   end');
    expect(consoleLabel('🎞' * 100).runes.length, 81);
  });
}
