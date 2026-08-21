#!/usr/bin/env node
/**
 * generate-seed-ldif.js
 * Generates 02-users.ldif and 03-groups.ldif for darkhorn-ldap.
 *
 * Usage:
 *   node generate-seed-ldif.js
 *
 * Output files are written alongside this script.
 */

'use strict';

const fs   = require('fs');
const path = require('path');

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

function generateGroups() {
  const groups = [];
  const used = new Set();
  while (groups.length < GROUPS_COUNT) {
    const prefix = pick(GROUP_PREFIXES);
    const suffix = String(groups.length + 1).padStart(2, '0');
    const name = used.has(prefix) ? `${prefix}-${suffix}` : prefix;
    used.add(name);
    groups.push({ name, description: `${name} group` });
  }
  return groups;
}

function generateUsers(groups) {
  const users = [];
  const usedUids = new Set();
  for (let i = 0; i < USERS_COUNT; i++) {
    const firstName  = pick(FIRST_NAMES);
    const lastName   = pick(LAST_NAMES);
    let uid = `${firstName.toLowerCase()}.${lastName.toLowerCase()}`;
    if (usedUids.has(uid)) uid = `${uid}${i}`;
    usedUids.add(uid);

    const userGroups = pickN(groups, Math.floor(Math.random() * 4)).map(g => g.name);
    const suspended  = Math.random() < 0.1;
    users.push({
      uid,
      cn:         `${firstName} ${lastName}`,
      sn:         lastName,
      givenName:  firstName,
      mail:       `${uid}@darkhorn.local`,
      password:   'Passw0rd!',
      department: pick(DEPARTMENTS),
      title:      pick(TITLES),
      groups:     userGroups,
      suspended,
    });
  }
  return users;
}

function buildUsersLdif(users) {
  const lines = [];
  for (const u of users) {
    lines.push(`dn: uid=${u.uid},ou=People,dc=darkhorn,dc=local`);
    lines.push(`objectClass: inetOrgPerson`);
    lines.push(`objectClass: organizationalPerson`);
    lines.push(`objectClass: person`);
    lines.push(`uid: ${u.uid}`);
    lines.push(`cn: ${u.cn}`);
    lines.push(`sn: ${u.sn}`);
    lines.push(`givenName: ${u.givenName}`);
    lines.push(`mail: ${u.mail}`);
    lines.push(`userPassword: ${u.password}`);
    lines.push(`departmentNumber: ${u.department}`);
    lines.push(`title: ${u.title}`);
    if (u.suspended) lines.push(`description: suspended`);
    lines.push('');
  }
  return lines.join('\n');
}

function buildGroupsLdif(groups, users) {
  // Collect user DNs per group
  const memberMap = {};
  for (const g of groups) memberMap[g.name] = [];
  for (const u of users) {
    for (const gname of u.groups) {
      if (memberMap[gname]) memberMap[gname].push(`uid=${u.uid},ou=People,dc=darkhorn,dc=local`);
    }
  }

  const lines = [];
  for (const g of groups) {
    lines.push(`dn: cn=${g.name},ou=Groups,dc=darkhorn,dc=local`);
    lines.push(`objectClass: groupOfNames`);
    lines.push(`cn: ${g.name}`);
    lines.push(`description: ${g.description}`);
    const members = memberMap[g.name];
    // groupOfNames requires at least one member
    if (members.length === 0) {
      lines.push(`member: cn=svc-darkhorn,ou=People,dc=darkhorn,dc=local`);
    } else {
      for (const m of members) lines.push(`member: ${m}`);
    }
    lines.push('');
  }
  return lines.join('\n');
}

const groups = generateGroups();
const users  = generateUsers(groups);

const outDir = path.join(__dirname, '..', 'bootstrap');
fs.writeFileSync(path.join(outDir, '02-users.ldif'),  buildUsersLdif(users),        'utf8');
fs.writeFileSync(path.join(outDir, '03-groups.ldif'), buildGroupsLdif(groups, users),'utf8');

console.log(`[ldap-seed] ${users.length} users  → bootstrap/02-users.ldif`);
console.log(`[ldap-seed] ${groups.length} groups → bootstrap/03-groups.ldif`);
