begin;

-- This test is intended for the backend integration harness after fixtures
-- establish a writable family/list. The trigger itself is assertion-tested
-- here without retaining any production data.
do $$
begin
  if not exists (
    select 1
      from pg_trigger
     where tgname = 'trg_guard_bulk_shopping_regression'
       and not tgisinternal
  ) then
    raise exception 'bulk shopping regression guard is missing';
  end if;
end;
$$;

rollback;
