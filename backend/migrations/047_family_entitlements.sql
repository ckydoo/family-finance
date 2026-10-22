-- 047: family-wide subscription entitlement and verified store receipts.
-- Store state is written only by trusted service-role functions.

create table if not exists public.family_entitlement (
  space_id uuid primary key references public.family_space(id) on delete cascade,
  status text not null default 'free'
    check (status in ('free', 'active', 'gracePeriod', 'canceledActive',
                      'billingIssue', 'expired', 'revoked')),
  features jsonb not null default '[]'::jsonb
    check (jsonb_typeof(features) = 'array'),
  product_id text,
  store text check (store is null or store = 'google_play'),
  expires_at timestamptz,
  verified_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.billing_purchase_verification (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.family_space(id) on delete cascade,
  store text not null check (store = 'google_play'),
  product_id text not null,
  purchase_token_hash text not null unique,
  state text not null check (state in ('pending', 'verified', 'rejected', 'revoked')),
  verified_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.family_entitlement enable row level security;
alter table public.billing_purchase_verification enable row level security;

drop policy if exists "family members read entitlement" on public.family_entitlement;
create policy "family members read entitlement"
  on public.family_entitlement for select to authenticated
  using (exists (
    select 1 from public.membership m
     where m.space_id = family_entitlement.space_id
       and m.user_id = auth.uid()
       and m.invite_status = 'active'
  ));

revoke all on public.family_entitlement from anon, authenticated;
grant select on public.family_entitlement to authenticated;
revoke all on public.billing_purchase_verification from anon, authenticated;
