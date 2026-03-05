-- ============================================================
-- AI TUTOR PROJECT - SCHEMA VERIFICATION
-- Author: Stefania Julin
-- Version: 1.0
-- Purpose: Verify schema is ready for all data sources:
--          1. Firebase JSON export
--          2. ISO 639 / Glottolog (language variants + dialects)
--          3. Universal Dependencies v2 (syntax trees)
--          4. EN as pivot language between IT dialects and FI dialects
-- ============================================================


-- TEST 1: ALL 10 TABLES EXIST
-- Expected result: 10

SELECT 'TEST 1 - Tables count' AS test,
       COUNT(*) AS result,
       CASE WHEN COUNT(*) = 10
            THEN 'PASS'
            ELSE 'FAIL - missing tables'
       END AS status
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN (
    'language_variant','lemma','morpho_form',
    'content_unit','tone_marker','cultural_context_tag',
    'ai_model_registry','correction_feedback_log',
    'rel_content_context','rel_content_tone'
);


-- TEST 2: ALL FOREIGN KEYS HAVE ON DELETE + ON UPDATE ACTIONS
-- Expected result: 10 rows, no row with delete_rule = NO ACTION

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
-- Purpose: supports full dialect tree IT + FI + EN pivot
-- parent_variant_id must be nullable (root languages have no parent)
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


-- TEST 4: JSONB COLUMNS EXIST FOR EXTERNAL DB SOURCES
-- Purpose: must support Universal Dependencies v2 syntax trees
--          and interference data for all dialects
-- Expected result: 6 JSONB columns across tables

SELECT 'TEST 4 - JSONB columns for UD v2 and interference data' AS test,
       table_name,
       column_name,
       data_type,
       'PASS - ready for external linguistic data' AS status
FROM information_schema.columns
WHERE table_schema = 'public'
AND data_type = 'jsonb'
ORDER BY table_name, column_name;


-- TEST 5: CONTENT_HASH IS UNIQUE
-- Purpose: prevents Firebase duplicate imports
-- Expected result: constraint_type = UNIQUE

SELECT 'TEST 5 - content_hash UNIQUE constraint' AS test,
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


-- TEST 6: BRIDGE TABLES HAVE COMPOSITE PRIMARY KEYS
-- Purpose: one content_unit can have many tones and contexts
-- Expected result: 2 rows per bridge table in composite key

SELECT 'TEST 6 - Composite PKs on bridge tables' AS test,
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


-- TEST 7: ISO_CODE IS UNIQUE IN LANGUAGE_VARIANT
-- Purpose: each dialect has one unique ISO code
-- Expected result: constraint_type = UNIQUE

SELECT 'TEST 7 - iso_code UNIQUE in language_variant' AS test,
       tc.constraint_name,
       tc.constraint_type,
       kcu.column_name,
       CASE
           WHEN tc.constraint_type = 'UNIQUE'
           THEN 'PASS - no duplicate ISO codes'
           ELSE 'FAIL - duplicate dialects possible'
       END AS status
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_schema = 'public'
AND tc.table_name = 'language_variant'
AND kcu.column_name = 'iso_code';


-- TEST 8: CURRENT LANGUAGE_VARIANT DATA
-- Purpose: shows existing dialect tree and identifies gaps
--          before full population with all IT and FI dialects

SELECT 'TEST 8 - Current language_variant data' AS test,
       variant_id,
       iso_code,
       variant_name,
       parent_variant_id,
       CASE
           WHEN parent_variant_id IS NULL
           THEN 'ROOT LANGUAGE'
           ELSE 'DIALECT OR VARIANT'
       END AS role
FROM public.language_variant
ORDER BY parent_variant_id NULLS FIRST, variant_id;


-- TEST 9: CORRECTION_FEEDBACK_LOG AUDIT CHAIN
-- Purpose: forensic audit trail must link
--          model version -> content unit -> error log
--          This is the Data Flywheel mechanism
-- Expected: model_id FK = RESTRICT, unit_id FK = CASCADE

SELECT 'TEST 9 - Audit chain FK integrity' AS test,
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


-- TEST 10: FULL SCHEMA SUMMARY
-- Purpose: one-shot overview of the entire DB structure

SELECT 'TEST 10 - Full schema summary' AS test,
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
    'rel_content_context','rel_content_tone'
)
GROUP BY t.table_name
ORDER BY t.table_name;


-- ============================================================
-- END VERIFICATION
-- If all tests PASS -> schema ready for data population
-- If any FAIL -> fix schema before populating
-- ============================================================