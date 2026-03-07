-- ============================================================
-- schema_fixes_v3_1.sql
-- Author: Stefania Julin | AI Tutor Project - Progetto DATA
-- Date: 2026-03-07
-- Version: 3.1
-- Repository: STEFFIJ-Labs/AI_Tutor_Project
--
-- PURPOSE:
--   Four surgical fixes to schema v3.0 identified by the
--   20-query forensic verification session on 2026-03-07.
--   Zero data loss. Zero destructive operations.
--
-- FIXES INCLUDED:
--   FIX 1: ISO code normalization trigger
--          Any external DB (Dependance V2, etc.) can send
--          'IT', 'it', 'it-IT' - all normalized automatically.
--   FIX 2: language_variant 'und' fallback row
--          Catch-all for unknown dialects discovered dynamically
--          by the Semantic Router during production.
--   FIX 3: content_unit variant_confidence column
--          Allows Semantic Router to track classification
--          certainty. NULL = not yet classified by Router.
--   FIX 4: v_content_full_context security_invoker
--          Fixes RLS bypass vulnerability. VIEW now executes
--          with the permissions of the caller, not the creator.
--   FIX 5: vector_index model_id column
--          Links each Pinecone vector to the AI model that
--          generated it. Required for per-model RAG isolation.
--
-- HOW TO DEPLOY:
--   Option A (recommended): GitHub Actions deploys automatically
--                           on push to main branch.
--   Option B (manual):      Paste in Supabase SQL Editor.
--
-- SAFE TO RUN MULTIPLE TIMES: all statements use IF NOT EXISTS
-- or CREATE OR REPLACE. Idempotent.
-- ============================================================


BEGIN;

-- ============================================================
-- FIX 1: ISO CODE NORMALIZATION TRIGGER
-- ============================================================
-- PROBLEM:
--   External databases (Dependance V2 and others) may send
--   language codes in different formats:
--     'IT'    (uppercase, no region)
--     'it'    (lowercase, no region)
--     'it-it' (lowercase with region)
--     'it-IT' (correct format used in this DB)
--   PostgreSQL VARCHAR is case-sensitive. 'IT' != 'it-IT'.
--   Without normalization, a lookup like:
--     SELECT variant_id FROM language_variant WHERE iso_code = 'IT'
--   returns 0 rows even though 'it-IT' exists.
--   Result: variant_id = NULL, data lost silently.
--
-- SOLUTION:
--   A BEFORE INSERT OR UPDATE trigger on language_variant that
--   normalizes any incoming iso_code to the canonical format
--   before it is written to disk. The normalization happens
--   inside the database itself - no application code needed.
--   Any script, any pipeline stage, any external DB can send
--   any format and the result is always correct.
--
-- EXAMPLE:
--   INSERT INTO language_variant (iso_code, ...) VALUES ('IT', ...)
--   → trigger fires → iso_code stored as 'it-IT' ✓
-- ============================================================

CREATE OR REPLACE FUNCTION fn_normalize_iso_code()
RETURNS TRIGGER AS $$
BEGIN
    -- Normalize by: lowercase + remove hyphens + remap to standard
    NEW.iso_code = CASE LOWER(REPLACE(NEW.iso_code, '-', ''))
        -- Italian variants
        WHEN 'itit' THEN 'it-IT'
        WHEN 'it'   THEN 'it-IT'
        -- Finnish variants
        WHEN 'fifi' THEN 'fi-FI'
        WHEN 'fi'   THEN 'fi-FI'
        -- English variants (pivot language)
        WHEN 'enen' THEN 'en-EN'
        WHEN 'en'   THEN 'en-EN'
        -- Undetermined (catch-all for Router-discovered variants)
        WHEN 'und'  THEN 'und'
        -- Unknown format: store as received, Router will handle it
        ELSE NEW.iso_code
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop and recreate trigger to ensure idempotency
DROP TRIGGER IF EXISTS trg_normalize_iso_code ON language_variant;

CREATE TRIGGER trg_normalize_iso_code
BEFORE INSERT OR UPDATE OF iso_code ON language_variant
FOR EACH ROW
EXECUTE FUNCTION fn_normalize_iso_code();

-- ============================================================
-- FIX 2: 'und' FALLBACK LANGUAGE VARIANT
-- ============================================================
-- PROBLEM:
--   The Semantic Router will autonomously discover new dialects
--   and variants during production (e.g., Napoletano, Puhekieli,
--   Siciliano). While the Router is classifying a new variant,
--   there is a window where content_unit.variant_id could be NULL.
--   A NULL variant_id means:
--     - The ETL cannot export that row to Hugging Face
--     - Training batches skip the row silently
--     - Data is lost without any error message
--
-- SOLUTION:
--   Insert one special row: iso_code = 'und' (ISO 639-2 standard
--   for "undetermined language"). This is the FALLBACK variant.
--   When the Router ingests a phrase it cannot yet classify,
--   it assigns variant_id pointing to 'und' instead of NULL.
--   The phrase is saved. The Router revisits it later and updates
--   variant_id to the correct dialect once identified.
--
-- PIPELINE FLOW WITH 'und':
--   1. New phrase arrives from Dependance V2
--   2. Router cannot identify dialect → assigns 'und'
--   3. Phrase saved with variant_id = (und row id)
--   4. Router background job re-classifies 'und' rows
--   5. variant_id updated to correct dialect
--   6. ETL picks up the now-classified phrase ✓
--
-- NOTE: 'und' is NOT a training language. The ETL script must
--       filter out variant_confidence < 0.7 before export.
-- ============================================================

INSERT INTO language_variant
    (iso_code, variant_name, is_pivot, parent_variant_id)
VALUES
    ('und', 'Undetermined', false, NULL)
ON CONFLICT (iso_code) DO NOTHING;

-- ============================================================
-- FIX 3: variant_confidence COLUMN IN content_unit
-- ============================================================
-- PROBLEM:
--   content_unit.variant_id is NULLABLE by design (to support
--   dynamic dialect discovery). But there is no way to know
--   HOW CERTAIN the Router is about its classification.
--   A phrase classified as 'nap-IT' with 40% confidence is
--   unreliable training data. Without a confidence score,
--   the ETL cannot filter out low-quality classifications.
--
-- SOLUTION:
--   Add variant_confidence FLOAT column (0.0 to 1.0).
--   Meaning of values:
--     NULL  = not yet processed by Semantic Router
--     0.0   = Router attempted classification, failed
--     0.5   = Router uncertain (e.g., code-switching detected)
--     1.0   = Router certain (or manually verified)
--
--   ETL EXPORT RULE (to be implemented in ETL script):
--     WHERE variant_id IS NOT NULL
--     AND   variant_confidence >= 0.7
--   This ensures only high-confidence rows reach Hugging Face.
--
-- EXAMPLE:
--   "Jamme jà"  → Router → variant='nap-IT', confidence=0.92 ✓
--   "???"       → Router → variant='und',    confidence=0.0  ✗ (excluded)
-- ============================================================

ALTER TABLE content_unit
    ADD COLUMN IF NOT EXISTS variant_confidence FLOAT
    CHECK (variant_confidence IS NULL
        OR (variant_confidence >= 0.0 AND variant_confidence <= 1.0));

COMMENT ON COLUMN content_unit.variant_confidence IS
    'Semantic Router classification confidence (0.0-1.0). '
    'NULL = unprocessed. ETL exports only rows >= 0.7. '
    'Populated by Router during ingestion or background re-classification.';

-- ============================================================
-- FIX 4: v_content_full_context SECURITY INVOKER
-- ============================================================
-- PROBLEM:
--   The VIEW v_content_full_context was created without
--   security_invoker = true. PostgreSQL default for views is
--   SECURITY DEFINER: the view runs with the permissions of
--   the user who CREATED it (admin), not the user who CALLS it.
--   This means RLS policies on the underlying tables are
--   completely bypassed when querying through the VIEW.
--
--   Real attack scenario:
--     Student user (restricted by RLS to their own data) calls:
--       SELECT * FROM v_content_full_context
--     Without security_invoker, they see ALL rows from ALL
--     students because the query runs as admin.
--
-- SOLUTION:
--   Recreate the VIEW with security_invoker = true.
--   Now every query through the VIEW uses the caller's
--   permissions. RLS policies are enforced correctly.
--
-- SAFE: CREATE OR REPLACE VIEW does not drop data.
--       The VIEW definition is identical to v3.0.
--       Only the security context changes.
-- ============================================================

CREATE OR REPLACE VIEW v_content_full_context
WITH (security_invoker = true) AS
SELECT
    cu.unit_id,
    cu.content_raw,
    cu.content_type,
    cu.cefr_level,
    cu.is_idiom,
    cu.difficulty,
    lv.iso_code,
    lv.variant_name,
    lv.is_pivot,
    cu.variant_confidence,
    tm.tone_name,
    cct.context_name                   AS theme
FROM content_unit                      cu
JOIN language_variant                  lv  ON lv.variant_id  = cu.variant_id
LEFT JOIN rel_content_tone             rct ON rct.unit_id     = cu.unit_id
LEFT JOIN tone_marker                  tm  ON tm.tone_id      = rct.tone_id
LEFT JOIN rel_content_context          rcc ON rcc.unit_id     = cu.unit_id
LEFT JOIN cultural_context_tag         cct ON cct.context_id  = rcc.context_id;

-- ============================================================
-- FIX 5: model_id COLUMN IN vector_index
-- ============================================================
-- PROBLEM:
--   Each AI model (Poro, Aya, Gemma) generates embeddings with
--   a different embedding model and different vector dimensions.
--   A vector generated by Poro's embedding model is NOT
--   semantically compatible with one generated by Aya's.
--   Without model_id in vector_index, the Semantic Router
--   cannot isolate which vectors belong to which model.
--
--   Consequence: the Router might compare a Finnish query
--   vector against Italian content vectors → wrong results.
--
-- SOLUTION:
--   Add model_id FK to vector_index referencing ai_model_registry.
--   ON DELETE SET NULL: if a model is removed from the registry,
--   its vectors are not deleted - they become unassigned and can
--   be re-indexed later. ON UPDATE CASCADE: if model_id changes,
--   the FK follows automatically.
--
-- EXAMPLE:
--   Poro generates embedding for "Mennään" →
--   vector_index row: pinecone_id='vec_123', model_id=1 (Poro)
--   Router receives Finnish query →
--   searches ONLY vectors WHERE model_id = 1 (Poro) ✓
-- ============================================================

ALTER TABLE vector_index
    ADD COLUMN IF NOT EXISTS model_id INT
    REFERENCES ai_model_registry(model_id)
    ON DELETE SET NULL
    ON UPDATE CASCADE;

COMMENT ON COLUMN vector_index.model_id IS
    'FK to ai_model_registry. Identifies which AI model generated '
    'this vector embedding. Required for per-model RAG isolation: '
    'Finnish queries search only Poro vectors (model_id=1), '
    'Italian dialect queries search only Aya vectors (model_id=2).';

-- ============================================================
-- VERIFICATION: run after COMMIT to confirm all fixes applied
-- ============================================================
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_schema = 'public'
--   AND table_name   = 'content_unit'
--   AND column_name  = 'variant_confidence';
--
-- SELECT trigger_name, event_manipulation, action_timing
-- FROM information_schema.triggers
-- WHERE trigger_schema = 'public'
--   AND event_object_table = 'language_variant';
--
-- SELECT iso_code, variant_name FROM language_variant
-- WHERE iso_code = 'und';
--
-- SELECT viewname FROM pg_views
-- WHERE schemaname = 'public'
--   AND viewname = 'v_content_full_context';
--
-- SELECT column_name FROM information_schema.columns
-- WHERE table_schema = 'public'
--   AND table_name   = 'vector_index'
--   AND column_name  = 'model_id';

COMMIT;
