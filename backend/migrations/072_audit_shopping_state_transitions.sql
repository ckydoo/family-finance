-- 072: retain both sides of each shopping-item state transition so a
-- background sync can be distinguished from a deliberate state change.

create or replace function public.audit_shopping_item() returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_space uuid;
  v_actor uuid;
  v_detail jsonb;
begin
  if tg_op = 'UPDATE'
     and (to_jsonb(new) - 'updated_at') = (to_jsonb(old) - 'updated_at') then
    return new;
  end if;

  select space_id into v_space
    from public.shopping_list
   where id = new.list_id;
  v_actor := coalesce(auth.uid(), new.added_by);
  if v_space is null or v_actor is null then return new; end if;

  v_detail := jsonb_build_object(
    'name', new.name,
    'qty', new.qty,
    'old_state', case when tg_op = 'UPDATE' then old.state end,
    'new_state', new.state,
    'old_checked_out', case when tg_op = 'UPDATE' then old.checked_out end,
    'new_checked_out', new.checked_out
  );
  insert into public.activity_log(
    space_id, actor_id, action, entity, entity_id, detail, hash)
  values (
    v_space,
    v_actor,
    case when tg_op = 'INSERT' then 'shopping.item_add'
         when new.state = 'done' and old.state <> 'done' then 'shopping.item_done'
         else 'shopping.item_update' end,
    'list_item', new.id, v_detail,
    md5(new.id::text || ':shopping:' || clock_timestamp())
  );
  return new;
end;
$$;

revoke all on function public.audit_shopping_item()
  from public, anon, authenticated;
