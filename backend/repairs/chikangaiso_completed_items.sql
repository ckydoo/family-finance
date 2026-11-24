-- Incident repair: user confirmed Done purchases were already deducted.
-- Purchaser attribution follows the latest recorded completion actor.
begin;
create or replace function public.guard_chikangaiso_completed_items()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if old.list_id = '0463bb91-d966-413f-b7c5-b7327aca56dd'::uuid
     and old.state = 'done'
     and (new.state <> 'done' or (old.checked_out and not new.checked_out)) then
    raise exception using errcode = '40001',
      message = 'COMPLETED_PURCHASE_PROTECTED',
      hint = 'Refresh the list. To buy again, add a new item; keep this purchase in Done.';
  end if;
  return new;
end;
$$;
drop trigger if exists trg_chikangaiso_completed_items on public.list_item;
create trigger trg_chikangaiso_completed_items before update on public.list_item
for each row execute function public.guard_chikangaiso_completed_items();

do $$
declare n integer;
begin
  update public.list_item
     set checked_out = true,
         purchased_by = '408f70f9-882a-4a9a-a28d-2aa785ef38f1'
   where list_id = '0463bb91-d966-413f-b7c5-b7327aca56dd'
     and id in ('23e4c780-be2d-4979-9c53-cb3552cd94e9',
                '8770610b-23a2-4843-9e8c-e80a48baa5b7')
     and state = 'done' and not checked_out and purchased_by is null;
  get diagnostics n = row_count;
  if n <> 2 then
    raise exception 'Expected two unchanged items; matched %. Repair rolled back.', n;
  end if;
end;
$$;
commit;
