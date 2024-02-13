-- Generic audit log trigger implemenatation
-- S. Stefanov, Revision Feb 2024

-- drop schema if exists audit cascade;
create schema audit;

-- drop table if exists audit.audit
create table audit.audit
(
  ts timestamp with time zone not null default current_timestamp,
  schema_name text not null,
  table_name text not null,
  user_name text not null,
  operation text not null,
  payload jsonb not null,
  row_ident jsonb
);

-- drop function if exists audit.key_values_as_jsonb;
create or replace function audit.key_values_as_jsonb(fields text, src record)
returns jsonb language plpgsql as
$function$
declare
  retval jsonb;
begin
  execute format(
     'select jsonb_build_object(%s);',
     array_to_string(array(select format('%1$L,$1.%1$I', s) from unnest(fields::text[]) s), ',')
    ) into retval using src;
  return nullif(retval, '{}');
end;
$function$;

-- drop function if exists audit.audit_trigger_fn;
create or replace function audit.audit_trigger_fn()
returns trigger language plpgsql as
$function$
declare
  EMPTYJB constant jsonb := '{}';
  v_old jsonb := to_jsonb(old);
  v_new jsonb := to_jsonb(new);
  audit_old jsonb := EMPTYJB;
  audit_new jsonb := EMPTYJB;
  running_key text;
begin
  case TG_OP
    when 'INSERT' then
      insert into audit.audit (schema_name, table_name, user_name, operation, payload)
      values (TG_TABLE_SCHEMA, TG_TABLE_NAME, current_user, TG_OP, jsonb_build_object('new',v_new));
    when 'DELETE' then
      insert into audit.audit (schema_name, table_name, user_name, operation, payload)
      values (TG_TABLE_SCHEMA, TG_TABLE_NAME, current_user, TG_OP, jsonb_build_object('old',v_old));
    when 'UPDATE' then
      for running_key in select jsonb_object_keys(v_new) loop
        if v_new[running_key] != v_old[running_key] then
           audit_new[running_key] := v_new[running_key];
           audit_old[running_key] := v_old[running_key];
        end if;
      end loop;
      insert into audit.audit (schema_name, table_name, user_name, operation, payload, row_ident)
      values (
        TG_TABLE_SCHEMA, TG_TABLE_NAME, current_user, TG_OP,
        case when audit_new != EMPTYJB then jsonb_build_object('new',audit_new,'old',audit_old) else EMPTYJB end,
        audit.key_values_as_jsonb(TG_ARGV[0], new));
  end case;
  return null;
end;
$function$;

-- drop function if exists audit.get_pk_keys_text;
create or replace function audit.get_pk_keys_text(schemaname text, tablename text)
returns text language sql stable as
$function$
select coalesce(array_agg(column_name)::text, '{}')
from information_schema.table_constraints
join information_schema.constraint_column_usage using (constraint_name, table_schema, table_name)
where constraint_type = 'PRIMARY KEY'
  and table_schema = schemaname
  and table_name = tablename;
$function$;

-- Generate 'create trigger' statement
select format(
'create or replace trigger %I
 after delete or update -- or insert
 on %I.%I for each row
 execute function audit.audit_trigger_fn(%L)',
:trigger_name,
:schema_name,
:table_name,
audit.get_pk_keys_text(:schema_name, :table_name)
);
