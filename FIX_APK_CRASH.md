# 🔧 APK 크래시 해결 가이드

## 🔍 크래시 로그 확인 (필수!)

```bash
# USB로 휴대폰 연결 후
adb devices

# Flutter 관련 로그
adb logcat | findstr Flutter

# 크래시 로그
adb logcat | findstr "FATAL AndroidRuntime Exception"

# 또는 전체 에러 로그
adb logcat *:E
```

**로그 없이는 정확한 원인 파악 불가!**

---

## 🎯 가장 흔한 크래시 원인

### 1. 인터넷 권한 문제 (가장 가능성 높음)

**확인:** `frontend/android/app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- 이 두 줄이 있는지 확인! -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    
    <application
        android:usesCleartextTraffic="true">  <!-- 이것도 확인! -->
        ...
    </application>
</manifest>
```

### 2. ProGuard 문제 (Release 빌드만 크래시)

**해결:** ProGuard 규칙 추가

**파일 생성:** `frontend/android/app/proguard-rules.pro`

```proguard
# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# HTTP package
-keep class dart.** { *; }
-keep class com.google.** { *; }

# Don't obfuscate
-dontobfuscate
```

**`build.gradle.kts` 수정:**

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
        
        // ProGuard 활성화
        minifyEnabled true
        shrinkResources true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```

### 3. 패키지명 불일치

**확인:**
```bash
# MainActivity.kt가 올바른 위치에 있는지
dir frontend\android\app\src\main\kotlin\com\example\bang_project_frontend\MainActivity.kt
```

**MainActivity.kt 내용:**
```kotlin
package com.example.bang_project_frontend  // 이것과

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
```

**build.gradle.kts:**
```kotlin
namespace = "com.example.bang_project_frontend"  // 이것이 일치해야 함
applicationId = "com.example.bang_project_frontend"
```

### 4. Kotlin 버전 문제

**`frontend/android/settings.gradle.kts` 확인:**

```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.1.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.0" apply false
}
```

### 5. MinSdkVersion 너무 낮음

**`build.gradle.kts`:**
```kotlin
defaultConfig {
    minSdk = 21  // Android 5.0 이상으로 설정
    targetSdk = 34
}
```

---

## ✅ 즉시 시도할 해결책

### 1단계: 디버그 APK로 테스트

```bash
cd frontend

# 디버그 빌드 (더 많은 로그 포함)
flutter build apk --debug

# 설치
flutter install

# 로그 확인
adb logcat | findstr Flutter
```

디버그 APK는 더 많은 에러 정보를 제공합니다!

### 2단계: ProGuard 비활성화

**`build.gradle.kts` 수정:**

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
        
        // ProGuard 완전 비활성화
        minifyEnabled false
        shrinkResources false
    }
}
```

```bash
flutter clean
flutter build apk --release
```

### 3단계: 완전 클린 빌드

```bash
cd frontend

# 완전히 정리
flutter clean
Remove-Item -Recurse -Force android\.gradle
Remove-Item -Recurse -Force android\build
Remove-Item -Recurse -Force build

# 재빌드
flutter pub get
flutter build apk --release --verbose
```

---

## 🧪 크래시 원인 진단

### A. 앱이 즉시 크래시 (0-1초)
→ **패키지명 불일치** 또는 **MainActivity 문제**

### B. 흰 화면 후 크래시 (2-3초)
→ **초기화 에러** (main.dart 문제)

### C. 네트워크 요청 시 크래시
→ **인터넷 권한 누락** 또는 **cleartext traffic**

### D. Release만 크래시, Debug는 정상
→ **ProGuard/R8 최적화 문제**

---

## 🎯 가장 가능성 높은 해결책

### 해결책 1: AndroidManifest.xml 확인

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    
    <application
        android:label="Pulse"
        android:usesCleartextTraffic="true"
        android:icon="@mipmap/ic_launcher">
```

### 해결책 2: ProGuard 비활성화

```kotlin
// build.gradle.kts
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
        minifyEnabled = false  // ← 추가
        shrinkResources = false  // ← 추가
    }
}
```

### 해결책 3: 디버그 APK 사용

```bash
flutter build apk --debug
```

디버그 APK도 실제 기기에서 정상 작동하며, 크래시 시 더 자세한 로그를 제공합니다!

---

## 📱 크래시 로그 보는 법

### Android Studio 사용
1. Android Studio 열기
2. Logcat 탭 열기
3. 휴대폰 USB 연결
4. 앱 실행
5. 로그에서 빨간색 에러 확인

### ADB 사용
```bash
# 실시간 로그
adb logcat | findstr "flutter"

# 파일로 저장
adb logcat > crash_log.txt

# 크래시 직전 로그만
adb logcat -b crash
```

---

## 🚀 빠른 해결 시나리오

### 시나리오 1: 인터넷 권한 문제
```xml
<!-- AndroidManifest.xml에 추가 -->
<uses-permission android:name="android.permission.INTERNET" />
```
```bash
flutter build apk --release
```

### 시나리오 2: ProGuard 문제
```kotlin
// build.gradle.kts
minifyEnabled = false
```
```bash
flutter clean
flutter build apk --release
```

### 시나리오 3: 패키지명 문제
```bash
# 패키지 구조 확인
dir android\app\src\main\kotlin\com\example\bang_project_frontend
```

---

## 💡 임시 해결책

**지금 당장 작동하는 APK 필요하다면:**

```bash
# 디버그 APK 빌드 (안정적)
flutter build apk --debug

# 생성 위치:
# build/app/outputs/flutter-apk/app-debug.apk
```

디버그 APK는:
- ✅ 크래시 가능성 낮음
- ✅ 더 많은 로그 제공
- ✅ 실제 기기에서 정상 작동
- ❌ 파일 크기 약간 큼 (~50MB)
- ❌ 성능 약간 느림

---

## 🎯 결론

**1순위: 로그 확인**
```bash
adb logcat | findstr Flutter
```

**2순위: ProGuard 비활성화**
```kotlin
minifyEnabled = false
shrinkResources = false
```

**3순위: 디버그 APK 사용**
```bash
flutter build apk --debug
```

**크래시 로그를 보여주시면 정확한 해결책을 드릴 수 있습니다!** 🔍
