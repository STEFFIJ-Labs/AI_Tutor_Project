"""
AI TUTOR PROJECT - Firebase to PostgreSQL ETL Script
Author: Stefania Julin
Version: 1.0

Purpose:
    Transforms Firebase Firestore JSON export into PostgreSQL
    INSERT statements for the Database IN (schema v3.0).

Input:
    firestore_export.json

Output:
    seed_data.sql

Transformation logic:
    Firebase phrases  (1 doc) -> content_unit (3 rows: IT, FI, EN)
                               -> rel_content_tone
                               -> rel_content_context
                               -> media_asset (audio + image pointers)
    Firebase vocabulary (1 doc) -> lemma (3 rows: IT, FI, EN)
                                 -> morpho_form (synonyms)

Data quality:
    - SHA-256 hash generated for each content_raw to prevent duplicates
    - ON CONFLICT DO NOTHING handles Firebase duplicate documents
    - NULL audio fields skipped (no file exists yet in GitHub LFS)
"""

import json
import hashlib
import sys
from datetime import date

# ============================================================
# CONFIGURATION
# ============================================================

INPUT_FILE  = "firestore_export.json"
OUTPUT_FILE = "seed_data.sql"
IMPORT_DATE = str(date.today())

# Language variant IDs (must match order of INSERT in seed_data.sql)
VARIANT_IT = 1   # it-IT Standard Italian
VARIANT_FI = 2   # fi-FI Standard Finnish
VARIANT_EN = 3   # en-EN Standard English (pivot)

# ============================================================
# HELPER FUNCTIONS
# ============================================================

def sha256(text):
    """Generate SHA-256 hash for content deduplication."""
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def escape_sql(text):
    """Escape single quotes for PostgreSQL."""
    if text is None:
        return "NULL"
    return "'" + str(text).replace("'", "''") + "'"

def safe_bool(value):
    """Convert Python bool to SQL boolean."""
    if value is True:
        return "true"
    return "false"

def safe_json(obj):
    """Convert Python dict to escaped JSON string for PostgreSQL."""
    if obj is None:
        return "NULL"
    return escape_sql(json.dumps(obj, ensure_ascii=False))

# ============================================================
# LOAD FIREBASE DATA
# ============================================================

try:
    with open(INPUT_FILE, encoding="utf-8") as f:
        data = json.load(f)
    print(f"Loaded {INPUT_FILE}")
except FileNotFoundError:
    print(f"ERROR: {INPUT_FILE} not found. Run this script in the same folder as the JSON file.")
    sys.exit(1)

phrases    = {k: v for k, v in data.get("phrases", {}).items()
              if k != "init_doc" and v}
vocabulary = {k: v for k, v in data.get("vocabulary", {}).items()
              if k != "init_doc" and v}

print(f"Phrases: {len(phrases)}")
print(f"Vocabulary: {len(vocabulary)}")

# ============================================================
# COLLECT UNIQUE VALUES FOR LOOKUP TABLES
# ============================================================

registers = set()
themes    = set()

for doc in list(phrases.values()) + list(vocabulary.values()):
    if "register" in doc and doc["register"]:
        registers.add(doc["register"])
    if "themeId" in doc and doc["themeId"]:
        themes.add(doc["themeId"])

registers = sorted(registers)
themes    = sorted(themes)

# Maps for foreign key lookup
register_id = {r: i + 1 for i, r in enumerate(registers)}
theme_id    = {t: i + 1 for i, t in enumerate(themes)}

print(f"Registers: {registers}")
print(f"Themes: {len(themes)}")

# ============================================================
# BUILD SQL OUTPUT
# ============================================================

lines = []

lines.append("-- ============================================================")
lines.append("-- AI TUTOR PROJECT - SEED DATA")
lines.append("-- Author: Stefania Julin")
lines.append(f"-- Generated: {IMPORT_DATE}")
lines.append("-- Source: Firebase Firestore JSON export")
lines.append("-- Schema version: 3.0")
lines.append("-- ============================================================")
lines.append("")
lines.append("BEGIN;")
lines.append("")

# ============================================================
# STEP 1: LANGUAGE_VARIANT
# Root languages first (parent_variant_id = NULL)
# EN is marked as pivot language (is_pivot = true)
# ============================================================

lines.append("-- ------------------------------------------------------------")
lines.append("-- STEP 1: LANGUAGE_VARIANT")
lines.append("-- Root languages: IT, FI, EN (pivot)")
lines.append("-- Dialects: added in separate migration after ISO 639 import")
lines.append("-- ------------------------------------------------------------")
lines.append("")
lines.append("INSERT INTO language_variant (variant_id, iso_code, variant_name, is_pivot, parent_variant_id) VALUES")
lines.append(f"    (1, 'it-IT', 'Standard Italian',  false, NULL),")
lines.append(f"    (2, 'fi-FI', 'Standard Finnish',  false, NULL),")
lines.append(f"    (3, 'en-EN', 'Standard English',  true,  NULL)")
lines.append("ON CONFLICT (iso_code) DO NOTHING;")
lines.append("")
lines.append("SELECT setval('language_variant_variant_id_seq', 3);")
lines.append("")

# ============================================================
# STEP 2: TONE_MARKER
# From Firebase register field values
# ============================================================

lines.append("-- ------------------------------------------------------------")
lines.append("-- STEP 2: TONE_MARKER")
lines.append(f"-- {len(registers)} values from Firebase register field")
lines.append("-- ------------------------------------------------------------")
lines.append("")
lines.append("INSERT INTO tone_marker (tone_id, tone_name) VALUES")
for i, r in enumerate(registers):
    comma = "," if i < len(registers) - 1 else ""
    lines.append(f"    ({i + 1}, {escape_sql(r)}){comma}")
lines.append("ON CONFLICT DO NOTHING;")
lines.append("")
lines.append(f"SELECT setval('tone_marker_tone_id_seq', {len(registers)});")
lines.append("")

# ============================================================
# STEP 3: CULTURAL_CONTEXT_TAG
# From Firebase themeId field values
# ============================================================

lines.append("-- ------------------------------------------------------------")
lines.append("-- STEP 3: CULTURAL_CONTEXT_TAG")
lines.append(f"-- {len(themes)} values from Firebase themeId field")
lines.append("-- ------------------------------------------------------------")
lines.append("")
lines.append("INSERT INTO cultural_context_tag (context_id, context_name, tag_category) VALUES")
for i, t in enumerate(themes):
    comma = "," if i < len(themes) - 1 else ""
    lines.append(f"    ({i + 1}, {escape_sql(t)}, 'thematic'){comma}")
lines.append("ON CONFLICT DO NOTHING;")
lines.append("")
lines.append(f"SELECT setval('cultural_context_tag_context_id_seq', {len(themes)});")
lines.append("")

# ============================================================
# STEP 4: AI_MODEL_REGISTRY
# Three AI models: Poro (Finnish), Aya (Italian dialects), Gemma (grammar)
# ============================================================

lines.append("-- ------------------------------------------------------------")
lines.append("-- STEP 4: AI_MODEL_REGISTRY")
lines.append("-- Three AI models in the training pipeline")
lines.append("-- ------------------------------------------------------------")
lines.append("")
lines.append("INSERT INTO ai_model_registry (model_id, model_name, model_version, training_status) VALUES")
lines.append("    (1, 'Poro',  'poro-34b-v1.0',  'pending'),")
lines.append("    (2, 'Aya',   'aya-23-35b-v1.0', 'pending'),")
lines.append("    (3, 'Gemma', 'gemma-7b-v1.0',   'pending')")
lines.append("ON CONFLICT DO NOTHING;")
lines.append("")
lines.append("SELECT setval('ai_model_registry_model_id_seq', 3);")
lines.append("")

# ============================================================
# STEP 5: CONTENT_UNIT from Firebase phrases
# 1 Firebase document -> 3 rows (IT, FI, EN)
# SHA-256 hash generated from content_raw + variant
# ============================================================

lines.append("-- ------------------------------------------------------------")
lines.append("-- STEP 5: CONTENT_UNIT from Firebase phrases")
lines.append(f"-- Source: {len(phrases)} Firebase documents")
lines.append("-- Each document generates 3 rows: IT, FI, EN")
lines.append("-- Duplicates handled with ON CONFLICT DO NOTHING")
lines.append("-- ------------------------------------------------------------")
lines.append("")

unit_id         = 1
content_units   = {}   # hash -> unit_id (for FK references)
unit_theme_map  = []   # (unit_id, context_id)
unit_tone_map   = []   # (unit_id, tone_id)
unit_media_map  = []   # (unit_id, asset_type, file_name, variant_id)

phrase_rows = []

for doc_id, doc in phrases.items():
    text_obj  = doc.get("text", {})
    level     = doc.get("level")
    is_idiom  = doc.get("idiom", False)
    register  = doc.get("register")
    theme     = doc.get("themeId")
    flashcard = doc.get("flashcard", {})
    difficulty = flashcard.get("difficulty") if flashcard else None
    img_hint   = flashcard.get("img_hint") if flashcard else None
    audio_hint = flashcard.get("audio_hint") if flashcard else None
    note       = doc.get("note_culturale")

    source_meta = json.dumps({
        "source": "firebase",
        "import_date": IMPORT_DATE,
        "original_id": doc_id,
        "note_culturale": note
    }, ensure_ascii=False)

    for lang_code, variant_id in [("it", VARIANT_IT), ("fi", VARIANT_FI), ("en", VARIANT_EN)]:
        text = text_obj.get(lang_code)
        if not text:
            continue

        h = sha256(text + str(variant_id))

        if h in content_units:
            continue  # duplicate

        phrase_rows.append(
            f"    ({unit_id}, {escape_sql(text)}, 'phrase', {escape_sql(h)}, "
            f"{escape_sql(level)}, {safe_bool(is_idiom)}, {escape_sql(difficulty)}, "
            f"'firebase', {variant_id}, "
            f"NULL, "
            f"{escape_sql(source_meta)}, "
            f"NULL)"
        )

        content_units[h] = unit_id

        # tone mapping
        if register and register in register_id:
            unit_tone_map.append((unit_id, register_id[register]))

        # context mapping
        if theme and theme in theme_id:
            unit_theme_map.append((unit_id, theme_id[theme]))

        # media assets
        if lang_code == "it":
            if audio_hint:
                unit_media_map.append((unit_id, "audio", audio_hint, variant_id))
            if img_hint:
                unit_media_map.append((unit_id, "image", img_hint, None))

        unit_id += 1

# Write content_unit INSERT
lines.append("INSERT INTO content_unit")
lines.append("    (unit_id, content_raw, content_type, content_hash,")
lines.append("     cefr_level, is_idiom, difficulty, source_origin, variant_id,")
lines.append("     syntax_ud_json, source_metadata_json, tech_meta_json)")
lines.append("VALUES")
for i, row in enumerate(phrase_rows):
    comma = "," if i < len(phrase_rows) - 1 else ""
    lines.append(row + comma)
lines.append("ON CONFLICT (content_hash) DO NOTHING;")
lines.append("")

phrase_unit_count = unit_id - 1
lines.append(f"-- Phrases inserted: {len(phrase_rows)} rows")
lines.append(f"-- Duplicates skipped: {len(phrases) * 3 - len(phrase_rows)}")
lines.append("")

# ============================================================
# STEP 6: LEMMA + MORPHO_FORM from Firebase vocabulary
# ============================================================

lines.append("-- ------------------------------------------------------------")
lines.append("-- STEP 6: LEMMA from Firebase vocabulary")
lines.append(f"-- Source: {len(vocabulary)} Firebase documents")
lines.append("-- Each document generates up to 3 rows: IT, FI, EN")
lines.append("-- ------------------------------------------------------------")
lines.append("")

lemma_id     = 1
lemma_rows   = []
morpho_rows  = []
seen_lemmas  = set()

pos_map = {
    "noun":      "noun",
    "verb":      "verb",
    "adjective": "adjective",
    "adverb":    "adverb",
    "phrase":    "phrase"
}

for doc_id, doc in vocabulary.items():
    lemma_obj  = doc.get("lemma", {})
    synonyms   = doc.get("rawWithSynonyms", {})
    pos        = doc.get("pos")
    register   = doc.get("register")
    theme      = doc.get("themeId")
    note       = doc.get("note_culturale")

    for lang_code, variant_id in [("it", VARIANT_IT), ("fi", VARIANT_FI), ("en", VARIANT_EN)]:
        text = lemma_obj.get(lang_code)
        if not text:
            continue

        key = text.lower().strip() + str(variant_id)
        if key in seen_lemmas:
            continue
        seen_lemmas.add(key)

        interference = None
        if lang_code == "it":
            interference = json.dumps({
                "standard_translation_EN": lemma_obj.get("en"),
                "standard_translation_IT": lemma_obj.get("it"),
                "note_culturale": note
            }, ensure_ascii=False)

        lemma_rows.append(
            f"    ({lemma_id}, {escape_sql(text)}, "
            f"{escape_sql(pos_map.get(pos, pos))}, "
            f"NULL, "
            f"{escape_sql(interference) if interference else 'NULL'}, "
            f"{variant_id})"
        )

        # synonyms -> morpho_form
        raw_synonyms = synonyms.get(lang_code, "")
        if raw_synonyms:
            for part in raw_synonyms.split():
                synonym_text = part.split("?")[0].strip()
                if synonym_text and synonym_text.lower() != text.lower():
                    morpho_rows.append(
                        f"    ({escape_sql(synonym_text)}, NULL, {lemma_id})"
                    )

        lemma_id += 1

lines.append("INSERT INTO lemma (lemma_id, text_root, grammatical_category, frequency_rank, interference_json, variant_id) VALUES")
for i, row in enumerate(lemma_rows):
    comma = "," if i < len(lemma_rows) - 1 else ""
    lines.append(row + comma)
lines.append("ON CONFLICT DO NOTHING;")
lines.append("")
lines.append(f"SELECT setval('lemma_lemma_id_seq', {lemma_id - 1});")
lines.append(f"-- Lemma rows inserted: {len(lemma_rows)}")
lines.append("")

# ============================================================
# STEP 7: MORPHO_FORM (synonyms)
# ============================================================

lines.append("-- ------------------------------------------------------------")
lines.append("-- STEP 7: MORPHO_FORM - synonyms from Firebase rawWithSynonyms")
lines.append("-- ------------------------------------------------------------")
lines.append("")
if morpho_rows:
    lines.append("INSERT INTO morpho_form (surface_form, grammar_json, lemma_id) VALUES")
    for i, row in enumerate(morpho_rows):
        comma = "," if i < len(morpho_rows) - 1 else ""
        lines.append(row + comma)
    lines.append("ON CONFLICT DO NOTHING;")
    lines.append(f"-- Morpho_form rows: {len(morpho_rows)}")
lines.append("")

# ============================================================
# STEP 8: REL_CONTENT_TONE
# ============================================================

lines.append("-- ------------------------------------------------------------")
lines.append("-- STEP 8: REL_CONTENT_TONE")
lines.append("-- ------------------------------------------------------------")
lines.append("")

# deduplicate
unit_tone_map = list(set(unit_tone_map))

if unit_tone_map:
    lines.append("INSERT INTO rel_content_tone (unit_id, tone_id, intensity_score) VALUES")
    for i, (uid, tid) in enumerate(unit_tone_map):
        comma = "," if i < len(unit_tone_map) - 1 else ""
        lines.append(f"    ({uid}, {tid}, 1.0){comma}")
    lines.append("ON CONFLICT DO NOTHING;")
    lines.append(f"-- Tone links: {len(unit_tone_map)}")
lines.append("")

# ============================================================
# STEP 9: REL_CONTENT_CONTEXT
# ============================================================

lines.append("-- ------------------------------------------------------------")
lines.append("-- STEP 9: REL_CONTENT_CONTEXT")
lines.append("-- ------------------------------------------------------------")
lines.append("")

unit_theme_map = list(set(unit_theme_map))

if unit_theme_map:
    lines.append("INSERT INTO rel_content_context (unit_id, context_id, relevance_score) VALUES")
    for i, (uid, cid) in enumerate(unit_theme_map):
        comma = "," if i < len(unit_theme_map) - 1 else ""
        lines.append(f"    ({uid}, {cid}, 1.0){comma}")
    lines.append("ON CONFLICT DO NOTHING;")
    lines.append(f"-- Context links: {len(unit_theme_map)}")
lines.append("")

# ============================================================
# STEP 10: MEDIA_ASSET (GitHub LFS pointers)
# Only records where file_name is not null
# ============================================================

lines.append("-- ------------------------------------------------------------")
lines.append("-- STEP 10: MEDIA_ASSET - GitHub LFS pointers")
lines.append("-- lfs_pointer will be updated when files are uploaded to LFS")
lines.append("-- ------------------------------------------------------------")
lines.append("")

if unit_media_map:
    media_insert_rows = []
    seen_media = set()
    for (uid, atype, fname, vid) in unit_media_map:
        key = f"{uid}_{fname}"
        if key in seen_media:
            continue
        seen_media.add(key)
        fmt = "mp3" if atype == "audio" else "jpg"
        vid_sql = str(vid) if vid else "NULL"
        media_insert_rows.append(
            f"    ({escape_sql(atype)}, {escape_sql(fmt)}, "
            f"{escape_sql(fname)}, 'github_lfs', NULL, {uid}, {vid_sql})"
        )

    lines.append("INSERT INTO media_asset (asset_type, file_format, file_name, storage_location, lfs_pointer, unit_id, variant_id) VALUES")
    for i, row in enumerate(media_insert_rows):
        comma = "," if i < len(media_insert_rows) - 1 else ""
        lines.append(row + comma)
    lines.append("ON CONFLICT DO NOTHING;")
    lines.append(f"-- Media asset rows: {len(media_insert_rows)}")
lines.append("")

# ============================================================
# STEP 11: UPDATE SEQUENCES
# ============================================================

lines.append("-- ------------------------------------------------------------")
lines.append("-- STEP 11: UPDATE ALL SEQUENCES")
lines.append("-- ------------------------------------------------------------")
lines.append("")
lines.append(f"SELECT setval('content_unit_unit_id_seq', {unit_id - 1});")
lines.append(f"SELECT setval('lemma_lemma_id_seq', {lemma_id - 1});")
lines.append("")
lines.append("COMMIT;")
lines.append("")
lines.append("-- ============================================================")
lines.append("-- END SEED DATA")
lines.append(f"-- content_unit rows: {len(phrase_rows)}")
lines.append(f"-- lemma rows:        {len(lemma_rows)}")
lines.append(f"-- morpho_form rows:  {len(morpho_rows)}")
lines.append(f"-- tone links:        {len(unit_tone_map)}")
lines.append(f"-- context links:     {len(unit_theme_map)}")
lines.append(f"-- media assets:      {len(media_insert_rows) if unit_media_map else 0}")
lines.append("-- ============================================================")

# ============================================================
# WRITE OUTPUT FILE
# ============================================================

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))

print(f"\nOutput written to {OUTPUT_FILE}")
print(f"content_unit rows : {len(phrase_rows)}")
print(f"lemma rows        : {len(lemma_rows)}")
print(f"morpho_form rows  : {len(morpho_rows)}")
print(f"tone links        : {len(unit_tone_map)}")
print(f"context links     : {len(unit_theme_map)}")
