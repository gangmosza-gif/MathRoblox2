# Score Storage Setup

This project now supports server-side score recording on Vercel.

## 1. Add a database

Create a Neon Postgres database from Vercel Marketplace, then make sure the Vercel project has this environment variable:

```text
DATABASE_URL
```

The API creates the required tables automatically on the first score save or export request.

## 2. Add an admin export token

Add another Vercel environment variable:

```text
ADMIN_TOKEN=your-secret-teacher-token
```

Use a private value that students will not know.

## 3. Export CSV

After deployment, open:

```text
https://YOUR-PROJECT.vercel.app/api/export-scores?token=YOUR_ADMIN_TOKEN
```

The CSV includes one row per answer attempt, with session-level fields such as player name, level, mode, correct count, stars, and coins earned.

## 4. Check recent sessions as JSON

```text
https://YOUR-PROJECT.vercel.app/api/scores?token=YOUR_ADMIN_TOKEN
```

## Notes

- The game still works if the database is not configured, but server-side score saving will be skipped.
- Public players can submit scores, but only someone with `ADMIN_TOKEN` can export or view the collected data.
- Do not commit real `.env` files or secret tokens to GitHub.
