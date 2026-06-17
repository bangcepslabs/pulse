# 📦 Android APK 빌드 가이드

## 🚀 빠른 빌드

### 1. Release APK 빌드
```bash
cd frontend
flutter build apk --release
```

빌드 완료 후 APK 위치:
```
frontend/build/app/outputs/flutter-apk/app-release.apk
```

### 2. APK 파일 찾기
```bash
# Windows PowerShell
explorer build\app\outputs\flutter-apk

# 또는 직접 경로
# F:\BangProject\frontend\build\app\outputs\flutter-apk\app-release.apk
```

---

## 📱 APK 설치 방법

### 방법 1: USB 케이블 연결
```bash
# 휴대폰을 USB로 연결 후
flutter install
```

### 방법 2: 파일 전송
1. `app-release.apk` 파일을 휴대폰으로 전송 (카카오톡, 이메일, USB 등)
2. 휴대폰에서 APK 파일 클릭
3. "출처를 알 수 없는 앱 설치" 허용
4. 설치 완료

---

## 🎯 버전 업데이트

새 버전으로 빌드하려면 `pubspec.yaml` 수정:

```yaml
version: 1.0.1+2  # 1.0.0+1 → 1.0.1+2
```

- `1.0.1`: 사용자에게 보이는 버전 (Version Name)
- `+2`: 내부 빌드 번호 (Version Code)

**규칙:**
- 작은 수정: `1.0.0` → `1.0.1`
- 기능 추가: `1.0.0` → `1.1.0`
- 큰 변경: `1.0.0` → `2.0.0`
- **빌드 번호는 항상 증가** (1 → 2 → 3...)

---

## 📦 APK 종류

### 1. 일반 APK (권장)
```bash
flutter build apk --release
```
- 파일명: `app-release.apk`
- 크기: 약 20-40MB
- 모든 CPU 아키텍처 포함 (arm, arm64, x86)
- **대부분의 기기에서 동작**

### 2. Split APK (고급)
```bash
flutter build apk --split-per-abi --release
```
- 3개 파일 생성:
  - `app-armeabi-v7a-release.apk` (32비트, 구형)
  - `app-arm64-v8a-release.apk` (64비트, 최신)
  - `app-x86_64-release.apk` (에뮬레이터)
- 각 파일 크기: 약 15-20MB
- 기기별로 적합한 APK 선택 필요

**대부분의 휴대폰은 `arm64-v8a`를 사용합니다.**

---

## 🔧 빌드 최적화

### 난독화 (ProGuard)
```bash
flutter build apk --release --obfuscate --split-debug-info=./debug-info
```

**효과:**
- 코드 크기 감소
- 역공학 방지
- 디버그 정보 분리

### APK 크기 줄이기
`android/app/build.gradle`:
```gradle
android {
    buildTypes {
        release {
            shrinkResources true  // 사용하지 않는 리소스 제거
            minifyEnabled true    // 코드 최적화
        }
    }
}
```

---

## 🐛 빌드 오류 해결

### 오류 1: Gradle 빌드 실패
```bash
cd frontend/android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk --release
```

### 오류 2: OutOfMemoryError
`android/gradle.properties`:
```properties
org.gradle.jvmargs=-Xmx4096m -XX:MaxPermSize=512m
```

### 오류 3: SDK 버전 오류
`android/app/build.gradle`:
```gradle
android {
    compileSdkVersion 34  // 최신 버전으로 업데이트
    defaultConfig {
        minSdkVersion 21   // 최소 Android 5.0
        targetSdkVersion 34
    }
}
```

---

## 📊 빌드 시간

| 작업 | 소요 시간 |
|------|----------|
| 첫 빌드 | 5-10분 |
| 두 번째 이후 | 2-5분 |
| `flutter clean` 후 | 5-10분 |

---

## ✅ 빌드 체크리스트

빌드 전 확인사항:

- [ ] `pubspec.yaml`의 버전 번호 업데이트
- [ ] API URL이 Cloudflare Workers 주소로 설정됨
- [ ] 테스트 실행 확인 (`flutter run`)
- [ ] 인터넷 권한 확인 (`AndroidManifest.xml`)
- [ ] 앱 아이콘 설정 완료
- [ ] `flutter clean` 실행 (권장)

빌드 후 확인사항:

- [ ] APK 파일 생성 확인
- [ ] 파일 크기 확인 (20-40MB 정상)
- [ ] 실제 기기에서 설치 테스트
- [ ] 네트워크 기능 테스트 (WiFi, LTE)
- [ ] 기사 로딩 확인
- [ ] 카테고리 탭 전환 확인

---

## 🎉 현재 변경사항 (새 APK 필요)

1. ✅ `published` 필드 추가 → 기사 출간 시간 정확하게 표시
2. ✅ Mock 데이터 제거 → 실제 API 데이터만 사용
3. ✅ 시간 표시 수정 → 기사 시간이 정확하게 나옴

**새 APK로 업데이트하면 시간 표시 오류가 해결됩니다!** 🎯

---

## 🚀 지금 빌드하기

```bash
cd frontend

# 클린 빌드 (권장)
flutter clean
flutter pub get
flutter build apk --release

# 빌드 완료 후
explorer build\app\outputs\flutter-apk
```

**생성된 파일:**
```
app-release.apk  (약 20-40MB)
```

이 파일을 휴대폰으로 전송해서 설치하세요! 📱
