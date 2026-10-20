import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../note_rows.dart';
import '../search/search_filters.dart';

/// A named filter definition kept on this device only; the server never
/// sees it (spec 4.5).
class SavedView {
  const SavedView({
    required this.id,
    required this.name,
    required this.scope,
    this.category = '',
    this.filters = NoteFilters.none,
    this.query = '',
  });

  final String id;
  final String name;
  final NoteScope scope;
  final String category;
  final NoteFilters filters;
  final String query;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'scope': scope.name,
    'category': category,
    'filters': filters.toJson(),
    'query': query,
  };

  static SavedView? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], name = json['name'];
    if (id is! String || name is! String) return null;
    final scope = NoteScope.values
        .where((s) => s.name == json['scope'])
        .firstOrNull;
    if (scope == null) return null;
    final filters = json['filters'];
    return SavedView(
      id: id,
      name: name,
      scope: scope,
      category: json['category'] is String ? json['category'] as String : '',
      filters: filters is Map
          ? NoteFilters.fromJson(filters.cast<String, Object?>())
          : NoteFilters.none,
      query: json['query'] is String ? json['query'] as String : '',
    );
  }

  /// Where a note created in this view goes, or null when the view does not
  /// name one category and the user has to be asked (spec 4.2).
  String? get createCategory => scope == NoteScope.category ? category : null;
}

/// Saved views per account in the device preferences.
class SavedViewStore {
  const SavedViewStore();

  static String _key(String accountId) => 'savedViews.$accountId';

  Future<List<SavedView>> load(String accountId) async {
    try {
      final raw = await SharedPreferencesAsync().getString(_key(accountId));
      if (raw == null) return const [];
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [for (final item in list) ?SavedView.fromJson(item)];
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(String accountId, List<SavedView> views) async {
    try {
      await SharedPreferencesAsync().setString(
        _key(accountId),
        jsonEncode([for (final v in views) v.toJson()]),
      );
    } catch (_) {
      // A view that cannot be stored is simply gone after a restart.
    }
  }
}
