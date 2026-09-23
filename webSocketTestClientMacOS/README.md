# 🍏 WebSocket Test Client for macOS (Swift / SwiftUI Desktop App)

본 프로젝트는 Spring Boot 백엔드 및 Nginx 리버스 프록시 기반 WebSocket 서버(`WEBSOCKET_SPEC.md`)와 연동하기 위해 제작된 **GUI를 갖춘 macOS 네이티브 데스크톱 애플리케이션**입니다.

하위 폴더 분리 없이 프로젝트 상위 루트에 소스 파일들과 Xcode 프로젝트가 함께 구성되어 있어 바로 Xcode로 열어 빌드 및 실행할 수 있습니다.

---

## 🖥️ UI 데스크톱 인터페이스 구성

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│ 🟢 연결됨 | URL: [ws://localhost/ws/       ] ID: [user_macos] 닉네임: [맥북유저] [연결 해제] ⚙️   │
├──────────────────────┬──────────────────────────────────────────────────────────────────────┤
│ 💬 브로드캐스트       │ 전체 브로드캐스트 (BROADCAST)                                        │
│ 🚪 룸 채널 대화      │  - 모든 접속자 대상 실시간 메시지 전송 및 수신                       │
│ ✉️ 1:1 다이렉트       │  - 카카오톡/슬랙 스타일의 채팅 UI 말풍선 렌더링                      │
│ ⏱️ 에코 & RTT (지연)  │                                                                      │
│ 📜 트래픽 로그 콘솔   │ [메시지 입력...                                               ] [전송] │
└──────────────────────┴──────────────────────────────────────────────────────────────────────┘
```

1. **상단 연결 제어 바**:
   - `ws://localhost/ws/` (Nginx 프록시) 및 `ws://localhost:8080/ws` (Spring Boot 직결) 선택
   - `userId`, `nickname` 입력 시 URL 쿼리 파라미터(`?userId=...&nickname=...`)로 자동 조합
   - 세션 정보(`sessionId`, `clientIp`) 및 연결 상태 실시간 표시

2. **메인 메뉴 네비게이션**:
   - 💬 **브로드캐스트 (`BROADCAST`)**: 전체 접속자 실시간 공지/단체 대화
   - 🚪 **룸 채널 대화 (`ROOM_*`)**: 룸 생성/선택, 입장(`ROOM_JOIN`), 대화(`ROOM_MESSAGE`), 퇴장(`ROOM_LEAVE`)
   - ✉️ **1:1 다이렉트 메시지 (`DIRECT_MESSAGE`)**: `target` 대상 귓속말 송수신
   - ⏱️ **에코 & RTT 지연시간 (`ECHO` / `PING`)**: 실시간 왕복 지연시간(ms) 측정 및 30초 자동 Keep-Alive PING & PONG
   - 📜 **트래픽 로그 콘솔**: IN / OUT / SYS 전 방향 Pretty Printed JSON 실시간 모니터링, 필터, 검색, 복사

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
