import SwiftUI
import AppKit

/// 실시간 트래픽 로그 및 Raw JSON 모니터링 뷰
public struct LogConsoleView: View {
    @ObservedObject var wsService: WebSocketService
    @State private var filterDirection: String = "ALL"
    @State private var searchQuery: String = ""
    @State private var selectedLog: LogEntry? = nil

    public init(wsService: WebSocketService) {
        self.wsService = wsService
    }

    public var body: some View {
        HSplitView {
            // 좌측 로그 목록
            VStack(spacing: 0) {
                // 상단 필터 바
                HStack(spacing: 8) {
                    Picker("필터", selection: $filterDirection) {
                        Text("전체").tag("ALL")
                        Text("수신(IN)").tag("IN")
                        Text("송신(OUT)").tag("OUT")
                        Text("시스템(SYS)").tag("SYS")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)

                    TextField("검색 (타입, 내용)...", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)

                    Button(action: {
                        wsService.clearLogs()
                        selectedLog = nil
                    }) {
                        Image(systemName: "trash")
                        Text("초기화")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(10)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // 로그 목록
                List(filteredLogs, selection: $selectedLog) { log in
                    LogRowView(log: log)
                        .tag(log)
                }
                .listStyle(.inset)
            }
            .frame(minWidth: 350)

            // 우측 Raw JSON 상세 뷰어
            VStack(alignment: .leading, spacing: 0) {
                if let log = selectedLog {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                directionBadge(log.direction)
                                Text(log.messageType)
                                    .font(.headline)
                            }
                            Text("\(log.formattedTime) | \(log.summary)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            copyToClipboard(log.rawJson.isEmpty ? log.summary : log.rawJson)
                        }) {
                            Label("JSON 복사", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))

                    Divider()

                    ScrollView {
                        Text(log.rawJson.isEmpty ? "(상세 JSON 데이터 없음 - 시스템 이벤트)" : log.rawJson)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(NSColor.textBackgroundColor))
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "curlybraces")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("왼쪽 목록에서 로그를 선택하면 포맷팅된 Raw JSON 스키마를 확인할 수 있습니다.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 280)
        }
    }

    private var filteredLogs: [LogEntry] {
        wsService.logs.reversed().filter { log in
            let matchDir: Bool
            switch filterDirection {
            case "IN": matchDir = (log.direction == .inbound)
            case "OUT": matchDir = (log.direction == .outbound)
            case "SYS": matchDir = (log.direction == .system)
            default: matchDir = true
            }

            let matchQuery: Bool
            if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                matchQuery = true
            } else {
                let q = searchQuery.lowercased()
                matchQuery = log.messageType.lowercased().contains(q) ||
                             log.summary.lowercased().contains(q) ||
                             log.rawJson.lowercased().contains(q)
            }

            return matchDir && matchQuery
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    @ViewBuilder
    private func directionBadge(_ dir: LogDirection) -> some View {
        switch dir {
        case .inbound:
            Text("IN")
                .font(.caption2)
                .bold()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .cornerRadius(4)
        case .outbound:
            Text("OUT")
                .font(.caption2)
                .bold()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(4)
        case .system:
            Text("SYS")
                .font(.caption2)
                .bold()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .cornerRadius(4)
        }
    }
}

/// 단일 로그 목록 항목 뷰
struct LogRowView: View {
    let log: LogEntry

    var body: some View {
        HStack(spacing: 8) {
            Text(log.direction.rawValue)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(badgeColor.opacity(0.2))
                .foregroundColor(badgeColor)
                .cornerRadius(4)

            Text(log.formattedTime)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)

            Text(log.messageType)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(log.isError ? .red : .primary)

            Text(log.summary)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var badgeColor: Color {
        if log.isError { return .red }
        switch log.direction {
        case .inbound: return .green
        case .outbound: return .blue
        case .system: return .orange
        }
    }
}
