-- =====================================================
-- CHATTERSON CLIENT PORTAL - SEED DATA
-- Phase 1: Sample organizations and users
-- =====================================================

-- =====================================================
-- SEED: AGENCY ORGANIZATION (Chatterson)
-- =====================================================
INSERT INTO public.organizations (id, name, slug, type, settings)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    'Chatterson Marketing',
    'chatterson',
    'agency',
    '{"primary_color": "#0066CC", "logo_url": ""}'::jsonb
)
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- SEED: SAMPLE CLIENT ORGANIZATIONS
-- =====================================================
INSERT INTO public.organizations (id, name, slug, type, settings)
VALUES
    (
        '00000000-0000-0000-0000-000000000002',
        'Sunrise Homes',
        'sunrise-homes',
        'client',
        '{"primary_color": "#FF6B35", "industry": "homebuilder"}'::jsonb
    ),
    (
        '00000000-0000-0000-0000-000000000003',
        'Peak Development Corp',
        'peak-development',
        'client',
        '{"primary_color": "#2D3142", "industry": "developer"}'::jsonb
    )
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- NOTE: USER SEEDING
-- =====================================================
-- Users are created via Supabase Auth signup flow
-- After a user signs up, your app should:
-- 1. Create a record in public.users (via trigger or API)
-- 2. Create a membership linking them to an organization
--
-- For local development, you can manually create test users:
--
-- Example (run after creating auth user):
-- INSERT INTO public.users (id, email, full_name)
-- VALUES (
--     'auth-user-uuid-here',
--     'test@example.com',
--     'Test User'
-- );
--
-- INSERT INTO public.memberships (user_id, org_id, role)
-- VALUES (
--     'auth-user-uuid-here',
--     '00000000-0000-0000-0000-000000000002',
--     'admin'
-- );
-- =====================================================

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '✅ Seed data inserted!';
    RAISE NOTICE '   - Chatterson Marketing (agency)';
    RAISE NOTICE '   - Sunrise Homes (client)';
    RAISE NOTICE '   - Peak Development Corp (client)';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  Users must be created via Supabase Auth';
    RAISE NOTICE '   After signup, create user profile and membership records';
END $$;
