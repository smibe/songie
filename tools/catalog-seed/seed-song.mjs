#!/usr/bin/env node

import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { normalizeSongSource } from './song-source.mjs';

function usage() {
  console.error([
    'Usage:',
    '  node seed-song.mjs <song1.pro|song1.txt> [song2.pro|song2.txt ...] [--project <project-id>] [--publish]',
    '',
    'Options:',
    '  --id       Firestore document ID. Only valid when importing one file.',
    '  --project  Firebase project ID. Defaults to songie-prod.',
    '  --publish  Publish immediately. Without this flag songs are created as drafts.',
    '  --visibility  public, friends (default), or private.',
    '',
    'Multiple source files are imported sequentially. Existing songs are never overwritten.',
  ].join('\n'));
}

function parseArguments(argv) {
  const options = {
    sourcePaths: [],
    documentId: null,
    projectId: process.env.GOOGLE_CLOUD_PROJECT
      ?? process.env.GCLOUD_PROJECT
      ?? 'songie-prod',
    published: false,
    visibility: 'friends',
  };

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];

    if (argument === '--help' || argument === '-h') {
      usage();
      process.exit(0);
    }

    if (argument === '--publish') {
      options.published = true;
      continue;
    }

    if (argument === '--visibility') {
      const value = argv[index + 1];
      if (!value || value.startsWith('--')) {
        throw new Error('Missing value for --visibility.');
      }
      options.visibility = value;
      index += 1;
      continue;
    }

    if (argument === '--id' || argument === '--project') {
      const value = argv[index + 1];
      if (!value || value.startsWith('--')) {
        throw new Error('Missing value for ' + argument + '.');
      }

      if (argument === '--id') options.documentId = value;
      if (argument === '--project') options.projectId = value;
      index += 1;
      continue;
    }

    if (argument.startsWith('--')) {
      throw new Error('Unknown option: ' + argument);
    }

    options.sourcePaths.push(argument);
  }

  if (options.sourcePaths.length === 0) {
    usage();
    throw new Error('At least one song source file is required.');
  }

  if (options.sourcePaths.length > 1 && options.documentId !== null) {
    throw new Error('--id can only be used when importing exactly one file.');
  }

  return options;
}

function readDirective(source, names) {
  const alternatives = names.join('|');
  const expression = new RegExp(
    '^[\\t ]*\\{[\\t ]*(?:' + alternatives + ')[\\t ]*:[\\t ]*(.*?)[\\t ]*\\}[\\t ]*$',
    'im',
  );

  const normalizedSource = source
    .replace(/^\uFEFF/, '')
    .replace(/\r\n?/g, '\n');

  return expression.exec(normalizedSource)?.[1]?.trim() ?? '';
}

function normalizeTitle(value) {
  return value
    .normalize('NFKD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .trim()
    .replace(/\s+/g, ' ');
}

function createDocumentId(title) {
  return normalizeTitle(title)
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

async function importSong(db, sourcePathArgument, options) {
  const sourcePath = resolve(process.cwd(), sourcePathArgument);
  const inputSource = await readFile(sourcePath, 'utf8');
  const normalized = normalizeSongSource(inputSource);
  const source = normalized.source;

  if (Buffer.byteLength(source, 'utf8') > 900_000) {
    throw new Error('Converted song source exceeds the 900,000-byte Firestore rule limit.');
  }

  const title = readDirective(source, ['title', 't']);
  if (!title) {
    throw new Error('The imported source must provide a title through a ChordPro directive or text-sheet header.');
  }

  const artist = readDirective(source, ['artist', 'a']);
  const key = readDirective(source, ['key', 'k']);
  const documentId = options.documentId ?? createDocumentId(title);

  if (!/^[a-z0-9][a-z0-9-]{0,127}$/.test(documentId)) {
    throw new Error(
      'Document ID must contain 1-128 lowercase letters, digits, or hyphens, and start with a letter or digit.',
    );
  }

  const now = FieldValue.serverTimestamp();
  const song = {
    title,
    artist,
    key,
    chordPro: source,
    titleSearch: normalizeTitle(title),
    published: options.published,
    visibility: options.visibility,
    schemaVersion: 1,
    createdAt: now,
    updatedAt: now,
  };

  const document = db.collection('songs').doc(documentId);
  try {
    await document.create(song);
  } catch (error) {
    if (error.code === 6 || error.code === 'already-exists') {
      throw new Error(
        'Song "' + documentId + '" already exists. Nothing was changed.',
      );
    }
    throw error;
  }

  console.log(
    'Created songs/' + documentId + ' — ' + title + ' (' + normalized.format + ').',
  );
}

async function main() {
  const options = parseArguments(process.argv.slice(2));

  if (!['public', 'friends', 'private'].includes(options.visibility)) {
    throw new Error('Visibility must be public, friends, or private.');
  }

  if (!options.projectId) {
    throw new Error('Firebase project ID is empty. Use --project <project-id>.');
  }

  initializeApp({
    credential: applicationDefault(),
    projectId: options.projectId,
  });

  const db = getFirestore();
  let created = 0;
  let failed = 0;

  for (const sourcePath of options.sourcePaths) {
    try {
      await importSong(db, sourcePath, options);
      created += 1;
    } catch (error) {
      failed += 1;
      console.error('Failed: ' + sourcePath);
      console.error('  ' + error.message);
    }
  }

  console.log('');
  console.log('Import finished: ' + created + ' created, ' + failed + ' failed.');

  if (failed > 0) {
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error('Seed failed: ' + error.message);
  process.exitCode = 1;
});
