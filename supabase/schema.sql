-- Run in Supabase SQL Editor once, in a new project.
create extension if not exists pgcrypto;
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default '',
 invite_code text not null unique default encode(gen_random_bytes(12),'hex'),
 partner_id uuid unique references public.profiles(id),
 created_at timestamptz not null default now()
);
create table public.diaries (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 title text not null, content text not null default '', created_at timestamptz not null default now()
);
create table public.moods (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 day date not null, emoji text not null, unique(user_id,day)
);
create table public.messages (
 id uuid primary key default gen_random_uuid(), author_id uuid not null references auth.users(id) on delete cascade,
 content text not null, created_at timestamptz not null default now()
);
create table public.memories (
 id uuid primary key default gen_random_uuid(), author_id uuid not null references auth.users(id) on delete cascade,
 title text not null, content text not null default '', image_path text,
 created_at timestamptz not null default now()
);
-- Private helper avoids recursive RLS and resolves the one approved friend.
create function public.my_partner() returns uuid language sql stable security definer set search_path='' as $$
 select partner_id from public.profiles where id=(select auth.uid())
$$;
revoke all on function public.my_partner() from public;
grant execute on function public.my_partner() to authenticated;
create function public.is_paired() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profiles p join public.profiles q on q.id=p.partner_id and q.partner_id=p.id where p.id=(select auth.uid()))
$$;
revoke all on function public.is_paired() from public;
grant execute on function public.is_paired() to authenticated;
create function public.create_profile() returns trigger language plpgsql security definer set search_path='' as $$
begin insert into public.profiles(id) values(new.id);return new;end;$$;
create trigger new_user_profile after insert on auth.users for each row execute function public.create_profile();
-- Pairing is atomic. It requires both users to be unpaired and disallows self-pairing.
create function public.connect_friend(code text) returns void language plpgsql security definer set search_path='' as $$
declare mine uuid := auth.uid(); other uuid;
begin
 if mine is null then raise exception '请先登录'; end if;
 -- Lock the current row, then the target row; serialization is protected by partner checks.
 perform 1 from public.profiles where id=mine for update;
 select id into other from public.profiles where invite_code=code and id<>mine for update;
 if other is null then raise exception '邀请码无效'; end if;
 if (select partner_id from public.profiles where id=mine) is not null or
    (select partner_id from public.profiles where id=other) is not null then
    raise exception '其中一个账号已经连接了好友';
 end if;
 update public.profiles set partner_id=other where id=mine;
 update public.profiles set partner_id=mine where id=other;
end;$$;
revoke all on function public.connect_friend(text) from public;
grant execute on function public.connect_friend(text) to authenticated;
-- User can only change their own nickname. Other columns are not client-writable.
revoke update on public.profiles from authenticated;
grant update(display_name) on public.profiles to authenticated;
alter table public.profiles enable row level security;
create policy "own profile" on public.profiles for select to authenticated using(id=(select auth.uid()));
create policy "update own profile" on public.profiles for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));
alter table public.diaries enable row level security;
create policy "own diary select" on public.diaries for select to authenticated using(user_id=(select auth.uid()));
create policy "own diary insert" on public.diaries for insert to authenticated with check(user_id=(select auth.uid()));
create policy "own diary update" on public.diaries for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy "own diary delete" on public.diaries for delete to authenticated using(user_id=(select auth.uid()));
alter table public.moods enable row level security;
create policy "own mood select" on public.moods for select to authenticated using(user_id=(select auth.uid()));
create policy "own mood insert" on public.moods for insert to authenticated with check(user_id=(select auth.uid()));
create policy "own mood update" on public.moods for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy "own mood delete" on public.moods for delete to authenticated using(user_id=(select auth.uid()));
alter table public.messages enable row level security;
create policy "paired message select" on public.messages for select to authenticated using(public.is_paired() and author_id in ((select auth.uid()),public.my_partner()));
create policy "paired message insert" on public.messages for insert to authenticated with check(public.is_paired() and author_id=(select auth.uid()));
create policy "own message delete" on public.messages for delete to authenticated using(author_id=(select auth.uid()));
alter table public.memories enable row level security;
create policy "paired memory select" on public.memories for select to authenticated using(public.is_paired() and author_id in ((select auth.uid()),public.my_partner()));
create policy "paired memory insert" on public.memories for insert to authenticated with check(public.is_paired() and author_id=(select auth.uid()));
create policy "own memory delete" on public.memories for delete to authenticated using(author_id=(select auth.uid()));
-- Private storage bucket, accessed by signed URLs. Uploaded files live under user-id/uuid.ext.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('memory-photos','memory-photos',false,5242880,array['image/jpeg','image/png','image/webp','image/gif'])
on conflict(id) do nothing;
create policy "paired upload own folder" on storage.objects for insert to authenticated
 with check(bucket_id='memory-photos' and public.is_paired() and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "paired read photos" on storage.objects for select to authenticated
 using(bucket_id='memory-photos' and public.is_paired() and (storage.foldername(name))[1] in ((select auth.uid())::text,public.my_partner()::text));
create policy "delete own photos" on storage.objects for delete to authenticated
 using(bucket_id='memory-photos' and (storage.foldername(name))[1]=(select auth.uid())::text);
