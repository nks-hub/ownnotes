import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate, HttpException;

import 'package:http/http.dart' as http;

import 'models.dart';
import 'server_base.dart';

final class NotesHttpException implements Exception {
  const NotesHttpException(this.statusCode, {required this.mayHaveApplied});
  final int statusCode;
  final bool mayHaveApplied;
  @override
  String toString() =>
      'NotesHttpException($statusCode, mayHaveApplied: $mayHaveApplied)';
}

final class MutationUncertain implements Exception {
  const MutationUncertain();
  @override
  String toString() => 'MutationUncertain';
}

final class NotesTransportException implements Exception {
  const NotesTransportException();
  @override
  String toString() => 'NotesTransportException';
}

final class NoteConflict implements Exception {
  const NoteConflict(this.remote);
  final NoteRecord remote;
  @override
  String toString() => 'NoteConflict';
}

/// One instance belongs to one account. Callers own lifecycle and persistence.
/// There are no automatic retries, redirects or logging of response bodies.
final class NotesClient {
  NotesClient({
    required this.base,
    required this.transport,
    required String loginName,
    required String appPassword,
    this.timeout = const Duration(seconds: 30),
    this.maxResponseBytes = 8388608,
  }) : _authorization =
           'Basic ${base64Encode(utf8.encode('$loginName:$appPassword'))}' {
    if (loginName.isEmpty ||
        loginName.contains(':') ||
        appPassword.isEmpty ||
        timeout <= Duration.zero ||
        maxResponseBytes <= 0) {
      throw ArgumentError('Invalid client configuration');
    }
  }

  final ServerBase base;
  final http.Client transport;
  final String _authorization;
  final Duration timeout;
  final int maxResponseBytes;

  Future<NotesPage> list({
    int? pruneBefore,
    int chunkSize = 100,
    String? cursor,
  }) async {
    if (chunkSize <= 0 ||
        (pruneBefore != null && pruneBefore < 0) ||
        (cursor != null && cursor.isEmpty)) {
      throw ArgumentError('Invalid list parameters');
    }
    final response = await _request(
      'GET',
      ['notes'],
      query: {
        'chunkSize': '$chunkSize',
        if (pruneBefore != null) 'pruneBefore': '$pruneBefore',
        'chunkCursor': ?cursor,
      },
    );
    _expectOk(response, mutation: false);
    final body = _json(response);
    if (body is! List<Object?>) {
      throw const NotesProtocolException('invalid_notes_list');
    }
    final notes = body.map(parseNote).toList();
    if (notes.map((n) => n.id).toSet().length != notes.length) {
      throw const NotesProtocolException('duplicate_note_id');
    }
    final next = response.headers['x-notes-chunk-cursor'];
    if (next != null && next.isEmpty) {
      throw const NotesProtocolException('empty_chunk_cursor');
    }
    DateTime? modified;
    final rawDate = response.headers['last-modified'];
    if (rawDate != null) {
      try {
        modified = HttpDate.parse(rawDate).toUtc();
      } on HttpException {
        /* Missing watermark remains explicit. */
      }
    }
    return NotesPage(
      notes: notes,
      cursor: next,
      lastModified: modified,
      etag: response.headers['etag'],
    );
  }

  /// A 304 requires the caller's matching account-scoped cached representation.
  Future<NoteReadResult> get(int id, {String? ifNoneMatch}) async {
    noteId(id);
    final response = await _request(
      'GET',
      ['notes', '$id'],
      headers: {
        if (ifNoneMatch != null) 'If-None-Match': quoteEtag(ifNoneMatch),
      },
    );
    if (response.statusCode == 304) {
      if (ifNoneMatch == null) {
        throw const NotesProtocolException('unsolicited_304');
      }
      return const NoteNotModified();
    }
    _expectOk(response, mutation: false);
    return _detail(response, expectedId: id);
  }

  Future<NoteRecord> create({
    required String content,
    required String title,
    String category = '',
    bool favorite = false,
  }) async {
    final response = await _request(
      'POST',
      ['notes'],
      body: {
        'content': content,
        'title': title,
        'category': category,
        'favorite': favorite,
      },
    );
    _expectOk(response, mutation: true);
    try {
      return _detail(response);
    } on NotesProtocolException {
      throw const MutationUncertain();
    }
  }

  Future<NoteRecord> update(
    int id, {
    required String etag,
    required NotePatch patch,
  }) async {
    noteId(id);
    final response = await _request(
      'PUT',
      ['notes', '$id'],
      headers: {'If-Match': quoteEtag(etag)},
      body: patch.fields,
    );
    if (response.statusCode == 412) {
      throw NoteConflict(_detail(response, expectedId: id));
    }
    _expectOk(response, mutation: true);
    try {
      return _detail(response, expectedId: id);
    } on NotesProtocolException {
      throw const MutationUncertain();
    }
  }

  /// This endpoint has no server-side If-Match protection.
  Future<void> delete(int id) async {
    noteId(id);
    final response = await _request('DELETE', ['notes', '$id']);
    _expectOk(response, mutation: true);
    try {
      final body = _json(response);
      if (body is! List<Object?> || body.isNotEmpty) {
        throw const NotesProtocolException('invalid_delete_receipt');
      }
    } on NotesProtocolException {
      throw const MutationUncertain();
    }
  }

  /// The account's Notes folder and file suffix as `notesPath|fileSuffix`;
  /// a change means the server lists a different set of files.
  Future<String> scope() async {
    final response = await _request('GET', ['settings']);
    _expectOk(response, mutation: false);
    final body = _json(response);
    if (body is! Map<String, Object?> ||
        body['notesPath'] is! String ||
        body['fileSuffix'] is! String) {
      throw const NotesProtocolException('invalid_settings');
    }
    return '${body['notesPath']}|${body['fileSuffix']}';
  }

  /// An image attached to a note, by the relative path the Markdown uses
  /// (e.g. `.attachments.42/photo.png`).
  Future<List<int>> attachment(int id, String path) async {
    noteId(id);
    final segments = path.split('/');
    if (path.isEmpty ||
        path.startsWith('/') ||
        Uri.tryParse(path)?.hasScheme != false ||
        segments.any((s) => s.isEmpty || s == '.' || s == '..')) {
      throw const NotesProtocolException('invalid_attachment_path');
    }
    final response = await _request(
      'GET',
      ['attachment', '$id'],
      query: {'path': path},
    );
    _expectOk(response, mutation: false);
    final type = response.headers['content-type']?.toLowerCase() ?? '';
    if (!type.startsWith('image/')) {
      throw const NotesProtocolException('not_an_image');
    }
    return response.bodyBytes;
  }

  NoteRecord _detail(http.Response response, {int? expectedId}) {
    final note = parseNote(_json(response));
    if (note is NoteIdOnly || (expectedId != null && note.id != expectedId)) {
      throw const NotesProtocolException('invalid_note_identity');
    }
    return note;
  }

  Object? _json(http.Response response) {
    final type = response.headers['content-type']
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    if (type != 'application/json') {
      throw const NotesProtocolException('unexpected_content_type');
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const NotesProtocolException('invalid_json');
    }
  }

  void _expectOk(http.Response response, {required bool mutation}) {
    if (response.statusCode != 200) {
      throw NotesHttpException(response.statusCode, mayHaveApplied: mutation);
    }
  }

  Future<http.Response> _request(
    String method,
    List<String> path, {
    Map<String, String>? query,
    Map<String, String> headers = const {},
    Map<String, Object>? body,
  }) async {
    final abort = Completer<void>();
    final request =
        http.AbortableRequest(
            method,
            base.notesEndpoint(path, query),
            abortTrigger: abort.future,
          )
          ..followRedirects = false
          ..headers.addAll({
            'Accept': 'application/json',
            'Authorization': _authorization,
            ...headers,
          });
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.bodyBytes = utf8.encode(jsonEncode(body));
    }
    final mutation = method != 'GET';
    try {
      return await (() async {
        final response = await transport.send(request);
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > maxResponseBytes) {
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
      // A local timeout does not cancel or disprove a remote write.
      if (mutation) throw const MutationUncertain();
      throw const NotesTransportException();
    } finally {
      if (!abort.isCompleted) abort.complete();
    }
  }
}
