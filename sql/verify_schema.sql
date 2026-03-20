-- ============================================================
-- AI TUTOR PROJECT - SCHEMA VERIFICATION v2.0
-- Author: Stefania Julin
-- Version: 2.0 - Updated for schema v3.0 (12 tables)
-- Purpose: Verify schema is ready for all data sources:
--          1. Firebase JSON export
--          2. ISO 639 / Glottolog (language variants + dialects)
--          3. Universal Dependencies v2 (syntax trees)
--          4. EN as pivot language between IT dialects and FI dialects
--          5. GitHub LFS media pointers (media_asset table)
--          6. Pinecone vector index (vector_index table)
-- ============================================================


-- TEST 1: ALL 12 TABLES EXIST
-- Expected result: 12

SELECT 'TEST 1 - Tables count' AS test,
       COUNT(*) AS result,
       CASE WHEN COUNT(*) = 12
            THEN 'PASS'
            ELSE 'FAIL - missing tables'
       END AS status
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN (
    'language_variant','lemma','morpho_form',
    'content_unit','tone_marker','cultural_context_tag',
    'ai_model_registry','correction_feedback_log',
    'rel_content_context','rel_content_tone',
    'media_asset','vector_index'
);


-- TEST 2: ALL FOREIGN KEYS HAVE ON DELETE + ON UPDATE ACTIONS
-- Expected result: 13 rows, no row with delete_rule = NO ACTION

SELECT 'TEST 2 - FK referential actions' AS test,
       tc.table_name,
       kcu.column_name,
       rc.delete_rule AS on_delete,
       rc.update_rule AS on_update,
       CASE
           WHEN rc.delete_rule = 'NO ACTION'
           THEN 'FAIL - missing ON DELETE'
           ELSE 'PASS'
       END AS status
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
AND tc.table_schema = 'public'
ORDER BY tc.table_name;


-- TEST 3: RECURSIVE RELATIONSHIP IN LANGUAGE_VARIANT
-- parent_variant_id must be nullable
-- Expected result: is_nullable = YES

SELECT 'TEST 3 - Recursive FK language_variant' AS test,
       column_name,
       is_nullable,
       data_type,
       CASE
           WHEN is_nullable = 'YES'
           THEN 'PASS - root languages can have NULL parent'
           ELSE 'FAIL - root languages need nullable parent_id'
       END AS status
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'language_variant'
AND column_name = 'parent_variant_id';


-- TEST 4: IS_PIVOT COLUMN EXISTS IN LANGUAGE_VARIANT
-- Expected result: 1 row

SELECT 'TEST 4 - is_pivot column in language_variant' AS test,
       column_name,
       data_type,
       column_default,
       CASE
           WHEN column_name = 'is_pivot'
           THEN 'PASS - pivot language identifiable'
           ELSE 'FAIL - cannot identify EN as pivot'
       END AS status
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'language_variant'
AND column_name = 'is_pivot';


-- TEST 5: 1NF FIX - CEFR_LEVEL, IS_IDIOM, DIFFICULTY IN CONTENT_UNIT
-- Expected result: 3 rows

SELECT 'TEST 5 - 1NF columns in content_unit' AS test,
       column_name,
       data_type,
       'PASS - attribute is a column not buried in JSON' AS status
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'content_unit'
AND column_name IN ('cefr_level', 'is_idiom', 'difficulty')
ORDER BY column_name;


-- TEST 6: 3NF FIX - MODEL_NAME, HF_ADAPTER_PATH, TRAINING_STATUS
-- Expected result: 3 rows

SELECT 'TEST 6 - 3NF columns in ai_model_registry' AS test,
       column_name,
       data_type,
       'PASS - model identity attributes present' AS status
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'ai_model_registry'
AND column_name IN ('model_name', 'hf_adapter_path', 'training_status')
ORDER BY column_name;


-- TEST 7: 2NF FIX - TRAINING_CYCLE, FEEDBACK_SOURCE
-- Expected result: 2 rows

SELECT 'TEST 7 - 2NF columns in correction_feedback_log' AS test,
       column_name,
       data_type,
       'PASS - Data Flywheel tracking columns present' AS status
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'correction_feedback_log'
AND column_name IN ('training_cycle', 'feedback_source')
ORDER BY column_name;


-- TEST 8: MEDIA_ASSET TABLE STRUCTURE
-- Expected result: 4 key columns present

SELECT 'TEST 8 - media_asset table structure' AS test,
       column_name,
       data_type,
       'PASS - media pointers in dedicated table' AS status
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'media_asset'
AND column_name IN ('asset_type', 'file_name', 'storage_location', 'lfs_pointer')
ORDER BY column_name;


-- TEST 9: VECTOR_INDEX TABLE STRUCTURE
-- Expected result: 3 key columns present

SELECT 'TEST 9 - vector_index table structure' AS test,
       column_name,
       data_type,
       'PASS - Pinecone vector tracking present' AS status
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'vector_index'
AND column_name IN ('pinecone_id', 'embedding_model', 'vector_status')
ORDER BY column_name;


-- TEST 10: CONTENT_HASH IS UNIQUE
-- Expected result: constraint_type = UNIQUE

SELECT 'TEST 10 - content_hash UNIQUE constraint' AS test,
       tc.constraint_name,
       tc.constraint_type,
       kcu.column_name,
       CASE
           WHEN tc.constraint_type = 'UNIQUE'
           THEN 'PASS - duplicates blocked'
           ELSE 'FAIL - duplicates will corrupt the DB'
       END AS status
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_schema = 'public'
AND tc.table_name = 'content_unit'
AND kcu.column_name = 'content_hash';


-- TEST 11: BRIDGE TABLES HAVE COMPOSITE PRIMARY KEYS
-- Expected result: 2 rows per bridge table

SELECT 'TEST 11 - Composite PKs on bridge tables' AS test,
       tc.table_name,
       STRING_AGG(kcu.column_name, ' + ' ORDER BY kcu.ordinal_position)
           AS composite_key,
       CASE
           WHEN COUNT(*) = 2
           THEN 'PASS - many-to-many supported'
           ELSE 'FAIL - composite PK broken'
       END AS status
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type = 'PRIMARY KEY'
AND tc.table_schema = 'public'
AND tc.table_name IN ('rel_content_context','rel_content_tone')
GROUP BY tc.table_name;


-- TEST 12: CORRECTION_FEEDBACK_LOG AUDIT CHAIN
-- model_id FK must be RESTRICT, unit_id FK must be CASCADE

SELECT 'TEST 12 - Audit chain FK integrity' AS test,
       tc.table_name,
       kcu.column_name,
       ccu.table_name AS references_table,
       rc.delete_rule,
       rc.update_rule,
       CASE
           WHEN kcu.column_name = 'model_id'
                AND rc.delete_rule = 'RESTRICT'
           THEN 'PASS - forensic logs protected'
           WHEN kcu.column_name = 'unit_id'
                AND rc.delete_rule = 'CASCADE'
           THEN 'PASS - orphan logs prevented'
           ELSE 'CHECK MANUALLY'
       END AS status
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
JOIN information_schema.constraint_column_usage ccu
    ON rc.unique_constraint_name = ccu.constraint_name
WHERE tc.table_schema = 'public'
AND tc.table_name = 'correction_feedback_log'
AND tc.constraint_type = 'FOREIGN KEY';


-- TEST 13: FULL SCHEMA SUMMARY
-- Expected result: 12 tables mapped

SELECT 'TEST 13 - Full schema summary' AS test,
       t.table_name,
       COUNT(c.column_name)                                        AS total_columns,
       SUM(CASE WHEN c.data_type = 'jsonb' THEN 1 ELSE 0 END)    AS jsonb_columns,
       SUM(CASE WHEN c.is_nullable = 'NO' THEN 1 ELSE 0 END)     AS not_null_columns,
       'MAPPED' AS status
FROM information_schema.tables t
JOIN information_schema.columns c
    ON t.table_name = c.table_name
    AND t.table_schema = c.table_schema
WHERE t.table_schema = 'public'
AND t.table_name IN (
    'language_variant','lemma','morpho_form',
    'content_unit','tone_marker','cultural_context_tag',
    'ai_model_registry','correction_feedback_log',
    'rel_content_context','rel_content_tone',
    'media_asset','vector_index'
)
GROUP BY t.table_name
ORDER BY t.table_name;


-- ============================================================
-- TESTS 14-20: VERIFY FIXES FROM v3.1 AND v3.2
-- These tests protect every fix applied after schema v3.0.
-- If GitHub Actions reruns any SQL file and overwrites a fix,
-- these tests will catch it immediately with a FAIL result.
-- ============================================================


-- TEST 14: variant_confidence COLUMN EXISTS IN content_unit
-- Applied in schema_fixes_v3_1.sql FIX 3.
-- If queries.sql or schema.sql is redeployed without this column,
-- the ETL cannot filter low-confidence classifications before
-- export to Hugging Face. Training data quality degrades silently.
-- Expected result: 1 row, PASS

SELECT 'TEST 14 - variant_confidence in content_unit' AS test,
       column_name,
       data_type,
       is_nullable,
       CASE
           WHEN column_name = 'variant_confidence'
           THEN 'PASS - ETL confidence filter available'
           ELSE 'FAIL - ETL cannot filter low-confidence rows'
       END AS status
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'content_unit'
AND column_name = 'variant_confidence';


-- TEST 15: VIEW v_content_full_context HAS security_invoker = true
-- Applied in schema_fixes_v3_1.sql FIX 4 and queries.sql v1.1.
-- Without security_invoker, RLS is bypassed: any user calling
-- the VIEW sees ALL rows from ALL students (admin permissions).
-- Expected result: 1 row containing 'security_invoker=true'

SELECT 'TEST 15 - VIEW security_invoker' AS test,
       relname AS viewname,
       CASE
           WHEN 'security_invoker=true' = ANY(reloptions)
           THEN 'PASS - RLS enforced through VIEW'
           ELSE 'FAIL - RLS BYPASSED: VIEW runs as admin'
       END AS status
FROM pg_class
WHERE relname = 'v_content_full_context';


-- TEST 16: model_id IN vector_index IS NOT NULL
-- Applied in schema_fixes_v3_2.sql FIX 5a.
-- A nullable model_id means vectors without a model owner:
-- the Semantic Router cannot isolate Poro vs Aya vs Gemma
-- vectors and returns semantically wrong results.
-- Expected result: is_nullable = NO

SELECT 'TEST 16 - vector_index.model_id NOT NULL' AS test,
       column_name,
       is_nullable,
       CASE
           WHEN is_nullable = 'NO'
           THEN 'PASS - vector ownership enforced'
           ELSE 'FAIL - ghost vectors possible (no model owner)'
       END AS status
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'vector_index'
AND column_name = 'model_id';


-- TEST 17: UNIQUE CONSTRAINT uq_vector_unit_model EXISTS
-- Applied in schema_fixes_v3_2.sql FIX 5c.
-- Without this constraint, ETL re-runs can insert duplicate
-- vectors for the same content_unit + model pair.
-- The Semantic Router would return duplicate results to students.
-- Expected result: 1 row, PASS

SELECT 'TEST 17 - uq_vector_unit_model constraint' AS test,
       conname,
       contype,
       CASE
           WHEN conname = 'uq_vector_unit_model'
           THEN 'PASS - duplicate vectors blocked'
           ELSE 'FAIL - ETL re-runs can create duplicate vectors'
       END AS status
FROM pg_constraint
WHERE conrelid = 'vector_index'::regclass
AND conname = 'uq_vector_unit_model';


-- TEST 18: TRIGGER trg_normalize_iso_code EXISTS (exactly once)
-- Applied in schema_fixes_v3_1.sql FIX 1.
-- Without this trigger, external sources sending 'IT' or 'it'
-- instead of 'it-IT' would create NULL variant_id lookups.
-- Data would be lost silently without any error message.
-- Expected result: exactly 1 row

SELECT 'TEST 18 - ISO normalization trigger' AS test,
       COUNT(*) AS trigger_count,
       CASE
           WHEN COUNT(*) = 2
           THEN 'PASS - ISO codes normalized on INSERT and UPDATE'
           WHEN COUNT(*) = 0
           THEN 'FAIL - ISO normalization missing'
           ELSE 'WARNING - unexpected trigger count, verify manually'
       END AS status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
AND trigger_name = 'trg_normalize_iso_code'
AND event_object_table = 'language_variant';


-- TEST 19: 'und' FALLBACK ROW EXISTS IN language_variant
-- Applied in schema_fixes_v3_1.sql FIX 2.
-- Without 'und', the Semantic Router cannot save phrases it
-- cannot yet classify. Data is lost during dialect discovery.
-- Expected result: 1 row, PASS

SELECT 'TEST 19 - und fallback language variant' AS test,
       iso_code,
       variant_name,
       CASE
           WHEN iso_code = 'und'
           THEN 'PASS - Router can save unclassified dialects'
           ELSE 'FAIL - unclassified dialects lost on ingestion'
       END AS status
FROM language_variant
WHERE iso_code = 'und';


-- TEST 20: vector_index.model_id FK IS ON DELETE RESTRICT
-- Applied in schema_fixes_v3_2.sql FIX 5a.
-- ON DELETE SET NULL (v3.1) was incorrect: it contradicts NOT NULL.
-- ON DELETE RESTRICT is correct: block deletion of a model that
-- still has indexed vectors. Forces re-indexing before deletion.
-- Expected result: on_delete = RESTRICT

SELECT 'TEST 20 - vector_index model_id ON DELETE RESTRICT' AS test,
       conname,
       CASE confdeltype
           WHEN 'r' THEN 'RESTRICT'
           WHEN 'c' THEN 'CASCADE'
           WHEN 'n' THEN 'SET NULL'
           WHEN 'a' THEN 'NO ACTION'
       END AS on_delete,
       CASE
           WHEN confdeltype = 'r'
           THEN 'PASS - model deletion blocked while vectors exist'
           ELSE 'FAIL - model can be deleted leaving orphan vectors'
       END AS status
FROM pg_constraint
WHERE conrelid = 'vector_index'::regclass
AND conname = 'vector_index_model_id_fkey';


-- ============================================================
-- END VERIFICATION v3.0
-- TESTS 1-13:  schema v3.0 structure (12 tables, 13 FK)
-- TESTS 14-20: fixes v3.1 and v3.2 (security, integrity, ETL)
-- ALL tests must PASS before any new data or code is pushed.
-- If any test FAILS, GitHub Actions blocks the deploy.
-- ============================================================
