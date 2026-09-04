const express = require('express');
const { v4: uuidv4 } = require('uuid');
const store = require('../persistence/store');

const router = express.Router();

function sanitize(user) {
  const { password, ...safe } = user;
  return safe;
}

// GET /api/health
router.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// GET /api/users — search / reconcile
router.get('/users', async (req, res, next) => {
  try {
    const users = await store.getUsers(req.query);
    const startIndex = parseInt(req.query.startIndex, 10) || 0;
    const count = parseInt(req.query.count, 10) || users.length;
    const page = users.slice(startIndex, startIndex + count);
    res.json({ totalResults: users.length, startIndex, count: page.length, resources: page.map(sanitize) });
  } catch (err) { next(err); }
});

// POST /api/users — add
router.post('/users', async (req, res, next) => {
  try {
    const { username, email, firstName, lastName, password, department, title } = req.body;
    if (!username) return res.status(400).json({ error: 'missing_field', message: '`username` is required.' });
    const existing = await store.getUserByUsername(username);
    if (existing) return res.status(409).json({ error: 'conflict', message: `User '${username}' already exists.` });
    const user = await store.createUser({ id: uuidv4(), username, email, firstName, lastName, password, department, title });
    res.status(201).json(sanitize(user));
  } catch (err) { next(err); }
});

// GET /api/users/:id — lookup
router.get('/users/:id', async (req, res, next) => {
  try {
    const user = await store.getUserById(req.params.id);
    if (!user) return res.status(404).json({ error: 'not_found', message: `User '${req.params.id}' not found.` });
    res.json(sanitize(user));
  } catch (err) { next(err); }
});

// PUT /api/users/:id — modify
router.put('/users/:id', async (req, res, next) => {
  try {
    const user = await store.getUserById(req.params.id);
    if (!user) return res.status(404).json({ error: 'not_found', message: `User '${req.params.id}' not found.` });
    const updated = await store.updateUser(req.params.id, req.body);
    res.json(sanitize(updated));
  } catch (err) { next(err); }
});

// DELETE /api/users/:id — delete
router.delete('/users/:id', async (req, res, next) => {
  try {
    const ok = await store.deleteUser(req.params.id);
    if (!ok) return res.status(404).json({ error: 'not_found', message: `User '${req.params.id}' not found.` });
    res.status(204).send();
  } catch (err) { next(err); }
});

// POST /api/users/:id/suspend
router.post('/users/:id/suspend', async (req, res, next) => {
  try {
    const user = await store.getUserById(req.params.id);
    if (!user) return res.status(404).json({ error: 'not_found', message: `User '${req.params.id}' not found.` });
    if (user.status === 'suspended') return res.status(409).json({ error: 'already_suspended', message: 'User is already suspended.' });
    const updated = await store.setUserStatus(req.params.id, 'suspended');
    res.json(sanitize(updated));
  } catch (err) { next(err); }
});

// POST /api/users/:id/restore
router.post('/users/:id/restore', async (req, res, next) => {
  try {
    const user = await store.getUserById(req.params.id);
    if (!user) return res.status(404).json({ error: 'not_found', message: `User '${req.params.id}' not found.` });
    if (user.status === 'active') return res.status(409).json({ error: 'already_active', message: 'User is already active.' });
    const updated = await store.setUserStatus(req.params.id, 'active');
    res.json(sanitize(updated));
  } catch (err) { next(err); }
});

module.exports = router;
