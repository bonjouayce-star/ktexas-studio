-- Run AFTER setup.sql and experience.sql. One studio space; all times use EAT.
begin;
-- Public content policies consult membership; anon may perform the lookup but
-- RLS exposes no membership rows (the only membership policy is staff's own).
grant select on public.studio_admins to anon;
create table public.studio_reservations (
 id uuid primary key default gen_random_uuid(), booking_id uuid unique references public.bookings(id) on delete cascade,
 starts_at timestamptz not null, ends_at timestamptz not null check(ends_at>starts_at),
 label text not null default '', created_at timestamptz not null default now(),
 exclude using gist (tstzrange(starts_at,ends_at,'[)') with &&)
);
create index reservations_start_idx on public.studio_reservations(starts_at);
create index reservations_end_idx on public.studio_reservations(ends_at);
alter table public.studio_reservations enable row level security;
revoke all on public.studio_reservations from anon,authenticated;
grant select,insert,update,delete on public.studio_reservations to authenticated;
grant all on public.studio_reservations to service_role;
create policy "Staff manage studio reservations" on public.studio_reservations for all to authenticated using(exists(select 1 from public.studio_admins where user_id=(select auth.uid()))) with check(exists(select 1 from public.studio_admins where user_id=(select auth.uid())));
-- Invoker permissions: only staff/server can confirm a booking and create its reservation.
create function public.sync_studio_reservation() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.status='confirmed' then
  insert into public.studio_reservations(booking_id,starts_at,ends_at,label)
  values(new.id,(new.date+new.time) at time zone 'Africa/Nairobi',((new.date+new.time) at time zone 'Africa/Nairobi')+make_interval(hours=>new.duration),'Confirmed session')
  on conflict(booking_id) do update set starts_at=excluded.starts_at,ends_at=excluded.ends_at;
 elsif new.status='completed' and exists(select 1 from public.studio_reservations where booking_id=new.id) then
  null; -- retain the occupied historical session
 else
  delete from public.studio_reservations where booking_id=new.id;
 end if;
 return new;
end $$;
revoke all on function public.sync_studio_reservation() from public,anon,authenticated;
create trigger booking_reservation after insert or update of status,date,time,duration on public.bookings for each row execute function public.sync_studio_reservation();
-- This intentionally fails if existing confirmed sessions overlap; resolve them before running.
insert into public.studio_reservations(booking_id,starts_at,ends_at,label)
select id,(date+time) at time zone 'Africa/Nairobi',((date+time) at time zone 'Africa/Nairobi')+make_interval(hours=>duration),'Confirmed session' from public.bookings where status='confirmed';
alter table public.client_projects add column preparation jsonb not null default '{}'::jsonb check(jsonb_typeof(preparation)='object');
create table public.client_decisions (
 id uuid primary key default gen_random_uuid(),project_id uuid not null references public.client_projects(id) on delete cascade,
 file_id uuid not null references public.client_files(id) on delete cascade,author_user_id uuid not null references auth.users(id),
 kind text not null check(kind in ('approved','revision')),body text not null default '' check(length(body)<=4000),
 status text not null default 'open' check(status in ('open','in_progress','resolved')),created_at timestamptz not null default now(),resolved_at timestamptz
);
create unique index file_final_approval on public.client_decisions(file_id) where kind='approved';
create index decisions_file_idx on public.client_decisions(file_id);
create index decisions_author_idx on public.client_decisions(author_user_id);
create index decisions_project_idx on public.client_decisions(project_id);
alter table public.client_files add column purpose text not null default 'delivery' check(purpose in ('delivery','reference'));
alter table public.client_decisions enable row level security;
revoke all on public.client_decisions from anon,authenticated;
grant select on public.client_decisions to authenticated;
grant all on public.client_decisions to service_role;
create policy "Owners and staff read decisions" on public.client_decisions for select to authenticated using(exists(select 1 from public.client_projects where id=project_id and(client_user_id=(select auth.uid()) or exists(select 1 from public.studio_admins where user_id=(select auth.uid())))));
-- Client reference uploads: own folder only; no overwrite/delete or public access.
create policy "Clients upload their references" on storage.objects for insert to authenticated with check(bucket_id='studio-deliverables' and (storage.foldername(name))[2]='references' and exists(select 1 from public.client_projects where id::text=(storage.foldername(name))[1] and client_user_id=(select auth.uid())));
alter table public.projects add column credits text not null default '' check(length(credits)<=2000);
alter table public.projects add column client_name text not null default '' check(length(client_name)<=180);
alter table public.projects add column release_year integer check(release_year between 1900 and 2200);
create table public.studio_testimonials (
 id uuid primary key default gen_random_uuid(),name text not null check(length(name) between 1 and 120),role text not null default '',
 quote text not null check(length(quote) between 1 and 1200),permission_confirmed boolean not null default false,published boolean not null default false,
 sort_order integer not null default 0,check(not published or permission_confirmed)
);
alter table public.studio_testimonials enable row level security;
grant select on public.studio_testimonials to anon,authenticated;
grant insert,update,delete on public.studio_testimonials to authenticated;
grant all on public.studio_testimonials to service_role;
create policy "Approved public testimonials" on public.studio_testimonials for select to anon,authenticated using((published and permission_confirmed) or exists(select 1 from public.studio_admins where user_id=(select auth.uid())));
create policy "Staff manage testimonials" on public.studio_testimonials for all to authenticated using(exists(select 1 from public.studio_admins where user_id=(select auth.uid()))) with check(exists(select 1 from public.studio_admins where user_id=(select auth.uid())));
-- Atomic provider selection prevents two providers charging the same deposit.
alter table public.bookings add column payment_provider text check(payment_provider in ('stripe','mpesa'));
create table public.mpesa_attempts (
 id uuid primary key default gen_random_uuid(),booking_id uuid not null unique references public.bookings(id),quote_version integer not null,
 amount_cents integer not null check(amount_cents>0 and amount_cents%100=0),phone text not null,
 checkout_request_id text unique,merchant_request_id text,status text not null default 'initiating' check(status in ('initiating','pending','paid','failed','unknown')),
 result_code text,created_at timestamptz not null default now(),checked_at timestamptz
);
alter table public.mpesa_attempts enable row level security;
revoke all on public.mpesa_attempts from anon,authenticated;
grant all on public.mpesa_attempts to service_role;
create function public.release_failed_mpesa(target_booking uuid) returns boolean language plpgsql security invoker set search_path='' as $$
declare current_booking public.bookings%rowtype; attempt public.mpesa_attempts%rowtype;
begin
 select * into current_booking from public.bookings where id=target_booking for update;
 select * into attempt from public.mpesa_attempts where booking_id=target_booking for update;
 if current_booking.payment_status='paid' or current_booking.payment_provider is distinct from 'mpesa' or attempt.status is distinct from 'failed' or attempt.result_code is null or attempt.result_code='0' then return false; end if;
 delete from public.mpesa_attempts where booking_id=target_booking;
 update public.bookings set payment_provider=null,quote_version=quote_version+1 where id=target_booking;
 return true;
end $$;
revoke all on function public.release_failed_mpesa(uuid) from public,anon,authenticated;
grant execute on function public.release_failed_mpesa(uuid) to service_role;
commit;
