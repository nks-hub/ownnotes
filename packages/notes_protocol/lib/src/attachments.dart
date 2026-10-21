import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'client.dart';
import 'models.dart';
import 'server_base.dart';

/// Which `attachment/{id}` route a Notes server serves.
///
/// Notes 6.0.x answers only under `api/v1.4`; 6.1 adds the `api/v1` alias and
/// the DELETE verb. An unknown version gets the route every release has and
/// no delete.
final class AttachmentRoute {
  const AttachmentRoute._(this.apiVersion, this.canDelete);

  static const legacy = AttachmentRoute._('v1.4', false);
  static const current = AttachmentRoute._('v1', true);

  final String apiVersion;
  final bool canDelete;

  /// [version] is the Notes app version from the server capabilities
  /// (`6.1.0`).
  factory AttachmentRoute.forNotesVersion(String? version) {
    final parts = RegExp(r'^(\d+)\.(\d+)').firstMatch(version ?? '');
    if (parts == null) return legacy;
    final major = int.parse(parts[1]!);
    final minor = int.parse(parts[2]!);
    return major > 6 || (major == 6 && minor >= 1) ? current : legacy;
  }
}

/// A file the server stored in a note's attachment folder.
final class UploadedAttachment {
  const UploadedAttachment(this.path);

  /// Relative path as the Markdown writes it, `.attachments.<id>/name.png`.
  final String path;
}

/// A downloaded attachment of any type.
final class AttachmentFile {
  const AttachmentFile(this.bytes, this.contentType);
  final List<int> bytes;
  final String contentType;
}

/// Uploads, downloads and deletes the files of a note, the way the Notes web
/// app does. One instance belongs to one account; there are no retries.
final class AttachmentsClient {
  AttachmentsClient({
    required this.base,
    required this.transport,
    required String loginName,
    required String appPassword,
    this.route = AttachmentRoute.legacy,
    this.timeout = const Duration(minutes: 5),
    this.maxDownloadBytes = 26214400,
  }) : _authorization =
           'Basic ${base64Encode(utf8.encode('$loginName:$appPassword'))}' {
    if (loginName.isEmpty ||
        loginName.contains(':') ||
        appPassword.isEmpty ||
        timeout <= Duration.zero ||
        maxDownloadBytes <= 0) {
      throw ArgumentError('Invalid client configuration');
    }
  }

  final ServerBase base;
  final http.Client transport;
  final String _authorization;
  final AttachmentRoute route;
  final Duration timeout;
  final int maxDownloadBytes;

  /// The Notes app version advertised in the capabilities, or null when the
  /// server does not say.
  Future<String?> notesVersion() async => (await versions()).notes;

  /// Nextcloud and Notes app versions from the capabilities; each is null
  /// when the server does not say.
  Future<({String? nextcloud, String? notes})> versions() async {
    final response = await _send(
      http.Request(
        'GET',
        base.uri.replace(
          pathSegments: [
            ...base.uri.pathSegments.where((s) => s.isNotEmpty),
            'ocs',
            'v2.php',
            'cloud',
            'capabilities',
          ],
          queryParameters: {'format': 'json'},
        ),
      )..headers['OCS-APIRequest'] = 'true',
      maxBytes: 1048576,
      mutation: false,
    );
    if (response.statusCode != 200) {
      throw NotesHttpException(response.statusCode, mayHaveApplied: false);
    }
    Object? data;
    try {
      data = (jsonDecode(utf8.decode(response.bodyBytes)) as Map)['ocs'];
      data = (data as Map)['data'];
    } on Object {
      data = null;
    }
    String? text(Object? map, String group, String key) {
      final inner = map is Map ? map[group] : null;
      final value = inner is Map ? inner[key] : null;
      return value is String ? value : null;
    }

    final capabilities = data is Map ? data['capabilities'] : null;
    return (
      nextcloud: text(data, 'version', 'string'),
      notes: text(capabilities, 'notes', 'version'),
    );
  }

  /// Stores [content] in the attachment folder of note [noteId] and returns
  /// the path the server chose (it renames on a name clash).
  ///
  /// A failure after the request left the device may still have stored the
  /// file ([MutationUncertain]); a retry can then leave a second copy.
  Future<UploadedAttachment> upload(
    int noteId, {
    required String fileName,
    required Stream<List<int>> content,
    required int length,
  }) async {
    _noteId(noteId);
    if (fileName.isEmpty ||
        fileName.contains('/') ||
        fileName.contains('\\') ||
        fileName == '.' ||
        fileName == '..' ||
        length < 0) {
      throw const NotesProtocolException('invalid_attachment_name');
    }
    final request = http.MultipartRequest('POST', _uri(noteId, null))
      ..files.add(
        http.MultipartFile('file', content, length, filename: fileName),
      );
    final response = await _send(request, maxBytes: 65536, mutation: true);
    if (response.statusCode != 200) {
      throw NotesHttpException(response.statusCode, mayHaveApplied: true);
    }
    final path = _filename(response, noteId);
    if (path == null) throw const MutationUncertain();
    return UploadedAttachment(path);
  }

  /// Removes one file from the note's attachment folder. Needs Notes 6.1.
  Future<void> delete(int noteId, String path) async {
    _noteId(noteId);
    if (!route.canDelete) {
      throw const NotesProtocolException('attachment_delete_unsupported');
    }
    final response = await _send(
      http.Request('DELETE', _uri(noteId, _checked(path))),
      maxBytes: 65536,
      mutation: true,
    );
    if (response.statusCode != 200) {
      throw NotesHttpException(response.statusCode, mayHaveApplied: true);
    }
  }

  /// A file of any type, by the relative path the Markdown uses.
  Future<AttachmentFile> download(int noteId, String path) async {
    _noteId(noteId);
    final response = await _send(
      http.Request('GET', _uri(noteId, _checked(path)))
        ..headers['Accept'] = '*/*',
      maxBytes: maxDownloadBytes,
      mutation: false,
    );
    if (response.statusCode != 200) {
      throw NotesHttpException(response.statusCode, mayHaveApplied: false);
    }
    return AttachmentFile(
      response.bodyBytes,
      response.headers['content-type']?.split(';').first.trim() ??
          'application/octet-stream',
    );
  }

  Uri _uri(int noteId, String? path) => base.uri.replace(
    pathSegments: [
      ...base.uri.pathSegments.where((s) => s.isNotEmpty),
      'index.php',
      'apps',
      'notes',
      'api',
      route.apiVersion,
      'attachment',
      '$noteId',
    ],
    queryParameters: path == null ? null : {'path': path},
  );

  static void _noteId(int id) {
    if (id <= 0) throw ArgumentError('Invalid note id');
  }

  static String _checked(String path) {
    final segments = path.split('/');
    if (path.isEmpty ||
        path.startsWith('/') ||
        Uri.tryParse(path)?.hasScheme != false ||
        segments.any((s) => s.isEmpty || s == '.' || s == '..')) {
      throw const NotesProtocolException('invalid_attachment_path');
    }
    return path;
  }

  static String? _filename(http.Response response, int noteId) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final name = body is Map ? body['filename'] : null;
      if (name is String &&
          name.startsWith('.attachments.$noteId/') &&
          !name.split('/').any((s) => s.isEmpty || s == '.' || s == '..') &&
          name.split('/').length == 2) {
        return name;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  Future<http.Response> _send(
    http.BaseRequest request, {
    required int maxBytes,
    required bool mutation,
  }) async {
    request
      ..followRedirects = false
      ..headers['Authorization'] = _authorization;
    request.headers.putIfAbsent('Accept', () => 'application/json');
    try {
      return await (() async {
        final response = await transport.send(request);
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > maxBytes) {
            throw const NotesProtocolException('response_too_large');
          }
          bytes.addAll(chunk);
        }
        return http.Response.bytes(
          bytes,
          response.statusCode,
          headers: response.headers,
        );
      })().timeout(timeout);
    } on NotesProtocolException {
      if (mutation) throw const MutationUncertain();
      rethrow;
    } catch (_) {
      if (mutation) throw const MutationUncertain();
      throw const NotesTransportException();
    }
  }
}
