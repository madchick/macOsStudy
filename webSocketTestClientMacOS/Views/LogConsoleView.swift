import SwiftUI
import AppKit

/// 실시간 트래픽 로그 및 Raw JSON 모니터링 뷰 (우측 패널 최적화)
public struct LogConsoleView: View {
    @ObservedObject var wsService: WebSocketService
    @State private var filterDirection: String = "ALL"
    @State private var searchQuery: String = ""
    @State private var selectedLog: LogEntry? = nil
    @State private var isVerticalSplit: Bool = true

    public init(wsService: WebSocketService) {
        self.wsService = wsService
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 패널 최상단 헤더
            panelHeader

            Divider()

            // 필터 및 검색 바
            filterBar

            Divider()

            // 상하 분할(VSplitView) 또는 좌우 분할(HSplitView)
            if isVerticalSplit {
                VSplitView {
                    logListSection
                        .frame(minHeight: 180)

                    jsonDetailSection
                        .frame(minHeight: 140)
                }
            } else {
                HSplitView {
                    logListSection
                        .frame(minWidth: 180)

                    jsonDetailSection
                        .frame(minWidth: 180)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Panel Header
    private var panelHeader: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "terminal.fill")
                    .foregroundColor(.accentColor)
                Text("트래픽 로그 콘솔")
                    .font(.system(size: 13, weight: .bold))
            }

            Spacer()

            // 로그 건수 뱃지
            Text("\(filteredLogs.count)건")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(4)

            // 상하 / 좌우 분할 전환
            Button(action: {
                isVerticalSplit.toggle()
            }) {
                Image(systemName: isVerticalSplit ? "rectangle.split.2x1" : "rectangle.split.1x2")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help(isVerticalSplit ? "좌우 분할로 변경" : "상하 분할로 변경")

            // 로그 전체 지우기
            Button(action: {
                wsService.clearLogs()
                selectedLog = nil
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help("로그 전체 초기화")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Filter Bar
    private var filterBar: some View {
        ViewThatFits(in: .horizontal) {
            // 너비가 충분한 경우: 1줄 배치 (fixedSize로 탭 크기를 보장하여 검색창이 탭을 가리지 않음)
            HStack(spacing: 8) {
                segmentedPicker
                    .fixedSize()

                searchField
            }

            // 너비가 좁은 경우: 2줄 배치 (탭과 검색창이 상하로 분리되어 절대 겹치지 않음)
            VStack(spacing: 6) {
                segmentedPicker

                searchField
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var segmentedPicker: some View {
        Picker("필터", selection: $filterDirection) {
            Text("전체").tag("ALL")
            Text("IN").tag("IN")
            Text("OUT").tag("OUT")
            Text("SYS").tag("SYS")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 11))

            TextField("검색 (타입, 내용)...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 11))

            if !searchQuery.isEmpty {
                Button(action: {
                    searchQuery = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }

    // MARK: - Log List Section
    private var logListSection: some View {
        Group {
            if filteredLogs.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("기록된 로그가 없습니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredLogs, selection: $selectedLog) { log in
                    LogRowView(log: log)
                        .tag(log)
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - JSON Detail Section
    private var jsonDetailSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let log = selectedLog {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            directionBadge(log.direction)
                            Text(log.messageType)
                                .font(.system(size: 12, weight: .bold))
                        }
                        Text("\(log.formattedTime) | \(log.summary)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button(action: {
                        copyToClipboard(log.rawJson.isEmpty ? log.summary : log.rawJson)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text("복사")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                ScrollView {
                    Text(log.rawJson.isEmpty ? "(상세 JSON 데이터 없음 - 시스템 이벤트)" : log.rawJson)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(NSColor.textBackgroundColor))
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "curlybraces")
                        .font(.system(size: 26))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("목록에서 로그를 선택하면\nRaw JSON 스키마를 확인할 수 있습니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor).opacity(0.5))
            }
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
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .cornerRadius(4)
        case .outbound:
            Text("OUT")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(4)
        case .system:
            Text("SYS")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 5)
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
        HStack(spacing: 6) {
            Text(log.direction.rawValue)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(badgeColor.opacity(0.2))
                .foregroundColor(badgeColor)
                .cornerRadius(4)

            Text(log.formattedTime)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)

            Text(log.messageType)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(log.isError ? .red : .primary)

            Text(log.summary)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
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
