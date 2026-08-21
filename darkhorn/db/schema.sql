-- darkhorn shared schema
-- Used by both darkhorn_rest and darkhorn_jdbc databases

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── Users ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    username          VARCHAR(64) NOT NULL UNIQUE,
    email             VARCHAR(255),
    first_name        VARCHAR(128),
    last_name         VARCHAR(128),
    password          VARCHAR(255),
    status            VARCHAR(16) NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended')),
    department        VARCHAR(128),
    title             VARCHAR(128),
    password_reset_at TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_username  ON users (username);
CREATE INDEX IF NOT EXISTS idx_users_email     ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_status    ON users (status);

-- ── Groups ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS groups (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(128) NOT NULL UNIQUE,
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_groups_name ON groups (name);

-- ── User ↔ Group membership ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_groups (
    user_id   UUID NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    group_id  UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, group_id)
);

CREATE INDEX IF NOT EXISTS idx_user_groups_user  ON user_groups (user_id);
CREATE INDEX IF NOT EXISTS idx_user_groups_group ON user_groups (group_id);
