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
