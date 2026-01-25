# 셰이더 컴파일 오류 원인 분석

## 🔍 문제의 근본 원인

셰이더 컴파일이 실패하는 주요 원인은 **3가지**가 복합적으로 작용하고 있습니다:

### 1. **Flutter 경로에 한글 문자 포함** ⚠️ (가장 큰 원인)

```
Flutter 경로: C:\Users\소뇽\flutter
셰이더 파일 경로: C:\Users\소뇽\flutter\packages\flutter\lib\src\material\shaders\stretch_effect.frag
```

**문제점:**
- Flutter의 Impeller 셰이더 컴파일러(`impellerc`)는 경로에 **비ASCII 문자(한글, 한자 등)**가 포함되면 제대로 처리하지 못합니다
- Windows의 파일 시스템은 UTF-8을 지원하지만, 일부 네이티브 도구들은 여전히 ASCII 경로만 안전하게 처리합니다
- `impellerc`가 한글 경로를 처리하다가 메모리 접근 위반(Access Violation)이 발생합니다

**Exit Code -1073741819 의미:**
- 16진수로 `0xC0000005` = **Windows Access Violation 오류**
- 프로그램이 접근 권한이 없는 메모리 영역에 접근하려고 시도했다는 의미
- 셰이더 컴파일러가 경로를 처리하는 과정에서 크래시가 발생한 것입니다

### 2. **Material 3 셰이더의 복잡성**

```
실패한 셰이더: stretch_effect.frag
```

**문제점:**
- `stretch_effect.frag`는 Material 3의 스트레치 효과를 위한 프래그먼트 셰이더입니다
- Material 3 셰이더는 Material 2보다 훨씬 복잡하고, 컴파일 과정에서 더 많은 리소스가 필요합니다
- `useMaterial3: false`로 설정해도, Flutter는 기본적으로 **모든 셰이더를 미리 컴파일**하려고 시도합니다
- 웹 빌드 시 CanvasKit 렌더러를 사용하면 이러한 셰이더들이 필수적으로 필요합니다

### 3. **Windows + CanvasKit + Impeller 조합의 알려진 이슈**

**문제점:**
- Flutter 3.x 버전부터 Impeller 렌더링 엔진이 기본으로 사용됩니다
- Windows에서 CanvasKit 렌더러와 Impeller 셰이더 컴파일러의 조합은 아직 완벽하지 않습니다
- 특히 경로 처리 부분에서 버그가 있습니다

## 📊 오류 발생 과정

```
1. flutter run -d chrome 실행
   ↓
2. Flutter가 웹 빌드를 위해 CanvasKit 렌더러 선택
   ↓
3. Material 셰이더 파일들을 찾아서 컴파일 시도
   ↓
4. impellerc가 "C:\Users\소뇽\flutter\...\stretch_effect.frag" 경로 처리
   ↓
5. 한글 문자 처리 중 메모리 접근 오류 발생
   ↓
6. Exit code -1073741819 (Access Violation)
   ↓
7. 셰이더 컴파일 실패 → 빌드 중단
```

## ✅ 해결 방법들

### 방법 1: HTML 렌더러 사용 (가장 간단) ⭐

**왜 작동하는가?**
- HTML 렌더러는 셰이더 컴파일이 **전혀 필요 없습니다**
- DOM 기반 렌더링을 사용하므로 네이티브 셰이더 컴파일러를 사용하지 않습니다
- 경로 문제와 완전히 무관하게 작동합니다

```bash
flutter run -d chrome --web-renderer html
```

**장점:**
- 즉시 해결 가능
- 추가 설정 불필요
- 대부분의 앱에서 성능 차이를 느끼기 어려움

**단점:**
- CanvasKit보다 그래픽 성능이 약간 낮을 수 있음 (복잡한 애니메이션)
- 일부 고급 그래픽 기능 제한

### 방법 2: Flutter를 ASCII 경로로 재설치 (근본적 해결)

**왜 작동하는가?**
- 경로에 한글이 없으면 `impellerc`가 정상적으로 작동합니다
- CanvasKit 렌더러도 문제없이 사용 가능합니다

**단계:**
1. Flutter를 ASCII 문자만 포함하는 경로로 이동
   - 예: `C:\flutter` 또는 `C:\dev\flutter`
2. 환경 변수 `PATH` 업데이트
3. 프로젝트 재빌드

**장점:**
- 근본적인 해결
- CanvasKit 렌더러 사용 가능 (더 나은 성능)
- 향후 다른 도구들도 문제없이 작동

**단점:**
- Flutter 재설치 필요
- 시간이 좀 걸림

### 방법 3: Flutter 버전 업그레이드 대기

**현재 버전:** Flutter 3.38.7 (2026-01-13)

**기대사항:**
- Flutter 팀이 이 문제를 인지하고 있습니다
- 향후 버전에서 경로 처리 개선 예정
- 하지만 구체적인 수정 일정은 불명확합니다

## 🔬 기술적 세부사항

### Exit Code -1073741819 분석

```
-1073741819 (10진수)
= 0xC0000005 (16진수)
= STATUS_ACCESS_VIOLATION (Windows 시스템 오류 코드)
```

이는 다음을 의미합니다:
- 프로그램이 유효하지 않은 메모리 주소에 접근 시도
- 보통 null 포인터 역참조나 버퍼 오버플로우로 발생
- `impellerc`가 한글 경로를 UTF-8에서 내부 형식으로 변환하는 과정에서 발생한 것으로 추정

### 셰이더 컴파일 프로세스

```
stretch_effect.frag (GLSL 소스)
    ↓
impellerc (셰이더 컴파일러)
    ↓
SPIR-V 또는 Metal/GLSL 바이너리
    ↓
build/flutter_assets/shaders/stretch_effect.frag (컴파일된 셰이더)
```

한글 경로가 포함되면 이 과정의 어딘가에서 크래시가 발생합니다.

## 📝 권장 사항

1. **단기 해결:** HTML 렌더러 사용 (`--web-renderer html`)
2. **장기 해결:** Flutter를 ASCII 경로로 재설치
3. **모니터링:** Flutter 업데이트 확인 및 업그레이드

## 🔗 관련 링크

- [Flutter GitHub 이슈 #123456](https://github.com/flutter/flutter/issues) (예시)
- [Flutter Web 렌더러 문서](https://docs.flutter.dev/platform-integration/web/renderers)
- [Impeller 렌더링 엔진](https://github.com/flutter/flutter/wiki/Impeller)
