// my_test_app/tool/create_review_accounts.mjs
//
// Creates the 3 fixed-code test accounts as REAL accounts:
// real Firebase Auth user (email+password) + real Firestore role doc.
// They bypass OTP only: the app matches them in `reviewPhones` and checks
// the local code 123456, then signs in with these credentials.
// Real registrations (register/send/mint/verify) are untouched.
//
// Key reuse (important): if a Firestore role doc with the same phone already
// exists (e.g. left over after the Auth user was deleted), its document ID
// is reused as the new Auth UID, so the account links back to its original
// data instead of orphaning it.
//
// Prerequisites:
//   npm i firebase-admin
//   Service-account key JSON for aksab-erp with Auth + Firestore admin.
//
// Usage (from my_test_app):
//   $env:GOOGLE_APPLICATION_CREDENTIALS='C:\path\to\aksab-erp-key.json'
//   node tool/create_review_accounts.mjs
//
// Credentials ensured (code for all three: 123456):
//   seller   01278287168 / 01278287168@aksab.com / Rabia_01278287168
//   buyer    01551445210 / 01551445210@aksab.com / Rabia_01551445210
//   consumer 01021070461 / 01021070461@aksab.com / Rabia_01021070461

import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import fs from 'node:fs';

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

const auth = getAuth(app);
const db = getFirestore(app);

const ALL_COLLECTIONS = ['sellers', 'consumers', 'users', 'pendingSellers', 'subUsers'];

const accounts = [
  {
    phone: '01278287168',
    role: 'seller',
    collection: 'sellers',
    fullname: 'Test Seller',
    merchantName: 'Test Seller Store',
  },
  {
    phone: '01551445210',
    role: 'buyer',
    collection: 'users',
    fullname: 'Test Buyer',
    merchantName: 'Test Buyer',
  },
  {
    phone: '01021070461',
    role: 'consumer',
    collection: 'consumers',
    fullname: 'Test Consumer',
    merchantName: 'Test Consumer',
  },
];

async function findDocsByPhone(phone) {
  const hits = [];
  for (const col of ALL_COLLECTIONS) {
    const snap = await db.collection(col).where('phone', '==', phone).limit(5).get();
    snap.forEach((d) => hits.push({ collection: col, id: d.id }));
  }
  return hits;
}

async function ensureAccount(acc) {
  const email = `${acc.phone}@aksab.com`;
  const password = `Rabia_${acc.phone}`;

  let uid = null;
  try {
    const existing = await auth.getUserByEmail(email);
    uid = existing.uid;
    await auth.updateUser(uid, { password, emailVerified: true, disabled: false });
    console.log(`[${acc.role}] Auth updated: ${email} (${uid})`);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
    // Reuse the leftover role-doc ID as UID when present, else fresh UID.
    const hits = await findDocsByPhone(acc.phone);
    const preferred = hits.find((h) => h.collection === acc.collection) ?? hits[0];
    const params = { email, password, emailVerified: true, disabled: false, displayName: acc.phone };
    if (preferred) params.uid = preferred.id;
    const created = await auth.createUser(params);
    uid = created.uid;
    console.log(`[${acc.role}] Auth created: ${email} (${uid})${preferred ? ' reusing doc id' : ''}`);
  }

  const hits = await findDocsByPhone(acc.phone);
  const dupes = hits.filter((h) => !(h.collection === acc.collection && h.id === uid));
  for (const d of dupes) {
    console.log(`[${acc.role}] WARNING duplicate doc: ${d.collection}/${d.id} (left untouched)`);
  }

  const phone20 = `20${acc.phone.substring(1)}`;
  await db.collection(acc.collection).doc(uid).set(
    {
      phone: acc.phone,
      phoneNumber: acc.phone,
      phone20,
      email,
      role: acc.role,
      status: 'active',
      fullname: acc.fullname,
      fullName: acc.fullname,
      merchantName: acc.merchantName,
      address: 'Test address',
    },
    { merge: true },
  );
  console.log(`[${acc.role}] Firestore upserted: ${acc.collection}/${uid}`);
  return uid;
}

async function main() {
  for (const acc of accounts) {
    await ensureAccount(acc);
  }
  console.log('Done. All three accounts open with code 123456.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
