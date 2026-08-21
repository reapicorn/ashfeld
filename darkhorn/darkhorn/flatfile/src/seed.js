'use strict';
/**
 * seed.js — populates users.csv and groups.csv on first start (if empty).
 * Called from index.js before the server starts listening.
 */

const { v4: uuidv4 } = require('uuid');
const store = require('./store');

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

function seedIfEmpty() {
  const existing = store.getUsers();
  if (existing.length > 0) {
    console.log(`[flatfile-seed] ${existing.length} users already loaded — skipping seed.`);
    return;
  }

  console.log('[flatfile-seed] Seeding 150 users + 50 groups...');

  // Groups
  const groupNames = [];
  const used = new Set();
  while (groupNames.length < GROUPS_COUNT) {
    const prefix = pick(GROUP_PREFIXES);
    const suffix = String(groupNames.length + 1).padStart(2, '0');
    const name = used.has(prefix) ? `${prefix}-${suffix}` : prefix;
    used.add(name);
    groupNames.push(name);
  }
  const groups = groupNames.map(name => store.createGroup({ id: uuidv4(), name, description: `${name} group` }));

  // Users
  const usedUids = new Set();
  for (let i = 0; i < USERS_COUNT; i++) {
    const firstName  = pick(FIRST_NAMES);
    const lastName   = pick(LAST_NAMES);
    let username = `${firstName.toLowerCase()}.${lastName.toLowerCase()}`;
    if (usedUids.has(username)) username = `${username}${i}`;
    usedUids.add(username);

    const user = store.createUser({
      id: uuidv4(), username,
      email:      `${username}@darkhorn.local`,
      firstName, lastName,
      password:   'Passw0rd!',
      status:     Math.random() < 0.1 ? 'suspended' : 'active',
      department: pick(DEPARTMENTS),
      title:      pick(TITLES),
    });

    const userGroups = pickN(groups, Math.floor(Math.random() * 4));
    if (userGroups.length) store.assignGroups(user.id, userGroups.map(g => g.id));
  }

  console.log('[flatfile-seed] Done.');
}

module.exports = seedIfEmpty;
