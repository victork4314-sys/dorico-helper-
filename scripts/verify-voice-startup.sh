#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "Voice startup safety check failed: $1" >&2
  exit 1
}

grep -q '<key>NSMicrophoneUsageDescription</key>' packaging/Info.plist \
  || fail "Info.plist is missing NSMicrophoneUsageDescription"
grep -q '<key>NSSpeechRecognitionUsageDescription</key>' packaging/Info.plist \
  || fail "Info.plist is missing NSSpeechRecognitionUsageDescription"

grep -q 'maximumContextualStrings = 100' Sources/DoricoBridgeCore/DoricoVoiceRuntimePolicy.swift \
  || fail "Apple Speech contextual strings are not capped at 100"
grep -q 'DoricoVoiceRuntimePolicy.contextualStrings' Sources/DoricoXboxBridge/DoricoVoiceControl.swift \
  || fail "native voice startup bypasses the contextual-string cap"
grep -q 'DoricoVoiceRuntimePolicy.isUsableAudioInput' Sources/DoricoXboxBridge/DoricoVoiceControl.swift \
  || fail "microphone format is not validated before tap installation"
grep -q 'inputTapInstalled' Sources/DoricoXboxBridge/DoricoVoiceControl.swift \
  || fail "microphone tap lifecycle is not tracked"
grep -q 'Label("Voice Control", systemImage: "mic.fill")' Sources/DoricoXboxBridge/ContentView.swift \
  || fail "dashboard Voice Control button is missing"

echo "Voice startup privacy, speech-limit, microphone-format, tap-lifecycle, and dashboard-entry safety rails are present."
