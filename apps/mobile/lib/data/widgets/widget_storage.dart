import 'package:home_widget/home_widget.dart';

/// Keys shared with the Android widget code (`widget/WidgetKeys.kt`). Every key
/// has one writer: the config and snapshot keys are written by Dart, the
/// command keys by the widget's tap receiver, `cmddone` and `applied` by Dart.
abstract final class WidgetKeys {
  static const locked = 'locked';
  static const untitled = 'widget.untitled';

  /// Callback handle of `widgetConfigMain`, which the configuration activity
  /// starts its Flutter engine with.
  static const configHandle = 'widget.confighandle';
  static const applied = 'widget.applied';
  static String config(String id) => 'widget.config.$id';
  static String snapshot(String id) => 'widget.snapshot.$id';

  /// Number of commands the widget queued for instance [id] (widget side).
  static String cmdSeq(String id) => 'widget.cmdseq.$id';

  /// Number of those commands Dart has handled.
  static String cmdDone(String id) => 'widget.cmddone.$id';
  static String cmd(String id, int n) => 'widget.cmd.$id.$n';

  /// Revision of a checklist note whose last tick could not be applied.
  static String stale(String id) => 'widget.stale.$id';
}

/// Where widget configuration, snapshots and queued commands live. Android
/// keeps them in the home_widget preferences, which the widget code reads too.
abstract interface class WidgetStorage {
  /// Ids of the widget instances placed on the home screen.
  Future<List<String>> instanceIds();
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
  Future<bool> isLocked();
  Future<void> setLocked(bool locked);

  /// Asks the launcher to redraw every instance.
  Future<void> refresh();
}

const widgetProviderClass = 'com.nkshub.nextcloudnotes.NotesWidget';

final class HomeWidgetStorage implements WidgetStorage {
  const HomeWidgetStorage();

  @override
  Future<List<String>> instanceIds() async => [
    for (final w in await HomeWidget.getInstalledWidgets())
      if (w.androidWidgetId != null) '${w.androidWidgetId}',
  ];

  @override
  Future<String?> read(String key) => HomeWidget.getWidgetData<String>(key);

  @override
  Future<void> write(String key, String? value) async {
    await HomeWidget.saveWidgetData<String>(key, value);
  }

  @override
  Future<bool> isLocked() async =>
      await HomeWidget.getWidgetData<bool>(WidgetKeys.locked) ?? false;

  @override
  Future<void> setLocked(bool locked) async {
    await HomeWidget.saveWidgetData<bool>(WidgetKeys.locked, locked);
  }

  @override
  Future<void> refresh() async {
    await HomeWidget.updateWidget(qualifiedAndroidName: widgetProviderClass);
  }
}
