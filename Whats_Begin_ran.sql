--Running Querries:

SELECT datname,
       pid,
       state,
       query
FROM pg_stat_activity
WHERE usename = 'postgres';

--Kill a process:

SELECT pg_cancel_backend(pid OF the postgres process);

--  Kill Everything on a db:
--    PostgreSQL 9.2 and above:

SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
  AND pg_stat_activity.datname = 'TARGET_DB';

--See all locks in db:

SELECT pg_class.relname,
       pg_locks.*
FROM pg_class,
     pg_locks
WHERE pg_class.relfilenode=pg_locks.relation;


SELECT *
FROM pg_locks pl
LEFT JOIN pg_stat_activity psa ON pl.pid = psa.pid;


SELECT blockeda.pid AS blocked_pid,
       blockeda.query AS blocked_query,
       blockinga.pid AS blocking_pid,
       blockinga.query AS blocking_query
FROM pg_catalog.pg_locks blockedl
JOIN pg_stat_activity blockeda ON blockedl.pid = blockeda.pid
JOIN pg_catalog.pg_locks blockingl ON(blockingl.transactionid=blockedl.transactionid
                                      AND blockedl.pid != blockingl.pid)
JOIN pg_stat_activity blockinga ON blockingl.pid = blockinga.pid
WHERE NOT blockedl.granted
  AND blockinga.datname='TARGET_DB';

