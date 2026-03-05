-- ============================================
-- AI TUTOR PROJECT - DATABASE SCHEMA
-- Generated from ER Diagram
-- DROP & RECREATE (full overwrite)
-- ============================================

DROP TABLE IF EXISTS rel_content_tone CASCADE;
DROP TABLE IF EXISTS rel_content_context CASCADE;
DROP TABLE IF EXISTS correction_feedback_log CASCADE;
DROP TABLE IF EXISTS content_unit CASCADE;
DROP TABLE IF EXISTS ai_model_registry CASCADE;
DROP TABLE IF EXISTS tone_marker CASCADE;
DROP TABLE IF EXISTS cultural_context_tag CASCADE;
DROP TABLE IF EXISTS morpho_form CASCADE;
DROP TABLE IF EXISTS lemma CASCADE;
DROP TABLE IF EXISTS language_variant CASCADE;

CREATE TABLE language_variant (
    variant_id SERIAL PRIMARY KEY,
    iso_code VARCHAR(10) UNIQUE NOT NULL,
    variant_name VARCHAR(100) NOT NULL,
    parent_variant_id INT REFERENCES language_variant(variant_id)
);

CREATE TABLE lemma (
    lemma_id SERIAL PRIMARY KEY,
    text_root VARCHAR(255) NOT NULL,
    grammatical_category VARCHAR(100),
    frequency_rank INT,
    interference_json JSONB,
    variant_id INT REFERENCES language_variant(variant_id)
);

CREATE TABLE morpho_form (
    form_id SERIAL PRIMARY KEY,
    lemma_id INT NOT NULL REFERENCES lemma(lemma_id),
    surface_form VARCHAR(255) NOT NULL,
    grammar_json JSONB
);

CREATE TABLE cultural_context_tag (
    context_id SERIAL PRIMARY KEY,
    context_name VARCHAR(255) NOT NULL,
    tag_category VARCHAR(100),
    description TEXT
);

CREATE TABLE tone_marker (
    tone_id SERIAL PRIMARY KEY,
    tone_name VARCHAR(100) NOT NULL,
    cue_type VARCHAR(100)
);

CREATE TABLE ai_model_registry (
    model_id SERIAL PRIMARY KEY,
    model_version VARCHAR(50) NOT NULL,
    release_date DATE,
    config_params_json JSONB
);

CREATE TABLE content_unit (
    unit_id SERIAL PRIMARY KEY,
    content_raw TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    content_type VARCHAR(100),
    content_hash VARCHAR(255) UNIQUE,
    source_origin VARCHAR(255),
    syntax_ud_json JSONB,
    tech_meta_json JSONB,
    source_metadata_json JSONB,
    variant_id INT REFERENCES language_variant(variant_id)
);

CREATE TABLE correction_feedback_log (
    log_id SERIAL PRIMARY KEY,
    error_severity VARCHAR(50),
    timestamp TIMESTAMP DEFAULT NOW(),
    correction_diff TEXT,
    error_type VARCHAR(100),
    model_id INT REFERENCES ai_model_registry(model_id),
    unit_id INT REFERENCES content_unit(unit_id)
);

CREATE TABLE rel_content_context (
    unit_id INT NOT NULL REFERENCES content_unit(unit_id),
    context_id INT NOT NULL REFERENCES cultural_context_tag(context_id),
    relevance_score FLOAT,
    PRIMARY KEY (unit_id, context_id)
);

CREATE TABLE rel_content_tone (
    unit_id INT NOT NULL REFERENCES content_unit(unit_id),
    tone_id INT NOT NULL REFERENCES tone_marker(tone_id),
    intensity_score FLOAT,
    PRIMARY KEY (unit_id, tone_id)
);
