import 'dart:async';
import 'package:flutter/material.dart';
import '../../design/design.dart';
import '../../l10n/app_localizations.dart';

/// Width classes of the notebook (spec 8.1).
enum NotebookLayout { phone, twoPane, threePane }

/// Below 840 dp one pane; from 840 list and editor; from 1280 also a 240 dp
/// navigation. Larger text takes the navigation away first, then the second
/// pane (spec 8.1: collapse navigation first, then one pane).
NotebookLayout notebookLayout(double width, double textScale) {
  if (width < 840 || textScale >= 2.0) return NotebookLayout.phone;
  if (width >= 1280 && textScale < 1.3) return NotebookLayout.threePane;
  return NotebookLayout.twoPane;
}

const navigationPaneWidth = 300.0;
const listPaneWidth = 340.0;

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
