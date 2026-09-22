do $$ begin
            if not exists (select from pg_roles where rolname='anon')
              then create role anon nologin; end if;
            if not exists (select from pg_roles where rolname='authenticated')
              then create role authenticated nologin; end if;
            if not exists (select from pg_roles where rolname='service_role')
              then create role service_role nologin; end if;
          end $$;
          create schema if not exists auth;
          create table if not exists auth.users (
            id uuid primary key,
            email text,
            encrypted_password text,
            email_confirmed_at timestamptz,
            last_sign_in_at timestamptz,
            created_at timestamptz default now(),
            updated_at timestamptz default now(),
            raw_user_meta_data jsonb default '{}'::jsonb
          );
          create or replace function auth.uid() returns uuid language sql stable as
          $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
          create schema if not exists storage;
          create table if not exists storage.buckets (
            id text primary key, name text, public boolean default false,
            file_size_limit bigint, allowed_mime_types text[]
          );
          create table if not exists storage.objects (
            id uuid primary key default gen_random_uuid(),
            bucket_id text references storage.buckets(id),
            name text, owner uuid, user_id text, metadata jsonb,
            created_at timestamptz default now(), updated_at timestamptz default now()
          );
          create or replace function storage.foldername(name text)
          returns text[] language sql immutable as
          $$ select string_to_array(name, '/') $$;
          create table if not exists auth.sessions (
            id uuid primary key default gen_random_uuid(),
            user_id uuid not null,
            created_at timestamptz default now()
          );
          create table if not exists auth.refresh_tokens (
            id bigserial primary key,
            user_id uuid not null,
            token text,
            created_at timestamptz default now()
          );
          grant usage on schema public, storage, auth to anon, authenticated;
          grant select, insert, update, delete on all tables in schema public
            to anon, authenticated;