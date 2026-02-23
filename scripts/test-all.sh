#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT_DIR/ResonanceBreathing.xcodeproj"
IOS_SCHEME="ResonanceBreathing"
WATCH_SCHEME="ResonanceBreathingWatch Watch App"
IOS_DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2"
WATCH_DESTINATION="platform=watchOS Simulator,name=Apple Watch Ultra 3 (49mm),OS=26.2"
IOS_BUNDLE_ID="com.lucascamillo.resonancebreathing"
WATCH_BUNDLE_ID="com.lucascamillo.resonancebreathing.watchkitapp"
IOS_RUNTIME_ID="com.apple.CoreSimulator.SimRuntime.iOS-26-2"
WATCH_RUNTIME_ID="com.apple.CoreSimulator.SimRuntime.watchOS-26-2"

run_with_timeout() {
  local timeout_seconds="$1"
  shift

  "$@" &
  local command_pid=$!
  local elapsed=0

  while kill -0 "$command_pid" >/dev/null 2>&1; do
    if (( elapsed >= timeout_seconds )); then
      kill -TERM "$command_pid" >/dev/null 2>&1 || true
      sleep 1
      kill -KILL "$command_pid" >/dev/null 2>&1 || true
      return 124
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  wait "$command_pid"
}

reset_simulators() {
  xcrun simctl shutdown all || true
  killall Simulator || true
  killall com.apple.CoreSimulator.CoreSimulatorService || true
}

require_timeout_success() {
  local timeout_seconds="$1"
  local description="$2"
  shift 2

  run_with_timeout "$timeout_seconds" "$@"
  local status=$?

  if [[ "$status" -eq 0 ]]; then
    return 0
  fi

  if [[ "$status" -eq 124 ]]; then
    echo "Timed out: $description"
  else
    echo "Failed: $description (exit $status)"
  fi
  return "$status"
}

cd "$ROOT_DIR"

xcodegen generate

(
  cd "$ROOT_DIR/Packages/BreathingCore"
  swift test
)

xcodebuild -project "$PROJECT" -scheme "$IOS_SCHEME" -destination "$IOS_DESTINATION" build
xcodebuild -project "$PROJECT" -scheme "$WATCH_SCHEME" -destination "$WATCH_DESTINATION" build

xcodebuild -project "$PROJECT" -scheme "$IOS_SCHEME" -destination "$IOS_DESTINATION" analyze
xcodebuild -project "$PROJECT" -scheme "$WATCH_SCHEME" -destination "$WATCH_DESTINATION" analyze

run_ios_tests() {
  if require_timeout_success 480 "iOS tests (first attempt)" \
    xcodebuild -project "$PROJECT" -scheme "$IOS_SCHEME" -destination "$IOS_DESTINATION" test; then
    return 0
  fi

  echo "Initial iOS test run failed. Retrying after simulator reset..."
  reset_simulators
  require_timeout_success 480 "iOS tests (retry)" \
    xcodebuild -project "$PROJECT" -scheme "$IOS_SCHEME" -destination "$IOS_DESTINATION" test
}

run_ios_tests

IOS_DEVICE_ID="$(
  xcrun simctl list devices available -j |
    jq -r --arg runtime "$IOS_RUNTIME_ID" '.devices[$runtime][]? | select(.name == "iPhone 17 Pro") | .udid' |
    head -n1
)"
WATCH_DEVICE_ID="$(
  xcrun simctl list devices available -j |
    jq -r --arg runtime "$WATCH_RUNTIME_ID" '.devices[$runtime][]? | select(.name == "Apple Watch Ultra 3 (49mm)") | .udid' |
    head -n1
)"

if [[ -z "$IOS_DEVICE_ID" || -z "$WATCH_DEVICE_ID" ]]; then
  echo "Required simulators are not available."
  exit 1
fi

run_with_timeout 90 xcrun simctl boot "$IOS_DEVICE_ID" >/dev/null 2>&1 || true
run_with_timeout 90 xcrun simctl boot "$WATCH_DEVICE_ID" >/dev/null 2>&1 || true
require_timeout_success 180 "Wait for iOS simulator boot" xcrun simctl bootstatus "$IOS_DEVICE_ID" -b
require_timeout_success 180 "Wait for watch simulator boot" xcrun simctl bootstatus "$WATCH_DEVICE_ID" -b

IOS_APP_PATH="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*ResonanceBreathing-*/Build/Products/Debug-iphonesimulator/ResonanceBreathing.app' | grep -v 'Index.noindex' | head -n1)"
WATCH_APP_PATH="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*ResonanceBreathing-*/Build/Products/Debug-watchsimulator/ResonanceBreathingWatch Watch App.app' | grep -v 'Index.noindex' | head -n1)"

if [[ -z "$IOS_APP_PATH" || -z "$WATCH_APP_PATH" ]]; then
  echo "Unable to locate simulator app bundles in DerivedData."
  exit 1
fi

require_timeout_success 120 "Install iOS app" xcrun simctl install "$IOS_DEVICE_ID" "$IOS_APP_PATH"
require_timeout_success 120 "Install watch app" xcrun simctl install "$WATCH_DEVICE_ID" "$WATCH_APP_PATH"

IOS_LAUNCH_OUTPUT="$(run_with_timeout 120 xcrun simctl launch "$IOS_DEVICE_ID" "$IOS_BUNDLE_ID")" || {
  status=$?
  if [[ "$status" -eq 124 ]]; then
    echo "Timed out launching iOS app via simctl (CoreSimulator appears wedged)."
  else
    echo "Failed launching iOS app via simctl (exit $status)."
  fi
  exit "$status"
}
WATCH_LAUNCH_OUTPUT="$(run_with_timeout 120 xcrun simctl launch "$WATCH_DEVICE_ID" "$WATCH_BUNDLE_ID")" || {
  status=$?
  if [[ "$status" -eq 124 ]]; then
    echo "Timed out launching watch app via simctl (CoreSimulator appears wedged)."
  else
    echo "Failed launching watch app via simctl (exit $status)."
  fi
  exit "$status"
}

IOS_PID="$(echo "$IOS_LAUNCH_OUTPUT" | awk -F': ' 'NF >= 2 {print $2}' | tr -d '[:space:]')"
WATCH_PID="$(echo "$WATCH_LAUNCH_OUTPUT" | awk -F': ' 'NF >= 2 {print $2}' | tr -d '[:space:]')"

if [[ ! "$IOS_PID" =~ ^[0-9]+$ || ! "$WATCH_PID" =~ ^[0-9]+$ ]]; then
  echo "Failed to parse launched app process IDs."
  echo "iOS launch output: $IOS_LAUNCH_OUTPUT"
  echo "watch launch output: $WATCH_LAUNCH_OUTPUT"
  exit 1
fi

sleep 2

if ! xcrun simctl spawn "$IOS_DEVICE_ID" launchctl procinfo "$IOS_PID" >/dev/null 2>&1; then
  echo "iOS app exited immediately after launch (pid: $IOS_PID)."
  exit 1
fi

if ! xcrun simctl spawn "$WATCH_DEVICE_ID" launchctl procinfo "$WATCH_PID" >/dev/null 2>&1; then
  echo "watch app exited immediately after launch (pid: $WATCH_PID)."
  exit 1
fi

echo "All checks passed."
