# Firebase 설정 가이드

Firebase를 프로젝트에 연결하는 방법입니다.

## 1. Firebase 프로젝트 생성

1. [Firebase Console](https://console.firebase.google.com/)에 접속
2. "프로젝트 추가" 클릭
3. 프로젝트 이름 입력 (예: `language-stretching`)
4. Google Analytics 설정 (선택사항)
5. 프로젝트 생성 완료

## 2. FlutterFire CLI 설치 및 설정

### FlutterFire CLI 설치

```bash
dart pub global activate flutterfire_cli
```

### Firebase 프로젝트에 앱 등록

```bash
# 프로젝트 루트에서 실행
flutterfire configure
```

이 명령어를 실행하면:
- Firebase 프로젝트 선택
- 플랫폼 선택 (Android, iOS, Web 등)
- 자동으로 `firebase_options.dart` 파일 생성

## 3. Android 설정

### google-services.json 파일

1. Firebase Console에서 Android 앱 추가
2. 패키지 이름 입력: `com.example.language_stretching` (실제 패키지 이름으로 변경)
3. `google-services.json` 파일 다운로드
4. `android/app/` 폴더에 복사

### build.gradle 설정

`android/build.gradle` 파일에 추가:

```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

`android/app/build.gradle` 파일 맨 아래에 추가:

```gradle
apply plugin: 'com.google.gms.google-services'
```

## 4. iOS 설정

### GoogleService-Info.plist 파일

1. Firebase Console에서 iOS 앱 추가
2. 번들 ID 입력: `com.example.languageStretching` (실제 번들 ID로 변경)
3. `GoogleService-Info.plist` 파일 다운로드
4. Xcode에서 `ios/Runner/` 폴더에 추가

### Podfile 설정

`ios/Podfile` 파일에 추가:

```ruby
platform :ios, '12.0'
```

그리고 터미널에서:

```bash
cd ios
pod install
cd ..
```

## 5. Firebase 서비스 활성화

Firebase Console에서 다음 서비스를 활성화하세요:

### Authentication
1. Authentication > Sign-in method
2. Google 제공업체 활성화
3. 프로젝트 지원 이메일 설정

### Firestore Database
1. Firestore Database > 데이터베이스 만들기
2. 테스트 모드로 시작 (개발 중)
3. 위치 선택 (예: `asia-northeast3` - 서울)

### 보안 규칙 예시

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 사용자별 작품 저장
    match /users/{userId}/creations/{creationId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // 공개 작품
    match /public_creations/{creationId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
        (request.resource.data.diff(resource.data).affectedKeys()
         .hasOnly(['likeCount', 'likes']));
    }
  }
}
```

## 6. 패키지 설치

```bash
flutter pub get
```

## 7. 테스트

앱을 실행하여 Firebase 연결이 정상적으로 작동하는지 확인하세요.

## 문제 해결

### Android 빌드 오류
- `google-services.json` 파일이 올바른 위치에 있는지 확인
- `build.gradle` 파일에 플러그인이 추가되었는지 확인

### iOS 빌드 오류
- `GoogleService-Info.plist` 파일이 Xcode 프로젝트에 추가되었는지 확인
- `pod install` 실행 확인

### 인증 오류
- Firebase Console에서 Authentication이 활성화되었는지 확인
- Google Sign-In 설정이 올바른지 확인

## 참고 자료

- [Firebase Flutter 문서](https://firebase.flutter.dev/)
- [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/)
- [Firebase Console](https://console.firebase.google.com/)
