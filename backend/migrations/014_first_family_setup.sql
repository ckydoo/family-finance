-- 014: short, resumable first-family setup. Existing families remain complete
-- because an absent onboarding_stage means "complete". New families begin at
-- currencies and finish through one idempotent, family-scoped RPC.

alter table public.envelope drop constraint if exists envelope_limit_minor_check;
alter table public.envelope add constraint envelope_limit_minor_check
  check (limit_minor >= 0);

alter table public.envelope drop constraint if exists envelope_limit_currency_check;
alter table public.envelope add constraint envelope_limit_currency_check
  check (limit_currency in ('USD','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR','ZWG'));

alter table public.family_space drop constraint if exists family_space_base_currency_check;
alter table public.family_space add constraint family_space_base_currency_check
  check (base_currency in ('USD','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR','ZWG'));

alter table public.envelope add column if not exists template_key text;
create unique index if not exists envelope_space_template_unique
  on public.envelope(space_id, template_key) where template_key is not null;

create or replace function public.create_space(
  p_name text, p_household text, p_base_currency text, p_preferred_name text
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_space uuid; v_user uuid := auth.uid(); v_code text; v_display_name text; v_list uuid;
begin
  if v_user is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select m.space_id, m.invite_code into v_space, v_code from public.membership m
   where m.user_id=v_user and m.invite_status='active' limit 1;
  if v_space is not null then
    select id into v_list from public.shopping_list where space_id=v_space and deleted_at is null order by created_at limit 1;
    return jsonb_build_object('id',v_space,'invite_code',v_code,'default_list_id',v_list,'existing',true);
  end if;
  if length(btrim(coalesce(p_name,''))) not between 2 and 80 then raise exception 'INVALID_FAMILY_NAME'; end if;
  if p_base_currency not in ('USD','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR','ZWG') then raise exception 'UNSUPPORTED_CURRENCY'; end if;
  if public.family_name_taken(p_name) then raise exception 'FAMILY_NAME_TAKEN'; end if;
  v_display_name := coalesce(nullif(btrim(p_preferred_name),''),
    nullif(split_part(coalesce((select email from auth.users where id=v_user),''),'@',1),''),'Member');
  insert into public.user_profile(id,name,email) values
    (v_user,v_display_name,coalesce((select email from auth.users where id=v_user),''))
    on conflict(id) do update set name=coalesce(nullif(btrim(p_preferred_name),''),public.user_profile.name);
  v_code := 'MHRI-' || upper(substr(md5(random()::text),1,4));
  insert into public.family_space(name,household_type,base_currency,settings)
   values(btrim(p_name),p_household,p_base_currency,
     jsonb_build_object('onboarding_stage','currencies')) returning id into v_space;
  insert into public.membership(space_id,user_id,role,sharing_level,invite_status,invite_code,joined_at)
   values(v_space,v_user,'owner','full','active',v_code,now());
  insert into public.shopping_list(space_id,name) values(v_space,'Shopping') returning id into v_list;
  insert into public.activity_log(space_id,actor_id,action,entity,entity_id,detail,hash)
   values(v_space,v_user,'family.create','family_space',v_space,
    jsonb_build_object('name',btrim(p_name),'base_currency',p_base_currency),
    md5(v_space::text || ':create:' || clock_timestamp()));
  return jsonb_build_object('id',v_space,'invite_code',v_code,'default_list_id',v_list,'existing',false);
end; $$;
revoke all on function public.create_space(text,text,text,text) from public, anon;
grant execute on function public.create_space(text,text,text,text) to authenticated;

create or replace function public.save_family_setup(
  p_primary text, p_secondary text, p_month_start int, p_templates jsonb,
  p_stage text default 'complete'
) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_space uuid; v_item jsonb; v_keys text[] := '{}'; v_key text; v_name text; v_icon text;
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
  if jsonb_typeof(coalesce(p_templates,'[]'::jsonb)) <> 'array' then raise exception 'BAD_TEMPLATES'; end if;
  for v_item in select value from jsonb_array_elements(coalesce(p_templates,'[]'::jsonb)) loop
    v_key := left(regexp_replace(lower(coalesce(v_item->>'key','')),'[^a-z0-9_]+','','g'),64);
    v_name := left(btrim(coalesce(v_item->>'name','')),60);
    v_icon := left(coalesce(nullif(v_item->>'icon',''),'money'),40);
    if v_key='' or length(v_name)<2 then raise exception 'BAD_TEMPLATE'; end if;
    v_keys := array_append(v_keys,v_key);
    insert into public.envelope(space_id,name,icon,limit_minor,limit_currency,template_key,is_archived)
      values(v_space,v_name,v_icon,0,p_primary,v_key,false)
      on conflict(space_id,template_key) where template_key is not null do update
        set name=excluded.name,icon=excluded.icon,limit_currency=excluded.limit_currency,is_archived=false;
  end loop;
  update public.envelope set is_archived=true
   where space_id=v_space and template_key is not null and not(template_key=any(v_keys));
  return jsonb_build_object('space_id',v_space,'stage',p_stage,'templates',cardinality(v_keys));
end; $$;
revoke all on function public.save_family_setup(text,text,int,jsonb,text) from public, anon;
grant execute on function public.save_family_setup(text,text,int,jsonb,text) to authenticated;

-- Authenticated users may discover only an active, unconsumed invitation
-- addressed to their own verified account email. Codes remain hidden.
create or replace function public.my_pending_family_invite() returns jsonb
language plpgsql security definer set search_path = public as $$
declare v record; v_email text;
begin
  select lower(email) into v_email from auth.users where id=auth.uid();
  select i.id,i.code,i.role,i.space_id,s.name family_name,p.name inviter_name into v
   from public.family_invite i join public.family_space s on s.id=i.space_id
   left join public.user_profile p on p.id=i.created_by
   where i.email=v_email and i.revoked_at is null and i.accepted_at is null and i.expires_at>now()
   order by i.created_at desc limit 1;
  if v.id is null then return null; end if;
  return jsonb_build_object('id',v.id,'code',v.code,'role',v.role,
    'family_name',v.family_name,'inviter_name',coalesce(v.inviter_name,'A family admin'));
end; $$;
revoke all on function public.my_pending_family_invite() from public, anon;
grant execute on function public.my_pending_family_invite() to authenticated;
