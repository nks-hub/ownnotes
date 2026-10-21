import 'dart:async';
import 'dart:ui' show DisplayFeatureState, DisplayFeatureType;
import 'package:flutter/material.dart';
import '../../design/design.dart';
import '../../l10n/app_localizations.dart';

/// Width classes of the notebook (spec 8.1).
enum NotebookLayout { phone, twoPane, threePane }

/// Below 600 dp one pane; from 600 list and editor (the inner display of a
/// foldable is 670-830 dp); from 1280 also the navigation. Larger text takes
/// the navigation away first, then the second pane (spec 8.1). A vertical
/// fold with room on both sides gives list and editor one side each.
NotebookLayout notebookLayout(
  double width,
  double textScale, {
  bool fold = false,
}) {
  if (textScale >= 2.0 || (width < 600 && !fold)) return NotebookLayout.phone;
  if (width < 840 && textScale >= 1.3 && !fold) return NotebookLayout.phone;
  if (width >= 1280 && textScale < 1.3) return NotebookLayout.threePane;
  return NotebookLayout.twoPane;
}

/// The list takes its full width from 840 dp, below that a share that still
/// leaves the editor more room than the list.
double listWidthFor(double width) =>
    width >= 840 ? listPaneWidth : (width * 0.45).clamp(270.0, listPaneWidth);

/// The fold or hinge that splits the window into a left and a right side, as
/// the part of the window it covers; null when there is none or one side is
/// too narrow for a pane.
Rect? verticalFold(MediaQueryData media) {
  for (final feature in media.displayFeatures) {
    final bounds = feature.bounds;
    if (feature.type == DisplayFeatureType.cutout ||
        bounds.top > 0 ||
        bounds.bottom < media.size.height) {
      continue;
    }
    if (bounds.left >= minFoldSide &&
        media.size.width - bounds.right >= minFoldSide) {
      return bounds;
    }
  }
  return null;
}

const minFoldSide = 280.0;

/// The fold of a half-open device lying like a laptop (tabletop posture):
/// the part of the window it covers, or null. The note goes above it, the
/// list below, where the keyboard comes up when typing.
Rect? tabletopFold(MediaQueryData media) {
  for (final feature in media.displayFeatures) {
    final bounds = feature.bounds;
    if (feature.type != DisplayFeatureType.cutout &&
        feature.state == DisplayFeatureState.postureHalfOpened &&
        bounds.left <= 0 &&
        bounds.right >= media.size.width &&
        bounds.top >= minFoldSide / 2 &&
        media.size.height - bounds.bottom >= minFoldSide / 2) {
      return bounds;
    }
  }
  return null;
}

const navigationPaneWidth = 300.0;
const listPaneWidth = 340.0;

/// Keeps the floating button at the end of the list pane, off the editor.
class PaneEndFloat extends FloatingActionButtonLocation {
  const PaneEndFloat(this.paneEnd);
  final double paneEnd;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final end = FloatingActionButtonLocation.endFloat.getOffset(geometry);
    final x =
        paneEnd -
        geometry.floatingActionButtonSize.width -
        kFloatingActionButtonMargin;
    return Offset(x < end.dx ? x : end.dx, end.dy);
  }
}

/// Puts [top] above a horizontal [fold] (window coordinates) and [bottom]
/// below it. When the keyboard leaves no usable room under the fold, [top]
/// gets all of it.
class FoldSplit extends StatefulWidget {
  const FoldSplit({
    required this.fold,
    required this.top,
    required this.bottom,
    super.key,
  });
  final Rect fold;
  final Widget top;
  final Widget bottom;

  @override
  State<FoldSplit> createState() => _FoldSplitState();
}

class _FoldSplitState extends State<FoldSplit> {
  double _origin = 0;

  void _measure(Duration _) {
    final box = context.findRenderObject() as RenderBox?;
    if (!mounted || box == null || !box.attached) return;
    final y = box.localToGlobal(Offset.zero).dy;
    if (y != _origin) setState(() => _origin = y);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    return LayoutBuilder(
      builder: (context, box) {
        final above = widget.fold.top - _origin;
        if (box.maxHeight - above - widget.fold.height < 48) return widget.top;
        return Column(
          children: [
            SizedBox(height: above, child: widget.top),
            if (widget.fold.height > 0)
              SizedBox(height: widget.fold.height)
            else
              const Divider(height: 1),
            Expanded(child: widget.bottom),
          ],
        );
      },
    );
  }
}

/// Owns the editor shown beside the list on wide windows. The editor is a
/// route of a nested [Navigator], so its own back and delete handling work
/// unchanged. Switching notes first lets the open editor flush its text; if
/// that fails the old note stays open.
class EditorPaneController extends ChangeNotifier {
  final navigatorKey = GlobalKey<NavigatorState>();
  late final _observer = _PaneObserver(this);
  int _depth = 0;
  String? _openId;
  Completer<void>? _closing;

  /// Called after an editor closed, with the id it showed.
  void Function(String noteId)? onClosed;

  /// Whether an editor is open in the pane.
  bool get isOpen => _depth > 0;
  String? get openId => _openId;

  /// Closes the open editor after it saved. False when it refused to close
  /// (its save failed), so the caller must not replace it.
  Future<bool> close() async {
    final nav = navigatorKey.currentState;
    if (nav == null || !isOpen) return true;
    final done = _closing = Completer<void>();
    await nav.maybePop();
    await done.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    _closing = null;
    return !isOpen;
  }

  /// Shows [page] for [noteId] in the pane. Returns false when the previously
  /// open editor could not be closed.
  Future<bool> open(String noteId, String routeName, WidgetBuilder page) async {
    if (!await close()) return false;
    final nav = navigatorKey.currentState;
    if (nav == null) return false;
    _openId = noteId;
    notifyListeners();
    unawaited(
      nav.push<void>(
        PageRouteBuilder<void>(
          settings: RouteSettings(name: routeName),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, _, _) => page(context),
        ),
      ),
    );
    return true;
  }

  void _pushed() {
    _depth++;
    notifyListeners();
  }

  void _popped() {
    if (_depth > 0) _depth--;
    final id = _openId;
    if (_depth == 0) _openId = null;
    _closing?.complete();
    _closing = null;
    notifyListeners();
    if (_depth == 0 && id != null) onClosed?.call(id);
  }
}

class _PaneObserver extends NavigatorObserver {
  _PaneObserver(this.pane);
  final EditorPaneController pane;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) pane._pushed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pane._popped();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pane._popped();
}

/// The editor pane: a placeholder until a note is opened. Keeping the same
/// [EditorPaneController] keeps the nested navigator, and with it the open
/// document, alive when the window is resized.
class EditorPane extends StatelessWidget {
  const EditorPane({required this.controller, super.key});
  final EditorPaneController controller;

  @override
  Widget build(BuildContext context) => NavigatorPopHandler(
    onPopWithResult: (_) => controller.navigatorKey.currentState?.maybePop(),
    child: Navigator(
      key: controller.navigatorKey,
      observers: [controller._observer],
      onGenerateRoute: (_) => PageRouteBuilder<void>(
        settings: const RouteSettings(name: '/pane'),
        pageBuilder: (context, _, _) => const _PanePlaceholder(),
      ),
    ),
  );
}

class _PanePlaceholder extends StatelessWidget {
  const _PanePlaceholder();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.own;
    return ColoredBox(
      color: colors.document,
      child: OwnStateView(icon: Icons.edit_note, title: l.selectNote),
    );
  }
}
