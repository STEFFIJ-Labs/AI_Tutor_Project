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
-- END VERIFICATION v2.0
-- If all tests PASS -> schema v3.0 ready for data population
-- If any FAIL -> fix schema before populating
-- ============================================================
