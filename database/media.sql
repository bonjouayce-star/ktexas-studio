-- Apply after launch.sql. Public library is separate from private deliverables.
begin;
alter table public.projects add column if not exists gallery jsonb not null default '[]'::jsonb;
alter table public.projects add constraint projects_gallery_array check(jsonb_typeof(gallery)='array' and jsonb_array_length(gallery)<=30);
create table public.studio_media(id uuid primary key default gen_random_uuid(),storage_path text not null unique,name text not null check(length(name) between 1 and 200),kind text not null check(kind in ('image','audio','video')),mime_type text not null,size_bytes bigint not null check(size_bytes between 1 and 52428800),uploaded_by uuid references auth.users(id) on delete set null,created_at timestamptz not null default now());
alter table public.studio_media enable row level security;
revoke all on public.studio_media from anon,authenticated;
grant select on public.studio_media to authenticated;
grant all on public.studio_media to service_role;
create policy "Media staff read library" on public.studio_media for select to authenticated using((select public.studio_role()) in ('owner','manager','producer'));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('studio-public-media','studio-public-media',true,52428800,array['image/jpeg','image/png','image/webp','image/gif','audio/mpeg','audio/mp3','audio/wav','audio/x-wav','audio/ogg','audio/flac','audio/mp4','audio/aac','video/mp4','video/webm','video/quicktime']);
create policy "Media staff upload public assets" on storage.objects for insert to authenticated with check(bucket_id='studio-public-media' and (select public.studio_role()) in ('owner','manager','producer') and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "Media staff read public assets" on storage.objects for select to authenticated using(bucket_id='studio-public-media' and (select public.studio_role()) in ('owner','manager','producer'));
create policy "Media staff clean own unregistered uploads" on storage.objects for delete to authenticated using(bucket_id='studio-public-media' and (select public.studio_role()) in ('owner','manager','producer') and (storage.foldername(name))[1]=(select auth.uid())::text and not exists(select 1 from public.studio_media where storage_path=storage.objects.name));
create policy "Producers read portfolio" on public.projects for select to authenticated using((select public.studio_role())='producer');
create policy "Producers insert portfolio" on public.projects for insert to authenticated with check((select public.studio_role())='producer');
create policy "Producers update portfolio" on public.projects for update to authenticated using((select public.studio_role())='producer') with check((select public.studio_role())='producer');
create policy "Producers delete portfolio" on public.projects for delete to authenticated using((select public.studio_role())='producer');
-- Server-only atomic JSON merge: producers may update audio, never packages/settings.
create function public.studio_save_audio(patch jsonb) returns void language sql security invoker set search_path='' as $$update public.studio_experience set content=content || patch where id=1$$;
revoke all on function public.studio_save_audio(jsonb) from public,anon,authenticated;
grant execute on function public.studio_save_audio(jsonb) to service_role;
commit;
