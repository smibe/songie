# Songie catalog seed tool

A small server-side utility for creating song documents in the shared Firestore
catalog. It reads a ChordPro file and derives `title`, `artist`, `key`,
`titleSearch`, and the document ID. It also writes the canonical source,
timestamps, `published`, and `schemaVersion`.

The tool uses the Firebase Admin SDK. It must only be run on a trusted
development machine or server; never bundle it into the Flutter app.

## Requirements

- Node.js 22 or newer
- npm
- Google Cloud Application Default Credentials for an account that can write
  to the `songs` collection in the target Firebase project

## Setup (PowerShell)

From this directory:

```powershell
npm install
gcloud auth application-default login
```

The Google account used for Application Default Credentials needs an
appropriate Firestore write permission in the target project.

If you use a service-account key instead, keep the JSON file outside the
repository and set the environment variable in the current PowerShell session:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\\secure\\songie-service-account.json"
```

Never commit a service-account key or put it in the Flutter app.

## Create the first song

From this directory, create Morning Light as a draft:

```powershell
npm run seed:morning-light
```

To publish it immediately so it appears in Songie:

```powershell
npm run seed:morning-light -- --publish
```

## Import another ChordPro file

```powershell
node .\\seed-song.mjs .\\samples\\my-song.pro --project songie-prod --publish
```

The script reads the ChordPro `{title: ...}`, `{artist: ...}`, and
`{key: ...}` directives. It accepts the short aliases `{t: ...}`,
`{a: ...}`, and `{k: ...}` as well. The Firestore document ID is generated
from the title unless `--id` is supplied.

By default, songs are created with `published: false`. Add `--publish` to
publish a song immediately.

**Safety:** creation uses Firestore's `create()` operation. If the document ID
already exists, the script stops and leaves the existing document untouched.
It never silently overwrites an existing song.

## What it writes

- Collection: `songs`
- `title`, `artist`, `key`
- `chordPro` (the original file contents)
- `titleSearch` (normalized lowercase title)
- `published`
- `schemaVersion: 1`
- `createdAt` and `updatedAt` (server timestamps)
