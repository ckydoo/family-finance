# Mhuri Hub — Privacy Policy

**Effective: 2026-09-23 · App: Mhuri Hub (Android/iOS) · Backend: Supabase**

Mhuri Hub is a family money manager: budgets, savings goals, shopping lists,
bills and a children's mode. This policy states exactly what the app collects,
where it lives, and how it is removed — in plain language.

## What we collect

| Data | Why | Where it lives |
|---|---|---|
| **Email + password** | Your sign-in. Passwords are stored only as salted hashes by Supabase Auth — never readable by us. | Supabase Auth |
| **Preferred name** | Shown to your family members. | Postgres `user_profile` |
| **Profile photo (optional)** | So family members recognise each other. | Supabase Storage (private bucket) |
| **Family financial content** | Envelopes, transactions, savings goals, shopping lists, bills, recurring rules, invite codes, activity-log entries. This is the app's core data. | Postgres, scoped to your family space |
| **Kid profiles** | A display name, an emoji avatar and permission switches. Kids sign in **on a parent's device with a profile PIN** — we do not collect kids' emails, phone numbers or any other identifying data. | Postgres, inside your family space |
| **Invite recipient email (optional)** | Only if you send an invite by email; the address is used once to deliver the invite. | Invite record + your mail app |

## What we do NOT collect

- No advertising identifiers, no analytics/tracking SDKs, no ad sales.
- No phone numbers (sign-in is email + password; invites are codes/links).
- No contacts, location or background location.
- No keystrokes or screen recording. Crash reports are **local debug output
  only** today; if a crash-reporting backend is ever added, this policy and
  the store listing will be updated first.

## Who can see family data

Access is enforced by **row-level security in the database itself**, not by
the app: a signed-in member can only read/write rows belonging to the family
space they belong to. Role switches can hide money amounts from kids and
teens. Nobody outside your family space — including other users — can read
your rows. The backup operator (you/the family admin) is the only human with
database-level access, under the family's own control.

## Deleting your data

- **Remove me from the family** (member): you leave the space; your past
  transaction rows remain for the family's records shown as "Former member"
  (no name or photo attached), your sessions are revoked and your email is
  freed for reuse.
- **Delete my account** (sole owner): the whole family space and every
  member's membership is deleted, then your identity and personal details.
  Financial history is retained only per the family's records where the
  family space continues under a new owner.
- Weekly encrypted backups age out of the retention window and are deleted.

## Your choices

- Avatars are optional and removable in Family → your profile.
- Export: request a copy of your family data from the family admin (the
  data lives in the family's own Supabase project — the admin can export at
  any time via `backend/scripts/backup.sh`).

## Contact

Questions or deletion requests: **[family-admin contact email — fill in
before store submission]**.

## Changes

Material changes to this policy ship in the release notes of the app update
that introduces them.
