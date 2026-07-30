#!/bin/bash

# FluidVoice Build Profile Router
# Defaults to the public OSS build, which skips private Fluid Intelligence.
#
# Usage:
#   ./build.sh                    # public OSS build
#   ./build.sh build              # public OSS build
#   ./build.sh public             # public OSS build
#   ./build.sh fi                 # private FI build
#   ./build.sh test               # signed tests using canonical DerivedData
#   ./build.sh test -only-testing:FluidTests/SomeTest

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PRIVATE_FI_BUILD_SCRIPT="${PROJECT_DIR}/build_with_FI_incremental.sh"

if [ "${1:-}" = "test" ]; then
    shift
    for argument in "$@"; do
        case "${argument}" in
            -only-testing:*) ;;
            *)
                echo "Unsupported test argument: ${argument}"
                echo "Only -only-testing:<test-identifier> selectors are accepted."
                exit 1
                ;;
        esac
    done

    echo "Running signed FluidVoice tests with canonical DerivedData..."
    cd "${PROJECT_DIR}"
    exec xcodebuild \
        -project Fluid.xcodeproj \
        -scheme Fluid \
        -configuration Debug \
        -destination 'platform=macOS' \
        -derivedDataPath "${PROJECT_DIR}/DerivedData" \
        test \
        "$@"
fi

if [ "${1:-}" = "build" ]; then
    shift
fi

if [ "$#" -gt 1 ]; then
    echo "Unexpected arguments: $*"
    exit 1
fi

PROFILE="${1:-${BUILD_PROFILE:-public}}"

case "${PROFILE}" in
    public|oss|incremental|fast)
        echo "Running public FluidVoice build without Fluid Intelligence..."
        cd "${PROJECT_DIR}"
        exec xcodebuild \
            -project Fluid.xcodeproj \
            -scheme Fluid \
            -configuration Debug \
            -destination 'platform=macOS' \
            -derivedDataPath "${PROJECT_DIR}/DerivedData" \
            build
        ;;
    fi|private|dev|full)
        if [ ! -x "${PRIVATE_FI_BUILD_SCRIPT}" ]; then
            echo "Private Fluid Intelligence build script is missing:"
            echo "  ${PRIVATE_FI_BUILD_SCRIPT}"
            echo "Restore the private FI build setup, then run: sh build_with_FI_incremental.sh"
            exit 1
        fi
        exec "${PRIVATE_FI_BUILD_SCRIPT}"
        ;;
    *)
        echo "Unknown build profile: ${PROFILE}"
        echo "Valid profiles: public/oss/incremental/fast, fi/private/dev/full"
        exit 1
        ;;
esac
