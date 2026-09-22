-- Prevent a completed shopping trip from being converted into an expense
-- more than once. The client marks each included item during local checkout
-- and syncs this durable flag to every device.
alter table public.list_item
  add column if not exists checked_out boolean not null default false;
