# Validation matrix

The project uses two complementary validation paths:

- `swift test` validates platform-independent controller mappings, layers, gestures, repeats, profile persistence, and MIDI address allocation.
- GitHub Actions on `macos-15` compiles and packages the SwiftUI, GameController, CoreHaptics, CoreMIDI, AppKit, and macOS Accessibility implementation.

A Linux core pass is not treated as proof that the native application compiles. The macOS workflow must also pass.
