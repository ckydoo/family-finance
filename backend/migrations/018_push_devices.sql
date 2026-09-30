-- FCM installation tokens. Tokens are private credentials: users may manage
-- only their own, while the push Edge Function reads them with service_role.
create table if not exists public.push_device (
  token text primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  updated_at timestamptz not null default now()
);

alter table public.push_device enable row level security;

drop policy if exists push_device_insert_own on public.push_device;
create policy push_device_insert_own on public.push_device
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists push_device_update_own on public.push_device;
create policy push_device_update_own on public.push_device
  for update to authenticated using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists push_device_delete_own on public.push_device;
create policy push_device_delete_own on public.push_device
  for delete to authenticated using (user_id = auth.uid());

revoke all on public.push_device from anon;
grant insert, update, delete on public.push_device to authenticated;

-- A newly submitted child/teen request is an important server-visible event
-- for parents. Decision events are already audited by migration 011.
create or replace function public.audit_request_create()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into activity_log
    (space_id, actor_id, action, entity, entity_id, detail, hash)
  values (
    new.space_id, new.requester_id, 'request.create', 'kid_request', new.id,
    jsonb_build_object('requester_id', new.requester_id, 'kind', new.kind),
    md5(new.id::text || ':request.create:' || clock_timestamp())
  );
  return new;
end;
$$;

drop trigger if exists trg_audit_request_create on public.kid_request;
create trigger trg_audit_request_create
  after insert on public.kid_request
  for each row execute function public.audit_request_create();
