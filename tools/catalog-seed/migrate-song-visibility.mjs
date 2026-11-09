#!/usr/bin/env node

import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const projectId = process.env.GOOGLE_CLOUD_PROJECT
  ?? process.env.GCLOUD_PROJECT
  ?? 'songie-prod';

async function main() {
  initializeApp({
    credential: applicationDefault(),
    projectId,
  });

  const db = getFirestore();
  const snapshot = await db.collection('songs').get();
  const legacyDocuments = snapshot.docs.filter((document) => {
    const visibility = document.data().visibility;
    return !['public', 'friends', 'private'].includes(visibility);
  });

  if (legacyDocuments.length === 0) {
    console.log('All song documents already have a valid visibility field.');
    return;
  }

  let updated = 0;
  for (let offset = 0; offset < legacyDocuments.length; offset += 450) {
    const batch = db.batch();
    const chunk = legacyDocuments.slice(offset, offset + 450);

    for (const document of chunk) {
      batch.update(document.ref, {
        visibility: 'friends',
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    updated += chunk.length;
  }

  console.log(
    'Marked ' + updated + ' legacy song(s) as friends-only in project ' + projectId + '.',
  );
}

main().catch((error) => {
  console.error('Visibility migration failed: ' + error.message);
  process.exitCode = 1;
});
