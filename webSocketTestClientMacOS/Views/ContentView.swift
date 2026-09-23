import SwiftUI

/// 앱 메인 네비게이션 탭 열거형
public enum NavigationTab: String, CaseIterable, Identifiable {
    case broadcast = "브로드캐스트"
    case roomChat = "룸 채널 대화"
    case directMessage = "1:1 다이렉트"
    case echoPing = "에코 & PING (RTT)"
    case logs = "트래픽 로그 콘솔"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .broadcast: return "bubble.left.and.bubble.right.fill"
        case .roomChat: return "number.square.fill"
        case .directMessage: return "paperplane.fill"
        case .echoPing: return "speedometer"
        case .logs: return "terminal.fill"
        }
    }
}

/// macOS 앱의 메인 컨테이너 뷰
public struct ContentView: View {
    @StateObject private var wsService = WebSocketService()
    @State private var selectedTab: NavigationTab = .broadcast

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // 상단 공통 연결 설정 바
            ConnectionBarView(wsService: wsService)

            // 메인 분할 뷰 (좌측 사이드바 + 우측 콘텐츠)
            NavigationSplitView {
                List(NavigationTab.allCases, selection: $selectedTab) { tab in
                    NavigationLink(value: tab) {
                        Label {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                        } icon: {
                            Image(systemName: tab.iconName)
                                .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                        }
                    }
                }
                .navigationTitle("기능 메뉴")
                .frame(minWidth: 190, maxWidth: 230)
            } detail: {
                Group {
                    switch selectedTab {
                    case .broadcast:
                        BroadcastView(wsService: wsService)
                    case .roomChat:
                        RoomChatView(wsService: wsService)
                    case .directMessage:
                        DirectMessageView(wsService: wsService)
                    case .echoPing:
                        EchoPingView(wsService: wsService)
                    case .logs:
                        LogConsoleView(wsService: wsService)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 850, minHeight: 560)
        .alert(
            "서버 오류 알림",
            isPresented: Binding(
                get: { wsService.errorMessage != nil },
                set: { if !$0 { wsService.errorMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) {
                wsService.errorMessage = nil
            }
        } message: {
            Text(wsService.errorMessage ?? "")
        }
    }
}
