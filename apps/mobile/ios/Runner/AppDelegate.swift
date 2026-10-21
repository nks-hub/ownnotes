import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// The share channel; SceneDelegate uses it to announce a new link.
  static var channel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ShareInbox")
    else { return }
    // Same channel as Android's MainActivity; text comes from ShareExtension.
    let channel = FlutterMethodChannel(
      name: "com.nkshub.nextcloudnotes/share",
      binaryMessenger: registrar.messenger()
    )
    Self.channel = channel
    channel.setMethodCallHandler { call, result in
      if call.method == "takeShared" {
        result(ShareInbox.take())
      } else if call.method == "takeLink" {
        result(SceneDelegate.pendingLink)
        SceneDelegate.pendingLink = nil
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
