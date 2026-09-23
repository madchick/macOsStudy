import Foundation

/// WebSocket 메시지 타입 정의 (WEBSOCKET_SPEC.md 규격)
public enum WebSocketMessageType: String, Codable, CaseIterable, Identifiable, Sendable {
    case ping = "PING"
    case pong = "PONG"
    case echo = "ECHO"
    case broadcast = "BROADCAST"
    case roomJoin = "ROOM_JOIN"
    case roomMessage = "ROOM_MESSAGE"
    case roomLeave = "ROOM_LEAVE"
    case directMessage = "DIRECT_MESSAGE"
    case systemNotice = "SYSTEM_NOTICE"
    case error = "ERROR"
    
    public var id: String { rawValue }
    
    public var displayTitle: String {
        switch self {
        case .ping: return "PING (하트비트)"
        case .pong: return "PONG (하트비트 응답)"
        case .echo: return "ECHO (RTT 왕복 지연)"
        case .broadcast: return "BROADCAST (전체 공지)"
        case .roomJoin: return "ROOM_JOIN (방 입장)"
        case .roomMessage: return "ROOM_MESSAGE (방 대화)"
        case .roomLeave: return "ROOM_LEAVE (방 퇴장)"
        case .directMessage: return "DIRECT_MESSAGE (1:1 귓속말)"
        case .systemNotice: return "SYSTEM_NOTICE (시스템 알림)"
        case .error: return "ERROR (오류 알림)"
        }
    }
}

/// JSON의 임의의 값을 표현할 수 있는 유연한 Codable 타입
public enum AnyCodableValue: Codable, Equatable, CustomStringConvertible, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case dictionary([String: AnyCodableValue])
    case array([AnyCodableValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let boolVal = try? container.decode(Bool.self) {
            self = .bool(boolVal)
        } else if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let doubleVal = try? container.decode(Double.self) {
            self = .double(doubleVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else if let dictVal = try? container.decode([String: AnyCodableValue].self) {
            self = .dictionary(dictVal)
        } else if let arrVal = try? container.decode([AnyCodableValue].self) {
            self = .array(arrVal)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "지원되지 않는 AnyCodableValue 타입입니다."
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str):
            try container.encode(str)
        case .int(let num):
            try container.encode(num)
        case .double(let num):
            try container.encode(num)
        case .bool(let b):
            try container.encode(b)
        case .dictionary(let dict):
            try container.encode(dict)
        case .array(let arr):
            try container.encode(arr)
        case .null:
            try container.encodeNil()
        }
    }

    public var description: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        case .dictionary(let dict):
            if let data = try? JSONEncoder().encode(dict),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
            return String(describing: dict)
        case .array(let arr):
            if let data = try? JSONEncoder().encode(arr),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
            return String(describing: arr)
        }
    }

    public var asString: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var asDictionary: [String: AnyCodableValue]? {
        if case .dictionary(let d) = self { return d }
        return nil
    }
}

/// WEBSOCKET_SPEC.md 2.1 표준 메시지 스키마 (JSON Envelope)
public struct WebSocketEnvelope: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID = UUID()
    
    public var type: String
    public var sender: String?
    public var target: String?
    public var roomId: String?
    public var payload: AnyCodableValue?
    public var timestamp: Int64?

    enum CodingKeys: String, CodingKey {
        case type
        case sender
        case target
        case roomId
        case payload
        case timestamp
    }

    public init(
        type: String,
        sender: String? = nil,
        target: String? = nil,
        roomId: String? = nil,
        payload: AnyCodableValue? = nil,
        timestamp: Int64? = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.id = UUID()
        self.type = type
        self.sender = sender
        self.target = target
        self.roomId = roomId
        self.payload = payload
        self.timestamp = timestamp
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.type = try container.decode(String.self, forKey: .type)
        self.sender = try container.decodeIfPresent(String.self, forKey: .sender)
        self.target = try container.decodeIfPresent(String.self, forKey: .target)
        self.roomId = try container.decodeIfPresent(String.self, forKey: .roomId)
        self.payload = try container.decodeIfPresent(AnyCodableValue.self, forKey: .payload)
        self.timestamp = try container.decodeIfPresent(Int64.self, forKey: .timestamp)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(sender, forKey: .sender)
        try container.encodeIfPresent(target, forKey: .target)
        try container.encodeIfPresent(roomId, forKey: .roomId)
        try container.encodeIfPresent(payload, forKey: .payload)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)
    }
    
    public var formattedDateString: String {
        guard let ts = timestamp else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(ts) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    public func toPrettyJson() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(self),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{\n  \"type\": \"\(type)\"\n}"
    }
}

/// SYSTEM_NOTICE 접속 정보 페이로드 모델
public struct SystemNoticePayload: Codable, Sendable {
    public let sessionId: String?
    public let userId: String?
    public let clientIp: String?
    public let serverTime: Int64?
    public let message: String?
    public let status: String?
    public let target: String?
}
