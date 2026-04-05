-- ============================================================
-- rls_policies.sql - AI TUTOR PROJECT
-- Author: Stefania Julin
-- Version: 1.0 - Basic roles for university assignment
-- Date: 2026-04-05
--
-- ROLES DEFINED:
--   sami_laaksonen  — professor, read-only, expires 2026-04-30
--   stefania_julin  — owner, full access
--   semantic_router — AI pipeline, read-only (placeholder)
--
-- TO EXPAND LATER:
--   Add RLS policies per table when Flutter app and
--   Semantic Router are connected in pipeline Phase 6-7.
-- ============================================================

-- ============================================================
-- PROFESSOR ACCESS (read-only until 2026-04-30)
-- Already created manually — this ensures it exists
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_catalog.pg_user WHERE usename = 'sami_laaksonen'
    ) THEN
        CREATE USER sami_laaksonen
            WITH PASSWORD 'TUASeval2026!'
            VALID UNTIL '2026-05-10';
    END IF;
END $$;

GRANT CONNECT ON DATABASE postgres TO sami_laaksonen;
GRANT USAGE ON SCHEMA public TO sami_laaksonen;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO sami_laaksonen;

-- ============================================================
-- SEMANTIC ROUTER ACCESS (read-only placeholder)
-- Will be expanded in Pipeline Phase 6 when Oracle server
-- connects to this database for RAG context injection.
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_catalog.pg_user WHERE usename = 'semantic_router'
    ) THEN
        CREATE USER semantic_router
            WITH PASSWORD 'router_placeholder_change_before_production';
    END IF;
END $$;

GRANT CONNECT ON DATABASE postgres TO semantic_router;
GRANT USAGE ON SCHEMA public TO semantic_router;
GRANT SELECT ON content_unit TO semantic_router;
GRANT SELECT ON language_variant TO semantic_router;
GRANT SELECT ON tone_marker TO semantic_router;
GRANT SELECT ON cultural_context_tag TO semantic_router;
GRANT SELECT ON rel_content_tone TO semantic_router;
GRANT SELECT ON rel_content_context TO semantic_router;
GRANT SELECT ON vector_index TO semantic_router;

-- ============================================================
-- ENABLE RLS ON KEY TABLES (structure only — no policies yet)
-- Policies will be added in Phase 6-7 of the pipeline.
-- RLS enabled = table is protected but no restrictions active
-- until explicit policies are added.
-- ============================================================
ALTER TABLE content_unit ENABLE ROW LEVEL SECURITY;
ALTER TABLE correction_feedback_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE vector_index ENABLE ROW LEVEL SECURITY;

-- Allow postgres admin to bypass RLS (always true for superuser)
-- This ensures the workflow and admin tools still work normally.
CREATE POLICY admin_full_access ON content_unit
    TO postgres USING (true);

CREATE POLICY admin_full_access ON correction_feedback_log
    TO postgres USING (true);

CREATE POLICY admin_full_access ON vector_index
    TO postgres USING (true);
