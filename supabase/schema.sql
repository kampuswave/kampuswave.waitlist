-- =====================================================================
-- KampusWave waitlist  ·  Supabase schema + Row Level Security
-- Paste this whole file into: Supabase Dashboard → SQL Editor → New query → Run
-- Safe to run once on a fresh project. (It does NOT drop anything.)
-- =====================================================================

-- ---------- 1. Table ----------------------------------------------------
create table public.waitlist_signups (
  id          uuid        primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),

  -- Set by the database, never by the browser (see grants below)
  campus         text not null default 'LASUED' check (campus = 'LASUED'),
  policy_version text not null default '2026-10-14',   -- Privacy Policy / Terms "Last updated" date the person saw

  -- Form: Full name (required)
  full_name text not null
    check (char_length(btrim(full_name)) between 2 and 100),

  -- Form: WhatsApp number (required) – same pattern as the form's own rule
  whatsapp text not null
    check (whatsapp ~ '^\+?[\d\s()-]{10,16}$'),

  -- Form: Email (optional)
  email text
    check (email is null or (char_length(email) <= 254
                             and email ~ '^[^\s@]+@[^\s@]+\.[^\s@]+$')),

  -- Form: Preferred location (required) + "Other" free text (conditional)
  location text not null
    check (location in ('Hostel','Lecture area','Library','Student centre','Other')),
  location_other text
    check (location_other is null or char_length(location_other) <= 100),

  -- Form: Monthly data spending (required): ONE chip OR a custom naira amount
  monthly_spend text
    check (monthly_spend in ('under_2000','2000_3000','3000_5000','over_5000')),
  monthly_spend_custom_naira integer
    check (monthly_spend_custom_naira between 0 and 9999999),

  -- Form: Interest in ₦4,999/month (required) + affordable amount (conditional)
  interest_at_4999 text not null
    check (interest_at_4999 in ('yes','maybe','no_can_afford_data','too_expensive')),
  affordable_monthly_naira integer
    check (affordable_monthly_naira between 0 and 9999999),

  -- Form: Number of devices (required)
  devices text not null
    check (devices in ('one','two','three_plus')),

  -- Form: "Do you have a question?" (optional) + question text (conditional)
  has_question boolean,
  question text
    check (question is null or char_length(question) between 1 and 500),

  -- Form: consent checkbox (required, must be true to be saved)
  consent boolean not null
    check (consent is true),

  -- Cross-field rules (the form enforces these in JS; the database enforces them again)
  constraint location_other_matches_location check (
    (location = 'Other' and location_other is not null and char_length(btrim(location_other)) >= 1)
    or (location <> 'Other' and location_other is null)
  ),
  constraint exactly_one_spend_answer check (
    num_nonnulls(monthly_spend, monthly_spend_custom_naira) = 1
  ),
  constraint afford_only_when_too_expensive check (
    (interest_at_4999 = 'too_expensive') = (affordable_monthly_naira is not null)
  ),
  constraint question_only_when_asked check (
    question is null or has_question is true
  )
);

comment on table public.waitlist_signups is
  'KampusWave pre-launch waitlist. Contains personal data (name, phone, email). Insert-only for the public site; readable only via the Supabase dashboard / service role.';

-- One signup per phone number. Compares the last 10 digits, so
-- 0803 000 0000, +234 803 000 0000 and 2348030000000 count as the same number.
create unique index waitlist_signups_whatsapp_unique
  on public.waitlist_signups (right(regexp_replace(whatsapp, '\D', '', 'g'), 10));

-- ---------- 2. Row Level Security --------------------------------------
alter table public.waitlist_signups enable row level security;

-- Start from zero access, then grant back only what the website needs.
revoke all on table public.waitlist_signups from public, anon, authenticated;

-- The public website (anon role) may INSERT, and only into these columns.
-- It cannot set id / created_at / campus / policy_version, and cannot SELECT, UPDATE or DELETE.
grant insert (
  full_name, whatsapp, email,
  location, location_other,
  monthly_spend, monthly_spend_custom_naira,
  interest_at_4999, affordable_monthly_naira,
  devices, has_question, question,
  consent
) on public.waitlist_signups to anon;

create policy "Public can submit a waitlist signup"
  on public.waitlist_signups
  for insert
  to anon
  with check (consent is true);

-- Deliberately NO select / update / delete policies:
-- the public cannot read, change or delete anyone's submission.
-- You read the data in Dashboard → Table Editor (uses your admin access).
