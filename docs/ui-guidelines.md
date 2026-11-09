# Songie UI guidelines

## Product feel

Songie should feel like a clean, dependable digital songbook. The songs are the focus; the interface should stay quiet and get out of the way.

## Visual style

- Use a restrained neutral palette: black, white, and a small range of greys.
- Avoid bright accent colors, gradients, decorative illustrations, and unnecessary borders.
- Guitar chords are plain text. Do not use chord-diagram icons, instrument icons, or chord-card graphics in the song reader.
- Use clear typography, generous line spacing, and predictable alignment.
- Make touch targets comfortable without making controls visually dominant.

## Navigation and screens

### Library / contents

- Show a clear screen title and a search field.
- Present songs in a simple, readable list. Title is primary; artist can be secondary.
- Keep navigation to settings discoverable but visually quiet.
- Categories and setlists can be added without cluttering the first version.

### Song display

- Show song title and artist near the top in normal reading mode.
- Display chords as text above the exact lyric position represented by each ChordPro marker.
- Keep lyrics readable at arm's length on a phone or tablet.
- Allow vertical scrolling and a simple way back to the library.
- Provide transposition controls without adding a row of decorative music icons.
- When chord display is disabled, render lyrics without chord labels; do not alter the stored source.

### Tablet full-screen performance mode (must-have)

- The tablet must offer a dedicated full-screen song view designed for a music stand.
- The song fills the available screen; hide the library, navigation pane, and non-essential application chrome.
- Make lyric and chord text large and comfortably spaced, with a user-adjustable text size.
- Support both portrait and landscape, with landscape as a particularly useful performance orientation.
- Keep controls unobtrusive: reveal them on tap and let them disappear again.
- Provide an easy-to-discover exit from full-screen mode.
- Keep the display awake while this mode is active.
- The reader must remain clear and useful with guitar chords switched off.

### Settings

- Start with a small settings page.
- Include a persistent `Show guitar chords` switch, enabled by default.
- Include a lyric text-size preference.
- Avoid adding settings until there is a clear user need.

## Responsive behavior

- **Phones:** use a single-page navigation stack: library, song display, settings.
- **Tablets:** the library may use a two-pane layout for browsing, but opening performance mode must switch to a true full-screen song display.
- Use available width to improve readability; do not simply stretch phone controls across a tablet.
- Keep the same settings and song behavior across device sizes.

## Accessibility and usability

- Support system text scaling where practical, with an in-app lyric-size control for the song reader.
- Maintain sufficient contrast in both light and dark themes if both are offered.
- Use semantic labels for settings and navigation controls.
- Do not rely on color alone to communicate selection or state.

## First implementation scope

Implement the library, song display, settings, and tablet performance mode. Chord visibility and the full-screen tablet reader are core requirements. More elaborate setlist management and live collaboration should come after the core reading experience works well.
