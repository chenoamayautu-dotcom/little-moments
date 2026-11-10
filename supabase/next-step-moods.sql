-- 仅执行一次：补充心情表，与现有 Supabase 数据库兼容
create table if not exists public.moods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  emoji text not null check (emoji in ('😄','🙂','😐','😔','😫')),
  created_at timestamptz not null default now(),
  unique (user_id, day)
);
alter table public.moods enable row level security;
create policy "Read own moods" on public.moods for select to authenticated using ((select auth.uid()) = user_id);
create policy "Insert own moods" on public.moods for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Update own moods" on public.moods for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Delete own moods" on public.moods for delete to authenticated using ((select auth.uid()) = user_id);
grant select,insert,update,delete on public.moods to authenticated;
revoke all on public.moods from anon;
