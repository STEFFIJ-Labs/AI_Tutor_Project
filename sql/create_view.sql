-- ============================================================
-- create_view.sql
-- Author: Stefania Julin | AI Tutor Project - Progetto DATA
-- Version: 1.1
-- Fix: column order aligned to schema_fixes_v3_2.sql FIX 4
--      to avoid 42P16 error on CREATE OR REPLACE VIEW.
--      Order must match the view already deployed on Supabase.
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
FROM content_unit                           cu
JOIN language_variant                       lv  ON lv.variant_id  = cu.variant_id
LEFT JOIN rel_content_tone                  rct ON rct.unit_id     = cu.unit_id
LEFT JOIN tone_marker                       tm  ON tm.tone_id      = rct.tone_id
LEFT JOIN rel_content_context               rcc ON rcc.unit_id     = cu.unit_id
LEFT JOIN cultural_context_tag              cct ON cct.context_id  = rcc.context_id;
