import Foundation

/// Content shared through the iOS share sheet waits here until the app has
/// stored it. The share extension and the app are separate processes; they
/// meet in a folder of the App Group container.
///
/// Every share is its own folder `captures/<id>/` with `capture.json` and the
/// files in `files/`. The folder is renamed into place after everything was
/// written, so nothing is shared by read-modify-write and nothing is capped.
/// The app reads the folders from Dart and deletes one only after storing it.
enum ShareInbox {
  static let group = "group.com.nkshub.nextcloudnotes"

  struct SharedFile {
    let name: String
    let mime: String
    let url: URL
  }

  static func root() -> URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: group)?
      .appendingPathComponent("captures", isDirectory: true)
  }

  /// Stores one share. False when it could not be written; the extension must
  /// then tell the user instead of closing as if it had worked.
  @discardableResult
  static func add(title: String, text: String, files: [SharedFile] = []) -> Bool {
    guard let root = root() else { return false }
    let fm = FileManager.default
    let id = UUID().uuidString.lowercased()
    let work = root.appendingPathComponent("\(id).tmp", isDirectory: true)
    do {
      try fm.createDirectory(
        at: work.appendingPathComponent("files", isDirectory: true),
        withIntermediateDirectories: true)
      var entries: [[String: String]] = []
      for (index, file) in files.enumerated() {
        try fm.copyItem(at: file.url, to: work.appendingPathComponent("files/\(index)"))
        entries.append(["name": file.name, "mime": file.mime, "file": "\(index)"])
      }
      let json: [String: Any] = [
        "id": id,
        "title": title,
        "text": text,
        "createdAt": Int(Date().timeIntervalSince1970 * 1000),
        "files": entries,
      ]
      try JSONSerialization.data(withJSONObject: json)
        .write(to: work.appendingPathComponent("capture.json"), options: .atomic)
      try fm.moveItem(at: work, to: root.appendingPathComponent(id, isDirectory: true))
      return true
    } catch {
      try? fm.removeItem(at: work)
      return false
    }
  }

  /// Retired: the app now lists and acknowledges `captures/` itself, so the
  /// old destructive "take one" no longer exists. Kept only because
  /// AppDelegate still answers the old channel call with it.
  static func take() -> [String: String]? { nil }
}
