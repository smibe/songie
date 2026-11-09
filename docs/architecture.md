# Songie architecture

## Product direction

Songie is a shared songbook for groups of people who want to sing and play together. The primary content library is centrally managed; regular users browse and read the same published songs rather than building separate personal libraries.

## Principles

- **Shared catalog first.** All users see the same published song catalog from Cloud Firestore.
- **Low-friction reading.** Reading published songs should not require an account.
- **Admin-managed content.** Only authorized administrators can create, edit, publish, unpublish, or delete catalog songs.
- **ChordPro is the canonical song format.** Store the original source and parse it for display on each client.
- **Keep the domain independent of Flutter.** Parsing, song models, and music utilities belong in pure Dart packages.
- **Offline first.** Recently loaded songs should remain available when a device temporarily loses connectivity.
- **Simple visual language.** Use restrained neutral colors and typography; avoid decorative controls and unnecessary icons.
- **Performance readability is essential.** A guitarist must be able to read the current song comfortably from a music stand.
- **Treat content licensing explicitly.** Only user-provided, public-domain, or appropriately licensed lyrics may be published.

## Repository layout

```text
apps/
  songie/                 # Flutter app for phones, tablets, and web
packages/
  chordpro/               # Pure Dart ChordPro model, parser, and music utilities
docs/
  architecture.md
  ui-guidelines.md
  firestore-catalog.md
firestore.rules
firestore.indexes.json
firebase.json
```

## Main application screens

1. **Library / contents:** searchable list of published songs, with simple categories or setlists later.
2. **Song display:** readable lyrics with optional chord text positioned above the corresponding lyric positions. The reader supports scrolling and transposition.
3. **Settings:** persistent `Show guitar chords` preference and adjustable text size.

On phones, use a normal navigation stack. On wider tablets, use a two-pane browsing layout, but allow the reader to open full-screen.

## Tablet performance mode (must-have)

Full-screen song display on tablets is a core requirement. A guitarist should be able to place the tablet on a music stand and read the song clearly without the library pane or normal application chrome taking up valuable space.

- Provide a dedicated full-screen performance mode.
- Hide the library pane, navigation rails, and other non-essential application chrome.
- Use the available display area for the song, with adjustable large lyrics and chord text.
- Keep chords as plain text aligned above their lyric anchors; honor the `Show guitar chords` preference.
- Keep scrolling smooth and predictable. Provide a clear, unobtrusive way to leave performance mode.
- Show performance controls on tap and allow them to disappear again.
- Support landscape and portrait orientations.
- Keep the display awake while performance mode is active, and restore normal behavior when it is exited.

Phone song display remains a focused single-page reader and reuses the same song-rendering component and preferences.

## Shared song catalog

Cloud Firestore is the source of truth for the published catalog. Each song is one document in the top-level `songs` collection. The canonical content field is the complete ChordPro source string; clients parse it with the pure Dart `chordpro` package.

Regular users read only documents with `published == true`. Reading is public and does not require Firebase Authentication in the first version. Client writes are forbidden. Admin writes are authorized by a trusted Firebase Authentication custom claim (`admin == true`) and enforced by Firestore Security Rules.

At startup, the app subscribes to the published-song query, orders by `titleSearch`, and maps each document to a `SongieSong`. Firestore's cache supplies recently fetched documents offline. On Android and iOS, Firestore persistence is enabled by default; on web it must be enabled explicitly and should handle browsers where persistent storage is unavailable.

The UI depends on a `SongRepository` abstraction rather than importing Firestore directly. The current in-memory demo catalog is a temporary implementation; `FirestoreSongRepository` will become the production implementation once the Firebase project is configured.

### Admin content workflow

Administrators are responsible for the shared catalog. Initially, songs can be created or edited in the Firebase Console. A dedicated admin screen can follow, with ChordPro text editing, file import, preview, and publish/unpublish actions. Import is an admin publishing tool, not a requirement for ordinary users.

Do not let the Flutter client grant itself admin access. Custom claims must be assigned by a trusted Admin SDK environment, and Firestore Rules must enforce the role regardless of what the UI displays.

## Shared catalog vs. live group session

The first Firebase milestone is the shared catalog only: every user sees the same published songs and can open them independently.

A later live-session feature is separate. A session document can reference a song ID and optionally a setlist, host, join code, and current position. Clients can listen to that session in realtime so everyone follows the host's selected song. This does not require duplicating song content in each session. Synchronized scrolling is a later optional refinement.

## Firebase services

- **Cloud Firestore:** published songs now; groups, setlists, and live-session state later.
- **Firebase Authentication:** not required for public song reading. Add it for administrator sign-in and private/group features.
- **Firebase Hosting:** deploy the Flutter web build.

Firebase client configuration contains project identifiers, not service-account private keys. Never commit Admin SDK service-account credentials or other private secrets.

## ChordPro core

The parser turns source text into an immutable document model:

- `ChordProSong`: metadata, ordered sections, warnings, and original source.
- `SongSection`: verse, chorus, bridge, tab, or other section.
- `SongLine`: plain display text, comment flag, and chord anchors.
- `ChordPlacement`: chord symbol plus a UTF-16 code-unit offset in its line.

The offset is a text position, not a pixel coordinate. The Flutter renderer measures the caret position within the complete lyric text using the same font and text direction as the displayed line.

## Planned application layers

1. **Presentation:** Flutter screens and widgets (library, song reader, tablet performance mode, settings, future admin and live-session screens).
2. **Application:** use cases such as watch published songs, search catalog, transpose, update display preferences, and later publish songs or join a live session.
3. **Domain:** song and setlist models plus ChordPro and music utilities.
4. **Infrastructure:** Firestore repository, local preference storage, Firebase Hosting, and later Authentication/session synchronization.

## First Firebase milestone

1. Create a Firebase project and register Android, iOS, and Web apps with FlutterFire CLI.
2. Initialize Firebase and configure Cloud Firestore.
3. Deploy the catalog security rules and indexes.
4. Replace the demo data source with `FirestoreSongRepository`.
5. Seed a few original or properly licensed ChordPro songs.
6. Verify public reads, admin-only writes, realtime updates, and offline behavior on web and mobile.

See [`firestore-catalog.md`](firestore-catalog.md) for the initial Firestore document schema and rules.
