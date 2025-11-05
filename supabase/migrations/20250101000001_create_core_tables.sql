-- =====================================================
-- CHATTERSON CLIENT PORTAL - CORE TABLES MIGRATION
-- Phase 1: Client Asset Uploads
-- =====================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- 1. ORGANIZATIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('agency', 'client')),
    settings JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_organizations_slug ON public.organizations(slug);
CREATE INDEX idx_organizations_type ON public.organizations(type);

COMMENT ON TABLE public.organizations IS 'Multi-tenant organizations: agency and client companies';
COMMENT ON COLUMN public.organizations.type IS 'agency = Chatterson staff, client = homebuilders/developers';

-- =====================================================
-- 2. USERS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    phone TEXT,
    settings JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_email ON public.users(email);

COMMENT ON TABLE public.users IS 'User profiles linked to Supabase Auth';

-- =====================================================
-- 3. MEMBERSHIPS TABLE (User-Organization Many-to-Many)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.memberships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, org_id)
);

CREATE INDEX idx_memberships_user_id ON public.memberships(user_id);
CREATE INDEX idx_memberships_org_id ON public.memberships(org_id);
CREATE INDEX idx_memberships_role ON public.memberships(role);

COMMENT ON TABLE public.memberships IS 'Links users to organizations with roles';
COMMENT ON COLUMN public.memberships.role IS 'owner = full control, admin = manage org, member = standard access, viewer = read-only';

-- =====================================================
-- 4. ASSETS TABLE (Parent asset records)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.assets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    uploaded_by UUID NOT NULL REFERENCES public.users(id),
    category TEXT NOT NULL CHECK (category IN ('logo', 'image', 'video', 'document', 'other')),
    title TEXT,
    description TEXT,
    tags TEXT[] DEFAULT ARRAY[]::TEXT[],
    metadata JSONB DEFAULT '{}'::jsonb,
    status TEXT DEFAULT 'processing' CHECK (status IN ('processing', 'ready', 'failed')),
    clickup_task_id TEXT,
    clickup_task_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_assets_org_id ON public.assets(org_id);
CREATE INDEX idx_assets_uploaded_by ON public.assets(uploaded_by);
CREATE INDEX idx_assets_category ON public.assets(category);
CREATE INDEX idx_assets_status ON public.assets(status);
CREATE INDEX idx_assets_created_at ON public.assets(created_at DESC);

COMMENT ON TABLE public.assets IS 'Parent records for uploaded assets (one asset can have multiple files)';
COMMENT ON COLUMN public.assets.category IS 'logo = brand assets, image = photos/graphics, video = video files, document = PDFs/docs';

-- =====================================================
-- 5. ASSET_FILES TABLE (Individual file records)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.asset_files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_id UUID NOT NULL REFERENCES public.assets(id) ON DELETE CASCADE,
    storage_path TEXT NOT NULL,
    filename TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    file_size BIGINT NOT NULL,
    width INTEGER,
    height INTEGER,
    duration NUMERIC,
    checksum TEXT,
    virus_scan_status TEXT DEFAULT 'pending' CHECK (virus_scan_status IN ('pending', 'clean', 'infected', 'failed')),
    processing_status TEXT DEFAULT 'pending' CHECK (processing_status IN ('pending', 'completed', 'failed')),
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_asset_files_asset_id ON public.asset_files(asset_id);
CREATE INDEX idx_asset_files_storage_path ON public.asset_files(storage_path);
CREATE INDEX idx_asset_files_mime_type ON public.asset_files(mime_type);

COMMENT ON TABLE public.asset_files IS 'Individual files belonging to assets (supports multi-file uploads)';
COMMENT ON COLUMN public.asset_files.storage_path IS 'Path in Supabase Storage bucket';

-- =====================================================
-- 6. ASSET_INDEX TABLE (Full-text search index)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.asset_index (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_id UUID NOT NULL REFERENCES public.assets(id) ON DELETE CASCADE,
    content_type TEXT NOT NULL CHECK (content_type IN ('extracted_text', 'ocr_text', 'metadata')),
    content TEXT NOT NULL,
    search_vector tsvector,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_asset_index_asset_id ON public.asset_index(asset_id);
CREATE INDEX idx_asset_index_search_vector ON public.asset_index USING GIN(search_vector);

COMMENT ON TABLE public.asset_index IS 'Full-text search index for asset content (PDFs, OCR, metadata)';

-- Create trigger to auto-update search_vector
CREATE OR REPLACE FUNCTION public.asset_index_update_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector = to_tsvector('english', COALESCE(NEW.content, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER asset_index_search_vector_update
    BEFORE INSERT OR UPDATE OF content
    ON public.asset_index
    FOR EACH ROW
    EXECUTE FUNCTION public.asset_index_update_search_vector();

-- =====================================================
-- 7. UPDATED_AT TRIGGERS
-- =====================================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_organizations_updated_at
    BEFORE UPDATE ON public.organizations
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_memberships_updated_at
    BEFORE UPDATE ON public.memberships
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_assets_updated_at
    BEFORE UPDATE ON public.assets
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '✅ Core tables created successfully!';
    RAISE NOTICE '   - organizations';
    RAISE NOTICE '   - users';
    RAISE NOTICE '   - memberships';
    RAISE NOTICE '   - assets';
    RAISE NOTICE '   - asset_files';
    RAISE NOTICE '   - asset_index';
END $$;
