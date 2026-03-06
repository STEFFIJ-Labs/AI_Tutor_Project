--
-- PostgreSQL database dump
--

\restrict bwR082h2IgSw6Ip0lM1FZhzstya4CfVrZcRFOhBbe2M5oQhP5agmuaplosryhfS

-- Dumped from database version 16.11 (Ubuntu 16.11-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.11 (Ubuntu 16.11-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ai_model_registry; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ai_model_registry (
    model_id integer NOT NULL,
    model_version character varying(50) NOT NULL,
    release_date date,
    config_params_json jsonb
);


ALTER TABLE public.ai_model_registry OWNER TO postgres;

--
-- Name: ai_model_registry_model_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ai_model_registry_model_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ai_model_registry_model_id_seq OWNER TO postgres;

--
-- Name: ai_model_registry_model_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ai_model_registry_model_id_seq OWNED BY public.ai_model_registry.model_id;


--
-- Name: content_unit; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.content_unit (
    unit_id integer NOT NULL,
    content_raw text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    content_type character varying(50) NOT NULL,
    content_hash character varying(255) NOT NULL,
    source_origin character varying(150),
    syntax_ud_json jsonb,
    tech_meta_json jsonb,
    source_metadata_json jsonb,
    variant_id integer
);


ALTER TABLE public.content_unit OWNER TO postgres;

--
-- Name: content_unit_unit_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.content_unit_unit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.content_unit_unit_id_seq OWNER TO postgres;

--
-- Name: content_unit_unit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.content_unit_unit_id_seq OWNED BY public.content_unit.unit_id;


--
-- Name: correction_feedback_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.correction_feedback_log (
    log_id integer NOT NULL,
    error_severity character varying(50),
    "timestamp" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    correction_diff text,
    error_type character varying(100),
    model_id integer,
    unit_id integer
);


ALTER TABLE public.correction_feedback_log OWNER TO postgres;

--
-- Name: correction_feedback_log_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.correction_feedback_log_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.correction_feedback_log_log_id_seq OWNER TO postgres;

--
-- Name: correction_feedback_log_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.correction_feedback_log_log_id_seq OWNED BY public.correction_feedback_log.log_id;


--
-- Name: cultural_context_tag; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cultural_context_tag (
    context_id integer NOT NULL,
    context_name character varying(150) NOT NULL,
    tag_category character varying(100),
    cue_type character varying(100),
    description text
);


ALTER TABLE public.cultural_context_tag OWNER TO postgres;

--
-- Name: cultural_context_tag_context_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cultural_context_tag_context_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cultural_context_tag_context_id_seq OWNER TO postgres;

--
-- Name: cultural_context_tag_context_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cultural_context_tag_context_id_seq OWNED BY public.cultural_context_tag.context_id;


--
-- Name: language_variant; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.language_variant (
    variant_id integer NOT NULL,
    iso_code character varying(10) NOT NULL,
    variant_name character varying(100) NOT NULL,
    parent_variant_id integer
);


ALTER TABLE public.language_variant OWNER TO postgres;

--
-- Name: language_variant_variant_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.language_variant_variant_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.language_variant_variant_id_seq OWNER TO postgres;

--
-- Name: language_variant_variant_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.language_variant_variant_id_seq OWNED BY public.language_variant.variant_id;


--
-- Name: lemma; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lemma (
    lemma_id integer NOT NULL,
    text_root character varying(255) NOT NULL,
    grammatical_category character varying(100),
    frequency_rank integer,
    interference_json jsonb,
    variant_id integer
);


ALTER TABLE public.lemma OWNER TO postgres;

--
-- Name: lemma_lemma_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lemma_lemma_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.lemma_lemma_id_seq OWNER TO postgres;

--
-- Name: lemma_lemma_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.lemma_lemma_id_seq OWNED BY public.lemma.lemma_id;


--
-- Name: morpho_form; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.morpho_form (
    form_id integer NOT NULL,
    lemma_id integer NOT NULL,
    surface_form character varying(255) NOT NULL,
    grammar_json jsonb
);


ALTER TABLE public.morpho_form OWNER TO postgres;

--
-- Name: morpho_form_form_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.morpho_form_form_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.morpho_form_form_id_seq OWNER TO postgres;

--
-- Name: morpho_form_form_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.morpho_form_form_id_seq OWNED BY public.morpho_form.form_id;


--
-- Name: rel_content_context; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rel_content_context (
    unit_id integer NOT NULL,
    context_id integer NOT NULL,
    relevance_score numeric(5,2)
);


ALTER TABLE public.rel_content_context OWNER TO postgres;

--
-- Name: rel_content_tone; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rel_content_tone (
    unit_id integer NOT NULL,
    tone_id integer NOT NULL,
    intensity_score numeric(5,2)
);


ALTER TABLE public.rel_content_tone OWNER TO postgres;

--
-- Name: tone_marker; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tone_marker (
    tone_id integer NOT NULL,
    tone_name character varying(100) NOT NULL
);


ALTER TABLE public.tone_marker OWNER TO postgres;

--
-- Name: tone_marker_tone_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tone_marker_tone_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tone_marker_tone_id_seq OWNER TO postgres;

--
-- Name: tone_marker_tone_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tone_marker_tone_id_seq OWNED BY public.tone_marker.tone_id;


--
-- Name: ai_model_registry model_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ai_model_registry ALTER COLUMN model_id SET DEFAULT nextval('public.ai_model_registry_model_id_seq'::regclass);


--
-- Name: content_unit unit_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.content_unit ALTER COLUMN unit_id SET DEFAULT nextval('public.content_unit_unit_id_seq'::regclass);


--
-- Name: correction_feedback_log log_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.correction_feedback_log ALTER COLUMN log_id SET DEFAULT nextval('public.correction_feedback_log_log_id_seq'::regclass);


--
-- Name: cultural_context_tag context_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cultural_context_tag ALTER COLUMN context_id SET DEFAULT nextval('public.cultural_context_tag_context_id_seq'::regclass);


--
-- Name: language_variant variant_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.language_variant ALTER COLUMN variant_id SET DEFAULT nextval('public.language_variant_variant_id_seq'::regclass);


--
-- Name: lemma lemma_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lemma ALTER COLUMN lemma_id SET DEFAULT nextval('public.lemma_lemma_id_seq'::regclass);


--
-- Name: morpho_form form_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.morpho_form ALTER COLUMN form_id SET DEFAULT nextval('public.morpho_form_form_id_seq'::regclass);


--
-- Name: tone_marker tone_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tone_marker ALTER COLUMN tone_id SET DEFAULT nextval('public.tone_marker_tone_id_seq'::regclass);


--
-- Data for Name: ai_model_registry; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ai_model_registry (model_id, model_version, release_date, config_params_json) FROM stdin;
\.


--
-- Data for Name: content_unit; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.content_unit (unit_id, content_raw, created_at, content_type, content_hash, source_origin, syntax_ud_json, tech_meta_json, source_metadata_json, variant_id) FROM stdin;
1	The quick brown fox jumps over the lazy dog.	2026-02-20 23:08:10.46092	Phrase	hash_99abc123	AI_Generated_Corpus	{"dependencies": [{"rel": "root", "word": "jumps"}, {"rel": "nsubj", "word": "fox"}]}	{"readability_index": 8.5, "ai_confidence_score": 0.98}	\N	4
\.


--
-- Data for Name: correction_feedback_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.correction_feedback_log (log_id, error_severity, "timestamp", correction_diff, error_type, model_id, unit_id) FROM stdin;
\.


--
-- Data for Name: cultural_context_tag; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cultural_context_tag (context_id, context_name, tag_category, cue_type, description) FROM stdin;
1	Academic Lecture	Education	Contextual	University lecture or formal academic writing
\.


--
-- Data for Name: language_variant; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.language_variant (variant_id, iso_code, variant_name, parent_variant_id) FROM stdin;
1	it-IT	Standard Italian	\N
2	nap-IT	Neapolitan Dialect	1
3	fi-FI	Standard Finnish	\N
4	en-US	American English	\N
\.


--
-- Data for Name: lemma; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.lemma (lemma_id, text_root, grammatical_category, frequency_rank, interference_json, variant_id) FROM stdin;
1	run	verb	50	{"severity": "high", "L1_transfer_errors": ["false_friends", "tense_mismatch"]}	4
\.


--
-- Data for Name: morpho_form; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.morpho_form (form_id, lemma_id, surface_form, grammar_json) FROM stdin;
\.


--
-- Data for Name: rel_content_context; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rel_content_context (unit_id, context_id, relevance_score) FROM stdin;
\.


--
-- Data for Name: rel_content_tone; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rel_content_tone (unit_id, tone_id, intensity_score) FROM stdin;
\.


--
-- Data for Name: tone_marker; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tone_marker (tone_id, tone_name) FROM stdin;
1	Formal
2	Colloquial
\.


--
-- Name: ai_model_registry_model_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ai_model_registry_model_id_seq', 1, false);


--
-- Name: content_unit_unit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.content_unit_unit_id_seq', 1, true);


--
-- Name: correction_feedback_log_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.correction_feedback_log_log_id_seq', 1, false);


--
-- Name: cultural_context_tag_context_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cultural_context_tag_context_id_seq', 1, true);


--
-- Name: language_variant_variant_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.language_variant_variant_id_seq', 4, true);


--
-- Name: lemma_lemma_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.lemma_lemma_id_seq', 1, true);


--
-- Name: morpho_form_form_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.morpho_form_form_id_seq', 1, false);


--
-- Name: tone_marker_tone_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tone_marker_tone_id_seq', 2, true);


--
-- Name: ai_model_registry ai_model_registry_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ai_model_registry
    ADD CONSTRAINT ai_model_registry_pkey PRIMARY KEY (model_id);


--
-- Name: content_unit content_unit_content_hash_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.content_unit
    ADD CONSTRAINT content_unit_content_hash_key UNIQUE (content_hash);


--
-- Name: content_unit content_unit_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.content_unit
    ADD CONSTRAINT content_unit_pkey PRIMARY KEY (unit_id);


--
-- Name: correction_feedback_log correction_feedback_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.correction_feedback_log
    ADD CONSTRAINT correction_feedback_log_pkey PRIMARY KEY (log_id);


--
-- Name: cultural_context_tag cultural_context_tag_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cultural_context_tag
    ADD CONSTRAINT cultural_context_tag_pkey PRIMARY KEY (context_id);


--
-- Name: language_variant language_variant_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.language_variant
    ADD CONSTRAINT language_variant_pkey PRIMARY KEY (variant_id);


--
-- Name: lemma lemma_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lemma
    ADD CONSTRAINT lemma_pkey PRIMARY KEY (lemma_id);


--
-- Name: morpho_form morpho_form_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.morpho_form
    ADD CONSTRAINT morpho_form_pkey PRIMARY KEY (form_id);


--
-- Name: rel_content_context rel_content_context_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rel_content_context
    ADD CONSTRAINT rel_content_context_pkey PRIMARY KEY (unit_id, context_id);


--
-- Name: rel_content_tone rel_content_tone_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rel_content_tone
    ADD CONSTRAINT rel_content_tone_pkey PRIMARY KEY (unit_id, tone_id);


--
-- Name: tone_marker tone_marker_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tone_marker
    ADD CONSTRAINT tone_marker_pkey PRIMARY KEY (tone_id);


--
-- Name: content_unit content_unit_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.content_unit
    ADD CONSTRAINT content_unit_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.language_variant(variant_id);


--
-- Name: correction_feedback_log correction_feedback_log_model_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.correction_feedback_log
    ADD CONSTRAINT correction_feedback_log_model_id_fkey FOREIGN KEY (model_id) REFERENCES public.ai_model_registry(model_id);


--
-- Name: correction_feedback_log correction_feedback_log_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.correction_feedback_log
    ADD CONSTRAINT correction_feedback_log_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.content_unit(unit_id);


--
-- Name: language_variant language_variant_parent_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.language_variant
    ADD CONSTRAINT language_variant_parent_variant_id_fkey FOREIGN KEY (parent_variant_id) REFERENCES public.language_variant(variant_id);


--
-- Name: lemma lemma_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lemma
    ADD CONSTRAINT lemma_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.language_variant(variant_id);


--
-- Name: morpho_form morpho_form_lemma_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.morpho_form
    ADD CONSTRAINT morpho_form_lemma_id_fkey FOREIGN KEY (lemma_id) REFERENCES public.lemma(lemma_id);


--
-- Name: rel_content_context rel_content_context_context_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rel_content_context
    ADD CONSTRAINT rel_content_context_context_id_fkey FOREIGN KEY (context_id) REFERENCES public.cultural_context_tag(context_id);


--
-- Name: rel_content_context rel_content_context_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rel_content_context
    ADD CONSTRAINT rel_content_context_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.content_unit(unit_id);


--
-- Name: rel_content_tone rel_content_tone_tone_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rel_content_tone
    ADD CONSTRAINT rel_content_tone_tone_id_fkey FOREIGN KEY (tone_id) REFERENCES public.tone_marker(tone_id);


--
-- Name: rel_content_tone rel_content_tone_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rel_content_tone
    ADD CONSTRAINT rel_content_tone_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.content_unit(unit_id);


--
-- PostgreSQL database dump complete
--

\unrestrict bwR082h2IgSw6Ip0lM1FZhzstya4CfVrZcRFOhBbe2M5oQhP5agmuaplosryhfS

