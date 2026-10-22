-- Chat authorship is an authentication fact, never a client-selected value.
-- This also keeps admin "Preview as" mode from producing an RLS rejection.
create or replace function public.guard_family_chat_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if auth.uid() is null then
      raise exception 'Authentication required';
    end if;
    new.sender_id := auth.uid();
  end if;
  new.updated_at := now();
  return new;
end;
$$;
