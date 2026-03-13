-- ============================================================
-- schema_fixes_v3_1.sql
-- Author: Stefania Julin | AI Tutor Project - Progetto DATA
-- Date: 2026-03-07
-- Version: 3.1
-- Repository: STEFFIJ-Labs/AI_Tutor_Project
--
-- PURPOSE:
--   Five surgical fixes to schema v3.0 identified by the
--   20-query forensic verification session on 2026-03-07.
--   Zero data loss. Zero destructive operations.
--
-- CRITICAL ARCHITECTURE NOTE:
--   The Supabase Management API accepts ONE statement per call.
--   This file is NOT sent as a single block.
--   The workflow deploy-schema-fixes2.yml sends each fix
--   as a separate curl call. Each fix below is therefore
--   a single self-contained SQL statement.
--
-- FIXES INCLUDED:
--
--   FIX 1: ISO code normalization trigger on language_variant
--          Any external DB (Dependance V2, Firebase, etc.) can send
--          'IT', 'it', 'it-IT' - all normalized automatically to
--          the canonical form before INSERT or UPDATE.
--          Solves: cross-database iso_code mismatch breaking ETL.
--
--   FIX 2: language_variant 'und' fallback row
--          ISO 639-2 standard code for undetermined language.
--          Catch-all for unknown dialects discovered dynamically
--          by the Semantic Router during production.
--          Solves: new dialect arrives, discovery fails,
--          variant_id = NULL, frase becomes invisible to ETL.
--
--   FIX 3: content_unit variant_confidence column
--          FLOAT, default NULL = not yet classified by Router.
--          Allows Semantic Router to track classification
--          certainty per content row.
--          Solves: Router cannot distinguish between
--          "classified as und" and "never classified".
--
--   FIX 4: v_content_full_context recreated with security_invoker
--          Fixes RLS bypass vulnerability reported by Supabase
--          Security Advisor. VIEW now executes with the permissions
--          of the caller (student, admin, router), not the creator.
--          DROP VIEW first required to change security mode.
--          Solves: SECURITY DEFINER bypass of Row Level Security.
--
--   FIX 5: vector_index model_id column
--          FK to ai_model_registry(model_id).
--          Links each Pinecone vector to the AI model that
--          generated it. Required for per-model RAG isolation:
--          Poro embeddings != Aya embeddings != Gemma embeddings.
--          Solves: Semantic Router cross-model vector search
--          returning semantically incorrect results.
--
-- HOW THIS FILE IS DEPLOYED:
--   The workflow sends each fix as a SEPARATE curl call.
--   This file documents all fixes for version control.
--   The actual SQL for each fix is embedded directly
--   in deploy-schema-fixes2.yml as individual steps.
--
-- VERIFICATION:
--   After deploy, the workflow runs a 5-check verification
--   query confirming each fix is present in the live database.
-- ============================================================


-- ============================================================
-- FIX 1: ISO normalization trigger
-- Single statement: CREATE OR REPLACE FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION normalize_iso_code()
RETURNS TRIGGER AS $$
BEGIN
    NEW.iso_code = CASE LOWER(REPLACE(NEW.iso_code, '-', ''))
        WHEN 'itit' THEN 'it-IT'
        WHEN 'it'   THEN 'it-IT'
        WHEN 'fifi' THEN 'fi-FI'
        WHEN 'fi'   THEN 'fi-FI'
        WHEN 'enen' THEN 'en-EN'
        WHEN 'en'   THEN 'en-EN'
        ELSE NEW.iso_code
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- FIX 1b: Attach trigger to language_variant table
-- Single statement: CREATE TRIGGER
-- ============================================================
CREATE OR REPLACE TRIGGER trg_normalize_iso_code
BEFORE INSERT OR UPDATE ON language_variant
FOR EACH ROW EXECUTE FUNCTION normalize_iso_code();


-- ============================================================
-- FIX 2: Insert 'und' fallback variant
-- Single statement: INSERT ... ON CONFLICT DO NOTHING
-- ============================================================
INSERT INTO language_variant (iso_code, variant_name, is_pivot, parent_variant_id)
VALUES ('und', 'Undetermined', false, NULL)
ON CONFLICT (iso_code) DO NOTHING;


-- ============================================================
-- FIX 3: Add variant_confidence column to content_unit
-- Single statement: ALTER TABLE ... ADD COLUMN IF NOT EXISTS
-- ============================================================
ALTER TABLE content_unit
    ADD COLUMN IF NOT EXISTS variant_confidence FLOAT;


-- ============================================================
-- FIX 4a: Drop existing view (required before recreating
--          with security_invoker - cannot use CREATE OR REPLACE
--          when changing security mode in PostgreSQL)
-- Single statement: DROP VIEW IF EXISTS
-- ============================================================
DROP VIEW IF EXISTS v_content_full_context;


-- ============================================================
-- FIX 4b: Recreate view with security_invoker = true
-- Single statement: CREATE VIEW ... WITH (security_invoker = true)
-- ============================================================
CREATE VIEW v_content_full_context
WITH (security_invoker = true) AS
SELECT
    cu.unit_id,
    cu.content_raw,
    cu.content_type,
    cu.cefr_level,
    cu.is_idiom,
    cu.difficulty,
    cu.variant_confidence,
    lv.iso_code,
    lv.variant_name,
    lv.is_pivot,
    tm.tone_name,
    cct.context_name AS theme
FROM content_unit cu
JOIN language_variant         lv  ON lv.variant_id  = cu.variant_id
LEFT JOIN rel_content_tone    rct ON rct.unit_id     = cu.unit_id
LEFT JOIN tone_marker         tm  ON tm.tone_id      = rct.tone_id
LEFT JOIN rel_content_context rcc ON rcc.unit_id     = cu.unit_id
LEFT JOIN cultural_context_tag cct ON cct.context_id = rcc.context_id;


-- ============================================================
-- FIX 5: Add model_id column to vector_index
-- Single statement: ALTER TABLE ... ADD COLUMN IF NOT EXISTS
-- ============================================================
ALTER TABLE vector_index
    ADD COLUMN IF NOT EXISTS model_id INT
    REFERENCES ai_model_registry(model_id)
    ON DELETE SET NULL ON UPDATE CASCADE;
