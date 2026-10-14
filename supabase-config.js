/* KampusWave · Supabase connection settings
   --------------------------------------------------------------
   Fill in the two values below (Supabase Dashboard → Project Settings → API Keys).

   • url  : your Project URL, e.g. https://abcdxyzcompany.supabase.co
   • key  : the PUBLISHABLE key (starts with  sb_publishable_ ).
            If your project only shows the older "anon" key (starts with eyJ…), that works too.

   This key is designed to be public – it is safe in browser code because Row Level
   Security (supabase/schema.sql) only lets it INSERT waitlist rows.

   NEVER put the "secret" key or the "service_role" key in this file or anywhere on the website.
*/
window.KW_SUPABASE = {
  url: "https://sueqgkczylnmtftcsksh.supabase.co",
  key: "sb_publishable_dPnpUHvZloOctwZy5MRRWQ_Gy3rpvYy",
};
