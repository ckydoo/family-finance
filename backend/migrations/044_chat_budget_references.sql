-- Allow family-chat messages to reference a shared budget envelope.
-- Existing reference types and rows are preserved.
alter table public.family_chat_message
  drop constraint if exists family_chat_message_reference_type_check;

alter table public.family_chat_message
  add constraint family_chat_message_reference_type_check
  check (reference_type in (
    'task',
    'shopping_list',
    'expense',
    'goal',
    'contribution',
    'budget'
  ));
