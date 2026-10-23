import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:http/http.dart' as http;

import 'client.dart';
import 'models.dart';
import 'server_base.dart';

/// A user a note can be shared with (`shareType` 0).
final class Sharee {
  const Sharee({required this.userId, required this.label});
  final String userId;
  final String label;
}

/// A share of a file, as the owner sees it.
final class FileShare {
  const FileShare({
    required this.id,
    required this.shareWith,
    required this.permissions,
    required this.path,
  });
  final String id;
  final String shareWith;

  /// Bit mask: 1 read, 2 update.
  final int permissions;
  final String path;
  bool get canEdit => permissions & 2 != 0;
}

/// An incoming file or folder at its mount path in the recipient's files.
final class IncomingShare {
  const IncomingShare({
    required this.id,
    required this.fileId,
    required this.path,
    required this.ownerId,
    required this.ownerName,
    required this.permissions,
    this.isFolder = false,
  });
  final String id;

  /// Equals the Notes API id when the file is a note.
  final int fileId;
  final String path;
  final String ownerId;
  final String ownerName;
  final int permissions;
  final bool isFolder;
  bool get canEdit => permissions & 2 != 0;
}

/// Direct file IDs and shared folders; a missing file path leaves inheritance unknown.
final class ShareTargets {
  const ShareTargets({this.fileIds = const {}, this.folderPaths = const {}});
  final Set<int> fileIds;
  final Set<String> folderPaths;

  bool? contains(int id, String? path) {
    if (fileIds.contains(id)) return true;
    if (folderPaths.isEmpty) return false;
    if (path == null || !path.startsWith('/')) return null;
    return inherits(path);
  }

  bool inherits(String path) => folderPaths.any(
    (folder) => path.startsWith(folder == '/' ? '/' : '$folder/'),
  );
}

String _sharePath(Object? value) {
  if (value is! String ||
      !value.startsWith('/') ||
      value.contains('\\') ||
      value.contains('\u0000')) {
    throw const NotesProtocolException('invalid_share_path');
  }
  final path = value.replaceFirst(RegExp(r'/+$'), '');
  if (value == '/') return '/';
  if (path.isEmpty ||
      path
          .substring(1)
          .split('/')
          .any((s) => s.isEmpty || s == '.' || s == '..')) {
    throw const NotesProtocolException('invalid_share_path');
  }
  return path;
}

final class SharedFile {
  const SharedFile({required this.content, required this.etag});
  final String content;

  /// The WebDAV entity tag. It is not the Notes API etag of the same note.
  final String etag;
}

final class SharedStat {
  const SharedStat({
    required this.etag,
    required this.fileId,
    required this.writable,
    required this.modified,
  });
  final String etag;
  final int? fileId;
  final bool writable;
  final DateTime? modified;
}

/// A WebDAV write failed its If-Match: the file changed since it was read.
final class SharedConflict implements Exception {
  const SharedConflict();
  @override
  String toString() => 'SharedConflict';
}

/// OCS sharing and WebDAV access to shared files. One instance belongs to one
/// account; like [NotesClient] it never retries and keeps bodies out of errors.
final class SharingClient {
  SharingClient({
    required this.base,
    required this.transport,
    required this.loginName,
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
  final String loginName;
  final String _authorization;
  final Duration timeout;
  final int maxResponseBytes;

  Future<List<Sharee>> searchSharees(String query, {int limit = 10}) async {
    final data = await _ocs(
      'GET',
      ['sharees'],
      query: {'search': query, 'itemType': 'file', 'perPage': '$limit'},
    );
    final users = (data as Map<String, Object?>)['users'];
    final exact = (data['exact'] as Map<String, Object?>?)?['users'];
    return [
      for (final u in [...?(exact as List?), ...?(users as List?)])
        if (u case {
          'label': final String label,
          'value': {'shareType': 0, 'shareWith': final String id},
        })
          if (id != loginName) Sharee(userId: id, label: label),
    ];
  }

  /// [path] is the file's path in the owner's files, e.g.
  /// `/Notes/Shopping.md` (`internalPath` of the Notes API).
  Future<FileShare> shareWithUser(
    String path,
    String userId, {
    bool canEdit = true,
  }) async {
    if (!path.startsWith('/') || userId.isEmpty) {
      throw ArgumentError('Invalid share parameters');
    }
    return _fileShare(
      await _ocs(
        'POST',
        const ['shares'],
        form: {
          'path': path,
          'shareType': '0',
          'shareWith': userId,
          'permissions': canEdit ? '3' : '1',
        },
      ),
    );
  }

  Future<List<FileShare>> sharesOf(String path) async {
    return (await shareSummary(path)).users;
  }

  /// Includes group and link shares in the badge while the editor lists users.
  Future<({List<FileShare> users, bool isShared, bool hasOtherShares})>
  shareSummary(String path) async {
    final data = await _ocs('GET', const ['shares'], query: {'path': path});
    final shares = data as List<Object?>;
    final inherited = (await sharedTargets()).inherits(path);
    return (
      users: [
        for (final s in shares)
          if (s is Map<String, Object?> && s['share_type'] == 0) _fileShare(s),
      ],
      isShared: shares.isNotEmpty || inherited,
      hasOtherShares:
          inherited ||
          shares.any((s) => s is Map<String, Object?> && s['share_type'] != 0),
    );
  }

  /// Outgoing file and folder shares, including public links and group shares.
  Future<ShareTargets> sharedTargets() async {
    final data = await _ocs('GET', const ['shares']);
    final ids = <int>{};
    final folders = <String>{};
    for (final share in data as List<Object?>) {
      if (share is! Map<String, Object?>) continue;
      if (share['item_type'] == 'folder') {
        folders.add(_sharePath(share['path']));
        continue;
      }
      if (share['item_type'] != 'file') {
        continue;
      }
      final id = share['file_source'];
      if (id is! int || id <= 0) {
        throw const NotesProtocolException('invalid_share_file');
      }
      ids.add(id);
    }
    return ShareTargets(
      fileIds: Set.unmodifiable(ids),
      folderPaths: Set.unmodifiable(folders),
    );
  }

  /// Removes a share; the recipient may remove one shared with them as well.
  Future<void> unshare(String shareId) async {
    if (shareId.isEmpty || shareId.contains('/')) {
      throw ArgumentError('Invalid share id');
    }
    await _ocs('DELETE', ['shares', shareId]);
  }

  /// Files and folders shared directly with this account or one of its groups.
  Future<List<IncomingShare>> sharedWithMe() async {
    final data = await _ocs(
      'GET',
      const ['shares'],
      query: {'shared_with_me': 'true'},
    );
    return [
      for (final s in data as List<Object?>)
        if (s is Map<String, Object?> &&
            (s['share_type'] == 0 || s['share_type'] == 1) &&
            (s['item_type'] == 'file' || s['item_type'] == 'folder') &&
            s['file_target'] is String &&
            s['file_source'] is int)
          IncomingShare(
            id: '${s['id']}',
            fileId: noteId(s['file_source']),
            path: _sharePath(s['file_target']),
            ownerId: '${s['uid_owner']}',
            ownerName: '${s['displayname_owner'] ?? s['uid_owner']}',
            permissions: s['permissions'] is int ? s['permissions']! as int : 1,
            isFolder: s['item_type'] == 'folder',
          ),
    ];
  }

  Future<SharedStat> stat(String path) async {
    final response = await _send(
      'PROPFIND',
      _dav(path),
      headers: {'Depth': '0', 'Content-Type': 'application/xml'},
      body: _propfind,
    );
    if (response.statusCode != 207) {
      throw NotesHttpException(response.statusCode, mayHaveApplied: false);
    }
    final xml = utf8.decode(response.bodyBytes);
    final etag = _prop(xml, 'getetag');
    if (etag == null) throw const NotesProtocolException('missing_etag');
    final date = _prop(xml, 'getlastmodified');
    DateTime? modified;
    try {
      modified = date == null ? null : HttpDate.parse(date).toUtc();
    } on Exception {
      /* A missing date stays explicit. */
    }
    return SharedStat(
      etag: _unquote(etag),
      fileId: int.tryParse(_prop(xml, 'fileid') ?? ''),
      writable: (_prop(xml, 'permissions') ?? '').contains('W'),
      modified: modified,
    );
  }

  Future<SharedFile> read(String path) async {
    final response = await _send('GET', _dav(path));
    if (response.statusCode != 200) {
      throw NotesHttpException(response.statusCode, mayHaveApplied: false);
    }
    final etag = response.headers['etag'];
    if (etag == null) throw const NotesProtocolException('missing_etag');
    try {
      return SharedFile(
        content: utf8.decode(response.bodyBytes),
        etag: _unquote(etag),
      );
    } on FormatException {
      throw const NotesProtocolException('invalid_utf8');
    }
  }

  /// Returns the new entity tag. Throws [SharedConflict] on 412.
  Future<String> write(
    String path,
    String content, {
    required String etag,
  }) async {
    final response = await _send(
      'PUT',
      _dav(path),
      headers: {
        'If-Match': quoteEtag(etag),
        'Content-Type': 'text/markdown; charset=utf-8',
      },
      body: utf8.encode(content),
    );
    if (response.statusCode == 412) throw const SharedConflict();
    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw NotesHttpException(response.statusCode, mayHaveApplied: true);
    }
    final fresh = response.headers['oc-etag'] ?? response.headers['etag'];
    if (fresh == null) throw const MutationUncertain();
    return _unquote(fresh);
  }

  /// Moves a received file to [to] in the recipient's files. Into the Notes
  /// folder it becomes an ordinary note of the Notes API (same id), after
  /// which [NotesClient] handles it.
  Future<void> move(String from, String to) async {
    final response = await _send(
      'MOVE',
      _dav(from),
      headers: {'Destination': _dav(to).toString(), 'Overwrite': 'F'},
    );
    if (response.statusCode != 201 && response.statusCode != 204) {
      throw NotesHttpException(response.statusCode, mayHaveApplied: true);
    }
  }

  Future<void> createFolder(String path) async {
    final response = await _send('MKCOL', _dav(path));
    // 405: the folder exists already.
    if (response.statusCode != 201 && response.statusCode != 405) {
      throw NotesHttpException(response.statusCode, mayHaveApplied: true);
    }
  }

  static final List<int> _propfind = utf8.encode(
    '<?xml version="1.0"?><d:propfind xmlns:d="DAV:" '
    'xmlns:oc="http://owncloud.org/ns"><d:prop><d:getetag/>'
    '<d:getlastmodified/><oc:fileid/><oc:permissions/></d:prop></d:propfind>',
  );

  Uri _dav(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (!path.startsWith('/') ||
        segments.any((s) => s == '.' || s == '..' || s.contains('\\'))) {
      throw const NotesProtocolException('invalid_path');
    }
    return base.davFile(loginName, segments);
  }

  static String? _prop(String xml, String name) {
    final m = RegExp('<(?:\\w+:)?$name>([^<]*)<').firstMatch(xml);
    return m == null
        ? null
        : m[1]!.replaceAll('&quot;', '"').replaceAll('&amp;', '&');
  }

  static String _unquote(String etag) {
    var e = etag.trim();
    if (e.startsWith('W/')) e = e.substring(2);
    return e.length >= 2 && e.startsWith('"') && e.endsWith('"')
        ? e.substring(1, e.length - 1)
        : e;
  }

  FileShare _fileShare(Object? data) {
    if (data case {
      'id': final Object id,
      'share_with': final String with_,
      'permissions': final int permissions,
      'path': final String path,
    }) {
      return FileShare(
        id: '$id',
        shareWith: with_,
        permissions: permissions,
        path: path,
      );
    }
    throw const NotesProtocolException('invalid_share');
  }

  Future<Object?> _ocs(
    String method,
    List<String> path, {
    Map<String, String>? query,
    Map<String, String>? form,
  }) async {
    final response = await _send(
      method,
      base.ocsSharing(path, {...?query, 'format': 'json'}),
      headers: {
        'OCS-APIRequest': 'true',
        'Accept': 'application/json',
        if (form != null)
          'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
      },
      body: form == null ? null : utf8.encode(Uri(queryParameters: form).query),
    );
    if (response.statusCode != 200) {
      throw NotesHttpException(
        response.statusCode,
        mayHaveApplied: method != 'GET',
      );
    }
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final meta =
          (body as Map<String, Object?>)['ocs'] as Map<String, Object?>;
      final status = (meta['meta']! as Map<String, Object?>)['statuscode'];
      if (status != 200 && status != 100) {
        throw NotesHttpException(
          status is int ? status : 500,
          mayHaveApplied: method != 'GET',
        );
      }
      return meta['data'];
    } on FormatException {
      throw const NotesProtocolException('invalid_json');
    } on TypeError {
      throw const NotesProtocolException('invalid_ocs');
    }
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) async {
    final abort = Completer<void>();
    final request =
        http.AbortableRequest(method, uri, abortTrigger: abort.future)
          ..followRedirects = false
          ..headers.addAll({'Authorization': _authorization, ...headers});
    if (body != null) request.bodyBytes = body;
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
      if (method != 'GET' && method != 'PROPFIND') {
        throw const MutationUncertain();
      }
      rethrow;
    } catch (_) {
      if (method != 'GET' && method != 'PROPFIND') {
        throw const MutationUncertain();
      }
      throw const NotesTransportException();
    } finally {
      if (!abort.isCompleted) abort.complete();
    }
  }
}
