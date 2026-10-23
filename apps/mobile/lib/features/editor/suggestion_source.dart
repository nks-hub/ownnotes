import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import '../../data/runtime.dart';

/// A user the `@` suggestions offer.
final class MentionCandidate {
  const MentionCandidate({required this.id, required this.label, this.subline});
  final String id;
  final String label;
  final String? subline;
}

/// A reference provider the server advertises for the smart picker, with the
/// search provider that answers it.
final class ReferenceProvider {
  const ReferenceProvider({
    required this.id,
    required this.title,
    required this.searchId,
  });
  final String id;
  final String title;
  final String searchId;
}

final class ReferenceResult {
  const ReferenceResult({required this.title, required this.url, this.subline});
  final String title;
  final String? subline;
  final Uri url;
}

/// The Nextcloud endpoints behind the typing suggestions.
abstract interface class SuggestionSource {
  Future<List<MentionCandidate>> users(String query);

  /// Providers that can actually be searched; others are left out so the
  /// picker never lists an entry that does nothing.
  Future<List<ReferenceProvider>> providers();
  Future<List<ReferenceResult>> search(ReferenceProvider provider, String term);
  void close();
}

/// Builds the source of an account. Tests replace the provider.
typedef SuggestionSourceFactory = Future<SuggestionSource> Function(Account a);

final suggestionSourceFactoryProvider = Provider<SuggestionSourceFactory>((
  ref,
) {
  final runtime = ref.watch(runtimeProvider);
  return (account) async {
    final password = await runtime.vault.read(account.credentialRef);
    if (password == null) throw StateError('reauth_required');
    return NextcloudSuggestionSource(
      base: ServerBase.parse(account.server),
      client: http.Client(),
      loginName: account.loginName,
      appPassword: password,
    );
  };
});

/// Core autocomplete (`/ocs/v2.php/core/autocomplete/get`), reference
/// providers (`/ocs/v2.php/references/providers`) and the unified search of a
/// provider. The credentials are the account's app password, sent only to its
/// own server.
final class NextcloudSuggestionSource implements SuggestionSource {
  NextcloudSuggestionSource({
    required this.base,
    required this.client,
    required this.loginName,
    required String appPassword,
    this.timeout = const Duration(seconds: 10),
  }) : _authorization =
           'Basic ${base64Encode(utf8.encode('$loginName:$appPassword'))}';

  final ServerBase base;
  final http.Client client;
  final String loginName;
  final Duration timeout;
  final String _authorization;
  List<ReferenceProvider>? _providers;

  Future<Object?> _ocs(List<String> segments, Map<String, Object> query) async {
    final uri = base.uri.replace(
      pathSegments: [
        ...base.uri.pathSegments.where((s) => s.isNotEmpty),
        'ocs',
        'v2.php',
        ...segments,
      ],
      queryParameters: {
        ...query.map(
          (k, v) => MapEntry(k, v is List ? v.map((e) => '$e').toList() : '$v'),
        ),
        'format': 'json',
      },
    );
    final response = await client
        .get(
          uri,
          headers: {
            'Authorization': _authorization,
            'OCS-APIRequest': 'true',
            'Accept': 'application/json',
          },
        )
        .timeout(timeout);
    if (response.statusCode != 200 || response.bodyBytes.length > 1 << 20) {
      throw const NotesProtocolException('suggestion_request_failed');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body case {'ocs': {'data': final data}}) return data;
    throw const NotesProtocolException('invalid_ocs');
  }

  @override
  Future<List<MentionCandidate>> users(String query) async {
    final data = await _ocs(
      ['core', 'autocomplete', 'get'],
      {
        'search': query,
        'itemType': '',
        'itemId': '',
        'shareTypes[]': ['0'],
        'limit': 10,
      },
    );
    return [
      if (data is List)
        for (final u in data)
          if (u case {
            'id': final String id,
            'label': final String label,
            'source': 'users',
          })
            MentionCandidate(
              id: id,
              label: label,
              subline:
                  u['subline'] is String && (u['subline']! as String).isNotEmpty
                  ? u['subline']! as String
                  : null,
            ),
    ];
  }

  @override
  Future<List<ReferenceProvider>> providers() async {
    final known = _providers;
    if (known != null) return known;
    final references = await _ocs(['references', 'providers'], {});
    final searchable = <String>{};
    try {
      final search = await _ocs(['search', 'providers'], {});
      if (search is List) {
        for (final p in search) {
          if (p case {'id': final String id}) searchable.add(id);
        }
      }
    } on Object {
      // Without the search list nothing can be picked.
    }
    final out = <ReferenceProvider>[];
    if (references is List) {
      for (final p in references) {
        if (p case {'id': final String id, 'title': final String title}) {
          final ids = [
            if (p['search_providers_ids'] is List)
              ...(p['search_providers_ids']! as List).whereType<String>(),
            id,
          ];
          final searchId = ids.where(searchable.contains).firstOrNull;
          if (searchId != null) {
            out.add(
              ReferenceProvider(id: id, title: title, searchId: searchId),
            );
          }
        }
      }
    }
    return _providers = List.unmodifiable(out);
  }

  @override
  Future<List<ReferenceResult>> search(
    ReferenceProvider provider,
    String term,
  ) async {
    final data = await _ocs(
      ['search', 'providers', provider.searchId, 'search'],
      {'term': term, 'limit': 10},
    );
    final entries = data is Map ? data['entries'] : null;
    final out = <ReferenceResult>[];
    if (entries is List) {
      for (final e in entries) {
        if (e case {
          'title': final String title,
          'resourceUrl': final String url,
        }) {
          final uri = Uri.tryParse(url);
          if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
            continue;
          }
          out.add(
            ReferenceResult(
              title: title,
              url: uri,
              subline:
                  e['subline'] is String && (e['subline']! as String).isNotEmpty
                  ? e['subline']! as String
                  : null,
            ),
          );
        }
      }
    }
    return out;
  }

  @override
  void close() => client.close();
}

/// Markdown a mention is saved as, the same as Nextcloud Text writes it.
String mentionMarkdown(MentionCandidate user) {
  final label = user.label.replaceAll(RegExp(r'[\[\]\\]'), '');
  // Text writes the id as it is; only characters that end a link are encoded.
  final id = RegExp(r'[\s()<>]').hasMatch(user.id)
      ? Uri.encodeComponent(user.id)
      : user.id;
  return '@[$label](mention://user/$id)';
}

/// Plain Markdown link of a picked reference.
String referenceMarkdown(ReferenceResult r) {
  final title = r.title.replaceAll(RegExp(r'[\[\]\\]'), '').trim();
  return '[${title.isEmpty ? r.url : title}](${r.url})';
}
