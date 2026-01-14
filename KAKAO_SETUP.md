# 카카오 로그인 설정 가이드

## 1. 카카오 개발자 콘솔 설정

1. [카카오 개발자 콘솔](https://developers.kakao.com/)에 접속하여 로그인
2. 내 애플리케이션 > 애플리케이션 추가하기
3. 앱 이름, 사업자명 입력 후 저장
4. 앱 키 확인
   - **네이티브 앱 키**: Android/iOS용
   - **JavaScript 키**: 웹용

## 2. 프로젝트 설정

### Android 설정

1. `android/app/src/main/AndroidManifest.xml`에 다음 추가:
```xml
<activity
    android:name="com.kakao.sdk.auth.AuthCodeHandlerActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="kakao{YOUR_NATIVE_APP_KEY}" />
    </intent-filter>
</activity>
```

2. `android/app/build.gradle`에 다음 추가:
```gradle
android {
    defaultConfig {
        manifestPlaceholders = [
            KAKAO_APP_KEY: "YOUR_NATIVE_APP_KEY"
        ]
    }
}
```

### iOS 설정

1. `ios/Runner/Info.plist`에 다음 추가:
```xml
<key>KAKAO_APP_KEY</key>
<string>YOUR_NATIVE_APP_KEY</string>
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>kakaokompassauth</string>
    <string>kakaolink</string>
    <string>kakaotalk</string>
</array>
```

2. `ios/Runner/Info.plist`의 URL Types에 추가:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>kakao{YOUR_NATIVE_APP_KEY}</string>
        </array>
    </dict>
</array>
```

## 3. 웹 설정

### 플랫폼 추가
1. 카카오 개발자 콘솔 > 내 애플리케이션 > 앱 설정 > 플랫폼
2. "Web 플랫폼 등록" 클릭
3. 사이트 도메인 등록 (예: `http://localhost:3000`, `https://yourdomain.com`)

### JavaScript 키 설정
1. 카카오 개발자 콘솔 > 내 애플리케이션 > 앱 키
2. JavaScript 키 복사

### 웹용 코드 설정
`lib/main.dart`에서 웹용 JavaScript 키도 설정하세요:

```dart
KakaoSdk.init(
  nativeAppKey: 'YOUR_KAKAO_NATIVE_APP_KEY', // Android/iOS용
  javaScriptAppKey: 'YOUR_KAKAO_JAVASCRIPT_KEY', // 웹용
);
```

### 웹 HTML 설정
`web/index.html`에 카카오 SDK 스크립트 추가:

```html
<!DOCTYPE html>
<html>
<head>
  <!-- 기존 head 내용 -->
  <script src="https://developers.kakao.com/sdk/js/kakao.js"></script>
  <script>
    // 카카오 SDK 초기화
    Kakao.init('YOUR_KAKAO_JAVASCRIPT_KEY');
  </script>
</head>
<body>
  <!-- 기존 body 내용 -->
</body>
</html>
```

## 4. 코드 설정

`lib/main.dart`에서 카카오 앱 키를 설정하세요:

```dart
KakaoSdk.init(
  nativeAppKey: 'YOUR_KAKAO_NATIVE_APP_KEY', // Android/iOS용
  javaScriptAppKey: 'YOUR_KAKAO_JAVASCRIPT_KEY', // 웹용 (선택사항)
);
```

## 4. 웹 설정

### 카카오 개발자 콘솔에서 웹 플랫폼 추가

1. 카카오 개발자 콘솔 > 내 애플리케이션 > 앱 설정 > 플랫폼
2. "Web 플랫폼 등록" 클릭
3. 사이트 도메인 등록
   - 로컬 개발: `http://localhost:포트번호` (예: `http://localhost:8080`)
   - 프로덕션: 실제 도메인 (예: `https://yourdomain.com`)
4. JavaScript 키 확인 (앱 키 섹션에서 확인)

### 웹용 코드 설정

`lib/main.dart`에서 웹용 JavaScript 키도 설정하세요:

```dart
KakaoSdk.init(
  nativeAppKey: 'YOUR_KAKAO_NATIVE_APP_KEY', // Android/iOS용
  javaScriptAppKey: 'YOUR_KAKAO_JAVASCRIPT_KEY', // 웹용
);
```

### web/index.html 설정

`web/index.html` 파일에 카카오 SDK 스크립트를 추가하세요:

```html
<!DOCTYPE html>
<html>
<head>
  <base href="$FLUTTER_BASE_HREF">
  
  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="언어 스트레칭">
  
  <!-- 카카오 SDK 스크립트 추가 -->
  <script src="https://developers.kakao.com/sdk/js/kakao.js"></script>
  <script>
    // 카카오 SDK 초기화
    Kakao.init('YOUR_KAKAO_JAVASCRIPT_KEY');
  </script>
  
  <!-- 기존 Flutter 스크립트 -->
  <script>
    // ...
  </script>
</head>
<body>
  <!-- 기존 body 내용 -->
</body>
</html>
```

### Firebase Console 웹 설정

1. Firebase Console > Authentication > Sign-in method
2. Kakao 제공업체 활성화
3. Kakao 앱 ID와 앱 시크릿 입력
   - 카카오 개발자 콘솔 > 내 애플리케이션 > 앱 키에서 확인
   - REST API 키를 사용할 수도 있습니다
4. 승인된 리디렉션 URI 설정
   - `https://YOUR_PROJECT_ID.firebaseapp.com/__/auth/handler`
   - 카카오 개발자 콘솔 > 내 애플리케이션 > 카카오 로그인 > Redirect URI에 위 URI 추가

## 5. Firebase 연동 설정

### Firebase Console 설정

1. Firebase Console > Authentication > Sign-in method로 이동
2. "Kakao" 제공업체 클릭하여 활성화
3. 다음 정보 입력:
   - **Kakao 앱 ID**: 카카오 개발자 콘솔 > 내 애플리케이션 > 앱 키 > REST API 키
   - **Kakao 앱 시크릿**: 카카오 개발자 콘솔 > 내 애플리케이션 > 앱 키 > Client Secret (생성 필요)
4. 승인된 리디렉션 URI 확인:
   - `https://YOUR_PROJECT_ID.firebaseapp.com/__/auth/handler`
   - `http://localhost:포트번호/__/auth/handler` (로컬 개발용)

### 카카오 개발자 콘솔에서 리디렉션 URI 설정

1. 카카오 개발자 콘솔 > 내 애플리케이션 > 카카오 로그인 > Redirect URI
2. 다음 URI 추가:
   - `https://YOUR_PROJECT_ID.firebaseapp.com/__/auth/handler`
   - `http://localhost:포트번호/__/auth/handler` (로컬 개발용, 예: `http://localhost:8080/__/auth/handler`)

### Client Secret 생성 (필수)

1. 카카오 개발자 콘솔 > 내 애플리케이션 > 앱 키
2. "Client Secret" 옆의 "생성" 버튼 클릭
3. 생성된 Client Secret을 복사하여 Firebase Console에 입력

### 웹에서의 Firebase 연동

웹에서는 Firebase Auth의 `KakaoAuthProvider`를 사용합니다. 코드는 이미 `AuthService`에 구현되어 있습니다.

### 모바일에서의 Firebase 연동

모바일에서는 카카오 SDK로 로그인한 후, 받은 토큰을 사용하여 Firebase Auth에 연동합니다. 코드는 이미 `AuthService`에 구현되어 있습니다.

### Firestore 사용자 정보 저장

카카오 로그인 성공 후, Firestore의 `users` 컬렉션에 사용자 정보가 자동으로 저장됩니다. `AuthService`에서 `FirestoreService.updateUserProfile`을 호출하여 처리합니다.

## 6. 테스트

### 웹 테스트
1. `flutter run -d chrome` 실행
2. 카카오 로그인 버튼 클릭
3. 카카오 로그인 완료 후 Firebase Auth에 연동 확인
4. Firestore에서 `users` 컬렉션에 사용자 정보 저장 확인

### 모바일 테스트
1. `flutter run` 실행
2. 카카오 로그인 버튼 클릭
3. 카카오톡 또는 카카오계정으로 로그인
4. Firebase Auth에 연동 확인
5. Firestore에서 `users` 컬렉션에 사용자 정보 저장 확인

## 7. 문제 해결

### "Invalid redirect URI" 오류
- 카카오 개발자 콘솔의 Redirect URI와 Firebase의 승인된 리디렉션 URI가 일치하는지 확인
- 로컬 개발 시 `http://localhost:포트번호` 형식 확인

### "Client Secret이 일치하지 않습니다" 오류
- Firebase Console에 입력한 Client Secret이 카카오 개발자 콘솔의 Client Secret과 일치하는지 확인
- Client Secret을 다시 생성한 경우 Firebase Console도 업데이트 필요

### 웹에서 로그인 실패
- `web/index.html`에 카카오 SDK 스크립트가 추가되었는지 확인
- JavaScript 키가 올바르게 설정되었는지 확인
- Firebase Console에서 Kakao 제공업체가 활성화되었는지 확인

### 모바일에서 Firebase 연동 실패
- 카카오 개발자 콘솔에서 Client Secret이 생성되었는지 확인
- Firebase Console의 Kakao 제공업체 설정이 올바른지 확인
- 카카오 SDK 초기화가 올바르게 되었는지 확인 (`lib/main.dart`)
