import 'package:flutter/material.dart';
import '../tokens.dart';

/// Height below which, or text scale from which, a sheet becomes a full
/// screen route because it no longer fits (spec 6.3).
const _fullScreenHeight = 480.0;
const _fullScreenTextScale = 1.8;

/// Whether a sheet would not fit in the current window.
bool ownSheetNeedsFullScreen(BuildContext context) {
  final media = MediaQuery.of(context);
  final available = media.size.height - media.viewInsets.bottom;
  return available < _fullScreenHeight ||
      media.textScaler.scale(16) / 16 >= _fullScreenTextScale;
}

/// Shows [builder] as a bottom sheet limited to the form width, or as a full
/// screen route when the window is short or the text very large, or when
/// [fullScreen] asks for it (typing-heavy content). A sheet never moves the
/// editor's focus; callers that open it from a text field should not call
/// `unfocus` themselves.
Future<T?> showOwnSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  bool fullScreen = false,
  bool dismissible = true,
}) {
  if (fullScreen || ownSheetNeedsFullScreen(context)) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          appBar: AppBar(title: title == null ? null : Text(title)),
          body: SafeArea(child: _SheetBody(builder: builder, scroll: true)),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: OwnShape.formWidth),
    builder: (context) => SafeArea(
      top: false,
      left: false,
      right: false,
      child: _SheetBody(
        builder: builder,
        title: title,
        scroll: true,
        keyboardInset: MediaQuery.viewInsetsOf(context).bottom,
      ),
    ),
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.builder,
    required this.scroll,
    this.title,
    this.keyboardInset = 0,
  });
  final WidgetBuilder builder;
  final bool scroll;
  final String? title;
  final double keyboardInset;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        OwnSpace.phoneInset,
        0,
        OwnSpace.phoneInset,
        OwnSpace.l + keyboardInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: OwnSpace.m),
              child: Semantics(
                header: true,
                child: Text(
                  title!,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          builder(context),
        ],
      ),
    );
    return scroll ? SingleChildScrollView(child: content) : content;
  }
}
