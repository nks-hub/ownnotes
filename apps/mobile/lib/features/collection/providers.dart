import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_store/notes_store.dart';
import '../../data/runtime.dart';

/// What an account's last passes found and what still waits; drives the
/// collapsing status area and the sync details sheet.
final syncStatusProvider = StreamProvider.autoDispose
    .family<AccountSyncStatus, String>(
      (ref, accountId) =>
          ref.watch(runtimeProvider).database.watchSyncStatus(accountId),
    );

/// The "Needs attention" list of an account.
final attentionProvider = StreamProvider.autoDispose
    .family<List<AttentionItem>, String>(
      (ref, accountId) => ref.watch(runtimeProvider).attention.watch(accountId),
    );
