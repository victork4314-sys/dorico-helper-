#!/usr/bin/env bash
set -euo pipefail

OUTPUT_PATH="${1:-.build/universal/DoricoXboxBridge}"
OUTPUT_DIRECTORY="$(dirname "${OUTPUT_PATH}")"

mkdir -p "${OUTPUT_DIRECTORY}"

swift build -c release --arch arm64
ARM_BIN_DIRECTORY="$(swift build -c release --arch arm64 --show-bin-path)"
ARM_BINARY="${ARM_BIN_DIRECTORY}/DoricoXboxBridge"

swift build -c release --arch x86_64
X86_BIN_DIRECTORY="$(swift build -c release --arch x86_64 --show-bin-path)"
X86_BINARY="${X86_BIN_DIRECTORY}/DoricoXboxBridge"

if [[ ! -x "${ARM_BINARY}" ]]; then
  echo "Missing arm64 executable: ${ARM_BINARY}" >&2
  exit 1
fi
if [[ ! -x "${X86_BINARY}" ]]; then
  echo "Missing x86_64 executable: ${X86_BINARY}" >&2
  exit 1
fi

lipo -create "${ARM_BINARY}" "${X86_BINARY}" -output "${OUTPUT_PATH}"
chmod +x "${OUTPUT_PATH}"
lipo "${OUTPUT_PATH}" -verify_arch arm64 x86_64
lipo -info "${OUTPUT_PATH}"
file "${OUTPUT_PATH}"
