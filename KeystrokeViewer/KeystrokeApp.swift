import SwiftUI

@main
struct KeystrokeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
            Settings { EmptyView() }
    }
}