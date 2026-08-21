'use strict';
/**
 * darkhorn-mq worker
 *
 * Listens on queue:  darkhorn.requests
 * Replies to:        message.properties.replyTo  (per-message reply queue)
 * Correlation:       message.properties.correlationId  (echoed back)
 *
 * Message format (JSON):
 * {
 *   "operation": "AddUser" | "ModifyUser" | "DeleteUser" | "LookupUser" |
 *                "SearchUsers" | "SuspendUser" | "RestoreUser" |
 *                "ChangePassword" | "ResetPassword" |
 *                "GetGroups" | "GetUserGroups" | "AssignGroups" | "RemoveGroups",
 *   "payload": { ...operation-specific fields }
 * }
 *
 * Response format (JSON):
 * {
 *   "status": "ok" | "error",
 *   "data":   { ...result fields }  // on ok
 *   "error":  { "code": "...", "message": "..." }  // on error
 * }
 *
 * Auth: AMQP connection uses username/password from env (MQ_USER / MQ_PASS).
 * The message payload may optionally carry an "apiKey" field that must match
 * MQ_API_KEY. If MQ_API_KEY is set and the key is absent/wrong, the request
 * is rejected with an error response.
 */

const amqp  = require('amqplib');
const { v4: uuidv4 } = require('uuid');
const store = require('./store');

const MQ_URL      = process.env.MQ_URL      || 'amqp://darkhorn:Wr41thPuls3!@localhost:5672';
const MQ_QUEUE    = process.env.MQ_QUEUE    || 'darkhorn.requests';
const MQ_API_KEY  = process.env.MQ_API_KEY  || null; // optional payload-level key

const RETRY_DELAY_MS = 5000;

// ── Handlers ──────────────────────────────────────────────────────────────────

async function handle(operation, payload) {
  switch (operation) {

    case 'AddUser': {
      const { username, email, firstName, lastName, password, department, title } = payload;
      if (!username) throw { code: 'MissingField', message: '`username` is required.' };
      const existing = await store.getUserByUsername(username);
      if (existing) throw { code: 'Conflict', message: `User '${username}' already exists.` };
      const user = await store.createUser({ id: uuidv4(), username, email, firstName, lastName, password, department, title });
      return { user };
    }

    case 'ModifyUser': {
      const { id, ...updates } = payload;
      if (!id) throw { code: 'MissingField', message: '`id` is required.' };
      const existing = await store.getUserById(id);
      if (!existing) throw { code: 'NotFound', message: `User '${id}' not found.` };
      const user = await store.updateUser(id, updates);
      return { user };
    }

    case 'DeleteUser': {
      const { id } = payload;
      if (!id) throw { code: 'MissingField', message: '`id` is required.' };
      const ok = await store.deleteUser(id);
      if (!ok) throw { code: 'NotFound', message: `User '${id}' not found.` };
      return { deleted: true };
    }

    case 'LookupUser': {
      const { id } = payload;
      if (!id) throw { code: 'MissingField', message: '`id` is required.' };
      const user = await store.getUserById(id);
      if (!user) throw { code: 'NotFound', message: `User '${id}' not found.` };
      return { user };
    }

    case 'SearchUsers': {
      const { startIndex, count, ...filters } = payload;
      const all  = await store.getUsers(filters);
      const si   = startIndex || 0;
      const cnt  = count      || all.length;
      const page = all.slice(si, si + cnt);
      return { totalResults: all.length, startIndex: si, count: page.length, users: page };
    }

    case 'SuspendUser': {
      const { id } = payload;
      if (!id) throw { code: 'MissingField', message: '`id` is required.' };
      const existing = await store.getUserById(id);
      if (!existing) throw { code: 'NotFound', message: `User '${id}' not found.` };
      if (existing.status === 'suspended') throw { code: 'AlreadySuspended', message: 'User is already suspended.' };
      const user = await store.setUserStatus(id, 'suspended');
      return { user };
    }

    case 'RestoreUser': {
      const { id } = payload;
      if (!id) throw { code: 'MissingField', message: '`id` is required.' };
      const existing = await store.getUserById(id);
      if (!existing) throw { code: 'NotFound', message: `User '${id}' not found.` };
      if (existing.status === 'active') throw { code: 'AlreadyActive', message: 'User is already active.' };
      const user = await store.setUserStatus(id, 'active');
      return { user };
    }

    case 'ChangePassword': {
      const { id, currentPassword, newPassword } = payload;
      if (!id || !currentPassword || !newPassword)
        throw { code: 'MissingField', message: '`id`, `currentPassword` and `newPassword` are required.' };
      const existing = await store.getUserById(id);
      if (!existing) throw { code: 'NotFound', message: `User '${id}' not found.` };
      if (existing.status === 'suspended') throw { code: 'AccountSuspended', message: 'Cannot change password of a suspended user.' };
      const storedPw = await store.getUserPassword(id);
      if (storedPw !== currentPassword) throw { code: 'InvalidPassword', message: 'Current password is incorrect.' };
      await store.setUserPassword(id, newPassword);
      return { message: 'Password changed successfully.' };
    }

    case 'ResetPassword': {
      const { id, newPassword } = payload;
      if (!id || !newPassword)
        throw { code: 'MissingField', message: '`id` and `newPassword` are required.' };
      const existing = await store.getUserById(id);
      if (!existing) throw { code: 'NotFound', message: `User '${id}' not found.` };
      await store.setUserPassword(id, newPassword, { passwordResetAt: new Date() });
      return { message: 'Password reset successfully.' };
    }

    case 'GetGroups': {
      const groups = await store.getGroups();
      return { totalResults: groups.length, groups };
    }

    case 'GetUserGroups': {
      const { userId } = payload;
      if (!userId) throw { code: 'MissingField', message: '`userId` is required.' };
      const groups = await store.getUserGroups(userId);
      if (!groups) throw { code: 'NotFound', message: `User '${userId}' not found.` };
      return { totalResults: groups.length, groups };
    }

    case 'AssignGroups': {
      const { userId, groupIds, groupNames } = payload;
      if (!userId) throw { code: 'MissingField', message: '`userId` is required.' };
      let ids = groupIds ? [...groupIds] : [];
      if (groupNames) {
        for (const name of groupNames) {
          const g = await store.getGroupById(name);
          if (!g) throw { code: 'NotFound', message: `Group '${name}' not found.` };
          ids.push(g.id);
        }
      }
      const groups = await store.assignGroups(userId, ids);
      if (!groups) throw { code: 'NotFound', message: `User '${userId}' not found.` };
      return { message: 'Groups assigned successfully.', totalGroups: groups.length, groups };
    }

    case 'RemoveGroups': {
      const { userId, groupIds, groupNames } = payload;
      if (!userId) throw { code: 'MissingField', message: '`userId` is required.' };
      let ids = groupIds ? [...groupIds] : [];
      if (groupNames) {
        for (const name of groupNames) {
          const g = await store.getGroupById(name);
          if (g) ids.push(g.id);
        }
      }
      const groups = await store.removeGroups(userId, ids);
      if (!groups) throw { code: 'NotFound', message: `User '${userId}' not found.` };
      return { message: 'Groups removed successfully.', totalGroups: groups.length, groups };
    }

    default:
      throw { code: 'UnknownOperation', message: `Unknown operation '${operation}'.` };
  }
}

// ── Worker loop ───────────────────────────────────────────────────────────────

async function startWorker() {
  console.log(`[darkhorn-mq] Connecting to ${MQ_URL.replace(/:\/\/[^@]+@/, '://***@')}...`);
  const conn    = await amqp.connect(MQ_URL);
  const channel = await conn.createChannel();

  await channel.assertQueue(MQ_QUEUE, { durable: true });
  channel.prefetch(1);

  console.log(`[darkhorn-mq] Listening on queue '${MQ_QUEUE}'`);

  channel.consume(MQ_QUEUE, async (msg) => {
    if (!msg) return;

    let response;
    try {
      const body = JSON.parse(msg.content.toString());
      const { operation, payload = {}, apiKey } = body;

      // Optional API key check
      if (MQ_API_KEY && apiKey !== MQ_API_KEY) {
        response = { status: 'error', error: { code: 'Unauthorized', message: 'Invalid or missing apiKey.' } };
      } else {
        const data = await handle(operation, payload);
        response = { status: 'ok', data };
      }
    } catch (err) {
      if (err.code) {
        response = { status: 'error', error: { code: err.code, message: err.message } };
      } else {
        console.error('[darkhorn-mq] Unexpected error:', err.message);
        response = { status: 'error', error: { code: 'InternalError', message: err.message } };
      }
    }

    // Reply
    if (msg.properties.replyTo) {
      channel.sendToQueue(
        msg.properties.replyTo,
        Buffer.from(JSON.stringify(response)),
        {
          correlationId: msg.properties.correlationId,
          contentType:   'application/json',
        }
      );
    }

    channel.ack(msg);
  });
}

// ── Entry point with retry ────────────────────────────────────────────────────

(async function main() {
  for (;;) {
    try {
      await startWorker();
      break; // connected — loop is maintained by amqplib callbacks
    } catch (err) {
      console.error(`[darkhorn-mq] Connection failed: ${err.message} — retrying in ${RETRY_DELAY_MS / 1000}s`);
      await new Promise(r => setTimeout(r, RETRY_DELAY_MS));
    }
  }
})();
