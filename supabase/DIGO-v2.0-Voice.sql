-- DIGO v2.0 Voice Beta: run once AFTER the existing v1.9 moderation migration.
-- No new app tables, passwords, or keys are needed.
-- Authorize voice signaling and voice Presence only for members of PRIVATE DIGO rooms.

begin;

create or replace function public.digo_can_access_voice_topic(p_topic text)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_room_id uuid;
begin
  if auth.uid() is null then return false; end if;
  if p_topic is null or p_topic !~ '^voice:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;
  if digo_private.is_suspended(auth.uid()) then return false; end if;
  v_room_id:=substring(p_topic from 7)::uuid;
  return exists (
    select 1 from public.rooms r
    where r.id=v_room_id and r.is_private=true
      and public.can_access_room(r.id)
  );
end;
$$;

revoke all on function public.digo_can_access_voice_topic(text) from public,anon,authenticated;
grant execute on function public.digo_can_access_voice_topic(text) to authenticated;

-- Supabase already manages RLS on realtime.messages.
-- Never ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY.
drop policy if exists digo_voice_read_v20 on realtime.messages;
create policy digo_voice_read_v20 on realtime.messages
  for select to authenticated
  using (
    extension in ('presence','broadcast')
    and public.digo_can_access_voice_topic(realtime.topic())
  );

drop policy if exists digo_voice_write_v20 on realtime.messages;
create policy digo_voice_write_v20 on realtime.messages
  for insert to authenticated
  with check (
    extension in ('presence','broadcast')
    and public.digo_can_access_voice_topic(realtime.topic())
  );

commit;

-- SAFETY:
-- Only private-room members are authorized to use the signaling channel.
-- Suspended users are denied on a new channel authorization.
-- Existing Realtime connections may retain cached permission until refreshed/reconnected.
-- Browser-to-browser voice has no guaranteed hard four-user limit or TURN relay yet.
-- Use only with trusted beta testers until signaling, moderator tools,
-- anti-impersonation and abuse controls have been independently tested.
