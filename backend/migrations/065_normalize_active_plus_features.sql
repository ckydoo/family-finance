-- 065: An active Mhuri Plus subscription includes the complete advertised
-- feature set. Backfill older entitlements and keep future active rows whole.

create or replace function public.mhuri_plus_feature_set()
returns jsonb
language sql
immutable
set search_path = public
as $$
  select '[
    "smart_commitments",
    "cash_flow_forecast",
    "period_preparation",
    "financial_health",
    "savings_projections",
    "debt_planning",
    "family_polls_pins",
    "advanced_chat_search",
    "enhanced_family_chat",
    "advanced_insights",
    "advanced_reports",
    "enhanced_reports"
  ]'::jsonb;
$$;

update public.family_entitlement
   set features = (
         select jsonb_agg(distinct value)
           from jsonb_array_elements(
             coalesce(features, '[]'::jsonb) || public.mhuri_plus_feature_set()
           ) as feature(value)
       ),
       updated_at = now()
 where status in ('active', 'gracePeriod', 'canceledActive')
   and (expires_at is null or expires_at > now());

create or replace function public.normalize_active_plus_features()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.status in ('active', 'gracePeriod', 'canceledActive')
     and (new.expires_at is null or new.expires_at > now()) then
    select jsonb_agg(distinct value)
      into new.features
      from jsonb_array_elements(
        coalesce(new.features, '[]'::jsonb) || public.mhuri_plus_feature_set()
      ) as feature(value);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_normalize_active_plus_features
  on public.family_entitlement;
create trigger trg_normalize_active_plus_features
before insert or update of status, features, expires_at
on public.family_entitlement
for each row execute function public.normalize_active_plus_features();
