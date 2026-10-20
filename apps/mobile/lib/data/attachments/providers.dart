import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:path_provider/path_provider.dart';

import '../runtime.dart';
import 'attachment_cache.dart';
import 'attachment_service.dart';
import 'staging.dart';

/// Staged files are the user's content, so they live in app support storage,
/// not in the cache directory the system may empty.
final attachmentServiceProvider = FutureProvider<AttachmentService>((
  ref,
) async {
  final runtime = ref.watch(runtimeProvider);
  final support = await getApplicationSupportDirectory();
  final routes = <String, AttachmentRoute>{};
  final transports = <String, http.Client>{};
  ref.onDispose(() {
    for (final t in transports.values) {
      t.close();
    }
  });
  Future<AttachmentsClient> clientFor(Account account) async {
    final password = await runtime.vault.read(account.credentialRef);
    if (password == null) throw StateError('reauth_required');
    AttachmentsClient make(AttachmentRoute route) => AttachmentsClient(
      base: ServerBase.parse(account.server),
      transport: transports.putIfAbsent(account.id, http.Client.new),
      loginName: account.loginName,
      appPassword: password,
      route: route,
    );
    var route = routes[account.id];
    if (route == null) {
      try {
        route = AttachmentRoute.forNotesVersion(
          await make(AttachmentRoute.legacy).notesVersion(),
        );
        routes[account.id] = route;
      } on Object {
        // Offline now: the route every release has, asked again next time.
        route = AttachmentRoute.legacy;
      }
    }
    return make(route);
  }

  return AttachmentService(
    database: runtime.database,
    staging: AttachmentStaging(Directory('${support.path}/attachments')),
    // Not the system cache folder: "available offline" must hold.
    cache: AttachmentCache(Directory('${support.path}/attachment_cache')),
    clientFor: clientFor,
  );
});
