import Foundation
import WidgetKit

/// Shared App Group storage written by the Flutter app through home_widget.
enum WidgetStore {
    static let group = "group.com.nkshub.nextcloudnotes"
    static let commandsKey = "commands"

    static var defaults: UserDefaults? { UserDefaults(suiteName: group) }

    static func snapshotKey(_ instance: String) -> String { "snapshot.\(instance)" }
}

/// The four widget types; one widget kind and one snapshot instance each.
enum OwnKind: String, CaseIterable {
    case notesList, singleNote, checklist, quickNote

    var instance: String { "ios.\(rawValue)" }
    var widgetKind: String { "OwnNotes.\(rawValue)" }
}

struct TaskKey: Codable, Hashable {
    let label: String
    let occurrence: Int
}

struct TaskEntry: Codable, Hashable {
    let key: TaskKey
    var checked: Bool
}

struct NoteLink: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let favorite: Bool?
}

/// Mirrors `WidgetSnapshot` in `lib/data/widgets/widget_model.dart`.
struct Snapshot: Codable {
    let instanceId: String
    let type: String
    let capturedAt: Int64
    let privacy: String
    var accountId: String?
    var accountLabel: String?
    var noteId: String?
    var revision: Int?
    var title: String?
    var excerpt: String?
    var notes: [NoteLink]?
    var tasks: [TaskEntry]?

    var isRedacted: Bool { privacy != "visible" }
    var capturedDate: Date { Date(timeIntervalSince1970: Double(capturedAt) / 1000) }

    /// Reads and decodes the stored snapshot. Anything not explicitly visible
    /// comes back with no content at all.
    static func load(_ instance: String) -> Snapshot? {
        guard let text = WidgetStore.defaults?.string(forKey: WidgetStore.snapshotKey(instance)),
              let data = text.data(using: .utf8),
              let s = try? JSONDecoder().decode(Snapshot.self, from: data) else { return nil }
        if s.isRedacted {
            return Snapshot(instanceId: s.instanceId, type: s.type, capturedAt: s.capturedAt, privacy: "redacted")
        }
        return s
    }

    func store() {
        guard let data = try? JSONEncoder().encode(self), let text = String(data: data, encoding: .utf8) else { return }
        WidgetStore.defaults?.set(text, forKey: WidgetStore.snapshotKey(instanceId))
    }
}

/// Deep links understood by the Flutter app.
enum DeepLink {
    static let new = URL(string: "ownnotes://new")!
    static let app = URL(string: "ownnotes://")!

    private static let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))

    static func note(account: String?, note: String) -> URL {
        func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: unreserved) ?? s }
        guard let account = account else { return app }
        return URL(string: "ownnotes://note/\(enc(account))/\(enc(note))") ?? app
    }
}

/// Durable checklist commands; the app drains them when it next runs.
enum CommandQueue {
    static func submit(instance: String, label: String, occurrence: Int, checked: Bool) {
        guard let defaults = WidgetStore.defaults,
              var snapshot = Snapshot.load(instance), !snapshot.isRedacted,
              let account = snapshot.accountId, let note = snapshot.noteId,
              let revision = snapshot.revision else { return }
        var queue: [[String: Any]] = []
        if let text = defaults.string(forKey: WidgetStore.commandsKey),
           let data = text.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            queue = parsed
        }
        queue.append([
            "schema": 1,
            "commandId": UUID().uuidString,
            "instanceId": instance,
            "accountId": account,
            "noteId": note,
            "expectedRevision": revision,
            "kind": "setTask",
            "task": ["label": label, "occurrence": occurrence],
            "checked": checked,
        ])
        guard let out = try? JSONSerialization.data(withJSONObject: queue),
              let text = String(data: out, encoding: .utf8) else { return }
        defaults.set(text, forKey: WidgetStore.commandsKey)

        // Show the tap as accepted until the app republishes the snapshot.
        if let i = snapshot.tasks?.firstIndex(where: { $0.key.label == label && $0.key.occurrence == occurrence }) {
            snapshot.tasks?[i].checked = checked
            snapshot.store()
        }
        WidgetCenter.shared.reloadTimelines(ofKind: OwnKind.checklist.widgetKind)
    }
}
