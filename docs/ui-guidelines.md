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

- Show song title and artist near the top.
- Display chords as text above the exact lyric position represented by each ChordPro marker.
- Keep lyrics readable at arm's length on a phone or tablet.
- Allow vertical scrolling and a simple way back to the library.
- Provide transposition controls without adding a row of decorative music icons.
- When chord display is disabled, render lyrics without chord labels; do not alter the stored source.

### Settings

- Start with a small settings page.
- Include a persistent `Show guitar chords` switch, enabled by default.
- Include a lyric text-size preference.
- Avoid adding settings until there is a clear user need.

## Responsive behavior

- **Phones:** use a single-page navigation stack: library, song display, settings.
- **Tablets:** support a two-pane layout with the library on the left and the selected song on the right. The song reader should also work in a full-screen presentation.
- Use available width to improve readability; do not simply stretch phone controls across a tablet.
- Keep the same settings and song behavior across device sizes.

## Accessibility and usability

- Support system text scaling where practical, with an in-app lyric-size control for the song reader.
- Maintain sufficient contrast in both light and dark themes if both are offered.
- Use semantic labels for settings and navigation controls.
- Do not rely on color alone to communicate selection or state.

## First implementation scope

Implement only the library, song display, and settings surfaces. The first preference is chord visibility. More elaborate setlist management and live collaboration should come after the core reading experience works well.
