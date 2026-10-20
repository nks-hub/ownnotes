import 'dart:async';
import 'package:flutter/material.dart';
import '../../design/design.dart';
import '../../l10n/app_localizations.dart';
import 'suggestion_source.dart';

IconData providerIcon(String id) => switch (id) {
  'files' => Icons.folder_outlined,
  'notes' => Icons.sticky_note_2_outlined,
  'spreed' => Icons.chat_bubble_outline,
  'deck' => Icons.view_kanban_outlined,
  'calendar' => Icons.event_outlined,
  _ => Icons.link,
};

/// Smart picker: choose a reference provider, search it and get back a plain
/// Markdown link, or null when dismissed. Only providers the server
/// advertises and can search are listed. [providerId] skips the first step.
Future<String?> showReferencePicker(
  BuildContext context, {
  required Future<SuggestionSource?> Function() source,
  String? providerId,
  String initialTerm = '',
}) => showOwnSheet<String>(
  context: context,
  title: AppLocalizations.of(context)!.smartPicker,
  fullScreen: true,
  builder: (_) => _Picker(
    source: source,
    providerId: providerId,
    initialTerm: initialTerm,
  ),
);

class _Picker extends StatefulWidget {
  const _Picker({
    required this.source,
    required this.providerId,
    required this.initialTerm,
  });
  final Future<SuggestionSource?> Function() source;
  final String? providerId;
  final String initialTerm;

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  late final TextEditingController _term;
  SuggestionSource? _source;
  List<ReferenceProvider>? _providers;
  ReferenceProvider? _provider;
  List<ReferenceResult> _results = const [];
  bool _failed = false;
  bool _busy = true;
  Timer? _timer;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _term = TextEditingController(text: widget.initialTerm);
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    try {
      final source = await widget.source();
      if (source == null) throw StateError('no_source');
      _source = source;
      final list = await source.providers();
      if (!mounted) return;
      final chosen = list.where((p) => p.id == widget.providerId).firstOrNull;
      setState(() {
        _providers = list;
        _provider = chosen;
        _busy = false;
      });
      if (chosen != null) _search();
    } on Object {
      if (mounted) {
        setState(() {
          _failed = true;
          _busy = false;
        });
      }
    }
  }

  void _search() {
    final provider = _provider, source = _source;
    if (provider == null || source == null) return;
    final generation = ++_generation;
    _timer?.cancel();
    setState(() {
      _busy = true;
      _failed = false;
    });
    _timer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final found = await source.search(provider, _term.text.trim());
        if (!mounted || generation != _generation) return;
        setState(() {
          _results = found;
          _busy = false;
        });
      } on Object {
        if (!mounted || generation != _generation) return;
        setState(() {
          _failed = true;
          _busy = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _term.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (_failed && _provider == null) {
      return OwnBanner(tone: OwnTone.error, message: l.suggestError);
    }
    if (_provider == null) {
      final list = _providers;
      if (_busy || list == null) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (list.isEmpty) {
        return OwnBanner(tone: OwnTone.info, message: l.smartPickerNone);
      }
      return Column(
        children: [
          for (final p in list)
            ListTile(
              minTileHeight: OwnShape.target,
              leading: Icon(providerIcon(p.id)),
              title: Text(p.title),
              onTap: () {
                setState(() => _provider = p);
                _search();
              },
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _term,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: Icon(providerIcon(_provider!.id)),
            hintText: _provider!.title,
          ),
          onChanged: (_) => _search(),
        ),
        const SizedBox(height: 8),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_failed)
          OwnBanner(tone: OwnTone.error, message: l.suggestError)
        else if (_results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.noMatches),
          )
        else
          for (final r in _results)
            ListTile(
              minTileHeight: OwnShape.target,
              leading: const Icon(Icons.link),
              title: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: r.subline == null
                  ? null
                  : Text(r.subline!, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.of(context).pop(referenceMarkdown(r)),
            ),
      ],
    );
  }
}
