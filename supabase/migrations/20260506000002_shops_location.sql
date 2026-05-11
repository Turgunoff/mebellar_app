-- Add geolocation columns to shops table for seller onboarding map integration.
ALTER TABLE public.shops
  ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
