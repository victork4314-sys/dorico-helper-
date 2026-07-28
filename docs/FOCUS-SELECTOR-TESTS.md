# Dorico focus selector physical test matrix

These checks require Dorico Pro 6.1, Accessibility permission, and a physical Xbox controller. CI can compile the overlay but cannot see Dorico's live accessibility tree.

- [ ] Right-stick spatial navigation draws a thin selector around the newly focused Dorico control.
- [ ] D-pad and left-stick Dorico navigation refresh the selector after each routed key command.
- [ ] The selector prefers an accessibility-selected child over its parent container.
- [ ] The selector prefers selected rows and selected cells where Dorico exposes them.
- [ ] A focused control with no title receives a useful role-based label rather than an empty badge.
- [ ] A very large score or window area displays a compact labeled marker instead of a screen-sized outline.
- [ ] The selector never accepts mouse clicks and never steals keyboard/controller focus from Dorico.
- [ ] Opening the bridge dashboard hides the Dorico selector.
- [ ] Opening the Xbox text keyboard hides the Dorico selector.
- [ ] Switching to Finder, Safari, or another non-Dorico app hides the selector.
- [ ] Returning to Dorico and navigating again restores the selector.
- [ ] The selector coordinates are correct on the primary display.
- [ ] The selector coordinates are correct on displays arranged left, right, above, and below the primary display.
- [ ] The selector follows controls near every screen edge without drawing outside the visible screen.
- [ ] Repeated navigation does not create extra overlay windows or leave stale outlines behind.
- [ ] Setup, Write, Engrave, Play, and Print modes each show a selector wherever Dorico exposes an accessible focused or selected object.
- [ ] Where Dorico does not expose an individual notation object, the selector honestly falls back to the nearest exposed container/control rather than pretending it found the note.
