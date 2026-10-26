-- =====================================================================
-- Spice Route: owner-editable menu upgrade.
-- Run ONCE in Supabase > SQL Editor, AFTER supabase-setup.sql. Safe to run again.
-- No passwords or keys. Row Level Security stays on: visitors still cannot read any table directly.
-- =====================================================================

-- 1. Extra columns so the owner can manage the whole menu
alter table public.menu_items add column if not exists category    text;
alter table public.menu_items add column if not exists description text;
alter table public.menu_items add column if not exists veg         boolean not null default true;
alter table public.menu_items add column if not exists image_url   text;

alter table public.menu_items drop constraint if exists menu_items_extra_chk;
alter table public.menu_items add constraint menu_items_extra_chk check (
  (category is null or char_length(category) between 1 and 40)
  and (description is null or char_length(description) <= 200)
  and (image_url is null or (char_length(image_url) <= 500 and image_url ~ '^(https://|images/)'))
);

-- 2. The starter dishes that are not vegetarian
update public.menu_items set veg = false where id in (3,4,9,10,11,12,13,14,22,25);

-- 3. New dishes get their own ids (starting at 1000, above the starter menu)
create sequence if not exists public.menu_items_id_seq start 1000;
alter table public.menu_items alter column id set default nextval('public.menu_items_id_seq');
grant usage on sequence public.menu_items_id_seq to authenticated;

-- 4. The public menu: the ONLY way visitors can read menu data (no private data is included)
create or replace function public.get_menu()
returns table (id int, name text, category text, description text, price numeric, veg boolean, image_url text, available boolean)
language sql stable security definer set search_path = ''
as $$
  select m.id, m.name, m.category, m.description, m.price, m.veg, m.image_url, m.available
  from public.menu_items m
  order by m.id
$$;
revoke all on function public.get_menu() from public, anon, authenticated;
grant execute on function public.get_menu() to anon, authenticated;

-- Owner permissions on menu_items (select/insert/update/delete only for the registered owner) already come from
-- supabase-setup.sql: grants to "authenticated" plus the policy menu_owner_all that requires is_owner().
-- place_order keeps using the prices stored here, so a price you change is the price customers are charged.
