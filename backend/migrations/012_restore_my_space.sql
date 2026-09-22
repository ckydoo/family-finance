-- 012: REINSTALL RECONCILIATION.
--
-- A reinstall (or a second phone) wipes local kv: no space_id, so the app
-- shows family setup and the member would have to re-enter the code — or
-- worse, create a duplicate family. restore_my_space() answers "am I still
-- in a family?" using the auth token alone: the active membership (if any)
-- with the family's name and the static code. The engine adopts it and
-- full-syncs; nothing is re-created, nothing duplicates.

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
  where m.user_id = auth.uid()
    and m.invite_status = 'active'
  limit 1;
$$;

revoke all on function public.restore_my_space() from public, anon;
grant execute on function public.restore_my_space() to authenticated;

-- ── self-test ───────────────────────────────────────────────────────────────
do $$
declare n int;
begin
  select count(*) into n from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public' and p.proname = 'restore_my_space';
  if n <> 1 then raise exception '012 SELF-TEST FAILED: restore_my_space missing'; end if;
end $$;
