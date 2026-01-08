# 구글 로그인 설정 가이드

구글 로그인을 사용하기 위해 다음 설정이 필요합니다.

## Android 설정

### 1. Google Cloud Console에서 OAuth 2.0 클라이언트 ID 생성

1. [Google Cloud Console](https://console.cloud.google.com/)에 접속
2. 새 프로젝트 생성 또는 기존 프로젝트 선택
3. "API 및 서비스" > "사용자 인증 정보"로 이동
4. "사용자 인증 정보 만들기" > "OAuth 클라이언트 ID" 선택
5. 애플리케이션 유형: Android 선택
6. 패키지 이름: `com.example.language_stretching` (또는 실제 패키지 이름)
7. SHA-1 인증서 지문 추가:
   ```bash
   # 디버그 키스토어의 SHA-1 확인
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
8. 생성된 클라이언트 ID를 복사

### 2. Android 앱 설정

`android/app/build.gradle` 파일에 다음을 추가:

```gradle
android {
    defaultConfig {
        // ... 기존 설정 ...
        resValue "string", "default_web_client_id", "YOUR_WEB_CLIENT_ID"
    }
}
```

`android/app/src/main/AndroidManifest.xml`에 인터넷 권한 확인:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

## iOS 설정

### 1. Google Cloud Console에서 iOS 클라이언트 ID 생성

1. Google Cloud Console에서 "OAuth 클라이언트 ID" 생성
2. 애플리케이션 유형: iOS 선택
3. 번들 ID 입력 (예: `com.example.languageStretching`)
4. 클라이언트 ID 복사

### 2. iOS 앱 설정

`ios/Runner/Info.plist`에 URL 스킴 추가:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

## 테스트

앱을 실행하고 구글 로그인 버튼을 눌러 로그인이 정상적으로 작동하는지 확인하세요.

## 참고 자료

- [google_sign_in 패키지 문서](https://pub.dev/packages/google_sign_in)
- [Google Sign-In 설정 가이드](https://developers.google.com/identity/sign-in/android/start-integrating)
