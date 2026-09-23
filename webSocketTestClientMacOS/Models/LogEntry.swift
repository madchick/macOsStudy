import Foundation

/// 로그 메시지 방향
public enum LogDirection: String, Codable, Hashable, Sendable {
    case inbound = "IN"
    case outbound = "OUT"
    case system = "SYS"
    
    public var label: String {
        switch self {
        case .inbound: return "수신 (IN)"
        case .outbound: return "송신 (OUT)"
        case .system: return "시스템 (SYS)"
        }
    }
}

/// 콘솔 모니터링용 통신 로그 엔트리
public struct LogEntry: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let direction: LogDirection
    public let messageType: String
    public let summary: String
    public let rawJson: String
    public let isError: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        direction: LogDirection,
        messageType: String,
        summary: String,
        rawJson: String,
        isError: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.direction = direction
        self.messageType = messageType
        self.summary = summary
        self.rawJson = rawJson
        self.isError = isError
    }

    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

/// 채팅 화면 표시용 메시지 모델
public struct ChatMessageItem: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let sender: String
    public let text: String
    public let timestamp: Date
    public let isMine: Bool
    public let isSystem: Bool

    public init(
        id: UUID = UUID(),
        sender: String,
        text: String,
        timestamp: Date = Date(),
        isMine: Bool = false,
        isSystem: Bool = false
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.isMine = isMine
        self.isSystem = isSystem
    }

    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}
