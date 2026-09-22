# Mhuri Money — CI

Two gates, both blocking:

1. **migrations** — applies `backend/migrations/*.sql` in lexical order to a
   clean Postgres 16 with the Supabase-compatible helpers auth.uid() etc.
   registered. A migration that only works on an already-mutated database
   fails here.
2. **flutter** — `flutter analyze` (zero issues) + `flutter test` on the app.
