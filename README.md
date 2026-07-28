# Dorico Xbox Bridge

A native macOS accessibility companion for **Dorico Pro 6.1** that makes an Xbox controller a complete Dorico control surface.

This is not a generic controller-to-keyboard mapper. It combines Xbox-native input, Dorico key commands and popovers, virtual MIDI Learn, live Dorico menu discovery, spatial macOS Accessibility navigation, pointer control, macros, profiles, haptics, and a controller-operated dashboard.

## Current implementation

- Xbox-only controller detection using Apple's GameController framework.
- A/B/X/Y, D-pad, bumpers, analog triggers, sticks, stick clicks, Menu, View, and Guide when macOS passes Guide events through.
- Legato-style controller behavior: A activates, B backs out, movement is not panel-trapped, held layers are supported, pointer mode is always available, and every mapping/profile/settings screen is controllable from the pad.
- Default Dorico Pro profile with navigation, editing, playback, note input, documented duration keys, documented popovers, accessibility focus, and pointer layers.
- 512 virtual MIDI Learn slots across four MIDI channels, with room to expand to the full 2,048 channel/note address space.
- Live accessible Dorico menu scanning so commands are not limited to a hard-coded list.
- Spatial Accessibility focus that chooses the nearest control in the requested direction across the focused Dorico window.
- JSON profile persistence, import, and export.
- Unit tests for layer precedence, B/back behavior, repeat fallback, double-press handling, profile persistence, and MIDI addressing.
- Native macOS CI build on every push.

## Dorico MIDI Learn

Dorico Pro 6.1 allows MIDI keys or buttons to be assigned to functions and menu items in **Preferences → Key Commands → MIDI Learn**. The bridge creates a virtual MIDI source called **Dorico Xbox Bridge**. Select a MIDI Learn slot in the bridge, map it to an Xbox input, then use that input while Dorico's MIDI Learn control is listening.

## Build

Requirements:

- macOS 14 or later
- Xcode 16 or a compatible Swift 6 toolchain
- Dorico Pro 6.1
- Xbox Wireless Controller or compatible Microsoft Xbox controller supported by macOS

```bash
swift test
swift build -c release
```

The executable is created at `.build/release/DoricoXboxBridge`.

## First launch

1. Pair the Xbox controller in macOS System Settings.
2. Start Dorico Pro 6.1.
3. Launch Dorico Xbox Bridge.
4. Grant Accessibility permission when prompted.
5. In Dorico, enable the `Dorico Xbox Bridge` MIDI input if you plan to use MIDI Learn.
6. Use View on the Xbox controller to show the dashboard.

## Controller rules inside the bridge

- **A:** activate or confirm
- **B:** back or cancel
- **D-pad / left stick:** move through the current section
- **Left / right:** adjust a value or change section
- **View:** show the dashboard

## Important Guide-button behavior

Apple exposes the Xbox Guide/Home button to apps only when macOS does not consume that event first. The bridge maps it whenever the operating system delivers it; View remains the guaranteed dashboard button.

See [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) for the complete non-negotiable behavior contract.
