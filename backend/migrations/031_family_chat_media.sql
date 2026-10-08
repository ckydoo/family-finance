-- 031: synced photo and sticker attachments for family chat.

alter table public.family_chat_message
  add column if not exists media_url text,
  add column if not exists media_type text,
  add column if not exists sticker text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'chat-media',
  'chat-media',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  -- Family chat attachments must always require an authenticated family
  -- membership check. This also repairs an accidentally-public bucket.
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists chat_media_read on storage.objects;
create policy chat_media_read on storage.objects for select
using (
  bucket_id = 'chat-media' and
  public.space_role(((storage.foldername(name))[1])::uuid) is not null
);

drop policy if exists chat_media_insert on storage.objects;
create policy chat_media_insert on storage.objects for insert
with check (
  bucket_id = 'chat-media' and
  public.space_role(((storage.foldername(name))[1])::uuid) is not null and
  owner_id = auth.uid()::text
);

drop policy if exists chat_media_delete on storage.objects;
create policy chat_media_delete on storage.objects for delete
using (
  bucket_id = 'chat-media' and owner_id = auth.uid()::text
);
