#!/bin/bash
# RustDesk 프로덕션 빌드 스크립트 (최적화 빌드 + .app 번들)

set -e  # 에러 발생 시 중단

echo "🏭 RustDesk 프로덕션 빌드 시작..."
echo ""

# 프로젝트 루트로 이동
cd "$(dirname "$0")"

# PATH 설정
export PATH="$HOME/.cargo/bin:$PATH"

# vcpkg 의존성 설정
setup_vcpkg() {
    echo "🔍 vcpkg 의존성 확인 중..."

    # vcpkg가 이미 설치되어 있는지 확인
    if [ -d "vcpkg" ]; then
        echo "✅ vcpkg가 이미 설치되어 있습니다."
        VCPKG_ROOT_PATH="$(pwd)/vcpkg"
        return 0
    fi

    # vcpkg_installed 디렉토리가 있는지 확인 (이미 설치된 경우)
    if [ -d "vcpkg_installed" ]; then
        echo "✅ vcpkg 패키지가 이미 설치되어 있습니다."
        # vcpkg_installed가 있으면 프로젝트 루트를 VCPKG_ROOT로 사용
        VCPKG_ROOT_PATH="$(pwd)"
        return 0
    fi

    # vcpkg 설치 필요
    echo "⚠️  vcpkg가 설치되지 않았습니다."
    echo ""
    echo "RustDesk는 다음 C++ 라이브러리가 필요합니다:"
    echo "  - libyuv (비디오 처리)"
    echo "  - libvpx (비디오 코덱)"
    echo "  - opus (오디오 코덱)"
    echo "  - aom (비디오 코덱)"
    echo ""
    read -p "vcpkg를 설치하고 의존성을 설정하시겠습니까? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ vcpkg 없이는 빌드할 수 없습니다."
        echo ""
        echo "💡 수동 설치 방법:"
        echo "   git clone https://github.com/microsoft/vcpkg.git"
        echo "   ./vcpkg/bootstrap-vcpkg.sh"
        echo "   export VCPKG_ROOT=\$(pwd)/vcpkg"
        echo "   ./vcpkg/vcpkg install libvpx libyuv opus aom"
        exit 1
    fi

    echo ""
    echo "📦 vcpkg 설치 중... (시간이 걸릴 수 있습니다)"

    # vcpkg 클론
    git clone https://github.com/microsoft/vcpkg.git

    # vcpkg 부트스트랩
    ./vcpkg/bootstrap-vcpkg.sh

    VCPKG_ROOT_PATH="$(pwd)/vcpkg"

    # 필요한 패키지 설치
    echo ""
    echo "📚 필요한 C++ 라이브러리 설치 중..."
    echo "   (이 작업은 10-20분 정도 걸릴 수 있습니다)"

    ./vcpkg/vcpkg install libvpx libyuv opus aom

    echo ""
    echo "✅ vcpkg 설정 완료!"
}

# 1. vcpkg 의존성 확인 및 설정
setup_vcpkg

# 2. 환경 변수 설정
if [ ! -z "$VCPKG_ROOT_PATH" ]; then
    export VCPKG_ROOT="$VCPKG_ROOT_PATH"
    # vcpkg_installed 디렉토리가 있으면 설정
    if [ -d "$VCPKG_ROOT_PATH/vcpkg_installed" ]; then
        export VCPKG_INSTALLED_ROOT="$VCPKG_ROOT_PATH/vcpkg_installed"
        echo "🔧 VCPKG_ROOT 설정: $VCPKG_ROOT"
        echo "🔧 VCPKG_INSTALLED_ROOT 설정: $VCPKG_INSTALLED_ROOT"
    else
        echo "🔧 VCPKG_ROOT 설정: $VCPKG_ROOT"
    fi
fi

# 3. cargo-bundle 설치 확인
echo ""
if ! command -v cargo-bundle &> /dev/null; then
    echo "⚠️  cargo-bundle이 설치되지 않았습니다."
    read -p "지금 설치하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "📦 cargo-bundle 설치 중..."
        cargo install cargo-bundle
    else
        echo "❌ cargo-bundle이 필요합니다. 종료합니다."
        exit 1
    fi
fi

# 4. Rust 바이너리 빌드 (release 모드)
echo ""
echo "📦 Rust 바이너리 빌드 (release 모드)..."
VCPKG_ROOT="$VCPKG_ROOT" cargo build --release --bin rustdesk --features inline

# 5. .app 번들 생성
echo "📱 macOS .app 번들 생성 중..."
VCPKG_ROOT="$VCPKG_ROOT" cargo bundle --release --features inline

# 6. 올바른 실행 파일 복사
echo "📋 실행 파일 복사 중..."
cp target/release/rustdesk target/release/bundle/osx/RustDesk.app/Contents/MacOS/

# 7. Sciter 라이브러리 복사
echo "📚 Sciter 라이브러리 복사 중..."
cp target/release/libsciter.dylib target/release/bundle/osx/RustDesk.app/Contents/MacOS/

# 8. Info.plist 수정 (naming → rustdesk)
echo "🔧 Info.plist 수정 중..."
sed -i '' 's/<string>naming<\/string>/<string>rustdesk<\/string>/g' \
  target/release/bundle/osx/RustDesk.app/Contents/Info.plist

# 9. 빌드 정보 표시
echo ""
echo "✅ 프로덕션 빌드 완료!"
echo ""
echo "📍 .app 번들 위치:"
echo "   $(pwd)/target/release/bundle/osx/RustDesk.app"
echo ""

# 파일 크기 표시
APP_SIZE=$(du -sh target/release/bundle/osx/RustDesk.app | cut -f1)
echo "📊 앱 크기: $APP_SIZE"
echo ""

# 10. DMG 생성 여부 확인
if command -v create-dmg &> /dev/null; then
    read -p "DMG 설치 파일을 생성하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "💿 DMG 파일 생성 중..."

        # 기존 DMG 삭제
        rm -f rustdesk-*.dmg

        # 버전 읽기
        VERSION=$(grep '^version' Cargo.toml | head -1 | sed 's/.*"\(.*\)".*/\1/')

        # DMG 생성
        create-dmg \
          --volname "RustDesk $VERSION" \
          --window-pos 200 120 \
          --window-size 800 400 \
          --icon-size 100 \
          --app-drop-link 600 185 \
          "rustdesk-${VERSION}.dmg" \
          "target/release/bundle/osx/RustDesk.app" 2>/dev/null || \
        create-dmg "rustdesk-${VERSION}.dmg" "target/release/bundle/osx/RustDesk.app"

        if [ -f "rustdesk-${VERSION}.dmg" ]; then
            DMG_SIZE=$(du -h "rustdesk-${VERSION}.dmg" | cut -f1)
            echo ""
            echo "✅ DMG 파일 생성 완료!"
            echo "📦 DMG 위치: $(pwd)/rustdesk-${VERSION}.dmg"
            echo "📊 DMG 크기: $DMG_SIZE"
        fi
    fi
else
    echo "💡 팁: create-dmg를 설치하면 DMG 설치 파일을 생성할 수 있습니다."
    echo "   설치: brew install create-dmg"
fi

echo ""
echo "   실행 방법:"
echo "   open target/release/bundle/osx/RustDesk.app"
echo ""
echo "   또는 Finder에서 더블클릭:"
echo "   target/release/bundle/osx/RustDesk.app"
echo ""
