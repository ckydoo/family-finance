-- Permanently delete the currently authenticated user.
-- SECURITY DEFINER is required because clients must never receive direct
-- delete permission on auth.users. All related public rows follow their
-- existing ON DELETE CASCADE / SET NULL constraints.
create or replace function public.delete_own_account()
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

  delete from auth.users where id = v_user;
end;
$$;

revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;
