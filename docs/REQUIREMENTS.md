# Non-negotiable requirements

## Product target

- Native macOS helper for **Dorico Pro 6.1**.
- Input device is an **Xbox controller**, not a generic gamepad profile.
- Dorico remains the notation application; this project adds full controller access around it.

## Controller behavior inherited from Legato

- A confirms or activates.
- B is an unconditional cancel/back command while the helper interface is active.
- Movement must cross sections according to the visible program layout; no list or panel may trap focus.
- Pointer mode must always be available as a fallback.
- Hold layers, repeats, deadzone, pointer speed, haptics, remapping, profile import/export, and diagnostics must be controller-operable.
- Mapping capture must be cancellable with B.
- The helper must never require a mouse or keyboard after initial macOS permission approval.

## Dorico command coverage

The bridge must not depend on one incomplete automation route. It uses all of these:

1. Dorico key commands.
2. Dorico popovers through key commands and text entry.
3. A virtual Core MIDI source named `Dorico Xbox Bridge` for Dorico Pro MIDI Learn.
4. Live discovery and execution of Dorico's accessible menu commands.
5. Spatial macOS Accessibility navigation across the complete focused Dorico window.
6. Controller pointer and scrolling for visual-only controls.
7. Macros that combine any of the routes above.

## Xbox inputs

A, B, X, Y, D-pad, both bumpers, both analog triggers, both thumbsticks, both thumbstick clicks, Menu, View/Options, and Guide/Home when macOS passes Guide events to the app.

## Safety and targeting

- Xbox input is ignored unless an Xbox/Microsoft controller with the extended gamepad profile is connected.
- The default profile can require Dorico to be frontmost.
- The user can instead allow the bridge to activate Dorico before sending a command.
- No input is sent to unrelated applications accidentally.

## Validation

- Platform-independent mapping, gesture, layer, repeat, profile, and MIDI-address logic is unit-tested.
- The full native target is built on a macOS GitHub Actions runner on every push and pull request.
- A build is not considered successful solely because the cross-platform core tests pass.
