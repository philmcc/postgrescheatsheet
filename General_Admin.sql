-- Reload conf
--  Option 1: From the command-line shell
--    su - postgres
--    /usr/bin/pg_ctl reload
--  Option 2: Using SQL

SELECT pg_reload_conf();

--  Using either option will not interrupt any active queries or connections to the database, thus applying these changes seemlessly.
 --  Kill Everything on a db:
--   PostgreSQL 9.2 and above:

SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
  AND pg_stat_activity.datname = 'TARGET_DB';

-- Disable connections

UPDATE pg_database
SET datallowconn = FALSE
WHERE datname = 'marks';

/* As of version 9.5, you cannot drop a Postgres database while clients are connected to it, using only dropdb utility - which is a simple wrapper around DROP DATABASE server query.
 Quite robust workaround follows:
 Connect to your server as superuser, using psql or other client. Do not use the database you want to drop.
 psql -h localhost postgres postgres
 Now using plain database client you can force drop database using three simple steps:
 1. Make sure no one can connect to this database. You can use one of following methods (the second seems safer, but works only for non-superusers).
*/ /* Method 1: update system catalog */
UPDATE pg_database
SET datallowconn = 'false'
WHERE datname = 'mydb';

/* Method 2: use ALTER DATABASE. Superusers still can connect! */
ALTER DATABASE mydb CONNECTION
LIMIT 1;

-- 2. Force disconnection of all clients connected to this database, using pg_terminate_backend.
-- For Postgres < 9.2:

SELECT pg_terminate_backend(procpid)
FROM pg_stat_activity
WHERE datname = 'mydb';


FOR Postgres versions >= 9.2 CHANGE procpid TO pid:
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'mydb';

-- 3. Drop it.

DROP DATABASE mydb;

