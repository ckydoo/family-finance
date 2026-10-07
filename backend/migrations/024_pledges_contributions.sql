-- 024: family contribution campaigns, pledges and immutable payments.

create table if not exists public.contribution_campaign (
  id uuid primary key, space_id uuid not null references public.family_space(id) on delete cascade,
  name text not null, target_minor bigint not null check (target_minor > 0),
  currency text not null, deadline timestamptz not null,
  created_by uuid not null references public.user_profile(id),
  status text not null default 'active' check (status in ('active','closed','archived')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.contribution_pledge (
  id uuid primary key, campaign_id uuid not null references public.contribution_campaign(id) on delete cascade,
  member_id uuid not null references public.user_profile(id), amount_minor bigint not null check (amount_minor > 0),
  currency text not null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(campaign_id, member_id)
);
create table if not exists public.contribution_payment (
  id uuid primary key, campaign_id uuid not null references public.contribution_campaign(id) on delete cascade,
  member_id uuid not null references public.user_profile(id), amount_minor bigint not null check (amount_minor > 0),
  currency text not null, paid_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

alter table public.contribution_campaign enable row level security;
alter table public.contribution_pledge enable row level security;
alter table public.contribution_payment enable row level security;

drop policy if exists contribution_campaign_read on public.contribution_campaign;
create policy contribution_campaign_read on public.contribution_campaign for select using (public.space_role(space_id) is not null);
drop policy if exists contribution_campaign_write on public.contribution_campaign;
create policy contribution_campaign_write on public.contribution_campaign for all using (public.is_adult(space_id)) with check (public.is_adult(space_id));
drop policy if exists contribution_pledge_read on public.contribution_pledge;
create policy contribution_pledge_read on public.contribution_pledge for select using (exists(select 1 from public.contribution_campaign c where c.id=campaign_id and public.space_role(c.space_id) is not null));
drop policy if exists contribution_pledge_write on public.contribution_pledge;
create policy contribution_pledge_write on public.contribution_pledge for all using (exists(select 1 from public.contribution_campaign c where c.id=campaign_id and (public.is_family_admin(c.space_id) or member_id=auth.uid()))) with check (exists(select 1 from public.contribution_campaign c where c.id=campaign_id and (public.is_family_admin(c.space_id) or member_id=auth.uid())));
drop policy if exists contribution_payment_read on public.contribution_payment;
create policy contribution_payment_read on public.contribution_payment for select using (exists(select 1 from public.contribution_campaign c where c.id=campaign_id and public.space_role(c.space_id) is not null));
drop policy if exists contribution_payment_insert on public.contribution_payment;
create policy contribution_payment_insert on public.contribution_payment for insert with check (exists(select 1 from public.contribution_campaign c where c.id=campaign_id and (public.is_family_admin(c.space_id) or member_id=auth.uid())));

drop trigger if exists trg_contribution_campaign_updated on public.contribution_campaign;
create trigger trg_contribution_campaign_updated before update on public.contribution_campaign for each row execute function public.set_updated_at();
drop trigger if exists trg_contribution_pledge_updated on public.contribution_pledge;
create trigger trg_contribution_pledge_updated before update on public.contribution_pledge for each row execute function public.set_updated_at();

grant select,insert,update on public.contribution_campaign, public.contribution_pledge to authenticated;
grant select,insert on public.contribution_payment to authenticated;

create or replace function public.audit_contribution() returns trigger language plpgsql security definer set search_path=public as $$
declare v_space uuid; v_action text;
begin
  select space_id into v_space from public.contribution_campaign where id=new.campaign_id;
  v_action := case when tg_table_name='contribution_payment' then 'contribution.payment' else 'contribution.pledge' end;
  insert into public.activity_log(space_id,actor_id,action,entity,entity_id,detail,hash)
  values(v_space,coalesce(auth.uid(),new.member_id),v_action,tg_table_name,new.id,
    jsonb_build_object('campaign_id',new.campaign_id,'member_id',new.member_id,'amount_minor',new.amount_minor,'currency',new.currency),
    md5(new.id::text||v_action||clock_timestamp()));
  return new;
end $$;
drop trigger if exists trg_audit_contribution_pledge on public.contribution_pledge;
create trigger trg_audit_contribution_pledge after insert or update on public.contribution_pledge for each row execute function public.audit_contribution();
drop trigger if exists trg_audit_contribution_payment on public.contribution_payment;
create trigger trg_audit_contribution_payment after insert on public.contribution_payment for each row execute function public.audit_contribution();
