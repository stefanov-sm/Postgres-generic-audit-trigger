# Postgres generic audit trigger
PostgreSQL generic audit log of inserts, updates and deletes into table "audit"  

**Demo**
```sql
-- create table "audit", functions "audit_tf" and "create_audit_trigger" defined in audit-log.sql 

truncate table audit;
drop table if exists test_table;
create table test_table (x integer, y integer, z text, t timestamptz default now());
select create_audit_trigger('test_table');

insert into test_table (x, y, z) values (2, 2, 'two');
update test_table set x = 1, y = 10 where x = 2;
update test_table set x = x where true; -- this shall not log anything
delete from test_table where x = 1;
select * from audit;
```
|id|ts                           |schema_name|table_name|operation|j_old                                                                 |j_new                                                                |
|--|-----------------------------|-----------|----------|---------|----------------------------------------------------------------------|---------------------------------------------------------------------|
|24|2021-12-28 20:24:35.534 +0200|public     |test_table|INSERT   |                                                                      |{"t": "2021-12-28T20:24:35.534974+02:00", "x": 2, "y": 2, "z": "two"}|
|25|2021-12-28 20:24:36.600 +0200|public     |test_table|UPDATE   |{"x": 2, "y": 2}                                                      |{"x": 1, "y": 10}                                                    |
|26|2021-12-28 20:24:38.204 +0200|public     |test_table|DELETE   |{"t": "2021-12-28T20:24:35.534974+02:00", "x": 1, "y": 10, "z": "two"}|                                                                     |
