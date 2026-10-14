# BLROME

사이트 차단과 사이트별 하루 사용 시간 제한이 들어간 모바일 브라우저 (Flutter).

## 1단계 기능

- **브라우저**: 주소창(URL이 아니면 Google 검색), 탭, 뒤로/앞으로/홈/새로고침
- **항상 차단**: 등록한 도메인과 하위 도메인 접속을 막음
- **하루 제한**: 도메인마다 하루 사용 시간(분)을 정하면, 화면에 보고 있는 시간만 세서 다 쓰면 차단
  - 주소창 옆에 남은 시간 표시, 5분·1분 전 알림
  - 매일 **자정(00:00)** 에 초기화 (사용량을 날짜별로 저장하므로 앱이 꺼져 있어도 정확함)
- **오늘만 해제 / 삭제**: 10초를 기다려야 확인 버튼이 눌림 (충동 해제 방지)

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
│  ├─ browser_screen.dart     # 주소창 + 탭 + WebView, 차단 처리
│  ├─ browser_tab.dart        # 탭 상태
│  └─ url_utils.dart          # 입력 → URL 또는 Google 검색
├─ rules/
│  ├─ site_rule.dart          # 규칙 모델 (항상 차단 / 하루 제한)
│  ├─ domain_matcher.dart     # 도메인 정규화, 하위 도메인 매칭
│  └─ rule_engine.dart        # 접속 허용/차단 판단
├─ usage/usage_tracker.dart   # 1초 단위 사용 시간 측정
├─ block/blocked_view.dart    # 차단 화면
├─ settings/                  # 차단 설정 화면, 규칙 편집 대화상자
├─ storage/storage.dart       # Hive 저장소 (테스트용 메모리 저장소 포함)
└─ util/format.dart
```

## 다음 단계

2. Google 로그인 + Firebase로 규칙/사용량 기기 간 동기화
3. iOS 빌드, PC 지원
4. (선택) 기기 전체 차단 (Android VPN/DNS 방식)
