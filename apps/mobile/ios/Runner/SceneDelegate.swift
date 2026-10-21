import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// Link of the home-screen quick action that opened the app; Flutter takes
  /// it through the share channel (`takeLink`).
  static var pendingLink: String?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    Self.pendingLink = connectionOptions.shortcutItem?.type
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func windowScene(
    _ windowScene: UIWindowScene,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    Self.pendingLink = shortcutItem.type
    completionHandler(true)
  }
}
