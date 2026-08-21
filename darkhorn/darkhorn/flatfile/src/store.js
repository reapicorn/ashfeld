'use strict';

const fs      = require('fs');
const path    = require('path');
const { parse }     = require('csv-parse/sync');
const { stringify } = require('csv-stringify/sync');

const DATA_DIR = process.env.DATA_DIR || path.resolve(__dirname, '..', 'data');
const USERS_FILE  = path.join(DATA_DIR, 'users.csv');
const GROUPS_FILE = path.join(DATA_DIR, 'groups.csv');
const MEMBERSHIP_FILE = path.join(DATA_DIR, 'user_groups.csv');

const USER_COLUMNS = ['id','username','email','firstName','lastName','password','status','department','title','createdAt','updatedAt','passwordResetAt'];
const GROUP_COLUMNS = ['id','name','description','createdAt'];
const MEMBERSHIP_COLUMNS = ['userId','groupId'];

// ── File helpers ──────────────────────────────────────────────────────────────

function ensureFile(filePath, columns) {
  if (!fs.existsSync(filePath)) {
    const header = stringify([columns], { header: false });
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    fs.writeFileSync(filePath, header, 'utf8');
  }
}

function readCsv(filePath, columns) {
  ensureFile(filePath, columns);
  const raw = fs.readFileSync(filePath, 'utf8');
  return parse(raw, { columns: true, skip_empty_lines: true, trim: true });
}

function writeCsv(filePath, rows, columns) {
  const out = stringify(rows, { header: true, columns });
  fs.writeFileSync(filePath, out, 'utf8');
}

// ── Users ─────────────────────────────────────────────────────────────────────

function readUsers()            { return readCsv(USERS_FILE, USER_COLUMNS); }
function writeUsers(rows)       { writeCsv(USERS_FILE, rows, USER_COLUMNS); }

function getUsers(filters = {}) {
  let rows = readUsers();
  if (filters.username)  rows = rows.filter(u => u.username.toLowerCase().includes(filters.username.toLowerCase()));
  if (filters.email)     rows = rows.filter(u => u.email && u.email.toLowerCase().includes(filters.email.toLowerCase()));
  if (filters.firstName) rows = rows.filter(u => u.firstName && u.firstName.toLowerCase().includes(filters.firstName.toLowerCase()));
  if (filters.lastName)  rows = rows.filter(u => u.lastName && u.lastName.toLowerCase().includes(filters.lastName.toLowerCase()));
  if (filters.status)    rows = rows.filter(u => u.status === filters.status);
  if (filters.filter) {
    const match = filters.filter.match(/^(\w+)\s+eq\s+"([^"]+)"$/i);
    if (match) rows = rows.filter(u => u[match[1]] === match[2]);
  }
  return rows;
}

function getUserById(id) {
  return readUsers().find(u => u.id === id || u.username === id) || null;
}

function getUserByUsername(username) {
  return readUsers().find(u => u.username === username) || null;
}

function createUser(user) {
  const rows = readUsers();
  const now = new Date().toISOString();
  const newUser = {
    id:              user.id,
    username:        user.username,
    email:           user.email    || '',
    firstName:       user.firstName || '',
    lastName:        user.lastName  || '',
    password:        user.password  || '',
    status:          user.status    || 'active',
    department:      user.department || '',
    title:           user.title      || '',
    createdAt:       now,
    updatedAt:       now,
    passwordResetAt: '',
  };
  rows.push(newUser);
  writeUsers(rows);
  return newUser;
}

function updateUser(id, updates) {
  const rows = readUsers();
  const idx  = rows.findIndex(u => u.id === id || u.username === id);
  if (idx === -1) return null;
  const allowed = ['email','firstName','lastName','department','title','status'];
  for (const k of allowed) {
    if (updates[k] !== undefined) rows[idx][k] = updates[k];
  }
  rows[idx].updatedAt = new Date().toISOString();
  writeUsers(rows);
  return rows[idx];
}

function deleteUser(id) {
  const rows = readUsers();
  const idx  = rows.findIndex(u => u.id === id || u.username === id);
  if (idx === -1) return false;
  const uid = rows[idx].id;
  rows.splice(idx, 1);
  writeUsers(rows);
  // remove memberships
  const memberships = readMemberships().filter(m => m.userId !== uid);
  writeMemberships(memberships);
  return true;
}

function setUserStatus(id, status) {
  return updateUser(id, { status });
}

function setUserPassword(id, newPassword, extra = {}) {
  const rows = readUsers();
  const idx  = rows.findIndex(u => u.id === id || u.username === id);
  if (idx === -1) return null;
  rows[idx].password  = newPassword;
  rows[idx].updatedAt = new Date().toISOString();
  if (extra.passwordResetAt) rows[idx].passwordResetAt = extra.passwordResetAt.toISOString();
  writeUsers(rows);
  return rows[idx];
}

// ── Groups ────────────────────────────────────────────────────────────────────

function readGroups()       { return readCsv(GROUPS_FILE, GROUP_COLUMNS); }
function writeGroups(rows)  { writeCsv(GROUPS_FILE, rows, GROUP_COLUMNS); }

function getGroups()   { return readGroups(); }

function getGroupById(id) {
  return readGroups().find(g => g.id === id || g.name === id) || null;
}

function createGroup(group) {
  const rows = readGroups();
  const newGroup = {
    id:          group.id,
    name:        group.name,
    description: group.description || '',
    createdAt:   new Date().toISOString(),
  };
  rows.push(newGroup);
  writeGroups(rows);
  return newGroup;
}

// ── Memberships ───────────────────────────────────────────────────────────────

function readMemberships()       { return readCsv(MEMBERSHIP_FILE, MEMBERSHIP_COLUMNS); }
function writeMemberships(rows)  { writeCsv(MEMBERSHIP_FILE, rows, MEMBERSHIP_COLUMNS); }

function getUserGroups(userId) {
  const user = getUserById(userId);
  if (!user) return null;
  const memberships = readMemberships().filter(m => m.userId === user.id);
  const groups = readGroups();
  return memberships.map(m => groups.find(g => g.id === m.groupId)).filter(Boolean);
}

function assignGroups(userId, groupIds) {
  const user = getUserById(userId);
  if (!user) return null;
  const memberships = readMemberships();
  for (const gid of groupIds) {
    const exists = memberships.find(m => m.userId === user.id && m.groupId === gid);
    if (!exists) memberships.push({ userId: user.id, groupId: gid });
  }
  writeMemberships(memberships);
  updateUser(user.id, {}); // bump updatedAt
  return getUserGroups(user.id);
}

function removeGroups(userId, groupIds) {
  const user = getUserById(userId);
  if (!user) return null;
  const memberships = readMemberships().filter(
    m => !(m.userId === user.id && groupIds.includes(m.groupId))
  );
  writeMemberships(memberships);
  updateUser(user.id, {}); // bump updatedAt
  return getUserGroups(user.id);
}

module.exports = {
  getUsers, getUserById, getUserByUsername,
  createUser, updateUser, deleteUser, setUserStatus, setUserPassword,
  getGroups, getGroupById, createGroup,
  getUserGroups, assignGroups, removeGroups,
};
