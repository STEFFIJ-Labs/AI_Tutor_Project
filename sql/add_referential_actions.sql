-- ============================================================
-- AI TUTOR PROJECT - ADD REFERENTIAL ACTIONS
-- Author: Stefania Julin
-- Version: 2.1
-- Description: Adds ON DELETE / ON UPDATE to existing FK constraints
-- SAFE: does NOT drop tables, does NOT delete data
-- ============================================================

-- ============================================================
-- STEP 1: DROP old FK constraints (without actions)
-- ============================================================

ALTER TABLE public.language_variant
    DROP CONSTRAINT IF EXISTS language_variant_parent_variant_id_fkey;

ALTER TABLE public.lemma
    DROP CONSTRAINT IF EXISTS lemma_variant_id_fkey;

ALTER TABLE public.morpho_form
    DROP CONSTRAINT IF EXISTS morpho_form_lemma_id_fkey;

ALTER TABLE public.content_unit
    DROP CONSTRAINT IF EXISTS content_unit_variant_id_fkey;

ALTER TABLE public.correction_feedback_log
    DROP CONSTRAINT IF EXISTS correction_feedback_log_model_id_fkey;

ALTER TABLE public.correction_feedback_log
    DROP CONSTRAINT IF EXISTS correction_feedback_log_unit_id_fkey;

ALTER TABLE public.rel_content_context
    DROP CONSTRAINT IF EXISTS rel_content_context_unit_id_fkey;

ALTER TABLE public.rel_content_context
    DROP CONSTRAINT IF EXISTS rel_content_context_context_id_fkey;

ALTER TABLE public.rel_content_tone
    DROP CONSTRAINT IF EXISTS rel_content_tone_unit_id_fkey;

ALTER TABLE public.rel_content_tone
    DROP CONSTRAINT IF EXISTS rel_content_tone_tone_id_fkey;

-- ============================================================
-- STEP 2: RE-ADD FK constraints WITH referential actions
-- ============================================================

-- language_variant -> itself (recursive: dialect -> parent language)
-- RESTRICT: cannot delete Italian Standard if Neapolitan still exists
ALTER TABLE public.language_variant
    ADD CONSTRAINT language_variant_parent_variant_id_fkey
    FOREIGN KEY (parent_variant_id)
    REFERENCES public.language_variant(variant_id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE;

-- lemma -> language_variant
-- RESTRICT: cannot delete a variant that still has lemmas
ALTER TABLE public.lemma
    ADD CONSTRAINT lemma_variant_id_fkey
    FOREIGN KEY (variant_id)
    REFERENCES public.language_variant(variant_id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE;

-- morpho_form -> lemma
-- CASCADE: if lemma deleted, delete all its forms (vado/vai/va)
ALTER TABLE public.morpho_form
    ADD CONSTRAINT morpho_form_lemma_id_fkey
    FOREIGN KEY (lemma_id)
    REFERENCES public.lemma(lemma_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE;

-- content_unit -> language_variant
-- RESTRICT: cannot delete a variant that still has content
ALTER TABLE public.content_unit
    ADD CONSTRAINT content_unit_variant_id_fkey
    FOREIGN KEY (variant_id)
    REFERENCES public.language_variant(variant_id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE;

-- correction_feedback_log -> ai_model_registry
-- RESTRICT: forensic logs must be kept even if model is retired
ALTER TABLE public.correction_feedback_log
    ADD CONSTRAINT correction_feedback_log_model_id_fkey
    FOREIGN KEY (model_id)
    REFERENCES public.ai_model_registry(model_id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE;

-- correction_feedback_log -> content_unit
-- CASCADE: if content deleted, delete its feedback logs too
ALTER TABLE public.correction_feedback_log
    ADD CONSTRAINT correction_feedback_log_unit_id_fkey
    FOREIGN KEY (unit_id)
    REFERENCES public.content_unit(unit_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE;

-- rel_content_context -> content_unit
-- CASCADE: if content deleted, remove its context links
ALTER TABLE public.rel_content_context
    ADD CONSTRAINT rel_content_context_unit_id_fkey
    FOREIGN KEY (unit_id)
    REFERENCES public.content_unit(unit_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE;

-- rel_content_context -> cultural_context_tag
-- RESTRICT: cannot delete a tag still linked to content
ALTER TABLE public.rel_content_context
    ADD CONSTRAINT rel_content_context_context_id_fkey
    FOREIGN KEY (context_id)
    REFERENCES public.cultural_context_tag(context_id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE;

-- rel_content_tone -> content_unit
-- CASCADE: if content deleted, remove its tone links
ALTER TABLE public.rel_content_tone
    ADD CONSTRAINT rel_content_tone_unit_id_fkey
    FOREIGN KEY (unit_id)
    REFERENCES public.content_unit(unit_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE;

-- rel_content_tone -> tone_marker
-- RESTRICT: cannot delete a tone still linked to content
ALTER TABLE public.rel_content_tone
    ADD CONSTRAINT rel_content_tone_tone_id_fkey
    FOREIGN KEY (tone_id)
    REFERENCES public.tone_marker(tone_id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE;

-- ============================================================
-- END: all referential actions applied safely
-- ============================================================
