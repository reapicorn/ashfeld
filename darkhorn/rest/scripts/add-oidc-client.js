#!/usr/bin/env node
/**
 * add-oidc-client.js
 * Agrega un nuevo cliente OIDC al config.json
 *
 * Uso:
 *   node scripts/add-oidc-client.js <clientId> [clientSecret]
 *
 * Si no se pasa <clientSecret>, se genera uno aleatorio.
 */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const configPath = path.resolve(__dirname, '..', 'config.json');
const clientId = process.argv[2];
const secretArg = process.argv[3];

if (!clientId) {
  console.error('Usage: node scripts/add-oidc-client.js <clientId> [clientSecret]');
  process.exit(1);
}

const clientSecret = secretArg || crypto.randomBytes(24).toString('hex');
const cfg = JSON.parse(fs.readFileSync(configPath, 'utf8'));

if (cfg.auth.oidc.clients.find(c => c.clientId === clientId)) {
  console.error(`A client with id '${clientId}' already exists.`);
  process.exit(1);
}

cfg.auth.oidc.clients.push({
  clientId,
  clientSecret,
  grantTypes: ['client_credentials', 'password'],
  scopes: ['openid', 'profile', 'users:read', 'users:write'],
});

fs.writeFileSync(configPath, JSON.stringify(cfg, null, 2), 'utf8');

console.log(`\nOIDC Client added:`);
console.log(`  clientId     : ${clientId}`);
console.log(`  clientSecret : ${clientSecret}`);
console.log(`\nGet a token:`);
console.log(`  curl -X POST http://localhost:3000/oauth/token \\`);
console.log(`    -d "grant_type=client_credentials" \\`);
console.log(`    -d "client_id=${clientId}" \\`);
console.log(`    -d "client_secret=${clientSecret}"\n`);
