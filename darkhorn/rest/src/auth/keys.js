const jose = require('node-jose');
const fs = require('fs');
const path = require('path');

const KEYSTORE_PATH = path.resolve(__dirname, '..', '..', 'data', 'keystore.json');

let _keystore = null;
let _privateKey = null;
let _publicKey = null;

async function initKeys() {
  if (_keystore) return { keystore: _keystore, privateKey: _privateKey, publicKey: _publicKey };

  let ks;

  if (fs.existsSync(KEYSTORE_PATH)) {
    const raw = fs.readFileSync(KEYSTORE_PATH, 'utf8');
    ks = await jose.JWK.asKeyStore(JSON.parse(raw));
    const keys = ks.all({ use: 'sig' });
    if (keys.length === 0) {
      ks = await generateKeystore();
    }
  } else {
    ks = await generateKeystore();
  }

  _keystore = ks;
  _privateKey = ks.all({ use: 'sig' })[0];
  _publicKey = _privateKey.toJSON(false); // public only

  return { keystore: _keystore, privateKey: _privateKey, publicKey: _publicKey };
}

async function generateKeystore() {
  const ks = jose.JWK.createKeyStore();
  await ks.generate('RSA', 2048, { use: 'sig', alg: 'RS256' });
  const dataDir = path.dirname(KEYSTORE_PATH);
  if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });
  fs.writeFileSync(KEYSTORE_PATH, JSON.stringify(ks.toJSON(true), null, 2), 'utf8');
  return ks;
}

async function getPrivateKey() {
  await initKeys();
  return _privateKey;
}

async function getPublicKeyJwks() {
  await initKeys();
  return { keys: [_publicKey] };
}

module.exports = { initKeys, getPrivateKey, getPublicKeyJwks };
