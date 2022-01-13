# PostgreSQL generic audit trigger
PostgreSQL generic audit log of inserts, updates and deletes into table "audit"  

**Demo**
```sql
-- First create table "audit", functions "audit_tf" and "create_audit_trigger".
-- These are defined in file audit-log.sql 

delete from audit;

create table if not exists test_table
(
 x integer,
 y integer,
 z text,
 t date default current_date
);

select create_audit_trigger('test_table');

insert into test_table (x, y, z) values (2, 2, 'two');
update test_table set x = 1, y = 10 where x = 2;
update test_table set x = x; -- this shall not log anything
delete from test_table where x = 1;

select * from audit;
```
|id|ts                           |schema_name|table_name|operation|j_old                                           |j_new                                          |
|--|-----------------------------|-----------|----------|---------|------------------------------------------------|-----------------------------------------------|
|30|2022-01-13 09:36:06.602 +0200|public     |test_table|INSERT   |                                                |{"t": "2022-01-13", "x": 2, "y": 2, "z": "two"}|
|31|2022-01-13 09:36:07.925 +0200|public     |test_table|UPDATE   |{"x": 2, "y": 2}                                |{"x": 1, "y": 10}                              |
|32|2022-01-13 09:36:16.864 +0200|public     |test_table|DELETE   |{"t": "2022-01-13", "x": 1, "y": 10, "z": "two"}|                                               |
