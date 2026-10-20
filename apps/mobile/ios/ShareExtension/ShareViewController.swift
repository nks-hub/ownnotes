import UIKit
import UniformTypeIdentifiers

/// Stores the shared text, links, pictures and files for OwnNotes and closes.
/// The app asks where the content goes the next time it comes to the front.
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
      let files = await loadFiles(from: providers)
      defer { files.forEach { try? FileManager.default.removeItem(at: $0.url.deletingLastPathComponent()) } }
      guard (text ?? "").isEmpty && files.isEmpty
        || ShareInbox.add(title: title, text: text ?? "", files: files)
      else {
        // Nothing was stored: say so, the sender's app would otherwise think
        // the content arrived.
        extensionContext?.cancelRequest(
          withError: NSError(domain: "OwnNotesShare", code: 1))
        return
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

  /// Pictures, recordings, PDFs and other files, copied into the extension's
  /// temporary folder (the system deletes its own copy when the loader
  /// returns). Web addresses and text are not files.
  private func loadFiles(from providers: [NSItemProvider]) async -> [ShareInbox.SharedFile] {
    var result: [ShareInbox.SharedFile] = []
    for provider in providers {
      guard !provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
            let type = [UTType.image, UTType.audio, UTType.pdf, UTType.data].first(where: {
              provider.hasItemConformingToTypeIdentifier($0.identifier)
            }),
            !(type == .data && provider.hasItemConformingToTypeIdentifier(UTType.url.identifier)
              && !provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier))
      else { continue }
      if let file = await copyFile(of: provider, type: type) { result.append(file) }
    }
    return result
  }

  private func copyFile(of provider: NSItemProvider, type: UTType) async -> ShareInbox.SharedFile? {
    await withCheckedContinuation { continuation in
      provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
        guard let url else { return continuation.resume(returning: nil) }
        let folder = FileManager.default.temporaryDirectory
          .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let target = folder.appendingPathComponent(url.lastPathComponent)
        do {
          try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
          try FileManager.default.copyItem(at: url, to: target)
          let mime = UTType(filenameExtension: target.pathExtension)?.preferredMIMEType
            ?? type.preferredMIMEType ?? "application/octet-stream"
          continuation.resume(
            returning: ShareInbox.SharedFile(name: target.lastPathComponent, mime: mime, url: target))
        } catch {
          continuation.resume(returning: nil)
        }
      }
    }
  }
}
