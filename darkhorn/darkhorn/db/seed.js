#!/usr/bin/env node
/**
 * seed.js — generates 150 users and 50 groups in both darkhorn_rest and darkhorn_jdbc
 *
 * Usage:
 *   node seed.js
 *
 * Environment variables (optional, defaults to localhost):
 *   PGHOST, PGPORT, PGUSER, PGPASSWORD
 */

'use strict';

const { Client } = require('pg');
const { v4: uuidv4 } = require('uuid');

const USERS_COUNT  = 150;
const GROUPS_COUNT = 50;

const FIRST_NAMES = [
  'James','Mary','John','Patricia','Robert','Jennifer','Michael','Linda','William','Barbara',
  'David','Susan','Richard','Jessica','Joseph','Sarah','Thomas','Karen','Charles','Lisa',
  'Christopher','Nancy','Daniel','Betty','Matthew','Margaret','Anthony','Sandra','Mark','Ashley',
  'Donald','Dorothy','Steven','Kimberly','Paul','Emily','Andrew','Donna','Joshua','Michelle',
  'Kenneth','Carol','Kevin','Amanda','Brian','Melissa','George','Deborah','Timothy','Stephanie',
];

const LAST_NAMES = [
  'Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez',
  'Hernandez','Lopez','Gonzalez','Wilson','Anderson','Thomas','Taylor','Moore','Jackson','Martin',
  'Lee','Perez','Thompson','White','Harris','Sanchez','Clark','Ramirez','Lewis','Robinson',
  'Walker','Young','Allen','King','Wright','Scott','Torres','Nguyen','Hill','Flores',
  'Green','Adams','Nelson','Baker','Hall','Rivera','Campbell','Mitchell','Carter','Roberts',
];

const DEPARTMENTS = [
  'Engineering','IT','Finance','HR','Marketing','Sales','Legal','Operations',
  'Research','Support','Security','DevOps','Product','Design','Procurement',
];

const TITLES = [
  'Engineer','Analyst','Manager','Director','Specialist','Coordinator','Consultant',
  'Administrator','Developer','Architect','Lead','Advisor','Officer','Associate','Executive',
];

const GROUP_PREFIXES = [
  'admins','developers','devops','finance','hr','legal','marketing','sales','support',
  'security','readonly','power-users','auditors','managers','analysts','architects',
  'ops','engineering','research','product',
];

function pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; }
function pickN(arr, n) {
  const shuffled = [...arr].sort(() => Math.random() - 0.5);
  return shuffled.slice(0, n);
}

function generateGroups() {
  const groups = [];
  const used = new Set();
  while (groups.length < GROUPS_COUNT) {
    const prefix = pick(GROUP_PREFIXES);
    const suffix = String(groups.length + 1).padStart(2, '0');
    const name = used.has(prefix) ? `${prefix}-${suffix}` : prefix;
    used.add(name);
    groups.push({ id: uuidv4(), name, description: `${name} group` });
  }
  return groups;
}

function generateUsers(groups) {
  const users = [];
  const usedUsernames = new Set();
  for (let i = 0; i < USERS_COUNT; i++) {
    const firstName = pick(FIRST_NAMES);
    const lastName  = pick(LAST_NAMES);
    let username    = `${firstName.toLowerCase()}.${lastName.toLowerCase()}`;
    if (usedUsernames.has(username)) username = `${username}${i}`;
    usedUsernames.add(username);

    const userGroupIds = pickN(groups, Math.floor(Math.random() * 4)).map(g => g.id);
    users.push({
      id:         uuidv4(),
      username,
      email:      `${username}@darkhorn.local`,
      firstName,
      lastName,
      password:   'Passw0rd!',
      status:     Math.random() < 0.1 ? 'suspended' : 'active',
      department: pick(DEPARTMENTS),
      title:      pick(TITLES),
      groups:     userGroupIds,
    });
  }
  return users;
}

async function seedDatabase(dbName) {
  const client = new Client({
    host:     process.env.PGHOST     || 'localhost',
    port:     parseInt(process.env.PGPORT || '5432', 10),
    database: dbName,
    user:     process.env.PGUSER     || 'darkhorn',
    password: process.env.PGPASSWORD || 'darkhorn',
  });

  await client.connect();
  console.log(`[seed] Connected to ${dbName}`);

  // Clear existing seed data
  await client.query('DELETE FROM user_groups');
  await client.query('DELETE FROM users');
  await client.query('DELETE FROM groups');

  const groups = generateGroups();
  const users  = generateUsers(groups);

  // Insert groups
  for (const g of groups) {
    await client.query(
      `INSERT INTO groups (id, name, description) VALUES ($1, $2, $3)`,
      [g.id, g.name, g.description]
    );
  }
  console.log(`[seed] ${groups.length} groups inserted into ${dbName}`);

  // Insert users
  for (const u of users) {
    await client.query(
      `INSERT INTO users (id, username, email, first_name, last_name, password, status, department, title)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
      [u.id, u.username, u.email, u.firstName, u.lastName, u.password, u.status, u.department, u.title]
    );
    for (const gid of u.groups) {
      await client.query(
        `INSERT INTO user_groups (user_id, group_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
        [u.id, gid]
      );
    }
  }
  console.log(`[seed] ${users.length} users inserted into ${dbName}`);

  await client.end();
  console.log(`[seed] Done with ${dbName}\n`);
}

async function main() {
  console.log('[seed] Starting darkhorn seed...\n');
  await seedDatabase('darkhorn_rest');
  await seedDatabase('darkhorn_jdbc');
  await seedDatabase('darkhorn_soap');
  await seedDatabase('darkhorn_mq');
  console.log('[seed] All done! 🌑🦄');
}

main().catch(err => {
  console.error('[seed] FATAL:', err.message);
  process.exit(1);
});
