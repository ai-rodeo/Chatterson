-- =====================================================
-- CHATTERSON CLIENT PORTAL - STORAGE BUCKETS
-- Phase 1: Client Assets Storage
-- =====================================================

-- =====================================================
-- CREATE PRIVATE BUCKET: client-assets
-- =====================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'client-assets',
    'client-assets',
    false, -- Private bucket (requires signed URLs)
    104857600, -- 100 MB limit per file
    ARRAY[
        'image/jpeg',
        'image/png',
        'image/gif',
        'image/webp',
        'image/svg+xml',
        'video/mp4',
        'video/quicktime',
        'video/x-msvideo',
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/zip',
        'text/plain'
    ]
)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- =====================================================
-- STORAGE POLICIES: client-assets bucket
-- =====================================================

-- Users can upload to their own org folder via signed URLs
-- Path structure: {org_id}/{asset_id}/{filename}
CREATE POLICY "Users can upload via signed URL"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'client-assets'
    AND (storage.foldername(name))[1]::uuid IN (
        SELECT org_id FROM public.memberships
        WHERE user_id = auth.uid()
    )
);

-- Users can read files from their org folders
CREATE POLICY "Users can read own org files"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'client-assets'
    AND (
        (storage.foldername(name))[1]::uuid IN (
            SELECT org_id FROM public.memberships
            WHERE user_id = auth.uid()
        )
        OR
        -- Agency staff can read all files
        public.is_agency_role()
    )
);

-- Users can update files they uploaded
CREATE POLICY "Users can update own uploads"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'client-assets'
    AND owner = auth.uid()
);

-- Users can delete their uploaded files
CREATE POLICY "Users can delete own uploads"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'client-assets'
    AND (
        owner = auth.uid()
        OR public.is_agency_role()
    )
);

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '✅ Storage bucket created: client-assets';
    RAISE NOTICE '   - Type: Private (requires signed URLs)';
    RAISE NOTICE '   - Max file size: 100 MB';
    RAISE NOTICE '   - Folder structure: {org_id}/{asset_id}/{filename}';
    RAISE NOTICE '   - Allowed types: images, videos, documents';
END $$;
