import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/markdown/markdown_document.dart';
import 'suggestion_model.dart';
import 'suggestion_source.dart';

/// A built-in `/` command.
final class LocalCommand {
  const LocalCommand(this.item, [this.keywords = const []]);
  final SuggestionItem item;
  final List<String> keywords;
}

/// Follows the caret and keeps the rows of the suggestion popup. Server
/// answers for an older query are dropped; a failing server only fills the
/// popup with an error row, the writing is never blocked.
class SuggestionController extends ChangeNotifier {
  SuggestionController({
    required this.source,
    required this.commands,
    required this.czech,
    this.debounce = const Duration(milliseconds: 250),
  });

  /// Asked lazily, once per use; null when no account can be asked.
  final Future<SuggestionSource?> Function() source;
  /// Replaced when the language changes.
  List<LocalCommand> commands;
  bool czech;
  final Duration debounce;

  /// Offset of a `:` the Insert menu just put in; its list opens without
  /// waiting for letters.
  int? eagerStart;
  SuggestionState? _state;
  int _selected = 0;
  int? _dismissedAt;
  int _generation = 0;
  Timer? _timer;
  List<ReferenceProvider>? _providers;
  bool _closed = false;

  SuggestionState? get state => _state;
  int get selected => _selected;
  bool get isOpen {
    final s = _state;
    return s != null && (s.loading || s.error || s.items.isNotEmpty);
  }

  SuggestionItem? get current {
    final s = _state;
    if (s == null || s.items.isEmpty) return null;
    return s.items[_selected.clamp(0, s.items.length - 1)];
  }

  /// Called after every edit and selection change.
  void update(TextEditingValue value, MarkdownDocument doc) {
    final query = detectSuggestion(value, doc, eagerStart: eagerStart);
    if (query == null) {
      _clear();
      return;
    }
    if (_dismissedAt == query.start) return;
    _dismissedAt = null;
    final previous = _state?.query;
    if (previous == query) return;
    _generation++;
    _timer?.cancel();
    switch (query.trigger) {
      case SuggestTrigger.emoji:
        _set(SuggestionState(query: query, items: searchEmoji(query.query, czech: czech)));
      case SuggestTrigger.command:
        _set(SuggestionState(query: query, items: _commandItems(query.query)));
        _loadProviders(query, _generation);
      case SuggestTrigger.mention:
        _set(SuggestionState(query: query, loading: true));
        final generation = _generation;
        _timer = Timer(debounce, () => _fetchUsers(query, generation));
    }
  }

  void _set(SuggestionState state) {
    final sameQuery = _state?.query == state.query;
    _state = state;
    if (!sameQuery || _selected >= state.items.length) _selected = 0;
    if (!_closed) notifyListeners();
  }

  void _clear() {
    _generation++;
    _timer?.cancel();
    _dismissedAt = null;
    if (_state != null) {
      _state = null;
      _selected = 0;
      if (!_closed) notifyListeners();
    }
  }

  /// Closes the popup and keeps the typed text; it stays closed for this
  /// trigger until the caret leaves it.
  void dismiss() {
    final s = _state;
    if (s == null) return;
    _dismissedAt = s.query.start;
    _generation++;
    _timer?.cancel();
    _state = null;
    _selected = 0;
    if (!_closed) notifyListeners();
  }

  void move(int by) {
    final s = _state;
    if (s == null || s.items.isEmpty) return;
    _selected = (_selected + by).clamp(0, s.items.length - 1);
    notifyListeners();
  }

  void select(int index) {
    _selected = index;
    notifyListeners();
  }

  List<SuggestionItem> _commandItems(String query) {
    final q = foldForSearch(query);
    final local = [
      for (final c in commands)
        if (q.isEmpty ||
            foldForSearch(c.item.title).contains(q) ||
            c.keywords.any((k) => foldForSearch(k).startsWith(q)))
          c.item,
    ];
    final providers = [
      for (final p in _providers ?? const <ReferenceProvider>[])
        if (q.isEmpty || foldForSearch(p.title).contains(q))
          SuggestionItem(
            id: 'ref:${p.id}',
            title: p.title,
            icon: Icons.travel_explore_outlined,
            action: SuggestionAction.reference,
          ),
    ];
    return [...local, ...providers];
  }

  Future<void> _loadProviders(SuggestQuery query, int generation) async {
    if (_providers != null) return;
    try {
      final source = await this.source();
      if (source == null) return;
      final list = await source.providers();
      _providers = list;
    } on Object {
      _providers = const [];
    }
    if (_closed || generation != _generation) return;
    final s = _state;
    if (s != null && s.query == query) {
      _set(SuggestionState(query: query, items: _commandItems(query.query)));
    }
  }

  Future<void> _fetchUsers(SuggestQuery query, int generation) async {
    try {
      final source = await this.source();
      if (source == null) throw StateError('no_source');
      final users = await source.users(query.query);
      if (_closed || generation != _generation) return;
      _set(
        SuggestionState(
          query: query,
          items: [
            for (final u in users)
              SuggestionItem(
                id: 'user:${u.id}',
                glyph: u.label.isEmpty
                    ? '@'
                    : String.fromCharCode(u.label.runes.first).toUpperCase(),
                title: u.label,
                subtitle: u.id,
                insert: '${mentionMarkdown(u)} ',
              ),
          ],
        ),
      );
    } on Object {
      if (_closed || generation != _generation) return;
      _set(SuggestionState(query: query, error: true));
    }
  }

  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
    super.dispose();
  }
}
