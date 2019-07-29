--Missing INDEXES:

SELECT relname,
       seq_scan-idx_scan AS too_much_seq,
       CASE
           WHEN seq_scan-idx_scan>0 THEN 'Missing Index?'
           ELSE 'OK'
       END,
       pg_relation_size(relname::regclass) AS rel_size,
       seq_scan,
       idx_scan
FROM pg_stat_all_tables
WHERE schemaname='public'
  AND pg_relation_size(relname::regclass)>80000
ORDER BY too_much_seq DESC;

--
--INDEX SIZE/Useage stats:
--

SELECT t.tablename,
       indexname,
       c.reltuples AS num_rows,
       pg_size_pretty(pg_relation_size(quote_ident(t.tablename)::text)) AS table_size,
       pg_size_pretty(pg_relation_size(quote_ident(indexrelname)::text)) AS index_size,
       CASE
           WHEN indisunique THEN 'Y'
           ELSE 'N'
       END AS UNIQUE,
       idx_scan AS number_of_scans,
       idx_tup_read AS tuples_read,
       idx_tup_fetch AS tuples_fetched
FROM pg_tables t
LEFT OUTER JOIN pg_class c ON t.tablename=c.relname
LEFT OUTER JOIN
  (SELECT c.relname AS ctablename,
          ipg.relname AS indexname,
          x.indnatts AS number_of_columns,
          idx_scan,
          idx_tup_read,
          idx_tup_fetch,
          indexrelname,
          indisunique
   FROM pg_index x
   JOIN pg_class c ON c.oid = x.indrelid
   JOIN pg_class ipg ON ipg.oid = x.indexrelid
   JOIN pg_stat_all_indexes psai ON x.indexrelid = psai.indexrelid) AS foo ON t.tablename = foo.ctablename
WHERE t.schemaname='public'
ORDER BY 1,
         2;


SELECT pt.tablename AS TableName,
       t.indexname AS IndexName,
       pc.reltuples AS TotalRows,
       pg_relation_size(quote_ident(pt.tablename)),
       pg_size_pretty(pg_relation_size(quote_ident(pt.tablename)::text)) AS TableSize,
       pg_size_pretty(pg_relation_size(quote_ident(t.indexrelname)::text)) AS IndexSize,
       t.idx_scan AS TotalNumberOfScan,
       t.idx_tup_read AS TotalTupleRead,
       t.idx_tup_fetch AS TotalTupleFetched
FROM pg_tables AS pt
LEFT OUTER JOIN pg_class AS pc ON pt.tablename=pc.relname
LEFT OUTER JOIN
  (SELECT pc.relname AS TableName,
          pc2.relname AS IndexName,
          psai.idx_scan,
          psai.idx_tup_read,
          psai.idx_tup_fetch,
          psai.indexrelname
   FROM pg_index AS pi
   JOIN pg_class AS pc ON pc.oid = pi.indrelid
   JOIN pg_class AS pc2 ON pc2.oid = pi.indexrelid
   JOIN pg_stat_all_indexes AS psai ON pi.indexrelid = psai.indexrelid)AS T ON pt.tablename = T.TableName
WHERE pt.schemaname='public'
ORDER BY 4 DESC;

--
--Duplicate INDEXES
--

SELECT pg_size_pretty(SUM(pg_relation_size(idx))::BIGINT) AS SIZE,
       (array_agg(idx))[1] AS idx1,
       (array_agg(idx))[2] AS idx2,
       (array_agg(idx))[3] AS idx3,
       (array_agg(idx))[4] AS idx4
FROM
  (SELECT indexrelid::regclass AS idx,
          (indrelid::text ||E'\n'|| indclass::text ||E'\n'|| indkey::text ||E'\n'|| COALESCE(indexprs::text,'')||E'\n' || COALESCE(indpred::text,'')) AS KEY
   FROM pg_index) sub
GROUP BY KEY
HAVING COUNT(*)>1
ORDER BY SUM(pg_relation_size(idx)) DESC;

--
--low usageindexes
--
WITH table_scans AS
  (SELECT relid,
          tables.idx_scan + tables.seq_scan AS all_scans,
          (tables.n_tup_ins + tables.n_tup_upd + tables.n_tup_del) AS writes,
          pg_relation_size(relid) AS table_size
   FROM pg_stat_user_tables AS TABLES),
     all_writes AS
  (SELECT sum(writes) AS total_writes
   FROM table_scans),
     INDEXES AS
  (SELECT idx_stat.relid,
          idx_stat.indexrelid,
          idx_stat.schemaname,
          idx_stat.relname AS tablename,
          idx_stat.indexrelname AS indexname,
          idx_stat.idx_scan,
          pg_relation_size(idx_stat.indexrelid) AS index_bytes,
          indexdef ~* 'USING btree' AS idx_is_btree
   FROM pg_stat_user_indexes AS idx_stat
   JOIN pg_index USING (indexrelid)
   JOIN pg_indexes AS INDEXES ON idx_stat.schemaname = indexes.schemaname
   AND idx_stat.relname = indexes.tablename
   AND idx_stat.indexrelname = indexes.indexname
   WHERE pg_index.indisunique = FALSE ), index_ratios AS
  (SELECT schemaname,
          tablename,
          indexname,
          idx_scan,
          all_scans,
          round((CASE
                     WHEN all_scans = 0 THEN 0.0::NUMERIC
                     ELSE idx_scan::NUMERIC/all_scans * 100
                 END),2) AS index_scan_pct,
          writes,
          round((CASE
                     WHEN writes = 0 THEN idx_scan::NUMERIC
                     ELSE idx_scan::NUMERIC/writes
                 END),2) AS scans_per_write,
          pg_size_pretty(index_bytes) AS index_size,
          pg_size_pretty(table_size) AS table_size,
          idx_is_btree,
          index_bytes
   FROM INDEXES
   JOIN table_scans USING (relid)),
                                         index_groups AS
  (SELECT 'Never Used Indexes' AS reason,
          *,
          1 AS grp
   FROM index_ratios
   WHERE idx_scan = 0
     AND idx_is_btree
   UNION ALL SELECT 'Low Scans, High Writes' AS reason,
                    *,
                    2 AS grp
   FROM index_ratios
   WHERE scans_per_write <= 1
     AND index_scan_pct < 10
     AND idx_scan > 0
     AND writes > 100
     AND idx_is_btree
   UNION ALL SELECT 'Seldom Used Large Indexes' AS reason,
                    *,
                    3 AS grp
   FROM index_ratios
   WHERE index_scan_pct < 5
     AND scans_per_write > 1
     AND idx_scan > 0
     AND idx_is_btree
     AND index_bytes > 100000000
   UNION ALL SELECT 'High-Write Large Non-Btree' AS reason,
                    index_ratios.*,
                    4 AS grp
   FROM index_ratios,
        all_writes
   WHERE (writes::NUMERIC / (total_writes + 1)) > 0.02
     AND NOT idx_is_btree
     AND index_bytes > 100000000
   ORDER BY grp,
            index_bytes DESC)
SELECT reason,
       schemaname,
       tablename,
       indexname,
       index_scan_pct,
       scans_per_write,
       index_size,
       table_size
FROM index_groups;

