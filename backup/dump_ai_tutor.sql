--
-- PostgreSQL database dump
--

\restrict wzSITCD4KGrcj74zu7VeFJzx1emSFYCNfA3xNRWr93BST0SGvpw48eZIjzhPyy1

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.9 (Ubuntu 17.9-1.pgdg24.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: rls_auto_enable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rls_auto_enable() RETURNS event_trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ai_model_registry; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_model_registry (
    model_id integer NOT NULL,
    model_name character varying(50) NOT NULL,
    model_version character varying(50) NOT NULL,
    hf_adapter_path character varying(255),
    training_status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    release_date date,
    config_params_json jsonb
);


--
-- Name: ai_model_registry_model_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_model_registry_model_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_model_registry_model_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_model_registry_model_id_seq OWNED BY public.ai_model_registry.model_id;


--
-- Name: content_unit; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_unit (
    unit_id integer NOT NULL,
    content_raw text NOT NULL,
    content_type character varying(50) NOT NULL,
    content_hash character varying(255) NOT NULL,
    cefr_level character varying(2),
    is_idiom boolean DEFAULT false NOT NULL,
    difficulty character varying(10),
    source_origin character varying(150),
    created_at timestamp without time zone DEFAULT now(),
    syntax_ud_json jsonb,
    tech_meta_json jsonb,
    source_metadata_json jsonb,
    variant_id integer
);


--
-- Name: content_unit_unit_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_unit_unit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_unit_unit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_unit_unit_id_seq OWNED BY public.content_unit.unit_id;


--
-- Name: correction_feedback_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.correction_feedback_log (
    log_id integer NOT NULL,
    error_severity character varying(20),
    error_type character varying(100),
    correction_diff text,
    training_cycle integer DEFAULT 1 NOT NULL,
    feedback_source character varying(50) DEFAULT 'database_out'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    model_id integer,
    unit_id integer
);


--
-- Name: correction_feedback_log_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.correction_feedback_log_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: correction_feedback_log_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.correction_feedback_log_log_id_seq OWNED BY public.correction_feedback_log.log_id;


--
-- Name: cultural_context_tag; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cultural_context_tag (
    context_id integer NOT NULL,
    context_name character varying(255) NOT NULL,
    tag_category character varying(100),
    cue_type character varying(100),
    description text
);


--
-- Name: cultural_context_tag_context_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cultural_context_tag_context_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cultural_context_tag_context_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cultural_context_tag_context_id_seq OWNED BY public.cultural_context_tag.context_id;


--
-- Name: language_variant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.language_variant (
    variant_id integer NOT NULL,
    iso_code character varying(10) NOT NULL,
    variant_name character varying(100) NOT NULL,
    is_pivot boolean DEFAULT false NOT NULL,
    parent_variant_id integer
);


--
-- Name: language_variant_variant_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.language_variant_variant_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: language_variant_variant_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.language_variant_variant_id_seq OWNED BY public.language_variant.variant_id;


--
-- Name: lemma; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lemma (
    lemma_id integer NOT NULL,
    text_root character varying(255) NOT NULL,
    grammatical_category character varying(100),
    frequency_rank integer,
    interference_json jsonb,
    variant_id integer
);


--
-- Name: lemma_lemma_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.lemma_lemma_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: lemma_lemma_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.lemma_lemma_id_seq OWNED BY public.lemma.lemma_id;


--
-- Name: media_asset; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.media_asset (
    asset_id integer NOT NULL,
    asset_type character varying(10) NOT NULL,
    file_format character varying(10) NOT NULL,
    file_name character varying(255) NOT NULL,
    storage_location character varying(50) DEFAULT 'github_lfs'::character varying NOT NULL,
    lfs_pointer jsonb,
    created_at timestamp without time zone DEFAULT now(),
    unit_id integer NOT NULL,
    variant_id integer
);


--
-- Name: media_asset_asset_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.media_asset_asset_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: media_asset_asset_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.media_asset_asset_id_seq OWNED BY public.media_asset.asset_id;


--
-- Name: morpho_form; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.morpho_form (
    form_id integer NOT NULL,
    surface_form character varying(255) NOT NULL,
    grammar_json jsonb,
    lemma_id integer NOT NULL
);


--
-- Name: morpho_form_form_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.morpho_form_form_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: morpho_form_form_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.morpho_form_form_id_seq OWNED BY public.morpho_form.form_id;


--
-- Name: rel_content_context; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rel_content_context (
    unit_id integer NOT NULL,
    context_id integer NOT NULL,
    relevance_score numeric(5,2)
);


--
-- Name: rel_content_tone; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rel_content_tone (
    unit_id integer NOT NULL,
    tone_id integer NOT NULL,
    intensity_score numeric(5,2)
);


--
-- Name: tone_marker; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tone_marker (
    tone_id integer NOT NULL,
    tone_name character varying(100) NOT NULL,
    cue_type character varying(100)
);


--
-- Name: tone_marker_tone_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tone_marker_tone_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tone_marker_tone_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tone_marker_tone_id_seq OWNED BY public.tone_marker.tone_id;


--
-- Name: v_content_full_context; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_content_full_context AS
 SELECT cu.unit_id,
    cu.content_raw,
    cu.content_type,
    cu.cefr_level,
    cu.is_idiom,
    cu.difficulty,
    lv.iso_code,
    lv.variant_name,
    lv.is_pivot,
    tm.tone_name,
    cct.context_name AS theme
   FROM (((((public.content_unit cu
     JOIN public.language_variant lv ON ((cu.variant_id = lv.variant_id)))
     LEFT JOIN public.rel_content_tone rct ON ((cu.unit_id = rct.unit_id)))
     LEFT JOIN public.tone_marker tm ON ((rct.tone_id = tm.tone_id)))
     LEFT JOIN public.rel_content_context rcc ON ((cu.unit_id = rcc.unit_id)))
     LEFT JOIN public.cultural_context_tag cct ON ((rcc.context_id = cct.context_id)));


--
-- Name: vector_index; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vector_index (
    vector_id integer NOT NULL,
    pinecone_id character varying(255) NOT NULL,
    embedding_model character varying(100) NOT NULL,
    vector_status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    indexed_at timestamp without time zone DEFAULT now(),
    unit_id integer NOT NULL
);


--
-- Name: vector_index_vector_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.vector_index_vector_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: vector_index_vector_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.vector_index_vector_id_seq OWNED BY public.vector_index.vector_id;


--
-- Name: ai_model_registry model_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_model_registry ALTER COLUMN model_id SET DEFAULT nextval('public.ai_model_registry_model_id_seq'::regclass);


--
-- Name: content_unit unit_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_unit ALTER COLUMN unit_id SET DEFAULT nextval('public.content_unit_unit_id_seq'::regclass);


--
-- Name: correction_feedback_log log_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.correction_feedback_log ALTER COLUMN log_id SET DEFAULT nextval('public.correction_feedback_log_log_id_seq'::regclass);


--
-- Name: cultural_context_tag context_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cultural_context_tag ALTER COLUMN context_id SET DEFAULT nextval('public.cultural_context_tag_context_id_seq'::regclass);


--
-- Name: language_variant variant_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.language_variant ALTER COLUMN variant_id SET DEFAULT nextval('public.language_variant_variant_id_seq'::regclass);


--
-- Name: lemma lemma_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lemma ALTER COLUMN lemma_id SET DEFAULT nextval('public.lemma_lemma_id_seq'::regclass);


--
-- Name: media_asset asset_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_asset ALTER COLUMN asset_id SET DEFAULT nextval('public.media_asset_asset_id_seq'::regclass);


--
-- Name: morpho_form form_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.morpho_form ALTER COLUMN form_id SET DEFAULT nextval('public.morpho_form_form_id_seq'::regclass);


--
-- Name: tone_marker tone_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tone_marker ALTER COLUMN tone_id SET DEFAULT nextval('public.tone_marker_tone_id_seq'::regclass);


--
-- Name: vector_index vector_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vector_index ALTER COLUMN vector_id SET DEFAULT nextval('public.vector_index_vector_id_seq'::regclass);


--
-- Data for Name: ai_model_registry; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ai_model_registry (model_id, model_name, model_version, hf_adapter_path, training_status, release_date, config_params_json) FROM stdin;
\.


--
-- Data for Name: content_unit; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.content_unit (unit_id, content_raw, content_type, content_hash, cefr_level, is_idiom, difficulty, source_origin, created_at, syntax_ud_json, tech_meta_json, source_metadata_json, variant_id) FROM stdin;
\.


--
-- Data for Name: correction_feedback_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.correction_feedback_log (log_id, error_severity, error_type, correction_diff, training_cycle, feedback_source, created_at, model_id, unit_id) FROM stdin;
\.


--
-- Data for Name: cultural_context_tag; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.cultural_context_tag (context_id, context_name, tag_category, cue_type, description) FROM stdin;
\.


--
-- Data for Name: language_variant; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.language_variant (variant_id, iso_code, variant_name, is_pivot, parent_variant_id) FROM stdin;
\.


--
-- Data for Name: lemma; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.lemma (lemma_id, text_root, grammatical_category, frequency_rank, interference_json, variant_id) FROM stdin;
\.


--
-- Data for Name: media_asset; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.media_asset (asset_id, asset_type, file_format, file_name, storage_location, lfs_pointer, created_at, unit_id, variant_id) FROM stdin;
\.


--
-- Data for Name: morpho_form; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.morpho_form (form_id, surface_form, grammar_json, lemma_id) FROM stdin;
\.


--
-- Data for Name: rel_content_context; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.rel_content_context (unit_id, context_id, relevance_score) FROM stdin;
\.


--
-- Data for Name: rel_content_tone; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.rel_content_tone (unit_id, tone_id, intensity_score) FROM stdin;
\.


--
-- Data for Name: tone_marker; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tone_marker (tone_id, tone_name, cue_type) FROM stdin;
\.


--
-- Data for Name: vector_index; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.vector_index (vector_id, pinecone_id, embedding_model, vector_status, indexed_at, unit_id) FROM stdin;
\.


--
-- Name: ai_model_registry_model_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ai_model_registry_model_id_seq', 1, false);


--
-- Name: content_unit_unit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.content_unit_unit_id_seq', 1, false);


--
-- Name: correction_feedback_log_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.correction_feedback_log_log_id_seq', 1, false);


--
-- Name: cultural_context_tag_context_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.cultural_context_tag_context_id_seq', 1, false);


--
-- Name: language_variant_variant_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.language_variant_variant_id_seq', 1, false);


--
-- Name: lemma_lemma_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.lemma_lemma_id_seq', 1, false);


--
-- Name: media_asset_asset_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.media_asset_asset_id_seq', 1, false);


--
-- Name: morpho_form_form_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.morpho_form_form_id_seq', 1, false);


--
-- Name: tone_marker_tone_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tone_marker_tone_id_seq', 1, false);


--
-- Name: vector_index_vector_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.vector_index_vector_id_seq', 1, false);


--
-- Name: ai_model_registry ai_model_registry_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_model_registry
    ADD CONSTRAINT ai_model_registry_pkey PRIMARY KEY (model_id);


--
-- Name: content_unit content_unit_content_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_unit
    ADD CONSTRAINT content_unit_content_hash_key UNIQUE (content_hash);


--
-- Name: content_unit content_unit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_unit
    ADD CONSTRAINT content_unit_pkey PRIMARY KEY (unit_id);


--
-- Name: correction_feedback_log correction_feedback_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.correction_feedback_log
    ADD CONSTRAINT correction_feedback_log_pkey PRIMARY KEY (log_id);


--
-- Name: cultural_context_tag cultural_context_tag_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cultural_context_tag
    ADD CONSTRAINT cultural_context_tag_pkey PRIMARY KEY (context_id);


--
-- Name: language_variant language_variant_iso_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.language_variant
    ADD CONSTRAINT language_variant_iso_code_key UNIQUE (iso_code);


--
-- Name: language_variant language_variant_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.language_variant
    ADD CONSTRAINT language_variant_pkey PRIMARY KEY (variant_id);


--
-- Name: lemma lemma_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lemma
    ADD CONSTRAINT lemma_pkey PRIMARY KEY (lemma_id);


--
-- Name: media_asset media_asset_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_asset
    ADD CONSTRAINT media_asset_pkey PRIMARY KEY (asset_id);


--
-- Name: morpho_form morpho_form_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.morpho_form
    ADD CONSTRAINT morpho_form_pkey PRIMARY KEY (form_id);


--
-- Name: rel_content_context rel_content_context_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rel_content_context
    ADD CONSTRAINT rel_content_context_pkey PRIMARY KEY (unit_id, context_id);


--
-- Name: rel_content_tone rel_content_tone_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rel_content_tone
    ADD CONSTRAINT rel_content_tone_pkey PRIMARY KEY (unit_id, tone_id);


--
-- Name: tone_marker tone_marker_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tone_marker
    ADD CONSTRAINT tone_marker_pkey PRIMARY KEY (tone_id);


--
-- Name: vector_index vector_index_pinecone_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vector_index
    ADD CONSTRAINT vector_index_pinecone_id_key UNIQUE (pinecone_id);


--
-- Name: vector_index vector_index_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vector_index
    ADD CONSTRAINT vector_index_pkey PRIMARY KEY (vector_id);


--
-- Name: content_unit content_unit_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_unit
    ADD CONSTRAINT content_unit_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.language_variant(variant_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: correction_feedback_log correction_feedback_log_model_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.correction_feedback_log
    ADD CONSTRAINT correction_feedback_log_model_id_fkey FOREIGN KEY (model_id) REFERENCES public.ai_model_registry(model_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: correction_feedback_log correction_feedback_log_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.correction_feedback_log
    ADD CONSTRAINT correction_feedback_log_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.content_unit(unit_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: language_variant language_variant_parent_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.language_variant
    ADD CONSTRAINT language_variant_parent_variant_id_fkey FOREIGN KEY (parent_variant_id) REFERENCES public.language_variant(variant_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: lemma lemma_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lemma
    ADD CONSTRAINT lemma_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.language_variant(variant_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: media_asset media_asset_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_asset
    ADD CONSTRAINT media_asset_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.content_unit(unit_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: media_asset media_asset_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_asset
    ADD CONSTRAINT media_asset_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.language_variant(variant_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: morpho_form morpho_form_lemma_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.morpho_form
    ADD CONSTRAINT morpho_form_lemma_id_fkey FOREIGN KEY (lemma_id) REFERENCES public.lemma(lemma_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: rel_content_context rel_content_context_context_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rel_content_context
    ADD CONSTRAINT rel_content_context_context_id_fkey FOREIGN KEY (context_id) REFERENCES public.cultural_context_tag(context_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rel_content_context rel_content_context_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rel_content_context
    ADD CONSTRAINT rel_content_context_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.content_unit(unit_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: rel_content_tone rel_content_tone_tone_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rel_content_tone
    ADD CONSTRAINT rel_content_tone_tone_id_fkey FOREIGN KEY (tone_id) REFERENCES public.tone_marker(tone_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rel_content_tone rel_content_tone_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rel_content_tone
    ADD CONSTRAINT rel_content_tone_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.content_unit(unit_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: vector_index vector_index_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vector_index
    ADD CONSTRAINT vector_index_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.content_unit(unit_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ai_model_registry; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ai_model_registry ENABLE ROW LEVEL SECURITY;

--
-- Name: content_unit; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.content_unit ENABLE ROW LEVEL SECURITY;

--
-- Name: correction_feedback_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.correction_feedback_log ENABLE ROW LEVEL SECURITY;

--
-- Name: cultural_context_tag; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cultural_context_tag ENABLE ROW LEVEL SECURITY;

--
-- Name: language_variant; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.language_variant ENABLE ROW LEVEL SECURITY;

--
-- Name: lemma; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lemma ENABLE ROW LEVEL SECURITY;

--
-- Name: media_asset; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.media_asset ENABLE ROW LEVEL SECURITY;

--
-- Name: morpho_form; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.morpho_form ENABLE ROW LEVEL SECURITY;

--
-- Name: rel_content_context; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.rel_content_context ENABLE ROW LEVEL SECURITY;

--
-- Name: rel_content_tone; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.rel_content_tone ENABLE ROW LEVEL SECURITY;

--
-- Name: tone_marker; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tone_marker ENABLE ROW LEVEL SECURITY;

--
-- Name: vector_index; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.vector_index ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

\unrestrict wzSITCD4KGrcj74zu7VeFJzx1emSFYCNfA3xNRWr93BST0SGvpw48eZIjzhPyy1

