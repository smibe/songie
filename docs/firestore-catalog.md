# Firestore shared song catalog

## First-version behavior

- The top-level `songs` collection is the shared catalog.
- Published songs marked `public` can be read without signing in.
- Published songs marked `friends` can be read by active friends and admins.
- Songs marked `private` can be read only by active admins.
- Only active admins can create, edit, publish/unpublish, and delete songs.
- The Flutter app treats Firestore as the catalog source of truth.
- The app stores the original ChordPro source in each song document and parses it locally.
- A user's show/hide chords and font size preferences remain device-local.

## Song document

Collection: `songs`

Document ID: stable, lowercase identifier such as `the-long-road-home`.

Required fields:

| Field | Type | Description |
|---|---|---|
| `title` | string | Display title |
| `artist` | string | Artist or author; use empty string if unknown |
| `key` | string | Original key; use empty string if unknown |
| `chordPro` | string | Complete canonical ChordPro source |
| `titleSearch` | string | Lowercase normalized title, used for ordering |
| `published` | boolean | Only published songs appear in the client catalog |
| `visibility` | string | `public`, `friends`, or `private` |
| `schemaVersion` | number | Start at `1` |
| `createdAt` | timestamp | Creation time |
| `updatedAt` | timestamp | Last content update |

Songs created before the visibility field was introduced are migrated to
`visibility: "friends"`. This is a conservative default: old songs are not
made public implicitly.

## Authentication and membership

Songie uses Firebase Authentication email-link sign-in. Anyone can request a
sign-in link, but signing in does not grant friend or administrator access.
Membership is stored in `members/{firebase-auth-uid}`:

| Field | Type | Description |
|---|---|---|
| `uid` | string | Firebase Authentication user ID |
| `email` | string | Verified account email |
| `role` | string | `friend` or `admin` |
| `active` | boolean | Whether the membership is currently enabled |
| `createdAt` | timestamp | Membership creation time |
| `updatedAt` | timestamp | Last membership change |

Members cannot create or update their own membership. Only trusted Admin SDK
credentials can grant or revoke access. Firestore rules are the security
boundary; filtering in the client is only for choosing a query compatible with
those rules.

## Enable passwordless sign-in

In Firebase Console for `songie-prod`:

1. Open **Authentication → Sign-in method**.
2. Enable **Email/Password** and its **Email link (passwordless sign-in)**
   option.
3. Under **Authentication → Settings → Authorized domains**, ensure
   `songie-prod.web.app` is authorized.

The email link is completed in the web app. If opened in a different browser
or device, the user must enter the same email address again.

## Bootstrap the first administrator

1. Deploy the updated web app and Firestore rules after running the migration
   described below.
2. Open `https://songie-prod.web.app` and sign in once using the email address
   that should own the catalog.
3. From `tools/catalog-seed`, grant that account the admin role:

```powershell
npm install
gcloud auth application-default login
npm run member -- --email you@example.com --role admin
```

The account must have completed Firebase Authentication sign-in before it can
be found by email.

## Grant or revoke friend access

Ask a friend to open Songie and sign in once. Then run:

```powershell
npm run member -- --email friend@example.com --role friend
```

To revoke access:

```powershell
npm run member -- --email friend@example.com --revoke
```

The membership listener updates the app when access changes. Friends can read
published `public` and `friends` songs. Only admins can read `private`
songs. An uninvited account can still read `public` songs only.

## Import songs

The importer reads a ChordPro file and derives `title`, `artist`, `key`,
`titleSearch`, and the document ID. It writes the canonical source,
timestamps, `published`, `visibility`, and `schemaVersion`.

By default, new songs are unpublished drafts in the friend circle:

```powershell
npm run seed:morning-light
```

Publish a friend-circle song:

```powershell
npm run seed:morning-light -- --publish
```

Import another ChordPro file:

```powershell
node .\\seed-song.mjs .\\samples\\my-song.pro --project songie-prod --publish --visibility friends
```

Allowed visibility values:

- `public`: anyone can read the song, including without signing in.
- `friends`: active friends and admins can read it.
- `private`: only admins can read it.

The default is `friends`. Creation uses Firestore's `create()` operation;
if a document ID already exists, the script stops and leaves it untouched.

## Migrate existing songs

Run this one-time migration before deploying the new Firestore rules:

```powershell
npm run migrate:visibility
```

The migration adds `visibility: "friends"` to documents with a missing or
invalid value. It does not change publication status or song text.

## Query requirements

Firestore Security Rules are not filters. Every public/friend query must
constrain `published` to `true` and constrain `visibility` to the values
allowed for that user. The app builds one of these queries:

- Public visitor: `visibility in ["public"]`
- Friend: `visibility in ["public", "friends"]`
- Admin: `visibility in ["public", "friends", "private"]`

All queries are ordered by `titleSearch` and use the composite index in
`firestore.indexes.json`.

## Offline behavior

Firestore caches documents fetched by the client. A previously fetched song
may remain in a device's offline cache, so revoking membership cannot erase
copies that a user has already downloaded. Do not treat app access control as
digital rights management.

## Future group sessions

Do not duplicate song content in a session. A future `sessions/{sessionId}`
document should contain references such as `songId`, `setlistId`,
`hostUid`, and optionally a current line/scroll position. Session membership
and write permissions will need separate rules and authentication decisions.
