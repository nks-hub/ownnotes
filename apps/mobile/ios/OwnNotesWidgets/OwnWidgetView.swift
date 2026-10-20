import SwiftUI
import WidgetKit

private func tr(_ key: String) -> String { NSLocalizedString(key, comment: "") }

extension View {
    @ViewBuilder
    fileprivate func ownBackground(accessory: Bool) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { accessory ? Color.clear : Color(UIColor.systemBackground) }
        } else if accessory {
            self
        } else {
            background(Color(UIColor.systemBackground))
        }
    }
}

struct OwnWidgetView: View {
    let kind: OwnKind
    let entry: OwnEntry
    @Environment(\.widgetFamily) private var family

    private var isAccessory: Bool {
        if #available(iOS 16.0, *) {
            return family == .accessoryCircular || family == .accessoryRectangular || family == .accessoryInline
        }
        return false
    }

    var body: some View {
        content
            .redacted(reason: entry.isPlaceholder ? .placeholder : [])
            .ownBackground(accessory: isAccessory)
    }

    @ViewBuilder
    private var content: some View {
        if entry.isPlaceholder {
            ListView(title: "OwnNotes", rows: [NoteLink(id: "1", title: "Note title", favorite: nil)], account: nil, limit: 3)
        } else if let s = entry.snapshot, s.isRedacted {
            RedactedView(isAccessory: isAccessory)
        } else if isAccessory {
            if #available(iOS 16.0, *) { AccessoryView(kind: kind, snapshot: entry.snapshot) }
        } else {
            switch kind {
            case .quickNote:
                QuickNoteView()
            case .notesList:
                if let s = entry.snapshot, s.accountId != nil {
                    ListView(title: s.accountLabel ?? "OwnNotes", rows: s.notes ?? [], account: s.accountId, limit: rowLimit)
                } else { SetupView() }
            case .singleNote:
                if let s = entry.snapshot, s.accountId != nil, let note = s.noteId {
                    SingleNoteView(snapshot: s, noteId: note)
                } else { SetupView() }
            case .checklist:
                if let s = entry.snapshot, s.accountId != nil, s.noteId != nil {
                    ChecklistView(snapshot: s, limit: rowLimit)
                } else { SetupView() }
            }
        }
    }

    private var rowLimit: Int {
        switch family {
        case .systemSmall: return 2
        case .systemMedium: return 3
        default: return 7
        }
    }
}

private struct SetupView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "note.text").font(.title2).foregroundColor(.accentColor)
            Text("open_to_set_up").font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(DeepLink.app)
    }
}

private struct RedactedView: View {
    let isAccessory: Bool

    var body: some View {
        if isAccessory {
            Image(systemName: "lock.fill").widgetURL(DeepLink.app)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.title2).foregroundColor(.accentColor)
                Text("OwnNotes").font(.headline)
                Text("hidden_by_lock").font(.footnote).multilineTextAlignment(.center)
                Text("unlock_to_open").font(.caption).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetURL(DeepLink.app)
        }
    }
}

private struct ListView: View {
    let title: String
    let rows: [NoteLink]
    let account: String?
    let limit: Int
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.headline).lineLimit(1)
                Spacer()
                Link(destination: DeepLink.new) {
                    Image(systemName: "plus.circle.fill").font(.title3).foregroundColor(.accentColor)
                }
            }
            if rows.isEmpty {
                Text("no_notes").font(.subheadline).foregroundColor(.secondary)
            }
            ForEach(Array(rows.prefix(limit))) { note in
                Link(destination: DeepLink.note(account: account, note: note.id)) {
                    HStack(spacing: 4) {
                        if note.favorite == true {
                            Image(systemName: "star.fill").font(.caption2).foregroundColor(.orange)
                        }
                        Text(note.title).font(.subheadline).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 28)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(family == .systemSmall ? (rows.first.map { DeepLink.note(account: account, note: $0.id) } ?? DeepLink.app) : nil)
    }
}

private struct SingleNoteView: View {
    let snapshot: Snapshot
    let noteId: String
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snapshot.title ?? "").font(.headline).lineLimit(family == .systemSmall ? 2 : 1)
            Text(snapshot.excerpt ?? "").font(.subheadline).foregroundColor(.secondary)
                .lineLimit(family == .systemSmall ? 4 : family == .systemMedium ? 3 : 14)
            Spacer(minLength: 0)
            if family != .systemSmall {
                Text(snapshot.capturedDate, style: .time).font(.caption2).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(DeepLink.note(account: snapshot.accountId, note: noteId))
    }
}

private struct ChecklistView: View {
    let snapshot: Snapshot
    let limit: Int

    var body: some View {
        let tasks = snapshot.tasks ?? []
        let done = tasks.filter { $0.checked }.count
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(snapshot.title ?? "").font(.headline).lineLimit(1)
                Spacer()
                Text("\(done)/\(tasks.count)").font(.caption).foregroundColor(.secondary)
            }
            if tasks.isEmpty {
                Text("no_tasks").font(.subheadline).foregroundColor(.secondary)
            }
            // Open tasks first so the visible rows are the ones still to do.
            ForEach(Array(tasks.sorted { !$0.checked && $1.checked }.prefix(limit)), id: \.key) { task in
                TaskRow(instance: snapshot.instanceId, task: task, link: DeepLink.note(account: snapshot.accountId, note: snapshot.noteId ?? ""))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(DeepLink.note(account: snapshot.accountId, note: snapshot.noteId ?? ""))
    }
}

private struct TaskRow: View {
    let instance: String
    let task: TaskEntry
    let link: URL

    private var label: some View {
        HStack(spacing: 6) {
            Image(systemName: task.checked ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.checked ? .accentColor : .secondary)
            Text(task.key.label).font(.subheadline).lineLimit(1)
                .strikethrough(task.checked)
                .foregroundColor(task.checked ? .secondary : .primary)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 28)
    }

    var body: some View {
        if #available(iOS 17.0, *) {
            Button(intent: ToggleTaskIntent(
                instanceId: instance, label: task.key.label,
                occurrence: task.key.occurrence, checked: !task.checked)) { label }
                .buttonStyle(.plain)
        } else {
            Link(destination: link) { label }
        }
    }
}

private struct QuickNoteView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Link(destination: DeepLink.new) {
            VStack(spacing: 6) {
                Image(systemName: "square.and.pencil").font(.largeTitle).foregroundColor(.accentColor)
                Text("new_note").font(.headline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .widgetURL(DeepLink.new)
    }
}

@available(iOS 16.0, *)
private struct AccessoryView: View {
    let kind: OwnKind
    let snapshot: Snapshot?
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let tasks = snapshot?.tasks ?? []
        let done = tasks.filter { $0.checked }.count
        switch family {
        case .accessoryCircular:
            if kind == .checklist, !tasks.isEmpty {
                Gauge(value: Double(done), in: 0...Double(tasks.count)) { Text("") } currentValueLabel: { Text("\(done)") }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .widgetURL(DeepLink.note(account: snapshot?.accountId, note: snapshot?.noteId ?? ""))
            } else {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "square.and.pencil").widgetURL(DeepLink.new)
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                switch kind {
                case .notesList:
                    ForEach(Array((snapshot?.notes ?? []).prefix(2))) { Text($0.title).lineLimit(1) }
                case .singleNote:
                    Text(snapshot?.title ?? "OwnNotes").font(.headline).lineLimit(1)
                    Text(snapshot?.excerpt ?? "").lineLimit(2)
                case .checklist:
                    Text(snapshot?.title ?? "OwnNotes").font(.headline).lineLimit(1)
                    Text("\(done)/\(tasks.count)")
                case .quickNote:
                    Label(tr("new_note"), systemImage: "square.and.pencil")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(kind == .quickNote ? DeepLink.new : DeepLink.note(account: snapshot?.accountId, note: snapshot?.noteId ?? snapshot?.notes?.first?.id ?? ""))
        default:
            Label(tr("new_note"), systemImage: "square.and.pencil").widgetURL(DeepLink.new)
        }
    }
}
