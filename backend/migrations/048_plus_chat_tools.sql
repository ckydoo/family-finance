-- 048: additive Plus polls and pinned messages. Existing chat stays free.

create table if not exists public.family_chat_poll (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.family_space(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  question text not null check (char_length(btrim(question)) between 1 and 240),
  options jsonb not null check (
    case when jsonb_typeof(options) = 'array'
      then jsonb_array_length(options) between 2 and 6 else false end
  ),
  allow_multiple boolean not null default false,
  closes_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (id, space_id)
);

create table if not exists public.family_chat_poll_vote (
  poll_id uuid not null,
  space_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  option_indexes integer[] not null check (cardinality(option_indexes) between 1 and 6),
  updated_at timestamptz not null default now(),
  primary key (poll_id, user_id),
  foreign key (poll_id, space_id)
    references public.family_chat_poll(id, space_id) on delete cascade
);

create table if not exists public.family_chat_pin (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.family_space(id) on delete cascade,
  message_id uuid not null references public.family_chat_message(id) on delete cascade,
  pinned_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (space_id, message_id)
);

create index if not exists family_chat_poll_space_created_idx
  on public.family_chat_poll(space_id, created_at desc);
create index if not exists family_chat_pin_space_created_idx
  on public.family_chat_pin(space_id, created_at desc);

alter table public.family_chat_poll enable row level security;
alter table public.family_chat_poll_vote enable row level security;
alter table public.family_chat_pin enable row level security;

drop policy if exists family_chat_poll_read on public.family_chat_poll;
create policy family_chat_poll_read on public.family_chat_poll for select to authenticated
  using (public.space_role(space_id) is not null);
drop policy if exists family_chat_poll_vote_read on public.family_chat_poll_vote;
create policy family_chat_poll_vote_read on public.family_chat_poll_vote for select to authenticated
  using (public.space_role(space_id) is not null);
drop policy if exists family_chat_pin_read on public.family_chat_pin;
create policy family_chat_pin_read on public.family_chat_pin for select to authenticated
  using (public.space_role(space_id) is not null);

revoke all on public.family_chat_poll from anon, authenticated;
revoke all on public.family_chat_poll_vote from anon, authenticated;
revoke all on public.family_chat_pin from anon, authenticated;
grant select on public.family_chat_poll, public.family_chat_poll_vote,
  public.family_chat_pin to authenticated;

create or replace function public.create_family_chat_poll(
  p_space_id uuid,
  p_question text,
  p_options jsonb,
  p_allow_multiple boolean default false,
  p_closes_at timestamptz default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare new_id uuid;
begin
  if auth.uid() is null or public.space_role(p_space_id) is null then
    raise exception 'FAMILY_ACCESS_DENIED';
  end if;
  if not exists (
    select 1 from family_entitlement e
     where e.space_id = p_space_id
       and e.status in ('active', 'gracePeriod', 'canceledActive')
       and (e.expires_at is null or e.expires_at > now())
       and e.features ? 'family_polls_pins'
  ) then raise exception 'PLUS_FEATURE_REQUIRED'; end if;
  if char_length(btrim(coalesce(p_question, ''))) not between 1 and 240
     or p_options is null or jsonb_typeof(p_options) <> 'array' then
    raise exception 'INVALID_POLL';
  end if;
  if jsonb_array_length(p_options) not between 2 and 6 then
    raise exception 'INVALID_POLL';
  end if;
  if exists (select 1 from jsonb_array_elements_text(p_options) x
              where char_length(btrim(x)) not between 1 and 80) then
    raise exception 'INVALID_POLL_OPTION';
  end if;
  if p_closes_at is not null and
     (p_closes_at <= now() or p_closes_at > now() + interval '90 days') then
    raise exception 'INVALID_POLL_CLOSE_DATE';
  end if;
  insert into family_chat_poll(space_id, created_by, question, options,
                               allow_multiple, closes_at)
  values (p_space_id, auth.uid(), btrim(p_question), p_options,
          coalesce(p_allow_multiple, false), p_closes_at)
  returning id into new_id;
  return new_id;
end; $$;

create or replace function public.vote_family_chat_poll(
  p_poll_id uuid,
  p_option_indexes integer[]
) returns void
language plpgsql security definer set search_path = public as $$
declare poll_row family_chat_poll%rowtype;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into poll_row from family_chat_poll where id = p_poll_id;
  if not found or public.space_role(poll_row.space_id) is null then
    raise exception 'FAMILY_ACCESS_DENIED';
  end if;
  if poll_row.closed_at is not null or
     (poll_row.closes_at is not null and poll_row.closes_at <= now()) then
    raise exception 'POLL_CLOSED';
  end if;
  if p_option_indexes is null or cardinality(p_option_indexes) < 1
     or cardinality(p_option_indexes) > 6
     or (not poll_row.allow_multiple and cardinality(p_option_indexes) <> 1)
     or array_position(p_option_indexes, null) is not null
     or exists (select 1 from unnest(p_option_indexes) as choices(option_index)
                 where option_index < 0 or option_index >= jsonb_array_length(poll_row.options))
     or cardinality(p_option_indexes) <>
        (select count(distinct option_index)
           from unnest(p_option_indexes) as choices(option_index)) then
    raise exception 'INVALID_POLL_VOTE';
  end if;
  insert into family_chat_poll_vote(poll_id, space_id, user_id, option_indexes)
  values (p_poll_id, poll_row.space_id, auth.uid(), p_option_indexes)
  on conflict (poll_id, user_id) do nothing;
end; $$;

create or replace function public.close_family_chat_poll(p_poll_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare poll_row family_chat_poll%rowtype;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into poll_row from family_chat_poll where id = p_poll_id for update;
  if not found or public.space_role(poll_row.space_id) is null then
    raise exception 'FAMILY_ACCESS_DENIED';
  end if;
  if poll_row.created_by <> auth.uid() and not public.is_adult(poll_row.space_id) then
    raise exception 'NOT_AUTHORIZED';
  end if;
  update family_chat_poll set closed_at = coalesce(closed_at, now()) where id = p_poll_id;
end; $$;

create or replace function public.set_family_chat_pin(
  p_space_id uuid,
  p_message_id uuid,
  p_pinned boolean
) returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or public.space_role(p_space_id) is null then
    raise exception 'FAMILY_ACCESS_DENIED';
  end if;
  if not p_pinned then
    delete from family_chat_pin where space_id = p_space_id and message_id = p_message_id;
    return;
  end if;
  if not exists (
    select 1 from family_entitlement e
     where e.space_id = p_space_id
       and e.status in ('active', 'gracePeriod', 'canceledActive')
       and (e.expires_at is null or e.expires_at > now())
       and e.features ? 'family_polls_pins'
  ) then raise exception 'PLUS_FEATURE_REQUIRED'; end if;
  if not exists (select 1 from family_chat_message
                  where id = p_message_id and space_id = p_space_id and not deleted) then
    raise exception 'MESSAGE_NOT_FOUND';
  end if;
  if not exists (select 1 from family_chat_pin
                  where space_id = p_space_id and message_id = p_message_id)
     and (select count(*) from family_chat_pin where space_id = p_space_id) >= 20 then
    raise exception 'PIN_LIMIT_REACHED';
  end if;
  insert into family_chat_pin(space_id, message_id, pinned_by)
  values (p_space_id, p_message_id, auth.uid())
  on conflict (space_id, message_id) do nothing;
end; $$;

create or replace function public.get_family_chat_polls(p_space_id uuid)
returns jsonb language plpgsql security definer stable set search_path = public as $$
declare result jsonb;
begin
  if auth.uid() is null or public.space_role(p_space_id) is null then
    raise exception 'FAMILY_ACCESS_DENIED';
  end if;
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', p.id,
      'question', p.question,
      'options', p.options,
      'allow_multiple', p.allow_multiple,
      'closes_at', p.closes_at,
      'closed_at', p.closed_at,
      'created_at', p.created_at,
      'created_by', p.created_by,
      'my_votes', coalesce((select to_jsonb(v.option_indexes)
        from family_chat_poll_vote v where v.poll_id = p.id and v.user_id = auth.uid()), '[]'::jsonb),
      'counts', coalesce((select jsonb_object_agg(t.option_index, t.total)
        from (select choice.option_index, count(*) as total
          from family_chat_poll_vote v
          cross join lateral unnest(v.option_indexes) as choice(option_index)
          where v.poll_id = p.id group by choice.option_index) t), '{}'::jsonb)
    ) order by p.created_at desc
  ), '[]'::jsonb) into result
  from family_chat_poll p where p.space_id = p_space_id;
  return result;
end; $$;

create or replace function public.search_family_chat_messages(
  p_space_id uuid,
  p_text text default null,
  p_sender_id uuid default null,
  p_after timestamptz default null,
  p_before timestamptz default null,
  p_kind text default 'any',
  p_limit integer default 250,
  p_offset integer default 0
) returns setof public.family_chat_message
language plpgsql security definer stable set search_path = public as $$
begin
  if auth.uid() is null or public.space_role(p_space_id) is null then
    raise exception 'FAMILY_ACCESS_DENIED';
  end if;
  if not exists (
    select 1 from family_entitlement e
     where e.space_id = p_space_id
       and e.status in ('active', 'gracePeriod', 'canceledActive')
       and (e.expires_at is null or e.expires_at > now())
       and e.features ? 'advanced_chat_search'
  ) then raise exception 'PLUS_FEATURE_REQUIRED'; end if;
  if p_kind not in ('any', 'text', 'media', 'sticker', 'system') then
    raise exception 'INVALID_SEARCH_KIND';
  end if;
  return query
    select m.* from family_chat_message m
     where m.space_id = p_space_id
       and not m.deleted
       and (p_text is null or btrim(p_text) = '' or
            m.text ilike '%' || replace(replace(p_text, '%', E'\\%'), '_', E'\\_') || '%')
       and (p_sender_id is null or m.sender_id = p_sender_id)
       and (p_after is null or m.created_at >= p_after)
       and (p_before is null or m.created_at < p_before)
       and case p_kind
         when 'text' then m.media_url is null and m.sticker is null and not m.is_system
         when 'media' then m.media_url is not null
         when 'sticker' then m.sticker is not null
         when 'system' then m.is_system
         else true
       end
     order by m.created_at desc
     limit greatest(1, least(coalesce(p_limit, 250), 500))
     offset greatest(coalesce(p_offset, 0), 0);
end; $$;

revoke all on function public.search_family_chat_messages(uuid, text, uuid, timestamptz, timestamptz, text, integer, integer) from public;
grant execute on function public.search_family_chat_messages(uuid, text, uuid, timestamptz, timestamptz, text, integer, integer) to authenticated;

revoke all on function public.create_family_chat_poll(uuid, text, jsonb, boolean, timestamptz) from public;
revoke all on function public.vote_family_chat_poll(uuid, integer[]) from public;
revoke all on function public.close_family_chat_poll(uuid) from public;
revoke all on function public.set_family_chat_pin(uuid, uuid, boolean) from public;
revoke all on function public.get_family_chat_polls(uuid) from public;
grant execute on function public.create_family_chat_poll(uuid, text, jsonb, boolean, timestamptz) to authenticated;
grant execute on function public.vote_family_chat_poll(uuid, integer[]) to authenticated;
grant execute on function public.close_family_chat_poll(uuid) to authenticated;
grant execute on function public.set_family_chat_pin(uuid, uuid, boolean) to authenticated;
grant execute on function public.get_family_chat_polls(uuid) to authenticated;

create or replace function public.remove_deleted_chat_pins()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.deleted and not old.deleted then
    delete from family_chat_pin where message_id = new.id;
  end if;
  return new;
end; $$;

drop trigger if exists trg_remove_deleted_chat_pins on public.family_chat_message;
create trigger trg_remove_deleted_chat_pins
after update of deleted on public.family_chat_message
for each row execute function public.remove_deleted_chat_pins();
revoke all on function public.remove_deleted_chat_pins() from public;
