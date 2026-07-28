# Dorico Xbox Bridge

A native macOS accessibility companion for **Dorico Pro 6.1** that makes an Xbox controller a complete Dorico control surface.

This is not a generic controller-to-keyboard mapper. It combines Xbox-native input, Dorico key commands and popovers, Jump Bar command entry, virtual MIDI Learn, live Dorico menu discovery, spatial macOS Accessibility navigation, pointer control, macros, profiles, haptics, and a controller-operated dashboard.

## Current implementation

- Xbox-only controller detection using Apple's GameController framework.
- A/B/X/Y, D-pad, bumpers, analog triggers, sticks, stick clicks, Menu, View, and Guide when macOS passes Guide events through.
- Legato-style controller behavior: A activates, B backs out, movement is not panel-trapped, held layers are supported, pointer mode is always available, and every mapping/profile/settings screen is controllable from the pad.
- Default Dorico Pro profile with navigation, editing, playback, note input, documented duration keys, documented popovers, Jump Bar entry, accessibility focus, and pointer layers.
- 512 virtual MIDI Learn slots across four MIDI channels, with room to expand to the full 2,048 channel/note address space.
- Live accessible Dorico menu scanning so commands are not limited to a hard-coded list.
- Spatial Accessibility focus that chooses the nearest control in the requested direction across the focused Dorico window.
- JSON profile persistence, controller-safe import, and controller-safe export without native file-picker traps.
- Unit tests for layer precedence, B/back behavior, repeat fallback, double-press handling, profile persistence, and MIDI addressing.
- Native macOS CI testing, Universal 2 release building, app-bundle signing verification, ZIP packaging, and DMG packaging on every push.

## Install the app

The macOS workflow produces both:

- `Dorico-Xbox-Bridge-macOS-Universal.dmg` — open it and drag **Dorico Xbox Bridge** to Applications.
- `Dorico-Xbox-Bridge-macOS-Universal.zip` — contains the complete **Dorico Xbox Bridge.app** bundle.

The app contains both Apple Silicon (`arm64`) and Intel (`x86_64`) code. The current development build is ad-hoc signed because the repository does not contain Apple Developer ID credentials. On first launch, macOS may require **Control-click → Open**. Accessibility permission is granted normally in **System Settings → Privacy & Security → Accessibility**.

## Dorico MIDI Learn

Dorico Pro 6.1 allows MIDI keys or buttons to be assigned to functions and menu items in **Preferences → Key Commands → MIDI Learn**. The bridge creates a virtual MIDI source called **Dorico Xbox Bridge**. Select a MIDI Learn slot in the bridge, map it to an Xbox input, then use that input while Dorico's MIDI Learn control is listening.

## Controller-safe profile exchange

The dashboard never opens a save/open panel that can steal the controller.

- **Export profiles** writes `Dorico-Xbox-Profiles.json` to `Documents/Dorico Xbox Bridge Profiles`.
- **Import profiles** loads the newest JSON file in that same folder.

This keeps profile exchange usable from the Xbox-controlled dashboard and avoids requiring a physical mouse or keyboard inside a native file dialog.

## Build

Requirements:

- macOS 14 or later
- Xcode 16 or a compatible Swift 6 toolchain
- Dorico Pro 6.1
- Xbox Wireless Controller or compatible Microsoft Xbox controller supported by macOS

```bash
bash scripts/build-app.sh
```

The script runs tests, compiles both Mac architectures, creates and ad-hoc signs the app bundle, verifies both architectures and the signature, and creates:

- `dist/Dorico Xbox Bridge.app`
- `dist/Dorico-Xbox-Bridge-macOS-Universal.zip`
- `dist/Dorico-Xbox-Bridge-macOS-Universal.dmg`

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
- **D-pad / left stick:** move spatially through the current interface without panel traps
- **Left / right:** adjust a value or change section where appropriate
- **View:** show the dashboard

## Important Guide-button behavior

Apple exposes the Xbox Guide/Home button to apps only when macOS does not consume that event first. The bridge maps it whenever the operating system delivers it; View remains the guaranteed dashboard button.

## Verification boundary

Automated tests and macOS CI verify the controller engine, Swift 6 compilation, Universal 2 binary, app structure, signature, ZIP, and DMG. A licensed Dorico Pro 6.1 installation and a physical Xbox controller are still required for the manual end-to-end matrix in [`docs/TEST-MATRIX.md`](docs/TEST-MATRIX.md); the project does not falsely treat CI as physical hardware testing.

See [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) for the complete non-negotiable behavior contract.
