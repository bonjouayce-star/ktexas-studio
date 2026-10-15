-- For studio databases that already ran the earlier launch.sql.
-- Fresh installs use the corrected launch.sql and do not need this patch.
begin;
drop policy if exists "Managers insert reservations" on public.studio_reservations;
drop policy if exists "Managers update reservations" on public.studio_reservations;
drop policy if exists "Managers delete reservations" on public.studio_reservations;
commit;
