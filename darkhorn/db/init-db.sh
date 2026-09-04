#!/bin/bash
# darkhorn/db/init-db.sh
# PostgreSQL init script — runs inside the postgres container on first start.
# Creates all databases, the shared user, and applies the schema to each.

set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL

  -- Create databases
  CREATE DATABASE darkhorn_rest;
  CREATE DATABASE darkhorn_jdbc;
  CREATE DATABASE darkhorn_soap;
  CREATE DATABASE darkhorn_mq;

  -- Create application user
  CREATE USER darkhorn WITH PASSWORD '${DARKHORN_DB_PASSWORD:-darkhorn}';

  -- Grant privileges
  GRANT ALL PRIVILEGES ON DATABASE darkhorn_rest  TO darkhorn;
  GRANT ALL PRIVILEGES ON DATABASE darkhorn_jdbc  TO darkhorn;
  GRANT ALL PRIVILEGES ON DATABASE darkhorn_soap  TO darkhorn;
  GRANT ALL PRIVILEGES ON DATABASE darkhorn_mq    TO darkhorn;

EOSQL

apply_schema() {
  local DB=$1
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB" < /docker-entrypoint-initdb.d/schema.sql
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB" \
    -c "GRANT ALL ON ALL TABLES IN SCHEMA public TO darkhorn; GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO darkhorn;"
}

apply_schema darkhorn_rest
apply_schema darkhorn_jdbc
apply_schema darkhorn_soap
apply_schema darkhorn_mq

echo "darkhorn databases initialized."
