# Arbitrary mapping test matrix

The automated suite covers:

- single-control exact bindings
- two-control exact bindings
- three-control exact bindings
- opposite directional inputs stored in one exact set
- every independent physical controller button and trigger in one binding
- order-independent chord assembly
- slow chord assembly without smaller action leakage
- release-time commitment when a smaller mapping is a prefix of a larger mapping
- partial-release suppression
- exact-only resolution with no subset or base fallback
- separate normal and pointer contexts
- old layer/input profile migration
- current exact-set profile round trips
- physical keyboard key-code and symbol preservation
- Command, Shift, Option, Control, Fn/Globe, and Caps Lock preservation
- modifier-only shortcuts
- ordered mixed-action sequences and per-step delays
- named MIDI pitches from C-1 through G9
- default Legato note placement and navigation parity
