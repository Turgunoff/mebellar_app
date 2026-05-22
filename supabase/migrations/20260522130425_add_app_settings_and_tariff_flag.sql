-- Runtime feature-flag store + tariff master switch.
--
-- The tariff / subscription system is being turned off for the current
-- stage. Rather than hard-code that in the app (which would need a new build
-- to re-enable), the switch lives in the DB: `app_settings.tariff_enabled`.
-- Both the product-quota triggers and the Flutter app gate on it, so one
-- UPDATE flips the whole feature on or off.

create table if not exists public.app_settings (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.app_settings enable row level security;

-- Public read so the app (anon + authenticated) can fetch flags at boot.
-- No write policy: only the service_role / SQL console may change a flag.
drop policy if exists "Public read app_settings" on public.app_settings;
create policy "Public read app_settings"
  on public.app_settings for select using (true);

-- Disabled for now. To re-enable the tariff system later:
--   update public.app_settings set value = 'true', updated_at = now()
--   where key = 'tariff_enabled';
insert into public.app_settings (key, value)
values ('tariff_enabled', 'false'::jsonb)
on conflict (key) do nothing;

-- SECURITY DEFINER so the products INSERT triggers can read the flag
-- regardless of the inserting role. Reads a public-readable table anyway,
-- so this exposes nothing sensitive.
create or replace function public.is_tariff_enabled()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select value::boolean from public.app_settings where key = 'tariff_enabled'),
    false
  );
$$;

grant execute on function public.is_tariff_enabled() to anon, authenticated;

-- Gate both quota triggers on the master switch: when tariff is off they
-- short-circuit, so product creation is unlimited. The rest of each body is
-- unchanged from the original definitions.
create or replace function public.enforce_product_count_limit()
 returns trigger
 language plpgsql
 set search_path to 'public', 'pg_catalog'
as $function$
DECLARE
    v_max INT;
    v_count INT;
    v_plan_code TEXT;
BEGIN
    -- Tariff master switch: when off, skip all quota enforcement.
    IF NOT public.is_tariff_enabled() THEN
        RETURN NEW;
    END IF;

    SELECT p.max_products, p.code
      INTO v_max, v_plan_code
      FROM public.shops s
      JOIN public.subscription_plans p ON p.id = s.plan_id
     WHERE s.id = NEW.shop_id;

    IF v_max IS NULL THEN
        RAISE EXCEPTION 'Shop % does not have a subscription plan', NEW.shop_id
            USING ERRCODE = 'check_violation';
    END IF;

    -- -1 = unlimited
    IF v_max < 0 THEN
        RETURN NEW;
    END IF;

    SELECT COUNT(*) INTO v_count
      FROM public.products
     WHERE shop_id = NEW.shop_id;

    IF v_count >= v_max THEN
        RAISE EXCEPTION
            'Tarif limit: % tarifida maksimum % ta mahsulot (joriy: %)',
            v_plan_code, v_max, v_count
            USING ERRCODE = 'check_violation',
                  HINT = 'Tarifni yangilang yoki mavjud mahsulotni o''chiring';
    END IF;

    RETURN NEW;
END;
$function$;

create or replace function public.enforce_product_image_limit()
 returns trigger
 language plpgsql
 set search_path to 'public', 'pg_catalog'
as $function$
DECLARE
    v_max INT;
    v_count INT;
    v_plan_code TEXT;
BEGIN
    -- Tariff master switch: when off, skip all quota enforcement.
    IF NOT public.is_tariff_enabled() THEN
        RETURN NEW;
    END IF;

    v_count := COALESCE(array_length(NEW.images, 1), 0);
    IF v_count = 0 THEN
        RETURN NEW;
    END IF;

    SELECT p.max_images_per_product, p.code
      INTO v_max, v_plan_code
      FROM public.shops s
      JOIN public.subscription_plans p ON p.id = s.plan_id
     WHERE s.id = NEW.shop_id;

    IF v_max IS NULL THEN
        RAISE EXCEPTION 'Shop % does not have a subscription plan', NEW.shop_id
            USING ERRCODE = 'check_violation';
    END IF;

    -- -1 = unlimited
    IF v_max < 0 THEN
        RETURN NEW;
    END IF;

    IF v_count > v_max THEN
        RAISE EXCEPTION
            'Tarif limit: % tarifida bitta mahsulotga maksimum % ta rasm (yuborilgan: %)',
            v_plan_code, v_max, v_count
            USING ERRCODE = 'check_violation',
                  HINT = 'Tarifni yangilang yoki rasm sonini kamaytiring';
    END IF;

    RETURN NEW;
END;
$function$;
