import '../../core/markdown/markdown_document.dart';

/// A piece of the preview with the exact source range it was read from, so a
/// tap or a task toggle never has to guess which of several equal texts was
/// meant.
sealed class PreviewSegment {
  const PreviewSegment(this.range);
  final SourceRange range;
}

/// Ordinary Markdown blocks (paragraph, list, quote, code, heading, rule).
final class MarkdownSegment extends PreviewSegment {
  const MarkdownSegment(super.range);
}

final class TableSegment extends PreviewSegment {
  const TableSegment(super.range);
}

enum CalloutKind { info, warn, error, success }

/// `::: info` ... `:::` as Nextcloud Text writes it.
final class CalloutSegment extends PreviewSegment {
  const CalloutSegment(super.range, this.kind, this.heading, this.children);
  final CalloutKind kind;
  final String heading;
  final List<PreviewSegment> children;
}

/// `<details><summary>..</summary>..</details>`.
final class DetailsSegment extends PreviewSegment {
  const DetailsSegment(super.range, this.summary, this.open, this.children);

  /// Plain text of the summary; empty when the element has none.
  final String summary;
  final bool open;
  final List<PreviewSegment> children;
}

final _calloutOpen = RegExp(
  r'^:::[ \t]*(info|warn|warning|error|success)[ \t]*(.*?)[ \t]*$',
);
final _calloutClose = RegExp(r'^:::[ \t]*$');
final _detailsOpen = RegExp(r'^[ \t]*<details(\s+open)?\s*>', caseSensitive: false);
final _fence = RegExp(r'^(`{3,}|~{3,})');
final _summary = RegExp(
  r'<summary[^>]*>(.*?)</summary>',
  caseSensitive: false,
  dotAll: true,
);
final _tags = RegExp(r'<[^>]+>');

/// Splits [text] into preview segments. Callouts and details become segments
/// holding their own children; everything else follows the block structure of
/// [MarkdownDocument]. An opening line without its closing line stays plain
/// text, so unsupported or unfinished syntax is shown as written.
List<PreviewSegment> buildPreviewSegments(String text, {int depth = 0}) =>
    _build(text, 0, depth);

List<PreviewSegment> _build(String text, int base, int depth) {
  final out = <PreviewSegment>[];
  final lines = <(int, int)>[];
  var at = 0;
  while (at <= text.length) {
    final end = text.indexOf('\n', at);
    final stop = end < 0 ? text.length : end;
    lines.add((at, stop));
    if (end < 0) break;
    at = end + 1;
  }
  String line(int i) {
    final raw = text.substring(lines[i].$1, lines[i].$2);
    return raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw;
  }

  var plainFrom = 0;
  void flushPlain(int until) {
    if (until <= plainFrom) return;
    final chunk = text.substring(plainFrom, until);
    if (chunk.trim().isEmpty) return;
    final doc = MarkdownDocument.parse(chunk);
    for (final b in doc.blocks) {
      final range = SourceRange(
        base + plainFrom + b.range.start,
        base + plainFrom + b.range.end,
      );
      out.add(
        b.kind == MdBlockKind.table
            ? TableSegment(range)
            : MarkdownSegment(range),
      );
    }
  }

  String? fence;
  var i = 0;
  while (i < lines.length) {
    final current = line(i);
    final f = _fence.firstMatch(current.trimLeft());
    if (fence != null) {
      if (f != null && f[1]![0] == fence[0] && f[1]!.length >= fence.length) {
        fence = null;
      }
      i++;
      continue;
    }
    if (f != null) {
      fence = f[1];
      i++;
      continue;
    }
    if (depth < 3) {
      final callout = _calloutOpen.firstMatch(current);
      if (callout != null) {
        var close = -1;
        String? inner;
        for (var j = i + 1; j < lines.length; j++) {
          final l = line(j);
          final jf = _fence.firstMatch(l.trimLeft());
          if (inner != null) {
            if (jf != null && jf[1]![0] == inner[0] && jf[1]!.length >= inner.length) {
              inner = null;
            }
            continue;
          }
          if (jf != null) {
            inner = jf[1];
            continue;
          }
          if (_calloutClose.hasMatch(l)) {
            close = j;
            break;
          }
        }
        if (close > 0) {
          flushPlain(lines[i].$1);
          final bodyStart = lines[i].$2 + 1;
          final bodyEnd = lines[close].$1;
          final kind = switch (callout[1]) {
            'warn' || 'warning' => CalloutKind.warn,
            'error' => CalloutKind.error,
            'success' => CalloutKind.success,
            _ => CalloutKind.info,
          };
          out.add(
            CalloutSegment(
              SourceRange(base + lines[i].$1, base + lines[close].$2),
              kind,
              callout[2] ?? '',
              bodyStart >= bodyEnd
                  ? const []
                  : _build(
                      text.substring(bodyStart, bodyEnd),
                      base + bodyStart,
                      depth + 1,
                    ),
            ),
          );
          plainFrom = i = close + 1;
          if (plainFrom < lines.length) plainFrom = lines[plainFrom].$1;
          if (i >= lines.length) plainFrom = text.length;
          continue;
        }
      }
      final details = _detailsOpen.firstMatch(current);
      if (details != null) {
        var close = -1;
        for (var j = i; j < lines.length; j++) {
          if (line(j).toLowerCase().contains('</details>')) {
            close = j;
            break;
          }
        }
        if (close >= 0) {
          flushPlain(lines[i].$1);
          final regionStart = lines[i].$1, regionEnd = lines[close].$2;
          final region = text.substring(regionStart, regionEnd);
          final opening = _detailsOpen.firstMatch(region)!;
          final sum = _summary.firstMatch(region);
          final bodyFrom = sum?.end ?? opening.end;
          final bodyTo = region.toLowerCase().lastIndexOf('</details>');
          final body = bodyTo > bodyFrom ? region.substring(bodyFrom, bodyTo) : '';
          out.add(
            DetailsSegment(
              SourceRange(base + regionStart, base + regionEnd),
              sum == null
                  ? ''
                  : sum[1]!.replaceAll(_tags, '').replaceAll(RegExp(r'\s+'), ' ').trim(),
              details[1] != null,
              body.trim().isEmpty
                  ? const []
                  : _build(body, base + regionStart + bodyFrom, depth + 1),
            ),
          );
          i = close + 1;
          plainFrom = i < lines.length ? lines[i].$1 : text.length;
          continue;
        }
      }
    }
    i++;
  }
  flushPlain(text.length);
  return out;
}
