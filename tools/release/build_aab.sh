#!/usr/bin/env bash
# Build the Play Store bundle and check it is signed with the upload key
# registered in Play Console. Runs the same on any laptop and on CI, as long
# as android/key.properties and the keystore it names exist (docs/RELEASE.md).
#
# Usage: tools/release/build_aab.sh [extra flutter build args]
set -euo pipefail
cd "$(dirname "$0")/../.."

# Upload key registered in Play Console since the 2026-11-08 reset
# (my-release-key.jks). A certificate fingerprint is public, safe to commit.
EXPECTED_SHA1="42:98:58:9D:CC:C9:6C:35:A1:9A:EE:D9:16:D5:41:32:4E:84:12:37"
AAB=build/app/outputs/bundle/release/app-release.aab
PROPS=android/key.properties

if [ ! -f "$PROPS" ]; then
  echo "✗ $PROPS not found. Copy it and the keystore from your backup (docs/RELEASE.md)." >&2
  exit 1
fi
store_file=$(sed -n 's/^storeFile=//p' "$PROPS")
case "$store_file" in
  /*) keystore=$store_file ;;
  *) keystore=android/$store_file ;; # Gradle resolves it from android/
esac
if [ ! -f "$keystore" ]; then
  echo "✗ Keystore $keystore (storeFile in $PROPS) not found." >&2
  exit 1
fi

# Local machines use the fvm-pinned SDK (.fvmrc); CI installs that version itself.
if [ -z "${CI:-}" ] && command -v fvm >/dev/null; then
  flutter=(fvm flutter)
else
  flutter=(flutter)
fi
"${flutter[@]}" build appbundle --release "$@"

actual=$(keytool -printcert -jarfile "$AAB" | sed -n 's/^[[:space:]]*SHA1: //p' | head -1)
if [ "$actual" != "$EXPECTED_SHA1" ]; then
  echo "✗ $AAB is signed with SHA-1 ${actual:-<none>}, but Play expects $EXPECTED_SHA1." >&2
  exit 1
fi

echo "✓ $AAB ($(sed -n 's/^version: //p' pubspec.yaml)) is signed with the Play upload key."
