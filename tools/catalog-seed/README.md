# Songie catalog and membership tools

Small trusted Node.js utilities for the shared Firestore song catalog. They use
the Firebase Admin SDK and must only run on a trusted development machine or
server. Never bundle them into the Flutter app.

## Requirements

- Node.js 22 or newer
- npm
- Google Cloud Application Default Credentials for an account with permission
  to manage Firebase Authentication users and write Firestore documents

## Setup (PowerShell)

From this directory:

```powershell
npm install
gcloud auth application-default login
```

The Google account used for Application Default Credentials needs suitable
Firebase Authentication and Firestore permissions in the target project.

## Enable passwordless sign-in once

In Firebase Console for project `songie-prod`:

1. Open **Authentication → Sign-in method**.
2. Enable **Email/Password**.
3. Also enable **Email link (passwordless sign-in)**.
4. Under **Authentication → Settings → Authorized domains**, add
   `songie-prod.web.app` if it is not already listed.

The Flutter web app sends a one-time link to the user's email address. The
person must open the link in a browser and enter the same email address if
they open it on another device/browser.

## Bootstrap the first administrator

1. Open Songie at `https://songie-prod.web.app`.
2. Sign in once using the email address that should own the catalog.
3. From this directory, grant that Firebase Auth user the administrator role:

```powershell
npm run member -- --email you@example.com --role admin
```

The account must have completed a Firebase sign-in before it can be found by
email. This command writes `members/{uid}`; ordinary users cannot create or
edit their own membership.

## Grant or revoke friend access

Ask a friend to open Songie and sign in once. Then run:

```powershell
npm run member -- --email friend@example.com --role friend
```

To revoke access:

```powershell
npm run member -- --email friend@example.com --revoke
```

The change takes effect through the live membership listener. Friends can read
songs with `visibility: "public"` and `visibility: "friends"`. Only admins
can read `visibility: "private"` songs and unpublished songs.

## Import a song

The importer reads a ChordPro file and derives `title`, `artist`, `key`,
`titleSearch`, and the document ID. It writes the canonical source,
timestamps, `published`, `visibility`, and `schemaVersion`.

Create Morning Light as a friends-only draft:

```powershell
npm run seed:morning-light
```

Publish it to the friend circle:

```powershell
npm run seed:morning-light -- --publish
```

Import another ChordPro file:

```powershell
node .\\seed-song.mjs .\\samples\\my-song.pro --project songie-prod --publish --visibility friends
```

Allowed visibility values:

- `public`: anyone can read the song, including without signing in.
- `friends`: only active friends and admins can read it.
- `private`: only admins can read it.

The default is `friends`. Add `--visibility public` or
`--visibility private` to override it. By default, songs are created with
`published: false`; add `--publish` to publish immediately.

Creation uses Firestore's `create()` operation. If the document ID already
exists, the script stops and leaves the existing document untouched.

## Migrate existing songs

Existing song documents created before the visibility field was introduced
should be treated as friends-only. Run this once before deploying the new
Firestore rules:

```powershell
npm run migrate:visibility
```

The migration adds `visibility: "friends"` to documents with a missing or
invalid visibility value. It does not change publication status or song text.

## What a member document contains

The membership utility writes documents to `members/{firebase-auth-uid}`:

- `uid`
- `email`
- `role` (`admin` or `friend`)
- `active`
- `createdAt`
- `updatedAt`

Only trusted Admin SDK credentials can assign or revoke membership.
