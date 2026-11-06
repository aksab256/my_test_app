// my_test_app/tool/verify_review_accounts.mjs
//
// Verifies each fixed-code test account the SAME way the app signs it in:
//   1. signInWithPassword with the derived identity
//      (<phone>@aksab.com / Rabia_<phone>) — mirrors _reviewSignIn.
//   2. Role lookup by phone/email across the role collections in the same
//      order the app uses — mirrors AuthService._getUserDataByEmail.
// Exits 0 only if all three roles PASS. Run this before any release.
//
// Prerequisites:
//   npm i firebase-admin
//   Service-account key JSON for aksab-erp (Firestore read).
//
// Usage (from my_test_app):
//   $env:GOOGLE_APPLICATION_CREDENTIALS='C:\path\to\aksab-erp-key.json'
//   node tool/verify_review_accounts.mjs

import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import fs from 'node:fs';

// Public Web client key, same one shipped in lib/firebase_options.dart.
const API_KEY = 'AIzaSyAR_ilDZbo9hPR0JJ2Wtal555N8VVWvqEQ';

const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (!keyPath || !fs.existsSync(keyPath)) {
  console.error(
    'Missing service-account key. Set GOOGLE_APPLICATION_CREDENTIALS first.',
  );
  process.exit(1);
}

const app = initializeApp({
  credential: cert(JSON.parse(fs.readFileSync(keyPath, 'utf8'))),
  projectId: 'aksab-erp',
});

const db = getFirestore(app);
const COLLECTIONS = ['sellers', 'consumers', 'users', 'pendingSellers', 'subUsers'];

const accounts = [
  { phone: '01278287168', expectedRole: 'seller', expectedCollection: 'sellers' },
  { phone: '01551445210', expectedRole: 'buyer', expectedCollection: 'users' },
  { phone: '01021070461', expectedRole: 'consumer', expectedCollection: 'consumers' },
];

async function restSignIn(email, password) {
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  const data = await res.json();
  if (!res.ok) {
    return { ok: false, error: data?.error?.message ?? `HTTP ${res.status}` };
  }
  return { ok: true, uid: data.localId };
}

// Mirror of AuthService._getUserDataByEmail (phone lookup, email fallback).
async function lookupRole(email) {
  const phoneFromEmail = email.split('@')[0];
  for (const col of COLLECTIONS) {
    const byPhone = await db.collection(col).where('phone', '==', phoneFromEmail).limit(1).get();
    let snap = byPhone;
    if (snap.empty) {
      snap = await db.collection(col).where('email', '==', email).limit(1).get();
    }
    if (!snap.empty) {
      const data = snap.docs[0].data();
      let role = data.role ?? 'buyer';
      if (col === 'sellers') role = 'seller';
      else if (col === 'consumers') role = 'consumer';
      if (role === 'pending' || data.status === 'pending') return { ok: false, error: 'account pending review' };
      return { ok: true, role, collection: col, docId: snap.docs[0].id };
    }
  }
  return { ok: false, error: 'no role doc found' };
}

async function main() {
  let failed = 0;
  for (const acc of accounts) {
    const email = `${acc.phone}@aksab.com`;
    const password = `Rabia_${acc.phone}`;
    const signIn = await restSignIn(email, password);
    if (!signIn.ok) {
      console.log(`[${acc.expectedRole}] FAIL sign-in: ${signIn.error}`);
      failed++;
      continue;
    }
    const lookup = await lookupRole(email);
    if (!lookup.ok) {
      console.log(`[${acc.expectedRole}] FAIL role lookup: ${lookup.error}`);
      failed++;
      continue;
    }
    const roleOk = lookup.role === acc.expectedRole;
    const uidOk = lookup.docId === signIn.uid || lookup.collection === 'subUsers';
    if (roleOk) {
      console.log(
        `[${acc.expectedRole}] PASS sign-in uid=${signIn.uid} role=${lookup.role} doc=${lookup.collection}/${lookup.docId}${uidOk ? '' : ' (doc id differs from auth uid)'}`,
      );
    } else {
      console.log(
        `[${acc.expectedRole}] FAIL role mismatch: got=${lookup.role} doc=${lookup.collection}/${lookup.docId}`,
      );
      failed++;
    }
  }
  if (failed > 0) {
    console.log(`${failed} role(s) FAILED — do not release.`);
    process.exit(1);
  }
  console.log('All three roles PASS — safe to proceed.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
