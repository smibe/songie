# Firestore shared song catalog

## First-version behavior

- The top-level `songs` collection is the shared catalog.
- Every user can read published songs without signing in.
- Only administrators can create, edit, publish/unpublish, and delete songs.
- The Flutter app treats Firestore as the catalog source of truth.
- The app stores the original ChordPro source in each song document and parses it locally.
- A user's show/hide chords and font size preferences remain device-local; they are not shared catalog data.

## Song document

Collection: `songs`

Document ID: stable, lowercase identifier such as `the-long-road-home` (or an auto-generated ID).

Required fields:

| Field | Type | Description |
|---|---|---|
| `title` | string | Display title |
| `artist` | string | Artist or author; use empty string if unknown |
| `key` | string | Original key; use empty string if unknown |
| `chordPro` | string | Complete canonical ChordPro source |
| `titleSearch` | string | Lowercase normalized title, used for ordering |
| `published` | boolean | Only published songs appear in the public catalog |
| `schemaVersion` | number | Start at `1` |
| `createdAt` | timestamp | Creation time |
| `updatedAt` | timestamp | Last content update |

Example document:

```json
{
  "title": "The Long Road Home",
  "artist": "Songie Demo",
  "key": "C",
  "chordPro": "{title: The Long Road Home}\\n{artist: Songie Demo}\\n[C]The road goes on...",
  "titleSearch": "the long road home",
  "published": true,
  "schemaVersion": 1,
  "createdAt": "<Firestore Timestamp>",
  "updatedAt": "<Firestore Timestamp>"
}
```

Keep the canonical ChordPro text in one document per song. It is compact for normal songs and avoids splitting metadata and lyrics across multiple reads. The Firestore document limit is 1 MiB, so the security rules leave a margin by limiting `chordPro` to 900,000 characters.

## Public catalog query

The app should use the equivalent of:

```dart
FirebaseFirestore.instance
    .collection('songs')
    .where('published', isEqualTo: true)
    .orderBy('titleSearch')
    .snapshots();
```

Firestore Security Rules are not filters. A public query must constrain `published` to `true`; do not fetch the whole collection and expect the rules to remove drafts.

Search can initially filter the downloaded published catalog in memory. Add a search service only if catalog size or query costs later justify it.

## Security

`firestore.rules` permits unauthenticated reads of published songs only. Drafts are visible only to administrators. All client writes require the trusted Firebase Authentication custom claim `admin == true`.

Custom claims can only be assigned from a trusted Admin SDK environment. Do not expose a way for the client to grant its own admin role. Firebase Console writes are performed with project-owner/editor privileges and can be used to seed the first songs.

## Add the first song in Firebase Console

Open **Firestore Database → Data → Start collection** and create a collection named `songs`. Create a document with ID `morning-light` and the following fields:

| Field | Type | Value |
|---|---|---|
| `title` | string | `Morning Light` |
| `artist` | string | `Songie Demo` |
| `key` | string | `G` |
| `titleSearch` | string | `morning light` |
| `published` | boolean | `true` |
| `schemaVersion` | number | `1` |
| `createdAt` | timestamp | Current timestamp |
| `updatedAt` | timestamp | Current timestamp |

Add a `chordPro` field with this original sample content (including the line breaks):

```text
{title: Morning Light}
{artist: Songie Demo}
{key: G}
{start_of_verse: Verse 1}
[G]When the morning [D]opens
[Em]And the road is [C]clear
[G]Take a quiet [D]moment
[C]Let the day begin [G]here
{end_of_verse}
{start_of_chorus: Chorus}
[C]Step by step, [G]mile by mile
[D]Leave a little [Em]room to smile
[C]The road is [G]wide, the sky is [D]bright
[C]Keep on walking [D]toward the [G]light
{end_of_chorus}
```

After saving, the song should appear in Songie automatically because the client listens to the published catalog in realtime.

## Initial admin workflow

1. Add or edit a song document in Firebase Console.
2. Set `published` to `false` while reviewing it.
3. Validate the ChordPro source in Songie or with the parser tests.
4. Set `published` to `true` when ready.

A dedicated admin UI with ChordPro editing, file import, preview, and publish controls can be added later. Ordinary singers do not need an import feature or an account to read the catalog.

## Offline behavior

Firestore caches documents fetched by the client. Android and iOS have persistent offline caching enabled by default. Web persistence is disabled by default and must be enabled explicitly; it uses browser storage and should handle unsupported browsers or storage conflicts gracefully. Avoid assuming that a never-before-loaded song is available offline.

## Future group sessions

Do not duplicate song content in a session. A future `sessions/{sessionId}` document should contain references such as `songId`, `setlistId`, `hostUid`, and optionally a current line/scroll position. Session membership and write permissions will need separate rules and authentication decisions.
