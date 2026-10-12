-- Kids Mode runs as a PIN-protected child profile on a parent/admin device.
-- Allow that authenticated family manager to create a pending request on
-- behalf of an active Kid in the same space. Directly authenticated Kids
-- retain the existing self-request path. No other role can impersonate a Kid.
drop policy if exists req_insert on public.kid_request;
create policy req_insert on public.kid_request for insert
  with check (
    (requester_id = auth.uid() and public.space_role(space_id) = 'kid')
    or (
      public.can_manage_finances(space_id)
      and state = 'pending'
      and kind = 'money'
      and exists (
        select 1
          from public.membership m
         where m.space_id = kid_request.space_id
           and m.user_id = kid_request.requester_id
           and m.role = 'kid'
           and m.invite_status = 'active'
      )
    )
  );
