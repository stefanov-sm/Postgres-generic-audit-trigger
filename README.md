# PostgreSQL generic audit trigger
### Generic audit log of inserts, updates and deletions  

Definitions in file [audit-log.sql](https://github.com/stefanov-sm/Postgres-generic-audit-trigger/blob/main/audit-log.sql).  

Table `audit.audit` and functions `audit.key_values_as_jsonb`, `audit.audit_trigger_fn` and `audit.get_pk_keys_text` must be created before running the demo.  

> [!NOTE]
> Function `audit.audit_trigger_fn` uses [JSONB subscripting](https://www.postgresql.org/docs/14/datatype-json.html#JSONB-SUBSCRIPTING) syntax, available since PG14. For older versions lines 55 - 57 in file `audit-log.sql` need to be rewritten.

**Demo**
```sql
-- drop schema if exists tests cascade;
-- create schema tests;

-- drop table if exists tests."Drop me"
create table tests."Drop me"
(
 id serial not null,
 "Is it good" boolean not null default true,
 ts timestamp with time zone not null default now(),
 uname text,
 description text,
 amount numeric,
 constraint pk_drop_me primary key (id, "Is it good")
);

-- truncate table tests."Drop me";
-- truncate table audit.audit;

select format(
'create or replace trigger %I 
 after delete or update -- or insert
 on %I.%I for each row
 execute function audit.audit_trigger_fn(%L);', 
:trigger_name, 
:schema_name, 
:table_name, 
audit.get_pk_keys_text(:schema_name, :table_name)
);

-- Create trigger. This is the output of the query above with parameter values 'drop_me_audit_trigger', 'tests' and 'Drop me'.
create or replace trigger drop_me_audit_trigger 
 after delete or update -- or insert
 on tests."Drop me" for each row
 execute function audit.audit_trigger_fn('{id,"Is it good"}');

insert into tests."Drop me" (uname, description, amount) 
 values ('Rita', 'dog', 1),  ('Луция', 'cat', 2), ('Pesho', 'hamster', 3);

insert into tests."Drop me" (uname, description, amount)
 values ('Stefan', 'human male', 4), ('Lili', 'human female', 5), ('Bubu', 'vacuum cleaner robot', 6);

select * from tests."Drop me";

update tests."Drop me" set uname = 'Lucia' where description = 'cat';
update tests."Drop me" set uname = 'Lucia' where description = 'cat'; -- nothing changes
delete from tests."Drop me" where description ~* 'robot';

select * from audit.audit;
```
|ts|schema_name|table_name|user_name|operation|payload|row_ident|
|--|-----------|----------|---------|---------|-------|---------|
|2024-02-13 12:17:44.077 +0200|tests|Drop me|some_user|UPDATE|{"new": {"uname": "Lucia"}, "old": {"uname": "Луция"}}|{"id": 2, "Is it good": true}|
|2024-02-13 12:17:45.399 +0200|tests|Drop me|some_user|UPDATE|{}|{"id": 2, "Is it good": true}|
|2024-02-13 12:17:46.424 +0200|tests|Drop me|some_user|DELETE|{"old": {"id": 6, "ts": "2024-02-13T12:17:38.647511+02:00", "uname": "Bubu", "amount": 6, "Is it good": true, "description": "vacuum cleaner robot"}}||
