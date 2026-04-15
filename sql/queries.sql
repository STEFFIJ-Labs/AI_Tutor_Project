-- ============================================================
-- AI TUTOR PROJECT - SQL SCRIPTS
-- Author: Stefania Julin
-- Version: 1.2
-- Database: PostgreSQL 17.6 (Supabase)
-- Purpose: 6 analytical queries + 1 Semantic Router VIEW
-- ============================================================

-- 1. DISTRIBUTION ANALYSIS (GROUP BY)
-- Need: Count content units per CEFR level.
-- Context: Identifies data gaps (e.g., C1 shortage) to guide collection strategy.
SELECT 
    cefr_level, 
    COUNT(*) AS total_units
FROM content_unit
GROUP BY cefr_level
ORDER BY total_units DESC;

-- 2. LANGUAGE AND LEVEL AUDIT (JOIN)
-- Need: Retrieve 'Standard Finnish' sentences at 'B2' level.
-- Context: Linguist verification of complex grammar cases before model training.
SELECT 
    cu.content_raw, 
    lv.variant_name, 
    cu.cefr_level
FROM content_unit cu
JOIN language_variant lv ON cu.variant_id = lv.variant_id
WHERE lv.variant_name = 'Standard Finnish' 
AND cu.cefr_level = 'B2';

-- 3. THEMATIC COVERAGE AUDIT (JOIN + GROUP BY)
-- Need: List cultural themes and unit counts.
-- Context: Confirms corpus variety across all 18 thematic tags.
SELECT 
    cct.context_name, 
    COUNT(rcc.unit_id) AS unit_count
FROM cultural_context_tag cct
JOIN rel_content_context rcc ON cct.context_id = rcc.context_id
GROUP BY cct.context_name
ORDER BY unit_count DESC;

-- 4. VECTOR PIPELINE INTEGRITY CHECK (SUBQUERY)
-- Need: Identify units not yet processed by Pinecone.
-- Context: ETL maintenance. Ensures all records are searchable by the Semantic Router.
SELECT 
    unit_id, 
    content_raw
FROM content_unit
WHERE unit_id NOT IN (SELECT unit_id FROM vector_index);

-- 5. MORPHOLOGICAL DENSITY ANALYSIS (JOIN + GROUP BY)
-- Need: Richness of inflected forms per language.
-- Context: Audit of 2,490 morpho_form rows to detect grammatical imbalances.
SELECT 
    lv.variant_name, 
    COUNT(mf.form_id) AS total_morpho_forms
FROM language_variant lv
JOIN lemma l ON lv.variant_id = l.variant_id
JOIN morpho_form mf ON l.lemma_id = mf.lemma_id
GROUP BY lv.variant_name
ORDER BY total_morpho_forms DESC;

-- 6. LOANWORDS CROSS-LINGUAL ANALYSIS (SUBQUERY + HAVING)
-- Need: Shared lexical roots across multiple variants.
-- Context: Predicts linguistic interference and cross-lingual knowledge transfer.
SELECT 
    l.text_root, 
    string_agg(lv.variant_name, ' | ') AS shared_by
FROM lemma l
JOIN language_variant lv ON l.variant_id = lv.variant_id
WHERE l.text_root IN (
    SELECT text_root 
    FROM lemma 
    GROUP BY text_root 
    HAVING COUNT(DISTINCT variant_id) > 1
)
GROUP BY l.text_root
ORDER BY l.text_root ASC;

-- ============================================================
-- SQL VIEW: v_content_full_context
-- Need: Aggregated linguistic/cultural metadata.
-- Context: Used by Semantic Router for RAG context retrieval.
-- Security: security_invoker = true ensures RLS compliance.
-- ============================================================

DROP VIEW IF EXISTS v_content_full_context;

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
    cct.context_name AS theme
FROM content_unit cu
JOIN language_variant lv ON cu.variant_id = lv.variant_id
LEFT JOIN rel_content_tone rct ON cu.unit_id = rct.unit_id
LEFT JOIN tone_marker tm ON rct.tone_id = tm.tone_id
LEFT JOIN rel_content_context rcc ON cu.unit_id = rcc.unit_id
LEFT JOIN cultural_context_tag cct ON rcc.context_id = cct.context_id;
