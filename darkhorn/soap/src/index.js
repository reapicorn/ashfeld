'use strict';

const path    = require('path');
const express = require('express');
const morgan  = require('morgan');
const soap    = require('soap');
const { v4: uuidv4 } = require('uuid');
const store   = require('./store');

const WSDL_PATH = path.resolve(__dirname, 'service.wsdl');
const PORT      = parseInt(process.env.PORT || '3002', 10);

// ── SOAP fault helper ─────────────────────────────────────────────────────────

function fault(faultCode, message) {
  const err = new Error(message);
  err.Fault = {
    faultcode:   faultCode,
    faultstring: message,
  };
  throw err;
}

// ── Service implementation ────────────────────────────────────────────────────

const serviceImpl = {
  DarkhornUserService: {
    UserServicePort: {

      async AddUser({ username, email, firstName, lastName, password, department, title }, callback) {
        if (!username) fault('Client.MissingField', '`username` is required.');
        const existing = await store.getUserByUsername(username);
        if (existing) fault('Client.Conflict', `User '${username}' already exists.`);
        const user = await store.createUser({ id: uuidv4(), username, email, firstName, lastName, password, department, title });
        callback({ user });
      },

      async ModifyUser({ id, email, firstName, lastName, department, title, status }, callback) {
        if (!id) fault('Client.MissingField', '`id` is required.');
        const existing = await store.getUserById(id);
        if (!existing) fault('Client.NotFound', `User '${id}' not found.`);
        const user = await store.updateUser(id, { email, firstName, lastName, department, title, status });
        callback({ user });
      },

      async DeleteUser({ id }, callback) {
        if (!id) fault('Client.MissingField', '`id` is required.');
        const ok = await store.deleteUser(id);
        if (!ok) fault('Client.NotFound', `User '${id}' not found.`);
        callback({ success: true });
      },

      async LookupUser({ id }, callback) {
        if (!id) fault('Client.MissingField', '`id` is required.');
        const user = await store.getUserById(id);
        if (!user) fault('Client.NotFound', `User '${id}' not found.`);
        callback({ user });
      },

      async SearchUsers({ username, email, firstName, lastName, status, startIndex, count }, callback) {
        const all = await store.getUsers({ username, email, firstName, lastName, status });
        const si  = startIndex || 0;
        const cnt = count      || all.length;
        const page = all.slice(si, si + cnt);
        callback({
          totalResults: all.length,
          startIndex:   si,
          count:        page.length,
          users:        { user: page },
        });
      },

      async SuspendUser({ id }, callback) {
        if (!id) fault('Client.MissingField', '`id` is required.');
        const existing = await store.getUserById(id);
        if (!existing) fault('Client.NotFound', `User '${id}' not found.`);
        if (existing.status === 'suspended') fault('Client.AlreadySuspended', 'User is already suspended.');
        const user = await store.setUserStatus(id, 'suspended');
        callback({ user });
      },

      async RestoreUser({ id }, callback) {
        if (!id) fault('Client.MissingField', '`id` is required.');
        const existing = await store.getUserById(id);
        if (!existing) fault('Client.NotFound', `User '${id}' not found.`);
        if (existing.status === 'active') fault('Client.AlreadyActive', 'User is already active.');
        const user = await store.setUserStatus(id, 'active');
        callback({ user });
      },

      async ChangePassword({ id, currentPassword, newPassword }, callback) {
        if (!id || !currentPassword || !newPassword)
          fault('Client.MissingField', '`id`, `currentPassword` and `newPassword` are required.');
        const existing = await store.getUserById(id);
        if (!existing) fault('Client.NotFound', `User '${id}' not found.`);
        if (existing.status === 'suspended') fault('Client.AccountSuspended', 'Cannot change password of a suspended user.');
        const storedPw = await store.getUserPassword(id);
        if (storedPw !== currentPassword) fault('Client.InvalidPassword', 'Current password is incorrect.');
        await store.setUserPassword(id, newPassword);
        callback({ message: 'Password changed successfully.' });
      },

      async ResetPassword({ id, newPassword }, callback) {
        if (!id || !newPassword)
          fault('Client.MissingField', '`id` and `newPassword` are required.');
        const existing = await store.getUserById(id);
        if (!existing) fault('Client.NotFound', `User '${id}' not found.`);
        await store.setUserPassword(id, newPassword, { passwordResetAt: new Date() });
        callback({ message: 'Password reset successfully.' });
      },

      async GetGroups(_args, callback) {
        const groups = await store.getGroups();
        callback({ totalResults: groups.length, groups: { group: groups } });
      },

      async GetUserGroups({ userId }, callback) {
        if (!userId) fault('Client.MissingField', '`userId` is required.');
        const groups = await store.getUserGroups(userId);
        if (!groups) fault('Client.NotFound', `User '${userId}' not found.`);
        callback({ totalResults: groups.length, groups: { group: groups } });
      },

      async AssignGroups({ userId, groupIds, groupNames }, callback) {
        if (!userId) fault('Client.MissingField', '`userId` is required.');
        let ids = (groupIds && groupIds.item) ? [].concat(groupIds.item) : [];
        if (groupNames && groupNames.item) {
          for (const name of [].concat(groupNames.item)) {
            const g = await store.getGroupById(name);
            if (!g) fault('Client.NotFound', `Group '${name}' not found.`);
            ids.push(g.id);
          }
        }
        const groups = await store.assignGroups(userId, ids);
        if (!groups) fault('Client.NotFound', `User '${userId}' not found.`);
        callback({ message: 'Groups assigned successfully.', totalGroups: groups.length, groups: { group: groups } });
      },

      async RemoveGroups({ userId, groupIds, groupNames }, callback) {
        if (!userId) fault('Client.MissingField', '`userId` is required.');
        let ids = (groupIds && groupIds.item) ? [].concat(groupIds.item) : [];
        if (groupNames && groupNames.item) {
          for (const name of [].concat(groupNames.item)) {
            const g = await store.getGroupById(name);
            if (g) ids.push(g.id);
          }
        }
        const groups = await store.removeGroups(userId, ids);
        if (!groups) fault('Client.NotFound', `User '${userId}' not found.`);
        callback({ message: 'Groups removed successfully.', totalGroups: groups.length, groups: { group: groups } });
      },
    },
  },
};

// ── WS-Security basic auth check ──────────────────────────────────────────────

const SOAP_USER = process.env.SOAP_USER || 'banshee';
const SOAP_PASS = process.env.SOAP_PASS || 'B4nsh33Sc4ms!';

function checkAuth(methodName, args, headers) {
  const sec = headers && headers['Security'];
  if (!sec) {
    fault('Client.Unauthorized', 'WS-Security UsernameToken required.');
  }
  const ut = sec.UsernameToken || {};
  if (ut.Username !== SOAP_USER || ut.Password['$value'] !== SOAP_PASS) {
    fault('Client.Unauthorized', 'Invalid WS-Security credentials.');
  }
}

// ── Bootstrap ─────────────────────────────────────────────────────────────────

async function main() {
  const app = express();
  app.use(morgan('dev'));

  // Health check (plain HTTP — no SOAP needed)
  app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
  });

  const server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`[darkhorn-soap] HTTP server listening on port ${PORT}`);
  });

  // Attach SOAP server to /soap path
  const wsdl = require('fs').readFileSync(WSDL_PATH, 'utf8');
  soap.listen(server, '/soap', serviceImpl, wsdl, () => {
    console.log(`[darkhorn-soap] SOAP endpoint: http://0.0.0.0:${PORT}/soap`);
    console.log(`[darkhorn-soap] WSDL:          http://0.0.0.0:${PORT}/soap?wsdl`);
  });

  // Optional: enforce WS-Security on all operations
  // Uncomment if you want header-level auth:
  // soapServer.authorizeConnection = checkAuth;
}

main().catch(err => {
  console.error('[FATAL]', err);
  process.exit(1);
});
