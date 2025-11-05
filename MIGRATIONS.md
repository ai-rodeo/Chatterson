# Database Migrations Guide

## Overview

This document explains how to apply the Chatterson Client Portal database migrations.

## Migration Files

The migrations are located in `supabase/migrations/` and must be run in order:

1. **20250101000001_create_core_tables.sql** - Creates core tables (organizations, users, memberships, assets, asset_files, asset_index)
2. **20250101000002_enable_rls.sql** - Enables Row Level Security and creates policies
3. **20250101000003_seed_data.sql** - Inserts sample organizations
4. **20250101000004_create_storage_bucket.sql** - Creates the `client-assets` storage bucket

## What Gets Created

### Tables
- ✅ **organizations** - Agency and client companies (with type: 'agency' or 'client')
- ✅ **users** - User profiles linked to Supabase Auth
- ✅ **memberships** - Many-to-many relationship between users and orgs (with roles)
- ✅ **assets** - Parent records for uploaded assets
- ✅ **asset_files** - Individual file records (supports multi-file uploads)
- ✅ **asset_index** - Full-text search index with tsvector

### RLS Policies
- ✅ **Org-scoped access** - Users can only see data from orgs they belong to
- ✅ **Agency override** - Agency staff (type='agency') can view all data
- ✅ **Role-based permissions** - owner/admin/member/viewer roles
- ✅ **Helper functions**:
  - `is_agency_role(org_id)` - Check if user is agency staff
  - `user_has_org_access(org_id)` - Check if user belongs to org

### Storage
- ✅ **client-assets bucket** - Private bucket for file uploads
- ✅ **Path structure**: `{org_id}/{asset_id}/{filename}`
- ✅ **File size limit**: 100 MB per file
- ✅ **Allowed types**: Images, videos, documents, PDFs

## How to Apply Migrations

### Option 1: Supabase CLI (Recommended for Local Development)

```bash
# Install Supabase CLI
npm install -g supabase

# Initialize Supabase (if not already done)
supabase init

# Link to your project
supabase link --project-ref your-project-ref

# Apply all migrations
supabase db push

# Or apply migrations one by one
supabase db push --file supabase/migrations/20250101000001_create_core_tables.sql
supabase db push --file supabase/migrations/20250101000002_enable_rls.sql
supabase db push --file supabase/migrations/20250101000003_seed_data.sql
supabase db push --file supabase/migrations/20250101000004_create_storage_bucket.sql
```

### Option 2: Supabase Dashboard SQL Editor

1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor** in the left sidebar
3. Copy and paste each migration file content in order
4. Click **Run** for each migration

### Option 3: psql Command Line

```bash
# Set your connection string
export DATABASE_URL="postgresql://postgres:your-password@db.your-project-ref.supabase.co:5432/postgres"

# Run migrations in order
psql $DATABASE_URL -f supabase/migrations/20250101000001_create_core_tables.sql
psql $DATABASE_URL -f supabase/migrations/20250101000002_enable_rls.sql
psql $DATABASE_URL -f supabase/migrations/20250101000003_seed_data.sql
psql $DATABASE_URL -f supabase/migrations/20250101000004_create_storage_bucket.sql
```

## Verify Migrations

After applying migrations, verify they worked:

```sql
-- Check tables exist
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('organizations', 'users', 'memberships', 'assets', 'asset_files', 'asset_index');

-- Check RLS is enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('organizations', 'users', 'memberships', 'assets', 'asset_files', 'asset_index');

-- Check policies exist
SELECT tablename, policyname
FROM pg_policies
WHERE schemaname = 'public';

-- Check storage bucket exists
SELECT * FROM storage.buckets WHERE id = 'client-assets';

-- Check seed data
SELECT id, name, slug, type FROM public.organizations;
```

## Rollback (if needed)

To rollback migrations, run these in **reverse order**:

```sql
-- Drop storage bucket
DELETE FROM storage.buckets WHERE id = 'client-assets';

-- Drop tables (CASCADE removes dependent objects)
DROP TABLE IF EXISTS public.asset_index CASCADE;
DROP TABLE IF EXISTS public.asset_files CASCADE;
DROP TABLE IF EXISTS public.assets CASCADE;
DROP TABLE IF EXISTS public.memberships CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;
DROP TABLE IF EXISTS public.organizations CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS public.is_agency_role(UUID);
DROP FUNCTION IF EXISTS public.user_has_org_access(UUID);
DROP FUNCTION IF EXISTS public.handle_updated_at();
DROP FUNCTION IF EXISTS public.asset_index_update_search_vector();
```

## Next Steps

After applying migrations:
1. Set up your `.env` file with Supabase credentials
2. Create test users via Supabase Auth
3. Test the API endpoints (see README.md)
4. Deploy the Edge Function

## Troubleshooting

### Error: "extension uuid-ossp does not exist"
- Enable it in Supabase Dashboard → Database → Extensions
- Or run: `CREATE EXTENSION IF NOT EXISTS "uuid-ossp";`

### Error: "permission denied for schema storage"
- Make sure you're using the service role key (not anon key) for migrations
- Or apply storage migration via Supabase Dashboard

### Error: "relation already exists"
- Migrations were already applied
- Check with: `SELECT * FROM public.organizations;`
- Drop and rerun if needed (see Rollback section)
