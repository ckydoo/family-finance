-- 030: notify other family members when a new chat message is created.
-- Delivery is best-effort and must never block chat persistence.

create or replace function public.dispatch_family_chat_push()
returns trigger
language plpgsql
security definer
set search_path = public, vault, net
as $$
declare
  webhook_secret text;
begin
  select decrypted_secret into webhook_secret
    from vault.decrypted_secrets
   where name = 'mhuri_push_webhook_secret'
   order by created_at desc
   limit 1;

  if webhook_secret is null or webhook_secret = '' then
    raise warning 'Push webhook secret is not configured';
    return new;
  end if;

  perform net.http_post(
    url := 'https://oltcfmlhtabknciyvqvk.supabase.co/functions/v1/send-family-push',
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

drop trigger if exists trg_family_chat_push on public.family_chat_message;
create trigger trg_family_chat_push
  after insert on public.family_chat_message
  for each row execute function public.dispatch_family_chat_push();
