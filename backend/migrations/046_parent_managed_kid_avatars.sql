-- 046: Parents can manage kid profile avatars.
-- Owners, co-parents/family admins, and adult parents may update a kid who
-- belongs to the same family. They cannot edit another adult's profile.

create or replace function public.can_manage_child_profile(p_member uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
      from membership actor
      join membership child on child.space_id = actor.space_id
     where actor.user_id = auth.uid()
       and actor.invite_status = 'active'
       and actor.role in ('owner', 'co_parent', 'adult')
       and child.user_id = p_member
       and child.invite_status = 'active'
       and child.role = 'kid'
  );
$$;

revoke all on function public.can_manage_child_profile(uuid) from public;
grant execute on function public.can_manage_child_profile(uuid) to authenticated;

create or replace function public.update_child_profile(
  p_member uuid,
  p_name text default null,
  p_avatar text default null,
  p_avatar_url text default null,
  p_update_name boolean default false,
  p_update_avatar boolean default false,
  p_update_avatar_url boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.can_manage_child_profile(p_member) then
    raise exception 'NOT_ALLOWED';
  end if;

  update user_profile
     set name = case
           when p_update_name then coalesce(nullif(btrim(p_name), ''), name)
           else name
         end,
         avatar = case
           when p_update_avatar then coalesce(nullif(btrim(p_avatar), ''), avatar)
           else avatar
         end,
         avatar_url = case
           when p_update_avatar_url then nullif(btrim(p_avatar_url), '')
           else avatar_url
         end
   where id = p_member;
end;
$$;

revoke all on function public.update_child_profile(
  uuid, text, text, text, boolean, boolean, boolean
) from public;
grant execute on function public.update_child_profile(
  uuid, text, text, text, boolean, boolean, boolean
) to authenticated;

-- Keep self-service writes and additionally allow a parent to upload into a
-- kid's folder. Public reads remain governed by avatar_public_read.
drop policy if exists "avatar_owner_write" on storage.objects;
create policy "avatar_owner_write" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.can_manage_child_profile(
        ((storage.foldername(name))[1])::uuid
      )
    )
  );

drop policy if exists "avatar_owner_update" on storage.objects;
create policy "avatar_owner_update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.can_manage_child_profile(
        ((storage.foldername(name))[1])::uuid
      )
    )
  )
  with check (
    bucket_id = 'avatars'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.can_manage_child_profile(
        ((storage.foldername(name))[1])::uuid
      )
    )
  );

drop policy if exists "avatar_owner_delete" on storage.objects;
create policy "avatar_owner_delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.can_manage_child_profile(
        ((storage.foldername(name))[1])::uuid
      )
    )
  );
