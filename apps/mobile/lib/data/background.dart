import 'dart:async';

import 'package:workmanager/workmanager.dart';
import 'background_policy.dart';
import 'notes_widget.dart';
import 'runtime.dart';

const _task = 'ownnotes-sync';
const _once = '$_task-once';

/// Runs in a separate isolate (and maybe process) started by the OS. It uses
/// the same database and the same coordinator rules as the app; the
/// per-account lease keeps the two from sending at the same time.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask(
    (task, input) => runBackgroundSync(retryWhenBlocked: task == _once),
  );
}

Future<bool> runBackgroundSync({
  AppRuntime Function()? openRuntime,
  bool retryWhenBlocked = false,
}) async {
  final preferences = await BackgroundSyncPreferences.load();
  if (!preferences.enabled) return true;
  // Periodic work keeps its interval instead of accumulating retry backoff.
  if (!await backgroundSyncAllowed()) return !retryWhenBlocked;
  final runtime =
      openRuntime?.call() ??
      AppRuntime.production(decorateTransport: BackgroundSyncClient.new);
  try {
    final db = runtime.database;
    for (final account in await db.select(db.accounts).get()) {
      if (!await backgroundSyncAllowed()) return !retryWhenBlocked;
      try {
        await runtime.sync.sync(account.id);
      } catch (_) {
        // Offline or refused; drafts stay and the next run tries again.
      }
    }
    // The app redraws the widgets only while it is open; this also applies
    // ticks queued on the widgets meanwhile.
    await publishAllWidgets(db);
    return true;
  } finally {
    await runtime.close();
  }
}

Future<void>? _scheduleTail;

Future<void> _schedule(Future<void> Function() apply) async {
  final previous = _scheduleTail;
  final done = Completer<void>();
  _scheduleTail = done.future;
  try {
    if (previous != null) await previous;
    await apply();
  } finally {
    if (identical(_scheduleTail, done.future)) _scheduleTail = null;
    done.complete();
  }
}

/// Update the existing schedule without resetting its elapsed interval.
Future<void> scheduleBackgroundSync() => _schedule(() async {
  if (!hasAndroidBackgroundSync) return;
  final preferences = await BackgroundSyncPreferences.load();
  final work = Workmanager();
  if (!preferences.enabled) {
    await work.cancelByUniqueName(_once);
    await work.cancelByUniqueName(_task);
    return;
  }
  await work.initialize(backgroundDispatcher);
  await work.registerPeriodicTask(
    _task,
    _task,
    frequency: Duration(minutes: preferences.minutes),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
});

/// Lifecycle flushes obey the same preferences as periodic work. A Wi-Fi-only
/// worker retries when the current connection is cellular, even if unmetered.
Future<void> syncWhenOnline() => _schedule(() async {
  if (!hasAndroidBackgroundSync) return;
  final preferences = await BackgroundSyncPreferences.load();
  if (!preferences.enabled) return;
  await Workmanager().initialize(backgroundDispatcher);
  await Workmanager().registerOneOffTask(
    _once,
    _once,
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );
});
