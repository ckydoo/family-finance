-- 041: durable edited marker for family chat messages.
-- Existing messages remain unmarked.

alter table public.family_chat_message
  add column if not exists edited_at timestamptz;
