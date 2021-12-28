create table audit
(
  id bigserial primary key not null,
  ts timestamptz not null default current_timestamp,
  schema_name text not null,
  table_name text not null,
  operation text not null,
  j_old jsonb null,
  j_new jsonb null
);

create or replace function audit_tf() returns trigger language plpgsql as
$function$
declare
  EMPTY_JB constant jsonb := '{}'::jsonb;
begin
  if TG_OP = 'INSERT' then 
    insert into audit (schema_name, table_name, operation, j_new)
    values (TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP, to_jsonb(new));
  elsif TG_OP = 'DELETE' then 
    insert into audit (schema_name, table_name, operation, j_old)
    values (TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP, to_jsonb(old));
  elsif TG_OP = 'UPDATE' then 
    declare
      running_key text;
      running_val jsonb;
      old_jb jsonb := to_jsonb(old); 
      new_jb_audit jsonb := EMPTY_JB;
      old_jb_audit jsonb := EMPTY_JB;
    begin
      for running_key, running_val in select key, value from jsonb_each(to_jsonb(new)) loop
        if (running_val <> old_jb -> running_key) then
          new_jb_audit := new_jb_audit || jsonb_build_object(running_key, running_val);
          old_jb_audit := old_jb_audit || jsonb_build_object(running_key, old_jb -> running_key);
        end if;
      end loop;
      if new_jb_audit <> EMPTY_JB then
        insert into audit (schema_name, table_name, operation, j_new, j_old)
        values (TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP, new_jb_audit, old_jb_audit);
      end if;
    end;
  end if;    
  return null;
end;
$function$;


-- SQLi prone, to be granted to DBA only
--
create or replace function create_audit_trigger(table_name text, schema_name text default 'public') returns void language plpgsql as
$function$
begin
  execute format 
  (
  'create trigger "%1$s_audit_trigger" after insert or update or delete on %2$I.%1$I for each row execute procedure audit_tf()', 
   table_name, 
   schema_name
  );
end;
$function$;
