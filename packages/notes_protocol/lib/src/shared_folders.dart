part of 'sharing.dart';

/// A readable note and the effective permission of the chosen DAV mount path.
final class SharedNote {
  const SharedNote({
    required this.fileId,
    required this.path,
    required this.writable,
  });
  final int fileId;
  final String path;
  final bool writable;
}

final _sharedNoteName = RegExp(r'\.(md|txt)$', caseSensitive: false);
final _attachmentFolder = RegExp(r'^\.attachments\.[0-9]+$');

extension SharedFolderDiscovery on SharingClient {
  /// Finishes the whole bounded traversal before returning a deletion census.
  /// A failed page, an unreadable note or a limit throws instead of returning
  /// a partial list that could remove locally cached notes.
  Future<List<SharedNote>> discoverSharedNotes(
    List<IncomingShare> shares, {
    required Future<void> Function() beforeRequest,
    Set<int> notesApiIds = const {},
    int maxFolders = 256,
    int maxRequests = 512,
    int maxEntries = 20000,
    int maxDepth = 32,
    int maxBytes = 33554432,
  }) async {
    if (maxFolders < 1 ||
        maxRequests < 1 ||
        maxEntries < 1 ||
        maxDepth < 0 ||
        maxBytes < 1) {
      throw ArgumentError('Invalid shared-folder limits');
    }
    if (shares.length > maxEntries) {
      throw const NotesProtocolException('shared_folder_limit');
    }
    final pending = <({String path, int id, int depth, Set<int> ancestors})>[];
    final visited = <String, int>{};
    final result = <int, SharedNote>{};
    var folders = 0, requests = 0, entries = 0, bytes = 0;

    Future<List<_DavEntry>> metadata(
      String path, {
      required bool children,
    }) async {
      if (++requests > maxRequests) {
        throw const NotesProtocolException('shared_folder_limit');
      }
      await beforeRequest();
      final request = _dav(path);
      final response = await _send(
        'PROPFIND',
        request,
        headers: {
          'Depth': children ? '1' : '0',
          'Content-Type': 'application/xml',
        },
        body: _folderProperties,
      );
      if (response.statusCode != 207) {
        throw NotesHttpException(response.statusCode, mayHaveApplied: false);
      }
      bytes += response.bodyBytes.length;
      if (bytes > maxBytes) {
        throw const NotesProtocolException('shared_folder_limit');
      }
      final listing = _readFolder(response.bodyBytes, request, path);
      entries += listing.length;
      if (entries > maxEntries) {
        throw const NotesProtocolException('shared_folder_limit');
      }
      return listing;
    }

    void accept(SharedNote note) {
      final old = result[note.fileId];
      if (old == null || (!old.writable && note.writable)) {
        result[note.fileId] = note;
      }
    }

    final directPaths = <String, int>{};
    for (final share in shares) {
      if (share.isFolder) {
        pending.add((
          path: share.path,
          id: share.fileId,
          depth: 0,
          ancestors: const {},
        ));
      } else if (_sharedNoteName.hasMatch(share.path) &&
          !notesApiIds.contains(share.fileId)) {
        final previous = directPaths[share.path];
        if (previous != null) {
          if (previous != share.fileId) {
            throw const NotesProtocolException('inconsistent_share_id');
          }
          continue;
        }
        directPaths[share.path] = share.fileId;
        final listing = await metadata(share.path, children: false);
        final current = listing.singleOrNull;
        if (current == null ||
            current.path != share.path ||
            current.id != share.fileId ||
            current.folder ||
            !current.readable) {
          throw const NotesProtocolException('shared_file_changed');
        }
        accept(
          SharedNote(
            fileId: share.fileId,
            path: share.path,
            writable: current.writable,
          ),
        );
      }
    }

    while (pending.isNotEmpty) {
      final folder = pending.removeLast();
      final prior = visited[folder.path];
      if (prior != null) {
        if (prior != folder.id) {
          throw const NotesProtocolException('inconsistent_share_id');
        }
        continue;
      }
      if (++folders > maxFolders || folder.depth > maxDepth) {
        throw const NotesProtocolException('shared_folder_limit');
      }
      if (folder.ancestors.contains(folder.id)) {
        throw const NotesProtocolException('cyclic_shared_folder');
      }
      visited[folder.path] = folder.id;
      final listing = await metadata(folder.path, children: true);
      final self = listing
          .where((entry) => entry.path == folder.path)
          .singleOrNull;
      if (self == null ||
          !self.folder ||
          self.id != folder.id ||
          !self.readable) {
        throw const NotesProtocolException('shared_folder_changed');
      }
      for (final entry in listing) {
        if (entry.path == folder.path) continue;
        if (entry.folder) {
          if (_attachmentFolder.hasMatch(entry.path.split('/').last)) continue;
          if (!entry.readable) {
            throw const NotesProtocolException('unreadable_shared_folder');
          }
          pending.add((
            path: entry.path,
            id: entry.id,
            depth: folder.depth + 1,
            ancestors: {...folder.ancestors, folder.id},
          ));
        } else if (_sharedNoteName.hasMatch(entry.path) &&
            !notesApiIds.contains(entry.id)) {
          if (!entry.readable) {
            throw const NotesProtocolException('unreadable_shared_note');
          }
          accept(
            SharedNote(
              fileId: entry.id,
              path: entry.path,
              writable: entry.writable,
            ),
          );
        }
      }
    }
    return List.unmodifiable(result.values);
  }

  List<_DavEntry> _readFolder(List<int> bytes, Uri request, String parent) {
    final XmlDocument document;
    try {
      final text = utf8.decode(bytes);
      if (RegExp(r'<!DOCTYPE\b', caseSensitive: false).hasMatch(text)) {
        throw const NotesProtocolException('invalid_dav_listing');
      }
      document = XmlDocument.parse(text);
    } on FormatException {
      throw const NotesProtocolException('invalid_dav_listing');
    } on XmlException {
      throw const NotesProtocolException('invalid_dav_listing');
    }
    final root = document.rootElement;
    if (root.localName != 'multistatus' || root.namespaceUri != 'DAV:') {
      throw const NotesProtocolException('invalid_dav_listing');
    }
    final entries = <_DavEntry>[];
    final paths = <String>{};
    for (final node in root.childElements) {
      if (node.localName == 'responsedescription' &&
          node.namespaceUri == 'DAV:') {
        continue;
      }
      if (node.localName != 'response' || node.namespaceUri != 'DAV:') {
        throw const NotesProtocolException('invalid_dav_listing');
      }
      final hrefs = node.findElements('href', namespaceUri: 'DAV:').toList();
      if (hrefs.length != 1) {
        throw const NotesProtocolException('invalid_dav_href');
      }
      final path = _listedPath(hrefs.single.innerText.trim(), request, parent);
      if (!paths.add(path)) {
        throw const NotesProtocolException('duplicate_dav_path');
      }
      final responseStatus = node.getElement('status', namespaceUri: 'DAV:');
      if (responseStatus != null &&
          !_successfulDavStatus(responseStatus.innerText)) {
        throw const NotesProtocolException('incomplete_dav_listing');
      }
      final properties = <(String?, String), XmlElement>{};
      for (final stat in node.findElements('propstat', namespaceUri: 'DAV:')) {
        final status = stat.getElement('status', namespaceUri: 'DAV:');
        if (status == null) {
          throw const NotesProtocolException('invalid_dav_listing');
        }
        if (!_successfulDavStatus(status.innerText)) continue;
        final prop = stat.getElement('prop', namespaceUri: 'DAV:');
        if (prop == null) {
          throw const NotesProtocolException('invalid_dav_listing');
        }
        for (final value in prop.childElements) {
          final key = (value.namespaceUri, value.localName);
          if (properties.containsKey(key)) {
            throw const NotesProtocolException('duplicate_dav_property');
          }
          properties[key] = value;
        }
      }
      final type = properties[('DAV:', 'resourcetype')];
      final id = properties[('http://owncloud.org/ns', 'fileid')]?.innerText
          .trim();
      final permissions = properties[('http://owncloud.org/ns', 'permissions')]
          ?.innerText
          .trim();
      if (type == null ||
          id == null ||
          permissions == null ||
          !RegExp(r'^[0-9]+$').hasMatch(id)) {
        throw const NotesProtocolException('incomplete_dav_listing');
      }
      final folder = type.childElements.any(
        (e) => e.localName == 'collection' && e.namespaceUri == 'DAV:',
      );
      if (type.childElements.any(
        (e) => e.localName != 'collection' || e.namespaceUri != 'DAV:',
      )) {
        throw const NotesProtocolException('invalid_dav_resource_type');
      }
      entries.add(
        _DavEntry(
          path,
          noteId(int.tryParse(id)),
          folder,
          permissions.contains('G'),
          permissions.contains('W'),
        ),
      );
    }
    return entries;
  }

  String _listedPath(String href, Uri request, String parent) {
    try {
      if (RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(href)) {
        throw const FormatException();
      }
      final uri = Uri.parse(href);
      if (uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          (uri.hasAuthority &&
              (uri.scheme != request.scheme ||
                  uri.host != request.host ||
                  uri.port != request.port)) ||
          (!uri.hasAuthority && (uri.hasScheme || !uri.path.startsWith('/')))) {
        throw const FormatException();
      }
      final segments = uri.pathSegments.toList();
      if (segments.isNotEmpty && segments.last.isEmpty) segments.removeLast();
      if (segments.any(
        (s) =>
            s.isEmpty ||
            s == '.' ||
            s == '..' ||
            s.contains('/') ||
            s.contains('\\') ||
            s.runes.any((c) => c < 32 || c == 127),
      )) {
        throw const FormatException();
      }
      final prefix = base.davFile(loginName, []).pathSegments;
      if (segments.length < prefix.length ||
          !Iterable<int>.generate(
            prefix.length,
          ).every((i) => segments[i] == prefix[i])) {
        throw const FormatException();
      }
      final relative = segments.skip(prefix.length).toList();
      final parentParts = parent.split('/').where((s) => s.isNotEmpty).toList();
      if (relative.length < parentParts.length ||
          relative.length > parentParts.length + 1 ||
          !Iterable<int>.generate(
            parentParts.length,
          ).every((i) => relative[i] == parentParts[i])) {
        throw const FormatException();
      }
      return '/${relative.join('/')}';
    } on FormatException {
      throw const NotesProtocolException('invalid_dav_href');
    }
  }
}

bool _successfulDavStatus(String status) =>
    RegExp(r'^HTTP/\d+(?:\.\d+)? 2\d\d(?: |$)').hasMatch(status.trim());

final _folderProperties = utf8.encode(
  '<?xml version="1.0"?><d:propfind xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns">'
  '<d:prop><d:resourcetype/><oc:fileid/><oc:permissions/></d:prop></d:propfind>',
);

final class _DavEntry {
  const _DavEntry(
    this.path,
    this.id,
    this.folder,
    this.readable,
    this.writable,
  );
  final String path;
  final int id;
  final bool folder;
  final bool readable;
  final bool writable;
}
