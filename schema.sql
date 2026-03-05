-- 1. RESET TOTALE
DROP TABLE IF EXISTS public.morpho_form CASCADE;
DROP TABLE IF EXISTS public.lemma CASCADE;
DROP TABLE IF EXISTS public.language_variant CASCADE;

-- 2. STRUTTURA PULITA
CREATE TABLE public.language_variant (
    variant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) UNIQUE NOT NULL,
    language_code VARCHAR(10) NOT NULL
);

CREATE TABLE public.lemma (
    lemma_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    variant_id UUID NOT NULL REFERENCES public.language_variant(variant_id) ON DELETE CASCADE,
    term VARCHAR(255) NOT NULL,
    lexical_category VARCHAR(50),
    definition TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE public.morpho_form (
    form_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lemma_id UUID NOT NULL REFERENCES public.lemma(lemma_id) ON DELETE CASCADE,
    surface_form VARCHAR(255) NOT NULL,
    grammar_json JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. INSERIMENTO DATI SENZA CONDIZIONI (Perché abbiamo fatto il DROP prima)
WITH lang_insert AS (
    INSERT INTO public.language_variant (name, language_code)
    VALUES ('Finnish-Standard', 'fi-FI')
    RETURNING variant_id
),
lemma_insert AS (
    INSERT INTO public.lemma (variant_id, term, lexical_category, definition)
    SELECT variant_id, 'koira', 'noun', 'Domesticated mammal.'
    FROM lang_insert
    RETURNING lemma_id
)
INSERT INTO public.morpho_form (lemma_id, surface_form, grammar_json)
SELECT lemma_id, 'koiran', '{"case": "genitive"}' FROM lemma_insert;
