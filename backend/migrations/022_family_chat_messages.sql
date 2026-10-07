-- 022: thread-safe family chat messages scoped to a single family.
-- Safe to re-run: migration is additive and idempotent.

create table if not exists public.family_chat_message (
  id uuid primary key,
  space_id uuid not null references public.family_space(id) on delete cascade,
  sender_id uuid not null references public.user_profile(id) on delete cascade,
  text text not null,
  status text not null default 'sent' check (status in ('sent','delivered','read')),
  reference_type text check (reference_type in ('task','shopping_list','expense','goal','contribution')),
  reference_id text,
  reference_title text,
  reference_meta text,
  is_system boolean not null default false,
  sender_name text,
  sender_avatar text,
  deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.family_chat_message enable row level security;

create index if not exists family_chat_message_space_created_idx
  on public.family_chat_message(space_id, created_at desc);

create or replace function public.guard_family_chat_message() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.sender_id := coalesce(new.sender_id, auth.uid());
  end if;
  new.updated_at := now();
  return new;
end; $$;

drop trigger if exists trg_family_chat_message_guard on public.family_chat_message;
create trigger trg_family_chat_message_guard
before insert or update on public.family_chat_message
for each row execute function public.guard_family_chat_message();

drop policy if exists family_chat_message_read on public.family_chat_message;
create policy family_chat_message_read on public.family_chat_message for select
  using (public.space_role(space_id) is not null);

drop policy if exists family_chat_message_insert on public.family_chat_message;
create policy family_chat_message_insert on public.family_chat_message for insert
  with check (
    public.space_role(space_id) is not null and
    sender_id = auth.uid()
  );

drop policy if exists family_chat_message_update on public.family_chat_message;
create policy family_chat_message_update on public.family_chat_message for update
  using (
    public.space_role(space_id) is not null and (
      sender_id = auth.uid() or public.is_adult(space_id)
    )
  )
  with check (
    public.space_role(space_id) is not null and (
      sender_id = auth.uid() or public.is_adult(space_id)
    )
  );

grant select, insert, update on public.family_chat_message to authenticated;
