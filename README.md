# Songie

Songie is a cross-platform songbook for musicians. It displays lyrics with guitar chords, supports transposition, and is designed to make songs easy to read on phones and tablets.

## Project structure

- `packages/chordpro/` — UI-independent Dart ChordPro parser, song model, and music utilities.
- `apps/songie/` — Flutter app for the song library, song reader, settings, and tablet performance mode.
- `docs/` — architecture and UI guidelines.

## First application slice

The Flutter app currently uses original in-memory demo songs. It includes a searchable library, phone song view, tablet two-pane layout, persistent chord visibility and lyric size preferences, and full-screen performance mode with screen-awake behavior.

See [`apps/songie/README.md`](apps/songie/README.md) for local Flutter setup and run instructions.

## ChordPro package

```sh
cd packages/chordpro
dart pub get
dart format .
dart analyze
dart test
```

## Design

- Keep the interface simple and neutral.
- Render chord symbols as text above their lyric anchors.
- Let users disable chord display without changing the stored ChordPro source.
- Make tablet full-screen performance reading a first-class experience.
- Keep songs available offline.

See [`docs/architecture.md`](docs/architecture.md) and [`docs/ui-guidelines.md`](docs/ui-guidelines.md).

## Content and copyright

Support user-provided ChordPro files and appropriately licensed or public-domain material. Do not assume that lyrics are reusable merely because they can be viewed for free online.
