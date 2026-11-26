-- 081: Production hardening, FK index coverage, Vault-backed push URLs,
-- scheduled maintenance, and household-synced currency/FX settings.
--
-- 1. Storage hardening: enforce a 5 MB file size limit and image MIME allowlist
--    on the public `avatars` bucket (matching `chat-media` discipline).
-- 2. Foreign key index coverage: index all 65 unindexed foreign keys in `public`
--    so account deletion (`delete_own_account`), space cascades, account/category
--    lookups, and envelope split joins never degrade into sequential scans.
-- 3. Environment-safe push webhooks: read `mhuri_supabase_url` from Supabase
--    Vault instead of hardcoding the production project ref in trigger SQL.
-- 4. Operational TTL reaper (`public.run_mhuri_maintenance`) + optional daily
--    `pg_cron` registration when `pg_cron` is available.
-- 5. Household currency & FX rate sync (`public.set_family_currency_settings`)
--    plus initial `rate_snapshot` seed so every device in a family sees the
--    same primary/secondary currency and custom exchange rate.

-- ── 1. Harden `avatars` Storage bucket ──────────────────────────────────────
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = true,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

do $$
begin
  if not exists (
    select 1
      from storage.buckets
     where id = 'avatars'
       and public = true
       and file_size_limit = 5242880
       and allowed_mime_types @> array['image/jpeg', 'image/png', 'image/webp']::text[]
  ) then
    raise exception '081 SELF-TEST FAILED: avatars bucket size/MIME limits were not applied';
  end if;
end;
$$;

-- ── 2. Cover all 65 unindexed foreign keys in `public` ──────────────────────
create index if not exists account_owner_member_id_idx
  on public.account (owner_member_id);
create index if not exists activity_log_actor_id_idx
  on public.activity_log (actor_id);
create index if not exists billing_purchase_verification_space_id_idx
  on public.billing_purchase_verification (space_id);
create index if not exists budget_cycle_plan_created_by_idx
  on public.budget_cycle_plan (created_by);
create index if not exists category_space_id_idx
  on public.category (space_id);
create index if not exists chore_archived_by_idx
  on public.chore (archived_by);
create index if not exists chore_assignee_member_id_idx
  on public.chore (assignee_member_id);
create index if not exists chore_log_claimed_by_idx
  on public.chore_log (claimed_by);
create index if not exists chore_log_confirmed_by_idx
  on public.chore_log (confirmed_by);
create index if not exists commitment_payment_created_by_idx
  on public.commitment_payment (created_by);
create index if not exists contribution_campaign_created_by_idx
  on public.contribution_campaign (created_by);
create index if not exists contribution_payment_member_id_idx
  on public.contribution_payment (member_id);
create index if not exists contribution_pledge_member_id_idx
  on public.contribution_pledge (member_id);
create index if not exists debt_repayment_member_id_idx
  on public.debt_repayment (member_id);
create index if not exists earning_member_id_idx
  on public.earning (member_id);
create index if not exists envelope_archived_by_idx
  on public.envelope (archived_by);
create index if not exists envelope_created_by_idx
  on public.envelope (created_by);
create index if not exists family_chat_message_sender_id_idx
  on public.family_chat_message (sender_id);
create index if not exists family_chat_pin_message_id_idx
  on public.family_chat_pin (message_id);
create index if not exists family_chat_pin_pinned_by_idx
  on public.family_chat_pin (pinned_by);
create index if not exists family_chat_poll_created_by_idx
  on public.family_chat_poll (created_by);
create index if not exists family_chat_poll_vote_poll_space_idx
  on public.family_chat_poll_vote (poll_id, space_id);
create index if not exists family_chat_poll_vote_user_id_idx
  on public.family_chat_poll_vote (user_id);
create index if not exists family_debt_counterparty_member_id_idx
  on public.family_debt (counterparty_member_id);
create index if not exists family_debt_created_by_idx
  on public.family_debt (created_by);
create index if not exists family_invite_accepted_by_idx
  on public.family_invite (accepted_by);
create index if not exists family_invite_created_by_idx
  on public.family_invite (created_by);
create index if not exists family_plus_space_grant_created_by_idx
  on public.family_plus_space_grant (created_by);
create index if not exists family_plus_space_grant_source_space_id_idx
  on public.family_plus_space_grant (source_space_id);
create index if not exists family_reward_redeemed_by_member_id_idx
  on public.family_reward (redeemed_by_member_id);
create index if not exists family_task_approved_by_member_id_idx
  on public.family_task (approved_by_member_id);
create index if not exists family_task_assignee_member_id_idx
  on public.family_task (assignee_member_id);
create index if not exists family_task_completed_by_member_id_idx
  on public.family_task (completed_by_member_id);
create index if not exists family_task_created_by_idx
  on public.family_task (created_by);
create index if not exists financial_commitment_created_by_idx
  on public.financial_commitment (created_by);
create index if not exists financial_commitment_envelope_id_idx
  on public.financial_commitment (envelope_id);
create index if not exists goal_archived_by_idx
  on public.goal (archived_by);
create index if not exists goal_created_by_idx
  on public.goal (created_by);
create index if not exists goal_owner_member_id_idx
  on public.goal (owner_member_id);
create index if not exists goal_tx_member_id_idx
  on public.goal_tx (member_id);
create index if not exists goal_tx_updated_by_idx
  on public.goal_tx (updated_by);
create index if not exists kid_request_decided_by_idx
  on public.kid_request (decided_by);
create index if not exists kid_request_envelope_id_idx
  on public.kid_request (envelope_id);
create index if not exists kid_request_requester_id_idx
  on public.kid_request (requester_id);
create index if not exists list_item_added_by_idx
  on public.list_item (added_by);
create index if not exists list_item_assigned_to_idx
  on public.list_item (assigned_to);
create index if not exists list_item_purchased_by_idx
  on public.list_item (purchased_by);
create index if not exists list_item_settled_tx_id_idx
  on public.list_item (settled_tx_id);
create index if not exists mukando_event_member_id_idx
  on public.mukando_event (member_id);
create index if not exists mukando_event_mukando_id_idx
  on public.mukando_event (mukando_id);
create index if not exists mukando_member_user_id_idx
  on public.mukando_member (user_id);
create index if not exists mukando_payment_member_id_idx
  on public.mukando_payment (member_id);
create index if not exists mukando_payment_recorded_by_idx
  on public.mukando_payment (recorded_by);
create index if not exists push_device_user_id_idx
  on public.push_device (user_id);
create index if not exists recurring_rule_archived_by_idx
  on public.recurring_rule (archived_by);
create index if not exists recurring_rule_created_by_idx
  on public.recurring_rule (created_by);
create index if not exists recurring_rule_envelope_id_idx
  on public.recurring_rule (envelope_id);
create index if not exists recurring_rule_member_id_idx
  on public.recurring_rule (member_id);
create index if not exists shopping_list_linked_envelope_id_idx
  on public.shopping_list (linked_envelope_id);
create index if not exists shopping_list_template_of_idx
  on public.shopping_list (template_of);
create index if not exists transaction_account_id_idx
  on public.transaction (account_id);
create index if not exists transaction_category_id_idx
  on public.transaction (category_id);
create index if not exists transaction_created_by_idx
  on public.transaction (created_by);
create index if not exists transaction_updated_by_idx
  on public.transaction (updated_by);
create index if not exists transaction_split_envelope_id_idx
  on public.transaction_split (envelope_id);

-- ── 3. Vault-backed push webhook dispatchers (no hardcoded prod URL) ────────
create or replace function public.dispatch_activity_push()
returns trigger
language plpgsql
security definer
set search_path = public, vault, net
as $$
declare
  webhook_secret text;
  webhook_base_url text;
begin
  select decrypted_secret into webhook_secret
    from vault.decrypted_secrets
   where name = 'mhuri_push_webhook_secret'
   order by created_at desc
   limit 1;

  select rtrim(btrim(decrypted_secret), '/') into webhook_base_url
    from vault.decrypted_secrets
   where name = 'mhuri_supabase_url'
   order by created_at desc
   limit 1;

  if webhook_secret is null or webhook_secret = '' then
    raise warning 'Push webhook secret is not configured';
    return new;
  end if;

  if webhook_base_url is null or webhook_base_url !~ '^https://' then
    raise warning 'Push webhook base URL (mhuri_supabase_url) is not configured';
    return new;
  end if;

  perform net.http_post(
    url := webhook_base_url || '/functions/v1/send-family-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', webhook_secret
    ),
    body := jsonb_build_object(
      'type', 'INSERT',
      'schema', 'public',
      'table', 'activity_log',
      'record', to_jsonb(new)
    ),
    timeout_milliseconds := 5000
  );
  return new;
exception when others then
  -- A notification provider outage must never roll back family finance data.
  raise warning 'Could not enqueue family push: %', sqlerrm;
  return new;
end;
$$;

revoke all on function public.dispatch_activity_push()
  from public, anon, authenticated;

create or replace function public.dispatch_family_chat_push()
returns trigger
language plpgsql
security definer
set search_path = public, vault, net
as $$
declare
  webhook_secret text;
  webhook_base_url text;
begin
  select decrypted_secret into webhook_secret
    from vault.decrypted_secrets
   where name = 'mhuri_push_webhook_secret'
   order by created_at desc
   limit 1;

  select rtrim(btrim(decrypted_secret), '/') into webhook_base_url
    from vault.decrypted_secrets
   where name = 'mhuri_supabase_url'
   order by created_at desc
   limit 1;

  if webhook_secret is null or webhook_secret = '' then
    raise warning 'Push webhook secret is not configured';
    return new;
  end if;

  if webhook_base_url is null or webhook_base_url !~ '^https://' then
    raise warning 'Push webhook base URL (mhuri_supabase_url) is not configured';
    return new;
  end if;

  perform net.http_post(
    url := webhook_base_url || '/functions/v1/send-family-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', webhook_secret
    ),
    body := jsonb_build_object(
      'type', 'INSERT',
      'schema', 'public',
      'table', 'family_chat_message',
      'record', to_jsonb(new)
    ),
    timeout_milliseconds := 5000
  );
  return new;
exception when others then
  raise warning 'Could not enqueue family chat push: %', sqlerrm;
  return new;
end;
$$;

revoke all on function public.dispatch_family_chat_push()
  from public, anon, authenticated;

-- ── 4. Scheduled operational TTL reaper + optional pg_cron schedule ─────────
create or replace function public.run_mhuri_maintenance()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sync_ops int := 0;
  v_ai_res int := 0;
  v_invites int := 0;
begin
  -- Idempotency op ledger: safe to prune once client retry window (60d) passes.
  delete from public.sync_applied_op
   where applied_at < now() - interval '60 days';
  get diagnostics v_sync_ops = row_count;

  -- AI usage reservations: prune completed/released rows > 30d and orphaned
  -- in-flight reservations > 2d (daily quota counts live in family_ai_usage).
  delete from public.ai_usage_reservation
   where (status <> 'reserved' and created_at < now() - interval '30 days')
      or (status = 'reserved' and created_at < now() - interval '2 days');
  get diagnostics v_ai_res = row_count;

  -- Unaccepted expired/revoked invites > 30d (accepted invites stay for audit).
  delete from public.family_invite
   where accepted_at is null
     and coalesce(revoked_at, expires_at) < now() - interval '30 days';
  get diagnostics v_invites = row_count;

  return jsonb_build_object(
    'sync_ops_pruned', v_sync_ops,
    'ai_reservations_pruned', v_ai_res,
    'expired_invites_pruned', v_invites,
    'ran_at', now()
  );
end;
$$;

revoke all on function public.run_mhuri_maintenance()
  from public, anon, authenticated;
grant execute on function public.run_mhuri_maintenance() to service_role;

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    if exists (select 1 from cron.job where jobname = 'mhuri-daily-maintenance') then
      perform cron.unschedule('mhuri-daily-maintenance');
    end if;
    perform cron.schedule(
      'mhuri-daily-maintenance',
      '17 2 * * *',
      'select public.run_mhuri_maintenance();'
    );
  end if;
exception when others then
  raise notice 'pg_cron unavailable in this environment (%): skipping schedule registration', sqlerrm;
end;
$$;

-- ── 5. Household currency & FX rate sync RPC + benchmark snapshot seed ──────
insert into public.rate_snapshot (day, source, usd_zwg)
select current_date, 'rbz', 26.54
 where not exists (select 1 from public.rate_snapshot);

create or replace function public.set_family_currency_settings(
  p_space_id uuid,
  p_primary text,
  p_secondary text default null,
  p_custom_rate numeric default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_primary text := upper(btrim(coalesce(p_primary, '')));
  v_secondary text := nullif(upper(btrim(coalesce(p_secondary, ''))), '');
  v_rate numeric := null;
  v_next_settings jsonb;
begin
  if v_secondary = 'NONE' then
    v_secondary := null;
  end if;

  if p_space_id is null or not public.is_family_admin(p_space_id) then
    raise exception 'ADMIN_REQUIRED';
  end if;

  if v_primary not in ('USD','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR','ZWG')
     or (v_secondary is not null and (
       v_secondary not in ('USD','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR','ZWG')
       or v_secondary = v_primary
     )) then
    raise exception 'UNSUPPORTED_CURRENCY';
  end if;

  if v_secondary is not null and p_custom_rate is not null then
    if p_custom_rate <= 0 or p_custom_rate > 10000000 then
      raise exception 'INVALID_EXCHANGE_RATE';
    end if;
    v_rate := round(p_custom_rate, 4);
  end if;

  perform pg_advisory_xact_lock(hashtext(p_space_id::text));

  select
    (coalesce(fs.settings, '{}'::jsonb)
      - 'secondary_currency'
      - 'custom_rate'
      - 'rate_mode')
    || jsonb_build_object('primary_currency', v_primary)
    || case
         when v_secondary is null then '{}'::jsonb
         when v_rate is not null then jsonb_build_object(
           'secondary_currency', v_secondary,
           'custom_rate', v_rate,
           'rate_mode', 'custom'
         )
         else jsonb_build_object(
           'secondary_currency', v_secondary,
           'rate_mode', 'market'
         )
       end
    into v_next_settings
    from public.family_space fs
   where fs.id = p_space_id
     for update;

  if v_next_settings is null then
    raise exception 'SPACE_NOT_FOUND';
  end if;

  update public.family_space
     set base_currency = v_primary,
         settings = v_next_settings,
         updated_at = now()
   where id = p_space_id;

  if auth.uid() is not null then
    insert into public.activity_log (
      space_id, actor_id, action, entity, entity_id, detail, hash
    ) values (
      p_space_id,
      auth.uid(),
      'family.currency_settings',
      'family_space',
      p_space_id,
      jsonb_strip_nulls(jsonb_build_object(
        'primary_currency', v_primary,
        'secondary_currency', v_secondary,
        'custom_rate', v_rate,
        'rate_mode', case
          when v_secondary is null then 'single'
          when v_rate is not null then 'custom'
          else 'market'
        end
      )),
      md5(p_space_id::text || ':currency:' || clock_timestamp())
    );
  end if;

  return jsonb_build_object(
    'space_id', p_space_id,
    'primary_currency', v_primary,
    'secondary_currency', v_secondary,
    'custom_rate', v_rate,
    'rate_mode', case
      when v_secondary is null then 'single'
      when v_rate is not null then 'custom'
      else 'market'
    end
  );
end;
$$;

revoke all on function public.set_family_currency_settings(uuid, text, text, numeric)
  from public, anon;
grant execute on function public.set_family_currency_settings(uuid, text, text, numeric)
  to authenticated;
