-- Run AFTER setup.sql in your new studio project's SQL editor.
begin;
alter table public.bookings add column if not exists deposit_cents integer not null default 0 check(deposit_cents>=0 and deposit_cents<=10000000);
alter table public.bookings add column if not exists currency text not null default 'USD' check(currency in ('USD','EUR','GBP','KES'));
alter table public.bookings add column if not exists quote_version integer not null default 1;
alter table public.bookings add column if not exists payment_status text not null default 'unpaid' check(payment_status in ('unpaid','paid'));
alter table public.bookings add column if not exists checkout_session_id text;
alter table public.bookings add column if not exists payment_intent_id text;
alter table public.bookings add column if not exists paid_at timestamptz;
alter table public.bookings add column if not exists confirmed_at timestamptz;
create table public.studio_experience (id integer primary key default 1 check(id=1),content jsonb not null check(jsonb_typeof(content)='object'));
create table public.client_projects (
 id uuid primary key default gen_random_uuid(), client_user_id uuid not null references auth.users(id) on delete restrict,
 client_name text not null, client_email text not null, booking_id uuid unique references public.bookings(id) on delete set null,
 title text not null check(length(title)<=180), service text not null, brief text not null default '' check(length(brief)<=4000),
 stage text not null default 'Planning' check(stage in ('Planning','Recording','Production','Mixing','Review','Delivered')),
 progress integer not null default 0 check(progress between 0 and 100), created_at timestamptz not null default now()
);
create table public.client_updates (id uuid primary key default gen_random_uuid(),project_id uuid not null references public.client_projects(id) on delete cascade,title text not null check(length(title)<=180),body text not null check(length(body)<=4000),created_at timestamptz not null default now());
create table public.client_files (id uuid primary key default gen_random_uuid(),project_id uuid not null references public.client_projects(id) on delete cascade,name text not null,kind text not null,storage_path text not null unique,is_final boolean not null default false,created_at timestamptz not null default now());
create table public.client_feedback (id uuid primary key default gen_random_uuid(),project_id uuid not null references public.client_projects(id) on delete cascade,author_user_id uuid not null references auth.users(id) on delete restrict,author_role text not null check(author_role in ('client','studio')),body text not null check(length(body) between 1 and 4000),created_at timestamptz not null default now());
create table public.notification_outbox (
 id uuid primary key default gen_random_uuid(),dedupe_key text not null unique,booking_id uuid references public.bookings(id) on delete set null,
 recipient text not null,kind text not null check(kind in ('received','confirmed','reminder','deposit')),subject text not null,html text not null,text text not null,
 status text not null default 'queued' check(status in ('queued','processing','sent','failed')),attempts integer not null default 0,
 provider_id text,last_error text not null default '',next_attempt_at timestamptz not null default now(),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),sent_at timestamptz
);
create index client_owner_idx on public.client_projects(client_user_id);
create index client_booking_idx on public.client_projects(booking_id);
create index client_updates_project_idx on public.client_updates(project_id);
create index client_files_project_idx on public.client_files(project_id);
create index client_feedback_project_idx on public.client_feedback(project_id);
create index client_feedback_author_idx on public.client_feedback(author_user_id);
create index outbox_pending_idx on public.notification_outbox(status,next_attempt_at);
create index outbox_booking_idx on public.notification_outbox(booking_id);
alter table public.studio_experience enable row level security;
alter table public.client_projects enable row level security;
alter table public.client_updates enable row level security;
alter table public.client_files enable row level security;
alter table public.client_feedback enable row level security;
alter table public.notification_outbox enable row level security;
revoke all on public.client_projects,public.client_updates,public.client_files,public.client_feedback,public.notification_outbox from anon,authenticated;
grant select on public.client_projects,public.client_updates,public.client_files,public.client_feedback to authenticated;
grant select on public.studio_experience to anon,authenticated;
grant update on public.studio_experience to authenticated;
grant all on public.studio_experience,public.client_projects,public.client_updates,public.client_files,public.client_feedback,public.notification_outbox to service_role;
create policy "Public studio experience" on public.studio_experience for select to anon,authenticated using(true);
create policy "Admins update studio experience" on public.studio_experience for update to authenticated using(exists(select 1 from public.studio_admins where user_id=(select auth.uid()))) with check(exists(select 1 from public.studio_admins where user_id=(select auth.uid())));
create policy "Owners or admins read projects" on public.client_projects for select to authenticated using(client_user_id=(select auth.uid()) or exists(select 1 from public.studio_admins where user_id=(select auth.uid())));
create policy "Owners or admins read updates" on public.client_updates for select to authenticated using(exists(select 1 from public.client_projects where id=project_id and (client_user_id=(select auth.uid()) or exists(select 1 from public.studio_admins where user_id=(select auth.uid())))));
create policy "Owners or admins read files" on public.client_files for select to authenticated using(exists(select 1 from public.client_projects where id=project_id and (client_user_id=(select auth.uid()) or exists(select 1 from public.studio_admins where user_id=(select auth.uid())))));
create policy "Owners or admins read feedback" on public.client_feedback for select to authenticated using(exists(select 1 from public.client_projects where id=project_id and (client_user_id=(select auth.uid()) or exists(select 1 from public.studio_admins where user_id=(select auth.uid())))));
-- All client mutations and notification operations go through authenticated server routes.
-- There is intentionally no client read or insert policy on notification_outbox.
insert into storage.buckets(id,name,public,file_size_limit) values('studio-deliverables','studio-deliverables',false,52428800) on conflict(id) do nothing;
create policy "Admins upload private deliverables" on storage.objects for insert to authenticated with check(bucket_id='studio-deliverables' and exists(select 1 from public.studio_admins where user_id=(select auth.uid())));
create policy "Admins read private deliverables" on storage.objects for select to authenticated using(bucket_id='studio-deliverables' and exists(select 1 from public.studio_admins where user_id=(select auth.uid())));
create policy "Admins remove private deliverables" on storage.objects for delete to authenticated using(bucket_id='studio-deliverables' and exists(select 1 from public.studio_admins where user_id=(select auth.uid())));
insert into public.studio_experience(id,content) values(1,'{"showreel_url":"","showreel_title":"A little sound. A lot of feeling.","audio_title":"Midnight / instrumental study","audio_before":"/audio/midnight-before.wav","audio_after":"/audio/midnight-after.wav","audio_is_demo":true,"packages":[{"id":"spark","title":"The Spark","tag":"Find your sound","price":180,"currency":"USD","duration":2,"service":"Recording & music production","featured":false,"items":["2-hour recording session","Vocal recording & editing","Creative session planning","Stereo rough mix"],"is_example":true},{"id":"record","title":"The Record","tag":"Bring it all together","price":480,"currency":"USD","duration":4,"service":"Recording & music production","featured":true,"items":["4-hour production session","Arrangement & vocal production","Mixing & mastering","Two rounds of revisions"],"is_example":true},{"id":"vision","title":"The Vision","tag":"Make your story seen","price":1200,"currency":"USD","duration":8,"service":"Film & video production","featured":false,"items":["Concept & production planning","One-day video shoot","Editing & colour grading","Social cutdowns"],"is_example":true}],"team":[{"id":"producer","name":"Your music producer","role":"Music production & creative direction","bio":"The collaborator who helps find the heart of your record — from the first idea to the final arrangement.","image":"/images/studio.jpg","is_placeholder":true},{"id":"engineer","name":"Your sound engineer","role":"Recording, mixing & mastering","bio":"A careful ear for detail, character and the sound that feels unmistakably yours.","image":"/images/microphone.jpg","is_placeholder":true},{"id":"director","name":"Your film director","role":"Film & visual storytelling","bio":"An eye for the moments that matter, turning your story into a visual world.","image":"/images/film.jpg","is_placeholder":true}]}'::jsonb);
commit;
