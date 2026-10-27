-- 060: private AAC voice notes use the existing family chat media bucket.
-- The 059 trigger and storage insert policy keep recording/upload Plus-only;
-- authenticated family members can continue reading existing voice notes.

update storage.buckets
   set public = false,
       file_size_limit = 10485760,
       allowed_mime_types = array[
         'image/jpeg', 'image/png', 'image/webp', 'audio/mp4'
       ]
 where id = 'chat-media';

do $$
begin
  if not exists (
    select 1 from storage.buckets
     where id = 'chat-media' and not public
       and allowed_mime_types @> array['audio/mp4']::text[]
  ) then
    raise exception '060 SELF-TEST FAILED: private chat media bucket must accept AAC voice notes';
  end if;
end;
$$;
