-- DIGO v1.9: server-protected moderation (run once AFTER v1.6 and v1.7 migrations).
-- Existing users, messages, rooms, and games are kept.
-- IMPORTANT: Admin accounts are intentionally NOT granted automatically.
begin;

create schema if not exists digo_private;
revoke all on schema digo_private from public, anon, authenticated;

create table if not exists digo_private.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  added_at timestamptz not null default now()
);
create table if not exists digo_private.suspensions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  suspended_until timestamptz not null,
  applied_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);
-- Defense in depth: private admin records must never be queryable by clients.
-- SECDEF RPCs owned by postgres continue to work without client RLS policies.
alter table digo_private.admins enable row level security;
alter table digo_private.suspensions enable row level security;
revoke all on all tables in schema digo_private from public,anon,authenticated;

alter table public.reports
  add column if not exists review_status text not null default 'open',
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by uuid references auth.users(id) on delete set null;
alter table public.direct_message_reports
  add column if not exists body_snapshot text,
  add column if not exists review_status text not null default 'open',
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by uuid references auth.users(id) on delete set null;
-- An admin can later review past reports; snapshot evidence when first reported.
update public.direct_message_reports r set body_snapshot=m.body
from public.direct_messages m where r.message_id=m.id and r.body_snapshot is null;

create or replace function digo_private.capture_dm_evidence()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  select m.body into new.body_snapshot from public.direct_messages m where m.id=new.message_id;
  return new;
end; $$;
drop trigger if exists digo_dm_report_snapshot_v19 on public.direct_message_reports;
create trigger digo_dm_report_snapshot_v19 before insert on public.direct_message_reports
for each row execute function digo_private.capture_dm_evidence();

revoke insert on public.direct_message_reports from authenticated;
grant insert(reporter_id,message_id,reason) on public.direct_message_reports to authenticated;

create or replace function digo_private.is_admin(p_user_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select p_user_id is not null and exists
    (select 1 from digo_private.admins a where a.user_id=p_user_id);
$$;
create or replace function digo_private.is_suspended(p_user_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select p_user_id is not null and exists
    (select 1 from digo_private.suspensions s
     where s.user_id=p_user_id and s.suspended_until>now());
$$;
create or replace function digo_private.block_suspended_writes()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is not null and digo_private.is_suspended(auth.uid()) then
    raise exception 'DIGO account temporarily suspended; you cannot post, chat, or play right now.';
  end if;
  return new;
end; $$;

-- Check the real JWT user before inserts; this also applies to SECURITY DEFINER RPCs.
do $$
declare t text;
begin
  foreach t in array array[
    'messages','emotes','message_reactions','direct_messages',
    'friend_requests','game_sessions','game_actions','game_guess_attempts',
    'room_members','rooms'
  ] loop
    execute format('drop trigger if exists digo_suspension_check_v19 on public.%I',t);
    execute format('create trigger digo_suspension_check_v19 before insert on public.%I for each row execute function digo_private.block_suspended_writes()',t);
  end loop;
end $$;

create or replace function public.digo_account_status()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare u uuid := auth.uid(); until_at timestamptz;
begin
  if u is null then raise exception 'Sign in required'; end if;
  select suspended_until into until_at from digo_private.suspensions where user_id=u and suspended_until>now();
  return jsonb_build_object('is_admin',digo_private.is_admin(u),'suspended_until',until_at);
end; $$;

create or replace function public.digo_admin_queue()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare u uuid := auth.uid(); items jsonb; active_bans jsonb;
begin
  if not digo_private.is_admin(u) then raise exception 'Admin access required'; end if;
  select coalesce(jsonb_agg(q.payload order by q.occurred_at desc),'[]'::jsonb) into items
  from (
    select r.created_at as occurred_at,
      jsonb_build_object(
        'id',r.id,'kind','room','status',r.review_status,'reason',r.reason,
        'reported_at',r.created_at,'reporter_id',r.reporter_id,
        'reporter_name',rp.display_name,'author_id',m.user_id,
        'author_name',ap.display_name,'content',coalesce(r.body_snapshot,m.body,'Unavailable'),
        'room_id',m.room_id,'message_id',m.id,'deleted',m.deleted_at is not null
      ) as payload
    from public.reports r
    join public.messages m on m.id=r.message_id
    left join public.profiles rp on rp.id=r.reporter_id
    left join public.profiles ap on ap.id=m.user_id
    union all
    select r.created_at,
      jsonb_build_object(
        'id',r.id,'kind','dm','status',r.review_status,'reason',r.reason,
        'reported_at',r.created_at,'reporter_id',r.reporter_id,
        'reporter_name',rp.display_name,'author_id',m.from_id,
        'author_name',ap.display_name,'content',coalesce(r.body_snapshot,m.body,'Unavailable'),
        'message_id',m.id,'deleted',m.body='[removed by moderation]'
      ) as payload
    from public.direct_message_reports r
    join public.direct_messages m on m.id=r.message_id
    left join public.profiles rp on rp.id=r.reporter_id
    left join public.profiles ap on ap.id=m.from_id
    order by 1 desc limit 100
  ) q;
  select coalesce(jsonb_agg(jsonb_build_object(
    'user_id',s.user_id,'name',p.display_name,'until',s.suspended_until
  ) order by s.suspended_until desc),'[]'::jsonb) into active_bans
  from digo_private.suspensions s
  left join public.profiles p on p.id=s.user_id
  where s.suspended_until>now();
  return jsonb_build_object('reports',items,'suspensions',active_bans);
end; $$;

create or replace function public.digo_admin_review(p_kind text,p_report_id uuid,p_decision text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if not digo_private.is_admin(auth.uid()) then raise exception 'Admin access required'; end if;
  if p_kind not in ('room','dm') or p_decision not in ('resolved','dismissed','open') then
    raise exception 'Invalid moderation decision';
  end if;
  if p_kind='room' then
    update public.reports
    set review_status=p_decision,reviewed_at=case when p_decision='open' then null else now() end,
      reviewed_by=case when p_decision='open' then null else auth.uid() end
    where id=p_report_id;
  else
    update public.direct_message_reports
    set review_status=p_decision,reviewed_at=case when p_decision='open' then null else now() end,
      reviewed_by=case when p_decision='open' then null else auth.uid() end
    where id=p_report_id;
  end if;
  if not found then raise exception 'Report not found'; end if;
end; $$;

create or replace function public.digo_admin_remove_reported(p_kind text,p_report_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare target_id uuid;
begin
  if not digo_private.is_admin(auth.uid()) then raise exception 'Admin access required'; end if;
  if p_kind='room' then
    select m.user_id into target_id from public.messages m
      join public.reports r on r.message_id=m.id where r.id=p_report_id;
    if target_id is null then raise exception 'Report not found'; end if;
    update public.messages set body='[removed by moderation]',deleted_at=coalesce(deleted_at,now())
    where id=(select message_id from public.reports where id=p_report_id);
    update public.reports set review_status='resolved',reviewed_at=now(),reviewed_by=auth.uid()
    where id=p_report_id;
  elsif p_kind='dm' then
    select m.from_id into target_id from public.direct_messages m
      join public.direct_message_reports r on r.message_id=m.id where r.id=p_report_id;
    if target_id is null then raise exception 'Report not found'; end if;
    update public.direct_messages set body='[removed by moderation]'
    where id=(select message_id from public.direct_message_reports where id=p_report_id);
    update public.direct_message_reports set review_status='resolved',reviewed_at=now(),reviewed_by=auth.uid()
    where id=p_report_id;
  else
    raise exception 'Unknown report category';
  end if;
  if digo_private.is_admin(target_id) then raise exception 'Cannot moderate another admin'; end if;
end; $$;

create or replace function public.digo_admin_suspend(p_user_id uuid,p_minutes integer)
returns void language plpgsql security definer set search_path='' as $$
begin
  if not digo_private.is_admin(auth.uid()) then raise exception 'Admin access required'; end if;
  if p_user_id is null or p_user_id=auth.uid() or digo_private.is_admin(p_user_id) then
    raise exception 'Cannot suspend that account';
  end if;
  if p_minutes=0 then
    delete from digo_private.suspensions where user_id=p_user_id;
  elsif p_minutes between 5 and 10080 then
    if not exists(select 1 from public.profiles where id=p_user_id) then
      raise exception 'Account not found';
    end if;
    insert into digo_private.suspensions(user_id,suspended_until,applied_by)
      values (p_user_id,now()+make_interval(mins=>p_minutes),auth.uid())
    on conflict (user_id) do update set
      suspended_until=excluded.suspended_until,
      applied_by=excluded.applied_by,
      updated_at=now();
  else
    raise exception 'Choose 0 (restore) or 5 minutes through 7 days';
  end if;
end; $$;

-- Exposed RPCs are strictly scoped and each checks auth.uid() and admin status.
revoke all on function public.digo_account_status() from public,anon,authenticated;
revoke all on function public.digo_admin_queue() from public,anon,authenticated;
revoke all on function public.digo_admin_review(text,uuid,text) from public,anon,authenticated;
revoke all on function public.digo_admin_remove_reported(text,uuid) from public,anon,authenticated;
revoke all on function public.digo_admin_suspend(uuid,integer) from public,anon,authenticated;
grant execute on function public.digo_account_status() to authenticated;
grant execute on function public.digo_admin_queue() to authenticated;
grant execute on function public.digo_admin_review(text,uuid,text) to authenticated;
grant execute on function public.digo_admin_remove_reported(text,uuid) to authenticated;
grant execute on function public.digo_admin_suspend(uuid,integer) to authenticated;

commit;

-- ACTIVATE YOUR ADMIN MANUALLY AFTER RUNNING:
-- 1) In DIGO on your own browser, use a nickname you recognize.
-- 2) In Supabase Authentication > Users, identify YOUR correct user and copy its UUID.
-- 3) In SQL Editor, run (replace the placeholder with YOUR UUID):
--    insert into digo_private.admins(user_id) values ('YOUR-AUTH-USER-UUID'::uuid)
--    on conflict (user_id) do nothing;
-- 4) Refresh DIGO. No other accounts gain admin automatically.
