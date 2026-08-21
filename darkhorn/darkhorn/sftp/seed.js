#!/usr/bin/env node
/**
 * darkhorn-sftp/seed.js
 *
 * Generates /data/users.csv and /data/groups.csv on first run (if empty or missing).
 * Run once after atmoz/sftp container is up and the volume is mounted.
 *
 * Usage:
 *   DATA_DIR=/path/to/volume node seed.js
 */

'use strict';

const fs   = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

const DATA_DIR   = process.env.DATA_DIR || path.resolve(__dirname, 'data');
const USERS_FILE  = path.join(DATA_DIR, 'users.csv');
const GROUPS_FILE = path.join(DATA_DIR, 'groups.csv');
const MEMBERSHIP_FILE = path.join(DATA_DIR, 'user_groups.csv');

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
function pickN(arr, n) { return [...arr].sort(() => Math.random() - 0.5).slice(0, n); }

function escapeCsv(val) {
  if (val === null || val === undefined) return '';
  const s = String(val);
  if (s.includes(',') || s.includes('"') || s.includes('\n')) {
    return '"' + s.replace(/"/g, '""') + '"';
  }
  return s;
}

function toCsvRow(fields) {
  return fields.map(escapeCsv).join(',');
}

function main() {
  if (fs.existsSync(USERS_FILE) && fs.statSync(USERS_FILE).size > 100) {
    console.log('[sftp-seed] users.csv already exists — skipping.');
    return;
  }

  fs.mkdirSync(DATA_DIR, { recursive: true });

  // Generate groups
  const groups = [];
  const usedNames = new Set();
  while (groups.length < GROUPS_COUNT) {
    const prefix = pick(GROUP_PREFIXES);
    const suffix = String(groups.length + 1).padStart(2, '0');
    const name = usedNames.has(prefix) ? `${prefix}-${suffix}` : prefix;
    usedNames.add(name);
    groups.push({ id: uuidv4(), name, description: `${name} group` });
  }

  // Generate users
  const users = [];
  const usedUids = new Set();
  for (let i = 0; i < USERS_COUNT; i++) {
    const firstName = pick(FIRST_NAMES);
    const lastName  = pick(LAST_NAMES);
    let username = `${firstName.toLowerCase()}.${lastName.toLowerCase()}`;
    if (usedUids.has(username)) username = `${username}${i}`;
    usedUids.add(username);
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
      groups:     pickN(groups, Math.floor(Math.random() * 4)).map(g => g.id),
      createdAt:  new Date().toISOString(),
      updatedAt:  new Date().toISOString(),
    });
  }

  // Write users.csv
  const userHeader = 'id,username,email,firstName,lastName,password,status,department,title,createdAt,updatedAt';
  const userRows = users.map(u =>
    toCsvRow([u.id, u.username, u.email, u.firstName, u.lastName,
              u.password, u.status, u.department, u.title, u.createdAt, u.updatedAt])
  );
  fs.writeFileSync(USERS_FILE, [userHeader, ...userRows].join('\n') + '\n', 'utf8');
  console.log(`[sftp-seed] ${users.length} users  → ${USERS_FILE}`);

  // Write groups.csv
  const groupHeader = 'id,name,description,createdAt';
  const groupRows = groups.map(g =>
    toCsvRow([g.id, g.name, g.description, new Date().toISOString()])
  );
  fs.writeFileSync(GROUPS_FILE, [groupHeader, ...groupRows].join('\n') + '\n', 'utf8');
  console.log(`[sftp-seed] ${groups.length} groups → ${GROUPS_FILE}`);

  // Write user_groups.csv
  const memberHeader = 'userId,groupId';
  const memberRows = [];
  for (const u of users) {
    for (const gid of u.groups) memberRows.push(`${u.id},${gid}`);
  }
  fs.writeFileSync(MEMBERSHIP_FILE, [memberHeader, ...memberRows].join('\n') + '\n', 'utf8');
  console.log(`[sftp-seed] ${memberRows.length} memberships → ${MEMBERSHIP_FILE}`);
}

main();
