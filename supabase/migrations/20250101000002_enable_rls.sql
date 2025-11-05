-- =====================================================
-- CHATTERSON CLIENT PORTAL - RLS POLICIES
-- Phase 1: Client Asset Uploads
-- =====================================================

-- =====================================================
-- ENABLE ROW LEVEL SECURITY
-- =====================================================
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asset_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asset_index ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- HELPER FUNCTION: is_agency_role
-- Check if current user has agency role in any org
-- =====================================================
CREATE OR REPLACE FUNCTION public.is_agency_role(check_org_id UUID DEFAULT NULL)
RETURNS BOOLEAN AS $$
DECLARE
    user_id UUID;
    is_agency BOOLEAN;
BEGIN
    user_id := auth.uid();

    IF user_id IS NULL THEN
        RETURN FALSE;
    END IF;

    -- If checking specific org
    IF check_org_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1
            FROM public.memberships m
            JOIN public.organizations o ON o.id = m.org_id
            WHERE m.user_id = user_id
                AND m.org_id = check_org_id
                AND o.type = 'agency'
                AND m.role IN ('owner', 'admin', 'member')
        ) INTO is_agency;
    ELSE
        -- Check if user belongs to ANY agency org
        SELECT EXISTS (
            SELECT 1
            FROM public.memberships m
            JOIN public.organizations o ON o.id = m.org_id
            WHERE m.user_id = user_id
                AND o.type = 'agency'
                AND m.role IN ('owner', 'admin', 'member')
        ) INTO is_agency;
    END IF;

    RETURN COALESCE(is_agency, FALSE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- HELPER FUNCTION: user_has_org_access
-- Check if user belongs to an organization
-- =====================================================
CREATE OR REPLACE FUNCTION public.user_has_org_access(check_org_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    user_id UUID;
BEGIN
    user_id := auth.uid();

    IF user_id IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM public.memberships
        WHERE user_id = user_id
            AND org_id = check_org_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- RLS POLICIES: ORGANIZATIONS
-- =====================================================

-- Users can view organizations they belong to
CREATE POLICY "Users can view their organizations"
    ON public.organizations
    FOR SELECT
    USING (
        public.user_has_org_access(id)
    );

-- Agency staff can view all organizations
CREATE POLICY "Agency staff can view all organizations"
    ON public.organizations
    FOR SELECT
    USING (
        public.is_agency_role()
    );

-- Only agency admins can insert organizations
CREATE POLICY "Agency admins can create organizations"
    ON public.organizations
    FOR INSERT
    WITH CHECK (
        public.is_agency_role() AND
        EXISTS (
            SELECT 1 FROM public.memberships m
            JOIN public.organizations o ON o.id = m.org_id
            WHERE m.user_id = auth.uid()
                AND o.type = 'agency'
                AND m.role IN ('owner', 'admin')
        )
    );

-- Agency admins and org owners can update
CREATE POLICY "Org owners and agency admins can update organizations"
    ON public.organizations
    FOR UPDATE
    USING (
        public.is_agency_role() OR
        EXISTS (
            SELECT 1 FROM public.memberships
            WHERE user_id = auth.uid()
                AND org_id = organizations.id
                AND role IN ('owner', 'admin')
        )
    );

-- =====================================================
-- RLS POLICIES: USERS
-- =====================================================

-- Users can view their own profile
CREATE POLICY "Users can view own profile"
    ON public.users
    FOR SELECT
    USING (id = auth.uid());

-- Agency staff can view all users
CREATE POLICY "Agency staff can view all users"
    ON public.users
    FOR SELECT
    USING (public.is_agency_role());

-- Users in same org can view each other
CREATE POLICY "Org members can view each other"
    ON public.users
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.memberships m1
            JOIN public.memberships m2 ON m1.org_id = m2.org_id
            WHERE m1.user_id = auth.uid()
                AND m2.user_id = users.id
        )
    );

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
    ON public.users
    FOR UPDATE
    USING (id = auth.uid());

-- Users can insert their own profile (on signup)
CREATE POLICY "Users can create own profile"
    ON public.users
    FOR INSERT
    WITH CHECK (id = auth.uid());

-- =====================================================
-- RLS POLICIES: MEMBERSHIPS
-- =====================================================

-- Users can view their own memberships
CREATE POLICY "Users can view own memberships"
    ON public.memberships
    FOR SELECT
    USING (user_id = auth.uid());

-- Agency staff can view all memberships
CREATE POLICY "Agency staff can view all memberships"
    ON public.memberships
    FOR SELECT
    USING (public.is_agency_role());

-- Org admins can view memberships in their org
CREATE POLICY "Org admins can view org memberships"
    ON public.memberships
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.memberships
            WHERE user_id = auth.uid()
                AND org_id = memberships.org_id
                AND role IN ('owner', 'admin')
        )
    );

-- Agency admins and org admins can manage memberships
CREATE POLICY "Admins can manage memberships"
    ON public.memberships
    FOR ALL
    USING (
        public.is_agency_role() OR
        EXISTS (
            SELECT 1 FROM public.memberships
            WHERE user_id = auth.uid()
                AND org_id = memberships.org_id
                AND role IN ('owner', 'admin')
        )
    );

-- =====================================================
-- RLS POLICIES: ASSETS
-- =====================================================

-- Users can view assets from their organizations
CREATE POLICY "Users can view own org assets"
    ON public.assets
    FOR SELECT
    USING (
        public.user_has_org_access(org_id)
    );

-- Agency staff can view all assets
CREATE POLICY "Agency staff can view all assets"
    ON public.assets
    FOR SELECT
    USING (
        public.is_agency_role()
    );

-- Users can insert assets for their organizations
CREATE POLICY "Users can create assets for their org"
    ON public.assets
    FOR INSERT
    WITH CHECK (
        public.user_has_org_access(org_id) AND
        uploaded_by = auth.uid()
    );

-- Users can update their own uploaded assets
CREATE POLICY "Users can update own assets"
    ON public.assets
    FOR UPDATE
    USING (
        uploaded_by = auth.uid() OR
        public.is_agency_role()
    );

-- Only uploaders and agency staff can delete
CREATE POLICY "Users can delete own assets"
    ON public.assets
    FOR DELETE
    USING (
        uploaded_by = auth.uid() OR
        public.is_agency_role()
    );

-- =====================================================
-- RLS POLICIES: ASSET_FILES
-- =====================================================

-- Users can view asset files if they can view the parent asset
CREATE POLICY "Users can view files from accessible assets"
    ON public.asset_files
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.assets
            WHERE id = asset_files.asset_id
                AND (
                    public.user_has_org_access(org_id) OR
                    public.is_agency_role()
                )
        )
    );

-- Users can insert files for assets they can access
CREATE POLICY "Users can upload files to accessible assets"
    ON public.asset_files
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.assets
            WHERE id = asset_files.asset_id
                AND (
                    uploaded_by = auth.uid() OR
                    public.is_agency_role()
                )
        )
    );

-- Only asset owner and agency staff can update files
CREATE POLICY "Asset owners can update files"
    ON public.asset_files
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.assets
            WHERE id = asset_files.asset_id
                AND (
                    uploaded_by = auth.uid() OR
                    public.is_agency_role()
                )
        )
    );

-- Only asset owner and agency staff can delete files
CREATE POLICY "Asset owners can delete files"
    ON public.asset_files
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.assets
            WHERE id = asset_files.asset_id
                AND (
                    uploaded_by = auth.uid() OR
                    public.is_agency_role()
                )
        )
    );

-- =====================================================
-- RLS POLICIES: ASSET_INDEX
-- =====================================================

-- Users can view index records for assets they can access
CREATE POLICY "Users can view index for accessible assets"
    ON public.asset_index
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.assets
            WHERE id = asset_index.asset_id
                AND (
                    public.user_has_org_access(org_id) OR
                    public.is_agency_role()
                )
        )
    );

-- Service role can insert/update index records (for Edge Function)
CREATE POLICY "Service can manage asset index"
    ON public.asset_index
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.assets
            WHERE id = asset_index.asset_id
        )
    );

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '✅ RLS policies created successfully!';
    RAISE NOTICE '   - Organizations: 4 policies';
    RAISE NOTICE '   - Users: 5 policies';
    RAISE NOTICE '   - Memberships: 4 policies';
    RAISE NOTICE '   - Assets: 5 policies';
    RAISE NOTICE '   - Asset Files: 4 policies';
    RAISE NOTICE '   - Asset Index: 2 policies';
    RAISE NOTICE '   - Helper functions: is_agency_role, user_has_org_access';
END $$;
