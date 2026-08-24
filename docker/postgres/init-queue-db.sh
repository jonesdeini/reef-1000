#!/bin/bash
# Runs once, only on first init of an empty postgres_data volume (standard
# postgres image behavior for anything in /docker-entrypoint-initdb.d/).
# POSTGRES_USER/POSTGRES_DB (reef_1000 / reef_1000_production) are already
# created by the image itself from the matching env vars; this just adds
# the second logical database Solid Queue needs, owned by that same role.
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE reef_1000_production_queue OWNER $POSTGRES_USER;
EOSQL
