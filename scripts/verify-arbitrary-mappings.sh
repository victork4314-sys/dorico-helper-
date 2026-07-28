#!/usr/bin/env bash
set -euo pipefail

models="Sources/DoricoBridgeCore/Models.swift"
engine="Sources/DoricoBridgeCore/GestureEngine.swift"
app_model="Sources/DoricoXboxBridge/AppModel.swift"
recorder="Sources/DoricoXboxBridge/KeyboardShortcutRecorder.swift"
picker="Sources/DoricoXboxBridge/MappingActionPickerView.swift"
sequence="Sources/DoricoXboxBridge/ActionSequenceBuilderView.swift"

require() {
  local file="$1"
  local pattern="$2"
  local description="$3"
  if ! grep -Fq "$pattern" "$file"; then
    echo "ARBITRARY MAPPING SAFETY CHECK FAILED: $description" >&2
    exit 1
  fi
}

require "$models" "public var inputs: Set<XboxInput>" "binding keys are not exact arbitrary input sets"
require "$models" "public var virtualKeyCode: UInt16?" "physical keyboard key-code capture is missing"
require "$models" "case command, shift, option, control, function, capsLock" "complete keyboard modifiers are missing"
require "$models" "public static func noteName" "named MIDI pitches are missing"
require "$engine" "for: emission.inputs" "resolver is not looking up the emitted exact input set"
require "$engine" "suppressUntilAllReleased" "partial release can leak smaller combinations"
require "$app_model" "capturePeakInputs" "physical arbitrary-combination capture is missing"
require "$recorder" "override func flagsChanged" "modifier-only keyboard capture is missing"
require "$recorder" "capturedKeyCode: event.keyCode" "all-symbol physical shortcut capture is missing"
require "$picker" "Add to sequence" "actions cannot be added to ordered sequences"
require "$picker" "MIDIAddress.noteName" "MIDI selector is not showing note names"
require "$sequence" "Move earlier" "sequence reordering is missing"
require "$sequence" "delayMilliseconds" "per-step sequence timing is missing"

echo "Arbitrary mapping checks passed: exact controller sets, no subset leakage, full keyboard capture, named pitches, and ordered action sequences are present."
