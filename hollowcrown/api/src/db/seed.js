#!/usr/bin/env node
'use strict';

const { Client } = require('pg');
const { v4: uuidv4 } = require('uuid');

const FIRST_NAMES = [
  'James','Mary','John','Patricia','Robert','Jennifer','Michael','Linda',
  'William','Barbara','David','Susan','Richard','Jessica','Joseph','Sarah',
  'Thomas','Karen','Charles','Lisa','Christopher','Nancy','Daniel','Betty',
  'Matthew','Margaret','Anthony','Sandra','Mark','Ashley','Donald','Dorothy',
  'Steven','Kimberly','Paul','Emily','Andrew','Donna','Joshua','Michelle',
  'Kenneth','Carol','Kevin','Amanda','Brian','Melissa','George','Deborah',
  'Timothy','Stephanie',
];

const LAST_NAMES = [
  'Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis',
  'Rodriguez','Martinez','Hernandez','Lopez','Gonzalez','Wilson','Anderson',
  'Thomas','Taylor','Moore','Jackson','Martin','Lee','Perez','Thompson',
  'White','Harris','Sanchez','Clark','Ramirez','Lewis','Robinson','Walker',
  'Young','Allen','King','Wright','Scott','Torres','Nguyen','Hill','Flores',
  'Green','Adams','Nelson','Baker','Hall','Rivera','Campbell','Mitchell',
  'Carter','Roberts',
];

const DEPARTMENTS = ['Engineering','IT','Finance','HR','Legal','Operations'];

const TITLES = {
  Engineering: ['Software Engineer','Senior Engineer','Tech Lead','Engineering Manager','DevOps Engineer'],
  IT:          ['Systems Administrator','IT Analyst','Network Engineer','IT Manager','Support Specialist'],
  Finance:     ['Financial Analyst','Accountant','Finance Manager','Controller','Auditor'],
  HR:          ['HR Specialist','Recruiter','HR Manager','Compensation Analyst','HR Business Partner'],
  Legal:       ['Legal Counsel','Compliance Officer','Paralegal','Legal Manager','Contract Specialist'],
  Operations:  ['Operations Analyst','Project Manager','Operations Manager','Process Specialist','Coordinator'],
};

function pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; }

function randomDate(start, end) {
  return new Date(start.getTime() + Math.random() * (end.getTime() - start.getTime()));
}

function formatDate(d) {
  return d.toISOString().split('T')[0];
}

async function main() {
  const client = new Client({
    host:     process.env.PGHOST     || 'localhost',
    port:     parseInt(process.env.PGPORT || '5432', 10),
    database: process.env.PGDATABASE || 'hollowcrown',
    user:     process.env.PGUSER     || 'hollowcrown',
    password: process.env.PGPASSWORD || 'hollowcrown',
  });

  await client.connect();
  console.log('[seed] Connected to hollowcrown');

  const { rows: existing } = await client.query('SELECT COUNT(*) FROM employees');
  if (parseInt(existing[0].count, 10) > 0) {
    console.log(`[seed] ${existing[0].count} employees already exist — skipping.`);
    await client.end();
    return;
  }

  const employees = [];
  const usedEmails = new Set();
  const usedNums   = new Set();

  for (let i = 0; i < 50; i++) {
    const firstName  = pick(FIRST_NAMES);
    const lastName   = pick(LAST_NAMES);
    const department = pick(DEPARTMENTS);
    const jobTitle   = pick(TITLES[department]);

    let email = `${firstName.toLowerCase()}.${lastName.toLowerCase()}@hollowcrown.local`;
    if (usedEmails.has(email)) email = `${firstName.toLowerCase()}.${lastName.toLowerCase()}${i}@hollowcrown.local`;
    usedEmails.add(email);

    let num;
    do { num = String(Math.floor(Math.random() * 99999) + 1).padStart(5, '0'); } while (usedNums.has(num));
    usedNums.add(num);

    const rand = Math.random();
    const status = rand < 0.08 ? 'terminated' : rand < 0.12 ? 'on-leave' : 'active';
    const hireDate = randomDate(new Date('2015-01-01'), new Date('2023-12-31'));
    const terminationDate = status === 'terminated'
      ? formatDate(randomDate(hireDate, new Date()))
      : null;

    employees.push({
      id:              uuidv4(),
      employeeId:      `HC-${num}`,
      firstName,
      lastName,
      email,
      phone:           `+1-555-${String(Math.floor(Math.random() * 9000) + 1000)}`,
      department,
      jobTitle,
      hireDate:        formatDate(hireDate),
      status,
      terminationDate,
    });
  }

  // Assign managers — first employee per department becomes manager
  const managerByDept = {};
  for (const e of employees) {
    if (!managerByDept[e.department]) managerByDept[e.department] = e.id;
  }

  for (const e of employees) {
    const managerId = managerByDept[e.department];
    e.managerId = managerId === e.id ? null : managerId;
  }

  for (const e of employees) {
    await client.query(
      `INSERT INTO employees
         (id, employee_id, first_name, last_name, email, phone,
          department, job_title, manager_id, hire_date, status, termination_date)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`,
      [e.id, e.employeeId, e.firstName, e.lastName, e.email, e.phone,
       e.department, e.jobTitle, e.managerId, e.hireDate, e.status, e.terminationDate]
    );
  }

  console.log(`[seed] ${employees.length} employees inserted.`);
  await client.end();
}

main().catch(err => {
  console.error('[seed] FATAL:', err.message);
  process.exit(1);
});
