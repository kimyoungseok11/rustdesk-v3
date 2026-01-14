# RustDesk 빌드 빠른 시작

자체 서버용 RustDesk 빌드 가이드입니다.

## ⚡ 빠른 시작

### 최초 빌드 (의존성 설치 필요)

```bash
# 1. 빌드 스크립트 실행
./build-test.sh

# 2. vcpkg 설치 안내가 나오면 'y' 입력
# → 10-20분 소요 (최초 1회만)

# 3. 빌드 완료 후 실행
./target/debug/rustdesk
```

### 이후 빌드 (의존성 설치 완료 후)

```bash
# 개발/테스트용 (빠름, 1-2분)
./build-test.sh

# 프로덕션용 (.app 번들, 3-5분)
./build-prod.sh
```

---

## 📋 빌드 스크립트

### `build-test.sh` - 개발/테스트용

```bash
./build-test.sh
```

**특징:**
- ⚡ 빠른 빌드 (1-2분)
- 🐛 디버그 모드
- 💻 터미널 전용
- 🔄 코드 수정 후 빠른 테스트용

**실행:**
```bash
./target/debug/rustdesk
```

### `build-prod.sh` - 프로덕션/배포용

```bash
./build-prod.sh
```

**특징:**
- 🏭 최적화 빌드 (3-5분)
- 📱 macOS .app 번들
- 🖱️ Finder에서 더블클릭 가능
- 💿 DMG 설치 파일 생성 가능

**실행:**
```bash
open target/release/bundle/osx/RustDesk.app
# 또는 Finder에서 더블클릭
```

---

## 🔧 의존성

RustDesk 빌드에는 다음이 필요합니다:

### 자동 설치 (권장)
빌드 스크립트가 자동으로 설치를 안내합니다.

### 수동 설치

```bash
# vcpkg (C++ 패키지 매니저)
git clone https://github.com/microsoft/vcpkg.git
./vcpkg/bootstrap-vcpkg.sh
export VCPKG_ROOT=$(pwd)/vcpkg

# C++ 라이브러리 설치 (10-20분 소요)
./vcpkg/vcpkg install libvpx libyuv opus aom

# cargo-bundle (macOS .app 번들 생성, 프로덕션 빌드 시)
cargo install cargo-bundle
```

---

## 🎯 사용 시나리오

### 코드 수정 후 빠른 테스트

```bash
# 1. 코드 수정
vim src/common.rs

# 2. 빠른 빌드
./build-test.sh

# 3. 실행
./target/debug/rustdesk
```

### 배포용 빌드

```bash
# 프로덕션 빌드
./build-prod.sh

# 결과:
# - target/release/bundle/osx/RustDesk.app
# - rustdesk-1.4.4.dmg (선택)
```

---

## 🐛 문제 해결

### `Could not find package in /opt/homebrew/Cellar/libyuv`

vcpkg가 설치되지 않았습니다.

```bash
# 빌드 스크립트 실행 시 'y' 선택
./build-test.sh
```

### Finder에서 더블클릭 시 흰 화면

.app 번들을 사용해야 합니다.

```bash
./build-prod.sh
```

### 빌드가 너무 느림

개발 중에는 test 빌드를 사용하세요.

```bash
./build-test.sh  # 빠름 (1-2분)
```

---

## 📖 자세한 가이드

전체 빌드 가이드는 [BUILD_GUIDE.md](BUILD_GUIDE.md)를 참고하세요.

```bash
cat BUILD_GUIDE.md
```

---

## 🔑 자체 서버 설정

현재 자체 서버가 하드코딩되어 있습니다:

- **파일:** `src/common.rs:115-116`
- **서버:** `10.185.38.13`
- **키:** `Kk52Nhpm6z0zMKNklC3XBlPslRgmjP3igPvAO5ZaUGg=`

서버 설정 변경 후 다시 빌드하세요.

---

## 📊 빌드 시간

| 작업 | 시간 | 빈도 |
|------|------|------|
| vcpkg 설치 | 10-20분 | 최초 1회 |
| 개발용 빌드 | 1-2분 | 매번 |
| 프로덕션 빌드 | 3-5분 | 배포 시 |

---

## 💡 팁

- **개발 중**: `build-test.sh` 사용 (빠름)
- **배포 전**: `build-prod.sh` 사용 (최적화)
- **DMG 생성**: `brew install create-dmg` 후 프로덕션 빌드
- **클린 빌드**: `cargo clean && ./build-prod.sh`

---

## 📞 도움말

문제가 발생하면:

1. [BUILD_GUIDE.md](BUILD_GUIDE.md) 확인
2. 에러 메시지 확인
3. vcpkg가 설치되었는지 확인: `ls -la vcpkg`
4. 클린 빌드 시도: `cargo clean`
