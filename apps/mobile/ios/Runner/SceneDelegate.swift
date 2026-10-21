import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// `ownnotes://` link of the quick action or widget that opened the app;
  /// Flutter takes it through the share channel (`takeLink`).
  static var pendingLink: String?

  /// Keeps [link] and tells a running Flutter side to take it.
  static func deliver(_ link: String?) {
    guard let link else { return }
    pendingLink = link
    AppDelegate.channel?.invokeMethod("link", arguments: nil)
  }

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    Self.pendingLink =
      connectionOptions.shortcutItem?.type
      ?? connectionOptions.urlContexts.first(where: { $0.url.scheme == "ownnotes" })?
      .url.absoluteString
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    Self.deliver(URLContexts.first(where: { $0.url.scheme == "ownnotes" })?.url.absoluteString)
    super.scene(scene, openURLContexts: URLContexts)
  }

  override func windowScene(
    _ windowScene: UIWindowScene,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    Self.deliver(shortcutItem.type)
    completionHandler(true)
  }
}
