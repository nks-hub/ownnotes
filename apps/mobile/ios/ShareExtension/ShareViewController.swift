import UIKit
import UniformTypeIdentifiers

/// Stores the shared text for OwnNotes and closes; the app turns it into a
/// note the next time it comes to the front.
final class ShareViewController: UIViewController {
  private var started = false

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !started else { return }
    started = true
    Task { @MainActor in
      let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
      let providers = items.flatMap { $0.attachments ?? [] }
      let title = items.compactMap { $0.attributedTitle?.string }.first ?? ""
      var text = items.compactMap { $0.attributedContentText?.string }
        .first { !$0.isEmpty }
      if text == nil { text = await load(UTType.plainText, from: providers) }
      // Safari sends the page title as text and the address only as a URL.
      if let url = await load(UTType.url, from: providers),
         !(text ?? "").contains(url)
      {
        text = [text, url].compactMap { $0 }.joined(separator: "\n")
      }
      if let text, !text.isEmpty {
        ShareInbox.add(title: title, text: text)
      }
      extensionContext?.completeRequest(returningItems: nil)
    }
  }

  private func load(_ type: UTType, from providers: [NSItemProvider]) async -> String? {
    guard let provider = providers.first(where: {
      $0.hasItemConformingToTypeIdentifier(type.identifier)
    }) else { return nil }
    switch try? await provider.loadItem(forTypeIdentifier: type.identifier) {
    case let value as String: return value
    case let value as URL: return value.absoluteString
    case let value as Data: return String(data: value, encoding: .utf8)
    default: return nil
    }
  }
}
