'use strict';

const express = require('express');
const morgan  = require('morgan');
const { v4: uuidv4 } = require('uuid');
const store = require('./store');
const seedIfEmpty = require('./seed');

const app  = express();
const PORT = parseInt(process.env.PORT || '3001', 10);
const API_KEY = process.env.API_KEY || 'gh0stF1l3-k3y-fl4tl1n3';

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));

// ── Auth ─────────────────────────────────────────────────────────────────────

function auth(req, res, next) {
  const key = req.headers['x-api-key'] || '';
  if (key === API_KEY) return next();
  const authHeader = req.headers.authorization || '';
  if (authHeader.startsWith('Basic ')) {
    const decoded = Buffer.from(authHeader.slice(6), 'base64').toString('utf8');
    const [user, pass] = decoded.split(':');
    const expectedUser = process.env.BASIC_USER || 'wraithfile';
    const expectedPass = process.env.BASIC_PASS || 'Wr41thF1l3!';
    if (user === expectedUser && pass === expectedPass) {
      return next();
    }
  }
  res.setHeader('WWW-Authenticate', 'Basic realm="darkhorn-flatfile"');
  return res.status(401).json({ error: 'unauthorized', message: 'Provide X-API-Key or Basic Auth.' });
}

function sanitize(u) {
  const { password, ...safe } = u;
  return safe;
}

// ── Health ────────────────────────────────────────────────────────────────────

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ── Users ─────────────────────────────────────────────────────────────────────

app.get('/api/users', auth, (req, res) => {
  const users = store.getUsers(req.query);
  const startIndex = parseInt(req.query.startIndex, 10) || 0;
  const count      = parseInt(req.query.count, 10) || users.length;
  const page       = users.slice(startIndex, startIndex + count);
  res.json({ totalResults: users.length, startIndex, count: page.length, resources: page.map(sanitize) });
});

app.post('/api/users', auth, (req, res) => {
  const { username, email, firstName, lastName, password, department, title } = req.body;
  if (!username) return res.status(400).json({ error: 'missing_field', message: '`username` is required.' });
  if (store.getUserByUsername(username))
    return res.status(409).json({ error: 'conflict', message: `User '${username}' already exists.` });
  const user = store.createUser({ id: uuidv4(), username, email, firstName, lastName, password, department, title });
  res.status(201).json(sanitize(user));
});

app.get('/api/users/:id', auth, (req, res) => {
  const user = store.getUserById(req.params.id);
  if (!user) return res.status(404).json({ error: 'not_found', message: `User '${req.params.id}' not found.` });
  res.json(sanitize(user));
});

app.put('/api/users/:id', auth, (req, res) => {
  const user = store.getUserById(req.params.id);
  if (!user) return res.status(404).json({ error: 'not_found', message: `User '${req.params.id}' not found.` });
  const updated = store.updateUser(req.params.id, req.body);
  res.json(sanitize(updated));
});

app.delete('/api/users/:id', auth, (req, res) => {
  const ok = store.deleteUser(req.params.id);
  if (!ok) return res.status(404).json({ error: 'not_found', message: `User '${req.params.id}' not found.` });
  res.status(204).send();
});

app.post('/api/users/:id/suspend', auth, (req, res) => {
  const user = store.getUserById(req.params.id);
  if (!user) return res.status(404).json({ error: 'not_found', message: `User '${req.params.id}' not found.` });
  if (user.status === 'suspended') return res.status(409).json({ error: 'already_suspended', message: 'User is already suspended.' });
  res.json(sanitize(store.setUserStatus(req.params.id, 'suspended')));
});

app.post('/api/users/:id/restore', auth, (req, res) => {
  const user = store.getUserById(req.params.id);
  if (!user) return res.status(404).json({ error: 'not_found', message: `User '${req.params.id}' not found.` });
  if (user.status === 'active') return res.status(409).json({ error: 'already_active', message: 'User is already active.' });
  res.json(sanitize(store.setUserStatus(req.params.id, 'active')));
});

// ── Passwords ─────────────────────────────────────────────────────────────────

app.post('/api/users/:id/change-password', auth, (req, res) => {
  const user = store.getUserById(req.params.id);
  if (!user) return res.status(404).json({ error: 'not_found', message: `User '${req.params.id}' not found.` });
  const { currentPassword, newPassword } = req.body;
  if (!currentPassword || !newPassword)
    return res.status(400).json({ error: 'missing_field', message: '`currentPassword` and `newPassword` are required.' });
  if (user.password !== currentPassword)
    return res.status(401).json({ error: 'invalid_password', message: 'Current password is incorrect.' });
  if (user.status === 'suspended')
    return res.status(403).json({ error: 'account_suspended', message: 'Cannot change password of a suspended user.' });
  store.setUserPassword(req.params.id, newPassword);
  res.json({ message: 'Password changed successfully.' });
});

app.post('/api/users/:id/reset-password', auth, (req, res) => {
  const user = store.getUserById(req.params.id);
  if (!user) return res.status(404).json({ error: 'not_found', message: `User '${req.params.id}' not found.` });
  const { newPassword } = req.body;
  if (!newPassword)
    return res.status(400).json({ error: 'missing_field', message: '`newPassword` is required.' });
  store.setUserPassword(req.params.id, newPassword, { passwordResetAt: new Date() });
  res.json({ message: 'Password reset successfully.' });
});

// ── Groups ────────────────────────────────────────────────────────────────────

app.get('/api/groups', auth, (req, res) => {
  const groups = store.getGroups();
  res.json({ totalResults: groups.length, resources: groups });
});

app.post('/api/groups', auth, (req, res) => {
  const { name, description } = req.body;
  if (!name) return res.status(400).json({ error: 'missing_field', message: '`name` is required.' });
  if (store.getGroupById(name)) return res.status(409).json({ error: 'conflict', message: `Group '${name}' already exists.` });
  res.status(201).json(store.createGroup({ id: uuidv4(), name, description }));
});

app.get('/api/users/:id/groups', auth, (req, res) => {
  const groups = store.getUserGroups(req.params.id);
  if (!groups) return res.status(404).json({ error: 'not_found', message: `User '${req.params.id}' not found.` });
  res.json({ totalResults: groups.length, resources: groups });
});

app.post('/api/users/:id/groups', auth, (req, res) => {
  const { groupIds, groupNames } = req.body;
  if (!groupIds && !groupNames)
    return res.status(400).json({ error: 'missing_field', message: '`groupIds` or `groupNames` array is required.' });
  let resolvedIds = groupIds || [];
  if (groupNames) {
    for (const name of groupNames) {
      const g = store.getGroupById(name);
      if (!g) return res.status(404).json({ error: 'group_not_found', message: `Group '${name}' not found.` });
      resolvedIds.push(g.id);
    }
  }
  const groups = store.assignGroups(req.params.id, resolvedIds);
  if (!groups) return res.status(404).json({ error: 'not_found', message: `User '${req.params.id}' not found.` });
  res.json({ message: 'Groups assigned successfully.', totalGroups: groups.length, resources: groups });
});

app.delete('/api/users/:id/groups', auth, (req, res) => {
  const { groupIds, groupNames } = req.body;
  if (!groupIds && !groupNames)
    return res.status(400).json({ error: 'missing_field', message: '`groupIds` or `groupNames` array is required.' });
  let resolvedIds = groupIds || [];
  if (groupNames) {
    for (const name of groupNames) {
      const g = store.getGroupById(name);
      if (g) resolvedIds.push(g.id);
    }
  }
  const groups = store.removeGroups(req.params.id, resolvedIds);
  if (!groups) return res.status(404).json({ error: 'not_found', message: `User '${req.params.id}' not found.` });
  res.json({ message: 'Groups removed successfully.', totalGroups: groups.length, resources: groups });
});

// ── 404 ───────────────────────────────────────────────────────────────────────

app.use((req, res) => {
  res.status(404).json({ error: 'not_found', message: `Route ${req.method} ${req.path} not found.` });
});

// ── Start ─────────────────────────────────────────────────────────────────────

seedIfEmpty();
app.listen(PORT, '0.0.0.0', () => {
  console.log(`[darkhorn-flatfile] running at http://0.0.0.0:${PORT}`);
});
