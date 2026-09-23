# 🍏 WebSocket Test Client for macOS (Swift / SwiftUI Desktop App)

본 프로젝트는 Spring Boot 백엔드 및 Nginx 리버스 프록시 기반 WebSocket 서버(`WEBSOCKET_SPEC.md`)와 연동하기 위해 제작된 **GUI를 갖춘 macOS 네이티브 데스크톱 애플리케이션**입니다.

하위 폴더 분리 없이 프로젝트 상위 루트에 소스 파일들과 Xcode 프로젝트가 함께 구성되어 있어 바로 Xcode로 열어 빌드 및 실행할 수 있습니다.

---

## 🖥️ UI 데스크톱 인터페이스 구성

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ 🟢 연결됨 | URL: [ws://localhost:8080/ws      ] ID: [mac_user] 닉네임: [맥북유저] [서버 연결] 📑 ⚙️      │
│            [nginx :80] [spring-boot :8080]                                                             │
├──────────────────────┬──────────────────────────────────────────┬──────────────────────────────────────┤
│ 💬 브로드캐스트       │ 전체 브로드캐스트 (BROADCAST)             │ 📟 트래픽 로그 콘솔 (12건)   [◫] [🗑️]  │
│ 🚪 룸 채널 대화      │  - 모든 접속자 대상 실시간 메시지 전송    │ [전체][IN][OUT][SYS] [검색...      ] │
│ ✉️ 1:1 다이렉트       │  - 실시간 채팅 말풍선 렌더링             │ [IN] 00:35:12 BROADCAST user: 안녕   │
│ ⏱️ 에코 & RTT (지연)  │                                          │ [OUT] 00:35:14 BROADCAST mac: 방가   │
│                      │                                          ├──────────────────────────────────────┤
│                      │ [메시지 입력...                  ] [전송] │ [IN] BROADCAST  00:35:12    [복사]   │
│                      │                                          │ { "type": "BROADCAST", ... }         │
└──────────────────────┴──────────────────────────────────────────┴──────────────────────────────────────┘
```

1. **상단 연결 제어 바**:
   - 디폴트 포트 `:8080` (`ws://localhost:8080/ws`) 설정
   - **빠른 포트 변경 버튼**: URL 입력창 하단의 `[nginx :80]`, `[spring-boot :8080]` 버튼 클릭 시 호스트/경로는 유지하면서 포트만 원클릭 변경
   - `userId`, `nickname` 입력 시 URL 쿼리 파라미터(`?userId=...&nickname=...`)로 자동 조합
   - 세션 정보(`sessionId`, `clientIp`) 및 연결 상태 실시간 표시
   - 우측 트래픽 로그 패널 접기/펼치기 토글 버튼 제공

2. **3-패널 분할 레이아웃 (어느 메뉴에서든 우측 로그 상시 노출)**:
   - **좌측 사이드바 (기능 메뉴)**:
     - 💬 **브로드캐스트 (`BROADCAST`)**: 전체 접속자 실시간 공지/단체 대화
     - 🚪 **룸 채널 대화 (`ROOM_*`)**: 룸 생성/선택, 입장(`ROOM_JOIN`), 대화(`ROOM_MESSAGE`), 퇴장(`ROOM_LEAVE`)
     - ✉️ **1:1 다이렉트 메시지 (`DIRECT_MESSAGE`)**: `target` 대상 귓속말 송수신
     - ⏱️ **에코 & RTT 지연시간 (`ECHO` / `PING`)**: 실시간 왕복 지연시간(ms) 측정 및 30초 자동 Keep-Alive PING & PONG
   - **중앙 작업 화면**: 좌측에서 선택한 기능의 UI 및 인터랙션 화면
   - **우측 트래픽 로그 콘솔**:
     - 좌측의 어느 메뉴를 선택하든 우측에 항상 패킷 로그가 실시간 노출되어 송수신 상태 즉시 확인
     - IN / OUT / SYS 전 방향 Pretty Printed JSON 모니터링, 필터, 검색, 원클릭 복사
     - 상하 분할(VSplitView) 및 좌우 분할(HSplitView) 전환 버튼 지원

---

## 📁 프로젝트 파일 구조

```
webSocketTestClientMacOS/
├── WebSocketClientMacOS.xcodeproj/              # ⭐ Xcode 프로젝트 (더블클릭 실행)
│   └── project.pbxproj
├── AppEntry.swift                               # @main 앱 진입점 (WindowGroup 설정)
├── Info.plist                                   # macOS 앱 번들 메타데이터
├── WebSocketClientMacOS.entitlements            # App Sandbox Outgoing 네트워크 연결 권한
├── Assets.xcassets/                             # 앱 아이콘 및 테마 색상 리소스
├── Models/
│   ├── WebSocketEnvelope.swift                  # JSON Envelope 규격 및 AnyCodableValue
│   └── LogEntry.swift                           # 로그 및 채팅 메시지 모델
├── Services/
│   └── WebSocketService.swift                   # URLSessionWebSocketTask 통신 엔진
├── Views/
│   ├── ContentView.swift                        # 메인 네비게이션 분할 뷰
│   ├── ConnectionBarView.swift                  # 상단 연결 제어 바
│   ├── BroadcastView.swift                      # 브로드캐스트 채팅 뷰
│   ├── RoomChatView.swift                       # 룸 채널 대화 뷰
│   ├── DirectMessageView.swift                  # 1:1 다이렉트 메시지 뷰
│   ├── EchoPingView.swift                       # RTT 지연시간 & PING/PONG 뷰
│   └── LogConsoleView.swift                     # 실시간 JSON 트래픽 로그 뷰
└── README.md                                    # 본 설명 문서
```

---

## 🚀 macOS에서 실행하기

1. macOS Finder에서 **`WebSocketClientMacOS.xcodeproj`** 를 더블클릭하여 Xcode를 엽니다.
2. 상단 실행 대상이 **`My Mac`** 으로 설정되어 있는지 확인합니다.
3. 단축키 **`Cmd + R`** (또는 좌측 상단 `▶` Run 버튼)을 누르면 데스크톱 GUI 창이 즉시 실행됩니다!
