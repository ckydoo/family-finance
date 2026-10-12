-- A physical installation keeps the same FCM token when the signed-in Mhuri
-- account changes. A direct PostgREST upsert cannot transfer that token: the
-- UPDATE branch sees the previous owner and is correctly rejected by RLS.
-- Keep RLS strict and expose one narrow operation that binds a presented token
-- to auth.uid(). No caller can choose the destination user.
create or replace function public.register_push_device(
  p_token text,
  p_platform text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if p_token is null or length(trim(p_token)) < 20 or length(p_token) > 4096 then
    raise exception 'INVALID_PUSH_TOKEN';
  end if;
  if p_platform not in ('android', 'ios') then
    raise exception 'INVALID_PLATFORM';
  end if;

  insert into public.push_device (token, user_id, platform, updated_at)
  values (p_token, v_user, p_platform, now())
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = excluded.updated_at;
end;
$$;

revoke all on function public.register_push_device(text, text) from public, anon;
grant execute on function public.register_push_device(text, text) to authenticated;

