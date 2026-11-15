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
3. **Singing rooms:** create or join a room with an invitation code/QR link, see participants, and activate the room owner's current song suggestion.
4. **Account and admin tools:** profile completion, administrator-managed member roles, and ChordPro import/preview.
5. **Settings:** persistent `Show guitar chords` preference and adjustable text size.

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

Song reads depend on the publication state, visibility, and the signed-in user's membership:

- Published `public` songs can be read without signing in.
- Active users with role `friend` or `admin` can read published `public` and `friends` songs.
- Active administrators can also read `private` songs and unpublished drafts.
- Only active administrators can create, update, or delete shared catalog documents.

At startup, the app subscribes to a query compatible with the user's catalog access, orders by `titleSearch`, and maps each document to a `SongieSong`. Firestore's cache supplies recently fetched documents offline. Web persistence is enabled where the browser permits it and falls back gracefully when persistent storage is unavailable.

The UI depends on a `SongRepository` abstraction rather than importing Firestore directly. `FirestoreSongRepository` is the production implementation.

### Authentication and membership

Firebase Authentication uses passwordless email-link sign-in in the web app. Public songs remain readable without an account; friend-circle songs, private songs, rooms, and administrator tools require an authenticated account with the appropriate membership. Android/iOS email-link deep links are not wired yet.

After first sign-in, users enter a display name. The app creates `members/{uid}` with role `none` and `active: false`; signing in does not grant friend or admin access. Administrators can list member profiles and assign `none`, `friend`, or `admin` in the in-app **Manage users** screen. Users can create their own no-access profile and update their name/email, but cannot grant themselves a role.

### Admin content workflow

Active administrators see an in-app import tool that accepts ChordPro and supported aligned plain-text chord sheets, previews the parsed song, and creates a catalog entry with publication and visibility settings. The trusted Admin SDK CLI remains available for bootstrapping the first administrator and for catalog maintenance.

Do not let the Flutter client grant itself admin access. Firestore Security Rules enforce membership roles and all catalog permissions; client-side checks only shape the UI and select queries that satisfy those rules.

## Live singing rooms

The app includes live singing rooms for active friends and administrators. A room is identified by an eight-character invitation code and stores its owner, active/closed status, participant UIDs, and the current song suggestion. The room owner chooses a published song that is visible to the whole friend circle; the room stores the song ID and display metadata, not a copy of the ChordPro source.

Each participant has a document in `rooms/{roomCode}/participants/{uid}`. It stores their display name, email, room role, and the song they last opened. The owner can close the room; other participants can leave. Rooms are limited to 30 participants in the first version.

Clients listen to the room and participant documents with Firestore snapshots. A new suggestion produces an in-app notification anywhere in Songie while the app is running, including while a participant is reading another song. The notification can return the participant to the room. Each participant activates the suggestion on their own device, preserving their own font size, chord visibility, and reading position. QR invitations contain a web link with the room code; the app preserves the invitation through email-link sign-in and opens the join flow once the user has friend/admin access.

This first version provides in-app realtime updates while Songie is running. Push notifications while the app is closed, synchronized scrolling, setlists, owner transfer, and participant removal are later refinements.

## Firebase services

- **Cloud Firestore:** published songs, membership profiles, and live singing room / participant state.
- **Firebase Authentication:** passwordless email-link sign-in for users who need friend-circle, room, or admin access; public song reading remains anonymous.
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

1. **Presentation:** Flutter screens and widgets (library, song reader, tablet performance mode, settings, member administration, and live rooms).
2. **Application:** use cases such as watch published songs, search catalog, transpose, update display preferences, and later publish songs or join a live session.
3. **Domain:** song and setlist models plus ChordPro and music utilities.
4. **Infrastructure:** Firestore song, membership, and room repositories, local preference storage, Firebase Hosting, and email-link Authentication.

## Deployment and verification

1. Configure the Firebase project and platform apps with FlutterFire CLI.
2. Deploy Firestore rules and indexes from the repository root.
3. Build and deploy the web app with `deploy-web.ps1`.
4. Verify anonymous public song reads, friend/admin access, role changes, room invitation links, realtime song suggestions, and offline behavior.
5. Use only original, public-domain, or appropriately licensed songs in the shared catalog.

See [`firestore-catalog.md`](firestore-catalog.md) for the initial Firestore document schema and rules.
