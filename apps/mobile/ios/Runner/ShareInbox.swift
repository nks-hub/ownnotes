import Foundation

/// Text shared through the iOS share sheet waits here until the app takes it.
/// The share extension and the app are separate processes; they meet in the
/// App Group.
enum ShareInbox {
  static let group = "group.com.nkshub.nextcloudnotes"
  private static let key = "pendingShares"

  // shortcut: no cross-process lock; a share saved at the very moment the app
  // takes one can be lost. Use a file lock if that ever shows up.
  static func add(title: String, text: String) {
    guard let defaults = UserDefaults(suiteName: group) else { return }
    var items = defaults.array(forKey: key) as? [[String: String]] ?? []
    items.append(["title": title, "text": text])
    defaults.set(Array(items.suffix(16)), forKey: key)
  }

  /// The oldest waiting share, removed from the inbox.
  static func take() -> [String: String]? {
    guard let defaults = UserDefaults(suiteName: group),
          var items = defaults.array(forKey: key) as? [[String: String]],
          !items.isEmpty
    else { return nil }
    let first = items.removeFirst()
    defaults.set(items, forKey: key)
    return first
  }
}
