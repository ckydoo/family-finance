-- 040: durable reply metadata for family chat swipe-to-reply.
-- Additive only: existing messages remain unchanged.

alter table public.family_chat_message
  add column if not exists reply_to_id uuid,
  add column if not exists reply_sender_name text,
  add column if not exists reply_preview text;

create index if not exists family_chat_message_reply_idx
  on public.family_chat_message(reply_to_id)
  where reply_to_id is not null;
