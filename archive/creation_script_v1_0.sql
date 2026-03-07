-- 1. DATABASE CREATION
CREATE DATABASE ai_tutor_db;
\c ai_tutor_db;

-- 2. TABLES CREATION (DDL)
CREATE TABLE LANGUAGE_VARIANT (
    variant_id SERIAL PRIMARY KEY,
    iso_code VARCHAR(10) NOT NULL,
    variant_name VARCHAR(100) NOT NULL,
    parent_variant_id INTEGER,
    FOREIGN KEY (parent_variant_id) REFERENCES LANGUAGE_VARIANT(variant_id)
);

CREATE TABLE LEMMA (
    lemma_id SERIAL PRIMARY KEY,
    text_root VARCHAR(255) NOT NULL,
    grammatical_category VARCHAR(100),
    frequency_rank INTEGER,
    interference_json JSONB,
    variant_id INTEGER,
    FOREIGN KEY (variant_id) REFERENCES LANGUAGE_VARIANT(variant_id)
);

CREATE TABLE TONE_MARKER (
    tone_id SERIAL PRIMARY KEY,
    tone_name VARCHAR(100) NOT NULL
);

CREATE TABLE CULTURAL_CONTEXT_TAG (
    context_id SERIAL PRIMARY KEY,
    context_name VARCHAR(150) NOT NULL,
    tag_category VARCHAR(100),
    cue_type VARCHAR(100),
    description TEXT
);

CREATE TABLE AI_MODEL_REGISTRY (
    model_id SERIAL PRIMARY KEY,
    model_version VARCHAR(50) NOT NULL,
    release_date DATE,
    config_params_json JSONB
);

CREATE TABLE MORPHO_FORM (
    form_id SERIAL PRIMARY KEY,
    lemma_id INTEGER NOT NULL,
    surface_form VARCHAR(255) NOT NULL,
    grammar_json JSONB,
    FOREIGN KEY (lemma_id) REFERENCES LEMMA(lemma_id)
);

CREATE TABLE CONTENT_UNIT (
    unit_id SERIAL PRIMARY KEY,
    content_raw TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    content_type VARCHAR(50) NOT NULL,
    content_hash VARCHAR(255) UNIQUE NOT NULL,
    source_origin VARCHAR(150),
    syntax_ud_json JSONB,
    tech_meta_json JSONB,
    source_metadata_json JSONB,
    variant_id INTEGER,
    FOREIGN KEY (variant_id) REFERENCES LANGUAGE_VARIANT(variant_id)
);

CREATE TABLE CORRECTION_FEEDBACK_LOG (
    log_id SERIAL PRIMARY KEY,
    error_severity VARCHAR(50),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    correction_diff TEXT,
    error_type VARCHAR(100),
    model_id INTEGER,
    unit_id INTEGER,
    FOREIGN KEY (model_id) REFERENCES AI_MODEL_REGISTRY(model_id),
    FOREIGN KEY (unit_id) REFERENCES CONTENT_UNIT(unit_id)
);

-- BRIDGE TABLES (M:N Relationships)
CREATE TABLE Rel_Content_Context (
    unit_id INTEGER NOT NULL,
    context_id INTEGER NOT NULL,
    relevance_score NUMERIC(5,2),
    PRIMARY KEY (unit_id, context_id),
    FOREIGN KEY (unit_id) REFERENCES CONTENT_UNIT(unit_id),
    FOREIGN KEY (context_id) REFERENCES CULTURAL_CONTEXT_TAG(context_id)
);

CREATE TABLE Rel_Content_Tone (
    unit_id INTEGER NOT NULL,
    tone_id INTEGER NOT NULL,
    intensity_score NUMERIC(5,2),
    PRIMARY KEY (unit_id, tone_id),
    FOREIGN KEY (unit_id) REFERENCES CONTENT_UNIT(unit_id),
    FOREIGN KEY (tone_id) REFERENCES TONE_MARKER(tone_id)
);

-- 3. DATA INSERTION (DML)
INSERT INTO LANGUAGE_VARIANT (iso_code, variant_name, parent_variant_id) VALUES ('it-IT', 'Standard Italian', NULL);
INSERT INTO LANGUAGE_VARIANT (iso_code, variant_name, parent_variant_id) VALUES ('nap-IT', 'Neapolitan Dialect', 1);
INSERT INTO LANGUAGE_VARIANT (iso_code, variant_name, parent_variant_id) VALUES ('fi-FI', 'Standard Finnish', NULL);
INSERT INTO LANGUAGE_VARIANT (iso_code, variant_name, parent_variant_id) VALUES ('en-US', 'American English', NULL);

INSERT INTO TONE_MARKER (tone_name) VALUES ('Formal');
INSERT INTO TONE_MARKER (tone_name) VALUES ('Colloquial');

INSERT INTO CULTURAL_CONTEXT_TAG (context_name, tag_category, cue_type, description) VALUES ('Academic Lecture', 'Education', 'Contextual', 'University lecture or formal academic writing');

INSERT INTO LEMMA (text_root, grammatical_category, frequency_rank, interference_json, variant_id)
VALUES ('run', 'verb', 50, '{"L1_transfer_errors": ["false_friends", "tense_mismatch"], "severity": "high"}', 4);

INSERT INTO CONTENT_UNIT (content_raw, content_type, content_hash, source_origin, syntax_ud_json, tech_meta_json, variant_id)
VALUES (
    'The quick brown fox jumps over the lazy dog.',
    'Phrase',
    'hash_99abc123',
    'AI_Generated_Corpus',
    '{"dependencies": [{"word": "jumps", "rel": "root"}, {"word": "fox", "rel": "nsubj"}]}',
    '{"readability_index": 8.5, "ai_confidence_score": 0.98}',
    4
);
