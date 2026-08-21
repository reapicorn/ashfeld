'use strict';

const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { getPool } = require('../db/pool');

const router = express.Router();

// ── Helpers ───────────────────────────────────────────────────────────────────

function dbToEmployee(row) {
  return {
    id:              row.id,
    employeeId:      row.employee_id,
    firstName:       row.first_name,
    lastName:        row.last_name,
    email:           row.email,
    phone:           row.phone           || '',
    department:      row.department,
    jobTitle:        row.job_title,
    managerId:       row.manager_id      || null,
    managerName:     row.manager_name    || null,
    hireDate:        row.hire_date,
    status:          row.status,
    terminationDate: row.termination_date || null,
    createdAt:       row.created_at,
    updatedAt:       row.updated_at,
  };
}

function nextEmployeeId(existing) {
  const nums = existing
    .map(id => parseInt(id.replace('HC-', ''), 10))
    .filter(n => !isNaN(n));
  const max = nums.length ? Math.max(...nums) : 0;
  return `HC-${String(max + 1).padStart(5, '0')}`;
}

// ── GET /api/employees ────────────────────────────────────────────────────────

router.get('/', async (req, res, next) => {
  try {
    const pool = getPool();
    const conditions = [];
    const values = [];
    let i = 1;

    if (req.query.search) {
      conditions.push(`(e.first_name ILIKE $${i} OR e.last_name ILIKE $${i} OR e.email ILIKE $${i} OR e.employee_id ILIKE $${i})`);
      values.push(`%${req.query.search}%`);
      i++;
    }
    if (req.query.department) { conditions.push(`e.department = $${i++}`); values.push(req.query.department); }
    if (req.query.status)     { conditions.push(`e.status = $${i++}`);     values.push(req.query.status); }

    const where  = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
    const limit  = Math.min(parseInt(req.query.limit  || '25', 10), 100);
    const offset = parseInt(req.query.offset || '0', 10);

    const { rows: countRows } = await pool.query(
      `SELECT COUNT(*) FROM employees e ${where}`, values
    );
    const total = parseInt(countRows[0].count, 10);

    const { rows } = await pool.query(
      `SELECT e.*,
              CONCAT(m.first_name, ' ', m.last_name) AS manager_name
       FROM employees e
       LEFT JOIN employees m ON m.id = e.manager_id
       ${where}
       ORDER BY e.last_name, e.first_name
       LIMIT $${i++} OFFSET $${i++}`,
      [...values, limit, offset]
    );

    res.json({ total, limit, offset, resources: rows.map(dbToEmployee) });
  } catch (err) { next(err); }
});

// ── POST /api/employees ───────────────────────────────────────────────────────

router.post('/', async (req, res, next) => {
  try {
    const pool = getPool();
    const { firstName, lastName, email, phone, department, jobTitle, managerId, hireDate } = req.body;

    if (!firstName || !lastName || !email || !department || !jobTitle || !hireDate)
      return res.status(400).json({ error: 'missing_field', message: 'firstName, lastName, email, department, jobTitle and hireDate are required.' });

    const { rows: existing } = await pool.query('SELECT employee_id FROM employees ORDER BY employee_id');
    const employeeId = nextEmployeeId(existing.map(r => r.employee_id));

    const { rows } = await pool.query(
      `INSERT INTO employees
         (id, employee_id, first_name, last_name, email, phone, department, job_title, manager_id, hire_date)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,
      [uuidv4(), employeeId, firstName, lastName, email, phone || null,
       department, jobTitle, managerId || null, hireDate]
    );
    res.status(201).json(dbToEmployee(rows[0]));
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ error: 'conflict', message: 'Email already in use.' });
    next(err);
  }
});

// ── GET /api/employees/:id ────────────────────────────────────────────────────

router.get('/:id', async (req, res, next) => {
  try {
    const { rows } = await getPool().query(
      `SELECT e.*, CONCAT(m.first_name, ' ', m.last_name) AS manager_name
       FROM employees e
       LEFT JOIN employees m ON m.id = e.manager_id
       WHERE e.id::text = $1 OR e.employee_id = $1`,
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'not_found', message: `Employee '${req.params.id}' not found.` });
    res.json(dbToEmployee(rows[0]));
  } catch (err) { next(err); }
});

// ── PUT /api/employees/:id ────────────────────────────────────────────────────

router.put('/:id', async (req, res, next) => {
  try {
    const pool = getPool();
    const { rows: found } = await pool.query(
      `SELECT id FROM employees WHERE id::text = $1 OR employee_id = $1`, [req.params.id]
    );
    if (!found.length) return res.status(404).json({ error: 'not_found', message: `Employee '${req.params.id}' not found.` });
    const id = found[0].id;

    const fields = [];
    const values = [];
    let i = 1;
    const map = {
      firstName: 'first_name', lastName: 'last_name', email: 'email',
      phone: 'phone', department: 'department', jobTitle: 'job_title',
      managerId: 'manager_id', hireDate: 'hire_date',
    };
    for (const [k, col] of Object.entries(map)) {
      if (req.body[k] !== undefined) { fields.push(`${col} = $${i++}`); values.push(req.body[k] || null); }
    }
    if (!fields.length) return res.status(400).json({ error: 'no_fields', message: 'No updatable fields provided.' });

    fields.push(`updated_at = $${i++}`); values.push(new Date()); values.push(id);
    const { rows } = await pool.query(
      `UPDATE employees SET ${fields.join(', ')} WHERE id = $${i} RETURNING *`, values
    );
    res.json(dbToEmployee(rows[0]));
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ error: 'conflict', message: 'Email already in use.' });
    next(err);
  }
});

// ── POST /api/employees/:id/terminate ─────────────────────────────────────────

router.post('/:id/terminate', async (req, res, next) => {
  try {
    const pool = getPool();
    const { rows: found } = await pool.query(
      `SELECT id, status FROM employees WHERE id::text = $1 OR employee_id = $1`, [req.params.id]
    );
    if (!found.length) return res.status(404).json({ error: 'not_found', message: `Employee '${req.params.id}' not found.` });
    if (found[0].status === 'terminated') return res.status(409).json({ error: 'already_terminated', message: 'Employee is already terminated.' });

    const terminationDate = req.body.terminationDate || new Date().toISOString().split('T')[0];
    const { rows } = await pool.query(
      `UPDATE employees SET status = 'terminated', termination_date = $1, updated_at = $2 WHERE id = $3 RETURNING *`,
      [terminationDate, new Date(), found[0].id]
    );
    res.json(dbToEmployee(rows[0]));
  } catch (err) { next(err); }
});

// ── POST /api/employees/:id/set-status ───────────────────────────────────────

router.post('/:id/set-status', async (req, res, next) => {
  try {
    const pool = getPool();
    const { status } = req.body;
    if (!['active','on-leave'].includes(status))
      return res.status(400).json({ error: 'invalid_status', message: 'status must be active or on-leave.' });

    const { rows: found } = await pool.query(
      `SELECT id FROM employees WHERE id::text = $1 OR employee_id = $1`, [req.params.id]
    );
    if (!found.length) return res.status(404).json({ error: 'not_found', message: `Employee '${req.params.id}' not found.` });

    const { rows } = await pool.query(
      `UPDATE employees SET status = $1, updated_at = $2 WHERE id = $3 RETURNING *`,
      [status, new Date(), found[0].id]
    );
    res.json(dbToEmployee(rows[0]));
  } catch (err) { next(err); }
});

module.exports = router;
