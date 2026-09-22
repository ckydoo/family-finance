-- 003: Email auth + live-schema reconciliation (2026-09-22)
-- Run once in the Supabase SQL editor. Idempotent — safe to re-run.
--
-- Reconciles the deployed schema (see supabase_live_schema.sql) with the app:
--   1. user_profile.email  — email+password auth replaced phone OTP
--   2. user_profile.language — app ships 6 locales (en,es,fr,pt,sn,nd);
--      deployed CHECK only allows (en,sn,nd)
--   3. transaction.method / recurring_rule.method — the app uses ONE method
--      enum for both tables; deployed CHECKs are disjoint subsets, so a
--      mobile-money expense (or an EcoCash bill rule) would fail to sync.
--      Both widen to the union domain.

-- 1a. user_profile.email (+ backfill from auth.users)
ALTER TABLE public.user_profile ADD COLUMN IF NOT EXISTS email text UNIQUE;

UPDATE public.user_profile p
SET email = u.email
FROM auth.users u
WHERE p.id = u.id AND p.email IS NULL;

CREATE INDEX IF NOT EXISTS user_profile_email_idx ON public.user_profile (email);

-- 1b. widen language CHECK to all six app locales (dynamic find & replace)
DO $$
DECLARE c text;
BEGIN
  SELECT conname INTO c FROM pg_constraint
   WHERE conrelid = 'public.user_profile'::regclass AND contype = 'c'
     AND pg_get_constraintdef(oid) ILIKE '%language%';
  IF c IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.user_profile DROP CONSTRAINT %I', c);
  END IF;
  ALTER TABLE public.user_profile ADD CONSTRAINT user_profile_language_check
    CHECK (language IN ('en','es','fr','pt','sn','nd'));
END $$;

-- 2. transaction.method → union domain
DO $$
DECLARE c text;
BEGIN
  SELECT conname INTO c FROM pg_constraint
   WHERE conrelid = 'public.transaction'::regclass AND contype = 'c'
     AND pg_get_constraintdef(oid) ILIKE '%method%';
  IF c IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.transaction DROP CONSTRAINT %I', c);
  END IF;
  ALTER TABLE public.transaction ADD CONSTRAINT transaction_method_wide_check
    CHECK (method IN ('cash','ecocash','mobile_money','bank_card',
                      'bank_transfer','zipit','innbucks','agent','other'));
END $$;

-- 3. recurring_rule.method → same union domain
DO $$
DECLARE c text;
BEGIN
  SELECT conname INTO c FROM pg_constraint
   WHERE conrelid = 'public.recurring_rule'::regclass AND contype = 'c'
     AND pg_get_constraintdef(oid) ILIKE '%method%';
  IF c IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.recurring_rule DROP CONSTRAINT %I', c);
  END IF;
  ALTER TABLE public.recurring_rule ADD CONSTRAINT recurring_rule_method_wide_check
    CHECK (method IN ('cash','ecocash','mobile_money','bank_card',
                      'bank_transfer','zipit','innbucks','agent','other'));
END $$;
