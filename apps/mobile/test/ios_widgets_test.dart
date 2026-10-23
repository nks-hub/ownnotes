import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/data/widgets/ios_widgets.dart';
import 'package:nextcloudnotes/data/widgets/widget_snapshots.dart';
import 'package:notes_store/notes_store.dart';

LocalNote note(
  String id,
  String content,
  int updatedAt, {
  String account = 'a',
}) => LocalNote(
  id: id,
  accountId: account,
  title: id,
  content: content,
  category: '',
  favorite: false,
  readonly: false,
  revision: 1,
  syncState: 'clean',
  updatedAt: updatedAt,
  kind: 'note',
);

void main() {
  final notes = [
    note('old', '- [ ] milk', 1),
    note('new', 'plain', 5),
    note('other', '- [ ] x', 9, account: 'b'),
  ];

  test('configs pick the latest note and the latest note with tasks', () {
    final configs = iosWidgetConfigs('a', notes);
    expect(configs.map((c) => c.instanceId), [
      'ios.notesList',
      'ios.singleNote',
      'ios.checklist',
      'ios.quickNote',
    ]);
    expect(configs[1].noteId, 'new');
    expect(configs[2].noteId, 'old');
    expect(configs.every((c) => c.isConfigured), isTrue);
  });

  test('locked snapshots of every kind carry no content', () {
    for (final c in iosWidgetConfigs('a', notes)) {
      final s = buildWidgetSnapshot(
        c,
        notes,
        locked: true,
        untitled: 'Untitled',
        now: 1,
        accountLabel: 'Home',
      );
      expect(s.isRedacted, isTrue);
      expect(s.encode(), isNot(contains('milk')));
      expect(s.encode(), isNot(contains('Home')));
    }
  });
}
