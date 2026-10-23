-- 050: Plus chat collaboration RPC hardening (polls, pins, search) and
-- RLS/schema security hardening (membership-scoped profile_read, private
-- account/transaction visibility, and envelope unique index).
-- Additive and forward-only; no production execution is performed automatically.

-- 1. Harden create_family_chat_poll: enforce normalized unique options.
create or replace function public.create_family_chat_poll(
  p_space_id uuid,
  p_question text,
  p_options jsonb,
  p_allow_multiple boolean default false,
  p_closes_at timestamptz default null
) returns uuid
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  new_id uuid;
  caller_role text;
begin
  caller_role := public.space_role(p_space_id);
  if auth.uid() is null or caller_role is null or caller_role = 'viewer' then
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
  if (
    select count(*) <> count(distinct lower(btrim(x)))
      from jsonb_array_elements_text(p_options) x
  ) then
    raise exception 'DUPLICATE_POLL_OPTION';
  end if;
  if p_closes_at is not null and
     (p_closes_at <= now() or p_closes_at > now() + interval '90 days') then
    raise exception 'INVALID_POLL_CLOSE_DATE';
  end if;
  insert into family_chat_poll(space_id, created_by, question, options,
                               allow_multiple, closes_at)
  values (
    p_space_id,
    auth.uid(),
    btrim(p_question),
    (select jsonb_agg(btrim(x)) from jsonb_array_elements_text(p_options) x),
    coalesce(p_allow_multiple, false),
    p_closes_at
  )
  returning id into new_id;
  return new_id;
end; $$;

-- 2. Harden vote_family_chat_poll: allow updating votes while poll is open,
-- block viewers, and reject out-of-range or duplicate option indexes.
create or replace function public.vote_family_chat_poll(
  p_poll_id uuid,
  p_option_indexes integer[]
) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  poll_row family_chat_poll%rowtype;
  caller_role text;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into poll_row from family_chat_poll where id = p_poll_id for update;
  caller_role := public.space_role(poll_row.space_id);
  if not found or caller_role is null or caller_role = 'viewer' then
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
  insert into family_chat_poll_vote(poll_id, space_id, user_id, option_indexes, updated_at)
  values (p_poll_id, poll_row.space_id, auth.uid(), p_option_indexes, now())
  on conflict (poll_id, user_id) do update
    set option_indexes = excluded.option_indexes,
        updated_at = now();
end; $$;

-- 3. Harden close_family_chat_poll: allow poll creator or owner/co_parent/adult.
create or replace function public.close_family_chat_poll(p_poll_id uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare
  poll_row family_chat_poll%rowtype;
  caller_role text;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into poll_row from family_chat_poll where id = p_poll_id for update;
  caller_role := public.space_role(poll_row.space_id);
  if not found or caller_role is null then
    raise exception 'FAMILY_ACCESS_DENIED';
  end if;
  if poll_row.created_by <> auth.uid()
     and caller_role not in ('owner', 'co_parent', 'adult') then
    raise exception 'NOT_AUTHORIZED';
  end if;
  update family_chat_poll
     set closed_at = coalesce(closed_at, now())
   where id = p_poll_id;
end; $$;

-- 4. Harden set_family_chat_pin: enforce least-privilege unpin (owner, co_parent,
-- adult, message author, or the member who pinned the message).
create or replace function public.set_family_chat_pin(
  p_space_id uuid,
  p_message_id uuid,
  p_pinned boolean
) returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare
  caller_role text;
  pin_owner uuid;
  msg_sender uuid;
begin
  caller_role := public.space_role(p_space_id);
  if auth.uid() is null or caller_role is null or caller_role = 'viewer' then
    raise exception 'FAMILY_ACCESS_DENIED';
  end if;
  if not p_pinned then
    select pinned_by into pin_owner
      from family_chat_pin
     where space_id = p_space_id and message_id = p_message_id
       for update;
    if not found then return; end if;
    select sender_id into msg_sender
      from family_chat_message
     where id = p_message_id and space_id = p_space_id;
    if caller_role not in ('owner', 'co_parent', 'adult')
       and pin_owner is distinct from auth.uid()
       and msg_sender is distinct from auth.uid() then
      raise exception 'NOT_AUTHORIZED';
    end if;
    delete from family_chat_pin
     where space_id = p_space_id and message_id = p_message_id;
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

-- 5. Harden search_family_chat_messages: explicit ESCAPE '\' for wildcard safety.
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
language plpgsql security definer stable set search_path = public, pg_temp as $$
declare escaped_query text;
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
  escaped_query := replace(
    replace(replace(coalesce(btrim(p_text), ''), E'\\', E'\\\\'), '%', E'\\%'),
    '_',
    E'\\_'
  );
  return query
    select m.* from family_chat_message m
     where m.space_id = p_space_id
       and not m.deleted
       and (escaped_query = '' or m.text ilike '%' || escaped_query || '%' escape E'\\')
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

-- 6. RLS hardening: restrict user_profile read to self or shared active family membership.
drop policy if exists profile_read on public.user_profile;
create policy profile_read on public.user_profile
  for select to authenticated
  using (
    id = (select auth.uid())
    or exists (
      select 1
        from public.membership caller_m
        join public.membership target_m
          on caller_m.space_id = target_m.space_id
       where caller_m.user_id = (select auth.uid())
         and target_m.user_id = user_profile.id
         and caller_m.invite_status = 'active'
         and target_m.invite_status = 'active'
    )
  );

-- 7. RLS hardening: enforce personal account and private transaction visibility
-- via RESTRICTIVE policies so existing role-based policies remain intact.
drop policy if exists account_personal_privacy on public.account;
create policy account_personal_privacy on public.account
  as restrictive
  for select to authenticated
  using (
    coalesce(sharing, 'shared') <> 'personal'
    or owner_member_id = (select auth.uid())
  );

drop policy if exists tx_personal_account_privacy on public.transaction;
create policy tx_personal_account_privacy on public.transaction
  as restrictive
  for select to authenticated
  using (
    account_id is null
    or exists (
      select 1 from public.account a
       where a.id = transaction.account_id
         and a.space_id = transaction.space_id
         and (
           coalesce(a.sharing, 'shared') <> 'personal'
           or a.owner_member_id = (select auth.uid())
         )
    )
  );

-- 8. Schema reconciliation: archive duplicate active shared envelopes before
-- adding the partial unique index envelope_space_name_unique.
with ranked_envelopes as (
  select id,
         row_number() over (
           partition by space_id, lower(btrim(name))
           order by limit_minor desc, created_at asc, id asc
         ) as rn
    from public.envelope
   where is_archived = false
     and coalesce(sharing, 'shared') = 'shared'
)
update public.envelope e
   set is_archived = true
  from ranked_envelopes r
 where e.id = r.id
   and r.rn > 1;

create unique index if not exists envelope_space_name_unique
  on public.envelope (space_id, lower(btrim(name)))
  where is_archived = false and coalesce(sharing, 'shared') = 'shared';

