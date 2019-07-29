--TO pause run the following query ON the slave server:
--VERSION 9.x

SELECT pg_is_xlog_replay_paused();


SELECT pg_xlog_replay_pause();

--TO resume run:

SELECT pg_xlog_replay_resume();

--Postgres 10+
--TO resume run

SELECT pg_wal_replay_resume();

--Query replication DATA:
-- IS the INSTANCE a replica?

SELECT pg_is_in_recovery();

-- ON the master / CASCADE master:

SELECT *
FROM pg_stat_replication;


SELECT *
FROM pg_replication_slots;

-- ON the relica - find lag:

SELECT DISTINCT ON (rm[1]) rm[1] AS name,
                   coalesce(replace(rm[4], '''''', ''''), rm[2]) AS setting
FROM
  (SELECT row_number() OVER() rn,
                       confs,
                       regexp_matches(confs, '^[\s]*([a-z_]+)[\s]*=[\s]*([A-Za-z_\200-\377]([-A-Za-z_0-9\200-\377._:/]*)|''(([^''\n]|\\.|'''')*)'')') AS rm
   FROM regexp_split_to_table(pg_read_file('recovery.conf'), '\n') AS confs) AS recovery_confs
ORDER BY rm[1],
         rn DESC;


SELECT extract(epoch
               FROM now() - pg_last_xact_replay_timestamp()) AS replica_lag;

--Replication Slots:
-- Crete a replication slots

SELECT pg_create_physical_replication_slot('slot1');

--drop the slot:

SELECT pg_drop_replication_slot('slot1');

