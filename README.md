# Songie

Songie is a cross-platform songbook for musicians. It displays lyrics with guitar chords, supports transposition, and will eventually let a group share a live setlist and follow the same song together.

## Project status

Early development. The first milestone is a reliable, UI-independent ChordPro parser. The Flutter application and Firebase integration will follow once the song model and text format are stable.

## Planned capabilities

- Read and render ChordPro songs.
- Keep chords anchored to the exact positions in lyric lines.
- Transpose songs without changing the stored source.
- Browse, search, favourite, and organize songs into setlists.
- Work offline with locally cached songs.
- Share a live session using a short join code.

## Repository layout

The initial implementation is organized around a reusable ChordPro core:

- `packages/chordpro/` — pure Dart parser, song model, and tests.
- `apps/songie/` — planned Flutter application.
- `docs/` — architecture and product decisions.

## Development

The ChordPro package is intentionally independent of Flutter so it can be tested without a UI framework.

```sh
cd packages/chordpro
dart pub get
dart test
```

Flutter setup instructions will be added when the app scaffold is introduced.

## Song format

ChordPro is the source format for songs. See the [ChordPro project](https://www.chordpro.org/) for the format reference.

## Copyright note

Songie should not scrape or redistribute commercial lyrics without permission. A song being freely viewable on a website does not mean its lyrics are licensed for reuse. The app should support user-provided ChordPro files and appropriately licensed or public-domain material.
