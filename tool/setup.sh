#!/usr/bin/env bash
set -euo pipefail
nada_project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$nada_project_dir/tool/env.sh"
mkdir -p "$NADA_TOOLS_DIR" "$ANDROID_USER_HOME" "$PUB_CACHE" "$GRADLE_USER_HOME" "$XDG_CONFIG_HOME"
python3 "$nada_project_dir/tool/configure_proxy.py"
python3 "$nada_project_dir/tool/install_jdk.py"
source "$nada_project_dir/tool/env.sh"
javac -version
nada_java_options="$(python3 "$nada_project_dir/tool/configure_proxy.py" --java-options)"

# Android command-line tools 19.0. Checksum from Google's repository2-3.xml.
if [[ ! -x "$ANDROID_HOME/cmdline-tools/19.0/bin/sdkmanager" ]]; then
  nada_sdk_tmp="$(mktemp -d)"
  trap 'rm -rf -- "$nada_sdk_tmp"' EXIT
  curl --fail --location --retry 2 --output "$nada_sdk_tmp/tools.zip" \
    https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip
  python3 - "$nada_sdk_tmp/tools.zip" "$nada_sdk_tmp" <<'PY'
import hashlib, pathlib, sys, zipfile
archive = pathlib.Path(sys.argv[1])
if hashlib.sha1(archive.read_bytes()).hexdigest() != '5fdcc763663eefb86a5b8879697aa6088b041e70':
    raise SystemExit('Android SDK tools checksum mismatch; refusing to install.')
with zipfile.ZipFile(archive) as package:
    package.extractall(sys.argv[2])
PY
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  mv "$nada_sdk_tmp/cmdline-tools" "$ANDROID_HOME/cmdline-tools/19.0"
  chmod +x "$ANDROID_HOME/cmdline-tools/19.0/bin/"*
fi

set +e
yes | JAVA_OPTS="${JAVA_OPTS:-} $nada_java_options" sdkmanager --sdk_root="$ANDROID_HOME" --licenses
nada_license_status=${PIPESTATUS[1]}
set -e
if [[ "$nada_license_status" -ne 0 ]]; then exit "$nada_license_status"; fi
JAVA_OPTS="${JAVA_OPTS:-} $nada_java_options" sdkmanager --sdk_root="$ANDROID_HOME" \
  'platform-tools' 'platforms;android-36' 'build-tools;36.0.0' \
  'platforms;android-35' 'build-tools;35.0.0' 'ndk;28.2.13676358' 'cmake;3.22.1'

if [[ "${1:-}" == '--android-only' ]]; then exit 0; fi

# Use the repository pin; never switch an existing, differently pinned SDK.
nada_flutter_commit=f6ff1529fd6d8af5f706051d9251ac9231c83407
if [[ ! -d "$NADA_TOOLS_DIR/flutter" ]]; then
  git clone --depth 1 --branch 3.38.5 https://github.com/flutter/flutter.git "$NADA_TOOLS_DIR/flutter"
fi
if [[ "$(git -C "$NADA_TOOLS_DIR/flutter" rev-parse HEAD)" != "$nada_flutter_commit" ]]; then
  printf '%s\n' 'The Flutter SDK at NADA_TOOLS_DIR is not pinned to 3.38.5. Choose an unused NADA_TOOLS_DIR.' >&2
  exit 1
fi
flutter --version
flutter precache --android
cd "$nada_project_dir"
if [[ -f pubspec.lock ]]; then
  flutter pub get --enforce-lockfile
else
  flutter pub get
fi
printf '%s\n' 'Toolchain and locked dependencies installed. Run bash tool/check.sh to validate the Android build.'
