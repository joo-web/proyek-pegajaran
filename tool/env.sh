#!/usr/bin/env bash
# Source this file before Flutter/Android commands in the cloud workspace.
export NADA_TOOLS_DIR="${NADA_TOOLS_DIR:-/workspace/tools}"
if [[ -x "$NADA_TOOLS_DIR/jdk-17/bin/javac" ]]; then
  export JAVA_HOME="$NADA_TOOLS_DIR/jdk-17"
  export PATH="$JAVA_HOME/bin:$PATH"
fi
export ANDROID_HOME="${ANDROID_HOME:-$NADA_TOOLS_DIR/android-sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="${ANDROID_USER_HOME:-/workspace/.cache/nada/android}"
export PUB_CACHE="${PUB_CACHE:-/workspace/.cache/nada/pub}"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-/workspace/.cache/nada/gradle}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/workspace/.cache/nada/config}"
export FLUTTER_SUPPRESS_ANALYTICS=true
# Dart subprocesses also suppress analytics in CI and use an explicit analyzer cache.
export CI=true
export ANALYZER_STATE_LOCATION_OVERRIDE="${ANALYZER_STATE_LOCATION_OVERRIDE:-/workspace/.cache/nada/analyzer}"
export PATH="$NADA_TOOLS_DIR/flutter/bin:$ANDROID_HOME/cmdline-tools/19.0/bin:$ANDROID_HOME/platform-tools:$PATH"
