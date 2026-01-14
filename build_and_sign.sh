#!/bin/bash

# RustDesk 빌드 및 서명 스크립트
# 사용법: ./build_and_sign.sh [--skip-cargo] [--zip]

set -e

PROJECT_DIR="/Users/jeonjanghoon/rustdesk_payq"
APP_PATH="$PROJECT_DIR/flutter/build/macos/Build/Products/Release/RustDesk.app"

cd "$PROJECT_DIR"

echo "========================================"
echo "  RustDesk 빌드 시작"
echo "========================================"

# 옵션 파싱
SKIP_CARGO=""
CREATE_ZIP=false

for arg in "$@"; do
    case $arg in
        --skip-cargo)
            SKIP_CARGO="--skip-cargo"
            echo "[옵션] Cargo 빌드 건너뛰기"
            ;;
        --zip)
            CREATE_ZIP=true
            echo "[옵션] ZIP 파일 생성"
            ;;
    esac
done

# 빌드 실행
echo ""
echo "[1/3] Flutter 빌드 중..."
python3 build.py --flutter $SKIP_CARGO

# 앱 서명
echo ""
echo "[2/3] 앱 서명 중..."
if [ -d "$APP_PATH" ]; then
    # Frameworks 서명
    if [ -d "$APP_PATH/Contents/Frameworks" ]; then
        for framework in "$APP_PATH/Contents/Frameworks"/*; do
            if [ -e "$framework" ]; then
                codesign --force --deep --sign - "$framework" 2>/dev/null || true
            fi
        done
    fi

    # 앱 전체 서명
    codesign --force --deep --sign - "$APP_PATH"
    echo "서명 완료: $APP_PATH"
else
    echo "오류: 앱을 찾을 수 없습니다: $APP_PATH"
    exit 1
fi

# ZIP 생성 (옵션)
if [ "$CREATE_ZIP" = true ]; then
    echo ""
    echo "[3/3] ZIP 파일 생성 중..."
    cd "$PROJECT_DIR/flutter/build/macos/Build/Products/Release"
    rm -f RustDesk.zip
    ditto -c -k --sequesterRsrc --keepParent RustDesk.app RustDesk.zip
    echo "ZIP 생성 완료: $PROJECT_DIR/flutter/build/macos/Build/Products/Release/RustDesk.zip"
fi

echo ""
echo "========================================"
echo "  빌드 완료!"
echo "========================================"
echo "앱 위치: $APP_PATH"
echo ""
echo "실행: open \"$APP_PATH\""
echo "========================================"
