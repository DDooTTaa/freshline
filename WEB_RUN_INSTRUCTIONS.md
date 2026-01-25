# Flutter Web 실행 오류 해결 방법

## 문제
Flutter Web을 실행할 때 다음과 같은 셰이더 컴파일 오류가 발생할 수 있습니다:
```
ShaderCompilerException: Shader compilation of "stretch_effect.frag" failed with exit code -1073741819
```

이 오류는 Flutter의 Impeller 셰이더 컴파일러가 Windows에서 Material 3 셰이더를 컴파일할 때 발생하는 알려진 문제입니다.

## 해결 방법

### 방법 1: HTML 렌더러 사용 (권장)

HTML 렌더러를 사용하면 셰이더 컴파일이 필요 없어 오류를 우회할 수 있습니다.

#### PowerShell 사용:
```powershell
.\run_web.ps1
```

#### 배치 파일 사용:
```cmd
run_web.bat
```

#### 직접 명령어 실행:
```bash
flutter run -d chrome --web-renderer html
```

### 방법 2: 빌드 디렉토리 정리 후 재시도

때때로 빌드 캐시 문제일 수 있습니다:

```bash
flutter clean
flutter pub get
flutter run -d chrome --web-renderer html
```

### 방법 3: Material 3 완전 비활성화 (이미 적용됨)

`lib/main.dart`에서 `useMaterial3: false`가 이미 설정되어 있습니다. 
만약 여전히 오류가 발생한다면, 앱 내에서 Material 3 위젯을 사용하지 않는지 확인하세요.

## 참고사항

- HTML 렌더러는 CanvasKit 렌더러보다 성능이 낮을 수 있지만, 대부분의 앱에서는 차이를 느끼기 어렵습니다.
- CanvasKit 렌더러를 사용하려면 Flutter SDK를 ASCII 문자만 포함하는 경로에 설치하는 것을 권장합니다.
- 이 문제는 Flutter 팀에서 인지하고 있으며, 향후 버전에서 수정될 예정입니다.

## 추가 정보

- [Flutter Web 렌더러 문서](https://docs.flutter.dev/platform-integration/web/renderers)
- [Flutter GitHub 이슈](https://github.com/flutter/flutter/issues)
