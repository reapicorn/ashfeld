'use strict';

const { Pool } = require('pg');

let _pool = null;

function getPool() {
  if (!_pool) {
    _pool = new Pool({
      host:     process.env.PGHOST     || 'localhost',
      port:     parseInt(process.env.PGPORT || '5432', 10),
      database: process.env.PGDATABASE || 'hollowcrown',
      user:     process.env.PGUSER     || 'hollowcrown',
      password: process.env.PGPASSWORD || 'hollowcrown',
    });
    _pool.on('error', err => console.error('[PG] Unexpected error', err));
  }
  return _pool;
}

module.exports = { getPool };
