# M&D Run Timer — iPhone 네이티브 앱

## 윈도우 11 → GitHub → Codemagic
1. GitHub에서 **Private** 저장소 `MDRunTimer`를 생성합니다. README 자동 생성은 꺼도 됩니다.
2. 이 ZIP을 PC에서 압축 해제합니다. `MDRunTimer.xcodeproj`, `MDRunTimer`, `codemagic.yaml`이 같은 최상위 폴더에 있어야 합니다.
3. GitHub 저장소에서 **Add file → Upload files**를 누르고 압축 해제한 폴더 **내부의 모든 항목**을 올립니다. 폴더 구조를 그대로 유지하세요. Commit changes를 누릅니다.
4. codemagic.io 로그인 → Add application → GitHub → Private 저장소 선택 → codemagic.yaml 사용.
5. `ios-compile-check` 실행. 이 작업은 **서명 없는 시뮬레이터 컴파일 검증**으로 아이폰 설치용 IPA가 생성되지 않습니다.
6. 빌드가 성공하면 Apple Developer Program 가입 및 iOS 코드 서명/배포용 워크플로를 별도로 설정해야 TestFlight 설치가 가능합니다.

## 주의
- 이 소스는 Mac/Xcode에서 실제 컴파일 검증되지 않았습니다. 최초 클라우드 빌드 결과를 확인해야 합니다.
- iOS 16 이상을 대상으로 합니다.
- 알림 권한을 허용해야 단계 전환 알림이 표시됩니다. 무음/집중 모드의 영향을 받습니다.
- 잠금 화면에서의 음성 낭독이나 백그라운드 연속 실행을 보장하지 않습니다.
- 프로젝트의 Bundle ID `com.mdaviation.runtimer`는 임시값입니다. 실제 서명 시 본인 고유 ID로 변경할 수 있습니다.
- Codemagic 과금과 머신 선택 가능 여부는 계정 플랜에 따라 달라집니다.
