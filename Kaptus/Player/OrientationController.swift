import UIKit

final class KaptusAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationController.mask
    }
}
@MainActor
enum OrientationController {
    static var mask: UIInterfaceOrientationMask = .allButUpsideDown
    private static var scene: UIWindowScene? { UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive } }
    static func lockCurrent() {
        guard let scene else { return }
        switch scene.interfaceOrientation {
        case .landscapeLeft: mask = .landscapeLeft
        case .landscapeRight: mask = .landscapeRight
        default: mask = .portrait
        }
        scene.windows.forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
    }
    static func unlock() {
        mask = .allButUpsideDown
        scene?.windows.forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
    }
}
