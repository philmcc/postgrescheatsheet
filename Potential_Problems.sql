TRANSACTION ID Wraparound - 200M MAX
SELECT relname,
       age(relfrozenxid) AS xid_age,
       pg_size_pretty(pg_table_size(oid)) AS table_size
FROM pg_class
WHERE relkind = 'r'
  AND pg_table_size(oid) > 1073741824
ORDER BY age(relfrozenxid) DESC
LIMIT 20;

