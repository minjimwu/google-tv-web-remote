import SwiftUI

@main
struct HeranRemoteApp: App {
    var body: some Scene {
        WindowGroup {
            RemoteControlView()
                .preferredColorScheme(.dark)
        }
    }
}
