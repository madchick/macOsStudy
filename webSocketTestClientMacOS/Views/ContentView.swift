import SwiftUI

/// 앱 메인 네비게이션 탭 열거형 (트래픽 로그는 우측 상시 패널로 분리)
public enum NavigationTab: String, CaseIterable, Identifiable {
    case broadcast = "브로드캐스트"
    case roomChat = "룸 채널 대화"
    case directMessage = "1:1 다이렉트"
    case echoPing = "에코 & PING (RTT)"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .broadcast: return "bubble.left.and.bubble.right.fill"
        case .roomChat: return "number.square.fill"
        case .directMessage: return "paperplane.fill"
        case .echoPing: return "speedometer"
        }
    }
}

/// macOS 앱의 메인 컨테이너 뷰
public struct ContentView: View {
    @StateObject private var wsService = WebSocketService()
    @State private var selectedTab: NavigationTab = .broadcast
    @State private var isSidebarVisible: Bool = true
    @State private var isLogPanelVisible: Bool = true

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // 상단 공통 연결 설정 바
            ConnectionBarView(
                wsService: wsService,
                isSidebarVisible: $isSidebarVisible,
                isLogPanelVisible: $isLogPanelVisible
            )

            // 메인 3단 분할 뷰 (좌측 메뉴 사이드바 | 중앙 작업영역 | 우측 트래픽 로그 콘솔)
            HSplitView {
                // 1. 좌측 기능 메뉴 사이드바
                if isSidebarVisible {
                    sidebarView
                        .frame(minWidth: 160, idealWidth: 190, maxWidth: 240)
                }

                // 2. 중앙 메인 작업 화면
                mainContentView
                    .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)

                // 3. 우측 실시간 트래픽 로그 콘솔 패널
                if isLogPanelVisible {
                    LogConsoleView(wsService: wsService)
                        .frame(minWidth: 320, idealWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 960, minHeight: 600)
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

    // MARK: - Sidebar View
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("기능 메뉴")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)

            List(NavigationTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                } icon: {
                    Image(systemName: tab.iconName)
                        .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                }
                .tag(tab)
            }
            .listStyle(.sidebar)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Main Content View
    @ViewBuilder
    private var mainContentView: some View {
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
            }
        }
    }
}
