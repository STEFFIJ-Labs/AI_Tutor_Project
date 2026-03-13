-- ============================================================
-- schema_fixes_v3_2.sql
-- Author: Stefania Julin | AI Tutor Project - Progetto DATA
-- Date: 2026-03-12
-- Version: 3.2  (replaces v3.1)
-- Repository: STEFFIJ-Labs/AI_Tutor_Project
--
-- CHANGES FROM v3.1:
--   FIX 5 rewritten completely.
--   v3.1 FIX 5 added model_id as NULLABLE — incorrect for a
--   weak entity that requires both owners to exist.
--   v3.2 FIX 5 adds NOT NULL, enforces CASCADE on unit_id FK,
--   and adds a natural uniqueness constraint.
--   All other fixes (1-4) are identical to v3.1.
--
-- FIXES INCLUDED:
--   FIX 1: ISO code normalization trigger
--   FIX 2: language_variant 'und' fallback row
--   FIX 3: content_unit variant_confidence column
--   FIX 4: v_content_full_context security_invoker
--   FIX 5: vector_index weak entity enforcement  ← REWRITTEN
--          (was: nullable model_id added)
--          (now: NOT NULL + CASCADE + uniqueness constraint)
--
-- HOW TO DEPLOY:
--   Option A (recommended): GitHub Actions deploys automatically
--                           on push to main branch.
--   Option B (manual):      Paste in Supabase SQL Editor.
--
-- SAFE TO RUN MULTIPLE TIMES: all statements use IF NOT EXISTS,
-- CREATE OR REPLACE, or DO $$ blocks with existence checks.
-- Idempotent.
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
-- FIX 5: vector_index WEAK ENTITY ENFORCEMENT  ← REWRITTEN
-- ============================================================
-- THEORY (Elmasri & Navathe, Chapter 7 — Weak Entities):
--   A weak entity has no key of its own. It depends on one or
--   more owner entities (its "identifying owners") to exist.
--   vector_index has TWO owners:
--     - content_unit   (the phrase that was embedded)
--     - ai_model_registry (the model that generated the vector)
--   This means a vector_index row cannot exist if either owner
--   is missing. This existence dependency must be enforced at
--   the database level, not just in application code.
--
-- WHAT WAS WRONG IN v3.1:
--   FIX 5 in v3.1 added model_id WITHOUT NOT NULL.
--   A nullable FK does not enforce existence dependency.
--   A row could be inserted with model_id = NULL, which means
--   "a vector that belongs to no model" — semantically invalid
--   for a weak entity. The weak entity dependency was declared
--   in the ER diagram but not enforced in the relational schema.
--
-- THREE SUB-FIXES IN THIS BLOCK:
--
--   SUB-FIX 5a: ADD model_id NOT NULL (if not already added)
--     model_id must be NOT NULL because vector_index is a weak
--     entity that depends on ai_model_registry. A vector that
--     has no model is a ghost record — it breaks RAG isolation.
--     ON DELETE SET NULL is kept intentionally: if a model is
--     removed from the registry, its vectors are not deleted
--     immediately but become unassigned (model_id = NULL after
--     SET NULL) so they can be re-indexed with a replacement
--     model. This is a deliberate exception to the strict weak
--     entity rule, justified by pipeline recovery requirements.
--     NOTE: SET NULL and NOT NULL together are contradictory.
--     The correct choice for this pipeline is:
--       - ON DELETE RESTRICT (block model deletion if vectors
--         reference it) → stronger protection, chosen here.
--
--   SUB-FIX 5b: ENFORCE CASCADE on unit_id FK
--     unit_id → content_unit must use ON DELETE CASCADE.
--     If a content_unit row is deleted, its vectors in Pinecone
--     are no longer retrievable and the index entry is orphaned.
--     CASCADE removes the vector_index row automatically,
--     keeping the relational schema consistent with Pinecone.
--     The existing FK constraint name in Supabase auto-generated
--     schemas is typically: vector_index_unit_id_fkey
--     This block drops and recreates it with CASCADE.
--
--   SUB-FIX 5c: NATURAL UNIQUENESS CONSTRAINT
--     Each (unit_id, model_id) pair should produce at most one
--     vector in Pinecone. Without this constraint, a bug in the
--     ETL pipeline could insert duplicate vectors for the same
--     phrase+model combination, causing the Router to return
--     duplicate results. The UNIQUE constraint prevents this.
--     vector_id (the Pinecone ID) is already the PK, but the
--     business rule is enforced explicitly here.
--
-- REFERENTIAL ACTION SUMMARY FOR vector_index:
--   unit_id  FK → ON DELETE CASCADE,  ON UPDATE CASCADE
--     Reason: if the content disappears, the vector is useless.
--   model_id FK → ON DELETE RESTRICT,  ON UPDATE CASCADE
--     Reason: block deletion of a model that still has indexed
--     vectors. Force the operator to re-index first.
-- ============================================================

-- SUB-FIX 5a: add model_id column if v3.1 was never deployed,
-- OR enforce NOT NULL if v3.1 was already deployed (column exists).
-- The DO block handles both cases safely.
DO $$
BEGIN
    -- Case 1: column does not exist yet (v3.1 was not deployed)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'vector_index'
          AND column_name  = 'model_id'
    ) THEN
        ALTER TABLE vector_index
            ADD COLUMN model_id INT NOT NULL
            REFERENCES ai_model_registry(model_id)
            ON DELETE RESTRICT
            ON UPDATE CASCADE;

        RAISE NOTICE 'SUB-FIX 5a: model_id column added as NOT NULL.';

    -- Case 2: column exists but is nullable (v3.1 was deployed)
    ELSIF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'vector_index'
          AND column_name  = 'model_id'
          AND is_nullable  = 'YES'
    ) THEN
        -- Before adding NOT NULL, fill any existing NULLs.
        -- Uses model_id = 1 (Poro) as the safe default.
        -- If your registry uses a different ID for the first
        -- model, change the value 1 below accordingly.
        UPDATE vector_index
        SET model_id = 1
        WHERE model_id IS NULL;

        ALTER TABLE vector_index
            ALTER COLUMN model_id SET NOT NULL;

        -- Also fix the ON DELETE action: drop old FK (SET NULL)
        -- and recreate with RESTRICT.
        ALTER TABLE vector_index
            DROP CONSTRAINT IF EXISTS vector_index_model_id_fkey;

        ALTER TABLE vector_index
            ADD CONSTRAINT vector_index_model_id_fkey
            FOREIGN KEY (model_id)
            REFERENCES ai_model_registry(model_id)
            ON DELETE RESTRICT
            ON UPDATE CASCADE;

        RAISE NOTICE 'SUB-FIX 5a: model_id enforced NOT NULL. NULLs backfilled with model_id=1.';

    ELSE
        RAISE NOTICE 'SUB-FIX 5a: model_id already NOT NULL. No action needed.';
    END IF;
END $$;

-- SUB-FIX 5b: enforce ON DELETE CASCADE on unit_id FK.
-- Drops the existing FK (whatever its current action) and
-- recreates it with CASCADE. Supabase default name used.
-- Safe to run even if the constraint was already CASCADE.
ALTER TABLE vector_index
    DROP CONSTRAINT IF EXISTS vector_index_unit_id_fkey;

ALTER TABLE vector_index
    ADD CONSTRAINT vector_index_unit_id_fkey
    FOREIGN KEY (unit_id)
    REFERENCES content_unit(unit_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE;

-- SUB-FIX 5c: natural uniqueness constraint.
-- One Pinecone vector per (content_unit, model) pair.
-- Prevents duplicate embeddings from ETL bugs or re-runs.
ALTER TABLE vector_index
    DROP CONSTRAINT IF EXISTS uq_vector_unit_model;

ALTER TABLE vector_index
    ADD CONSTRAINT uq_vector_unit_model
    UNIQUE (unit_id, model_id);

COMMENT ON CONSTRAINT uq_vector_unit_model ON vector_index IS
    'Natural uniqueness: each content_unit is embedded once per '
    'model. Prevents duplicate Pinecone vectors from ETL re-runs.';

COMMENT ON COLUMN vector_index.model_id IS
    'FK to ai_model_registry. NOT NULL: weak entity existence '
    'dependency on ai_model_registry (Elmasri ch.7). '
    'ON DELETE RESTRICT: model cannot be deleted while vectors '
    'still reference it. Re-index first, then delete. '
    'Finnish queries search only Poro vectors (model_id=1), '
    'Italian dialect queries search only Aya vectors (model_id=2).';

-- ============================================================
-- VERIFICATION QUERIES
-- Run these individually after COMMIT to confirm all fixes.
-- ============================================================

-- FIX 1: trigger exists?
-- SELECT trigger_name, event_manipulation, action_timing
-- FROM information_schema.triggers
-- WHERE trigger_schema = 'public'
--   AND event_object_table = 'language_variant';

-- FIX 2: 'und' row exists?
-- SELECT variant_id, iso_code, variant_name
-- FROM language_variant WHERE iso_code = 'und';

-- FIX 3: variant_confidence column exists with CHECK?
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_schema = 'public'
--   AND table_name   = 'content_unit'
--   AND column_name  = 'variant_confidence';

-- FIX 4: view uses security_invoker?
-- SELECT viewname, definition
-- FROM pg_views
-- WHERE schemaname = 'public'
--   AND viewname   = 'v_content_full_context';

-- FIX 5a: model_id is NOT NULL?
-- SELECT column_name, is_nullable
-- FROM information_schema.columns
-- WHERE table_schema = 'public'
--   AND table_name   = 'vector_index'
--   AND column_name  = 'model_id';

-- FIX 5b: unit_id FK uses CASCADE?
-- SELECT conname, confdeltype, confupdtype
-- FROM pg_constraint
-- WHERE conrelid = 'vector_index'::regclass
--   AND contype  = 'f';
-- Expected: confdeltype = 'c' (CASCADE) for unit_id_fkey
--           confdeltype = 'r' (RESTRICT) for model_id_fkey

-- FIX 5c: uniqueness constraint exists?
-- SELECT conname, contype
-- FROM pg_constraint
-- WHERE conrelid = 'vector_index'::regclass
--   AND conname  = 'uq_vector_unit_model';

COMMIT;
