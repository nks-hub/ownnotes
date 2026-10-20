import AppIntents
import SwiftUI
import WidgetKit

struct OwnEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?
    var isPlaceholder = false
}

/// Reads the snapshot the app wrote to the App Group. No network, no
/// configuration: the app decides what each kind shows.
struct OwnProvider: TimelineProvider {
    let kind: OwnKind

    func placeholder(in context: Context) -> OwnEntry {
        OwnEntry(date: Date(), snapshot: nil, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (OwnEntry) -> Void) {
        completion(OwnEntry(date: Date(), snapshot: Snapshot.load(kind.instance)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OwnEntry>) -> Void) {
        let entry = OwnEntry(date: Date(), snapshot: Snapshot.load(kind.instance))
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))))
    }
}

@available(iOS 17.0, *)
struct ToggleTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle task"
    static let isDiscoverable = false

    @Parameter(title: "Widget") var instanceId: String
    @Parameter(title: "Task") var label: String
    @Parameter(title: "Occurrence") var occurrence: Int
    @Parameter(title: "Checked") var checked: Bool

    init() {}

    init(instanceId: String, label: String, occurrence: Int, checked: Bool) {
        self.instanceId = instanceId
        self.label = label
        self.occurrence = occurrence
        self.checked = checked
    }

    func perform() async throws -> some IntentResult {
        CommandQueue.submit(instance: instanceId, label: label, occurrence: occurrence, checked: checked)
        return .result()
    }
}

private func families(_ base: [WidgetFamily], accessory: [String]) -> [WidgetFamily] {
    var all = base
    if #available(iOS 16.0, *) {
        for name in accessory {
            switch name {
            case "circular": all.append(.accessoryCircular)
            case "rectangular": all.append(.accessoryRectangular)
            case "inline": all.append(.accessoryInline)
            default: break
            }
        }
    }
    return all
}

struct OwnWidget: Widget {
    let kind: OwnKind
    let name: LocalizedStringKey
    let blurb: LocalizedStringKey
    let supported: [WidgetFamily]

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind.widgetKind, provider: OwnProvider(kind: kind)) { entry in
            OwnWidgetView(kind: kind, entry: entry)
        }
        .configurationDisplayName(name)
        .description(blurb)
        .supportedFamilies(supported)
    }
}

struct NotesListWidget: Widget {
    var body: some WidgetConfiguration {
        OwnWidget(
            kind: .notesList, name: "widget_notes_list", blurb: "widget_notes_list_desc",
            supported: families([.systemSmall, .systemMedium, .systemLarge], accessory: ["rectangular", "inline"])
        ).body
    }
}

struct SingleNoteWidget: Widget {
    var body: some WidgetConfiguration {
        OwnWidget(
            kind: .singleNote, name: "widget_single_note", blurb: "widget_single_note_desc",
            supported: families([.systemSmall, .systemMedium, .systemLarge], accessory: ["rectangular"])
        ).body
    }
}

struct ChecklistWidget: Widget {
    var body: some WidgetConfiguration {
        OwnWidget(
            kind: .checklist, name: "widget_checklist", blurb: "widget_checklist_desc",
            supported: families([.systemSmall, .systemMedium, .systemLarge], accessory: ["circular", "rectangular"])
        ).body
    }
}

struct QuickNoteWidget: Widget {
    var body: some WidgetConfiguration {
        OwnWidget(
            kind: .quickNote, name: "widget_quick_note", blurb: "widget_quick_note_desc",
            supported: families([.systemSmall, .systemMedium], accessory: ["circular", "inline"])
        ).body
    }
}

@main
struct OwnNotesWidgetBundle: WidgetBundle {
    var body: some Widget {
        NotesListWidget()
        SingleNoteWidget()
        ChecklistWidget()
        QuickNoteWidget()
    }
}
