import SwiftUI

/// 룸 / 채널 기반 통신 뷰 (`ROOM_JOIN`, `ROOM_MESSAGE`, `ROOM_LEAVE`)
public struct RoomChatView: View {
    @ObservedObject var wsService: WebSocketService
    @State private var newRoomName: String = ""
    @State private var inputText: String = ""

    public init(wsService: WebSocketService) {
        self.wsService = wsService
    }

    public var body: some View {
        HSplitView {
            // 좌측 방 목록
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("채팅 룸 목록")
                        .font(.headline)
                    Spacer()
                }
                .padding()

                Divider()

                List(selection: $wsService.selectedRoom) {
                    ForEach(wsService.activeRooms, id: \.self) { room in
                        HStack {
                            Image(systemName: "number")
                                .foregroundColor(.secondary)
                            Text(room)
                                .fontWeight(wsService.selectedRoom == room ? .bold : .regular)
                            Spacer()
                            if wsService.joinedRooms.contains(room) {
                                Text("참여중")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)
                            }
                        }
                        .tag(room)
                    }
                }
                .listStyle(.sidebar)

                Divider()

                // 새 방 추가
                HStack(spacing: 6) {
                    TextField("새 룸 ID 입력...", text: $newRoomName)
                        .textFieldStyle(.roundedBorder)
                    Button(action: addRoom) {
                        Image(systemName: "plus")
                    }
                    .disabled(newRoomName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(10)
            }
            .frame(minWidth: 180, maxWidth: 240)

            // 우측 선택된 방의 채팅 창
            VStack(spacing: 0) {
                // 방 상단 헤더 (입장/퇴장 컨트롤)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("# \(wsService.selectedRoom)")
                                .font(.title3)
                                .bold()
                            if isCurrentRoomJoined {
                                Text("입장 완료")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("미입장 상태 (입장 필요)")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        Text("격리된 그룹 채널 통신 (ROOM_*)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if isCurrentRoomJoined {
                        Button(action: leaveCurrentRoom) {
                            Label("룸 퇴장", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .buttonStyle(.bordered)
                        .disabled(wsService.status != .connected)
                    } else {
                        Button(action: joinCurrentRoom) {
                            Label("룸 입장 (JOIN)", systemImage: "arrow.right.to.line")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(wsService.status != .connected)
                    }
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // 방 메시지 목록
                let currentMessages = wsService.roomMessages[wsService.selectedRoom] ?? []
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if currentMessages.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "tray")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary.opacity(0.5))
                                    Text("아직 방 메시지가 없습니다.")
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                    if !isCurrentRoomJoined {
                                        Text("우측 상단의 '룸 입장 (JOIN)' 버튼을 눌러 먼저 방에 참여하세요.")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                                .padding(.top, 60)
                            } else {
                                ForEach(currentMessages) { item in
                                    ChatBubbleView(item: item)
                                        .id(item.id)
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: currentMessages.count) {
                        if let last = currentMessages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // 하단 입력 창
                HStack(spacing: 8) {
                    TextField(isCurrentRoomJoined ? "[\(wsService.selectedRoom)] 방에 메시지 입력..." : "방에 먼저 입장(JOIN)해야 전송할 수 있습니다.", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            sendMessage()
                        }
                        .disabled(wsService.status != .connected || !isCurrentRoomJoined)

                    Button(action: sendMessage) {
                        Label("전송", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(wsService.status != .connected || !isCurrentRoomJoined || inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }

    private var isCurrentRoomJoined: Bool {
        wsService.joinedRooms.contains(wsService.selectedRoom)
    }

    private func addRoom() {
        let trimmed = newRoomName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !wsService.activeRooms.contains(trimmed) {
            wsService.activeRooms.append(trimmed)
            wsService.selectedRoom = trimmed
        }
        newRoomName = ""
    }

    private func joinCurrentRoom() {
        wsService.joinRoom(roomId: wsService.selectedRoom)
    }

    private func leaveCurrentRoom() {
        wsService.leaveRoom(roomId: wsService.selectedRoom)
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        wsService.sendRoomMessage(roomId: wsService.selectedRoom, message: trimmed)
        inputText = ""
    }
}
