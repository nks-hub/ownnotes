import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class NoteFindBar extends StatefulWidget implements PreferredSizeWidget {
  const NoteFindBar({
    required this.source,
    required this.query,
    required this.sourceFocus,
    required this.onClose,
    this.leading,
    super.key,
  });

  final TextEditingController source;
  final TextEditingController query;
  final FocusNode sourceFocus;
  final VoidCallback onClose;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 48);

  @override
  State<NoteFindBar> createState() => _NoteFindBarState();
}

class _NoteFindBarState extends State<NoteFindBar> {
  String? _text;
  String? _query;
  List<Match> _matches = const [];

  @override
  void initState() {
    super.initState();
    widget.source.addListener(_refresh);
    widget.query.addListener(_refresh);
    _scan();
  }

  @override
  void didUpdateWidget(NoteFindBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      oldWidget.source.removeListener(_refresh);
      widget.source.addListener(_refresh);
    }
    if (oldWidget.query != widget.query) {
      oldWidget.query.removeListener(_refresh);
      widget.query.addListener(_refresh);
    }
    _scan();
  }

  void _scan() {
    if (_text == widget.source.text && _query == widget.query.text) return;
    _text = widget.source.text;
    _query = widget.query.text;
    // Match the original string so Unicode case folding cannot shift offsets.
    _matches = _query!.isEmpty
        ? const []
        : RegExp(
            RegExp.escape(_query!),
            caseSensitive: false,
            unicode: true,
          ).allMatches(_text!).toList();
  }

  void _refresh() => setState(_scan);

  void _step(int direction) {
    if (_matches.isEmpty) return;
    final selection = widget.source.selection;
    final from = selection.isValid
        ? (direction > 0 ? selection.end : selection.start)
        : 0;
    var index = direction > 0
        ? _matches.indexWhere((m) => m.start >= from)
        : _matches.lastIndexWhere((m) => m.start < from);
    if (index < 0) index = direction > 0 ? 0 : _matches.length - 1;
    final match = _matches[index];
    widget.source.selection = TextSelection(
      baseOffset: match.start,
      extentOffset: match.end,
    );
    widget.sourceFocus.requestFocus();
  }

  @override
  void dispose() {
    widget.source.removeListener(_refresh);
    widget.query.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final selection = widget.source.selection;
    final current = _matches.indexWhere(
      (m) => m.start == selection.start && m.end == selection.end,
    );
    return AppBar(
      automaticallyImplyLeading: false,
      leading: widget.leading,
      title: TextField(
        controller: widget.query,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l.findInNote,
          border: InputBorder.none,
        ),
        onSubmitted: (_) => _step(1),
      ),
      actions: [
        IconButton(
          tooltip: l.cancel,
          onPressed: widget.onClose,
          icon: const Icon(Icons.close),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _query!.isEmpty
                      ? ''
                      : l.findCount(current + 1, _matches.length),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton(
              tooltip: l.findPrevious,
              onPressed: _matches.isEmpty ? null : () => _step(-1),
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              tooltip: l.findNext,
              onPressed: _matches.isEmpty ? null : () => _step(1),
              icon: const Icon(Icons.arrow_downward),
            ),
          ],
        ),
      ),
    );
  }
}
