-- DIGO v1.7: message controls and real replies
-- Run ONCE in the existing DIGO Supabase project after v1.6 setup.
-- Existing messages and conversations are not dropped.
begin;

alter table public.messages
  add column if not exists deleted_at timestamptz,
  add column if not exists edited_at timestamptz,
  add column if not exists reply_to uuid references public.messages(id) on delete set null;

create index if not exists digo_messages_reply_to_idx on public.messages(reply_to);

-- Keep a private copy of reported text at reporting time. The client cannot set the snapshot.
alter table public.reports add column if not exists body_snapshot text;
update public.reports r
set body_snapshot=m.body from public.messages m
where m.id=r.message_id and r.body_snapshot is null;

create or replace function public.digo_capture_report_evidence()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  select m.body into new.body_snapshot from public.messages m where m.id=new.message_id;
  return new;
end; $$;
drop trigger if exists digo_capture_report_evidence_v17 on public.reports;
create trigger digo_capture_report_evidence_v17
before insert on public.reports for each row
execute function public.digo_capture_report_evidence();

revoke insert on public.reports from authenticated;
grant insert(reporter_id,message_id,reason) on public.reports to authenticated;

-- Check reply target against the room through a fixed-purpose database function.
create or replace function public.digo_reply_allowed(p_message uuid,p_room uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $
  select exists(select 1 from public.messages
                where id=p_message and room_id=p_room and deleted_at is null);
$;
revoke all on function public.digo_reply_allowed(uuid,uuid) from public;
grant execute on function public.digo_reply_allowed(uuid,uuid) to authenticated;

drop policy if exists message_send on public.messages;
create policy message_send on public.messages for insert to authenticated
with check (
  user_id=(select auth.uid()) and public.is_room_member(room_id)
  and deleted_at is null and edited_at is null
  and (reply_to is null or public.digo_reply_allowed(reply_to,room_id))
);
-- No direct client UPDATE or DELETE on messages. Trusted RPC functions own these changes.
revoke update, delete on public.messages from authenticated;

create or replace function public.digo_delete_own_message(p_message_id uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Sign in first'; end if;
  update public.messages set body='[message deleted]',deleted_at=now()
  where id=p_message_id and user_id=v_uid and deleted_at is null;
  if not found then raise exception 'Only your own active messages can be deleted'; end if;
end; $$;

create or replace function public.digo_edit_own_message(p_message_id uuid,p_body text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Sign in first'; end if;
  if char_length(trim(coalesce(p_body,''))) not between 1 and 500 then
    raise exception 'Message must contain 1 to 500 characters';
  end if;
  update public.messages set body=trim(p_body),edited_at=now()
  where id=p_message_id and user_id=v_uid and deleted_at is null;
  if not found then raise exception 'Only your own active messages can be edited'; end if;
end; $$;

revoke all on function public.digo_delete_own_message(uuid) from public;
revoke all on function public.digo_edit_own_message(uuid,text) from public;
grant execute on function public.digo_delete_own_message(uuid) to authenticated;
grant execute on function public.digo_edit_own_message(uuid,text) to authenticated;

commit;

-- Verify after running:
-- select column_name from information_schema.columns
-- where table_schema='public' and table_name='messages'
-- and column_name in ('deleted_at','edited_at','reply_to');
