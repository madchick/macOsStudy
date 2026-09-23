import SwiftUI

/// 상단 연결 설정 및 상태 바 뷰
public struct ConnectionBarView: View {
    @ObservedObject var wsService: WebSocketService
    @State private var isShowingSettings: Bool = false

    public init(wsService: WebSocketService) {
        self.wsService = wsService
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
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

                // 서버 URL 필드
                HStack(spacing: 4) {
                    Text("URL:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("ws://localhost/ws/", text: $wsService.serverUrlString)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 200, maxWidth: 300)
                        .disabled(wsService.status != .disconnected)
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
                                wsService.serverUrlString = "ws://localhost/ws/"
                            }
                            Button("Spring Boot 직결 (:8080)") {
                                wsService.serverUrlString = "ws://localhost:8080/ws"
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
