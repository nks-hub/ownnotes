import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import '../../core/markdown/live_styling.dart';
import '../../core/markdown/markdown_document.dart';
import '../../design/design.dart';
import '../../l10n/app_localizations.dart';
import 'preview_segments.dart';
import 'preview_image.dart';

/// Inline `@[Name](mention://user/id)` as Nextcloud Text writes it.
class MentionSyntax extends md.InlineSyntax {
  MentionSyntax() : super(r'@\[([^\]]+)\]\(mention://user/([^)\s]+)\)');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(
      md.Element.text('mention', match[1]!)..attributes['id'] = match[2]!,
    );
    return true;
  }
}

/// Link to a file in the note's `.attachments.<id>/` folder (images are left
/// to the image syntax, which starts earlier at the `!`).
class AttachmentSyntax extends md.InlineSyntax {
  AttachmentSyntax() : super(r'\[([^\]]*)\]\((\.attachments\.[^)\s]+)\)');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(
      md.Element.text('attachment', match[1]!)..attributes['path'] = match[2]!,
    );
    return true;
  }
}

/// Rounded inline chip with a person symbol and the name. It wraps its text
/// instead of clipping it.
class MentionChip extends StatelessWidget {
  const MentionChip(this.name, {super.key});
  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.own;
    return Semantics(
      label: AppLocalizations.of(context)!.mentionLabel(name),
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - 64,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.selected,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.person_outline,
                    size: 16,
                    color: colors.onSelected,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: colors.onSelected,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MentionBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => MentionChip(element.textContent);
}

/// File name and type of an attachment link; opening it is the job of the
/// attachment surface, because the file needs the account's credentials.
class AttachmentChip extends StatelessWidget {
  const AttachmentChip(this.path, {super.key});
  final String path;

  @override
  Widget build(BuildContext context) {
    final colors = context.own;
    var decoded = path;
    try {
      decoded = Uri.decodeFull(path);
    } on ArgumentError {
      // Keep the raw destination.
    }
    final name = decoded.split('/').last;
    final dot = name.lastIndexOf('.');
    final type = dot > 0 && dot < name.length - 1
        ? name.substring(dot + 1).toUpperCase()
        : null;
    return Semantics(
      label: AppLocalizations.of(context)!.attachmentLabel(name),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.raised,
          border: Border.all(color: colors.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.attach_file, size: 16, color: colors.textSecondary),
              const SizedBox(width: 4),
              Flexible(child: Text(type == null ? name : '$name · $type')),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => AttachmentChip(element.attributes['path'] ?? element.textContent);
}

/// Source range of what the segment tag was built from, found in a hit test.
class _SegmentTag {
  const _SegmentTag(this.segment);
  final PreviewSegment segment;
}

typedef AttachmentLoader = Future<List<int>> Function(String path);

/// Reading view of a note: Text-compatible Markdown with callouts, details,
/// tables, mentions and attachments, and no request to any third party.
///
/// A short tap on text calls [onEditAt] with the offset of that text in the
/// source; a drag scrolls and a long press selects. Checkboxes, links and
/// disclosure rows keep their own actions.
class MarkdownPreview extends StatefulWidget {
  const MarkdownPreview({
    required this.text,
    required this.readonly,
    required this.onEditAt,
    required this.onReplaceRange,
    this.loadAttachment,
    this.bottomPadding = 88,
    super.key,
  });

  final String text;
  final bool readonly;

  /// Offset in [text] to put the caret at when the user taps to edit.
  final ValueChanged<int> onEditAt;

  /// Replace [range], which must still read [expected], with [replacement].
  final void Function(SourceRange range, String expected, String replacement)
  onReplaceRange;
  final AttachmentLoader? loadAttachment;
  final double bottomPadding;

  @override
  State<MarkdownPreview> createState() => _MarkdownPreviewState();
}

class _MarkdownPreviewState extends State<MarkdownPreview> {
  bool _tapConsumed = false;
  Offset? _down;
  Duration? _downAt;
  final _images = <String, Future<List<int>>>{};

  @override
  Widget build(BuildContext context) {
    final segments = buildPreviewSegments(widget.text);
    return Listener(
      onPointerDown: (e) {
        _down = e.position;
        _downAt = e.timeStamp;
        _tapConsumed = false;
      },
      onPointerUp: _pointerUp,
      onPointerCancel: (_) => _down = null,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, widget.bottomPadding),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: OwnShape.editorMeasure,
              ),
              child: _Segments(state: this, segments: segments),
            ),
          ),
        ],
      ),
    );
  }

  void _pointerUp(PointerUpEvent e) {
    final down = _down, at = _downAt;
    _down = null;
    // A drag scrolls and a long press selects; only a short tap edits.
    if (down == null ||
        at == null ||
        widget.readonly ||
        (e.position - down).distance > kTouchSlop ||
        e.timeStamp - at > kLongPressTimeout) {
      return;
    }
    // Links, checkboxes and disclosure rows claim the tap after this event.
    scheduleMicrotask(() {
      if (!_tapConsumed && mounted) _editAt(e.position, e.viewId);
    });
  }

  void _editAt(Offset global, int viewId) {
    final hit = HitTestResult();
    WidgetsBinding.instance.hitTestInView(hit, global, viewId);
    (String, int, RenderObject)? found;
    _SegmentTag? tag;
    RenderObject? tagRender;
    for (final entry in hit.path) {
      final target = entry.target;
      found ??= switch (target) {
        RenderParagraph() => (
          target.text.toPlainText(),
          target.getPositionForOffset(target.globalToLocal(global)).offset,
          target,
        ),
        RenderEditable(:final text?) => (
          text.toPlainText(),
          target.getPositionForPoint(global).offset,
          target,
        ),
        _ => null,
      };
      if (target is RenderMetaData && target.metaData is _SegmentTag) {
        tag = target.metaData as _SegmentTag;
        tagRender = target;
        break;
      }
    }
    if (tag == null || tagRender == null) return;
    final range = tag.segment.range;
    if (found == null) {
      widget.onEditAt(range.start);
      return;
    }
    final (plain, at, paragraph) = found;
    final word = RegExp(
      r'[\p{L}\p{N}]+',
      unicode: true,
    ).allMatches(plain).where((m) => m.end >= at && m.start <= at).firstOrNull;
    final source = range.of(widget.text);
    final local = MarkdownDocument.parse(source).offsetOfText(
      word?.group(0) ?? '',
      plain.substring(word?.start ?? at.clamp(0, plain.length)),
      occurrence: _occurrence(tagRender, paragraph, plain),
    );
    widget.onEditAt(range.start + (local >= source.length ? 0 : local));
  }

  /// How many texts equal to [plain] the segment shows before [hit].
  int _occurrence(RenderObject root, RenderObject hit, String plain) {
    var count = 0;
    var done = false;
    void visit(RenderObject o) {
      if (done) return;
      if (identical(o, hit)) {
        done = true;
        return;
      }
      final text = switch (o) {
        RenderParagraph() => o.text.toPlainText(),
        RenderEditable(:final text?) => text.toPlainText(),
        _ => null,
      };
      if (text != null && text == plain) count++;
      o.visitChildren(visit);
    }

    visit(root);
    return count;
  }

  void _openLink(String text, String? href, String title) {
    _tapConsumed = true;
    final uri = href == null ? null : Uri.tryParse(href);
    if (uri == null || !{'http', 'https', 'mailto'}.contains(uri.scheme)) {
      return;
    }
    launchUrl(uri, mode: LaunchMode.externalApplication).ignore();
  }

  Widget _image(MarkdownImageConfig config, Widget placeholder) {
    final load = widget.loadAttachment;
    if (load == null || config.uri.hasScheme) return placeholder;
    final String path;
    try {
      path = Uri.decodeFull(config.uri.toString());
    } on FormatException {
      return placeholder;
    } on ArgumentError {
      return placeholder;
    }
    return AttachmentPreviewImage(
      load: () => _images.putIfAbsent(path, () => load(path)),
      onRetry: () {
        _tapConsumed = true;
        _images.remove(path);
      },
      placeholder: placeholder,
      width: config.width,
      height: config.height,
      alt: config.alt,
    );
  }

  MarkdownStyleSheet _sheet(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.own;
    final body = theme.textTheme.bodyLarge!.copyWith(height: 1.6);
    TextStyle heading(double size) =>
        body.copyWith(fontSize: size, fontWeight: FontWeight.w600, height: 1.3);
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: body,
      h1: heading(30),
      h2: heading(24),
      h3: heading(20),
      h4: heading(18),
      h5: heading(16),
      h6: heading(16),
      a: body.copyWith(
        color: colors.accent,
        decoration: TextDecoration.underline,
        decorationColor: colors.accent,
      ),
      code: monoTextStyle().copyWith(
        fontSize: 16,
        backgroundColor: colors.raised,
        color: colors.text,
      ),
      codeblockPadding: const EdgeInsets.all(12),
      codeblockDecoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(OwnShape.compactRadius),
      ),
      blockquote: body.copyWith(color: colors.textSecondary),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: colors.accent, width: 4)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.divider)),
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({required this.state, required this.segments});
  final _MarkdownPreviewState state;
  final List<PreviewSegment> segments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < segments.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == segments.length - 1 ? 0 : 12),
            child: _tagged(context, segments[i]),
          ),
      ],
    );
  }

  Widget _tagged(BuildContext context, PreviewSegment s) {
    final l = AppLocalizations.of(context)!;
    final widget = state.widget;
    return MetaData(
      metaData: _SegmentTag(s),
      child: Semantics(
        container: true,
        customSemanticsActions: widget.readonly
            ? null
            : {
                CustomSemanticsAction(label: l.editSection): () =>
                    widget.onEditAt(s.range.start),
              },
        child: switch (s) {
          MarkdownSegment() => _MarkdownBlock(state: state, segment: s),
          TableSegment() => _TableBlock(source: s.range.of(widget.text)),
          CalloutSegment() => _Callout(state: state, segment: s),
          DetailsSegment() => _Details(state: state, segment: s),
        },
      ),
    );
  }
}

class _MarkdownBlock extends StatelessWidget {
  const _MarkdownBlock({required this.state, required this.segment});
  final _MarkdownPreviewState state;
  final MarkdownSegment segment;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final widget = state.widget;
    final source = segment.range.of(widget.text);
    final doc = MarkdownDocument.parse(source);
    final tasks = doc.renderedTasks();
    var boxes = 0;
    final image = Semantics(
      label: l.imageUnavailable,
      child: const Icon(Icons.image_not_supported_outlined),
    );
    return MarkdownBody(
      data: source,
      selectable: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: state._sheet(context),
      inlineSyntaxes: [MentionSyntax(), AttachmentSyntax()],
      builders: {
        'mention': _MentionBuilder(),
        'attachment': _AttachmentBuilder(),
      },
      sizedImageBuilder: (c) => state._image(c, image),
      onTapLink: state._openLink,
      checkboxBuilder: (checked) {
        final index = boxes++;
        return Checkbox(
          value: checked,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          onChanged: widget.readonly
              ? null
              : (_) {
                  state._tapConsumed = true;
                  final task = tasks.elementAtOrNull(index);
                  final next = task == null ? null : doc.toggled(source, task);
                  if (next != null) {
                    widget.onReplaceRange(segment.range, source, next);
                  }
                },
        );
      },
    );
  }
}

Color _toneBorder(OwnColors c, CalloutKind k) => switch (k) {
  CalloutKind.info => c.info,
  CalloutKind.warn => c.decision,
  CalloutKind.error => c.error,
  CalloutKind.success => c.success,
};

class _Callout extends StatelessWidget {
  const _Callout({required this.state, required this.segment});
  final _MarkdownPreviewState state;
  final CalloutSegment segment;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.own;
    final tone = switch (segment.kind) {
      CalloutKind.info => OwnTone.info,
      CalloutKind.warn => OwnTone.decision,
      CalloutKind.error => OwnTone.error,
      CalloutKind.success => OwnTone.success,
    };
    final label = switch (segment.kind) {
      CalloutKind.info => l.calloutInfo,
      CalloutKind.warn => l.calloutWarning,
      CalloutKind.error => l.calloutError,
      CalloutKind.success => l.calloutSuccess,
    };
    final fg = _toneBorder(colors, segment.kind);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.container(tone),
        border: Border(left: BorderSide(color: fg, width: 4)),
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(OwnShape.compactRadius),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    segment.kind == CalloutKind.warn
                        ? Icons.warning_amber_outlined
                        : ownToneIcon(tone),
                    color: fg,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    segment.heading.isEmpty
                        ? label
                        : '$label: ${segment.heading}',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: fg),
                  ),
                ),
              ],
            ),
            if (segment.children.isNotEmpty) const SizedBox(height: 8),
            _Segments(state: state, segments: segment.children),
          ],
        ),
      ),
    );
  }
}

class _Details extends StatefulWidget {
  const _Details({required this.state, required this.segment});
  final _MarkdownPreviewState state;
  final DetailsSegment segment;

  @override
  State<_Details> createState() => _DetailsState();
}

class _DetailsState extends State<_Details> {
  late bool _open = widget.segment.open;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.own;
    final summary = widget.segment.summary.isEmpty
        ? l.detailsDefault
        : widget.segment.summary;
    void toggle() {
      widget.state._tapConsumed = true;
      setState(() => _open = !_open);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(OwnShape.compactRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            label: summary,
            excludeSemantics: true,
            onTap: toggle,
            child: InkWell(
              onTap: toggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: OwnShape.target),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Icon(_open ? Icons.expand_more : Icons.chevron_right),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          summary,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_open && widget.segment.children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              child: _Segments(
                state: widget.state,
                segments: widget.segment.children,
              ),
            ),
        ],
      ),
    );
  }
}

/// A Markdown table with its own horizontal scrolling.
class _TableBlock extends StatelessWidget {
  const _TableBlock({required this.source});
  final String source;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.own;
    final doc = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: [MentionSyntax()],
    );
    final nodes = doc.parseLines(source.split('\n'));
    final table = nodes
        .whereType<md.Element>()
        .where((e) => e.tag == 'table')
        .firstOrNull;
    if (table == null) {
      return Text(source);
    }
    final head = <md.Element>[], body = <md.Element>[];
    for (final part in table.children!.whereType<md.Element>()) {
      final rows = part.children!.whereType<md.Element>();
      (part.tag == 'thead' ? head : body).addAll(rows);
    }
    final base = Theme.of(context).textTheme.bodyMedium!;
    TableRow row(md.Element tr, {required bool header}) => TableRow(
      decoration: header ? BoxDecoration(color: colors.raised) : null,
      children: [
        for (final cell in tr.children!.whereType<md.Element>())
          Semantics(
            header: header,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text.rich(
                  TextSpan(
                    children: _inline(
                      context,
                      cell.children ?? const [],
                      header
                          ? base.copyWith(fontWeight: FontWeight.w700)
                          : base,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    final rows = [
      for (final r in head) row(r, header: true),
      for (final r in body) row(r, header: false),
    ];
    final columns = rows.isEmpty ? 0 : rows.first.children.length;
    return Semantics(
      container: true,
      label: l.tableLabel(rows.length, columns),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: colors.outline.withValues(alpha: 0.5)),
          children: rows,
        ),
      ),
    );
  }

  List<InlineSpan> _inline(
    BuildContext context,
    List<md.Node> nodes,
    TextStyle style,
  ) {
    final colors = context.own;
    final out = <InlineSpan>[];
    for (final n in nodes) {
      if (n is md.Text) {
        out.add(TextSpan(text: n.text, style: style));
      } else if (n is md.Element) {
        switch (n.tag) {
          case 'mention':
            out.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: MentionChip(n.textContent),
              ),
            );
          case 'br':
            out.add(const TextSpan(text: '\n'));
          case 'img':
            out.add(TextSpan(text: n.attributes['alt'] ?? '', style: style));
          default:
            final next = switch (n.tag) {
              'strong' => style.copyWith(fontWeight: FontWeight.w700),
              'em' => style.copyWith(fontStyle: FontStyle.italic),
              'del' => style.copyWith(decoration: TextDecoration.lineThrough),
              'code' => monoTextStyle().copyWith(
                fontSize: style.fontSize,
                backgroundColor: colors.raised,
              ),
              'a' => style.copyWith(
                color: colors.accent,
                decoration: TextDecoration.underline,
              ),
              _ => style,
            };
            out.addAll(_inline(context, n.children ?? const [], next));
        }
      }
    }
    return out;
  }
}
