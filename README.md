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
- **광고 차단**: 광고·추적 도메인(약 7만 개, `assets/adblock/hosts.txt`)으로 가는 요청 자체를 Android 네이티브에서 차단 + 남은 광고 자리 숨기기 + YouTube 영상 광고 건너뛰기. 사이트별 예외 가능
  - 목록 갱신: `python3 tool/update_adblock_hosts.py`

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
├─ adblock/                   # 주입 스크립트, 네이티브 차단 연결
│                             # (android/.../AdBlocker.java, BlockingWebViewClient.java)
├─ block/blocked_view.dart    # 차단 화면
├─ settings/                  # 차단 설정 화면, 규칙 편집(다이얼) 대화상자
├─ widgets/                   # 꾹 누르기 확인 대화상자, 명언
├─ storage/storage.dart       # Hive 저장소 (테스트용 메모리 저장소 포함)
└─ util/format.dart
```

## APK 빌드

GitHub Actions(`.github/workflows/build-apk.yml`)가 푸시마다 APK를 만들어 Artifacts에 올린다.
`v*` 태그를 푸시하면 Release에도 첨부한다. 빌드 번호는 Actions 실행 번호를 쓴다.

### 고정 서명 키

저장소 Settings → Secrets and variables → Actions에 아래 Secret을 넣으면 매번 같은 키로 서명되어
기존 앱 위에 업데이트 설치가 된다. 없으면 디버그 키로 서명한다.

| Secret | 값 |
|---|---|
| `BLROME_KEYSTORE_BASE64` | 키스토어(.jks) 파일을 base64로 인코딩한 값 |
| `BLROME_KEYSTORE_PASSWORD` | 키스토어 비밀번호 |
| `BLROME_KEY_ALIAS` | 키 별칭 |
| `BLROME_KEY_PASSWORD` | 키 비밀번호 |

로컬 빌드는 `android/key.properties`(`storeFile`, `storePassword`, `keyAlias`, `keyPassword`)를 쓴다.
키스토어와 key.properties는 커밋하지 않는다.

ABI별 APK(arm64 등)와 전체용 `app-release.apk`는 버전 코드가 달라서 섞어 설치하면 업데이트가 안 된다.
한 종류만 계속 쓴다.

## 다음 단계

- Google 로그인 + Firebase로 규칙/사용량 기기 간 동기화
- iOS 빌드, PC 지원
- (선택) 기기 전체 차단 (Android VPN/DNS 방식)
