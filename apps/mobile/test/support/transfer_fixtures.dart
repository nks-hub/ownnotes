import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nextcloudnotes/data/attachments/attachment_cache.dart';
import 'package:nextcloudnotes/data/attachments/attachment_service.dart';
import 'package:nextcloudnotes/data/attachments/staging.dart';
import 'package:nextcloudnotes/data/runtime.dart';
import 'package:nextcloudnotes/features/attachments/attach_sources.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';

class FileSources implements AttachmentSources {
  FileSources(this.picked);
  final List<PickedFile> picked;
  @override
  Future<List<PickedFile>> photos() async => picked;
  @override
  Future<PickedFile?> camera() async => picked.firstOrNull;
  @override
  Future<List<PickedFile>> files() async => picked;
}

class FakeVault implements CredentialVault {
  final entries = <String, String>{};
  @override
  Future<void> write(String reference, String password) async {
    entries[reference] = password;
  }

  @override
  Future<String?> read(String reference) async => entries[reference];
  @override
  Future<void> delete(String reference) async {
    entries.remove(reference);
  }

  @override
  Future<Set<String>> references() async => entries.keys.toSet();
}

/// What a fake Notes server saw of attachment calls.
class FakeServer {
  final uploads = <String>[];
  final deletes = <String>[];

  /// Status for the next upload calls; empty means 200.
  final failures = <int>[];
  bool offline = false;

  Future<http.Response> handle(http.Request r) async {
    if (offline) throw const SocketException('offline');
    if (r.url.path.contains('/attachment/')) {
      if (r.method == 'POST') {
        if (failures.isNotEmpty) {
          return http.Response('{}', failures.removeAt(0));
        }
        final name = RegExp(r'filename="([^"]+)"').firstMatch(r.body)![1]!;
        uploads.add(name);
        final id = r.url.pathSegments.last;
        return http.Response(
          jsonEncode({'filename': '.attachments.$id/$name'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (r.method == 'DELETE') {
        deletes.add(r.url.queryParameters['path']!);
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response.bytes([1, 2, 3], 200);
    }
    return http.Response('{}', 404);
  }
}

class TransferEnv {
  TransferEnv._(
    this.dir,
    this.runtime,
    this.accountId,
    this.server,
    this.service,
  );

  final Directory dir;
  final AppRuntime runtime;
  final String accountId;
  final FakeServer server;
  final AttachmentService service;

  NotesDatabase get db => runtime.database;

  static Future<TransferEnv> create({
    List<Duration> retryDelays = const [],
    Directory? dir,
  }) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final root = dir ?? await Directory.systemTemp.createTemp('transfers');
    final server = FakeServer();
    final runtime = AppRuntime(
      NotesDatabase(NativeDatabase.memory()),
      FakeVault(),
    );
    final accountId = await runtime.accounts.add(
      LoginCredentials(
        server: ServerBase.parse('https://cloud.test'),
        loginName: 'anna',
        appPassword: 'secret',
      ),
    );
    final env = TransferEnv._(
      root,
      runtime,
      accountId,
      server,
      attachmentServiceFor(root, runtime.database, server, retryDelays),
    );
    return env;
  }

  /// A new service over the same folders, as after a restart.
  AttachmentService restarted() =>
      attachmentServiceFor(dir, db, server, const []);

  Future<String> addNote({
    String id = 'n1',
    int? remoteId = 42,
    String content = 'body',
    String? accountId,
  }) async {
    await db
        .into(db.localNotes)
        .insert(
          LocalNotesCompanion.insert(
            id: id,
            accountId: accountId ?? this.accountId,
            title: 'T $id',
            content: content,
            remoteId: Value(remoteId),
            updatedAt: 1,
          ),
        );
    return id;
  }

  Future<File> file(String name, [List<int> bytes = const [1, 2, 3]]) async {
    final f = File('${dir.path}/src/$name');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes);
    return f;
  }

  Future<void> dispose() async {
    await runtime.close();
    // A background flush may still hold a file for a moment (Windows).
    for (var i = 0; i < 5 && await dir.exists(); i++) {
      try {
        await dir.delete(recursive: true);
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }
}

AttachmentService attachmentServiceFor(
  Directory root,
  NotesDatabase db,
  FakeServer server,
  List<Duration> retryDelays,
) => AttachmentService(
  database: db,
  staging: AttachmentStaging(Directory('${root.path}/staging')),
  cache: AttachmentCache(Directory('${root.path}/cache')),
  retryDelays: retryDelays,
  clientFor: (account) async => AttachmentsClient(
    base: ServerBase.parse(account.server),
    transport: MockClient(server.handle),
    loginName: account.loginName,
    appPassword: 'secret',
    route: AttachmentRoute.current,
  ),
);
