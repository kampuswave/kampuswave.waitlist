# KampusWave × Supabase — setup guide

## Files

| File | What it is |
|---|---|
| `supabase/schema.sql` | Creates the `waitlist_signups` table, validation rules, and Row Level Security. Run once in Supabase. |
| `supabase-config.js` | **You edit this.** Holds your Project URL and publishable key. |
| `index.html` | Changed: loads supabase-js, and the form now saves to Supabase (see "What changed"). |

Keep `index.html`, `supabase-config.js`, `privacy-policy.html` and `terms-of-use.html` in the same folder. The `supabase/` folder is only for you; you don't need to deploy it.

## Step 1 — Create the project
1. Go to <https://supabase.com/dashboard> → **New project**.
2. Choose a name, a strong database password (save it in a password manager), and the region closest to your students.
3. Wait for it to finish provisioning.

## Step 2 — Create the table and security rules
1. In the dashboard sidebar open **SQL Editor** → **New query**.
2. Open `supabase/schema.sql`, copy **everything**, paste it into the editor.
3. Click **Run**. You should see "Success. No rows returned."
4. Check **Table Editor → waitlist_signups** exists. In **Authentication → Policies**, the table shows RLS enabled with one policy: *Public can submit a waitlist signup*.

Run it only once. If you need to start over: `drop table public.waitlist_signups;` then run the file again.

## Step 3 — Put your keys in the website
1. Dashboard → **Project Settings → API Keys** (older projects: **API**).
2. Copy the **Project URL** and the **Publishable key** (`sb_publishable_…`). If you only see a legacy **anon** key (`eyJ…`), that works too.
3. Edit `supabase-config.js`:
   ```js
   window.KW_SUPABASE = {
     url: "https://abcdxyz.supabase.co",
     key: "sb_publishable_xxxxxxxx",
   };
   ```

**Never** put the *secret* key or *service_role* key anywhere in the website files. Anyone can read your site's source, so only the publishable key belongs there. It is safe because RLS only lets it add rows.

## Step 4 — Deploy (Vercel or any static host)
- This is a plain static site, so there is **no build step and no environment variables**. The publishable key is public by design, which is why it lives in `supabase-config.js` instead.
- Upload/push the four site files together (Vercel: push to your repo or drag the folder into a new project; framework preset **Other**, no build command).
- If you later want separate test and live databases, keep a different `supabase-config.js` for each environment.

## Reading your submissions
Dashboard → **Table Editor → waitlist_signups**. Only you (logged in as project owner) can see rows. Export: **⋯ → Export to CSV**. The public website cannot read, edit or delete anything.

## How saving behaves
- Success screen appears only after Supabase confirms the insert.
- While sending, the button is disabled and reads "Sending…". Extra clicks are ignored.
- On failure the form keeps everything the person typed and shows a message; they can retry.
- **Same phone number twice** (any format: `0803…`, `+234 803…`): the second is rejected by the database and the person sees the normal success screen, since they are already on the list. Their second set of answers is *not* saved. To show a different message instead, change the `"duplicate"` branch in `submitWaitlist()`.

## Test checklist
Do these after Step 3, on your live URL and again on your phone.

**Saving**
- [ ] Fill every field using a preset spend chip → submit → success screen → row appears in Table Editor with matching values.
- [ ] Choose **Other** location + custom spend + "₦4,999/month is expensive" + a question → row shows `location_other`, `monthly_spend_custom_naira`, `affordable_monthly_naira`, `has_question = true`, `question`.
- [ ] Leave email blank → row saves with empty `email`.

**Validation**
- [ ] Submit an empty form → nothing is sent, fields are highlighted.
- [ ] Bad phone (`abc`), bad email, missing consent checkbox → blocked on the page.
- [ ] Re-submit with the same phone number → success screen, but only one row in the table.

**States**
- [ ] Click submit twice quickly → only one row.
- [ ] Turn on airplane mode, submit → error message, form data still there; turn it off, submit again → works.

**Security**
- [ ] In the browser console on your site, run:
  `await window.supabase.createClient(KW_SUPABASE.url, KW_SUPABASE.key).from("waitlist_signups").select("*")`
  → must return an error (permission denied), **not** your data.
- [ ] Same with `.delete()` and `.update({full_name:"x"})` → both must fail.
- [ ] Open `view-source` on the live site and confirm only the publishable key appears.

**Layout**
- [ ] Repeat the first test on a phone, in light and dark mode.

## Limits of saving straight from the browser (be aware)
- **Spam:** anyone can find your URL and publishable key and send rows directly, bypassing the page. The database rules stop *malformed* rows and duplicate phone numbers, but not someone submitting many different fake numbers.
- **If spam becomes a problem**, move the insert behind a server function (a Supabase Edge Function or a Vercel serverless function) that checks a CAPTCHA such as Cloudflare Turnstile and rate-limits per IP, and then revoke the public `insert` grant. I did not add this now because it needs a Turnstile account and a deployed function, and the unique-phone rule plus validation is reasonable for a small pre-launch waitlist. Say the word and I'll build it.
- Supabase also applies its own platform rate limits, and you can watch for odd bursts in the Table Editor (`created_at`).
- Client-side validation is not trusted: every rule is enforced again by the database (`CHECK` constraints), which I tested.

## What changed in `index.html`
1. Added two `<script>` tags before the main script: supabase-js (pinned to `2.117.1`, with an integrity hash so a tampered file won't run) and `supabase-config.js`.
2. Replaced the empty `ENDPOINT` constant with the Supabase client set-up (no login session is stored in the visitor's browser).
3. Replaced the body of `submitWaitlist()` with a Supabase insert. The form's payload object is unchanged; `toRow()` converts it to the table's columns (e.g. `"₦2,000–₦3,000"` → `2000_3000`).
4. In the submit handler: double-submit guard, "Sending…" button label with `aria-busy`, success only after confirmation, clear errors, and the form is cleared only after success. Validation code is untouched.

No HTML markup or CSS was changed. If the config still has placeholders, the form shows its original "isn't connected yet" message.

If you ever reword an option in the form (for example fix "oppurtunity"), update the matching key in `SPEND_CODE`, `INTEREST_CODE` or `DEVICE_CODE` in `index.html`. Otherwise the form shows an error instead of saving wrong data.

## Before you collect real student data
- Your **Privacy Policy** must name Supabase as a service provider and say where data is stored. Pick the region deliberately; storing outside Nigeria may count as a cross-border transfer under the Nigeria Data Protection Act. Section 2 also lists fewer fields than the form collects (devices, affordable amount, free-text question).
- Decide a **retention period** and how you'll handle deletion requests (delete the row in Table Editor).
- `policy_version` is stamped `2026-10-14` automatically. Update the default in the table when you publish a new policy version.
- Have a qualified Nigerian lawyer review the consent text, the Privacy Policy and the Terms.
