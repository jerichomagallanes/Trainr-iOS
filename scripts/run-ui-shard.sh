#!/usr/bin/env bash
# Runs one shard of the UI tests against a prepared simulator and gives it a
# second attempt only when the first one died of the runner rather than of a
# test: no device, the app not launching, the simulator losing the app. A test
# that fails is already retried once inside xcodebuild; a shard whose log shows
# a real failed test is not rerun, so a genuine failure stays red.
#
#   scripts/run-ui-shard.sh <udid> <TestClass> [<TestClass>...]
set -uo pipefail
cd "$(dirname "$0")/.."
udid="$1"; shift
only=()
for class in "$@"; do only+=("-only-testing:TrainrUITests/$class"); done

looks_like_infra() {
  local log="$1"
  grep -qE 'Unable to find a device|Failed to send signal|Finished with error|Unable to boot|Simulator device failed|Lost connection to the application|failed to launch|Application launch failed|Timed out waiting for|Early unexpected exit|Underlying Error: .*(simulator|Simulator)' "$log" || return 1
  ! grep -qE "Executed [0-9]+ tests?, with [1-9][0-9]* failures" "$log"
}

for attempt in 1 2; do
  rm -rf UITestResults.xcresult build/reports; mkdir -p build
  set +e
  xcodebuild test \
    -project Trainr.xcodeproj \
    -scheme Trainr \
    -destination "platform=iOS Simulator,id=$udid" \
    "${only[@]}" \
    -resultBundlePath UITestResults.xcresult \
    -parallel-testing-enabled NO \
    -retry-tests-on-failure \
    -test-iterations 2 \
    2>&1 | tee "build/xcodebuild-attempt-$attempt.log" | xcbeautify --report junit --report-path build/reports
  status=${PIPESTATUS[0]}
  set -e
  [ "$status" -eq 0 ] && exit 0
  if [ "$attempt" -eq 1 ] && looks_like_infra "build/xcodebuild-attempt-$attempt.log"; then
    echo "::warning::Shard died of the simulator, not a test (see build/xcodebuild-attempt-1.log); resetting it and running once more."
    { echo "### Shard rerun"; echo "Attempt 1 failed on the runner (simulator or app launch), not on a test. It was run again."; } >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
    mv UITestResults.xcresult UITestResults-attempt-1.xcresult 2>/dev/null || true
    xcrun simctl shutdown "$udid" 2>/dev/null || true
    xcrun simctl erase "$udid" 2>/dev/null || true
    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" -b >/dev/null
    continue
  fi
  exit "$status"
done
