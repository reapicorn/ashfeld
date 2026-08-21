const { Pool } = require('pg');

let _pool = null;

function getPool() {
  if (!_pool) {
    _pool = new Pool({
      host:     process.env.PGHOST     || 'localhost',
      port:     parseInt(process.env.PGPORT || '5432', 10),
      database: process.env.PGDATABASE || 'darkhorn_rest',
      user:     process.env.PGUSER     || 'darkhorn',
      password: process.env.PGPASSWORD || 'darkhorn',
    });
    _pool.on('error', (err) => console.error('[PG] Unexpected error', err));
  }
  return _pool;
}

// ── Users ─────────────────────────────────────────────────────────────────────

async function getUsers(filters = {}) {
  const pool = getPool();
  const conditions = [];
  const values = [];
  let i = 1;

  if (filters.username)  { conditions.push(`username ILIKE $${i++}`);   values.push(`%${filters.username}%`); }
  if (filters.email)     { conditions.push(`email ILIKE $${i++}`);      values.push(`%${filters.email}%`); }
  if (filters.firstName) { conditions.push(`first_name ILIKE $${i++}`); values.push(`%${filters.firstName}%`); }
  if (filters.lastName)  { conditions.push(`last_name ILIKE $${i++}`);  values.push(`%${filters.lastName}%`); }
  if (filters.status)    { conditions.push(`status = $${i++}`);         values.push(filters.status); }
  if (filters.filter) {
    const match = filters.filter.match(/^(\w+)\s+eq\s+"([^"]+)"$/i);
    if (match) {
      const col = match[1].replace(/([A-Z])/g, '_$1').toLowerCase();
      conditions.push(`${col} = $${i++}`);
      values.push(match[2]);
    }
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const { rows } = await pool.query(`SELECT * FROM users ${where} ORDER BY created_at`, values);
  return rows.map(dbToUser);
}

async function getUserById(id) {
  const pool = getPool();
  const { rows } = await pool.query(
    `SELECT * FROM users WHERE id = $1 OR username = $1 LIMIT 1`, [id]
  );
  return rows.length ? dbToUser(rows[0]) : null;
}

async function getUserByUsername(username) {
  const pool = getPool();
  const { rows } = await pool.query(`SELECT * FROM users WHERE username = $1 LIMIT 1`, [username]);
  return rows.length ? dbToUser(rows[0]) : null;
}

async function createUser(user) {
  const pool = getPool();
  const now = new Date();
  const { rows } = await pool.query(
    `INSERT INTO users (id, username, email, first_name, last_name, password, status, department, title, created_at, updated_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING *`,
    [user.id, user.username, user.email, user.firstName, user.lastName,
     user.password, user.status || 'active', user.department, user.title, now, now]
  );
  return dbToUser(rows[0]);
}

async function updateUser(id, updates) {
  const pool = getPool();
  const fields = [];
  const values = [];
  let i = 1;
  const map = { email:'email', firstName:'first_name', lastName:'last_name',
                department:'department', title:'title', status:'status' };
  for (const [k, col] of Object.entries(map)) {
    if (updates[k] !== undefined) { fields.push(`${col} = $${i++}`); values.push(updates[k]); }
  }
  if (!fields.length) return getUserById(id);
  fields.push(`updated_at = $${i++}`);
  values.push(new Date());
  values.push(id);
  const { rows } = await pool.query(
    `UPDATE users SET ${fields.join(', ')} WHERE id = $${i} OR username = $${i} RETURNING *`,
    values
  );
  return rows.length ? dbToUser(rows[0]) : null;
}

async function deleteUser(id) {
  const pool = getPool();
  const { rowCount } = await pool.query(`DELETE FROM users WHERE id = $1 OR username = $1`, [id]);
  return rowCount > 0;
}

async function setUserStatus(id, status) {
  const pool = getPool();
  const { rows } = await pool.query(
    `UPDATE users SET status = $1, updated_at = $2 WHERE id = $3 OR username = $3 RETURNING *`,
    [status, new Date(), id]
  );
  return rows.length ? dbToUser(rows[0]) : null;
}

async function setUserPassword(id, password, extra = {}) {
  const pool = getPool();
  const fields = ['password = $1', 'updated_at = $2'];
  const values = [password, new Date()];
  let i = 3;
  if (extra.passwordResetAt) { fields.push(`password_reset_at = $${i++}`); values.push(extra.passwordResetAt); }
  values.push(id);
  const { rows } = await pool.query(
    `UPDATE users SET ${fields.join(', ')} WHERE id = $${i} OR username = $${i} RETURNING *`, values
  );
  return rows.length ? dbToUser(rows[0]) : null;
}

// ── Groups ────────────────────────────────────────────────────────────────────

async function getGroups() {
  const pool = getPool();
  const { rows } = await pool.query(`SELECT * FROM groups ORDER BY name`);
  return rows.map(dbToGroup);
}

async function getGroupById(id) {
  const pool = getPool();
  const { rows } = await pool.query(`SELECT * FROM groups WHERE id = $1 OR name = $1 LIMIT 1`, [id]);
  return rows.length ? dbToGroup(rows[0]) : null;
}

async function createGroup(group) {
  const pool = getPool();
  const { rows } = await pool.query(
    `INSERT INTO groups (id, name, description, created_at) VALUES ($1,$2,$3,$4) RETURNING *`,
    [group.id, group.name, group.description, new Date()]
  );
  return dbToGroup(rows[0]);
}

async function getUserGroups(userId) {
  const pool = getPool();
  const user = await getUserById(userId);
  if (!user) return null;
  const { rows } = await pool.query(
    `SELECT g.* FROM groups g
     JOIN user_groups ug ON ug.group_id = g.id
     WHERE ug.user_id = $1 ORDER BY g.name`,
    [user.id]
  );
  return rows.map(dbToGroup);
}

async function assignGroups(userId, groupIds) {
  const pool = getPool();
  const user = await getUserById(userId);
  if (!user) return null;
  for (const gid of groupIds) {
    await pool.query(
      `INSERT INTO user_groups (user_id, group_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
      [user.id, gid]
    );
  }
  await pool.query(`UPDATE users SET updated_at = $1 WHERE id = $2`, [new Date(), user.id]);
  return getUserGroups(user.id);
}

async function removeGroups(userId, groupIds) {
  const pool = getPool();
  const user = await getUserById(userId);
  if (!user) return null;
  for (const gid of groupIds) {
    await pool.query(`DELETE FROM user_groups WHERE user_id = $1 AND group_id = $2`, [user.id, gid]);
  }
  await pool.query(`UPDATE users SET updated_at = $1 WHERE id = $2`, [new Date(), user.id]);
  return getUserGroups(user.id);
}

// ── Mappers ───────────────────────────────────────────────────────────────────

function dbToUser(row) {
  return {
    id:              row.id,
    username:        row.username,
    email:           row.email,
    firstName:       row.first_name,
    lastName:        row.last_name,
    password:        row.password,
    status:          row.status,
    department:      row.department,
    title:           row.title,
    createdAt:       row.created_at,
    updatedAt:       row.updated_at,
    passwordResetAt: row.password_reset_at,
  };
}

function dbToGroup(row) {
  return {
    id:          row.id,
    name:        row.name,
    description: row.description,
    createdAt:   row.created_at,
  };
}

module.exports = {
  getPool,
  getUsers, getUserById, getUserByUsername,
  createUser, updateUser, deleteUser, setUserStatus, setUserPassword,
  getGroups, getGroupById, createGroup,
  getUserGroups, assignGroups, removeGroups,
};
