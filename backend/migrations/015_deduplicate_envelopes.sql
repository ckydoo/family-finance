-- 015_deduplicate_envelopes.sql
-- Fix duplicate envelope creation and clean up existing duplicates.

-- 1. Allow database maintenance / migrations when auth.uid() is null (SQL editor / postgres role)
create or replace function public.guard_financial_archive() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null then
    if tg_table_name = 'envelope' and coalesce(old.is_archived,false) = false and coalesce(new.is_archived,false) = true
       and not public.is_family_admin(new.space_id) then raise exception 'ADMIN_REQUIRED'; end if;
    if tg_table_name = 'goal' and old.status <> 'archived' and new.status = 'archived'
       and not public.is_family_admin(new.space_id) then raise exception 'ADMIN_REQUIRED'; end if;
    if tg_table_name = 'recurring_rule' and old.archived_at is null and new.archived_at is not null
       and not public.is_family_admin(new.space_id) then raise exception 'ADMIN_REQUIRED'; end if;
  end if;
  return new;
end; $$;

-- 2. Clean up duplicate shared envelopes in public.envelope per space
with ranked as (
  select id,
         row_number() over (
           partition by space_id, lower(trim(name))
           order by
             (case when template_key is not null then 1 else 2 end),
             limit_minor desc,
             created_at asc
         ) as rn
  from public.envelope
  where is_archived = false and sharing = 'shared'
)
update public.envelope
set is_archived = true
where id in (select id from ranked where rn > 1);

-- 3. Prevent duplicate active shared envelopes at database level
create unique index if not exists envelope_space_name_unique
  on public.envelope(space_id, lower(trim(name)))
  where is_archived = false and sharing = 'shared';

-- 4. Make save_family_setup idempotent with respect to envelope names
create or replace function public.save_family_setup(
  p_primary text, p_secondary text, p_month_start int, p_templates jsonb,
  p_stage text default 'complete'
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_space uuid;
  v_item jsonb;
  v_keys text[] := '{}';
  v_key text;
  v_name text;
  v_icon text;
  v_existing_id uuid;
begin
  select space_id into v_space from public.membership where user_id=auth.uid()
   and invite_status='active' and role in ('owner','co_parent') limit 1;
  if v_space is null then raise exception 'ADMIN_REQUIRED'; end if;
  if p_primary not in ('USD','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR','ZWG')
    or (p_secondary is not null and p_secondary not in ('USD','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR','ZWG'))
    or p_primary = p_secondary then raise exception 'UNSUPPORTED_CURRENCY'; end if;
  if p_month_start not between 1 and 28 then raise exception 'INVALID_MONTH_START'; end if;
  if p_stage not in ('currencies','spending','ready','complete') then raise exception 'BAD_STAGE'; end if;

  update public.family_space set base_currency=p_primary, settings=
    jsonb_strip_nulls(coalesce(settings,'{}'::jsonb) || jsonb_build_object(
      'onboarding_stage',p_stage,'primary_currency',p_primary,
      'secondary_currency',p_secondary,'month_start_day',p_month_start)) where id=v_space;

  if p_templates is not null and jsonb_typeof(p_templates) = 'array' and jsonb_array_length(p_templates) > 0 then
    for v_item in select value from jsonb_array_elements(p_templates) loop
      v_key := left(regexp_replace(lower(coalesce(v_item->>'key','')),'[^a-z0-9_]+','','g'),64);
      v_name := left(btrim(coalesce(v_item->>'name','')),60);
      v_icon := left(coalesce(nullif(v_item->>'icon',''),'money'),40);
      if v_key='' or length(v_name)<2 then raise exception 'BAD_TEMPLATE'; end if;
      v_keys := array_append(v_keys,v_key);

      -- Match existing envelope by space and case-insensitive name first
      select id into v_existing_id from public.envelope
       where space_id=v_space and lower(name)=lower(v_name) and is_archived=false limit 1;

      if v_existing_id is not null then
        update public.envelope
           set template_key=v_key, icon=v_icon, limit_currency=p_primary
         where id=v_existing_id;
      else
        insert into public.envelope(space_id,name,icon,limit_minor,limit_currency,template_key,is_archived)
          values(v_space,v_name,v_icon,0,p_primary,v_key,false)
          on conflict(space_id,template_key) where template_key is not null do update
            set name=excluded.name,icon=excluded.icon,limit_currency=excluded.limit_currency,is_archived=false;
      end if;
    end loop;

    update public.envelope set is_archived=true
     where space_id=v_space and template_key is not null and not(template_key=any(v_keys));
  end if;

  return jsonb_build_object('space_id',v_space,'stage',p_stage,'templates',cardinality(v_keys));
end; $$;
revoke all on function public.save_family_setup(text,text,int,jsonb,text) from public, anon;
grant execute on function public.save_family_setup(text,text,int,jsonb,text) to authenticated;
