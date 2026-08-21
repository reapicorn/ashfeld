const express = require('express');
const { v4: uuidv4 } = require('uuid');
const store = require('../persistence/store');

const router = express.Router();

// GET /api/groups
router.get('/groups', async (req, res, next) => {
  try {
    const groups = await store.getGroups();
    res.json({ totalResults: groups.length, resources: groups });
  } catch (err) { next(err); }
});

// POST /api/groups
router.post('/groups', async (req, res, next) => {
  try {
    const { name, description } = req.body;
    if (!name) return res.status(400).json({ error: 'missing_field', message: '`name` is required.' });
    const existing = await store.getGroupById(name);
    if (existing) return res.status(409).json({ error: 'conflict', message: `Group '${name}' already exists.` });
    const group = await store.createGroup({ id: uuidv4(), name, description });
    res.status(201).json(group);
  } catch (err) { next(err); }
});

// GET /api/users/:id/groups
router.get('/users/:id/groups', async (req, res, next) => {
  try {
    const groups = await store.getUserGroups(req.params.id);
    if (!groups) return res.status(404).json({ error: 'not_found', message: `User '${req.params.id}' not found.` });
    res.json({ totalResults: groups.length, resources: groups });
  } catch (err) { next(err); }
});

// POST /api/users/:id/groups — assign
router.post('/users/:id/groups', async (req, res, next) => {
  try {
    const { groupIds, groupNames } = req.body;
    if (!groupIds && !groupNames)
      return res.status(400).json({ error: 'missing_field', message: '`groupIds` or `groupNames` array is required.' });

    let resolvedIds = [];
    if (groupIds) {
      resolvedIds = groupIds;
    } else {
      for (const name of groupNames) {
        const g = await store.getGroupById(name);
        if (!g) return res.status(404).json({ error: 'group_not_found', message: `Group '${name}' not found.` });
        resolvedIds.push(g.id);
      }
    }

    const groups = await store.assignGroups(req.params.id, resolvedIds);
    if (!groups) return res.status(404).json({ error: 'not_found', message: `User '${req.params.id}' not found.` });
    res.json({ message: 'Groups assigned successfully.', totalGroups: groups.length, resources: groups });
  } catch (err) { next(err); }
});

// DELETE /api/users/:id/groups — remove
router.delete('/users/:id/groups', async (req, res, next) => {
  try {
    const { groupIds, groupNames } = req.body;
    if (!groupIds && !groupNames)
      return res.status(400).json({ error: 'missing_field', message: '`groupIds` or `groupNames` array is required.' });

    let resolvedIds = [];
    if (groupIds) {
      resolvedIds = groupIds;
    } else {
      for (const name of groupNames) {
        const g = await store.getGroupById(name);
        if (g) resolvedIds.push(g.id);
      }
    }

    const groups = await store.removeGroups(req.params.id, resolvedIds);
    if (!groups) return res.status(404).json({ error: 'not_found', message: `User '${req.params.id}' not found.` });
    res.json({ message: 'Groups removed successfully.', totalGroups: groups.length, resources: groups });
  } catch (err) { next(err); }
});

module.exports = router;
