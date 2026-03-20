import SwiftUI
import UIKit

@main
struct HeroArenaApp: App {
    @UIApplicationDelegateAdaptor(HeroArenaAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class HeroArenaAppDelegate: NSObject, UIApplicationDelegate {
    static var supportedOrientations: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.supportedOrientations
    }
}

enum AppOrientationController {
    static func rotate(to mask: UIInterfaceOrientationMask, preferredOrientation: UIInterfaceOrientation) {
        HeroArenaAppDelegate.supportedOrientations = mask

        guard let windowScene = activeWindowScene else { return }

        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        UIDevice.current.setValue(preferredOrientation.rawValue, forKey: "orientation")
        windowScene.windows.first(where: \.isKeyWindow)?
            .rootViewController?
            .setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    private static var activeWindowScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }

        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    }
}

private struct ArenaLandscapeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                AppOrientationController.rotate(to: .landscape, preferredOrientation: .landscapeRight)
            }
            .onDisappear {
                AppOrientationController.rotate(to: .portrait, preferredOrientation: .portrait)
            }
    }
}

extension View {
    func arenaLandscape() -> some View {
        modifier(ArenaLandscapeModifier())
    }
}
