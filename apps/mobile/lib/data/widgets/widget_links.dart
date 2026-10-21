/// Deep links a home-screen widget opens: `ownnotes://new/<account>?kind=`,
/// `ownnotes://note/<account>/<note>`, `ownnotes://search` and `ownnotes://open`.
/// The pre-redesign forms `ownnotes://new` and `ownnotes://note/<note>` stay valid.
library;

enum WidgetNewKind { note, checklist, daily, template }

sealed class WidgetLink {
  const WidgetLink();
}

/// Open the app without a destination (used by the locked widget).
final class OpenAppLink extends WidgetLink {
  const OpenAppLink();
}

/// Open the search field (launcher shortcut, quick action).
final class SearchLink extends WidgetLink {
  const SearchLink();
}

final class OpenNoteLink extends WidgetLink {
  const OpenNoteLink(this.noteId, {this.accountId});
  final String noteId;

  /// Null for a link written before widgets carried an account.
  final String? accountId;
}

final class NewNoteLink extends WidgetLink {
  const NewNoteLink({this.accountId, this.kind = WidgetNewKind.note});
  final String? accountId;
  final WidgetNewKind kind;
}

/// Reads a widget link; null when [uri] is not one.
WidgetLink? parseWidgetLink(Uri? uri) {
  if (uri == null || uri.scheme != 'ownnotes') return null;
  final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  switch (uri.host) {
    case 'open':
      return const OpenAppLink();
    case 'search':
      return const SearchLink();
    case 'new':
      final kind = WidgetNewKind.values.asNameMap()[uri.queryParameters['kind']];
      return NewNoteLink(
        accountId: parts.firstOrNull,
        kind: kind ?? WidgetNewKind.note,
      );
    case 'note':
      return switch (parts.length) {
        1 => OpenNoteLink(parts[0]),
        2 => OpenNoteLink(parts[1], accountId: parts[0]),
        _ => null,
      };
  }
  return null;
}
