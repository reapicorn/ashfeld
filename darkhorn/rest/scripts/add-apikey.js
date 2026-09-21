#!/usr/bin/env node
/**
 * add-apikey.js
 * Agrega una nueva API Key al config.json
 *
 * Uso:
 *   node scripts/add-apikey.js <label> [key]
 *
 * Si no se pasa <key>, se genera una aleatoria.
 */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const configPath = path.resolve(__dirname, '..', 'config.json');
const label = process.argv[2];
const keyArg = process.argv[3];

if (!label) {
  console.error('Usage: node scripts/add-apikey.js <label> [key]');
  process.exit(1);
}

const key = keyArg || crypto.randomBytes(32).toString('hex');
const cfg = JSON.parse(fs.readFileSync(configPath, 'utf8'));

if (cfg.auth.apiKey.keys.find(k => k.label === label)) {
  console.error(`A key with label '${label}' already exists.`);
  process.exit(1);
}

cfg.auth.apiKey.keys.push({ key, label });
fs.writeFileSync(configPath, JSON.stringify(cfg, null, 2), 'utf8');

console.log(`\nAPI Key added:`);
console.log(`  Label : ${label}`);
console.log(`  Key   : ${key}`);
console.log(`\nUse this header in your requests:`);
console.log(`  X-API-Key: ${key}\n`);
