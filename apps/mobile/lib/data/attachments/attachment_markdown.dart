/// File names and Markdown references the way the Notes web app writes them.
library;

const _mimeByExtension = {
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'bmp': 'image/bmp',
  'svg': 'image/svg+xml',
  'm4a': 'audio/mp4',
  'mp3': 'audio/mpeg',
  'aac': 'audio/aac',
  'wav': 'audio/wav',
  'ogg': 'audio/ogg',
  '3gp': 'audio/3gpp',
  'amr': 'audio/amr',
  'mp4': 'video/mp4',
  'pdf': 'application/pdf',
  'txt': 'text/plain',
  'md': 'text/markdown',
  'zip': 'application/zip',
};

/// Content type guessed from the file name; unknown names are binary.
String mimeForName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return 'application/octet-stream';
  return _mimeByExtension[name.substring(dot + 1).toLowerCase()] ??
      'application/octet-stream';
}

/// A file name the Notes server accepts: no separators or reserved
/// characters, never empty, at most 120 characters with the extension kept.
String safeAttachmentName(String name, {String fallback = 'attachment'}) {
  var clean = name
      .split(RegExp(r'[\\/]'))
      .last
      .replaceAll(RegExp(r'[\x00-\x1f\x7f:*?"<>|]'), '_')
      .trim();
  while (clean.startsWith('.')) {
    clean = clean.substring(1);
  }
  if (clean.isEmpty) return fallback;
  if (clean.length <= 120) return clean;
  final dot = clean.lastIndexOf('.');
  final ext = dot > 0 && clean.length - dot <= 12 ? clean.substring(dot) : '';
  return clean.substring(0, 120 - ext.length) + ext;
}

String _encodeSegment(String s) =>
    Uri.encodeComponent(s).replaceAll('(', '%28').replaceAll(')', '%29');

/// Markdown for a file stored at [path] (`.attachments.<id>/name.png`): an
/// image for pictures, a plain link for everything else.
String attachmentMarkdown(String path, {required bool image}) {
  final slash = path.indexOf('/');
  final folder = path.substring(0, slash);
  final name = path.substring(slash + 1);
  final label = name.replaceAll(RegExp(r'[\[\]]'), '');
  return '${image ? '!' : ''}[$label]($folder/${_encodeSegment(name)})';
}
