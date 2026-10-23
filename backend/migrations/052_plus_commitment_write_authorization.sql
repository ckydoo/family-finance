-- 052: require a current, server-owned Plus entitlement for every premium
-- commitment write. Existing commitment data remains readable after expiry.
-- Additive/forward-only; apply only through the approved release process.

create or replace function public.has_active_plus_feature(
  p_space_id uuid,
  p_feature text
) returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
      from public.family_entitlement e
     where e.space_id = p_space_id
       and e.status in ('active', 'gracePeriod', 'canceledActive')
       and (e.expires_at is null or e.expires_at > now())
       and e.features ? p_feature
  );
$$;

revoke all on function public.has_active_plus_feature(uuid, text) from public;
grant execute on function public.has_active_plus_feature(uuid, text)
  to authenticated;

drop policy if exists financial_commitment_write
  on public.financial_commitment;
create policy financial_commitment_write on public.financial_commitment
  for all to authenticated
  using (
    public.space_role(space_id) is not null
    and public.space_role(space_id) <> 'viewer'
    and public.has_active_plus_feature(space_id, 'smart_commitments')
  )
  with check (
    public.space_role(space_id) is not null
    and public.space_role(space_id) <> 'viewer'
    and public.has_active_plus_feature(space_id, 'smart_commitments')
  );

drop policy if exists commitment_occurrence_write
  on public.commitment_occurrence;
create policy commitment_occurrence_write on public.commitment_occurrence
  for all to authenticated
  using (exists (
    select 1
      from public.financial_commitment c
     where c.id = commitment_id
       and public.space_role(c.space_id) is not null
       and public.space_role(c.space_id) <> 'viewer'
       and public.has_active_plus_feature(c.space_id, 'smart_commitments')
  ))
  with check (exists (
    select 1
      from public.financial_commitment c
     where c.id = commitment_id
       and public.space_role(c.space_id) is not null
       and public.space_role(c.space_id) <> 'viewer'
       and public.has_active_plus_feature(c.space_id, 'smart_commitments')
  ));

drop policy if exists commitment_payment_write
  on public.commitment_payment;
create policy commitment_payment_write on public.commitment_payment
  for all to authenticated
  using (exists (
    select 1
      from public.commitment_occurrence o
      join public.financial_commitment c on c.id = o.commitment_id
     where o.id = occurrence_id
       and public.space_role(c.space_id) is not null
       and public.space_role(c.space_id) <> 'viewer'
       and public.has_active_plus_feature(c.space_id, 'smart_commitments')
  ))
  with check (exists (
    select 1
      from public.commitment_occurrence o
      join public.financial_commitment c on c.id = o.commitment_id
     where o.id = occurrence_id
       and public.space_role(c.space_id) is not null
       and public.space_role(c.space_id) <> 'viewer'
       and public.has_active_plus_feature(c.space_id, 'smart_commitments')
  ));
