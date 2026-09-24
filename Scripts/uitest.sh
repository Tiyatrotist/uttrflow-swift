#!/usr/bin/env bash
# Runs the UI suite against the bundle `make app` produced. Needs a windowing session, so it is
# not part of `make verify` and never runs headless.
set -euo pipefail

cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null 2>&1 || {
    printf 'xcodegen is not installed. brew install xcodegen\n' >&2
    exit 1
}

[[ -d dist/Uttrflow.app ]] || {
    printf 'dist/Uttrflow.app is not there. Run: make app\n' >&2
    exit 1
}

xcodegen generate --spec UITests/project.yml --project UITests --quiet

# xcodebuild refuses to write into a result bundle that is already there, so a second
# `make uitest` needs the prior one moved aside; see Scripts/uitest_result_path.sh.
result_bundle_path="$(./Scripts/uitest_result_path.sh dist/uitest.xcresult)"

xcodebuild test \
    -project UITests/UttrflowUITests.xcodeproj \
    -scheme UttrflowUITests \
    -destination 'platform=macOS,arch=arm64' \
    -resultBundlePath "$result_bundle_path" \
    "$@"
