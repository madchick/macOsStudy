import SwiftUI

/// 1:1 다이렉트 메시지 뷰 (`DIRECT_MESSAGE`)
public struct DirectMessageView: View {
    @ObservedObject var wsService: WebSocketService
    @State private var targetUserId: String = "user_guest"
    @State private var inputText: String = ""

    public init(wsService: WebSocketService) {
        self.wsService = wsService
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 상단 대상자 지정 바
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("1:1 다이렉트 메시지 (DIRECT_MESSAGE)")
                            .font(.headline)
                        Text("특정 사용자 ID 또는 세션 ID를 대상으로 1:1 비밀 메시지를 전송합니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        wsService.directMessages.removeAll()
                    }) {
                        Image(systemName: "trash")
                        Text("지우기")
                    }
                    .buttonStyle(.borderless)
                }

                HStack(spacing: 8) {
                    Text("수신 대상 (Target):")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("수신자 userId 또는 sessionId", text: $targetUserId)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 260)
                    
                    Text("(상대방이 접속 중이어야 정상 전달됩니다)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // DM 메시지 목록
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if wsService.directMessages.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "envelope.open")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text("주고받은 1:1 메시지가 없습니다.")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 60)
                        } else {
                            ForEach(wsService.directMessages) { item in
                                ChatBubbleView(item: item)
                                    .id(item.id)
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: wsService.directMessages.count) {
                    if let last = wsService.directMessages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // 하단 입력 창
            HStack(spacing: 8) {
                TextField(targetUserId.isEmpty ? "대상을 먼저 입력하세요" : "[\(targetUserId)] 님에게 보낼 비밀 메시지...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        sendMessage()
                    }
                    .disabled(wsService.status != .connected || targetUserId.trimmingCharacters(in: .whitespaces).isEmpty)

                Button(action: sendMessage) {
                    Label("DM 전송", systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    wsService.status != .connected ||
                    targetUserId.trimmingCharacters(in: .whitespaces).isEmpty ||
                    inputText.trimmingCharacters(in: .whitespaces).isEmpty
                )
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    private func sendMessage() {
        let trimmedTarget = targetUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMsg = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTarget.isEmpty, !trimmedMsg.isEmpty else { return }
        
        wsService.sendDirectMessage(target: trimmedTarget, message: trimmedMsg)
        inputText = ""
    }
}
