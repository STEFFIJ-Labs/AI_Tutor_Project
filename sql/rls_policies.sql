-- rls_policies.sql - Author: Stefania Julin
-- Row Level Security policies for Progetto DATA - AI Tutor Project
-- Applied after schema.sql and all fixes.
-- Three roles: admin (full access), authenticated/student (read only), anon (Semantic Router read only)

-- STEP 1: ENABLE RLS ON ALL TABLES
ALTER TABLE content_unit ENABLE ROW LEVEL SECURITY;
ALTER TABLE language_variant ENABLE ROW LEVEL SECURITY;
ALTER TABLE lemma ENABLE ROW LEVEL SECURITY;
ALTER TABLE morpho_form ENABLE ROW LEVEL SECURITY;
ALTER TABLE tone_marker ENABLE ROW LEVEL SECURITY;
ALTER TABLE cultural_context_tag ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_model_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE media_asset ENABLE ROW LEVEL SECURITY;
ALTER TABLE vector_index ENABLE ROW LEVEL SECURITY;
ALTER TABLE correction_feedback_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE rel_content_context ENABLE ROW LEVEL SECURITY;
ALTER TABLE rel_content_tone ENABLE ROW LEVEL SECURITY;

-- STEP 2: ADMIN POLICY - full access on all tables
DO $$
DECLARE
    t text;
BEGIN
    FOR t IN SELECT unnest(ARRAY[
        'content_unit', 'language_variant', 'lemma', 'morpho_form',
        'tone_marker', 'cultural_context_tag', 'ai_model_registry',
        'media_asset', 'vector_index', 'correction_feedback_log',
        'rel_content_context', 'rel_content_tone'
    ])
    LOOP
        EXECUTE format('
            CREATE POLICY admin_full_access ON %I
            FOR ALL
            TO authenticated
            USING (auth.jwt() ->> ''role'' = ''admin'')
            WITH CHECK (auth.jwt() ->> ''role'' = ''admin'');
        ', t);
    END LOOP;
END $$;

-- STEP 3: ANON POLICY - read only on public linguistic tables
CREATE POLICY anon_read_content ON content_unit FOR SELECT TO anon USING (true);
CREATE POLICY anon_read_language ON language_variant FOR SELECT TO anon USING (true);
CREATE POLICY anon_read_lemma ON lemma FOR SELECT TO anon USING (true);
CREATE POLICY anon_read_morpho ON morpho_form FOR SELECT TO anon USING (true);
CREATE POLICY anon_read_tone ON tone_marker FOR SELECT TO anon USING (true);
CREATE POLICY anon_read_context ON cultural_context_tag FOR SELECT TO anon USING (true);
CREATE POLICY anon_read_rel_tone ON rel_content_tone FOR SELECT TO anon USING (true);
CREATE POLICY anon_read_rel_context ON rel_content_context FOR SELECT TO anon USING (true);

-- STEP 4: STUDENT POLICY - read only on linguistic content
CREATE POLICY student_read_content ON content_unit FOR SELECT TO authenticated USING (auth.jwt() ->> 'role' != 'admin');
CREATE POLICY student_read_language ON language_variant FOR SELECT TO authenticated USING (auth.jwt() ->> 'role' != 'admin');
CREATE POLICY student_read_lemma ON lemma FOR SELECT TO authenticated USING (auth.jwt() ->> 'role' != 'admin');
CREATE POLICY student_read_morpho ON morpho_form FOR SELECT TO authenticated USING (auth.jwt() ->> 'role' != 'admin');
