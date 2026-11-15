#!/usr/bin/env bash
# One-time setup: copy this machine's signing config into GitHub Actions
# secrets so the "Release (Play Store)" workflow can build from anywhere.
# Nothing is printed; values go straight from local files into `gh`.
#
# Needs the GitHub CLI:  brew install gh && gh auth login
# Usage: tools/release/setup_github_secrets.sh [path/to/play-service-account.json]
set -euo pipefail
cd "$(dirname "$0")/../.."

command -v gh >/dev/null || {
  echo "✗ GitHub CLI not found. Run: brew install gh && gh auth login" >&2
  exit 1
}

PROPS=android/key.properties
[ -f "$PROPS" ] || { echo "✗ $PROPS not found." >&2; exit 1; }
prop() { sed -n "s/^$1=//p" "$PROPS" | tr -d '\n'; }

store_file=$(prop storeFile)
case "$store_file" in
  /*) keystore=$store_file ;;
  *) keystore=android/$store_file ;;
esac
[ -f "$keystore" ] || { echo "✗ Keystore $keystore not found." >&2; exit 1; }

base64 < "$keystore" | tr -d '\n' | gh secret set ANDROID_KEYSTORE_BASE64
prop storePassword | gh secret set ANDROID_KEYSTORE_PASSWORD
prop keyPassword | gh secret set ANDROID_KEY_PASSWORD
prop keyAlias | gh secret set ANDROID_KEY_ALIAS
echo "✓ Signing secrets set."

if [ $# -ge 1 ]; then
  gh secret set PLAY_SERVICE_ACCOUNT_JSON < "$1"
  echo "✓ PLAY_SERVICE_ACCOUNT_JSON set: the workflow will also upload to Play."
else
  echo "• No service account JSON given: the workflow builds the AAB only."
fi
