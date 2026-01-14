# RustDesk 빌드 가이드

소스 코드 수정 후 RustDesk를 빌드하는 방법을 설명합니다.

## 📋 목차

- [빠른 시작](#빠른-시작)
- [개발용 빌드 (Test)](#개발용-빌드-test)
- [프로덕션 빌드 (Prod)](#프로덕션-빌드-prod)
- [수동 빌드](#수동-빌드)
- [문제 해결](#문제-해결)

---

## 🚀 빠른 시작

### 개발/테스트용 (빠른 빌드)

```bash
./build-test.sh
```

**특징:**
- ⚡ 빠른 빌드 (1-2분)
- 🐛 디버그 심볼 포함
- 📦 단일 실행 파일
- 💻 터미널에서만 실행 가능

### 프로덕션용 (배포용)

```bash
./build-prod.sh
```

**특징:**
- 🏭 최적화된 빌드 (3-5분)
- 📱 macOS .app 번들
- 🖱️ Finder에서 더블클릭 가능
- 💿 DMG 설치 파일 생성 (선택)

---

## 🧪 개발용 빌드 (Test)

### 사용법

```bash
./build-test.sh
```

### 빌드 과정

1. Rust 바이너리 빌드 (debug 모드)
2. 실행 파일 생성: `target/debug/rustdesk`

### 실행 방법

```bash
# 터미널에서 실행
./target/debug/rustdesk
```

### 언제 사용?

- ✅ 코드 수정 후 빠른 테스트
- ✅ 디버깅
- ✅ 개발 중 기능 확인
- ❌ 배포용 (최적화 안 됨)

---

## 🏭 프로덕션 빌드 (Prod)

### 사용법

```bash
./build-prod.sh
```

### 빌드 과정

1. Rust 바이너리 빌드 (release 모드, 최적화)
2. macOS .app 번들 생성
3. 실행 파일 및 라이브러리 복사
4. Info.plist 수정
5. DMG 설치 파일 생성 (선택)

### 빌드 결과

- **앱 번들:** `target/release/bundle/osx/RustDesk.app`
- **DMG 파일:** `rustdesk-1.4.4.dmg` (선택 시)

### 실행 방법

```bash
# 터미널에서 실행
open target/release/bundle/osx/RustDesk.app

# 또는 Finder에서 더블클릭
# target/release/bundle/osx/RustDesk.app
```

### 언제 사용?

- ✅ 배포용 빌드
- ✅ Finder에서 실행 가능한 앱 필요 시
- ✅ 다른 사람에게 공유할 때
- ✅ 최종 테스트

---

## 🔧 수동 빌드

자동 스크립트를 사용하지 않고 수동으로 빌드하는 방법입니다.

### 개발용 빌드 (수동)

```bash
# debug 모드 빌드
cargo build --bin rustdesk --features inline

# 실행
./target/debug/rustdesk
```

### 프로덕션 빌드 (수동)

```bash
# 1. Release 빌드
cargo build --release --bin rustdesk --features inline

# 2. .app 번들 생성
cargo bundle --release --features inline

# 3. 실행 파일 복사
cp target/release/rustdesk \
   target/release/bundle/osx/RustDesk.app/Contents/MacOS/

# 4. Sciter 라이브러리 복사
cp target/release/libsciter.dylib \
   target/release/bundle/osx/RustDesk.app/Contents/MacOS/

# 5. Info.plist 수정
sed -i '' 's/<string>naming<\/string>/<string>rustdesk<\/string>/g' \
  target/release/bundle/osx/RustDesk.app/Contents/Info.plist

# 6. 실행
open target/release/bundle/osx/RustDesk.app
```

### DMG 생성 (수동)

```bash
# create-dmg 설치 (최초 1회)
brew install create-dmg

# DMG 생성
create-dmg "RustDesk 1.4.4.dmg" \
  "target/release/bundle/osx/RustDesk.app"
```

---

## 🛠️ 빌드 옵션

### Cargo Features

| Feature | 설명 | 사용 시기 |
|---------|------|----------|
| `inline` | UI 리소스를 바이너리에 포함 | 필수 (항상 사용) |
| `hwcodec` | 하드웨어 비디오 코덱 지원 | 성능 향상 필요 시 |
| `flutter` | Flutter UI 사용 (별도 빌드) | Flutter 앱 빌드 시만 |

### 하드웨어 코덱 빌드

```bash
# 개발용
cargo build --bin rustdesk --features inline,hwcodec

# 프로덕션용
cargo build --release --bin rustdesk --features inline,hwcodec
cargo bundle --release --features inline,hwcodec
```

---

## 📦 의존성 설치

RustDesk 빌드에는 다음 C++ 라이브러리가 필요합니다:

- **libyuv** - 비디오 처리
- **libvpx** - VP8/VP9 비디오 코덱
- **opus** - 오디오 코덱
- **aom** - AV1 비디오 코덱

### 자동 설치 (권장)

빌드 스크립트 실행 시 자동으로 vcpkg 설치를 안내합니다:

```bash
./build-test.sh  # 또는 ./build-prod.sh
# vcpkg 설치 여부를 물어봅니다 (y 입력)
```

### 수동 설치

직접 vcpkg를 설치하려면:

```bash
# 1. vcpkg 클론
git clone https://github.com/microsoft/vcpkg.git

# 2. vcpkg 부트스트랩
./vcpkg/bootstrap-vcpkg.sh

# 3. 환경 변수 설정
export VCPKG_ROOT=$(pwd)/vcpkg

# 4. 필요한 패키지 설치 (10-20분 소요)
./vcpkg/vcpkg install libvpx libyuv opus aom

# 5. 이후 빌드 시 항상 VCPKG_ROOT 설정 필요
export VCPKG_ROOT=$(pwd)/vcpkg
```

### 환경 변수 영구 설정 (선택)

```bash
# .zshrc 또는 .bashrc에 추가
echo 'export VCPKG_ROOT=/Users/jeonjanghoon/rustdesk_payq/vcpkg' >> ~/.zshrc
source ~/.zshrc
```

---

## 🐛 문제 해결

### 1. `Could not find package in /opt/homebrew/Cellar/libyuv`

**원인:** vcpkg가 설치되지 않았거나 환경 변수가 설정되지 않음

**해결:**
```bash
# 빌드 스크립트 사용 (자동으로 vcpkg 설치 안내)
./build-test.sh

# 또는 수동으로 vcpkg 설치 (위 "의존성 설치" 섹션 참고)
```

### 2. `cargo: command not found`

**원인:** Rust가 설치되지 않았거나 PATH가 설정되지 않음

**해결:**
```bash
# PATH 설정
export PATH="$HOME/.cargo/bin:$PATH"

# 또는 .zshrc에 추가
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### 3. `cargo-bundle: command not found`

**원인:** cargo-bundle이 설치되지 않음

**해결:**
```bash
cargo install cargo-bundle
```

### 4. Finder에서 더블클릭 시 흰 화면

**원인:** `inline` feature 없이 빌드하거나 .app 번들이 아닌 일반 바이너리 실행

**해결:**
- `build-prod.sh` 스크립트 사용
- 또는 `--features inline` 옵션으로 빌드
- .app 번들로 실행

### 5. `libsciter.dylib` 에러

**원인:** Sciter 라이브러리가 복사되지 않음

**해결:**
```bash
cp target/release/libsciter.dylib \
   target/release/bundle/osx/RustDesk.app/Contents/MacOS/
```

### 6. 빌드가 너무 느림

**원인:** Release 모드는 최적화 때문에 느림

**해결:**
- 개발 중에는 `build-test.sh` 사용 (debug 모드)
- 최종 테스트/배포 시만 `build-prod.sh` 사용

---

## 📊 빌드 시간 비교

| 빌드 타입 | 시간 | 파일 크기 | 용도 |
|----------|------|----------|------|
| vcpkg 설치 (최초 1회) | 10-20분 | - | 의존성 |
| Test (debug) | 1-2분 | ~20MB | 개발/디버깅 |
| Prod (release) | 3-5분 | ~45MB (앱 번들) | 배포 |

**참고:** vcpkg는 최초 1회만 설치하면 됩니다.

---

## 📝 자주 사용하는 명령어

```bash
# 개발용 빌드 + 실행
./build-test.sh

# 프로덕션 빌드 + DMG 생성
./build-prod.sh

# 빌드 결과물 정리
cargo clean

# 특정 바이너리만 빌드
cargo build --release --bin rustdesk --features inline

# 전체 재빌드
cargo clean && ./build-prod.sh
```

---

## 🔑 핵심 요약

### 개발 시

```bash
./build-test.sh        # 빠른 빌드
./target/debug/rustdesk  # 실행
```

### 배포 시

```bash
./build-prod.sh  # 프로덕션 빌드
# → target/release/bundle/osx/RustDesk.app
# → rustdesk-1.4.4.dmg (선택)
```

---

## 📌 참고사항

- **자체 서버 설정:** `src/common.rs:115-116`에 하드코딩됨
- **서버 주소:** `10.185.38.13`
- **서버 키:** `Kk52Nhpm6z0zMKNklC3XBlPslRgmjP3igPvAO5ZaUGg=`
- **UI 타입:** Sciter UI (Flutter 아님)

서버 설정을 변경하려면 `src/common.rs` 파일을 수정 후 다시 빌드하세요.
