import 'dart:io';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';
import 'notes_widget.dart';
import 'runtime.dart';

const _task = 'ownnotes-sync';

/// Runs in a separate isolate (and maybe process) started by the OS. It uses
/// the same database and the same coordinator rules as the app; the
/// per-account lease keeps the two from sending at the same time.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, input) async {
    final runtime = AppRuntime.production();
    try {
      final db = runtime.database;
      for (final account in await db.select(db.accounts).get()) {
        try {
          await runtime.sync.sync(account.id);
        } catch (_) {
          // Offline or refused; drafts stay and the next run tries again.
        }
      }
      // The app redraws the widget only while it is open.
      final shown = await HomeWidget.getWidgetData<String>('account');
      if (shown != null && await db.account(shown) != null) {
        await publishNotesWidget(
          shown,
          await db.watchNotes(shown).first,
          locked: await HomeWidget.getWidgetData<bool>('locked') ?? false,
          untitled: '…',
        );
      }
      return true;
    } finally {
      await runtime.close();
    }
  });
}

/// Uploads drafts and pulls changes about every 15 minutes while a network
/// is available, also when the app is closed.
Future<void> scheduleBackgroundSync() async {
  if (!Platform.isAndroid) return;
  await Workmanager().initialize(backgroundDispatcher);
  await Workmanager().registerPeriodicTask(
    _task,
    _task,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

/// One extra run as soon as a network is available; queued when the app
/// goes to the background, so an offline edit does not wait for the
/// periodic run.
Future<void> syncWhenOnline() async {
  if (!Platform.isAndroid) return;
  await Workmanager().registerOneOffTask(
    '$_task-once',
    _task,
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}
