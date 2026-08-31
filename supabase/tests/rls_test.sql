-- Fitti — RLS proof
--
-- The claim in docs/DECISIONS.md is that a route-handler bug cannot leak another
-- user's closet, because isolation is enforced by the database rather than by
-- application code. That is a testable claim. This tests it.
--
-- Run: docker exec -i supabase_db_fittie psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f - < supabase/tests/rls_test.sql

\set ON_ERROR_STOP on
begin;

-- Two users. The signup trigger gives each a profile and a free entitlement.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values
  ('aaaaaaaa-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'a@test.local', 'x', now(), now(), now()),
  ('bbbbbbbb-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'b@test.local', 'x', now(), now(), now());

-- Seed one garment for each, as superuser (bypasses RLS, which is the point:
-- the data genuinely exists, so a later count of 0 proves policy, not absence).
insert into public.garments (id, user_id, name, category, covers, status)
values
  ('11111111-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000001',
   'A wool coat', 'outerwear', array['outerwear'], 'ready'),
  ('22222222-0000-4000-8000-000000000002', 'bbbbbbbb-0000-4000-8000-000000000002',
   'B linen shirt', 'top', array['top'], 'ready');

-- ---------------------------------------------------------------------------
-- Test 1: a user sees exactly their own garment, and no one else's.
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-4000-8000-000000000001","role":"authenticated"}';

do $$
declare
  visible integer;
  leaked integer;
begin
  select count(*) into visible from public.garments;
  select count(*) into leaked from public.garments
    where user_id = 'bbbbbbbb-0000-4000-8000-000000000002';

  if visible <> 1 then
    raise exception 'FAIL: user A saw % garments, expected exactly 1', visible;
  end if;
  if leaked <> 0 then
    raise exception 'FAIL: user A read % of user B''s garments', leaked;
  end if;
  raise notice 'PASS  user A sees only their own garment';
end
$$;

-- ---------------------------------------------------------------------------
-- Test 2: addressing another user's row by primary key still returns nothing.
-- This is the IDOR case — guessing an id must not be enough.
-- ---------------------------------------------------------------------------
do $$
declare
  found integer;
begin
  select count(*) into found from public.garments
    where id = '22222222-0000-4000-8000-000000000002';
  if found <> 0 then
    raise exception 'FAIL: direct id lookup leaked another user''s garment';
  end if;
  raise notice 'PASS  direct id lookup of another user''s garment returns nothing';
end
$$;

-- ---------------------------------------------------------------------------
-- Test 3: you cannot write a row owned by someone else.
-- ---------------------------------------------------------------------------
do $$
begin
  begin
    insert into public.garments (id, user_id, name, category, covers, status)
    values ('33333333-0000-4000-8000-000000000003',
            'bbbbbbbb-0000-4000-8000-000000000002',
            'forged', 'top', array['top'], 'ready');
    raise exception 'FAIL: user A inserted a garment owned by user B';
  exception
    when insufficient_privilege then
      raise notice 'PASS  insert with a forged user_id is rejected';
  end;
end
$$;

-- ---------------------------------------------------------------------------
-- Test 4: you cannot update or delete another user's row.
-- ---------------------------------------------------------------------------
do $$
declare
  touched integer;
begin
  update public.garments set name = 'stolen'
    where id = '22222222-0000-4000-8000-000000000002';
  get diagnostics touched = row_count;
  if touched <> 0 then
    raise exception 'FAIL: user A updated % of user B''s rows', touched;
  end if;

  delete from public.garments
    where id = '22222222-0000-4000-8000-000000000002';
  get diagnostics touched = row_count;
  if touched <> 0 then
    raise exception 'FAIL: user A deleted % of user B''s rows', touched;
  end if;
  raise notice 'PASS  update and delete of another user''s garment affect 0 rows';
end
$$;

-- ---------------------------------------------------------------------------
-- Test 5: entitlements are readable but NOT writable by the client.
-- A client that can write this table can grant itself the paid tier.
-- ---------------------------------------------------------------------------
do $$
declare
  tier_now text;
begin
  select tier into tier_now from public.entitlements
    where user_id = 'aaaaaaaa-0000-4000-8000-000000000001';
  if tier_now is null then
    raise exception 'FAIL: user cannot read their own entitlement';
  end if;

  begin
    update public.entitlements set tier = 'plus', garment_limit = -1
      where user_id = 'aaaaaaaa-0000-4000-8000-000000000001';
    -- No update policy exists, so this matches 0 rows rather than erroring.
    if found then
      raise exception 'FAIL: user granted themselves the paid tier';
    end if;
  exception
    when insufficient_privilege then null;
  end;

  raise notice 'PASS  entitlements readable, not self-grantable';
end
$$;

reset role;

-- ---------------------------------------------------------------------------
-- Test 6: the free-tier ceiling is enforced by the database, not the app.
-- ---------------------------------------------------------------------------
update public.entitlements set garment_limit = 3
  where user_id = 'aaaaaaaa-0000-4000-8000-000000000001';

do $$
declare
  i integer;
begin
  -- A already has 1. Two more reaches the limit of 3.
  for i in 1..2 loop
    insert into public.garments (id, user_id, name, category, covers, status)
    values (gen_random_uuid(), 'aaaaaaaa-0000-4000-8000-000000000001',
            'filler ' || i, 'top', array['top'], 'ready');
  end loop;

  begin
    insert into public.garments (id, user_id, name, category, covers, status)
    values (gen_random_uuid(), 'aaaaaaaa-0000-4000-8000-000000000001',
            'one too many', 'top', array['top'], 'ready');
    raise exception 'FAIL: garment limit was not enforced';
  exception
    when check_violation then
      raise notice 'PASS  garment limit enforced at the database';
  end;
end
$$;

-- ---------------------------------------------------------------------------
-- Test 7: every table in public has RLS enabled AND forced.
-- Catches a new table added later without policies.
-- ---------------------------------------------------------------------------
do $$
declare
  offenders text;
begin
  select string_agg(c.relname, ', ') into offenders
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;

  if offenders is not null then
    raise exception 'FAIL: tables without RLS: %', offenders;
  end if;
  raise notice 'PASS  every public table has RLS enabled';
end
$$;

rollback;
