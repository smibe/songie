# Songie

Songie is a cross-platform shared songbook for groups who want to sing and play together. It displays lyrics with guitar chords and is designed for phones, tablets, and the web.

## Project structure

- `packages/chordpro/` — UI-independent Dart ChordPro parser, song model, and music utilities.
- `apps/songie/` — Flutter app for the shared song library, song reader, settings, and tablet performance mode.
- `docs/` — architecture, UI guidelines, and Firestore catalog schema.
- `firestore.rules` / `firestore.indexes.json` — shared catalog security and query index.

## Shared catalog

The production song library lives in Cloud Firestore. Anyone can read published songs without signing in; only trusted administrators can write to the catalog. Song documents store the complete original ChordPro source, which each client parses locally.

See [`docs/firestore-catalog.md`](docs/firestore-catalog.md) for the document schema, first-song setup, and admin workflow.

## Flutter application

The app supports Android, iOS, and Web from one Flutter codebase. It includes a searchable catalog, phone song reader, tablet two-pane browsing, full-screen tablet performance mode, and persistent chord-visibility / lyric-size preferences.

See [`apps/songie/README.md`](apps/songie/README.md) for setup and run instructions.

## ChordPro package

```sh
cd packages/chordpro
dart pub get
dart format .
dart analyze
dart test
```

## Firebase deployment

From the repository root, link the Firebase project and deploy the Firestore rules and indexes:

```sh
firebase use --add
firebase deploy --only firestore:rules,firestore:indexes
```

## Design

- Keep the interface simple and neutral.
- Render chord symbols as text above their lyric anchors.
- Let users disable chord display without changing the stored ChordPro source.
- Make tablet full-screen performance reading a first-class experience.
- Keep recently loaded songs available offline.

See [`docs/architecture.md`](docs/architecture.md) and [`docs/ui-guidelines.md`](docs/ui-guidelines.md).

## Content and copyright

Only publish user-provided, public-domain, or appropriately licensed material. Do not assume that lyrics are reusable merely because they can be viewed for free online.
