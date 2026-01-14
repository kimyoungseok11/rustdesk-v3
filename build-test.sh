#!/bin/bash
# RustDesk 개발용 빌드 스크립트 (빠른 빌드, 디버그 모드)

set -e  # 에러 발생 시 중단

echo "🔨 RustDesk 개발용 빌드 시작..."
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

# 3. Rust 빌드 (debug 모드 - 빠름)
echo ""
echo "📦 Rust 바이너리 빌드 (debug 모드)..."
VCPKG_ROOT="$VCPKG_ROOT" cargo build --bin rustdesk --features inline

# 4. 빌드 결과 확인
if [ -f "target/debug/rustdesk" ]; then
    echo ""
    echo "✅ 빌드 완료!"
    echo ""
    echo "📍 실행 파일 위치:"
    echo "   $(pwd)/target/debug/rustdesk"
    echo ""
    echo "🚀 실행 방법:"
    echo "   ./target/debug/rustdesk"
    echo ""

    # 파일 크기 표시
    FILE_SIZE=$(du -h target/debug/rustdesk | cut -f1)
    echo "📊 파일 크기: $FILE_SIZE"
    echo ""

else
    echo "❌ 빌드 실패!"
    exit 1
fi
