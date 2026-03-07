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
--          DROP VIEW first required: CREATE OR REPLACE cannot
--          change column order in PostgreSQL.
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
-- or DROP IF EXISTS. Idempotent.
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
--
-- EXAMPLE:
--   INSERT INTO language_variant (iso_code, ...) VALUES ('IT', ...)
--   trigger fires -> iso_code stored as 'it-IT' 
-- ============================================================

CREATE OR REPLACE FUNCTION fn_normalize_iso_code()
RETURNS TRIGGER AS $$
BEGIN
    NEW.iso_code = CASE LOWER(REPLACE(NEW.iso_code, '-', ''))
        WHEN 'itit' THEN 'it-IT'
        WHEN 'it'   THEN 'it-IT'
        WHEN 'fifi' THEN 'fi-FI'
        WHEN 'fi'   THEN 'fi-FI'
        WHEN 'enen' THEN 'en-EN'
        WHEN 'en'   THEN 'en-EN'
        WHEN 'und'  THEN 'und'
        ELSE NEW.iso_code
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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
--   during production (Napoletano, Puhekieli, Siciliano...).
--   While classifying a new variant, content_unit.variant_id
--   could be NULL. A NULL variant_id means the ETL cannot
--   export that row to Hugging Face - data lost silently.
--
-- SOLUTION:
--   Insert one special row: iso_code = 'und' (ISO 639-2
--   standard for "undetermined language"). This is the FALLBACK
--   variant. Router assigns 'und' instead of NULL, then
--   revisits and updates to correct dialect once identified.
--
-- PIPELINE FLOW WITH 'und':
--   1. New phrase arrives - Router cannot identify dialect
--   2. Router assigns variant_id -> 'und' row
--   3. Phrase saved, not lost
--   4. Router background job re-classifies 'und' rows
--   5. variant_id updated to correct dialect
--   6. ETL picks up the now-classified phrase
--
-- NOTE: ETL must filter variant_confidence >= 0.7 before export
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
--   content_unit.variant_id is NULLABLE by design to support
--   dynamic dialect discovery. But there is no way to know
--   HOW CERTAIN the Router is about its classification.
--   A phrase classified with 40% confidence is unreliable
--   training data. Without a confidence score, the ETL cannot
--   filter out low-quality classifications.
--
-- SOLUTION:
--   Add variant_confidence FLOAT column (0.0 to 1.0).
--   Values:
--     NULL  = not yet processed by Semantic Router
--     0.0   = Router attempted classification, failed
--     0.5   = Router uncertain (code-switching detected)
--     1.0   = Router certain or manually verified
--
--   ETL EXPORT RULE:
--     WHERE variant_id IS NOT NULL
--     AND   variant_confidence >= 0.7
--
-- EXAMPLE:
--   "Jamme ja" -> Router -> variant='nap-IT', confidence=0.92
--   "???"      -> Router -> variant='und',    confidence=0.0
-- ============================================================

ALTER TABLE content_unit
    ADD COLUMN IF NOT EXISTS variant_confidence FLOAT
    CHECK (variant_confidence IS NULL
        OR (variant_confidence >= 0.0 AND variant_confidence <= 1.0));

COMMENT ON COLUMN content_unit.variant_confidence IS
    'Semantic Router classification confidence (0.0-1.0). '
    'NULL = unprocessed. ETL exports only rows >= 0.7. '
    'Populated by Router during ingestion or background job.';

-- ============================================================
-- FIX 4: v_content_full_context WITH security_invoker
-- ============================================================
-- PROBLEM:
--   The VIEW was created without security_invoker = true.
--   PostgreSQL default for views is SECURITY DEFINER: the view
--   runs with the permissions of the user who CREATED it
--   (admin), bypassing all RLS policies completely.
--
--   Real scenario: a student user restricted by RLS calls
--     SELECT * FROM v_content_full_context
--   Without security_invoker they see ALL rows from ALL
--   students because the query runs as admin.
--
-- SOLUTION:
--   DROP VIEW first (CREATE OR REPLACE cannot change column
--   order in PostgreSQL - would cause error 42P16).
--   Then CREATE VIEW with security_invoker = true.
--   Now RLS policies are enforced correctly for every caller.
--
-- SAFE: DROP VIEW does not delete any table data.
--       Only the view definition is removed and recreated.
-- ============================================================

DROP VIEW IF EXISTS v_content_full_context;

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
--   a different model and different vector dimensions.
--   A vector from Poro is NOT compatible with one from Aya.
--   Without model_id in vector_index, the Semantic Router
--   cannot isolate which vectors belong to which model.
--   Result: Finnish query compared against Italian vectors
--   -> semantically wrong results.
--
-- SOLUTION:
--   Add model_id FK to vector_index referencing ai_model_registry.
--   ON DELETE SET NULL: if a model is removed, its vectors are
--   not deleted - they become unassigned for re-indexing later.
--
-- EXAMPLE:
--   Poro generates embedding for "Mennaan" ->
--   vector_index: pinecone_id='vec_123', model_id=1 (Poro)
--   Router receives Finnish query ->
--   searches ONLY vectors WHERE model_id = 1 (Poro)
-- ============================================================

ALTER TABLE vector_index
    ADD COLUMN IF NOT EXISTS model_id INT
    REFERENCES ai_model_registry(model_id)
    ON DELETE SET NULL
    ON UPDATE CASCADE;

COMMENT ON COLUMN vector_index.model_id IS
    'FK to ai_model_registry. Identifies which AI model generated '
    'this vector. Required for per-model RAG isolation: '
    'Finnish queries search only Poro vectors (model_id=1), '
    'Italian dialect queries search only Aya vectors (model_id=2).';

-- ============================================================
-- VERIFICATION QUERIES (uncomment to run after COMMIT)
-- ============================================================
-- SELECT 'FIX1' AS fix,
--   CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
-- FROM information_schema.triggers
-- WHERE event_object_table = 'language_variant'
--   AND trigger_name = 'trg_normalize_iso_code';
--
-- SELECT 'FIX2' AS fix,
--   CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
-- FROM language_variant WHERE iso_code = 'und';
--
-- SELECT 'FIX3' AS fix,
--   CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
-- FROM information_schema.columns
-- WHERE table_name = 'content_unit'
--   AND column_name = 'variant_confidence';
--
-- SELECT 'FIX4' AS fix,
--   CASE WHEN definition ILIKE '%security_invoker%'
--        THEN 'OK' ELSE 'MISSING' END AS status
-- FROM pg_views WHERE viewname = 'v_content_full_context';
--
-- SELECT 'FIX5' AS fix,
--   CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
-- FROM information_schema.columns
-- WHERE table_name = 'vector_index'
--   AND column_name = 'model_id';

COMMIT;
