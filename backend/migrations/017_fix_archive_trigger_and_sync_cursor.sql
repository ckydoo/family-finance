-- 017: repair onboarding envelope updates and timestamp cursor transport.
--
-- A trigger function shared by envelope, goal and recurring_rule referenced
-- every table-specific OLD/NEW field in independent boolean expressions.
-- PostgreSQL resolves those record fields for the current trigger row, so an
-- envelope update could fail with: record "old" has no field "status".
-- Dispatch on the table first; only then access that table's fields.

create or replace function public.guard_financial_archive() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  if tg_table_name = 'envelope' then
    if coalesce(old.is_archived,false) = false
       and coalesce(new.is_archived,false) = true
       and not public.is_family_admin(new.space_id) then
      raise exception 'ADMIN_REQUIRED';
    end if;
  elsif tg_table_name = 'goal' then
    if old.status <> 'archived'
       and new.status = 'archived'
       and not public.is_family_admin(new.space_id) then
      raise exception 'ADMIN_REQUIRED';
    end if;
  elsif tg_table_name = 'recurring_rule' then
    if old.archived_at is null
       and new.archived_at is not null
       and not public.is_family_admin(new.space_id) then
      raise exception 'ADMIN_REQUIRED';
    end if;
  end if;

  return new;
end; $$;
