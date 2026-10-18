#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../packages/notes_protocol"
dart pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
dart analyze --fatal-infos
dart test --reporter expanded
