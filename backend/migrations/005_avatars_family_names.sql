-- 005: profile pictures, unique family names, mukando groundwork (2026-09-22)
-- Idempotent — safe to re-run. Run in the Supabase SQL editor after 004.
--
-- 1. user_profile.avatar_url  — public URL of the member's picture
-- 2. storage bucket 'avatars' — public read, per-user write folders
-- 3. family names unique      — no two families with the same name
-- 4. family_name_taken()      — inline availability check for the create form

-- ── 1. avatar_url on user_profile ───────────────────────────────────────────
alter table public.user_profile
  add column if not exists avatar_url text;

-- ── 2. avatars storage bucket + policies ────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Everyone (even other families' apps) can VIEW avatars: they are served by
-- public URL. Only the owner can write/delete inside their own folder.
drop policy if exists "avatar_public_read" on storage.objects;
create policy "avatar_public_read" on storage.objects
  for select using (bucket_id = 'avatars');

drop policy if exists "avatar_owner_write" on storage.objects;
create policy "avatar_owner_write" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatar_owner_update" on storage.objects;
create policy "avatar_owner_update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatar_owner_delete" on storage.objects;
create policy "avatar_owner_delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ── 3. unique family names ──────────────────────────────────────────────────
-- Case/space-insensitive: "Moyo Family" == "moyo  family ".
-- NOTE: if old test rows already share a name this index creation fails —
-- delete or rename the duplicates first (fresh live DBs are unaffected).
create unique index if not exists family_space_name_uni
  on public.family_space (lower(btrim(name)));

-- ── 4. RPCs: name availability + create_space with a clear error ───────────
create or replace function family_name_taken(p_name text)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from family_space
    where lower(btrim(name)) = lower(btrim(p_name))
  );
$$;

grant execute on function family_name_taken(text) to authenticated;

create or replace function create_space(p_name text, p_household text default 'couple_kids')
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_space uuid;
  v_user uuid := auth.uid();
  v_code text;
begin
  if v_user is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if btrim(p_name) = '' then
    raise exception 'FAMILY_NAME_REQUIRED';
  end if;

  if family_name_taken(p_name) then
    raise exception 'FAMILY_NAME_TAKEN';
  end if;

  insert into user_profile (id, name, avatar_url)
  values (v_user, coalesce(
    nullif(split_part(coalesce((select email from auth.users where id = v_user), ''),'@',1), ''),
    'Member'),
    (select avatar_url from user_profile where id = v_user))
  on conflict (id) do update
    set name = coalesce(user_profile.name, excluded.name);

  v_code := 'MHRI-' || upper(substr(md5(random()::text), 1, 4));

  insert into family_space (name, household_type)
  values (btrim(p_name), p_household)
  returning id into v_space;

  insert into membership (space_id, user_id, role, sharing_level, invite_status, invite_code, joined_at)
  values (v_space, v_user, 'owner', 'full', 'active', v_code, now());

  return jsonb_build_object('id', v_space, 'invite_code', v_code);
end;
$$;
