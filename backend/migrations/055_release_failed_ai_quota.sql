-- 055: Refund an Ask Mhuri quota reservation when the provider fails.
-- Usage remains family-scoped and server-only.
create or replace function public.release_ai_usage(p_space_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.ai_usage_quota
     set request_count = greatest(0, request_count - 1), updated_at = now()
   where space_id = p_space_id
     and usage_date = (now() at time zone 'utc')::date;
$$;

revoke all on function public.release_ai_usage(uuid) from public;
revoke all on function public.release_ai_usage(uuid) from anon, authenticated;
grant execute on function public.release_ai_usage(uuid) to service_role;
