#!/usr/bin/env bash
set -euo pipefail

manager="Sources/DoricoXboxBridge/XboxControllerManager.swift"
state="Sources/DoricoBridgeCore/ControllerInputState.swift"

require() {
  local file="$1"
  local pattern="$2"
  local description="$3"
  if ! grep -Fq "$pattern" "$file"; then
    echo "CONTROLLER ROUTING SAFETY CHECK FAILED: $description" >&2
    exit 1
  fi
}

require "$manager" "GCController.shouldMonitorBackgroundEvents = true" "background controller monitoring is missing"
require "$manager" "valueChangedHandler" "primary GameController callbacks are missing"
require "$manager" "1.0 / 60.0" "60 Hz polling backup is missing"
require "$manager" "pollControllerState()" "direct controller polling is missing"
require "$manager" "NSWorkspace.didWakeNotification" "sleep/wake recovery is missing"
require "$manager" "NSWorkspace.didActivateApplicationNotification" "frontmost-app recovery is missing"
require "$manager" "startTransportWatchdog()" "transport watchdog is missing"
require "$manager" "ControllerInputState()" "shared deduplication gate is missing"
require "$state" "guard states[input] != pressed" "duplicate-input suppression is missing"

if grep -Fq "GCController.shouldMonitorBackgroundEvents = false" "$manager"; then
  echo "CONTROLLER ROUTING SAFETY CHECK FAILED: background monitoring is explicitly disabled" >&2
  exit 1
fi

echo "Controller routing safety checks passed: background monitoring, callbacks, polling, lifecycle recovery, watchdog, and deduplication are present."
