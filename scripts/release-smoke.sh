#!/usr/bin/env bash
# Installs the given app on a booted simulator, launches it, and fails if the
# process dies within the watch window. The Release configuration is the one
# nothing else in the pipeline ever runs, so "it starts and stays up" is the
# whole point of this check.
set -euo pipefail

APP="${1:?usage: release-smoke.sh path/to/Trainr.app}"
DEVICE="${SMOKE_DEVICE:-iPhone 17 Pro}"
BUNDLE_ID="com.jericx.trainr"

xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b

xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" "$BUNDLE_ID"

# A crash on launch or first paint happens fast; give it long enough to settle.
sleep 15

# Read the list before matching it: grep -q exits on the first hit, which leaves
# launchctl writing into a closed pipe, and pipefail then reads that SIGPIPE as
# the app being gone.
running=$(xcrun simctl spawn "$DEVICE" launchctl list || true)

if ! grep -q "$BUNDLE_ID" <<<"$running"; then
  echo "The app is no longer running — it crashed after launch." >&2
  exit 1
fi
echo "The Release build launched and stayed up."
