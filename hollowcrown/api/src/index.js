'use strict';

const express  = require('express');
const morgan   = require('morgan');
const cors     = require('cors');
const { getPool } = require('./db/pool');

const employeesRouter   = require('./routes/employees');
const departmentsRouter = require('./routes/departments');

const app  = express();
const PORT = parseInt(process.env.PORT || '4000', 10);

app.use(cors());
app.use(express.json());
app.use(morgan('dev'));

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ── Stats endpoint for dashboard ──────────────────────────────────────────────
app.get('/api/stats', async (req, res, next) => {
  try {
    const pool = getPool();
    const { rows } = await pool.query(`
      SELECT
        COUNT(*) FILTER (WHERE status = 'active')     AS active,
        COUNT(*) FILTER (WHERE status = 'on-leave')   AS on_leave,
        COUNT(*) FILTER (WHERE status = 'terminated') AS terminated,
        COUNT(*)                                       AS total
      FROM employees
    `);
    const byDept = await pool.query(`
      SELECT department, COUNT(*) AS count
      FROM employees
      WHERE status != 'terminated'
      GROUP BY department ORDER BY department
    `);
    const recent = await pool.query(`
      SELECT id, employee_id, first_name, last_name, department, job_title, hire_date, status
      FROM employees ORDER BY created_at DESC LIMIT 5
    `);
    res.json({
      counts: {
        active:     parseInt(rows[0].active, 10),
        onLeave:    parseInt(rows[0].on_leave, 10),
        terminated: parseInt(rows[0].terminated, 10),
        total:      parseInt(rows[0].total, 10),
      },
      byDepartment: byDept.rows.map(r => ({ department: r.department, count: parseInt(r.count, 10) })),
      recentHires:  recent.rows,
    });
  } catch (err) { next(err); }
});

app.use('/api/employees',   employeesRouter);
app.use('/api/departments', departmentsRouter);

app.use((req, res) => res.status(404).json({ error: 'not_found', message: `${req.method} ${req.path} not found.` }));

app.use((err, req, res, _next) => {
  console.error('[ERROR]', err.message);
  res.status(err.status || 500).json({ error: 'internal_error', message: err.message });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`[hollowcrown-api] running at http://0.0.0.0:${PORT}`);
});
