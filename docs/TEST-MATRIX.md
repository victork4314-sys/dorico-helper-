# Dorico Pro 6.1 + Xbox end-to-end test matrix

This matrix separates what CI can prove from what requires a licensed Dorico Pro 6.1 installation and a physical Xbox controller. Do not mark a manual row complete without performing it on real hardware.

## Automated validation

- [x] Swift 6 controller-core tests pass.
- [x] Native SwiftUI/AppKit/GameController/CoreHaptics/CoreMIDI/Accessibility target compiles on macOS 15.
- [x] Release builds are produced for `arm64` and `x86_64`.
- [x] `lipo` verifies both architectures in one Universal 2 executable.
- [x] The `.app` bundle contains a valid `Info.plist` and executable.
- [x] Ad-hoc code-signing verification passes.
- [x] ZIP packaging succeeds.
- [x] DMG creation and `hdiutil verify` succeed.
- [x] Mapping-layer precedence, helper input isolation, B/back interception, repeat fallback, hold/double-press behavior, profile JSON round-trip, routed Xbox text serialization, default popover/Jump Bar routes, MIDI addressing, and universal fallback catalog coverage are unit-tested.

## Test environment record

Record these before manual validation:

- macOS version:
- Mac model and architecture:
- Dorico Pro version/build:
- Xbox controller model and firmware:
- Bluetooth or USB connection:
- Bridge commit/build number:
- Accessibility permission granted: Yes / No
- Dorico virtual MIDI input enabled: Yes / No

## Installation and launch

- [ ] DMG mounts without an error.
- [ ] The Applications shortcut appears beside the app.
- [ ] The app copies to Applications.
- [ ] Control-click → Open allows first launch for the ad-hoc-signed development build.
- [ ] The dashboard appears without Terminal.
- [ ] Relaunching the app preserves profiles and settings.
- [ ] Accessibility permission prompt opens System Settings.
- [ ] After permission is granted, the bridge reports Accessibility ready.
- [ ] Dorico Pro 6.1 is detected while running.
- [ ] Dorico is reported absent while closed.

## Xbox-only device handling

- [ ] Xbox controller connects over Bluetooth.
- [ ] Xbox controller connects over USB where supported.
- [ ] A non-Xbox controller is ignored.
- [ ] Connecting a second non-Xbox controller does not replace the Xbox controller.
- [ ] Disconnecting the active Xbox controller clears held triggers, bumpers, stick directions, pointer mode, capture state, and keyboard state.
- [ ] Reconnecting restores control without restarting the bridge.
- [ ] Battery percentage is shown when macOS supplies it.
- [ ] Haptic test produces controller feedback.
- [ ] Disabling haptics suppresses feedback.

## Every Xbox control

Confirm press, release, remap capture, and diagnostic reporting where the operating system exposes the control:

- [ ] A
- [ ] B
- [ ] X
- [ ] Y
- [ ] D-pad up
- [ ] D-pad down
- [ ] D-pad left
- [ ] D-pad right
- [ ] Left bumper
- [ ] Right bumper
- [ ] Left analog trigger
- [ ] Right analog trigger
- [ ] Left stick up/down/left/right
- [ ] Right stick up/down/left/right
- [ ] Left stick click
- [ ] Right stick click
- [ ] Menu
- [ ] View/Options
- [ ] Guide/Home when macOS delivers it

## Dashboard controller operation

- [ ] View opens the dashboard from Dorico.
- [ ] View closes or toggles the dashboard as configured.
- [ ] A activates the highlighted item.
- [ ] B cancels mapping capture before doing anything else.
- [ ] B returns to Status from another section.
- [ ] B hides the dashboard from Status.
- [ ] D-pad and left stick move through every visible row.
- [ ] Left/right cross sections when the current row is not adjustable.
- [ ] Left/right adjust settings when the current row is adjustable.
- [ ] Navigation wraps without trapping focus inside a list.
- [ ] Status, Mappings, Commands, Profiles, Settings, and Diagnostics are all reachable.
- [ ] Every action in those sections is operable without a physical mouse or keyboard.
- [ ] Repeat delay changes take effect.
- [ ] Repeat rate changes take effect.
- [ ] Stick deadzone changes take effect.
- [ ] Trigger threshold changes take effect.
- [ ] Hold delay changes take effect.
- [ ] Double-press window changes take effect.
- [ ] Pointer speed changes take effect.

## Xbox controller keyboard

Test command search, arbitrary Dorico text, routed popovers, Jump Bar execution, and Jump Bar mapping:

- [ ] The keyboard opens from Status and Commands without a physical keyboard.
- [ ] D-pad and left stick move horizontally and vertically through every visible key.
- [ ] Grid movement wraps without trapping the selected key.
- [ ] A types the selected character.
- [ ] B cancels immediately on the first press, regardless of entered text.
- [ ] X erases the last character.
- [ ] The selectable Space key inserts a space.
- [ ] Y changes between uppercase/music, lowercase, and symbols pages.
- [ ] Either bumper changes the keyboard page.
- [ ] Menu submits the entered text.
- [ ] Right-stick click also submits the entered text.
- [ ] View cancels the keyboard without executing text.
- [ ] Uppercase, lowercase, digits, punctuation, flat, sharp, double-flat, and double-sharp characters render correctly.
- [ ] Held directional movement repeats according to the active repeat settings.
- [ ] Command search can be entered, changed, and cleared entirely through the Xbox keyboard.
- [ ] Cancelling a routed keyboard clears its pending Dorico route.
- [ ] A later plain text action cannot inherit a cancelled popover or Jump Bar route.

## Mapping and profiles

- [ ] Select a command and begin capture with A.
- [ ] B cancels capture and does not create a binding.
- [ ] Every Xbox input can be captured.
- [ ] Base, LT, RT, both triggers, LB, RB, both bumpers, and pointer layers can be selected.
- [ ] Press, release, hold, double-press, and repeat gestures can be selected.
- [ ] A new binding executes after capture.
- [ ] Clearing a binding removes only the selected binding.
- [ ] Duplicating a profile preserves every binding and setting.
- [ ] Reset restores the complete default Legato-style profile.
- [ ] Export writes `Documents/Dorico Xbox Bridge Profiles/Dorico-Xbox-Profiles.json`.
- [ ] Import loads the newest JSON in that folder.
- [ ] Importing malformed JSON leaves current profiles intact.
- [ ] Active profile persists after relaunch.

## Dorico targeting safety

- [ ] With frontmost-only enabled, commands do nothing when another app is frontmost.
- [ ] With background activation enabled, the bridge activates Dorico before sending a command.
- [ ] Controller keyboard submission hides the dashboard, activates Dorico, and sends text only after Dorico is frontmost.
- [ ] No keyboard command is sent to Safari, Finder, Messages, or another unrelated app.
- [ ] Dashboard A/B/D-pad input never leaks into Dorico while the dashboard is active.
- [ ] Dashboard X/Y/Menu/trigger/bumper input is consumed locally or ignored rather than leaking into Dorico.
- [ ] Pointer mode is the only intentional global-pointer route.
- [ ] Disabling the bridge stops routed commands immediately.

## Base Dorico navigation and editing

Test in Setup, Write, Engrave, Play, and Print where the command is meaningful:

- [ ] Selection left/right/up/down
- [ ] Held navigation repeats smoothly.
- [ ] A/Return activates the selected Dorico control or confirms a popover.
- [ ] B/Escape closes popovers and dialogs.
- [ ] X/Delete removes the current selection.
- [ ] Menu toggles play/stop.
- [ ] Left stick click performs Undo.
- [ ] Right stick click performs Redo.
- [ ] Start note input works.
- [ ] Copy, cut, paste, and select all work through the LT layer.
- [ ] No command becomes stuck after releasing a trigger or bumper.

## Duration and note-entry layer

- [ ] 16th note
- [ ] Eighth note
- [ ] Quarter note
- [ ] Half note
- [ ] Whole note
- [ ] Rhythm dot
- [ ] Layer remains active while RT is held.
- [ ] Base actions resume immediately after RT release.

## Dorico popovers

Use the default LT + RT routes. Each route must open the Xbox keyboard first, then return to Dorico, open the correct popover, enter text, and confirm:

- [ ] LT + RT + A: Dynamics
- [ ] LT + RT + B: Ornaments
- [ ] LT + RT + X: Time signature
- [ ] LT + RT + Y: Key signature
- [ ] LT + RT + D-pad Up: Tempo
- [ ] LT + RT + D-pad Down: Clef
- [ ] LT + RT + D-pad Left: Playing techniques
- [ ] LT + RT + D-pad Right: Bars and barlines
- [ ] Controller-entered Unicode text reaches Dorico without corruption.
- [ ] B cancels keyboard entry before Dorico is changed.
- [ ] B/Escape cancels an already-open Dorico popover.

## Jump Bar

- [ ] LB + X opens the Xbox keyboard for Jump Bar Commands.
- [ ] LB + Y opens the Xbox keyboard for Jump Bar Go To.
- [ ] LB + A opens generic focused-field Dorico text entry.
- [ ] “Run a Dorico Jump Bar command” opens the Xbox keyboard.
- [ ] Submitting hides the helper and activates Dorico.
- [ ] Jump Bar opens with J.
- [ ] Commands mode opens with Control-1 on macOS.
- [ ] Go To mode opens with Control-2 on macOS.
- [ ] The entered controller text reaches the Jump Bar.
- [ ] Return executes the command or location automatically after submission.
- [ ] “Create a Jump Bar controller mapping” accepts text, then starts Xbox input capture.
- [ ] The captured Xbox input runs the saved Jump Bar macro later.
- [ ] B cancels keyboard entry and Dorico Escape closes an open Jump Bar.
- [ ] Jump Bar option changes work where Dorico exposes them.

## Virtual MIDI Learn

- [ ] Dorico lists `Dorico Xbox Bridge` as a MIDI input.
- [ ] MIDI test sends channel 1, note 60.
- [ ] MIDI Learn slot 1 can be assigned to a Dorico function.
- [ ] The assigned Xbox input executes the learned function.
- [ ] Test at least one slot on each exposed MIDI channel.
- [ ] Rapid presses send distinct note-on/note-off pulses.
- [ ] MIDI Learn does not leave a held note.
- [ ] Profile export/import preserves MIDI slot bindings.

## Live Dorico menu discovery

- [ ] Menu scan completes while Dorico is frontmost.
- [ ] The discovered command count is nonzero.
- [ ] Commands from each top-level Dorico menu appear.
- [ ] Disabled menu items are not falsely executed.
- [ ] A discovered command can be mapped to an Xbox input.
- [ ] The mapped menu command executes.
- [ ] Rescanning after changing Dorico mode updates available commands.
- [ ] Nested menu paths execute the correct item rather than a same-named item elsewhere.

## Spatial Accessibility navigation

- [ ] Right stick moves focus left/right/up/down across Dorico controls.
- [ ] Focus chooses the nearest control in the requested direction.
- [ ] Movement crosses panel boundaries.
- [ ] Movement wraps when no candidate exists in the requested direction.
- [ ] Hidden controls are skipped.
- [ ] Disabled/non-focusable decorative elements are skipped.
- [ ] LB + RB + B presses the focused accessible control.
- [ ] LB + RB + Y increments sliders or steppers.
- [ ] LB + RB + X decrements sliders or steppers.
- [ ] LB + RB + Menu opens the focused control menu.
- [ ] LB + RB + D-pad Right scans next.
- [ ] LB + RB + D-pad Left scans previous.
- [ ] Setup, Write, Engrave, Play, and Print each remain navigable.

## Pointer fallback

- [ ] Both bumpers + A toggles pointer mode.
- [ ] Left stick moves the pointer in all directions.
- [ ] Pointer speed setting changes movement distance.
- [ ] Right stick scrolls vertically and horizontally.
- [ ] A left-clicks.
- [ ] Y double-clicks.
- [ ] X right-clicks.
- [ ] B exits pointer mode.
- [ ] Pointer direction remains correct on the primary display and on displays arranged above, below, left, and right.
- [ ] Pointer remains within usable screen coordinates across multiple displays.
- [ ] Pointer mode can operate a Dorico control not exposed through Accessibility.

## Stability and stress

- [ ] Hold navigation for 60 seconds without runaway repeats.
- [ ] Rapidly alternate LT/RT layers 100 times without a stuck layer.
- [ ] Disconnect while both triggers are held; reconnect and confirm base layer.
- [ ] Open/close the dashboard 100 times.
- [ ] Open, type, submit, and cancel the Xbox keyboard 100 times.
- [ ] Scan Dorico menus repeatedly without duplicate growth or a crash.
- [ ] Switch profiles repeatedly during Dorico playback.
- [ ] Leave bridge and Dorico running for one hour without increasing input latency.
- [ ] Sleep/wake the Mac and reconnect the controller.
- [ ] Quit Dorico while the bridge is running; bridge remains stable.
- [ ] Relaunch Dorico; detection and command routing recover.

## Sign-off

- Tester:
- Date:
- Build/commit:
- Failed rows and linked issues:
- Final result: Pass / Fail / Blocked
