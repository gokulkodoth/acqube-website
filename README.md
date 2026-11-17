# Acqube website: Supabase setup

Files in this folder:
- `index.html`: the whole website (public pages + Admin Console at `#admin`)
- `logo.png`, `logo-white.png`: logos
- `supabase-setup.sql`: creates the database tables and security rules

## 1. Create the database (2 minutes)
1. Open your Supabase project **Acqube-new** → **SQL Editor** → **New query**.
2. Paste everything from `supabase-setup.sql` and click **Run**. You should see "Success. No rows returned".

## 2. Create the admin login
1. Supabase → **Authentication** → **Users** → **Add user** → **Create new user**.
2. Email: `gokul@acqube.com`, choose a strong password, tick **Auto Confirm User**, then click **Create user**.
3. Recommended: **Authentication** → **Sign In / Providers** → turn off **Allow new users to sign up**, so nobody else can create accounts. Even if someone did, they would not be an admin.
4. To add another admin later, run in the SQL editor:
   `insert into public.admins (email) values ('name@acqube.com');` and create that user as in step 2.

## 3. Connect the website
1. Supabase → **Project Settings** → **API Keys**. Copy the **anon / publishable** key. Never use the `service_role` / secret key on a website.
2. Open `index.html`, find `PASTE_YOUR_ANON_PUBLIC_KEY_HERE` and paste the key there. The project URL is already filled in.
3. Supabase → **Authentication** → **URL Configuration** → set **Site URL** to your website address (for example `https://www.acqube.com`) so password-reset links come back to your site.

## 4. Put it online
Upload the folder to any static host: GitHub Pages, Netlify, Vercel or Cloudflare Pages. All of them are free for a site this size, and you point your domain at the host.

## Using the admin console
Go to `https://your-site/#admin` (also linked as "Admin" in the footer) and sign in.
- **Leads**: every website form lands here. Set a status for each lead, add notes, call or WhatsApp in one tap, add phone or WhatsApp enquiries by hand, and copy the list as CSV.
- **Blog posts**: write, save drafts and publish. Formatting: blank line = new paragraph, `## ` = heading, `- ` = bullet, `**bold**`.
- **Testimonials**: a testimonial shows on the site only when both "client permission" and "show on website" are ticked.

## Optional next steps
- Email alert for each new lead: Supabase → Database → Webhooks (on insert into `leads`) → send to an email or automation service such as Zapier, Make or Pabbly.
- Google Analytics / Search Console: add the tracking snippet into `<head>` of `index.html`.

## How the site is built (since Nov 2026)
- `src/index.html` is the website source. **Edit this file**, not the generated ones.
- `tools/build.py` turns it into one real page per URL (`/services/gst/`, `/blog/<article>/`, …) with its own title,
  description and content, plus `sitemap.xml` and `robots.txt`. The generated files live in the repository root.
- `.github/workflows/build-site.yml` runs the build automatically every morning and whenever `src/` changes, so new
  blog posts published from Admin get their own page and sitemap entry by the next morning.
- Google Analytics: set `GA_ID` near the top of the script in `src/index.html`.
