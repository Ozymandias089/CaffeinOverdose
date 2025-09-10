# CaffeinOverdose

macOS용 로컬 미디어 라이브러리 앱 (SwiftUI, Swift 6).  
이미지/영상 파일을 로컬 라이브러리에 정리하고, **WaterfallGrid**로 masonry(타일) 뷰를 제공하며, 타일 클릭 시 **라이트박스(모달) 뷰어**로 크게 감상할 수 있습니다.

## 요구 사항
- macOS 15.6 (Sequoia) 이상
- Xcode 16.x 이상 (Swift 6)
- 권장: Apple Silicon

## 주요 기능
- **로컬 라이브러리**: `~/Pictures/CaffeinOverdose.coffeelib/` 에 `media/`, `thumbs/`, `db.json` 생성/사용  
- **임포트**: 폴더/파일을 선택해 라이브러리로 복사 (중복 시 스킵)  
- **사이드바 탐색**: 폴더 트리 클릭 시 해당 폴더의 미디어가 우측 그리드에 표시  
- **Masonry 그리드**: 이미지/영상의 실제 비율에 맞춘 수직 그리드  
- **라이트박스 뷰어**: 타일 클릭 → 모달로 크게 보기
  - `←` `→` : 이전/다음
  - `Esc` : 닫기
  - `Space` : 동영상 재생/일시정지

## 프로젝트 구조

```
CaffeinOverdose/
├─ Models/ # MediaItem, MediaFolder, LibraryStore, etc.
├─ Utils/ # Importer, LibraryLocation, ThumbnailProvider
├─ ViewModels/ # LibraryViewModel
├─ Views/ # SidebarView, MasonryGridView, DetailView, ContentView
└─ CaffeinOverdoseApp.swift
```


## 빌드 & 실행
1. 저장소 클론 후 `CaffeinOverdose.xcodeproj` 열기
2. **Signing & Capabilities** 설정
   - **App Sandbox** 켜기
   - **Pictures Folder – Read/Write** ✅ (이 프로젝트는 App Store 배포가 목적이 아님)
   - (선택) User Selected File – Read/Write ✅
3. 실행 (⌘R)

앱 시작 시 `~/Pictures/CaffeinOverdose.coffeelib/` 경로가 자동 생성됩니다.

## 사용 방법
- 툴바의 **임포트** 버튼을 눌러 폴더 또는 개별 파일을 선택 → `media/`로 복사되어 라이브러리에 반영됩니다.
- 왼쪽 **사이드바**에서 폴더를 클릭하면 해당 폴더의 미디어가 우측 **Masonry 그리드**에 나타납니다.
- 타일을 클릭하면 **DetailView(라이트박스)** 가 모달로 열립니다. 키보드 단축키로 탐색/재생 제어가 가능합니다.

## 의존성
- [WaterfallGrid](https://github.com/paololeonardi/WaterfallGrid)
- AVKit / AVFoundation (영상 메타, 썸네일)
- AppKit (NSImage 등)

## 성능/안정성 메모
- 현재 썸네일은 생성 시 디스크 캐시(`thumbs/`)에 PNG로 저장합니다.
- SwiftUI + WaterfallGrid 조합에서 썸네일이 순차적으로 들어올 때 **`Bound preference … multiple times per frame`** 경고가 보일 수 있습니다. 기능에는 영향이 없지만, 추후 다음 개선을 고려합니다:
  - ImageIO(CGImageSource) 기반 다운샘플링으로 썸네일 생성 속도 개선
  - 프리패칭/프리히트 전략 도입
  - 그리드 레이아웃 재계산 최소화(고정 라인 높이, 배치 배리어 등) 옵션 추가

## 트러블슈팅
- **썸네일이 안 보이거나 스피너만 돎**  
  - 임포트 실패(권한/경로)로 대상 파일이 실제로 없을 수 있음 → 콘솔 로그 확인  
  - Importer는 **복사 성공 또는 대상 파일 존재** 시에만 `MediaItem`을 추가하도록 구현되어야 합니다.
- **권한 오류(NSCocoaErrorDomain Code=513)**  
  - 이 프로젝트는 `Pictures Folder – Read/Write` 권한을 전제로 합니다. Entitlements 설정을 확인하세요.

## 로그/디버깅 팁
- Xcode 콘솔에서 `Importer:` 또는 `Library ensure error:` 접두사 로그를 확인
- 필요 시 `LibraryLocation.ensureExists()` 호출 위치를 App 진입점에 배치하여 초기화 타이밍 보장

## 로드맵 (To-Do)
- [ ] 썸네일: ImageIO 다운샘플링 + 백그라운드 큐로 병렬 처리
- [ ] import 시 폴더만이 아닌 다른 형태의 파일까지 지원
- [ ] 동영상 미디어 지원 여부 확인
- [ ] 앱 내부에서 디렉토리 생성 기능
- [ ] 컨텍스트 메뉴로 폴더, 미디어 등 삭제
- [ ] 비효율적 코드베이스 리팩토링
- [ ] 폴더 변경 감지(FSEvents)로 자동 갱신
- [ ] 정렬/필터/검색
- [ ] EXIF/메타데이터 오버레이
- [ ] 슬라이드쇼/줌/회전 등 뷰어 고급 기능
- [ ] 뷰어 디자인 변경
- [ ] 앱 아이콘 넣기

## 라이선스
개인 프로젝트. 필요 시 LICENSE 추가 예정.
