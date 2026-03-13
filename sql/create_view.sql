-- ============================================================
-- create_view.sql
-- Author: Stefania Julin | AI Tutor Project - Progetto DATA
-- Version: 1.0
-- Purpose: Create v_content_full_context VIEW with
--          security_invoker = true and variant_confidence.
--
-- DEPLOYED AS SEPARATE STEP in deploy-schema.yml because
-- the Supabase Management API accepts one statement per call.
-- DROP and CREATE are sent as a single transaction here.
--
-- Execution order in workflow:
--   1. schema.sql
--   2. add_referential_actions.sql
--   3. schema_fixes_v3_1.sql
--   4. schema_fixes_v3_2.sql
--   5. create_view.sql         <- THIS FILE
--   6. queries.sql
--   7. verify_schema.sql
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
    cct.context_name                        AS theme
FROM content_unit                           cu
JOIN language_variant                       lv  ON lv.variant_id  = cu.variant_id
LEFT JOIN rel_content_tone                  rct ON rct.unit_id     = cu.unit_id
LEFT JOIN tone_marker                       tm  ON tm.tone_id      = rct.tone_id
LEFT JOIN rel_content_context               rcc ON rcc.unit_id     = cu.unit_id
LEFT JOIN cultural_context_tag              cct ON cct.context_id  = rcc.context_id;
