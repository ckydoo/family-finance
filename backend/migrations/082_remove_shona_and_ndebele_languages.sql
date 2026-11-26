-- 082: Remove Shona (sn) and Ndebele (nd) from supported user_profile languages.
-- Normalizes any existing profile rows to 'en' and updates the language CHECK
-- constraint to the four shipped app locales: ('en', 'es', 'fr', 'pt').
-- Idempotent - safe to re-run.

UPDATE public.user_profile
SET language = 'en'
WHERE language IS NULL OR language NOT IN ('en', 'es', 'fr', 'pt');

DO $$
DECLARE c text;
BEGIN
  FOR c IN
    SELECT conname
      FROM pg_constraint
     WHERE conrelid = 'public.user_profile'::regclass
       AND contype = 'c'
       AND pg_get_constraintdef(oid) ILIKE '%language%'
  LOOP
    EXECUTE format('ALTER TABLE public.user_profile DROP CONSTRAINT %I', c);
  END LOOP;

  ALTER TABLE public.user_profile
    ADD CONSTRAINT user_profile_language_check
    CHECK (language IN ('en', 'es', 'fr', 'pt'));
END $$;
