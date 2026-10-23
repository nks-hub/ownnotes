import 'package:flutter/material.dart';
import 'package:notes_store/notes_store.dart';
import '../../core/markdown/markdown_document.dart';
import '../../data/widgets/widget_model.dart';
import '../../data/widgets/widget_snapshots.dart';
import '../../l10n/app_localizations.dart';

/// An account a widget can be bound to.
final class WidgetAccountChoice {
  const WidgetAccountChoice(this.id, this.label);
  final String id;
  final String label;
}

/// Configuration of one widget instance (spec 9.1): type, account, the
/// collection or note, and appearance. The result belongs to the instance;
/// changing the app's selected account never touches it.
class WidgetConfigScreen extends StatefulWidget {
  const WidgetConfigScreen({
    required this.instanceId,
    required this.accounts,
    required this.notesOf,
    required this.onSave,
    required this.onCancel,
    this.initial,
    super.key,
  });

  final String instanceId;
  final List<WidgetAccountChoice> accounts;
  final Future<List<LocalNote>> Function(String accountId) notesOf;
  final Future<void> Function(WidgetConfig config) onSave;
  final VoidCallback onCancel;

  /// Present when an existing widget is reconfigured.
  final WidgetConfig? initial;

  @override
  State<WidgetConfigScreen> createState() => _WidgetConfigScreenState();
}

class _WidgetConfigScreenState extends State<WidgetConfigScreen> {
  late WidgetType _type = widget.initial?.type ?? WidgetType.notesList;
  late String? _account = _initialAccount();
  late WidgetCollection _collection =
      widget.initial?.collection ?? const WidgetCollection(WidgetScope.all);
  late String? _noteId = widget.initial?.noteId;
  late WidgetAppearance _appearance =
      widget.initial?.appearance ?? WidgetAppearance.system;
  Future<List<LocalNote>> _notes = Future.value(const []);
  bool _saving = false;
  bool _failed = false;

  String? _initialAccount() {
    final wanted = widget.initial?.accountId;
    if (widget.accounts.any((a) => a.id == wanted)) return wanted;
    return widget.accounts.length == 1 ? widget.accounts.single.id : null;
  }

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  void _loadNotes() {
    final account = _account;
    _notes = account == null ? Future.value(const []) : widget.notesOf(account);
  }

  WidgetConfig? get _config {
    final account = _account;
    if (account == null) return null;
    final config = WidgetConfig(
      instanceId: widget.instanceId,
      type: _type,
      accountId: account,
      collection: _type == WidgetType.notesList ? _collection : null,
      noteId: _type == WidgetType.singleNote || _type == WidgetType.checklist
          ? _noteId
          : null,
      appearance: _appearance,
    );
    return config.isConfigured ? config : null;
  }

  Future<void> _save() async {
    final config = _config;
    if (config == null || _saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.onSave(config);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  String _typeName(AppLocalizations l, WidgetType t) => switch (t) {
    WidgetType.notesList => l.widgetTypeList,
    WidgetType.singleNote => l.widgetTypeNote,
    WidgetType.checklist => l.widgetTypeChecklist,
    WidgetType.quickNote => l.widgetTypeQuick,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.cancel,
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
        title: Text(l.widgetConfigTitle),
      ),
      body: widget.accounts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.widgetNoAccount, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                _Section(l.widgetTypeLabel),
                for (final t in WidgetType.values)
                  _Choice(
                    label: _typeName(l, t),
                    selected: _type == t,
                    onTap: () => setState(() => _type = t),
                  ),
                _Section(l.widgetAccountLabel),
                for (final a in widget.accounts)
                  _Choice(
                    label: a.label,
                    selected: _account == a.id,
                    onTap: () => setState(() {
                      _account = a.id;
                      _noteId = null;
                      _collection = const WidgetCollection(WidgetScope.all);
                      _loadNotes();
                    }),
                  ),
                if (_type == WidgetType.notesList) ..._collectionChoices(l),
                if (_type == WidgetType.singleNote ||
                    _type == WidgetType.checklist)
                  ..._noteChoices(l),
                _Section(l.widgetAppearanceLabel),
                for (final a in WidgetAppearance.values)
                  _Choice(
                    label: switch (a) {
                      WidgetAppearance.system => l.themeSystem,
                      WidgetAppearance.light => l.themeLight,
                      WidgetAppearance.dark => l.themeDark,
                    },
                    selected: _appearance == a,
                    onTap: () => setState(() => _appearance = a),
                  ),
              ],
            ),
      bottomNavigationBar: widget.accounts.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_failed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            l.widgetSaveFailed,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _config == null || _saving ? null : _save,
                      child: Text(l.widgetAdd),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  List<Widget> _collectionChoices(AppLocalizations l) => [
    _Section(l.widgetCollectionLabel),
    for (final (label, value) in [
      (l.allNotes, const WidgetCollection(WidgetScope.all)),
      (l.favorites, const WidgetCollection(WidgetScope.favorites)),
      (l.uncategorised, const WidgetCollection(WidgetScope.uncategorised)),
    ])
      _Choice(
        label: label,
        selected: _collection.scope == value.scope,
        onTap: () => setState(() => _collection = value),
      ),
    FutureBuilder<List<LocalNote>>(
      future: _notes,
      builder: (context, snapshot) {
        final paths = {
          for (final n in snapshot.data ?? const <LocalNote>[])
            if (n.category.isNotEmpty) n.category,
        }.toList()..sort();
        return Column(
          children: [
            for (final path in paths)
              _Choice(
                label: path,
                selected:
                    _collection.scope == WidgetScope.category &&
                    _collection.category == path,
                onTap: () => setState(
                  () => _collection = WidgetCollection(
                    WidgetScope.category,
                    path,
                  ),
                ),
              ),
          ],
        );
      },
    ),
  ];

  List<Widget> _noteChoices(AppLocalizations l) => [
    _Section(l.widgetNoteLabel),
    FutureBuilder<List<LocalNote>>(
      future: _notes,
      builder: (context, snapshot) {
        final all = snapshot.data;
        if (all == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final checklist = _type == WidgetType.checklist;
        final notes = [
          for (final n in all)
            if (!checklist ||
                MarkdownDocument.parse(n.content).tasks.isNotEmpty)
              n,
        ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        if (notes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(checklist ? l.widgetNoChecklistNotes : l.noNotes),
          );
        }
        return Column(
          children: [
            for (final n in notes)
              _Choice(
                label: widgetNoteTitle(n, l.untitled),
                selected: _noteId == n.id,
                onTap: () => setState(() => _noteId = n.id),
              ),
          ],
        );
      },
    ),
  ];
}

class _Section extends StatelessWidget {
  const _Section(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
    child: Semantics(
      header: true,
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}

/// One option of a single-choice group; the selection shows as a check, not
/// colour alone.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    inMutuallyExclusiveGroup: true,
    selected: selected,
    child: ListTile(
      minTileHeight: 48,
      title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
      selected: selected,
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: onTap,
    ),
  );
}
