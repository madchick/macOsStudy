import Foundation
import Combine

/// 연결 상태
public enum ConnectionStatus: String {
    case disconnected = "연결 끊김"
    case connecting = "연결 중..."
    case connected = "연결됨"
}

/// WebSocket 통신 및 비즈니스 로직을 총괄하는 서비스
@MainActor
public class WebSocketService: NSObject, ObservableObject {
    // MARK: - Published Properties (UI 상태 바인딩)
    @Published public var status: ConnectionStatus = .disconnected
    @Published public var serverUrlString: String = "ws://localhost:8080/ws"
    @Published public var userId: String = "mac_user"
    @Published public var nickname: String = "맥북유저"
    @Published public var autoReconnect: Bool = true
    @Published public var autoPingEnabled: Bool = true
    
    // MARK: - Port Helper
    /// 현재 접속 URL에서 포트 번호 감지 (80, 8080 등)
    public var currentPort: Int? {
        if let components = URLComponents(string: serverUrlString), let port = components.port {
            return port
        }
        if let regex = try? NSRegularExpression(pattern: #":(\d+)"#),
           let match = regex.firstMatch(in: serverUrlString, range: NSRange(serverUrlString.startIndex..., in: serverUrlString)),
           let range = Range(match.range(at: 1), in: serverUrlString),
           let port = Int(serverUrlString[range]) {
            return port
        }
        if serverUrlString.hasPrefix("ws://") || serverUrlString.hasPrefix("http://") {
            return 80
        }
        return nil
    }
    
    /// 접속 URL의 호스트와 경로를 유지하며 포트 번호를 변경
    public func updatePort(_ newPort: Int) {
        let trimmed = serverUrlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            serverUrlString = "ws://localhost:\(newPort)/ws"
            return
        }
        
        let portPattern = #"(ws[s]?:\/\/[^\/:]+)(?::\d+)?(.*)"#
        if let regex = try? NSRegularExpression(pattern: portPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let hostRange = Range(match.range(at: 1), in: trimmed),
           let pathRange = Range(match.range(at: 2), in: trimmed) {
            let hostPart = String(trimmed[hostRange])
            var pathPart = String(trimmed[pathRange])
            if pathPart.isEmpty {
                pathPart = "/ws"
            }
            serverUrlString = "\(hostPart):\(newPort)\(pathPart)"
            return
        }
        
        if var components = URLComponents(string: trimmed) {
            components.port = newPort
            if let newUrl = components.string {
                serverUrlString = newUrl
                return
            }
        }
        
        serverUrlString = "ws://localhost:\(newPort)/ws"
    }
    
    // 세션 정보 (서버 SYSTEM_NOTICE로부터 획득)
    @Published public var currentSessionId: String? = nil
    @Published public var serverAssignedUserId: String? = nil
    @Published public var clientIp: String? = nil
    
    // 대화 내역
    @Published public var broadcastMessages: [ChatMessageItem] = []
    @Published public var activeRooms: [String] = ["dev-chat", "general"]
    @Published public var selectedRoom: String = "dev-chat"
    @Published public var joinedRooms: Set<String> = []
    @Published public var roomMessages: [String: [ChatMessageItem]] = [:]
    @Published public var directMessages: [ChatMessageItem] = []
    
    // 에코 및 RTT 지연시간
    @Published public var latestRttMs: Double? = nil
    @Published public var echoHistory: [(timestamp: Date, rttMs: Double)] = []
    @Published public var pingSentCount: Int = 0
    @Published public var pongReceivedCount: Int = 0
    
    // 로그 및 에러 알림
    @Published public var logs: [LogEntry] = []
    @Published public var errorMessage: String? = nil

    // MARK: - Internal Properties
    private var urlSession: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var reconnectTimer: Timer?
    private var reconnectAttempt: Int = 0
    private var isIntentionallyDisconnected: Bool = false
    
    // RTT 측정을 위한 타임스탬프 기록 (testId 혹은 timestamp 기준)
    private var pendingEchoRequests: [String: Date] = [:]
    
    public override init() {
        super.init()
    }

    // MARK: - Connection Management
    
    /// WebSocket 서버 연결 시작
    public func connect() {
        guard status != .connected && status != .connecting else { return }
        
        isIntentionallyDisconnected = false
        status = .connecting
        appendLog(direction: .system, type: "CONNECT", summary: "서버 연결 시도: \(serverUrlString)")
        
        // 쿼리 파라미터 조합 (WEBSOCKET_SPEC.md 1.3)
        guard var urlComponents = URLComponents(string: serverUrlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            handleConnectionError("잘못된 URL 형식입니다.")
            return
        }
        
        var queryItems = urlComponents.queryItems ?? []
        if !userId.isEmpty {
            queryItems.removeAll(where: { $0.name == "userId" })
            queryItems.append(URLQueryItem(name: "userId", value: userId))
        }
        if !nickname.isEmpty {
            queryItems.removeAll(where: { $0.name == "nickname" })
            queryItems.append(URLQueryItem(name: "nickname", value: nickname))
        }
        urlComponents.queryItems = queryItems
        
        guard let finalUrl = urlComponents.url else {
            handleConnectionError("URL 파라미터 조합 실패")
            return
        }
        
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())
        self.urlSession = session
        
        let task = session.webSocketTask(with: finalUrl)
        self.webSocketTask = task
        task.resume()
        
        // 메시지 수신 루프 시작
        listenForMessages()
    }
    
    /// WebSocket 서버 연결 해제
    public func disconnect() {
        isIntentionallyDisconnected = true
        stopPingTimer()
        stopReconnectTimer()
        reconnectAttempt = 0
        
        webSocketTask?.cancel(with: .normalClosure, reason: "사용자 요청에 의한 연결 종료".data(using: .utf8))
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        
        status = .disconnected
        appendLog(direction: .system, type: "DISCONNECT", summary: "연결 해제 완료")
    }

    // MARK: - Message Receiving Loop
    
    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleIncomingText(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleIncomingText(text)
                        }
                    @unknown default:
                        break
                    }
                    // 다음 메시지 계속 청취
                    self.listenForMessages()
                    
                case .failure(let error):
                    self.handleDisconnection(error: error)
                }
            }
        }
    }
    
    // MARK: - Incoming Message Handler
    
    private func handleIncomingText(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            let decoder = JSONDecoder()
            let envelope = try decoder.decode(WebSocketEnvelope.self, from: data)
            
            // Raw JSON 포맷팅 로그 기록
            appendLog(
                direction: .inbound,
                type: envelope.type,
                summary: "[\(envelope.type)] \(envelope.sender ?? "서버"): \(envelope.payload?.description ?? "")",
                rawJson: envelope.toPrettyJson()
            )
            
            processEnvelope(envelope)
            
        } catch {
            appendLog(
                direction: .inbound,
                type: "PARSE_ERROR",
                summary: "JSON 파싱 오류: \(error.localizedDescription)",
                rawJson: text,
                isError: true
            )
        }
    }
    
    private func processEnvelope(_ envelope: WebSocketEnvelope) {
        switch envelope.type {
        case WebSocketMessageType.systemNotice.rawValue:
            handleSystemNotice(envelope)
            
        case WebSocketMessageType.pong.rawValue:
            pongReceivedCount += 1
            
        case WebSocketMessageType.echo.rawValue:
            handleEchoResponse(envelope)
            
        case WebSocketMessageType.broadcast.rawValue:
            let sender = envelope.sender ?? "알 수 없음"
            let msgText = envelope.payload?.description ?? ""
            let isMine = (sender == self.nickname || sender == self.userId || sender == self.currentSessionId)
            let item = ChatMessageItem(sender: sender, text: msgText, isMine: isMine)
            broadcastMessages.append(item)
            
        case WebSocketMessageType.roomJoin.rawValue:
            if let roomId = envelope.roomId {
                joinedRooms.insert(roomId)
                let item = ChatMessageItem(sender: "SYSTEM", text: "\(envelope.sender ?? "누군가") 님이 [\(roomId)] 방에 입장했습니다.", isSystem: true)
                appendRoomMessage(roomId: roomId, message: item)
            }
            
        case WebSocketMessageType.roomMessage.rawValue:
            if let roomId = envelope.roomId {
                let sender = envelope.sender ?? "알 수 없음"
                let text = envelope.payload?.description ?? ""
                let isMine = (sender == self.nickname || sender == self.userId || sender == self.currentSessionId)
                let item = ChatMessageItem(sender: sender, text: text, isMine: isMine)
                appendRoomMessage(roomId: roomId, message: item)
            }
            
        case WebSocketMessageType.roomLeave.rawValue:
            if let roomId = envelope.roomId {
                if envelope.sender == self.nickname || envelope.sender == self.userId || envelope.sender == self.currentSessionId {
                    joinedRooms.remove(roomId)
                }
                let item = ChatMessageItem(sender: "SYSTEM", text: "\(envelope.sender ?? "누군가") 님이 [\(roomId)] 방에서 퇴장했습니다.", isSystem: true)
                appendRoomMessage(roomId: roomId, message: item)
            }
            
        case WebSocketMessageType.directMessage.rawValue:
            let sender = envelope.sender ?? "익명"
            let text = envelope.payload?.description ?? ""
            let isMine = (sender == self.nickname || sender == self.userId || sender == self.currentSessionId)
            let item = ChatMessageItem(sender: sender, text: text, isMine: isMine)
            directMessages.append(item)
            
        case WebSocketMessageType.error.rawValue:
            let errText = envelope.payload?.description ?? "서버 에러가 발생했습니다."
            errorMessage = errText
            appendLog(direction: .inbound, type: "ERROR", summary: "서버 에러: \(errText)", rawJson: envelope.toPrettyJson(), isError: true)
            
        default:
            break
        }
    }
    
    private func handleSystemNotice(_ envelope: WebSocketEnvelope) {
        if let dict = envelope.payload?.asDictionary {
            if let sessId = dict["sessionId"]?.asString {
                self.currentSessionId = sessId
            }
            if let uid = dict["userId"]?.asString {
                self.serverAssignedUserId = uid
            }
            if let ip = dict["clientIp"]?.asString {
                self.clientIp = ip
            }
            if let msg = dict["message"]?.asString {
                let sysMsg = ChatMessageItem(sender: "SYSTEM", text: msg, isSystem: true)
                broadcastMessages.append(sysMsg)
            }
        } else if let str = envelope.payload?.asString {
            let sysMsg = ChatMessageItem(sender: "SYSTEM", text: str, isSystem: true)
            broadcastMessages.append(sysMsg)
        }
    }
    
    private func handleEchoResponse(_ envelope: WebSocketEnvelope) {
        let now = Date()
        var calculatedRtt: Double? = nil
        
        // 보낸 시각과 비교하여 RTT 계산
        if let ts = envelope.timestamp {
            let sentTime = Date(timeIntervalSince1970: TimeInterval(ts) / 1000.0)
            let elapsed = now.timeIntervalSince(sentTime) * 1000.0
            if elapsed >= 0 && elapsed < 60000 {
                calculatedRtt = elapsed
            }
        }
        
        // pending 목록에서 매칭 시도
        if calculatedRtt == nil, let firstKey = pendingEchoRequests.keys.first, let sentDate = pendingEchoRequests.removeValue(forKey: firstKey) {
            calculatedRtt = now.timeIntervalSince(sentDate) * 1000.0
        }
        
        if let rtt = calculatedRtt {
            latestRttMs = rtt
            echoHistory.append((timestamp: now, rttMs: rtt))
            if echoHistory.count > 30 {
                echoHistory.removeFirst()
            }
        }
    }
    
    private func appendRoomMessage(roomId: String, message: ChatMessageItem) {
        var list = roomMessages[roomId] ?? []
        list.append(message)
        roomMessages[roomId] = list
    }

    // MARK: - Sending Messages
    
    /// WebSocketEnvelope 객체를 서버로 직렬화하여 전송
    public func sendEnvelope(_ envelope: WebSocketEnvelope) {
        guard status == .connected, let task = webSocketTask else {
            appendLog(direction: .system, type: "WARN", summary: "연결되지 않은 상태에서 메시지 전송 시도", rawJson: "", isError: true)
            return
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        
        do {
            let data = try encoder.encode(envelope)
            guard let jsonString = String(data: data, encoding: .utf8) else { return }
            
            let message = URLSessionWebSocketTask.Message.string(jsonString)
            let envelopeType = envelope.type
            task.send(message) { [weak self] error in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if let error = error {
                        self.appendLog(
                            direction: .outbound,
                            type: envelopeType,
                            summary: "전송 실패: \(error.localizedDescription)",
                            rawJson: jsonString,
                            isError: true
                        )
                    } else {
                        self.appendLog(
                            direction: .outbound,
                            type: envelopeType,
                            summary: "[\(envelopeType)] 전송 성공",
                            rawJson: jsonString
                        )
                    }
                }
            }
        } catch {
            appendLog(direction: .system, type: "ENCODE_ERROR", summary: "JSON 인코딩 실패: \(error.localizedDescription)", rawJson: "", isError: true)
        }
    }
    
    // MARK: - Specific Feature Actions
    
    /// 하트비트 PING 발송
    public func sendPing() {
        pingSentCount += 1
        let envelope = WebSocketEnvelope(
            type: WebSocketMessageType.ping.rawValue,
            payload: .string("ping")
        )
        sendEnvelope(envelope)
    }
    
    /// 단독 에코 RTT 테스트 발송
    public func sendEcho(content: String = "RTT 측정 메시지") {
        let now = Date()
        let reqKey = UUID().uuidString
        pendingEchoRequests[reqKey] = now
        
        let payloadDict: [String: AnyCodableValue] = [
            "requestId": .string(reqKey),
            "content": .string(content)
        ]
        
        let envelope = WebSocketEnvelope(
            type: WebSocketMessageType.echo.rawValue,
            sender: self.nickname.isEmpty ? self.userId : self.nickname,
            payload: .dictionary(payloadDict),
            timestamp: Int64(now.timeIntervalSince1970 * 1000)
        )
        sendEnvelope(envelope)
    }
    
    /// 전체 브로드캐스트 메시지 전송
    public func sendBroadcast(message: String) {
        let envelope = WebSocketEnvelope(
            type: WebSocketMessageType.broadcast.rawValue,
            sender: self.nickname.isEmpty ? self.userId : self.nickname,
            payload: .string(message)
        )
        sendEnvelope(envelope)
    }
    
    /// 룸 입장
    public func joinRoom(roomId: String) {
        let envelope = WebSocketEnvelope(
            type: WebSocketMessageType.roomJoin.rawValue,
            sender: self.nickname.isEmpty ? self.userId : self.nickname,
            roomId: roomId
        )
        sendEnvelope(envelope)
    }
    
    /// 룸 메시지 전송
    public func sendRoomMessage(roomId: String, message: String) {
        let envelope = WebSocketEnvelope(
            type: WebSocketMessageType.roomMessage.rawValue,
            sender: self.nickname.isEmpty ? self.userId : self.nickname,
            roomId: roomId,
            payload: .string(message)
        )
        sendEnvelope(envelope)
    }
    
    /// 룸 퇴장
    public func leaveRoom(roomId: String) {
        let envelope = WebSocketEnvelope(
            type: WebSocketMessageType.roomLeave.rawValue,
            sender: self.nickname.isEmpty ? self.userId : self.nickname,
            roomId: roomId
        )
        sendEnvelope(envelope)
    }
    
    /// 1:1 다이렉트 메시지 전송
    public func sendDirectMessage(target: String, message: String) {
        let senderName = self.nickname.isEmpty ? self.userId : self.nickname
        let envelope = WebSocketEnvelope(
            type: WebSocketMessageType.directMessage.rawValue,
            sender: senderName,
            target: target,
            payload: .string(message)
        )
        sendEnvelope(envelope)
        
        // 내 화면에도 송신한 DM 추가
        let item = ChatMessageItem(sender: "\(senderName) ➔ [\(target)]", text: message, isMine: true)
        directMessages.append(item)
    }

    // MARK: - Heartbeat & Keep-Alive (30s)
    
    private func startPingTimer() {
        stopPingTimer()
        guard autoPingEnabled else { return }
        
        // WEBSOCKET_SPEC.md 6.3: Nginx 타임아웃 방지 및 Keep-Alive를 위해 30초마다 PING 전송
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.status == .connected else { return }
                self.sendPing()
            }
        }
    }
    
    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    // MARK: - Reconnection & Error Handling (Exponential Backoff)
    
    private func handleConnectionError(_ errorMsg: String) {
        status = .disconnected
        errorMessage = errorMsg
        appendLog(direction: .system, type: "ERROR", summary: errorMsg, rawJson: "", isError: true)
        scheduleReconnect()
    }
    
    private func handleDisconnection(error: Error?) {
        let desc = error?.localizedDescription ?? "알 수 없는 연결 종료"
        status = .disconnected
        stopPingTimer()
        
        if isIntentionallyDisconnected {
            appendLog(direction: .system, type: "DISCONNECT", summary: "정상 종료")
        } else {
            appendLog(direction: .system, type: "DISCONNECT", summary: "비정상 연결 종료: \(desc)", isError: true)
            scheduleReconnect()
        }
    }
    
    private func scheduleReconnect() {
        guard autoReconnect, !isIntentionallyDisconnected else { return }
        
        stopReconnectTimer()
        
        // WEBSOCKET_SPEC.md 6.2 지수 백오프 전략: 1초, 2초, 4초, 8초, 16초, 최대 30초
        let delay = min(pow(2.0, Double(reconnectAttempt)), 30.0)
        reconnectAttempt += 1
        
        appendLog(direction: .system, type: "RECONNECT", summary: "\(Int(delay))초 후 재연결을 시도합니다... (시도 횟수: \(reconnectAttempt))")
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.connect()
            }
        }
    }
    
    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    // MARK: - Logging Helper
    
    public func appendLog(
        direction: LogDirection,
        type: String,
        summary: String,
        rawJson: String = "",
        isError: Bool = false
    ) {
        let entry = LogEntry(
            direction: direction,
            messageType: type,
            summary: summary,
            rawJson: rawJson,
            isError: isError
        )
        logs.append(entry)
        
        // 최대 500개 유지
        if logs.count > 500 {
            logs.removeFirst(100)
        }
    }
    
    public func clearLogs() {
        logs.removeAll()
    }
}

// MARK: - URLSessionWebSocketDelegate
extension WebSocketService: URLSessionWebSocketDelegate {
    nonisolated public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        Task { @MainActor in
            self.status = .connected
            self.reconnectAttempt = 0
            self.appendLog(
                direction: .system,
                type: "CONNECTED",
                summary: "서버에 성공적으로 연결되었습니다! (프로토콜: \(`protocol` ?? "기본")"
            )
            self.startPingTimer()
        }
    }
    
    nonisolated public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "이유 없음"
        Task { @MainActor in
            self.appendLog(
                direction: .system,
                type: "CLOSED",
                summary: "서버로부터 연결이 종료되었습니다. (코드: \(closeCode.rawValue), 사유: \(reasonStr))"
            )
            self.handleDisconnection(error: nil)
        }
    }
}
