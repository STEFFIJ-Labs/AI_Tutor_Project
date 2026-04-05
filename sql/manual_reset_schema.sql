-- ============================================================
-- manual_reset_schema.sql - AI TUTOR PROJECT
-- Author: Stefania Julin
-- WARNING: DROPS ALL TABLES AND ALL DATA.
-- Run ONLY manually from Supabase SQL Editor.
-- NEVER executed by any GitHub Actions workflow.
-- Use only when rebuilding the schema from scratch.
-- ============================================================
DROP TABLE IF EXISTS vector_index              CASCADE;
DROP TABLE IF EXISTS media_asset               CASCADE;
DROP TABLE IF EXISTS rel_content_tone          CASCADE;
DROP TABLE IF EXISTS rel_content_context       CASCADE;
DROP TABLE IF EXISTS correction_feedback_log   CASCADE;
DROP TABLE IF EXISTS content_unit              CASCADE;
DROP TABLE IF EXISTS morpho_form               CASCADE;
DROP TABLE IF EXISTS lemma                     CASCADE;
DROP TABLE IF EXISTS language_variant          CASCADE;
DROP TABLE IF EXISTS tone_marker               CASCADE;
DROP TABLE IF EXISTS cultural_context_tag      CASCADE;
DROP TABLE IF EXISTS ai_model_registry         CASCADE;
DROP FUNCTION IF EXISTS normalize_iso_code()   CASCADE;
DROP VIEW IF EXISTS v_content_full_context;
