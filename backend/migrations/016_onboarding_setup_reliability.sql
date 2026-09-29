-- 016: make first-family setup fully resumable and empty-selection safe.
-- Selected templates are family settings (not financial history), so every
-- device can reconstruct the wizard without guessing from display names.

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

  -- Serialize retries/double submissions for this family. Unique indexes are
  -- still the final duplicate guard, while this makes the resulting selection
  -- deterministic when two requests arrive together.
  perform pg_advisory_xact_lock(hashtext(v_space::text));

  if p_primary not in ('USD','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR','ZWG')
    or (p_secondary is not null and p_secondary not in ('USD','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR','ZWG'))
    or p_primary = p_secondary then raise exception 'UNSUPPORTED_CURRENCY'; end if;
  if p_month_start not between 1 and 28 then raise exception 'INVALID_MONTH_START'; end if;
  if p_stage not in ('currencies','spending','ready','complete') then raise exception 'BAD_STAGE'; end if;
  if jsonb_typeof(coalesce(p_templates,'[]'::jsonb)) <> 'array' then raise exception 'BAD_TEMPLATES'; end if;

  for v_item in select value from jsonb_array_elements(coalesce(p_templates,'[]'::jsonb)) loop
    v_key := left(regexp_replace(lower(coalesce(v_item->>'key','')),'[^a-z0-9_]+','','g'),64);
    v_name := left(btrim(coalesce(v_item->>'name','')),60);
    v_icon := left(coalesce(nullif(v_item->>'icon',''),'money'),40);
    if v_key='' or length(v_name)<2 then raise exception 'BAD_TEMPLATE'; end if;
    if v_key = any(v_keys) then continue; end if;
    v_keys := array_append(v_keys,v_key);

    select id into v_existing_id from public.envelope
     where space_id=v_space and lower(trim(name))=lower(trim(v_name))
       and is_archived=false and sharing='shared' limit 1;

    if v_existing_id is not null then
      update public.envelope
         set template_key=v_key, icon=v_icon, limit_currency=p_primary
       where id=v_existing_id;
    else
      insert into public.envelope(
        space_id,name,icon,limit_minor,limit_currency,template_key,is_archived
      ) values(v_space,v_name,v_icon,0,p_primary,v_key,false)
      on conflict(space_id,template_key) where template_key is not null do update
        set name=excluded.name,icon=excluded.icon,
            limit_currency=excluded.limit_currency,is_archived=false;
    end if;
  end loop;

  -- An empty array is intentional: it means the family skipped all starter
  -- budgets. Only template-owned envelopes are archived; user-created budgets
  -- are never removed by onboarding.
  update public.envelope set is_archived=true
   where space_id=v_space and template_key is not null
     and not(template_key=any(v_keys));

  update public.family_space set base_currency=p_primary, settings=
    jsonb_strip_nulls(coalesce(settings,'{}'::jsonb) || jsonb_build_object(
      'onboarding_stage',p_stage,
      'onboarding_templates',coalesce(p_templates,'[]'::jsonb),
      'primary_currency',p_primary,
      'secondary_currency',p_secondary,
      'month_start_day',p_month_start
    )) where id=v_space;

  return jsonb_build_object(
    'space_id',v_space,'stage',p_stage,'templates',cardinality(v_keys)
  );
end; $$;

revoke all on function public.save_family_setup(text,text,int,jsonb,text) from public, anon;
grant execute on function public.save_family_setup(text,text,int,jsonb,text) to authenticated;
