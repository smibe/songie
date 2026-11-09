#!/usr/bin/env node

import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

function usage() {
  console.error(`Usage:
  node seed-song.mjs <song.chopro> [--id <document-id>] [--project <project-id>] [--publish]

Options:
  --id       Firestore document ID. Defaults to a slug generated from the title.
  --project  Firebase project ID. Defaults to songie-prod.
  --publish  Publish immediately. Without this flag the song is created as a draft.

The script creates a new document and never overwrites an existing one.`);
}

function parseArguments(argv) {
  const options = {
    sourcePath: null,
    documentId: null,
    projectId: process.env.GOOGLE_CLOUD_PROJECT
      ?? process.env.GCLOUD_PROJECT
      ?? 'songie-prod',
    published: false,
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

    if (argument === '--id' || argument === '--project') {
      const value = argv[index + 1];
      if (!value || value.startsWith('--')) {
        throw new Error(`Missing value for ${argument}.`);
      }

      if (argument === '--id') options.documentId = value;
      if (argument === '--project') options.projectId = value;
      index += 1;
      continue;
    }

    if (argument.startsWith('--')) {
      throw new Error(`Unknown option: ${argument}`);
    }

    if (options.sourcePath !== null) {
      throw new Error('Only one ChordPro source file can be imported at a time.');
    }

    options.sourcePath = argument;
  }

  if (!options.sourcePath) {
    usage();
    throw new Error('A ChordPro source file is required.');
  }

  return options;
}

function readDirective(source, names) {
  const alternatives = names.join('|');
  const expression = new RegExp(
    `^[\\t ]*\\{[\\t ]*(?:${alternatives})[\\t ]*:[\\t ]*(.*?)[\\t ]*\\}[\\t ]*$`,
    'im',
  );

  return expression.exec(source)?.[1]?.trim() ?? '';
}

function normalizeTitle(value) {
  return value
    .normalize('NFKD')
    .replace(/\\p{M}/gu, '')
    .toLowerCase()
    .trim()
    .replace(/\\s+/g, ' ');
}

function createDocumentId(title) {
  return normalizeTitle(title)
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  const sourcePath = resolve(process.cwd(), options.sourcePath);
  const source = await readFile(sourcePath, 'utf8');

  if (Buffer.byteLength(source, 'utf8') > 900_000) {
    throw new Error('ChordPro source exceeds the 900,000-byte Firestore rule limit.');
  }

  const title = readDirective(source, ['title', 't']);
  if (!title) {
    throw new Error('The ChordPro file must contain a {title: ...} directive.');
  }

  const artist = readDirective(source, ['artist', 'a']);
  const key = readDirective(source, ['key', 'k']);
  const documentId = options.documentId ?? createDocumentId(title);

  if (!/^[a-z0-9][a-z0-9-]{0,127}$/.test(documentId)) {
    throw new Error(
      'Document ID must contain 1-128 lowercase letters, digits, or hyphens, and start with a letter or digit.',
    );
  }

  if (!options.projectId) {
    throw new Error('Firebase project ID is empty. Use --project <project-id>.');
  }

  initializeApp({
    credential: applicationDefault(),
    projectId: options.projectId,
  });

  const db = getFirestore();
  const document = db.collection('songs').doc(documentId);
  const now = FieldValue.serverTimestamp();

  const song = {
    title,
    artist,
    key,
    chordPro: source,
    titleSearch: normalizeTitle(title),
    published: options.published,
    schemaVersion: 1,
    createdAt: now,
    updatedAt: now,
  };

  try {
    await document.create(song);
  } catch (error) {
    if (error.code === 6 || error.code === 'already-exists') {
      throw new Error(
        `Song "${documentId}" already exists. Nothing was changed; choose another --id or edit it in the admin workflow.`,
      );
    }
    throw error;
  }

  console.log(`Created songs/${documentId} in project ${options.projectId}.`);
  console.log(`Title: ${title}`);
  console.log(`Published: ${options.published}`);
}

main().catch((error) => {
  console.error(`Seed failed: ${error.message}`);
  process.exitCode = 1;
});
