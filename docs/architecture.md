# Songie architecture (initial direction)

## Principles

- **ChordPro is the interchange format.** Keep the original source so songs can be imported and exported without losing formatting.
- **Keep the domain independent of Flutter.** Parsing, song models, and music utilities belong in pure Dart packages.
- **Offline first.** A musician must be able to open a saved song without a network connection.
- **Simple visual language.** Use restrained neutral colors and typography; avoid decorative controls and unnecessary icons.
- **Performance readability is essential.** A guitarist must be able to read the current song comfortably from a music stand.
- **Treat content licensing explicitly.** User imports and public-domain or licensed catalogs are supported; scraping and redistributing commercial lyrics is not assumed to be permitted.

## Initial repository shape

```text
apps/
  songie/                 # Flutter application (next milestone)
packages/
  chordpro/               # Pure Dart ChordPro model and parser
docs/
  architecture.md
  ui-guidelines.md
```

## ChordPro core

The parser turns source text into an immutable document model:

- `ChordProSong`: metadata, ordered sections, warnings, and original source.
- `SongSection`: verse, chorus, bridge, tab, or other section.
- `SongLine`: plain display text, comment flag, and chord anchors.
- `ChordPlacement`: chord symbol plus a UTF-16 code-unit offset in its line.

The offset is a text position, not a pixel coordinate. The Flutter renderer should measure the corresponding text prefix with the same font, style, and text direction used for the lyric line. This avoids hard-coded character widths and keeps chord placement accurate with proportional fonts.

## Main application screens

1. **Library / contents:** searchable song list, with simple categories or setlists. Selecting an item opens its song display.
2. **Song display:** readable lyrics with optional chord text positioned above the corresponding lyric positions. The reader supports scrolling and transposition.
3. **Settings:** a small set of display preferences, beginning with a persistent `Show guitar chords` on/off setting and adjustable text size.

Keep the library and song reader as distinct navigation destinations. On phones, use a normal push/pop navigation flow. On wider tablets, a two-pane library/detail layout is useful for browsing, but it must never be the only way to read a song.

## Tablet performance mode (must-have)

Full-screen song display on tablets is a core requirement. A guitarist should be able to place the tablet on a music stand and read the song clearly without the library pane or normal application chrome taking up valuable space.

- Provide a dedicated, explicit full-screen performance mode on tablets.
- Hide the library pane, navigation rails, and other non-essential application chrome while in performance mode.
- Use the tablet's available display area for the song, with adjustable large lyrics and chord text.
- Keep chords as plain text aligned above their lyric anchors; honor the `Show guitar chords` preference.
- Keep scrolling smooth and predictable. Provide a clear, unobtrusive way to leave performance mode.
- Show performance controls on tap and allow them to disappear again, so they do not obscure the lyrics.
- Support landscape orientation and remain usable in portrait orientation.
- Keep the display awake while performance mode is active, and restore normal device behavior when it is exited.

Phone song display remains a focused single-page reader and should reuse the same song-rendering component and preferences.

The `Show guitar chords` preference must affect only rendering, not the stored ChordPro source. Turning chords off should leave lyric text and line spacing readable without chord labels.

## Planned application layers

1. **Presentation:** Flutter screens and widgets (library, song reader, tablet performance mode, settings, setlists, live session).
2. **Application:** use cases such as import song, search library, transpose, update display preferences, enter/exit performance mode, create setlist, and join session.
3. **Domain:** song and setlist models plus ChordPro and music utilities.
4. **Infrastructure:** local persistence, Firebase Authentication, Cloud Firestore, and session synchronization.

## Firebase direction

Firestore can hold user libraries, setlists, preferences, and live-session state. Song content should be cached locally for offline reading. Firebase configuration files and credentials must not contain service-account private keys, and secrets must never be committed to the repository.

## First milestone

Build and test the pure Dart ChordPro package before binding it to Flutter. The current parser is an initial supported subset, not a claim of complete ChordPro specification compliance. Expand it through fixtures and tests as real song files expose additional directives and edge cases.
