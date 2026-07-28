# Legato parity and Mapping rebinding contract

This branch must satisfy both requirements together. Neither may ship alone.

## Exact Legato physical controls

- A: confirm or place the current note/object.
- B: contextual cancel/delete, matching Legato context rather than firing two commands.
- X: articulation/ornament action.
- Y: command surface action.
- LB/RB: previous/next zone.
- LB+RB: score editor action, with combo disambiguation so LB and RB do not also fire.
- LT: selection modifier.
- RT: duration control.
- View: undo.
- Menu: project/menu action.
- Left-stick click: play/stop.
- Right-stick click: pointer mode.
- D-pad and left stick: identical directional movement, repeat timing, and selection behavior.
- Right stick: scrolling outside pointer mode and pointer movement inside pointer mode.

## One-input/one-action rule

Within a single context/layer/gesture, one physical input may resolve to only one action. A held combination is a distinct context. Unmapped combinations must do nothing and must never fall through to a base action.

## Mappings behavior

- Activating a Mapping row starts rebinding that existing mapping.
- It must never delete the mapping.
- B cancels rebinding.
- Deletion is a separate explicit action with clear wording and confirmation.
- Rebinding replaces only the chosen mapping and preserves all unrelated mappings.

## Required automated checks

- Exact default physical map matches Legato.
- D-pad/left-stick parity.
- Right-stick mode parity.
- No duplicate resolution inside any layer and gesture.
- No modifier fallthrough.
- LB/RB combo cannot also trigger individual bumper actions.
- Activating a mapping row enters rebind capture.
- Rebind cancellation preserves the old mapping.
- Successful rebind moves/replaces only the selected mapping.
- Explicit deletion is the only path that removes a mapping.
