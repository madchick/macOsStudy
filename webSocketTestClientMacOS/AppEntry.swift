import SwiftUI

/// macOS WebSocket 클라이언트 애플리케이션 진입점
@main
public struct WebSocketClientApp: App {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 980, height: 640)
        .commands {
            SidebarCommands()
        }
    }
}
