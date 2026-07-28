# Arbitrary mapping requirements

This release treats controller mappings as exact unordered sets of controls rather than a small list of hard-coded modifier layers.

- Any controller control may participate in a combination.
- Combinations may contain one control, several controls, or all independently pressable controller buttons and triggers.
- Assembly order does not change the binding.
- Extra held controls form a different binding.
- Smaller combinations never fire underneath a larger combination.
- Releasing part of a combination never synthesizes actions for the remaining subset.
- Only the selected profile/layout is active.

Custom keyboard shortcuts preserve the physical macOS key code and the actual displayed symbol. Command, Shift, Option, Control, Fn/Globe, Caps Lock, punctuation, localized keys, keypad keys, navigation keys, and function keys are supported, including modifier-only shortcuts.

One controller mapping may also run a user-ordered sequence containing built-in actions, scanned Dorico menu commands, keyboard shortcuts, typed text, Jump Bar commands, named MIDI pitches, pointer actions, and per-step waits.

All user-facing MIDI selectors and action labels use musical pitch names such as C4 and F♯5 rather than raw MIDI note numbers.
