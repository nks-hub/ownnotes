part of '../editor_writing_test.dart';

void _workflowTests() {
  group('sharing', () {
    Future<http.Response> server(
      http.Request r,
      List<String> log, {
      int shareStatus = 200,
    }) async {
      log.add(
        '${r.method} ${r.url.path}${r.url.query.isEmpty ? '' : '?${r.url.query}'}',
      );
      final p = r.url.path;
      if (p.endsWith('/api/v1/notes') && r.method == 'GET') return _json([]);
      if (p.endsWith('/api/v1/notes') && r.method == 'POST') {
        return _json({
          'id': 55,
          'etag': 'e1',
          'title': 'Doc',
          'content': 'text',
          'category': '',
          'favorite': false,
          'readonly': false,
          'modified': 5,
          'internalPath': '/Notes/Doc.md',
        });
      }
      if (p.contains('/api/v1/notes/')) {
        return _json({
          'id': int.parse(p.split('/').last),
          'etag': 'e1',
          'title': 'Doc',
          'content': 'text',
          'category': '',
          'favorite': false,
          'readonly': false,
          'modified': 5,
          'internalPath': '/Notes/Doc.md',
        });
      }
      if (p.endsWith('/sharees')) {
        return _ocs({
          'users': [
            {
              'label': 'Jan Novák',
              'value': {'shareType': 0, 'shareWith': 'jan'},
            },
          ],
        });
      }
      if (p.endsWith('/shares') && r.method == 'GET') {
        return _ocs(
          shared
              .map(
                (s) => {
                  'id': s.$1,
                  'share_type': 0,
                  'share_with': s.$2,
                  'permissions': s.$3,
                  'path': '/Notes/Doc.md',
                },
              )
              .toList(),
        );
      }
      if (p.endsWith('/shares') && r.method == 'POST') {
        if (shareStatus != 200) return _json({}, shareStatus);
        final form = Uri.splitQueryString(r.body);
        shared.add(('31', form['shareWith']!, int.parse(form['permissions']!)));
        return _ocs({
          'id': 31,
          'share_with': form['shareWith'],
          'permissions': int.parse(form['permissions']!),
          'path': '/Notes/Doc.md',
        });
      }
      if (r.method == 'DELETE') {
        shared.clear();
        return _ocs([]);
      }
      return _json({});
    }

    testWidgets('send a copy works offline as text and as a file', (
      tester,
    ) async {
      final sent = <(String, String, bool)>[];
      final (runtime, note) = await _setup(
        tester,
        title: 'Plan',
        content: 'body',
        remoteId: 7,
      );
      await _open(
        tester,
        runtime,
        note,
        overrides: [
          copySenderProvider.overrideWithValue(
            ({required title, required text, required asFile}) async =>
                sent.add((title, text, asFile)),
          ),
        ],
      );
      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send as text'));
      await tester.tap(find.text('Send as Markdown file'));
      await tester.pump();
      expect(sent, [('Plan', 'body', false), ('Plan', 'body', true)]);
      expect(markdownFileName('a/b: c?'), 'a b c.md');
      expect(markdownFileName('  '), 'note.md');
      await _close(tester);
    });

    testWidgets('a never uploaded note uploads first, then can be shared', (
      tester,
    ) async {
      final log = <String>[];
      shared.clear();
      final (runtime, note) = await _setup(
        tester,
        content: 'text',
        handler: (r) => server(r, log),
      );
      await _open(tester, runtime, note);
      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();
      expect(find.textContaining('not on the server yet'), findsOneWidget);
      expect(
        log.where((l) => l.startsWith('POST') && l.contains('/shares')),
        isEmpty,
      );
      await tester.tap(find.text('Upload and continue'));
      await _settle(tester, 25);
      await tester.pumpAndSettle();
      expect(
        log.any((l) => l.startsWith('POST') && l.endsWith('/api/v1/notes')),
        isTrue,
      );
      expect(find.widgetWithText(TextField, 'Search people'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('share as viewer, see the list, remove access', (tester) async {
      final log = <String>[];
      shared.clear();
      final (runtime, note) = await _setup(
        tester,
        content: 'text',
        remoteId: 7,
        syncState: 'clean',
        handler: (r) => server(r, log),
      );
      await _open(tester, runtime, note);
      await tester.tap(find.byTooltip('Share'));
      await _settle(tester, 6);
      await tester.pumpAndSettle();
      expect(find.text('Not shared with anyone yet.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Search people'),
        'ja',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester, 4);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jan Novák'));
      await tester.pumpAndSettle();
      // Can view is the default.
      expect(find.text('Can view'), findsOneWidget);
      await tester.tap(find.text('Share with Jan Novák'));
      await _settle(tester, 6);
      await tester.pumpAndSettle();
      final post = log.lastWhere(
        (l) => l.startsWith('POST') && l.contains('/shares'),
      );
      expect(post, isNotEmpty);
      expect(find.text('jan'), findsOneWidget);
      expect(find.text('Can view'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove access'));
      await _settle(tester, 6);
      await tester.pumpAndSettle();
      expect(find.text('Not shared with anyone yet.'), findsOneWidget);
      expect(log.any((l) => l.startsWith('DELETE')), isTrue);
      await _close(tester);
    });

    testWidgets('a failed share is shown with Retry and nothing else breaks', (
      tester,
    ) async {
      final log = <String>[];
      shared.clear();
      var failing = true;
      final (runtime, note) = await _setup(
        tester,
        content: 'text',
        remoteId: 7,
        syncState: 'clean',
        handler: (r) => server(r, log, shareStatus: failing ? 500 : 200),
      );
      await _open(tester, runtime, note);
      await tester.tap(find.byTooltip('Share'));
      await _settle(tester, 6);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search people'),
        'ja',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester, 4);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jan Novák'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share with Jan Novák'));
      await _settle(tester, 6);
      await tester.pumpAndSettle();
      expect(find.textContaining('This did not work'), findsOneWidget);
      failing = false;
      await tester.tap(find.text('Retry'));
      await _settle(tester, 6);
      await tester.pumpAndSettle();
      expect(find.textContaining('This did not work'), findsNothing);
      expect(find.text('jan'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('a note shared with me cannot be shared further', (
      tester,
    ) async {
      final (runtime, note) = await _setup(
        tester,
        content: 'x',
        remoteId: 9,
        kind: 'shared',
      );
      await _open(tester, runtime, note);
      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Only its owner can share it further'),
        findsOneWidget,
      );
      await _close(tester);
    });

    testWidgets('attachments get a warning in the share sheet', (tester) async {
      final log = <String>[];
      shared.clear();
      final (runtime, note) = await _setup(
        tester,
        content: '![p](.attachments.7/a.png)',
        remoteId: 7,
        syncState: 'clean',
        handler: (r) => server(r, log),
      );
      await _open(tester, runtime, note);
      await tester.tap(find.byTooltip('Share'));
      await _settle(tester, 4);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('may not be able to open them'),
        findsOneWidget,
      );
      await _close(tester);
    });
  });

  group('saving', () {
    testWidgets('a local save failure is reported and listed under attention', (
      tester,
    ) async {
      final (runtime, note) = await _setup(
        tester,
        content: 'x',
        syncState: 'unreadable',
      );
      await _open(tester, runtime, note);
      await tester.tap(_source);
      await tester.enterText(_source, 'typed on top');
      await tester.pump(const Duration(milliseconds: 500));
      await _settle(tester, 3);
      expect(find.text('Could not save on this device'), findsWidgets);
      expect(
        find.textContaining('could not hand out this note'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Copy Markdown'), findsOneWidget);
      expect(find.text('Export draft'), findsOneWidget);
      final items = await tester.runAsync(
        () => runtime.attention
            .watch(note.accountId)
            .firstWhere(
              (list) => list.any((i) => i.kind == AttentionKind.saveFailure),
            )
            .timeout(const Duration(seconds: 5)),
      );
      expect(items!.any((i) => i.reason == 'note_unreadable'), isTrue);
      // The typed text is still in the editor.
      expect(_controller(tester).text, 'typed on top');
      await _close(tester);
    });
  });

  group('templates and daily notes', () {
    test('placeholders become ordinary text', () {
      final when = DateTime(2026, 10, 20, 7, 5);
      expect(
        expandTemplate('# {{date}} {{time}}\n{{title}}', when, title: 'T'),
        '# 2026-10-20 07:05\nT',
      );
      expect(
        planDailyNote(const DailyNoteConfig(category: 'Daily'), when).title,
        '2026-10-20',
      );
      expect(
        planDailyNote(
          const DailyNoteConfig(titlePattern: 'EEE d.M.'),
          when,
        ).title,
        'Tue 20.10.',
      );
    });

    test('store round trip and bad data', () async {
      const store = TemplateStore();
      expect(await store.templates(), isEmpty);
      await store.saveTemplates(const [
        NoteTemplate(
          id: 'a',
          name: 'Meeting',
          content: '# {{title}}',
          category: 'Work',
        ),
      ]);
      final list = await store.templates();
      expect(list.single.name, 'Meeting');
      expect(list.single.category, 'Work');
      await store.saveDaily(
        const DailyNoteConfig(category: 'Daily', templateId: 'a'),
      );
      expect((await store.daily()).templateId, 'a');
    });

    Future<(AppRuntime, String)> runtimeWithAccount() async {
      final runtime = AppRuntime(
        NotesDatabase(NativeDatabase.memory()),
        _Vault(),
      );
      await runtime.accounts.add(
        LoginCredentials(
          server: ServerBase.parse('https://cloud.test'),
          loginName: 'test',
          appPassword: 'secret',
        ),
      );
      final account = (await runtime.database.watchAccounts().first).single;
      return (runtime, account.id);
    }

    test('createFromTemplate makes a draft in the chosen category', () async {
      final (runtime, account) = await runtimeWithAccount();
      final id = await createFromTemplate(
        runtime,
        account,
        const NoteTemplate(
          id: 't',
          name: 'Meet',
          title: 'Meet {{date}}',
          content: '- [ ] {{title}}',
          category: 'Work',
        ),
        now: DateTime(2026, 1, 2),
      );
      final note = (await runtime.database.note(account, id))!;
      expect(note.title, 'Meet 2026-01-02');
      expect(note.content, '- [ ] Meet 2026-01-02');
      expect(note.category, 'Work');
      final moved = await createFromTemplate(
        runtime,
        account,
        const NoteTemplate(id: 't', name: 'Meet'),
        category: 'Elsewhere',
      );
      expect(
        (await runtime.database.note(account, moved))!.category,
        'Elsewhere',
      );
      await runtime.close();
    });

    test('the daily note is created once per title and category', () async {
      final (runtime, account) = await runtimeWithAccount();
      const config = DailyNoteConfig(category: 'Daily');
      final when = DateTime(2026, 5, 6);
      final first = await createDailyNote(
        runtime,
        account,
        config: config,
        now: when,
        template: const NoteTemplate(
          id: 't',
          name: 'D',
          content: '## {{date}}',
        ),
      );
      expect(first.created, isTrue);
      expect(first.plan.title, '2026-05-06');
      final note = (await runtime.database.note(account, first.noteId))!;
      expect(note.content, '## 2026-05-06');
      expect(note.category, 'Daily');
      final again = await createDailyNote(
        runtime,
        account,
        config: config,
        now: when,
      );
      expect(again.created, isFalse);
      expect(again.noteId, first.noteId);
      final next = await createDailyNote(
        runtime,
        account,
        config: config,
        now: DateTime(2026, 5, 7),
      );
      expect(next.created, isTrue);
      await runtime.close();
    });
  });
}
