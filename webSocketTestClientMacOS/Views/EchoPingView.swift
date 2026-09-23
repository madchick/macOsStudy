import SwiftUI

/// 에코(RTT 지연시간 측정) 및 하트비트(PING/PONG) 테스트 뷰
public struct EchoPingView: View {
    @ObservedObject var wsService: WebSocketService
    @State private var echoMessage: String = "RTT 네트워크 지연시간 측정 테스트"

    public init(wsService: WebSocketService) {
        self.wsService = wsService
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 상단 타이틀
                VStack(alignment: .leading, spacing: 4) {
                    Text("지연시간(RTT) 및 생존 확인(PING/PONG)")
                        .font(.title2)
                        .bold()
                    Text("ECHO 메시지를 통한 실시간 왕복 통신 지연(Round Trip Time) 측정과 PING/PONG 하트비트 상태를 확인합니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // 1. ECHO (RTT) 측정 카드
                VStack(alignment: .leading, spacing: 14) {
                    Label("ECHO 테스트 및 왕복 지연시간 (RTT)", systemImage: "speedometer")
                        .font(.headline)

                    HStack(spacing: 20) {
                        // 지연시간 게이지 카드
                        VStack(spacing: 6) {
                            Text("최신 RTT")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let rtt = wsService.latestRttMs {
                                Text(String(format: "%.1f ms", rtt))
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundColor(rttColor(rtt))
                            } else {
                                Text("-- ms")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 140, height: 90)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )

                        // 에코 전송 컨트롤
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                TextField("에코 메시지 본문", text: $echoMessage)
                                    .textFieldStyle(.roundedBorder)
                                
                                Button(action: {
                                    wsService.sendEcho(content: echoMessage)
                                }) {
                                    Label("RTT 측정 (ECHO 전송)", systemImage: "arrow.triangle.2.circlepath")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(wsService.status != .connected)
                            }

                            Text("서버가 동일 페이로드를 회신할 때까지의 소요 시간을 ms 단위로 계산합니다.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    // 최근 RTT 히스토리 목록
                    if !wsService.echoHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("최근 측정 히스토리 (최근 \(wsService.echoHistory.count)건)")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            ForEach(wsService.echoHistory.reversed().prefix(5), id: \.timestamp) { record in
                                HStack {
                                    Text(formattedTime(record.timestamp))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(String(format: "%.1f ms", record.rttMs))
                                        .font(.system(.caption, design: .monospaced))
                                        .bold()
                                        .foregroundColor(rttColor(record.rttMs))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(6)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))

                // 2. 하트비트 (PING/PONG) 카드
                VStack(alignment: .leading, spacing: 14) {
                    Label("하트비트 (PING ➔ PONG)", systemImage: "heart.fill")
                        .font(.headline)
                        .foregroundColor(.pink)

                    Text("Nginx 유휴 연결 끊김 방지 및 서버 연결 유효성 유지를 위해 30초마다 자동 PING을 발송합니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text("전송된 PING")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(wsService.pingSentCount)회")
                                .font(.title3)
                                .bold()
                        }
                        .frame(width: 120, height: 60)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)

                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)

                        VStack(spacing: 4) {
                            Text("수신된 PONG")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(wsService.pongReceivedCount)회")
                                .font(.title3)
                                .bold()
                                .foregroundColor(.green)
                        }
                        .frame(width: 120, height: 60)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)

                        Spacer()

                        Button(action: {
                            wsService.sendPing()
                        }) {
                            Label("수동 PING 전송", systemImage: "paperplane")
                        }
                        .buttonStyle(.bordered)
                        .disabled(wsService.status != .connected)
                    }

                    Toggle("30초 주기 Keep-Alive PING 자동 전송 활성화", isOn: $wsService.autoPingEnabled)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            }
            .padding()
        }
    }

    private func rttColor(_ rtt: Double) -> Color {
        if rtt < 30.0 {
            return .green
        } else if rtt < 100.0 {
            return .orange
        } else {
            return .red
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}
