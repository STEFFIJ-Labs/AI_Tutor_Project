-- ============================================================
-- AI TUTOR PROJECT - SQL QUERIES
-- Author: Stefania Julin
-- Version: 1.1
-- Purpose: 6 meaningful queries + 1 VIEW for university assignment
-- Database: AI Tutor Database IN (PostgreSQL 17.6)
-- Schema version: 3.1
-- v1.1 changes: VIEW updated with security_invoker=true and variant_confidence
-- ============================================================
DROP VIEW IF EXISTS v_content_full_context;

-- ============================================================
-- QUERY 1 - JOIN
-- Information need:
--   How many Italian phrases exist for each cultural theme?
--   This is needed to evaluate corpus coverage before AI training.
--   Themes with fewer than 10 phrases may produce undertrained models.
-- Tables: content_unit, rel_content_context, cultural_context_tag
-- ============================================================

SELECT
    cct.context_name                        AS theme,
    COUNT(cu.unit_id)                       AS phrase_count
FROM content_unit cu
JOIN rel_content_context rcc
    ON cu.unit_id = rcc.unit_id
JOIN cultural_context_tag cct
    ON rcc.context_id = cct.context_id
JOIN language_variant lv
    ON cu.variant_id = lv.variant_id
WHERE lv.iso_code = 'it-IT'
AND   cu.content_type = 'phrase'
GROUP BY cct.context_name
ORDER BY phrase_count DESC;


-- ============================================================
-- QUERY 2 - GROUP BY
-- Information need:
--   What is the CEFR level distribution of the corpus?
--   A balanced corpus (roughly equal A1/A2/B1/B2/C1) is required
--   for the AI models to learn across all student proficiency levels.
--   An imbalanced corpus will produce a model biased toward one level.
-- Table: content_unit
-- ============================================================

SELECT
    cefr_level,
    COUNT(*)                                AS total_units,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM content_unit
WHERE cefr_level IS NOT NULL
GROUP BY cefr_level
ORDER BY cefr_level;


-- ============================================================
-- QUERY 3 - JOIN + GROUP BY
-- Information need:
--   Which cultural themes have the most formal versus informal content?
--   The Semantic Router uses tone markers in real time to select
--   the appropriate register when generating responses for students.
--   Themes with no formal content cannot be used in academic contexts.
-- Tables: content_unit, rel_content_tone, tone_marker,
--         rel_content_context, cultural_context_tag
-- ============================================================

SELECT
    cct.context_name                        AS theme,
    tm.tone_name                            AS register,
    COUNT(cu.unit_id)                       AS unit_count
FROM content_unit cu
JOIN rel_content_tone rct
    ON cu.unit_id = rct.unit_id
JOIN tone_marker tm
    ON rct.tone_id = tm.tone_id
JOIN rel_content_context rcc
    ON cu.unit_id = rcc.unit_id
JOIN cultural_context_tag cct
    ON rcc.context_id = cct.context_id
GROUP BY cct.context_name, tm.tone_name
ORDER BY cct.context_name, unit_count DESC;


-- ============================================================
-- QUERY 4 - SUBQUERY
-- Information need:
--   Which Italian lemmas have no morphological forms registered?
--   Lemmas without morpho_form entries are incomplete for AI training.
--   The model cannot learn conjugations or declensions without them.
--   These gaps must be filled before the training pipeline runs.
-- Tables: lemma, morpho_form, language_variant
-- ============================================================

SELECT
    l.lemma_id,
    l.text_root,
    l.grammatical_category
FROM lemma l
JOIN language_variant lv
    ON l.variant_id = lv.variant_id
WHERE lv.iso_code = 'it-IT'
AND l.lemma_id NOT IN (
    SELECT DISTINCT lemma_id
    FROM morpho_form
)
ORDER BY l.grammatical_category, l.text_root;


-- ============================================================
-- QUERY 5 - JOIN + SUBQUERY
-- Information need:
--   Which content units have both an audio file and an image file
--   registered as media assets?
--   Multimodal content (text + audio + image) is the highest quality
--   training data for the AI models. This query identifies how many
--   units are ready for multimodal training versus text-only training.
-- Tables: content_unit, media_asset, language_variant
-- ============================================================

SELECT
    cu.unit_id,
    cu.content_raw,
    lv.iso_code,
    cu.cefr_level
FROM content_unit cu
JOIN language_variant lv
    ON cu.variant_id = lv.variant_id
WHERE cu.unit_id IN (
    SELECT unit_id
    FROM media_asset
    WHERE asset_type = 'audio'
)
AND cu.unit_id IN (
    SELECT unit_id
    FROM media_asset
    WHERE asset_type = 'image'
)
ORDER BY lv.iso_code, cu.cefr_level;


-- ============================================================
-- QUERY 6 - GROUP BY + SUBQUERY
-- Information need:
--   Which cultural themes have above-average content coverage
--   across all three languages (IT, FI, EN)?
--   A theme is well-covered only if it has sufficient content
--   in all three languages. Themes below average in any language
--   will produce unbalanced multilingual AI models.
-- Tables: content_unit, rel_content_context, cultural_context_tag,
--         language_variant
-- ============================================================

SELECT
    cct.context_name                        AS theme,
    COUNT(cu.unit_id)                       AS total_units,
    SUM(CASE WHEN lv.iso_code = 'it-IT' THEN 1 ELSE 0 END) AS count_IT,
    SUM(CASE WHEN lv.iso_code = 'fi-FI' THEN 1 ELSE 0 END) AS count_FI,
    SUM(CASE WHEN lv.iso_code = 'en-EN' THEN 1 ELSE 0 END) AS count_EN
FROM content_unit cu
JOIN rel_content_context rcc
    ON cu.unit_id = rcc.unit_id
JOIN cultural_context_tag cct
    ON rcc.context_id = cct.context_id
JOIN language_variant lv
    ON cu.variant_id = lv.variant_id
GROUP BY cct.context_name
HAVING COUNT(cu.unit_id) > (
    SELECT AVG(theme_count)
    FROM (
        SELECT COUNT(cu2.unit_id) AS theme_count
        FROM content_unit cu2
        JOIN rel_content_context rcc2
            ON cu2.unit_id = rcc2.unit_id
        GROUP BY rcc2.context_id
    ) AS theme_averages
)
ORDER BY total_units DESC;


-- ============================================================
-- VIEW
-- Information need:
--   Show a complete overview of all content units with their
--   language, CEFR level, tone and cultural theme in one place.
--   This view is used by the Semantic Router to retrieve
--   full context for RAG (Retrieval Augmented Generation)
--   without joining 5 tables every time.
--   Implemented as a VIEW because this join is executed
--   thousands of times per day in production and must be fast.
--
-- SECURITY NOTE (fix applied from schema_fixes_v3_1.sql):
--   security_invoker = true: the VIEW executes with the
--   permissions of the caller, not the creator (admin).
--   Without this, RLS policies on underlying tables are
--   completely bypassed - any user sees all rows.
--
-- v3.1 CHANGE: added cu.variant_confidence column.
--   Required by ETL to filter out low-confidence classifications
--   before export to Hugging Face (only rows >= 0.7 exported).
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
    cu.variant_confidence,
    lv.iso_code,
    lv.variant_name,
    lv.is_pivot,
    tm.tone_name,
    cct.context_name                        AS theme
FROM content_unit cu
JOIN language_variant lv
    ON cu.variant_id = lv.variant_id
LEFT JOIN rel_content_tone rct
    ON cu.unit_id = rct.unit_id
LEFT JOIN tone_marker tm
    ON rct.tone_id = tm.tone_id
LEFT JOIN rel_content_context rcc
    ON cu.unit_id = rcc.unit_id
LEFT JOIN cultural_context_tag cct
    ON rcc.context_id = cct.context_id;


-- ============================================================
-- END QUERIES
-- Query 1: JOIN
-- Query 2: GROUP BY
-- Query 3: JOIN + GROUP BY
-- Query 4: SUBQUERY
-- Query 5: JOIN + SUBQUERY
-- Query 6: GROUP BY + SUBQUERY
-- VIEW: v_content_full_context (Semantic Router RAG context)
-- ============================================================
