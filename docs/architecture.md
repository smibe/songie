# Songie architecture (initial direction)

## Principles

- **ChordPro is the interchange format.** Keep the original source so songs can be imported and exported without losing formatting.
- **Keep the domain independent of Flutter.** Parsing, song models, and music utilities belong in pure Dart packages.
- **Offline first.** A musician must be able to open a saved song without a network connection.
- **Treat content licensing explicitly.** User imports and public-domain or licensed catalogs are supported; scraping and redistributing commercial lyrics is not assumed to be permitted.

## Initial repository shape

```text
apps/
  songie/                 # Flutter application (next milestone)
packages/
  chordpro/               # Pure Dart ChordPro model and parser
docs/
  architecture.md
```

## ChordPro core

The parser turns source text into an immutable document model:

- `ChordProSong`: metadata, ordered sections, warnings, and original source.
- `SongSection`: verse, chorus, bridge, tab, or other section.
- `SongLine`: plain display text, comment flag, and chord anchors.
- `ChordPlacement`: chord symbol plus a UTF-16 code-unit offset in its line.

The offset is a text position, not a pixel coordinate. The Flutter renderer should measure the corresponding text prefix with the same font, style, and text direction used for the lyric line. This avoids hard-coded character widths and keeps chord placement accurate with proportional fonts.

## Planned application layers

1. **Presentation:** Flutter screens and widgets (song reader, library, setlists, live session).
2. **Application:** use cases such as import song, search library, transpose, create setlist, and join session.
3. **Domain:** song and setlist models plus ChordPro and music utilities.
4. **Infrastructure:** local persistence, Firebase Authentication, Cloud Firestore, and session synchronization.

## Firebase direction

Firestore can hold user libraries, setlists, and live-session state. Song content should be cached locally for offline reading. Firebase configuration files and credentials must not contain service-account private keys, and secrets must never be committed to the repository.

## First milestone

Build and test the pure Dart ChordPro package before binding it to Flutter. The current parser is an initial supported subset, not a claim of complete ChordPro specification compliance. Expand it through fixtures and tests as real song files expose additional directives and edge cases.
