import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import 'suggestion_controller.dart';
import 'suggestion_model.dart';

List<LocalCommand> localEditorCommands(AppLocalizations l) {
  SuggestionItem item(
    String id,
    String title,
    IconData icon,
    String insert, {
    int caretBack = 0,
    SuggestionAction action = SuggestionAction.none,
  }) => SuggestionItem(
    id: 'cmd:$id',
    title: title,
    subtitle: insert.split('\n').first.trim(),
    icon: icon,
    insert: insert,
    caretBack: caretBack,
    action: action,
  );
  final now = DateTime.now();
  return [
    LocalCommand(
      item(
        'today',
        l.cmdToday,
        Icons.event_outlined,
        DateFormat('yyyy-MM-dd', 'en').format(now),
      ),
      ['date', 'today', 'datum', 'dnes'],
    ),
    LocalCommand(
      item(
        'time',
        l.cmdTime,
        Icons.schedule,
        DateFormat('HH:mm', 'en').format(now),
      ),
      ['time', 'cas', 'čas'],
    ),
    LocalCommand(
      item('h1', '${l.fmtHeading} 1', Icons.looks_one_outlined, '# '),
      ['h1', 'heading', 'nadpis'],
    ),
    LocalCommand(
      item('h2', '${l.fmtHeading} 2', Icons.looks_two_outlined, '## '),
      ['h2', 'heading', 'nadpis'],
    ),
    LocalCommand(
      item('h3', '${l.fmtHeading} 3', Icons.looks_3_outlined, '### '),
      ['h3', 'heading', 'nadpis'],
    ),
    LocalCommand(item('list', l.fmtList, Icons.format_list_bulleted, '- '), [
      'list',
      'bullet',
      'seznam',
    ]),
    LocalCommand(
      item('tasks', l.fmtChecklist, Icons.check_box_outlined, '- [ ] '),
      ['task', 'todo', 'ukol', 'úkol'],
    ),
    LocalCommand(item('quote', l.fmtQuote, Icons.format_quote, '> '), [
      'quote',
      'citace',
    ]),
    LocalCommand(
      item('code', l.fmtCode, Icons.code, '```\n\n```', caretBack: 4),
      ['code', 'kod', 'kód'],
    ),
    LocalCommand(
      item(
        'table',
        l.cmdTable,
        Icons.table_chart_outlined,
        '| A | B |\n| --- | --- |\n|   |   |\n',
      ),
      ['table', 'tabulka'],
    ),
    LocalCommand(item('rule', l.cmdDivider, Icons.horizontal_rule, '---\n'), [
      'divider',
      'rule',
      'cara',
      'čára',
    ]),
    LocalCommand(
      item(
        'info',
        l.calloutInfo,
        Icons.info_outline,
        '::: info\n\n:::\n',
        caretBack: 5,
      ),
      ['callout', 'info'],
    ),
    LocalCommand(
      item(
        'warn',
        l.calloutWarning,
        Icons.warning_amber,
        '::: warn\n\n:::\n',
        caretBack: 5,
      ),
      ['callout', 'warning', 'varovani', 'varování'],
    ),
    LocalCommand(
      item(
        'details',
        l.detailsDefault,
        Icons.expand_circle_down_outlined,
        '<details>\n<summary>${l.detailsDefault}</summary>\n\n\n</details>\n',
        caretBack: 12,
      ),
      ['details', 'summary', 'detail'],
    ),
    LocalCommand(
      item(
        'template',
        l.templates,
        Icons.description_outlined,
        '',
        action: SuggestionAction.template,
      ),
      ['template', 'sablona', 'šablona'],
    ),
  ];
}
