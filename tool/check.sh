#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for package in notes_protocol notes_store; do
  (
    cd "packages/$package"
    dart --suppress-analytics pub get --enforce-lockfile
    dart format --output=none --set-exit-if-changed lib test
    dart analyze --fatal-infos
    dart --suppress-analytics test --reporter expanded
  )
done
