# BLROME

사이트 차단과 사이트별 하루 사용 시간 제한이 들어간 모바일 브라우저 (Flutter).

## 기능

- **브라우저**: 주소창(URL이 아니면 Google 검색), 탭, 뒤로/앞으로/홈/새로고침
  - 주소창 왼쪽 사이트 정보(보안 연결, 시간 제한 추가, 사이트별 광고 차단, 쿠키), 오른쪽 새로고침
  - 하단 메뉴: 차단·시간 설정, 사용 시간, 방문 기록, 새 탭, 데스크톱 사이트, 광고 차단, 쿠키·데이터, 글자 크기
- **항상 차단 / 하루 제한**: 도메인(하위 도메인 포함)마다 설정, 시간은 다이얼로 선택
  - 화면에 보고 있는 시간만 세고, 주소창 옆에 남은 시간 표시, 5분·1분 전 알림
  - 매일 **자정(00:00)** 에 초기화
- **풀어 주는 변경은 꾹 누르기**: 삭제, 오늘만 해제, 시간 늘리기 등은 버튼을 10초 동안 눌러야 하고, 누르는 동안 명언이 나옴. 더 엄하게 바꾸는 건 바로 적용
- **사용 시간**: 날짜별 사이트 사용 시간 목록 + 하루 24시간 × 10분 칸 시간표 (30일 보관)
- **방문 기록**: 날짜별, 검색, 항목/전체 삭제 (30일 보관)
- **광고 차단**: 광고 요소 숨기기, 광고 도메인 iframe 제거, YouTube 영상 광고 건너뛰기. 사이트별 예외 가능

## 실행

```bash
flutter pub get
flutter run          # Android 기기/에뮬레이터 연결 후
flutter test         # 단위 테스트
```

## 구조

```
lib/
├─ main.dart                  # 앱 시작, 저장소 열기
├─ blrome_controller.dart     # 규칙 · 날짜별 사용량 · 오늘 해제 관리
├─ browser/
│  ├─ browser_screen.dart     # 주소창 + 탭 + WebView(webview_flutter), 차단 처리
│  ├─ browser_tab.dart        # 탭 상태
│  ├─ url_utils.dart          # 입력 → URL 또는 Google 검색
├─ rules/
│  ├─ site_rule.dart          # 규칙 모델 (항상 차단 / 하루 제한)
│  ├─ domain_matcher.dart     # 도메인 정규화, 하위 도메인 매칭
│  └─ rule_engine.dart        # 접속 허용/차단 판단
│  └─ browser_settings.dart   # 광고 차단·쿠키·글자 크기 설정
├─ usage/usage_tracker.dart   # 1초 단위 사용 시간 측정
├─ stats/usage_stats_screen.dart  # 사용 시간 목록 + 10분 칸 시간표
├─ history/                   # 방문 기록 저장소와 화면
├─ adblock/adblock.dart       # 광고 도메인 목록, 주입 스크립트
├─ block/blocked_view.dart    # 차단 화면
├─ settings/                  # 차단 설정 화면, 규칙 편집(다이얼) 대화상자
├─ widgets/                   # 꾹 누르기 확인 대화상자, 명언
├─ storage/storage.dart       # Hive 저장소 (테스트용 메모리 저장소 포함)
└─ util/format.dart
```

## APK 빌드

GitHub Actions(`.github/workflows/build-apk.yml`)가 푸시마다 APK를 만들어 Artifacts에 올린다.
`v*` 태그를 푸시하면 Release에도 첨부한다.

## 다음 단계

- Google 로그인 + Firebase로 규칙/사용량 기기 간 동기화
- iOS 빌드, PC 지원
- (선택) 기기 전체 차단 (Android VPN/DNS 방식)
