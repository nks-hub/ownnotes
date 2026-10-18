#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .artifacts
exec 9>.artifacts/flutter-test.lock
flock 9
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
cd apps/mobile
flutter --suppress-analytics pub get --enforce-lockfile
flutter --suppress-analytics gen-l10n
dart format --output=none --set-exit-if-changed lib test
flutter --suppress-analytics analyze --no-pub
flutter --suppress-analytics test --no-pub --reporter expanded
