-- seed_01_lookup.sql - Author: Stefania Julin
-- language_variant, tone_marker, cultural_context_tag, ai_model_registry
BEGIN;

INSERT INTO language_variant (variant_id, iso_code, variant_name, is_pivot, parent_variant_id) VALUES
    (1, 'it-IT', 'Standard Italian', false, NULL),
    (2, 'fi-FI', 'Standard Finnish',  false, NULL),
    (3, 'en-EN', 'Standard English',  true,  NULL)
ON CONFLICT DO NOTHING;
SELECT setval('language_variant_variant_id_seq', 3);

INSERT INTO tone_marker (tone_id, tone_name) VALUES
    (1, 'comune'),
    (2, 'enfatico'),
    (3, 'femminile'),
    (4, 'formale'),
    (5, 'informale'),
    (6, 'maschile'),
    (7, 'neutro')
ON CONFLICT DO NOTHING;
SELECT setval('tone_marker_tone_id_seq', 7);

INSERT INTO cultural_context_tag (context_id, context_name, tag_category) VALUES
    (1, 'casa_vita_quotidiana', 'thematic'),
    (2, 'cibo_bevande', 'thematic'),
    (3, 'città_servizi', 'thematic'),
    (4, 'emozioni_sentimenti', 'thematic'),
    (5, 'etica_digitale', 'thematic'),
    (6, 'famiglia', 'thematic'),
    (7, 'festivita_tradizioni', 'thematic'),
    (8, 'lavoro', 'thematic'),
    (9, 'natura_ambiente', 'thematic'),
    (10, 'salute_benessere', 'thematic'),
    (11, 'scuola_studio', 'thematic'),
    (12, 'soldi_consumi', 'thematic'),
    (13, 'tecnologia_media', 'thematic'),
    (14, 'tempo_libero_hobby', 'thematic'),
    (15, 'tempo_meteo', 'thematic'),
    (16, 'trasporti', 'thematic'),
    (17, 'viaggi_turismo', 'thematic'),
    (18, 'vita_sociale', 'thematic')
ON CONFLICT DO NOTHING;
SELECT setval('cultural_context_tag_context_id_seq', 18);

INSERT INTO ai_model_registry (model_id, model_name, model_version, training_status) VALUES
    (1, 'Poro',  'poro-34b-v1.0',   'pending'),
    (2, 'Aya',   'aya-23-35b-v1.0', 'pending'),
    (3, 'Gemma', 'gemma-7b-v1.0',   'pending')
ON CONFLICT DO NOTHING;
SELECT setval('ai_model_registry_model_id_seq', 3);

COMMIT;