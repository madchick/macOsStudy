import SwiftUI

/// 전체 브로드캐스트 메시지 뷰 (`BROADCAST`)
public struct BroadcastView: View {
    @ObservedObject var wsService: WebSocketService
    @State private var inputText: String = ""

    public init(wsService: WebSocketService) {
        self.wsService = wsService
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 설명 헤더
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("전체 브로드캐스트 (BROADCAST)")
                        .font(.headline)
                    Text("현재 서버에 연결된 모든 접속자에게 실시간으로 메시지를 전파합니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    wsService.broadcastMessages.removeAll()
                }) {
                    Image(systemName: "trash")
                    Text("지우기")
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()

            // 메시지 스크롤 리스트
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if wsService.broadcastMessages.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text("수신된 브로드캐스트 메시지가 없습니다.")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 60)
                        } else {
                            ForEach(wsService.broadcastMessages) { item in
                                ChatBubbleView(item: item)
                                    .id(item.id)
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: wsService.broadcastMessages.count) { _ in
                    if let last = wsService.broadcastMessages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // 하단 입력 바
            HStack(spacing: 8) {
                TextField("브로드캐스트 메시지 입력...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        sendMessage()
                    }
                    .disabled(wsService.status != .connected)

                Button(action: sendMessage) {
                    Label("전송", systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(wsService.status != .connected || inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        wsService.sendBroadcast(message: trimmed)
        inputText = ""
    }
}

/// 공통 채팅 말풍선 뷰
public struct ChatBubbleView: View {
    public let item: ChatMessageItem

    public var body: some View {
        if item.isSystem {
            // 시스템 알림 메시지 중앙 배치
            HStack {
                Spacer()
                Text("📢 \(item.text)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(12)
                Spacer()
            }
        } else if item.isMine {
            // 본인 송신 메시지 우측 배치
            HStack(alignment: .bottom, spacing: 6) {
                Spacer()
                Text(item.formattedTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.text)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .cornerRadius(14)
                }
            }
        } else {
            // 상대방 수신 메시지 좌측 배치
            HStack(alignment: .bottom, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.sender)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(item.text)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlHighlightColor))
                        .cornerRadius(14)
                }

                Text(item.formattedTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }
}
