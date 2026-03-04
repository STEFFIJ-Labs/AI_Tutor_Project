CREATE TABLE IF NOT EXISTS public.language_variant (
    variant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    iso_code VARCHAR(10) NOT NULL UNIQUE,
    variant_name VARCHAR(100) NOT NULL,
    parent_variant_id UUID REFERENCES public.language_variant(variant_id) ON DELETE CASCADE ON UPDATE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.language_variant ENABLE ROW LEVEL SECURITY;
-- trigger_sync
-- trigger_deployment
