-- Add pending-seller flag so the customer profile screen can show the
-- "under review" state without a separate sellers join.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_seller_pending BOOLEAN NOT NULL DEFAULT false;

-- Allow an authenticated user to insert their own seller row.
DO $$ BEGIN
  CREATE POLICY "sellers_insert_own" ON public.sellers
    FOR INSERT WITH CHECK (auth.uid() = id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Allow a seller to read their own row.
DO $$ BEGIN
  CREATE POLICY "sellers_select_own" ON public.sellers
    FOR SELECT USING (auth.uid() = id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Allow a seller to update their own row (needed for upsert / re-submission).
DO $$ BEGIN
  CREATE POLICY "sellers_update_own" ON public.sellers
    FOR UPDATE USING (auth.uid() = id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Allow a seller to insert their own shop (seller_id = auth.uid() because
-- sellers.id is the same UUID as the auth user).
DO $$ BEGIN
  CREATE POLICY "shops_insert_own" ON public.shops
    FOR INSERT WITH CHECK (auth.uid() = seller_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Allow a seller to read and update their own shop (needed for upsert).
DO $$ BEGIN
  CREATE POLICY "shops_select_own" ON public.shops
    FOR SELECT USING (auth.uid() = seller_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "shops_update_own" ON public.shops
    FOR UPDATE USING (auth.uid() = seller_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
