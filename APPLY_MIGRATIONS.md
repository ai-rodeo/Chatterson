# Quick Migration Guide

Due to network restrictions in the Claude environment, here are 2 simple ways to apply your migrations:

---

## ⚡ FASTEST: Supabase Dashboard (5 minutes)

1. **Go to:** https://supabase.com/dashboard/project/ntbqncyqettduuycmzpk/sql/new

2. **Copy the full content** of each file below (in order) and click **Run**:

### Step 1: Core Tables
```sql
Copy ALL content from: supabase/migrations/20250101000001_create_core_tables.sql
```

### Step 2: RLS Policies
```sql
Copy ALL content from: supabase/migrations/20250101000002_enable_rls.sql
```

### Step 3: Seed Data
```sql
Copy ALL content from: supabase/migrations/20250101000003_seed_data.sql
```

### Step 4: Storage Bucket
```sql
Copy ALL content from: supabase/migrations/20250101000004_create_storage_bucket.sql
```

3. **Verify** by running this query:
```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('organizations', 'users', 'memberships', 'assets', 'asset_files', 'asset_index');
```

Should return 6 tables!

---

## 💻 Option 2: Run Locally (On Your Machine)

If you have Node.js installed locally:

```bash
# 1. Clone/download your repo
cd Chatterson

# 2. Install dependencies
npm install

# 3. Run migrations
node scripts/apply-migrations.js
```

The script will connect and apply all migrations automatically!

---

## ✅ After Applying

You should see:
- ✅ 6 tables created (organizations, users, memberships, assets, asset_files, asset_index)
- ✅ 23 RLS policies active
- ✅ 3 sample organizations (Chatterson Marketing + 2 clients)
- ✅ 1 storage bucket (client-assets)

**Then reply "migrations done" and I'll continue building the API routes!** 🚀
