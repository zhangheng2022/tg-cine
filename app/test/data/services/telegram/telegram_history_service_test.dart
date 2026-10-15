import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/data/services/telegram/telegram_history_service.dart';

Map<String, dynamic> historyVideo(
  int id, {
  int source = -1,
  bool document = false,
  String unique = 'file',
  String mime = 'video/mp4',
}) => {
  '@type': 'message',
  'id': id,
  'chat_id': source,
  'date': id,
  'content': {
    '@type': document ? 'messageDocument' : 'messageVideo',
    'caption': {'text': 'original-caption'},
    document ? 'document' : 'video': {
      'file_name': document ? 'video.mkv' : 'video.mp4',
      'mime_type': mime,
      if (!document) 'duration': 10,
      document ? 'document' : 'video': {
        'id': 99,
        'size': 1024,
        'remote': {'unique_id': unique},
      },
    },
  },
};

void main() {
  test('short page retains server cursor and imports video documents without downloading', () async {
    final requests = <Map<String, dynamic>>[];
    final service = TelegramHistoryService((request) async {
      requests.add(request);
      return {
        '@type': 'foundChatMessages',
        'messages': [historyVideo(20), historyVideo(10, document: true)],
        'next_from_message_id': 9,
      };
    });
    final page = await service.page(-1, 0);
    expect(page.nextMessageId, 9);
    expect(page.media, hasLength(2));
    expect(page.media.first.caption, 'original-caption');
    expect(page.media.last.durationSeconds, 0);
    expect(requests.single['@type'], 'searchChatMessages');
    expect(requests.single['filter'], isNull);
    expect(requests.single['from_message_id'], 0);
  });
  test('non-media and ephemeral messages are skipped but an empty media page still advances', () async {
    final ephemeral = historyVideo(20);
    (ephemeral['content'] as Map)['is_secret'] = true;
    final file = historyVideo(10, document: true, mime: 'application/pdf');
    ((file['content'] as Map)['document'] as Map)['file_name'] = 'file.pdf';
    final page = await TelegramHistoryService(
      (_) async => {
        '@type': 'foundChatMessages',
        'messages': [
          ephemeral,
          file,
          {
            'id': 5,
            'chat_id': -1,
            'content': {'@type': 'messageText'},
          },
        ],
        'next_from_message_id': 4,
      },
    ).page(-1, 9);
    expect(page.media, isEmpty);
    expect(page.nextMessageId, 4);
  });
  test('foreign sources, incomplete video identities, oversized and stagnant pages fail safely', () async {
    for (final response in [
      {
        '@type': 'foundChatMessages',
        'messages': [historyVideo(10, source: -2)],
        'next_from_message_id': 0,
      },
      {
        '@type': 'foundChatMessages',
        'messages': [historyVideo(10, unique: '')],
        'next_from_message_id': 0,
      },
      {'@type': 'foundChatMessages', 'messages': [], 'next_from_message_id': 8},
      {
        '@type': 'foundChatMessages',
        'messages': List.filled(51, historyVideo(10)),
        'next_from_message_id': 0,
      },
      {'@type': 'error', 'code': 403, 'message': 'private-error-details'},
    ]) {
      await expectLater(
        TelegramHistoryService((_) async => response).page(-1, 8),
        throwsFormatException,
      );
    }
  });
}
