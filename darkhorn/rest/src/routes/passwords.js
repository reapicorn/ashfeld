const express = require('express');
const store = require('../persistence/store');

const router = express.Router();

// POST /api/users/:id/change-password
router.post('/users/:id/change-password', async (req, res, next) => {
  try {
    const user = await store.getUserById(req.params.id);
    if (!user) return res.status(404).json({ error: 'not_found', message: `User '${req.params.id}' not found.` });
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword)
      return res.status(400).json({ error: 'missing_field', message: '`currentPassword` and `newPassword` are required.' });
    if (user.password !== currentPassword)
      return res.status(401).json({ error: 'invalid_password', message: 'Current password is incorrect.' });
    if (user.status === 'suspended')
      return res.status(403).json({ error: 'account_suspended', message: 'Cannot change password of a suspended user.' });
    await store.setUserPassword(req.params.id, newPassword);
    res.json({ message: 'Password changed successfully.' });
  } catch (err) { next(err); }
});

// POST /api/users/:id/reset-password
router.post('/users/:id/reset-password', async (req, res, next) => {
  try {
    const user = await store.getUserById(req.params.id);
    if (!user) return res.status(404).json({ error: 'not_found', message: `User '${req.params.id}' not found.` });
    const { newPassword } = req.body;
    if (!newPassword)
      return res.status(400).json({ error: 'missing_field', message: '`newPassword` is required.' });
    await store.setUserPassword(req.params.id, newPassword, { passwordResetAt: new Date() });
    res.json({ message: 'Password reset successfully.' });
  } catch (err) { next(err); }
});

module.exports = router;
