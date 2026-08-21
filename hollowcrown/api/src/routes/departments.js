'use strict';

const express = require('express');
const { getPool } = require('../db/pool');

const router = express.Router();

router.get('/', async (req, res, next) => {
  try {
    const { rows } = await getPool().query('SELECT name FROM departments ORDER BY name');
    res.json(rows.map(r => r.name));
  } catch (err) { next(err); }
});

module.exports = router;
