-- 027: MULTIPLE FAMILY SPACES.
-- One account may belong to several Mhuri spaces and choose which one is
-- active on each device. Existing family-scoped RLS remains authoritative.

create or replace function public.list_my_spaces()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'space_id', m.space_id,
    'name', s.name,
    'role', m.role,
    'invite_code', m.invite_code
  ) order by m.joined_at desc nulls last), '[]'::jsonb)
  from membership m
  join family_space s on s.id = m.space_id
  where m.user_id = auth.uid() and m.invite_status = 'active';
$$;

revoke all on function public.list_my_spaces() from public, anon;
grant execute on function public.list_my_spaces() to authenticated;

-- A fresh install restores the most recently joined space. The app can then
-- list and switch to any other active membership.
create or replace function public.restore_my_space()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'space_id', m.space_id,
    'name', s.name,
    'invite_code', m.invite_code,
    'role', m.role
  )
  from membership m
  join family_space s on s.id = m.space_id
  where m.user_id = auth.uid() and m.invite_status = 'active'
  order by m.joined_at desc nulls last
  limit 1;
$$;

revoke all on function public.restore_my_space() from public, anon;
grant execute on function public.restore_my_space() to authenticated;

create or replace function public.join_invite(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_rec public.family_invite%rowtype;
  v_email text;
  v_space uuid;
begin
  if v_user is null then raise exception 'NOT_AUTHENTICATED'; end if;
  v_email := lower(coalesce((select email from auth.users where id = v_user), ''));
  select * into v_rec from family_invite
   where upper(trim(p_code)) = code for update;
  if not found or v_rec.revoked_at is not null or v_rec.accepted_at is not null
     or v_rec.expires_at <= now() then raise exception 'INVALID_CODE'; end if;
  if v_rec.email is not null and v_rec.email <> v_email then
    raise exception 'INVALID_CODE';
  end if;
  insert into public.user_profile (id, name, email)
  values (v_user,
          coalesce(nullif(split_part(coalesce(
            (select email from auth.users where id = v_user), ''), '@', 1), ''),
            'Member'), v_email)
  on conflict (id) do update
    set name = coalesce(public.user_profile.name, excluded.name);
  v_space := v_rec.space_id;
  insert into membership
    (space_id, user_id, role, sharing_level, invite_status, joined_at)
  values (v_space, v_user, v_rec.role,
          case when v_rec.role in ('adult','co_parent') then 'full' else 'shared_only' end,
          'active', now())
  on conflict (space_id, user_id) do update
    set invite_status = 'active', joined_at = now(), role = excluded.role;
  update family_invite set accepted_by = v_user, accepted_at = now()
    where id = v_rec.id;
  insert into activity_log (space_id, actor_id, action, entity, entity_id, detail, hash)
  values (v_space, v_user, 'member.join_invite', 'family_invite', v_rec.id,
          jsonb_build_object('role', v_rec.role),
          md5(v_user::text || ':join_invite:' || clock_timestamp()));
  return v_space;
end;
$$;

revoke all on function public.join_invite(text) from public, anon;
grant execute on function public.join_invite(text) to authenticated;

-- Family administration must be explicitly scoped once an administrator can
-- own more than one space. These overloads reject cross-family identifiers.
create or replace function public.set_role_permissions(p_permissions jsonb, p_space_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.is_family_admin(p_space_id) then raise exception 'ADMIN_REQUIRED'; end if;
  update public.family_space set settings=jsonb_set(coalesce(settings,'{}'::jsonb),
    '{role_permissions}',coalesce(p_permissions,'{}'::jsonb),true) where id=p_space_id;
end; $$;

create or replace function public.update_family_name(p_name text, p_space_id uuid)
returns text language plpgsql security definer set search_path=public as $$
declare v_name text := btrim(coalesce(p_name,''));
begin
  if not public.is_family_admin(p_space_id) then raise exception 'ADMIN_REQUIRED'; end if;
  if length(v_name)<2 or length(v_name)>80 then raise exception 'INVALID_FAMILY_NAME'; end if;
  update public.family_space set name=v_name where id=p_space_id;
  insert into public.activity_log(space_id,actor_id,action,entity,entity_id,detail,hash)
  values(p_space_id,auth.uid(),'family.rename','family_space',p_space_id,
    jsonb_build_object('name',v_name),md5(p_space_id::text||':rename:'||clock_timestamp()));
  return v_name;
end; $$;

create or replace function public.change_member_role(p_member uuid,p_role text,p_space_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_old text; v_admins int;
begin
  if not public.is_family_admin(p_space_id) then raise exception 'ADMIN_REQUIRED'; end if;
  if p_member=auth.uid() then raise exception 'CANNOT_CHANGE_OWN_ROLE'; end if;
  if p_role not in ('co_parent','adult','teen','kid','viewer') then raise exception 'BAD_ROLE'; end if;
  select role into v_old from public.membership where space_id=p_space_id
    and user_id=p_member and invite_status='active' for update;
  if v_old is null then raise exception 'MEMBER_NOT_FOUND'; end if;
  if p_role='co_parent' and v_old<>'adult' then raise exception 'ADULT_REQUIRED'; end if;
  if v_old='owner' then raise exception 'USE_OWNERSHIP_TRANSFER'; end if;
  if v_old='co_parent' and p_role<>'co_parent' then
    select count(*) into v_admins from public.membership where space_id=p_space_id
      and invite_status='active' and role in ('owner','co_parent');
    if v_admins<=1 then raise exception 'LAST_ADMIN'; end if;
  end if;
  update public.membership set role=p_role where space_id=p_space_id and user_id=p_member;
end; $$;

create or replace function public.remove_family_member(p_member uuid,p_space_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_role text; v_admins int;
begin
  if not public.is_family_admin(p_space_id) then raise exception 'ADMIN_REQUIRED'; end if;
  if p_member=auth.uid() then raise exception 'CANNOT_REMOVE_SELF'; end if;
  select role into v_role from public.membership where space_id=p_space_id
    and user_id=p_member and invite_status='active' for update;
  if v_role is null then raise exception 'MEMBER_NOT_FOUND'; end if;
  if v_role in ('owner','co_parent') then
    select count(*) into v_admins from public.membership where space_id=p_space_id
      and invite_status='active' and role in ('owner','co_parent');
    if v_admins<=1 then raise exception 'LAST_ADMIN'; end if;
  end if;
  update public.membership set invite_status='left' where space_id=p_space_id and user_id=p_member;
end; $$;

create or replace function public.transfer_ownership(p_new_owner uuid,p_space_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_code text;
begin
  if public.space_role(p_space_id)<>'owner' then raise exception 'OWNER_REQUIRED'; end if;
  if p_new_owner=auth.uid() then raise exception 'SELF_TRANSFER'; end if;
  if not exists(select 1 from public.membership where space_id=p_space_id
    and user_id=p_new_owner and invite_status='active') then raise exception 'NEW_OWNER_NOT_MEMBER'; end if;
  select invite_code into v_code from public.membership where space_id=p_space_id and user_id=auth.uid();
  update public.membership set role='adult',invite_code=null where space_id=p_space_id and user_id=auth.uid();
  update public.membership set role='owner',invite_code=coalesce(v_code,invite_code)
    where space_id=p_space_id and user_id=p_new_owner;
end; $$;

create or replace function public.create_invite(p_role text,p_email text,p_space_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_code text; v_id uuid; v_open int; v_email text:=lower(btrim(coalesce(p_email,'')));
begin
  if not public.is_family_admin(p_space_id) then raise exception 'ADMIN_REQUIRED'; end if;
  if p_role not in ('adult','co_parent','teen','kid','viewer') then raise exception 'BAD_ROLE'; end if;
  select count(*) into v_open from public.family_invite where space_id=p_space_id
    and revoked_at is null and accepted_at is null and expires_at>now();
  if v_open>=5 then raise exception 'TOO_MANY_INVITES'; end if;
  loop
    v_code:='MHRI-'||upper(substr(md5(random()::text||clock_timestamp()::text),1,6));
    exit when not exists(select 1 from public.family_invite where code=v_code);
  end loop;
  insert into public.family_invite(space_id,code,role,email,created_by)
  values(p_space_id,v_code,p_role,nullif(v_email,''),auth.uid()) returning id into v_id;
  return jsonb_build_object('id',v_id,'code',v_code,'role',p_role);
end; $$;

revoke all on function public.set_role_permissions(jsonb,uuid),
  public.update_family_name(text,uuid), public.change_member_role(uuid,text,uuid),
  public.remove_family_member(uuid,uuid), public.transfer_ownership(uuid,uuid),
  public.create_invite(text,text,uuid) from public,anon;
grant execute on function public.set_role_permissions(jsonb,uuid),
  public.update_family_name(text,uuid), public.change_member_role(uuid,text,uuid),
  public.remove_family_member(uuid,uuid), public.transfer_ownership(uuid,uuid),
  public.create_invite(text,text,uuid) to authenticated;
