-- Run once in the NEW studio project's Supabase SQL editor.
-- No client insert permissions: bookings are submitted through the server API.
begin;
create table public.studio_admins (user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.studio_admins enable row level security;
grant select on public.studio_admins to authenticated;
revoke all on public.studio_admins from anon;
create policy "Admin can verify own membership" on public.studio_admins for select to authenticated using (user_id = (select auth.uid()));
create table public.site_settings (
 id integer primary key default 1 check(id=1), studio_name text not null default 'KTEXAS',
 hero_line text not null default E'Make something\nthat moves people.',
 hero_description text not null default 'A creative home for extraordinary sound and cinematic stories. From the first spark to the final frame — let’s make it unforgettable.',
 email text not null default '', phone text not null default '', location text not null default '',
 instagram text not null default '', youtube text not null default '', tiktok text not null default '', facebook text not null default '', booking_open boolean not null default true
);
create table public.services (id uuid primary key default gen_random_uuid(), title text not null, category text not null, description text not null, details text not null default '', image text not null, active boolean not null default true, sort_order integer not null default 0);
create table public.projects (id uuid primary key default gen_random_uuid(), title text not null, category text not null check(category in ('Music','Film','Live')), description text not null, image text not null, media_url text not null default '', is_concept boolean not null default false, published boolean not null default true, sort_order integer not null default 0);
create table public.bookings (
 id uuid primary key default gen_random_uuid(), name text not null check(length(name) between 1 and 120), email text not null check(length(email)<=254), phone text not null default '',
 service text not null, date date not null, time time not null, duration integer not null check(duration in (2,3,4,6,8)),
 notes text not null default '' check(length(notes)<=2000), admin_notes text not null default '',
 status text not null default 'pending' check(status in ('pending','confirmed','completed','cancelled')), created_at timestamptz not null default now()
);
create table public.booking_rate_limits (id text primary key, expires_at timestamptz not null);
create index bookings_date_idx on public.bookings(date);
create index bookings_created_idx on public.bookings(created_at desc);
create index booking_rate_expiry_idx on public.booking_rate_limits(expires_at);
alter table public.site_settings enable row level security;
alter table public.services enable row level security;
alter table public.projects enable row level security;
alter table public.bookings enable row level security;
alter table public.booking_rate_limits enable row level security;
revoke all on public.bookings, public.booking_rate_limits from anon, authenticated;
grant select, update on public.bookings to authenticated;
grant select on public.site_settings, public.services, public.projects to anon, authenticated;
grant update on public.site_settings to authenticated;
grant insert, update, delete on public.services, public.projects to authenticated;
grant all on public.bookings, public.booking_rate_limits, public.site_settings, public.services, public.projects to service_role;
create policy "Public studio settings" on public.site_settings for select to anon, authenticated using(true);
create policy "Public active services" on public.services for select to anon, authenticated using(active or exists(select 1 from public.studio_admins where user_id=(select auth.uid())));
create policy "Public published projects" on public.projects for select to anon, authenticated using(published or exists(select 1 from public.studio_admins where user_id=(select auth.uid())));
create policy "Admins edit settings" on public.site_settings for update to authenticated using(exists(select 1 from public.studio_admins where user_id=(select auth.uid()))) with check(exists(select 1 from public.studio_admins where user_id=(select auth.uid())));
create policy "Admins manage services" on public.services for all to authenticated using(exists(select 1 from public.studio_admins where user_id=(select auth.uid()))) with check(exists(select 1 from public.studio_admins where user_id=(select auth.uid())));
create policy "Admins manage projects" on public.projects for all to authenticated using(exists(select 1 from public.studio_admins where user_id=(select auth.uid()))) with check(exists(select 1 from public.studio_admins where user_id=(select auth.uid())));
create policy "Admins read bookings" on public.bookings for select to authenticated using(exists(select 1 from public.studio_admins where user_id=(select auth.uid())));
create policy "Admins update bookings" on public.bookings for update to authenticated using(exists(select 1 from public.studio_admins where user_id=(select auth.uid()))) with check(exists(select 1 from public.studio_admins where user_id=(select auth.uid())));
insert into public.site_settings(id) values(1);
insert into public.services(title,category,description,details,image,sort_order) values
('Recording & music production','Sound','Find your sound. Capture the feeling. From intimate vocal sessions to fully realised productions, we give your ideas room to become something extraordinary.','Vocal & instrument recording · Beat production · Song arrangement · Creative direction','/images/microphone.jpg',1),
('Film & video production','Vision','Stories that stay with you. Music videos, brand films and visual experiences built around an unmistakable point of view.','Music videos · Brand films · Live sessions · Editing & colour grading','/images/film.jpg',2),
('Mixing & mastering','Finish','Every detail, in its right place. Depth, clarity and character that translate beautifully from headphones to the biggest speakers.','Stereo mixing · Mastering · Vocal editing · Remote collaboration','/images/studio.jpg',3),
('Creative direction','Feeling','A bigger picture for your next chapter. We connect the sound, the visuals and the story into one cohesive creative world.','Visual concepts · Release identity · Art direction · Production planning','/images/live.jpg',4);
insert into public.projects(title,category,description,image,is_concept,sort_order) values
('The sound of a new chapter','Music','From a rough voice note to a finished record. Explore the possibilities of recording and music production with KTEXAS.','/images/microphone.jpg',true,1),
('Stories beyond the frame','Film','A cinematic approach to music videos and brand storytelling, shaped around your vision.','/images/film.jpg',true,2),
('In the moment','Live','Capture the energy of a performance through live session recording and film.','/images/live.jpg',true,3);
commit;
-- Create your administrator in Supabase Authentication > Users, then run:
-- insert into public.studio_admins(user_id) values ('ADMIN_USER_UUID');
-- Disable public signups in Authentication settings; never grant membership from user metadata.
