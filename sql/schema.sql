-- ============================================================
-- AI TUTOR PROJECT - DATABASE IN (PostgreSQL)
-- Author: Stefania Julin
-- Version: 3.1 - Schema fixes incorporated
--
-- CHANGES FROM v3.0:
-- FIX v3.1-1: Added normalize_iso_code() trigger on language_variant
--             Any external source (Dependance V2, Firebase) sending
--             'IT', 'it', 'it-IT' is normalized automatically.
-- FIX v3.1-2: Added 'und' fallback row in language_variant
--             ISO 639-2 catch-all for unknown dialects discovered
--             dynamically by the Semantic Router in production.
-- FIX v3.1-3: Added variant_confidence FLOAT to content_unit
--             Semantic Router tracks classification certainty per row.
-- FIX v3.1-4: VIEW v_content_full_context recreated with
--             security_invoker = true (RLS bypass fixed).
-- FIX v3.1-5: Added model_id FK to vector_index
--             Links each Pinecone vector to the AI model that
--             generated it. Required for per-model RAG isolation.
--
-- CHANGES FROM v2.0:
-- FIX 1NF: extracted cefr_level, is_idiom, difficulty from JSON
--          to dedicated columns in content_unit
-- FIX 1NF: created media_asset table for audio/image pointers
--          to GitHub LFS (removed from tech_meta_json)
-- FIX 2NF: added training_cycle and feedback_source
--          to correction_feedback_log for Data Flywheel tracking
-- FIX 3NF: added model_name, hf_adapter_path, training_status
--          to ai_model_registry (Poro / Aya / Gemma)
-- FIX 3NF: added is_pivot column to language_variant
--          to identify EN as bridge language
-- REF INT: added vector_index table to track Pinecone embeddings
-- STANDARD: documented interference_json structure in comments
--
-- NORMALIZATION:
-- 1NF: no multivalued attributes, no hidden groups in JSON
-- 2NF: no partial dependencies on composite keys
-- 3NF: no transitive dependencies
--
-- DATA SOURCES:
-- IN:  Firebase JSON export (phrases, vocabulary)
--      ISO 639 / Glottolog (language variants and dialects)
--      Universal Dependencies v2 (syntax trees, morphology)
--      Database OUT via Data Flywheel (correction_feedback_log)
-- OUT: Hugging Face Datasets (.parquet for AI training)
--      Pinecone (semantic vectors for RAG)
--      Semantic Router (real-time RAG context injection)
--      Flutter / Godot app (via REST API + JWT)
-- ============================================================


-- ============================================================
-- STEP 0: DROP all tables in reverse dependency order
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

-- Drop trigger function if exists (recreated in STEP 10)
DROP FUNCTION IF EXISTS normalize_iso_code() CASCADE;

-- Drop view if exists (recreated in STEP 11)
DROP VIEW IF EXISTS v_content_full_context;


-- ============================================================
-- STEP 1: INDEPENDENT TABLES (no foreign keys)
-- ============================================================

-- ------------------------------------------------------------
-- ai_model_registry
-- Tracks all AI models used in the pipeline.
-- FIX 3NF: model_name, hf_adapter_path, training_status added
-- so that model identity attributes depend only on model_id
-- and not transitively on each other.
-- model_name values: Poro | Aya | Gemma
-- training_status values: pending | training | ready | retired
-- ------------------------------------------------------------
CREATE TABLE ai_model_registry (
    model_id           SERIAL PRIMARY KEY,
    model_name         VARCHAR(50)  NOT NULL,
    model_version      VARCHAR(50)  NOT NULL,
    hf_adapter_path    VARCHAR(255),
    training_status    VARCHAR(20)  NOT NULL DEFAULT 'pending',
    release_date       DATE,
    config_params_json JSONB
);

-- ------------------------------------------------------------
-- cultural_context_tag
-- Thematic and cultural context tags derived from Firebase themeId.
-- Values: casa_vita_quotidiana, cibo_bevande, viaggi_turismo, etc.
-- ------------------------------------------------------------
CREATE TABLE cultural_context_tag (
    context_id   SERIAL PRIMARY KEY,
    context_name VARCHAR(255) NOT NULL,
    tag_category VARCHAR(100),
    cue_type     VARCHAR(100),
    description  TEXT
);

-- ------------------------------------------------------------
-- tone_marker
-- Register and tone markers derived from Firebase register field.
-- Values: formale, informale, neutro, comune, enfatico,
--         femminile, maschile
-- ------------------------------------------------------------
CREATE TABLE tone_marker (
    tone_id   SERIAL PRIMARY KEY,
    tone_name VARCHAR(100) NOT NULL,
    cue_type  VARCHAR(100)
);


-- ============================================================
-- STEP 2: LANGUAGE_VARIANT (self-referencing)
-- FIX 3NF: added is_pivot column.
-- EN Standard is the bridge language for chaining:
-- IT dialect -> EN -> FI dialect
-- is_pivot = true only for en-EN
-- parent_variant_id = NULL for all root languages:
-- it-IT, fi-FI, en-EN
-- ============================================================
CREATE TABLE language_variant (
    variant_id        SERIAL PRIMARY KEY,
    iso_code          VARCHAR(10)  UNIQUE NOT NULL,
    variant_name      VARCHAR(100) NOT NULL,
    is_pivot          BOOLEAN      NOT NULL DEFAULT false,
    parent_variant_id INT REFERENCES language_variant(variant_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);


-- ============================================================
-- STEP 3: LEMMA
-- Stores root word forms from Firebase vocabulary.lemma
-- and from Universal Dependencies v2.
--
-- interference_json standard structure:
-- {
--   "standard_translation_EN": "Let's go",
--   "standard_translation_IT": "Andiamo",
--   "L1_transfer_errors": ["false_friends", "tense_mismatch"],
--   "severity": "high | medium | low",
--   "source_variant": "nap-IT",
--   "target_variants": ["fi-spoken", "fi-north"]
-- }
--
-- grammatical_category values: noun | verb | adjective | adverb | phrase
-- ============================================================
CREATE TABLE lemma (
    lemma_id             SERIAL PRIMARY KEY,
    text_root            VARCHAR(255) NOT NULL,
    grammatical_category VARCHAR(100),
    frequency_rank       INT,
    interference_json    JSONB,
    variant_id           INT REFERENCES language_variant(variant_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);


-- ============================================================
-- STEP 4: MORPHO_FORM
-- Stores inflected forms and synonyms from Firebase
-- rawWithSynonyms field and from Universal Dependencies v2.
--
-- grammar_json standard structure (UD v2):
-- {
--   "upos": "VERB",
--   "feats": {
--     "Mood": "Ind",
--     "Number": "Sing",
--     "Person": "1",
--     "Tense": "Pres",
--     "VerbForm": "Fin"
--   }
-- }
-- ============================================================
CREATE TABLE morpho_form (
    form_id      SERIAL PRIMARY KEY,
    surface_form VARCHAR(255) NOT NULL,
    grammar_json JSONB,
    lemma_id     INT NOT NULL REFERENCES lemma(lemma_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


-- ============================================================
-- STEP 5: CONTENT_UNIT
-- Central table of the Database IN.
-- Stores phrases and vocabulary from Firebase and
-- from external linguistic databases.
--
-- FIX 1NF: cefr_level, is_idiom, difficulty extracted
-- from tech_meta_json to dedicated columns.
-- These are interrogable attributes used by the Semantic Router
-- and by the AI training pipeline to filter content by level.
--
-- FIX v3.1-3: variant_confidence FLOAT added.
-- Tracks how certain the Semantic Router is about the language
-- classification of this row. NULL = not yet classified.
--
-- cefr_level values: A1 | A2 | B1 | B2 | C1 | C2
-- difficulty values: easy | medium | hard
-- content_type values: phrase | vocabulary | dialogue | grammar_rule
--
-- syntax_ud_json standard structure (Universal Dependencies v2):
-- {
--   "dependencies": [
--     {"id": 1, "word": "jumps", "rel": "root", "head": 0},
--     {"id": 2, "word": "fox",   "rel": "nsubj", "head": 1}
--   ]
-- }
--
-- tech_meta_json standard structure:
-- {
--   "readability_index": 8.5,
--   "ai_confidence_score": 0.98,
--   "firebase_doc_id": "0OAlY5KrLljzloWuGrCu"
-- }
--
-- source_metadata_json standard structure:
-- {
--   "source": "firebase | iso639 | glottolog | ud_v2 | manual",
--   "import_date": "2026-03-05",
--   "original_id": "firebase_doc_id"
-- }
-- ============================================================
CREATE TABLE content_unit (
    unit_id              SERIAL PRIMARY KEY,
    content_raw          TEXT         NOT NULL,
    content_type         VARCHAR(50)  NOT NULL,
    content_hash         VARCHAR(255) UNIQUE NOT NULL,
    cefr_level           VARCHAR(2),
    is_idiom             BOOLEAN      NOT NULL DEFAULT false,
    difficulty           VARCHAR(10),
    variant_confidence   FLOAT,
    source_origin        VARCHAR(150),
    created_at           TIMESTAMP    DEFAULT NOW(),
    syntax_ud_json       JSONB,
    tech_meta_json       JSONB,
    source_metadata_json JSONB,
    variant_id           INT REFERENCES language_variant(variant_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);


-- ============================================================
-- STEP 6: CORRECTION_FEEDBACK_LOG
-- Forensic audit log. Core of the Data Flywheel mechanism.
-- Errors generated by AI models in production (Database OUT)
-- flow back here to improve the next training cycle.
--
-- FIX 2NF: added training_cycle and feedback_source.
-- These attributes depend on the full error context
-- (model_id + unit_id), not on either alone.
--
-- feedback_source values: database_out | human_review | automated
-- error_severity values: low | medium | high | critical
-- ============================================================
CREATE TABLE correction_feedback_log (
    log_id          SERIAL PRIMARY KEY,
    error_severity  VARCHAR(20),
    error_type      VARCHAR(100),
    correction_diff TEXT,
    training_cycle  INT          NOT NULL DEFAULT 1,
    feedback_source VARCHAR(50)  NOT NULL DEFAULT 'database_out',
    created_at      TIMESTAMP    DEFAULT NOW(),
    model_id        INT REFERENCES ai_model_registry(model_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    unit_id         INT REFERENCES content_unit(unit_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


-- ============================================================
-- STEP 7: MEDIA_ASSET
-- FIX 1NF: audio and image pointers moved from tech_meta_json
-- to a dedicated table. Each content_unit can have multiple
-- media assets (one audio IT, one audio FI, one image).
-- Pointers reference files stored in GitHub LFS.
-- Files are then packaged to Hugging Face .parquet for training.
--
-- asset_type values: audio | image
-- file_format values: mp3 | wav | jpg | png | webp
-- storage_location values: github_lfs | hugging_face | local
--
-- lfs_pointer standard structure:
-- {
--   "lfs_url": "https://lfs.github.com/STEFFIJ-Labs/AI_Tutor/...",
--   "hf_url":  "hf://datasets/STEFFIJ-Labs/ai-tutor/audio/...",
--   "sha256":  "abc123..."
-- }
-- ============================================================
CREATE TABLE media_asset (
    asset_id         SERIAL PRIMARY KEY,
    asset_type       VARCHAR(10)  NOT NULL,
    file_format      VARCHAR(10)  NOT NULL,
    file_name        VARCHAR(255) NOT NULL,
    storage_location VARCHAR(50)  NOT NULL DEFAULT 'github_lfs',
    lfs_pointer      JSONB,
    created_at       TIMESTAMP    DEFAULT NOW(),
    unit_id          INT NOT NULL REFERENCES content_unit(unit_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    variant_id       INT REFERENCES language_variant(variant_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);


-- ============================================================
-- STEP 8: VECTOR_INDEX
-- Tracks Pinecone vector embeddings for each content_unit.
-- Required for RAG (Retrieval Augmented Generation).
-- The Semantic Router queries Pinecone to inject context
-- from the database into AI model prompts in real time.
--
-- FIX v3.1-5: model_id FK added to ai_model_registry.
-- Each vector is linked to the model that generated it.
-- Poro embeddings != Aya embeddings != Gemma embeddings.
-- Without model_id the Router cannot isolate per-model search.
--
-- vector_status values: pending | indexed | outdated | error
-- embedding_model values: text-embedding-ada-002 | multilingual-e5
-- ============================================================
CREATE TABLE vector_index (
    vector_id        SERIAL PRIMARY KEY,
    pinecone_id      VARCHAR(255) UNIQUE NOT NULL,
    embedding_model  VARCHAR(100) NOT NULL,
    vector_status    VARCHAR(20)  NOT NULL DEFAULT 'pending',
    indexed_at       TIMESTAMP    DEFAULT NOW(),
    model_id         INT REFERENCES ai_model_registry(model_id)
        ON DELETE SET NULL
        ON UPDATE CASCADE,
    unit_id          INT NOT NULL REFERENCES content_unit(unit_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


-- ============================================================
-- STEP 9: BRIDGE TABLES
-- Many-to-many relationships with scoring weights.
-- Composite primary keys enforce uniqueness of each pair.
-- Used by Semantic Router for real-time RAG context injection.
-- ============================================================

-- One content_unit can belong to many cultural contexts
-- One cultural context can tag many content_units
CREATE TABLE rel_content_context (
    unit_id         INT NOT NULL,
    context_id      INT NOT NULL,
    relevance_score NUMERIC(5,2),
    PRIMARY KEY (unit_id, context_id),
    FOREIGN KEY (unit_id) REFERENCES content_unit(unit_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (context_id) REFERENCES cultural_context_tag(context_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- One content_unit can have many tone markers
-- One tone marker can tag many content_units
CREATE TABLE rel_content_tone (
    unit_id         INT NOT NULL,
    tone_id         INT NOT NULL,
    intensity_score NUMERIC(5,2),
    PRIMARY KEY (unit_id, tone_id),
    FOREIGN KEY (unit_id) REFERENCES content_unit(unit_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (tone_id) REFERENCES tone_marker(tone_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);


-- ============================================================
-- STEP 10: ISO NORMALIZATION TRIGGER (FIX v3.1-1 + v3.1-2)
-- Normalizes iso_code on INSERT/UPDATE so any external source
-- sending 'IT', 'it', 'IT-IT', 'it-it' is stored as 'it-IT'.
-- Also inserts 'und' fallback variant for unknown dialects.
-- ============================================================

CREATE OR REPLACE FUNCTION normalize_iso_code()
RETURNS TRIGGER AS $$
BEGIN
    NEW.iso_code = CASE LOWER(REPLACE(NEW.iso_code, '-', ''))
        WHEN 'itit' THEN 'it-IT'
        WHEN 'it'   THEN 'it-IT'
        WHEN 'fifi' THEN 'fi-FI'
        WHEN 'fi'   THEN 'fi-FI'
        WHEN 'enen' THEN 'en-EN'
        WHEN 'en'   THEN 'en-EN'
        ELSE NEW.iso_code
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_normalize_iso_code
BEFORE INSERT OR UPDATE ON language_variant
FOR EACH ROW EXECUTE FUNCTION normalize_iso_code();

-- FIX v3.1-2: 'und' fallback variant
-- ISO 639-2 standard code for undetermined language.
-- Used by Semantic Router when dialect discovery fails.
-- The Router classifies the row later and updates variant_id.
INSERT INTO language_variant (iso_code, variant_name, is_pivot, parent_variant_id)
VALUES ('und', 'Undetermined', false, NULL)
ON CONFLICT (iso_code) DO NOTHING;


-- ============================================================
-- STEP 11: VIEW v_content_full_context (FIX v3.1-4)
-- Unified view for Semantic Router real-time queries.
-- Joins content_unit with language, tone and cultural context.
-- security_invoker = true: queries run with the caller's
-- permissions, not the creator's. This respects RLS policies
-- and prevents data leakage between user roles.
-- ============================================================

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
    cct.context_name AS theme
FROM content_unit cu
JOIN language_variant          lv  ON lv.variant_id  = cu.variant_id
LEFT JOIN rel_content_tone     rct ON rct.unit_id     = cu.unit_id
LEFT JOIN tone_marker          tm  ON tm.tone_id      = rct.tone_id
LEFT JOIN rel_content_context  rcc ON rcc.unit_id     = cu.unit_id
LEFT JOIN cultural_context_tag cct ON cct.context_id  = rcc.context_id;


-- ============================================================
-- END: schema v3.1 definitive
-- Tables: 12
-- Foreign keys: 13 + model_id in vector_index
-- Trigger: trg_normalize_iso_code on language_variant
-- View: v_content_full_context (security_invoker = true)
-- Normalization: 1NF, 2NF, 3NF verified
-- Ready for population from:
--   - Firebase JSON export (generate_seeds.py)
--   - ISO 639 / Glottolog
--   - Universal Dependencies v2
-- ============================================================
