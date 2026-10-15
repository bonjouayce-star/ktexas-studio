-- Run AFTER workflow.sql. Existing studio_admins become owners; staff roles are separate.
begin;
grant select on public.studio_admins to service_role;
create table public.studio_staff(user_id uuid primary key references auth.users(id) on delete cascade,role text not null check(role in ('manager','producer','engineer')),display_name text not null check(length(display_name) between 1 and 120),created_at timestamptz not null default now());
create table public.project_staff(project_id uuid not null references public.client_projects(id) on delete cascade,user_id uuid not null references public.studio_staff(user_id) on delete cascade,primary key(project_id,user_id));
create index project_staff_user_idx on public.project_staff(user_id,project_id);
alter table public.studio_staff enable row level security;
alter table public.project_staff enable row level security;
revoke all on public.studio_staff,public.project_staff from anon,authenticated;
grant select on public.studio_staff,public.project_staff to authenticated;
grant all on public.studio_staff,public.project_staff to service_role;
create policy "Self or owner reads staff" on public.studio_staff for select to authenticated using(user_id=(select auth.uid()) or exists(select 1 from public.studio_admins where user_id=(select auth.uid())));
create policy "Self or owner reads assignment" on public.project_staff for select to authenticated using(user_id=(select auth.uid()) or exists(select 1 from public.studio_admins where user_id=(select auth.uid())));
-- Invoker helpers consult only self-readable membership/assignment rows; no RLS bypass.
create function public.studio_role() returns text language sql stable security invoker set search_path='' as $$select case when auth.uid() is null then null when exists(select 1 from public.studio_admins where user_id=auth.uid()) then 'owner' else (select role from public.studio_staff where user_id=auth.uid()) end$$;
create function public.can_work_project(target uuid) returns boolean language sql stable security invoker set search_path='' as $$select auth.uid() is not null and (public.studio_role() in ('owner','manager') or (public.studio_role() in ('producer','engineer') and exists(select 1 from public.project_staff where project_id=target and user_id=auth.uid())))$$;
revoke all on function public.studio_role(),public.can_work_project(uuid) from public,anon;
grant execute on function public.studio_role(),public.can_work_project(uuid) to authenticated,service_role;
-- Preserve owner policies; add explicit manager operations, without identity or staff grants.
create policy "Managers read bookings" on public.bookings for select to authenticated using((select public.studio_role())='manager');
-- Managers change bookings/payment quotes through checked server routes; owners retain their original policy.
-- Managers mutate calendar blocks only through the validated workflow API.
create policy "Managers read reservations" on public.studio_reservations for select to authenticated using((select public.studio_role())='manager');
create policy "Managers read services" on public.services for select to authenticated using((select public.studio_role())='manager');
create policy "Managers insert services" on public.services for insert to authenticated with check((select public.studio_role())='manager');
create policy "Managers update services" on public.services for update to authenticated using((select public.studio_role())='manager') with check((select public.studio_role())='manager');
create policy "Managers delete services" on public.services for delete to authenticated using((select public.studio_role())='manager');
create policy "Managers read portfolio" on public.projects for select to authenticated using((select public.studio_role())='manager');
create policy "Managers insert portfolio" on public.projects for insert to authenticated with check((select public.studio_role())='manager');
create policy "Managers update portfolio" on public.projects for update to authenticated using((select public.studio_role())='manager') with check((select public.studio_role())='manager');
create policy "Managers delete portfolio" on public.projects for delete to authenticated using((select public.studio_role())='manager');
create policy "Managers edit experience" on public.studio_experience for update to authenticated using((select public.studio_role())='manager') with check((select public.studio_role())='manager');
create policy "Managers read testimonials" on public.studio_testimonials for select to authenticated using((select public.studio_role())='manager');
create policy "Managers insert testimonials" on public.studio_testimonials for insert to authenticated with check((select public.studio_role())='manager');
create policy "Managers update testimonials" on public.studio_testimonials for update to authenticated using((select public.studio_role())='manager') with check((select public.studio_role())='manager');
create policy "Managers delete testimonials" on public.studio_testimonials for delete to authenticated using((select public.studio_role())='manager');
create policy "Assigned staff read client projects" on public.client_projects for select to authenticated using(public.can_work_project(id));
-- Child policies query client_projects under its ownership / assignment policy.
create policy "Assigned staff read updates" on public.client_updates for select to authenticated using(public.can_work_project(project_id));
create policy "Assigned staff read files" on public.client_files for select to authenticated using(public.can_work_project(project_id));
create policy "Assigned staff read feedback" on public.client_feedback for select to authenticated using(public.can_work_project(project_id));
create policy "Assigned staff read decisions" on public.client_decisions for select to authenticated using(public.can_work_project(project_id));
create policy "Assigned staff upload deliverables" on storage.objects for insert to authenticated with check(bucket_id='studio-deliverables' and exists(select 1 from public.client_projects p where p.id::text=(storage.foldername(name))[1] and public.can_work_project(p.id)));
create policy "Assigned staff read deliverables" on storage.objects for select to authenticated using(bucket_id='studio-deliverables' and exists(select 1 from public.client_projects p where p.id::text=(storage.foldername(name))[1] and public.can_work_project(p.id)));
create policy "Assigned staff remove deliverables" on storage.objects for delete to authenticated using(bucket_id='studio-deliverables' and exists(select 1 from public.client_projects p where p.id::text=(storage.foldername(name))[1] and public.can_work_project(p.id)));
alter table public.site_settings add column logo_url text not null default '';
alter table public.site_settings add column hero_image text not null default '/images/studio.jpg';
alter table public.site_settings add column hero_image_alt text not null default 'Reference photography of a recording studio mixing console';
alter table public.site_settings add column hero_is_reference boolean not null default true;
alter table public.site_settings add column seo_title text not null default 'KTEXAS Studio — Sound. Vision. Feeling.';
alter table public.site_settings add column seo_description text not null default 'Music production, recording, mixing and mastering, and cinematic video production. Make something that moves people.';
alter table public.client_projects add column email_notifications boolean not null default true;
create table public.project_documents(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.client_projects(id) on delete cascade,title text not null check(length(title) between 1 and 180),content jsonb not null check(jsonb_typeof(content)='object'),published boolean not null default false,created_at timestamptz not null default now(),published_at timestamptz);
create index documents_project_idx on public.project_documents(project_id,created_at desc);
alter table public.project_documents enable row level security;
revoke all on public.project_documents from anon,authenticated;
grant select on public.project_documents to authenticated;
grant all on public.project_documents to service_role;
create policy "Staff read assigned documents" on public.project_documents for select to authenticated using(public.can_work_project(project_id));
create policy "Clients read published documents" on public.project_documents for select to authenticated using(published and exists(select 1 from public.client_projects p where p.id=project_id and p.client_user_id=(select auth.uid())));
alter table public.notification_outbox add column project_id uuid references public.client_projects(id) on delete set null;
create index outbox_project_idx on public.notification_outbox(project_id);
alter table public.notification_outbox drop constraint notification_outbox_kind_check;
alter table public.notification_outbox add constraint notification_outbox_kind_check check(kind in ('received','confirmed','reminder','deposit','file_ready','revision_ready','proposal_ready'));
alter table public.notification_outbox drop constraint notification_outbox_status_check;
alter table public.notification_outbox add constraint notification_outbox_status_check check(status in ('queued','processing','sent','failed','cancelled'));
commit;
