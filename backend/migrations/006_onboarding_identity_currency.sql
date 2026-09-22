-- 006: save onboarding identity and supported family currency atomically.
-- This overload preserves the older create_space(text,text) RPC for clients
-- that have not updated yet.

create or replace function public.create_space(
  p_name text,
  p_household text,
  p_base_currency text,
  p_preferred_name text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_space uuid;
  v_user uuid := auth.uid();
  v_code text;
  v_display_name text;
begin
  if v_user is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if btrim(p_name) = '' then raise exception 'FAMILY_NAME_REQUIRED'; end if;
  if p_base_currency not in ('USD', 'ZWG') then
    raise exception 'UNSUPPORTED_CURRENCY';
  end if;
  if public.family_name_taken(p_name) then
    raise exception 'FAMILY_NAME_TAKEN';
  end if;

  v_display_name := coalesce(
    nullif(btrim(p_preferred_name), ''),
    nullif(split_part(coalesce(
      (select email from auth.users where id = v_user), ''), '@', 1), ''),
    'Member'
  );

  insert into public.user_profile (id, name, email)
  values (
    v_user,
    v_display_name,
    (select email from auth.users where id = v_user)
  )
  on conflict (id) do update set
    name = excluded.name,
    email = coalesce(public.user_profile.email, excluded.email);

  v_code := 'MHRI-' || upper(substr(md5(random()::text), 1, 4));

  insert into public.family_space (name, household_type, base_currency)
  values (btrim(p_name), p_household, p_base_currency)
  returning id into v_space;

  insert into public.membership
    (space_id, user_id, role, sharing_level, invite_status, invite_code, joined_at)
  values (v_space, v_user, 'owner', 'full', 'active', v_code, now());

  return jsonb_build_object('id', v_space, 'invite_code', v_code);
end;
$$;

grant execute on function public.create_space(text,text,text,text)
  to authenticated;

-- Persists onboarding role defaults for every device in the family. RLS is
-- still the security boundary; these values configure product behavior.
create or replace function public.set_role_permissions(p_permissions jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_space uuid;
begin
  select m.space_id into v_space
  from public.membership m
  where m.user_id = auth.uid()
    and m.role = 'owner'
    and m.invite_status = 'active'
  limit 1;

  if v_space is null then raise exception 'OWNER_REQUIRED'; end if;

  update public.family_space
  set settings = jsonb_set(
    coalesce(settings, '{}'::jsonb),
    '{role_permissions}',
    coalesce(p_permissions, '{}'::jsonb),
    true
  )
  where id = v_space;
end;
$$;

revoke all on function public.set_role_permissions(jsonb) from public, anon;
grant execute on function public.set_role_permissions(jsonb) to authenticated;
