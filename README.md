# Dorico Xbox Bridge

A native macOS accessibility companion for **Dorico Pro 6.1** that makes an Xbox controller and natural-language voice commands a complete Dorico control surface.

## Download

### [Download Dorico Xbox Bridge for macOS — DMG](https://github.com/victork4314-sys/dorico-helper-/releases/latest/download/Dorico-Xbox-Bridge-macOS-Universal.dmg)

[Download the app as a ZIP](https://github.com/victork4314-sys/dorico-helper-/releases/latest/download/Dorico-Xbox-Bridge-macOS-Universal.zip) · [Build manifest](https://github.com/victork4314-sys/dorico-helper-/releases/latest/download/BUILD-MANIFEST.txt) · [SHA-256 checksums](https://github.com/victork4314-sys/dorico-helper-/releases/latest/download/SHA256SUMS.txt) · [View the latest release](https://github.com/victork4314-sys/dorico-helper-/releases/latest)

These are permanent latest-release links. Every successful `main` build replaces the GitHub **Latest** release with newly tested Universal 2 installers using the same URLs.

This is not a generic controller-to-keyboard mapper. It combines Xbox-native input, Dorico key commands and popovers, Jump Bar command entry, virtual MIDI Learn, live Dorico menu discovery, spatial macOS Accessibility navigation, pointer control, macros, profiles, haptics, a controller-operated dashboard, and Dorico-specific natural-language voice control.

## Voice control

Open **Dorico Voice Control** from the bridge and grant macOS Microphone and Speech Recognition permissions when prompted.

- **One short setup for your whole voice:** say five varied music phrases once each. The bridge learns reusable transcription corrections for your pronunciation and microphone instead of making you train every command separately.
- **Every helper action is speakable:** voice automatically indexes every action in the real `DefaultCatalog`, including navigation, selection, editing, note entry, durations, popovers, accessibility zones, pointer controls, bridge controls, and all 512 MIDI Learn entries.
- **Future catalog actions become speakable automatically:** adding a named action to `DefaultCatalog` also adds it to voice recognition without another hand-written parser entry.
- **Normal music language works:** American and British duration names, spoken pitches and octaves, accidentals, articulations, dynamics, clefs, key signatures, time signatures, bars, navigation, and spoken numbers are supported.
- **Several commands can be spoken together:** for example, `quarter note, C sharp four, staccato` or `quaver then E flat three then tenuto`.
- **Dorico command fallback:** say `Dorico command …` to route an explicit command name through Dorico Jump Bar Commands when it is not represented by a helper action.
- **Recognition is guarded:** high-confidence fuzzy matching accepts likely transcription errors while ambiguous matches are rejected instead of executing a random command.

Voice calibration and command aliases are stored locally in macOS user defaults. Apple does not expose Siri's private voice-profile system to third-party apps; this project builds a persistent Dorico-specific correction layer over Apple's Speech Recognition framework.

## Current implementation

- Xbox-only controller detection using Apple's GameController framework.
- A/B/X/Y, D-pad, bumpers, analog triggers, sticks, stick clicks, Menu, View, and Guide when macOS passes Guide events through.
- Legato-style controller behavior: A activates, B backs out, movement is not panel-trapped, held layers are supported, pointer mode is always available, and every mapping/profile/settings screen is controllable from the pad.
- Separate visible focus for the dashboard sidebar and content column, with directional movement that cannot be trapped by an adjustable Settings row.
- A small non-interactive focus selector that outlines the accessible Dorico object or control currently reached by controller navigation. Selected child, row, or cell objects are preferred when Dorico exposes them; very large score areas use a compact labeled marker instead of covering the screen.
- Default Dorico Pro profile with navigation, editing, playback, note input, documented duration keys, controller-written popovers, Jump Bar Commands/Go To entry, accessibility focus, and pointer layers.
- Dorico-specific natural-language voice control with five-phrase whole-voice calibration, full catalog indexing, multi-command utterances, fuzzy disambiguation, and Jump Bar fallback.
- A controller-operated two-dimensional text keyboard for Dorico fields, every default text-driven popover, Jump Bar, command search, and reusable mappings.
- 512 virtual MIDI Learn slots across four MIDI channels, with room to expand to the full 2,048 channel/note address space.
- Live accessible Dorico menu scanning so commands are not limited to a hard-coded list.
- Spatial Accessibility focus that chooses the nearest control in the requested direction across the focused Dorico window.
- JSON profile persistence, controller-safe import, and controller-safe export without native file-picker traps.
- Automated coverage for routing layers, helper isolation, spatial dashboard controls, bumper adjustment, text routes, strict Dorico targeting, persistence, MIDI addressing, universal fallbacks, voice calibration, command parsing, and exact voice resolution for every catalog action.
- Native macOS CI testing, Universal 2 release building, app-bundle signing verification, ZIP packaging, DMG packaging, SHA-256 verification, and automatic publication to GitHub Releases after every successful `main` build.

## Install the app

The latest GitHub Release provides:

- `Dorico-Xbox-Bridge-macOS-Universal.dmg` — open it and drag **Dorico Xbox Bridge** to Applications.
- `Dorico-Xbox-Bridge-macOS-Universal.zip` — contains the complete **Dorico Xbox Bridge.app** bundle.
- `BUILD-MANIFEST.txt` — records the source commit, build number, toolchain, architectures, and verification results.
- `SHA256SUMS.txt` — checksums for both installers.

The app contains both Apple Silicon (`arm64`) and Intel (`x86_64`) code. The current development build is ad-hoc signed because the repository does not contain Apple Developer ID credentials. On first launch, macOS may require **Control-click → Open**. Accessibility permission is granted normally in **System Settings → Privacy & Security → Accessibility**. Voice control additionally requires Microphone and Speech Recognition permission.

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
- `dist/BUILD-MANIFEST.txt`
- `dist/SHA256SUMS.txt`

## First launch

1. Pair the Xbox controller in macOS System Settings.
2. Start Dorico Pro 6.1.
3. Launch Dorico Xbox Bridge.
4. Grant Accessibility permission when prompted.
5. In Dorico, enable the `Dorico Xbox Bridge` MIDI input if you plan to use MIDI Learn.
6. Use View on the Xbox controller to show the dashboard.
7. Open **Dorico Voice Control**, choose **Set Up My Voice**, and grant Microphone and Speech Recognition permissions if you want voice control.

## Controller rules inside the bridge

- **A:** activate the focused content item or enter the selected sidebar section
- **B:** back or cancel
- **D-pad / left stick Up/Down:** move within the visibly focused sidebar or content column
- **Left:** move from content to the sidebar
- **Right:** enter content from the sidebar
- **LB / RB:** decrease or increase the focused adjustable value
- **View / Guide:** show or hide the dashboard when macOS exposes the button

## Important Guide-button behavior

Apple exposes the Xbox Guide/Home button to apps only when macOS does not consume that event first. The bridge maps it whenever the operating system delivers it; View remains the guaranteed dashboard button.

## Verification boundary

Automated tests and macOS CI verify the controller engine, voice parser and calibration, exact voice resolution for every helper action, Swift 6 compilation, Universal 2 binary, app structure, signature, ZIP, DMG, build manifest, and SHA-256 checksums. A licensed Dorico Pro installation, a physical Xbox controller, and a physical microphone are still required for the manual end-to-end matrix in [`docs/TEST-MATRIX.md`](docs/TEST-MATRIX.md); the project does not falsely treat CI as physical hardware or microphone testing.

See [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) for the complete non-negotiable behavior contract.
