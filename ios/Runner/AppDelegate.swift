import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // numero sull'icona: lo mette il push, l'app lo riallinea alle notifiche davvero non lette (0 = sparisce)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TriburbaBadge") {
      let canale = FlutterMethodChannel(name: "triburba/badge", binaryMessenger: registrar.messenger())
      canale.setMethodCallHandler { call, result in
        guard call.method == "imposta", let n = call.arguments as? Int else {
          result(FlutterMethodNotImplemented)
          return
        }
        if #available(iOS 16.0, *) {
          UNUserNotificationCenter.current().setBadgeCount(max(0, n)) { _ in }
        } else {
          UIApplication.shared.applicationIconBadgeNumber = max(0, n)
        }
        result(nil)
      }
    }
  }
}
