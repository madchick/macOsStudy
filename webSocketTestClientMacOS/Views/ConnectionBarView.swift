import SwiftUI

/// 상단 연결 설정 및 상태 바 뷰
public struct ConnectionBarView: View {
    @ObservedObject var wsService: WebSocketService
    var isSidebarVisible: Binding<Bool>?
    var isLogPanelVisible: Binding<Bool>?
    @State private var isShowingSettings: Bool = false

    public init(
        wsService: WebSocketService,
        isSidebarVisible: Binding<Bool>? = nil,
        isLogPanelVisible: Binding<Bool>? = nil
    ) {
        self.wsService = wsService
        self.isSidebarVisible = isSidebarVisible
        self.isLogPanelVisible = isLogPanelVisible
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                // 메뉴 사이드바 토글 버튼
                if let isSidebarVisible = isSidebarVisible {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSidebarVisible.wrappedValue.toggle()
                        }
                    }) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 14))
                            .foregroundColor(isSidebarVisible.wrappedValue ? .accentColor : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(isSidebarVisible.wrappedValue ? "메뉴 사이드바 숨기기" : "메뉴 사이드바 보이기")
                    .padding(.top, 2)
                }

                // 상태 인디케이터
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    Text(wsService.status.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.12))
                .cornerRadius(6)

                // 서버 URL 필드 및 포트 빠른 전환 버튼
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("URL:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("ws://localhost:8080/ws", text: $wsService.serverUrlString)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 200, maxWidth: 300)
                            .disabled(wsService.status != .disconnected)
                    }

                    HStack(spacing: 6) {
                        Button(action: {
                            wsService.updatePort(80)
                        }) {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(wsService.currentPort == 80 ? Color.blue : Color.secondary.opacity(0.4))
                                    .frame(width: 5, height: 5)
                                Text("nginx :80")
                            }
                            .font(.system(size: 11, weight: wsService.currentPort == 80 ? .semibold : .regular))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .tint(wsService.currentPort == 80 ? .blue : .secondary)
                        .disabled(wsService.status != .disconnected)
                        .help("Nginx 리버스 프록시 80번 포트로 변경")

                        Button(action: {
                            wsService.updatePort(8080)
                        }) {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(wsService.currentPort == 8080 ? Color.blue : Color.secondary.opacity(0.4))
                                    .frame(width: 5, height: 5)
                                Text("spring-boot :8080")
                            }
                            .font(.system(size: 11, weight: wsService.currentPort == 8080 ? .semibold : .regular))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .tint(wsService.currentPort == 8080 ? .blue : .secondary)
                        .disabled(wsService.status != .disconnected)
                        .help("Spring Boot 서버 직결 8080번 포트로 변경")
                    }
                    .padding(.leading, 32)
                }

                // User ID 필드
                HStack(spacing: 4) {
                    Text("User ID:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("user_macos", text: $wsService.userId)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 110)
                        .disabled(wsService.status != .disconnected)
                }

                // Nickname 필드
                HStack(spacing: 4) {
                    Text("닉네임:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("맥북유저", text: $wsService.nickname)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .disabled(wsService.status != .disconnected)
                }

                Spacer()

                // 연결 / 해제 버튼
                if wsService.status == .connected {
                    Button(action: {
                        wsService.disconnect()
                    }) {
                        Label("연결 해제", systemImage: "bolt.slash.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red.opacity(0.85))
                } else if wsService.status == .connecting {
                    Button(action: {
                        wsService.disconnect()
                    }) {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("연결 취소")
                        }
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: {
                        wsService.connect()
                    }) {
                        Label("서버 연결", systemImage: "bolt.fill")
                            .bold()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                }

                // 트래픽 로그 패널 토글 버튼
                if let isLogPanelVisible = isLogPanelVisible {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isLogPanelVisible.wrappedValue.toggle()
                        }
                    }) {
                        Image(systemName: isLogPanelVisible.wrappedValue ? "sidebar.right" : "sidebar.right")
                            .font(.system(size: 14))
                            .foregroundColor(isLogPanelVisible.wrappedValue ? .accentColor : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(isLogPanelVisible.wrappedValue ? "트래픽 로그 패널 숨기기" : "트래픽 로그 패널 보이기")
                }

                Button(action: {
                    isShowingSettings.toggle()
                }) {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.borderless)
                .help("고급 연결 설정")
                .popover(isPresented: $isShowingSettings) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("연결 옵션")
                            .font(.headline)
                        Toggle("네트워크 끊김 시 자동 재연결 (지수 백오프)", isOn: $wsService.autoReconnect)
                        Toggle("30초 주기 Keep-Alive PING 자동 전송", isOn: $wsService.autoPingEnabled)
                        Divider()
                        Text("기본 프리셋 URL:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Button("Nginx (:80)") {
                                wsService.updatePort(80)
                            }
                            Button("Spring Boot 직결 (:8080)") {
                                wsService.updatePort(8080)
                            }
                        }
                    }
                    .padding()
                    .frame(width: 320)
                }
            }

            // 하단 세션 정보 뱃지 바 (연결 시에만 표시)
            if wsService.status == .connected {
                HStack(spacing: 16) {
                    if let sid = wsService.currentSessionId {
                        Label("Session: \(sid)", systemImage: "key.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let ip = wsService.clientIp {
                        Label("IP: \(ip)", systemImage: "network")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let rtt = wsService.latestRttMs {
                        Label(String(format: "RTT: %.1f ms", rtt), systemImage: "speedometer")
                            .font(.caption)
                            .foregroundColor(rtt < 50 ? .green : .orange)
                    }
                    Spacer()
                    Text("하트비트: PING \(wsService.pingSentCount)회 / PONG \(wsService.pongReceivedCount)회")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(Divider(), alignment: .bottom)
    }

    private var statusColor: Color {
        switch wsService.status {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .gray
        }
    }
}
