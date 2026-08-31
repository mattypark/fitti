-- Fitti — row level security
--
-- Deny by default, owner-only, on every table in public. No table ships without
-- policies: this is photographs of people's bedrooms, and RLS is enforced inside
-- the database, so a bug in a route handler cannot leak someone else's closet.
--
-- Two details that matter and are easy to get wrong:
--
--   (select auth.uid())  is evaluated once per statement. A bare auth.uid() is
--                        re-evaluated once per ROW, which turns a closet scan
--                        into thousands of function calls.
--   to authenticated     keeps the anon role out of the policy entirely rather
--                        than relying on the predicate to fail for it.

-- ---------------------------------------------------------------------------
-- The uniform case: "you may touch a row if you own it."
--
-- Generated in a loop rather than written out thirteen times. Copy-paste is how
-- one table quietly ends up with `using (true)` on its update policy — the loop
-- makes it impossible for the predicate to drift between tables, and the policy
-- names come out identical to the hand-written ones.
-- ---------------------------------------------------------------------------
do $$
declare
  target text;
  owner_tables text[] := array[
    'garments', 'garment_assets', 'garment_embeddings', 'outfits', 'wears',
    'style_context', 'feed_requests', 'events', 'ai_usage', 'ingest_jobs'
  ];
begin
  foreach target in array owner_tables loop
    execute format('alter table public.%I enable row level security', target);
    -- Force RLS to apply to the table owner too. Without this, anything
    -- connecting as the owning role silently bypasses every policy below.
    execute format('alter table public.%I force row level security', target);

    execute format('drop policy if exists %I on public.%I', target || '_select_own', target);
    execute format($f$create policy %I on public.%I
                       for select to authenticated
                       using ((select auth.uid()) = user_id)$f$,
                   target || '_select_own', target);

    execute format('drop policy if exists %I on public.%I', target || '_insert_own', target);
    execute format($f$create policy %I on public.%I
                       for insert to authenticated
                       with check ((select auth.uid()) = user_id)$f$,
                   target || '_insert_own', target);

    execute format('drop policy if exists %I on public.%I', target || '_update_own', target);
    execute format($f$create policy %I on public.%I
                       for update to authenticated
                       using ((select auth.uid()) = user_id)
                       with check ((select auth.uid()) = user_id)$f$,
                   target || '_update_own', target);

    execute format('drop policy if exists %I on public.%I', target || '_delete_own', target);
    execute format($f$create policy %I on public.%I
                       for delete to authenticated
                       using ((select auth.uid()) = user_id)$f$,
                   target || '_delete_own', target);
  end loop;
end
$$;

-- ---------------------------------------------------------------------------
-- profiles — keyed on id, not user_id, so it does not fit the loop above.
-- No delete policy: profiles die with the auth user via ON DELETE CASCADE.
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.profiles force row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert to authenticated with check ((select auth.uid()) = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- ---------------------------------------------------------------------------
-- outfit_items — no user_id of its own; ownership is inherited through outfits.
--
-- The subquery is why outfits.id is indexed as a primary key: this runs on every
-- row touched, and an unindexed inherited check is the classic RLS performance
-- cliff.
-- ---------------------------------------------------------------------------
alter table public.outfit_items enable row level security;
alter table public.outfit_items force row level security;

drop policy if exists "outfit_items_own" on public.outfit_items;
create policy "outfit_items_own" on public.outfit_items
  for all to authenticated
  using (
    exists (
      select 1 from public.outfits o
      where o.id = outfit_id and o.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.outfits o
      where o.id = outfit_id and o.user_id = (select auth.uid())
    )
  );

-- ---------------------------------------------------------------------------
-- entitlements — readable by its owner, writable by NOBODY.
--
-- There is no insert or update policy on purpose. Entitlements are written only
-- by the server after verifying a StoreKit transaction with Apple, using the
-- service-role client which bypasses RLS. A client that could write this table
-- could grant itself the paid tier.
-- ---------------------------------------------------------------------------
alter table public.entitlements enable row level security;
alter table public.entitlements force row level security;

drop policy if exists "entitlements_select_own" on public.entitlements;
create policy "entitlements_select_own" on public.entitlements
  for select to authenticated using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- catalog — the shopping inventory. Not user data: every signed-in user sees the
-- same rows. Read-only to clients; feeds are ingested server-side.
-- ---------------------------------------------------------------------------
alter table public.catalog_items enable row level security;
alter table public.catalog_embeddings enable row level security;

drop policy if exists "catalog_items_read" on public.catalog_items;
create policy "catalog_items_read" on public.catalog_items
  for select to authenticated using (true);

drop policy if exists "catalog_embeddings_read" on public.catalog_embeddings;
create policy "catalog_embeddings_read" on public.catalog_embeddings
  for select to authenticated using (true);

-- ---------------------------------------------------------------------------
-- Enforce the free-tier ceiling in the database.
--
-- The 25-garment limit is checked here rather than only in a route handler,
-- because the iOS app, the share extension, the email ingester, and the bulk
-- importer are four separate write paths and every one of them would otherwise
-- need to remember. A trigger cannot be forgotten.
-- ---------------------------------------------------------------------------
create or replace function public.enforce_garment_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  allowed integer;
  current_count integer;
begin
  select garment_limit into allowed
    from public.entitlements where user_id = new.user_id;

  -- No entitlement row yet: the signup trigger will create one. Let it through
  -- rather than blocking a brand-new user's very first garment.
  if allowed is null then
    return new;
  end if;

  -- 'plus' carries a sentinel of -1 for unlimited.
  if allowed < 0 then
    return new;
  end if;

  select count(*) into current_count
    from public.garments
    where user_id = new.user_id and deleted_at is null;

  if current_count >= allowed then
    raise exception 'garment_limit_reached'
      using hint = 'Free plan holds 25 pieces. Upgrade for unlimited.',
            errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists garments_enforce_limit on public.garments;
create trigger garments_enforce_limit
  before insert on public.garments
  for each row execute function public.enforce_garment_limit();
