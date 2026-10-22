-- 043: Make the budget-cycle start a family-wide setting.
-- Older clients could update only their local SQLite value, while setup kept
-- a duplicate JSON value beside the typed family_space column.

create or replace function public.set_family_month_start(
  p_space_id uuid,
  p_day integer
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_day not between 1 and 31 then
    raise exception 'INVALID_MONTH_START';
  end if;
  if not public.is_family_admin(p_space_id) then
    raise exception 'ADMIN_REQUIRED';
  end if;

  update public.family_space
     set month_start_day = p_day,
         settings = jsonb_set(
           coalesce(settings, '{}'::jsonb),
           '{month_start_day}',
           to_jsonb(p_day),
           true
         ),
         updated_at = now()
   where id = p_space_id;
end;
$$;

revoke all on function public.set_family_month_start(uuid, integer)
  from public, anon;
grant execute on function public.set_family_month_start(uuid, integer)
  to authenticated;
