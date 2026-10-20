/// A validated Nextcloud installation URL, including its subdirectory.
final class ServerBase {
  ServerBase._(this.uri);

  factory ServerBase.parse(String input, {bool allowInsecureHttp = false}) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' &&
            !(allowInsecureHttp && uri.scheme == 'http')) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Invalid Nextcloud base URL');
    }
    final segments = uri.pathSegments.toList();
    if (segments.isNotEmpty && segments.last.isEmpty) segments.removeLast();
    if (segments.any(
      (s) =>
          s.isEmpty ||
          s == '.' ||
          s == '..' ||
          s.contains('/') ||
          s.contains('\\') ||
          s.runes.any((c) => c < 32 || c == 127),
    )) {
      throw const FormatException('Invalid Nextcloud base path');
    }
    return ServerBase._(uri.replace(pathSegments: [...segments, '']));
  }

  final Uri uri;

  Uri _under(
    List<String> prefix,
    List<String> segments,
    Map<String, String>? q,
  ) => uri.replace(
    pathSegments: [
      ...uri.pathSegments.where((s) => s.isNotEmpty),
      ...prefix,
      ...segments,
    ],
    queryParameters: q == null || q.isEmpty ? null : q,
  );

  /// `/ocs/v2.php/apps/files_sharing/api/v1/<shares|sharees>/...`
  Uri ocsSharing(List<String> segments, [Map<String, String>? query]) => _under(
    ['ocs', 'v2.php', 'apps', 'files_sharing', 'api', 'v1'],
    segments,
    query,
  );

  /// `/remote.php/dav/files/<user>/...`
  Uri davFile(String user, List<String> segments) =>
      _under(['remote.php', 'dav', 'files', user], segments, null);

  Uri notesEndpoint(List<String> segments, [Map<String, String>? query]) =>
      uri.replace(
        pathSegments: [
          ...uri.pathSegments.where((s) => s.isNotEmpty),
          'index.php',
          'apps',
          'notes',
          'api',
          'v1',
          ...segments,
        ],
        queryParameters: query == null || query.isEmpty ? null : query,
      );
}
