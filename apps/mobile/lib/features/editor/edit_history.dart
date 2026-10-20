import 'package:flutter/widgets.dart';

/// Undo and redo of one text controller. Typing within a short time joins one
/// step; every command applied through [apply] is a step of its own. The
/// controller is never replaced, so focus, selection and composition stay.
class EditHistory extends ChangeNotifier {
  EditHistory(this.controller, {this.typingWindow = const Duration(seconds: 1)})
    : _entries = [_Entry(controller.value, typing: false)] {
    controller.addListener(_onChange);
  }

  final TextEditingController controller;

  /// Edits closer together than this are one undo step.
  final Duration typingWindow;
  final List<_Entry> _entries;
  int _at = 0;
  bool _silent = false;
  bool _forceNew = false;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  bool get canUndo => _at > 0;
  bool get canRedo => _at < _entries.length - 1;

  /// Number of steps kept, for tests.
  int get length => _entries.length;

  void _onChange() {
    if (_silent) return;
    final value = controller.value;
    final top = _entries[_at];
    if (value.text == top.value.text) {
      // Selection only: remembered with the step, not a step of its own.
      _entries[_at] = _Entry(value, typing: top.typing);
      return;
    }
    final now = DateTime.now();
    final join =
        !_forceNew &&
        top.typing &&
        (now.difference(_last) < typingWindow || value.isComposingRangeValid);
    _last = now;
    if (join && _at == _entries.length - 1) {
      _entries[_at] = _Entry(value, typing: true);
    } else {
      _entries.removeRange(_at + 1, _entries.length);
      _entries.add(_Entry(value, typing: !_forceNew));
      _at++;
    }
    _forceNew = false;
    notifyListeners();
  }

  /// Applies [value] as exactly one step, however soon after typing.
  void apply(TextEditingValue value) {
    if (value.text == controller.text) {
      controller.value = value;
      return;
    }
    _forceNew = true;
    controller.value = value;
    _forceNew = false;
    // The next typing starts a step of its own.
    _entries[_at] = _Entry(_entries[_at].value, typing: false);
  }

  void undo() => _move(-1);
  void redo() => _move(1);

  void _move(int by) {
    final to = _at + by;
    if (to < 0 || to >= _entries.length) return;
    // What was typed since the last step is kept as that step's selection.
    _at = to;
    _silent = true;
    controller.value = _entries[to].value.copyWith(
      composing: TextRange.empty,
    );
    _silent = false;
    notifyListeners();
  }

  /// Drops all steps and starts from [value]. Used when a sync brings text
  /// from another device: local undo must not walk across it.
  void rebase(TextEditingValue value) {
    _silent = true;
    controller.value = value;
    _silent = false;
    _entries
      ..clear()
      ..add(_Entry(value, typing: false));
    _at = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    controller.removeListener(_onChange);
    super.dispose();
  }
}

class _Entry {
  const _Entry(this.value, {required this.typing});
  final TextEditingValue value;
  final bool typing;
}
