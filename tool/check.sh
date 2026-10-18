#!/usr/bin/env bash
set -euo pipefail
nada_project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$nada_project_dir/tool/env.sh"
cd "$nada_project_dir"
dart format --output=none --set-exit-if-changed lib test tool/youtube_smoke.dart
flutter analyze
flutter test
flutter build apk --debug
