import 'package:flutter/material.dart';
import '../../core/markdown/live_styling.dart';
import '../../design/design.dart';
import '../../l10n/app_localizations.dart';
import 'templates.dart';

/// Sheet listing the device's templates; returns the chosen one. The last row
/// opens the template manager.
Future<NoteTemplate?> showTemplatePicker(
  BuildContext context, {
  TemplateStore store = const TemplateStore(),
}) => showOwnSheet<NoteTemplate>(
  context: context,
  title: AppLocalizations.of(context)!.templates,
  builder: (_) => _Picker(store: store),
);

class _Picker extends StatefulWidget {
  const _Picker({required this.store});
  final TemplateStore store;

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  List<NoteTemplate>? _templates;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.store.templates();
    if (mounted) setState(() => _templates = list);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final list = _templates;
    if (list == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      children: [
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(l.templatesEmpty),
          ),
        for (final t in list)
          ListTile(
            minTileHeight: OwnShape.target,
            leading: const Icon(Icons.description_outlined),
            title: Text(t.name),
            subtitle: t.category.isEmpty ? null : Text(t.category),
            onTap: () => Navigator.of(context).pop(t),
          ),
        ListTile(
          minTileHeight: OwnShape.target,
          leading: const Icon(Icons.tune),
          title: Text(l.templatesManage),
          onTap: () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => TemplatesScreen(store: widget.store),
              ),
            );
            if (mounted) _load();
          },
        ),
      ],
    );
  }
}

/// Templates and the daily-note settings. Both stay on this device.
class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({this.store = const TemplateStore(), super.key});
  final TemplateStore store;

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  List<NoteTemplate> _templates = const [];
  DailyNoteConfig _daily = const DailyNoteConfig();
  bool _loaded = false;
  final _category = TextEditingController();
  final _pattern = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final templates = await widget.store.templates();
    final daily = await widget.store.daily();
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _daily = daily;
      _category.text = daily.category;
      _pattern.text = daily.titlePattern;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _category.dispose();
    _pattern.dispose();
    super.dispose();
  }

  Future<void> _saveTemplates(List<NoteTemplate> list) async {
    setState(() => _templates = list);
    try {
      await widget.store.saveTemplates(list);
    } on Object {
      if (mounted) {
        showOwnSnackBar(context, AppLocalizations.of(context)!.settingSaveFailed);
      }
    }
  }

  Future<void> _saveDaily(DailyNoteConfig c) async {
    setState(() => _daily = c);
    try {
      await widget.store.saveDaily(c);
    } on Object {
      if (mounted) {
        showOwnSnackBar(context, AppLocalizations.of(context)!.settingSaveFailed);
      }
    }
  }

  Future<void> _edit([NoteTemplate? existing]) async {
    final result = await Navigator.of(context).push<NoteTemplate?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _TemplateEditor(template: existing),
      ),
    );
    if (result == null) return;
    final list = [..._templates];
    final at = list.indexWhere((t) => t.id == result.id);
    at < 0 ? list.add(result) : list[at] = result;
    await _saveTemplates(list);
  }

  Future<void> _delete(NoteTemplate t) async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.templateDeleteConfirm(t.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _saveTemplates([..._templates]..removeWhere((x) => x.id == t.id));
    if (_daily.templateId == t.id) {
      await _saveDaily(_daily.copyWith(clearTemplate: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final plan = planDailyNote(_daily, DateTime.now());
    return Scaffold(
      appBar: AppBar(title: Text(l.templates)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: Text(l.templateNew),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(l.templatesDeviceOnly),
                ),
                if (_templates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l.templatesEmpty),
                  ),
                for (final t in _templates)
                  ListTile(
                    minTileHeight: OwnShape.target,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(t.name),
                    subtitle: t.category.isEmpty ? null : Text(t.category),
                    onTap: () => _edit(t),
                    trailing: IconButton(
                      tooltip: l.delete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(t),
                    ),
                  ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Semantics(
                    header: true,
                    child: Text(
                      l.dailyNote,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _category,
                        decoration: InputDecoration(
                          labelText: l.category,
                          prefixIcon: const Icon(Icons.folder_outlined),
                        ),
                        onChanged: (v) => _saveDaily(_daily.copyWith(category: v.trim())),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pattern,
                        decoration: InputDecoration(
                          labelText: l.dailyNotePattern,
                          prefixIcon: const Icon(Icons.event_outlined),
                        ),
                        onChanged: (v) => _saveDaily(
                          _daily.copyWith(
                            titlePattern: v.trim().isEmpty ? 'yyyy-MM-dd' : v.trim(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: _templates.any((t) => t.id == _daily.templateId)
                            ? _daily.templateId
                            : null,
                        decoration: InputDecoration(
                          labelText: l.dailyNoteTemplate,
                          prefixIcon: const Icon(Icons.description_outlined),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(l.dailyNoteNoTemplate),
                          ),
                          for (final t in _templates)
                            DropdownMenuItem<String?>(
                              value: t.id,
                              child: Text(t.name),
                            ),
                        ],
                        onChanged: (v) => _saveDaily(
                          v == null
                              ? _daily.copyWith(clearTemplate: true)
                              : _daily.copyWith(templateId: v),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l.dailyNotePreview(
                          plan.title,
                          plan.category.isEmpty ? l.uncategorised : plan.category,
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor({this.template});
  final NoteTemplate? template;

  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  late final _name = TextEditingController(text: widget.template?.name);
  late final _title = TextEditingController(text: widget.template?.title);
  late final _category = TextEditingController(text: widget.template?.category);
  late final _content = TextEditingController(text: widget.template?.content);

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    _category.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template == null ? l.templateNew : l.templateEdit),
        actions: [
          TextButton(
            onPressed: () {
              final name = _name.text.trim();
              if (name.isEmpty) return;
              Navigator.of(context).pop(
                NoteTemplate(
                  id: widget.template?.id ??
                      DateTime.now().microsecondsSinceEpoch.toRadixString(36),
                  name: name,
                  title: _title.text,
                  category: _category.text.trim(),
                  content: _content.text,
                ),
              );
            },
            child: Text(l.templateSave),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            autofocus: widget.template == null,
            decoration: InputDecoration(labelText: l.templateName),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: InputDecoration(labelText: l.title),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _category,
            decoration: InputDecoration(labelText: l.category),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            minLines: 8,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            style: monoTextStyle().copyWith(fontSize: 15),
            decoration: InputDecoration(
              labelText: l.content,
              helperText: l.templatePlaceholders('{{date}}, {{time}}, {{title}}'),
              helperMaxLines: 3,
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}
