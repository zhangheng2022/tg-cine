import '../../../domain/models/local_media.dart';
import 'telegram_video_file.dart';

class TelegramHistoryService {
  TelegramHistoryService(this._request);
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) _request;

  Future<TelegramMediaPage> page(int sourceId, int cursor) async {
    final response = await _request({
      '@type': 'searchChatMessages',
      'chat_id': sourceId,
      'topic_id': null,
      'query': '',
      'sender_id': null,
      'from_message_id': cursor,
      'offset': 0,
      'limit': 50,
      'filter': null,
    });
    if (response['@type'] != 'foundChatMessages' ||
        response['messages'] is! List ||
        response['next_from_message_id'] is! int) {
      throw const FormatException('Invalid history page');
    }
    final next = response['next_from_message_id'] as int;
    final messages = response['messages'] as List;
    if (next < 0 || (next != 0 && next == cursor) || messages.length > 50) {
      throw const FormatException('Non-progressing history page');
    }
    final media = <LocalMedia>[];
    for (final raw in messages) {
      if (raw is! Map ||
          raw['chat_id'] != sourceId ||
          raw['id'] is! int ||
          (raw['id'] as int) <= 0 ||
          raw['content'] is! Map) {
        throw const FormatException('Invalid source message');
      }
      final content = raw['content'] as Map;
      if (content['is_secret'] == true || raw['self_destruct_type'] != null) {
        continue;
      }
      final Map description;
      final Map file;
      if (content['@type'] == 'messageVideo' && content['video'] is Map) {
        description = content['video'] as Map;
        file = description['video'] as Map;
      } else if (content['@type'] == 'messageDocument' &&
          content['document'] is Map) {
        description = content['document'] as Map;
        if (videoFile(raw.cast<String, dynamic>()) == null) {
          continue;
        }
        file = description['document'] as Map;
      } else {
        continue;
      }
      final remote = file['remote'];
      if (remote is! Map ||
          remote['unique_id'] is! String ||
          (remote['unique_id'] as String).isEmpty ||
          file['size'] is! int ||
          (file['size'] as int) <= 0 ||
          raw['date'] is! int ||
          description['file_name'] is! String) {
        // Never advance past a video whose persistent identity is not available yet.
        throw const FormatException('Incomplete media metadata');
      }
      media.add(
        LocalMedia(
          sourceId: sourceId,
          messageId: raw['id'] as int,
          remoteUniqueId: remote['unique_id'] as String,
          sizeBytes: file['size'] as int,
          fileName: description['file_name'] as String,
          durationSeconds: (description['duration'] as int?) ?? 0,
          caption: (content['caption'] as Map?)?['text'] as String? ?? '',
          sentAt: raw['date'] as int,
        ),
      );
    }
    return TelegramMediaPage(media: media, nextMessageId: next);
  }
}
