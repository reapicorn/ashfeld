#!/usr/bin/env node
/**
 * hash-password.js
 * Genera un bcrypt hash para usar en config.json > auth.basicAuth.users
 *
 * Uso:
 *   node scripts/hash-password.js miPassword
 */
const bcrypt = require('bcrypt');

const password = process.argv[2];
if (!password) {
  console.error('Usage: node scripts/hash-password.js <password>');
  process.exit(1);
}

bcrypt.hash(password, 10).then(hash => {
  console.log('\nPassword hash (copy this into config.json):\n');
  console.log(hash);
  console.log('');
});
