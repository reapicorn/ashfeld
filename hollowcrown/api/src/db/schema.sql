CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS departments (
  id    SERIAL      PRIMARY KEY,
  name  VARCHAR(128) NOT NULL UNIQUE
);

INSERT INTO departments (name) VALUES
  ('Engineering'),
  ('IT'),
  ('Finance'),
  ('HR'),
  ('Legal'),
  ('Operations')
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS employees (
  id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id      VARCHAR(16)  NOT NULL UNIQUE,
  first_name       VARCHAR(128) NOT NULL,
  last_name        VARCHAR(128) NOT NULL,
  email            VARCHAR(255) NOT NULL UNIQUE,
  phone            VARCHAR(32),
  department       VARCHAR(128) NOT NULL,
  job_title        VARCHAR(128) NOT NULL,
  manager_id       UUID         REFERENCES employees(id) ON DELETE SET NULL,
  hire_date        DATE         NOT NULL,
  status           VARCHAR(16)  NOT NULL DEFAULT 'active'
                     CHECK (status IN ('active','on-leave','terminated')),
  termination_date DATE,
  created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_employees_status     ON employees (status);
CREATE INDEX IF NOT EXISTS idx_employees_department ON employees (department);
CREATE INDEX IF NOT EXISTS idx_employees_last_name  ON employees (last_name);
