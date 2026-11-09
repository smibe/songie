#!/usr/bin/env node

import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

function parseArguments(argv) {
  const options = {
    email: null,
    role: null,
    projectId: process.env.GOOGLE_CLOUD_PROJECT
      ?? process.env.GCLOUD_PROJECT
      ?? 'songie-prod',
    revoke: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];

    if (argument === '--revoke') {
      options.revoke = true;
      continue;
    }

    if (argument === '--email' || argument === '--role' || argument === '--project') {
      const value = argv[index + 1];
      if (!value || value.startsWith('--')) {
        throw new Error('Missing value for ' + argument + '.');
      }

      if (argument === '--email') options.email = value.trim().toLowerCase();
      if (argument === '--role') options.role = value;
      if (argument === '--project') options.projectId = value;
      index += 1;
      continue;
    }

    if (argument === '--help' || argument === '-h') {
      console.log([
        'Grant or revoke Songie catalog membership.',
        '',
        'Grant:',
        '  node manage-member.mjs --email friend@example.com --role friend',
        '  node manage-member.mjs --email you@example.com --role admin',
        '',
        'Revoke:',
        '  node manage-member.mjs --email friend@example.com --revoke',
        '',
        'The user must have signed in to Songie at least once before membership',
        'can be assigned. This command uses trusted Firebase Admin credentials.',
      ].join('\n'));
      process.exit(0);
    }

    throw new Error('Unknown option: ' + argument);
  }

  if (!options.email || !options.email.includes('@')) {
    throw new Error('Use --email with a valid email address.');
  }
  if (!options.revoke && !['friend', 'admin'].includes(options.role)) {
    throw new Error('Use --role friend or --role admin.');
  }
  if (!options.projectId) {
    throw new Error('Firebase project ID is empty.');
  }

  return options;
}

async function main() {
  const options = parseArguments(process.argv.slice(2));

  initializeApp({
    credential: applicationDefault(),
    projectId: options.projectId,
  });

  const auth = getAuth();
  const db = getFirestore();

  let user;
  try {
    user = await auth.getUserByEmail(options.email);
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      throw new Error(
        'This email has not signed in to Songie yet. Ask the person to sign in once, then run the command again.',
      );
    }
    throw error;
  }

  const memberRef = db.collection('members').doc(user.uid);
  const current = await memberRef.get();

  if (options.revoke) {
    if (!current.exists) {
      throw new Error('No Songie membership exists for ' + options.email + '.');
    }
    await memberRef.update({
      active: false,
      updatedAt: FieldValue.serverTimestamp(),
    });
    console.log('Revoked Songie access for ' + options.email + '.');
    return;
  }

  const member = {
    uid: user.uid,
    email: user.email ?? options.email,
    role: options.role,
    active: true,
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (!current.exists || !current.data()?.createdAt) {
    member.createdAt = FieldValue.serverTimestamp();
  }

  await memberRef.set(member, { merge: true });
  console.log(
    'Granted ' + options.role + ' access to ' + (user.email ?? options.email) +
    ' in project ' + options.projectId + '.',
  );
}

main().catch((error) => {
  console.error('Membership update failed: ' + error.message);
  process.exitCode = 1;
});
