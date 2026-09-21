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
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_preference_adult_content_gate_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_adult_content_gate_options (
    id bigint NOT NULL
);


--
-- Name: org_preference_adult_content_gate_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_adult_content_gate_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_adult_content_gate_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_adult_content_gate_options_id_seq OWNED BY public.org_preference_adult_content_gate_options.id;


--
-- Name: org_preference_adult_content_gates; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_adult_content_gates (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_preference_adult_content_gates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_adult_content_gates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_adult_content_gates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_adult_content_gates_id_seq OWNED BY public.org_preference_adult_content_gates.id;


--
-- Name: org_preference_binding_methods; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_binding_methods (
    id bigint NOT NULL
);


--
-- Name: org_preference_binding_methods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_binding_methods_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_binding_methods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_binding_methods_id_seq OWNED BY public.org_preference_binding_methods.id;


--
-- Name: org_preference_cookies; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_cookies (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    consent_version uuid,
    consented boolean DEFAULT false NOT NULL,
    consented_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    functional boolean DEFAULT false NOT NULL,
    performant boolean DEFAULT false NOT NULL,
    targetable boolean DEFAULT false NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_preference_cookies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_cookies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_cookies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_cookies_id_seq OWNED BY public.org_preference_cookies.id;


--
-- Name: org_preference_currencies; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_currencies (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_preference_currencies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_currencies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_currencies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_currencies_id_seq OWNED BY public.org_preference_currencies.id;


--
-- Name: org_preference_currency_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_currency_options (
    id bigint NOT NULL
);


--
-- Name: org_preference_currency_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_currency_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_currency_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_currency_options_id_seq OWNED BY public.org_preference_currency_options.id;


--
-- Name: org_preference_date_format_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_date_format_options (
    id bigint NOT NULL
);


--
-- Name: org_preference_date_format_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_date_format_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_date_format_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_date_format_options_id_seq OWNED BY public.org_preference_date_format_options.id;


--
-- Name: org_preference_date_formats; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_date_formats (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_preference_date_formats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_date_formats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_date_formats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_date_formats_id_seq OWNED BY public.org_preference_date_formats.id;


--
-- Name: org_preference_dbsc_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_dbsc_statuses (
    id bigint NOT NULL
);


--
-- Name: org_preference_dbsc_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_dbsc_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_dbsc_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_dbsc_statuses_id_seq OWNED BY public.org_preference_dbsc_statuses.id;


--
-- Name: org_preference_densities; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_densities (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_preference_densities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_densities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_densities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_densities_id_seq OWNED BY public.org_preference_densities.id;


--
-- Name: org_preference_density_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_density_options (
    id bigint NOT NULL
);


--
-- Name: org_preference_density_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_density_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_density_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_density_options_id_seq OWNED BY public.org_preference_density_options.id;


--
-- Name: org_preference_language_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_language_options (
    id bigint NOT NULL
);


--
-- Name: org_preference_language_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_language_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_language_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_language_options_id_seq OWNED BY public.org_preference_language_options.id;


--
-- Name: org_preference_languages; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_languages (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_preference_languages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_languages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_languages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_languages_id_seq OWNED BY public.org_preference_languages.id;


--
-- Name: org_preference_motion_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_motion_options (
    id bigint NOT NULL
);


--
-- Name: org_preference_motion_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_motion_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_motion_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_motion_options_id_seq OWNED BY public.org_preference_motion_options.id;


--
-- Name: org_preference_motions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_motions (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_preference_motions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_motions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_motions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_motions_id_seq OWNED BY public.org_preference_motions.id;


--
-- Name: org_preference_page_size_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_page_size_options (
    id bigint NOT NULL
);


--
-- Name: org_preference_page_size_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_page_size_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_page_size_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_page_size_options_id_seq OWNED BY public.org_preference_page_size_options.id;


--
-- Name: org_preference_page_sizes; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_page_sizes (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_preference_page_sizes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_page_sizes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_page_sizes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_page_sizes_id_seq OWNED BY public.org_preference_page_sizes.id;


--
-- Name: org_preference_region_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_region_options (
    id bigint NOT NULL
);


--
-- Name: org_preference_region_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_region_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_region_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_region_options_id_seq OWNED BY public.org_preference_region_options.id;


--
-- Name: org_preference_regions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_regions (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_preference_regions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_regions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_regions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_regions_id_seq OWNED BY public.org_preference_regions.id;


--
-- Name: org_preference_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_statuses (
    id bigint NOT NULL
);


--
-- Name: org_preference_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_statuses_id_seq OWNED BY public.org_preference_statuses.id;


--
-- Name: org_preference_theme_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_theme_options (
    id bigint NOT NULL
);


--
-- Name: org_preference_theme_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_theme_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_theme_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_theme_options_id_seq OWNED BY public.org_preference_theme_options.id;


--
-- Name: org_preference_themes; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_themes (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_preference_themes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_themes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_themes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_themes_id_seq OWNED BY public.org_preference_themes.id;


--
-- Name: org_preference_time_format_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_time_format_options (
    id bigint NOT NULL
);


--
-- Name: org_preference_time_format_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_time_format_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_time_format_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_time_format_options_id_seq OWNED BY public.org_preference_time_format_options.id;


--
-- Name: org_preference_time_formats; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_time_formats (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_preference_time_formats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_time_formats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_time_formats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_time_formats_id_seq OWNED BY public.org_preference_time_formats.id;


--
-- Name: org_preference_timezone_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_timezone_options (
    id bigint NOT NULL
);


--
-- Name: org_preference_timezone_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_timezone_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_timezone_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_timezone_options_id_seq OWNED BY public.org_preference_timezone_options.id;


--
-- Name: org_preference_timezones; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preference_timezones (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_preference_timezones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preference_timezones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_timezones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_timezones_id_seq OWNED BY public.org_preference_timezones.id;


--
-- Name: org_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_preferences (
    id bigint NOT NULL,
    binding_method_id bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    dbsc_challenge text,
    dbsc_challenge_issued_at timestamp(6) with time zone,
    dbsc_public_key jsonb,
    dbsc_session_id character varying,
    dbsc_status_id bigint DEFAULT 0 NOT NULL,
    jti character varying,
    public_id character varying NOT NULL,
    replaced_by_id bigint,
    status_id bigint DEFAULT 2 NOT NULL,
    token_digest bytea,
    updated_at timestamp(6) with time zone NOT NULL,
    used_at timestamp(6) with time zone,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    explicit_fields jsonb DEFAULT '[]'::jsonb NOT NULL
);


--
-- Name: org_preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_preferences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preferences_id_seq OWNED BY public.org_preferences.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: org_preference_adult_content_gate_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_adult_content_gate_options ALTER COLUMN id SET DEFAULT nextval('public.org_preference_adult_content_gate_options_id_seq'::regclass);


--
-- Name: org_preference_adult_content_gates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_adult_content_gates ALTER COLUMN id SET DEFAULT nextval('public.org_preference_adult_content_gates_id_seq'::regclass);


--
-- Name: org_preference_binding_methods id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_binding_methods ALTER COLUMN id SET DEFAULT nextval('public.org_preference_binding_methods_id_seq'::regclass);


--
-- Name: org_preference_cookies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_cookies ALTER COLUMN id SET DEFAULT nextval('public.org_preference_cookies_id_seq'::regclass);


--
-- Name: org_preference_currencies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_currencies ALTER COLUMN id SET DEFAULT nextval('public.org_preference_currencies_id_seq'::regclass);


--
-- Name: org_preference_currency_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_currency_options ALTER COLUMN id SET DEFAULT nextval('public.org_preference_currency_options_id_seq'::regclass);


--
-- Name: org_preference_date_format_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_date_format_options ALTER COLUMN id SET DEFAULT nextval('public.org_preference_date_format_options_id_seq'::regclass);


--
-- Name: org_preference_date_formats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_date_formats ALTER COLUMN id SET DEFAULT nextval('public.org_preference_date_formats_id_seq'::regclass);


--
-- Name: org_preference_dbsc_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_dbsc_statuses ALTER COLUMN id SET DEFAULT nextval('public.org_preference_dbsc_statuses_id_seq'::regclass);


--
-- Name: org_preference_densities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_densities ALTER COLUMN id SET DEFAULT nextval('public.org_preference_densities_id_seq'::regclass);


--
-- Name: org_preference_density_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_density_options ALTER COLUMN id SET DEFAULT nextval('public.org_preference_density_options_id_seq'::regclass);


--
-- Name: org_preference_language_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_language_options ALTER COLUMN id SET DEFAULT nextval('public.org_preference_language_options_id_seq'::regclass);


--
-- Name: org_preference_languages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_languages ALTER COLUMN id SET DEFAULT nextval('public.org_preference_languages_id_seq'::regclass);


--
-- Name: org_preference_motion_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_motion_options ALTER COLUMN id SET DEFAULT nextval('public.org_preference_motion_options_id_seq'::regclass);


--
-- Name: org_preference_motions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_motions ALTER COLUMN id SET DEFAULT nextval('public.org_preference_motions_id_seq'::regclass);


--
-- Name: org_preference_page_size_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_page_size_options ALTER COLUMN id SET DEFAULT nextval('public.org_preference_page_size_options_id_seq'::regclass);


--
-- Name: org_preference_page_sizes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_page_sizes ALTER COLUMN id SET DEFAULT nextval('public.org_preference_page_sizes_id_seq'::regclass);


--
-- Name: org_preference_region_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_region_options ALTER COLUMN id SET DEFAULT nextval('public.org_preference_region_options_id_seq'::regclass);


--
-- Name: org_preference_regions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_regions ALTER COLUMN id SET DEFAULT nextval('public.org_preference_regions_id_seq'::regclass);


--
-- Name: org_preference_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_statuses ALTER COLUMN id SET DEFAULT nextval('public.org_preference_statuses_id_seq'::regclass);


--
-- Name: org_preference_theme_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_theme_options ALTER COLUMN id SET DEFAULT nextval('public.org_preference_theme_options_id_seq'::regclass);


--
-- Name: org_preference_themes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_themes ALTER COLUMN id SET DEFAULT nextval('public.org_preference_themes_id_seq'::regclass);


--
-- Name: org_preference_time_format_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_time_format_options ALTER COLUMN id SET DEFAULT nextval('public.org_preference_time_format_options_id_seq'::regclass);


--
-- Name: org_preference_time_formats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_time_formats ALTER COLUMN id SET DEFAULT nextval('public.org_preference_time_formats_id_seq'::regclass);


--
-- Name: org_preference_timezone_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_timezone_options ALTER COLUMN id SET DEFAULT nextval('public.org_preference_timezone_options_id_seq'::regclass);


--
-- Name: org_preference_timezones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_timezones ALTER COLUMN id SET DEFAULT nextval('public.org_preference_timezones_id_seq'::regclass);


--
-- Name: org_preferences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preferences ALTER COLUMN id SET DEFAULT nextval('public.org_preferences_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: org_preference_adult_content_gate_options org_preference_adult_content_gate_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_adult_content_gate_options
    ADD CONSTRAINT org_preference_adult_content_gate_options_pkey PRIMARY KEY (id);


--
-- Name: org_preference_adult_content_gates org_preference_adult_content_gates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_adult_content_gates
    ADD CONSTRAINT org_preference_adult_content_gates_pkey PRIMARY KEY (id);


--
-- Name: org_preference_binding_methods org_preference_binding_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_binding_methods
    ADD CONSTRAINT org_preference_binding_methods_pkey PRIMARY KEY (id);


--
-- Name: org_preference_cookies org_preference_cookies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_cookies
    ADD CONSTRAINT org_preference_cookies_pkey PRIMARY KEY (id);


--
-- Name: org_preference_currencies org_preference_currencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_currencies
    ADD CONSTRAINT org_preference_currencies_pkey PRIMARY KEY (id);


--
-- Name: org_preference_currency_options org_preference_currency_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_currency_options
    ADD CONSTRAINT org_preference_currency_options_pkey PRIMARY KEY (id);


--
-- Name: org_preference_date_format_options org_preference_date_format_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_date_format_options
    ADD CONSTRAINT org_preference_date_format_options_pkey PRIMARY KEY (id);


--
-- Name: org_preference_date_formats org_preference_date_formats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_date_formats
    ADD CONSTRAINT org_preference_date_formats_pkey PRIMARY KEY (id);


--
-- Name: org_preference_dbsc_statuses org_preference_dbsc_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_dbsc_statuses
    ADD CONSTRAINT org_preference_dbsc_statuses_pkey PRIMARY KEY (id);


--
-- Name: org_preference_densities org_preference_densities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_densities
    ADD CONSTRAINT org_preference_densities_pkey PRIMARY KEY (id);


--
-- Name: org_preference_density_options org_preference_density_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_density_options
    ADD CONSTRAINT org_preference_density_options_pkey PRIMARY KEY (id);


--
-- Name: org_preference_language_options org_preference_language_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_language_options
    ADD CONSTRAINT org_preference_language_options_pkey PRIMARY KEY (id);


--
-- Name: org_preference_languages org_preference_languages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_languages
    ADD CONSTRAINT org_preference_languages_pkey PRIMARY KEY (id);


--
-- Name: org_preference_motion_options org_preference_motion_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_motion_options
    ADD CONSTRAINT org_preference_motion_options_pkey PRIMARY KEY (id);


--
-- Name: org_preference_motions org_preference_motions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_motions
    ADD CONSTRAINT org_preference_motions_pkey PRIMARY KEY (id);


--
-- Name: org_preference_page_size_options org_preference_page_size_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_page_size_options
    ADD CONSTRAINT org_preference_page_size_options_pkey PRIMARY KEY (id);


--
-- Name: org_preference_page_sizes org_preference_page_sizes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_page_sizes
    ADD CONSTRAINT org_preference_page_sizes_pkey PRIMARY KEY (id);


--
-- Name: org_preference_region_options org_preference_region_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_region_options
    ADD CONSTRAINT org_preference_region_options_pkey PRIMARY KEY (id);


--
-- Name: org_preference_regions org_preference_regions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_regions
    ADD CONSTRAINT org_preference_regions_pkey PRIMARY KEY (id);


--
-- Name: org_preference_statuses org_preference_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_statuses
    ADD CONSTRAINT org_preference_statuses_pkey PRIMARY KEY (id);


--
-- Name: org_preference_theme_options org_preference_theme_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_theme_options
    ADD CONSTRAINT org_preference_theme_options_pkey PRIMARY KEY (id);


--
-- Name: org_preference_themes org_preference_themes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_themes
    ADD CONSTRAINT org_preference_themes_pkey PRIMARY KEY (id);


--
-- Name: org_preference_time_format_options org_preference_time_format_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_time_format_options
    ADD CONSTRAINT org_preference_time_format_options_pkey PRIMARY KEY (id);


--
-- Name: org_preference_time_formats org_preference_time_formats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_time_formats
    ADD CONSTRAINT org_preference_time_formats_pkey PRIMARY KEY (id);


--
-- Name: org_preference_timezone_options org_preference_timezone_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_timezone_options
    ADD CONSTRAINT org_preference_timezone_options_pkey PRIMARY KEY (id);


--
-- Name: org_preference_timezones org_preference_timezones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_timezones
    ADD CONSTRAINT org_preference_timezones_pkey PRIMARY KEY (id);


--
-- Name: org_preferences org_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preferences
    ADD CONSTRAINT org_preferences_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: index_org_preference_adult_content_gates_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preference_adult_content_gates_on_option_id ON public.org_preference_adult_content_gates USING btree (option_id);


--
-- Name: index_org_preference_adult_content_gates_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_preference_adult_content_gates_on_preference_id ON public.org_preference_adult_content_gates USING btree (preference_id);


--
-- Name: index_org_preference_cookies_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_preference_cookies_on_preference_id ON public.org_preference_cookies USING btree (preference_id);


--
-- Name: index_org_preference_currencies_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preference_currencies_on_option_id ON public.org_preference_currencies USING btree (option_id);


--
-- Name: index_org_preference_currencies_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_preference_currencies_on_preference_id ON public.org_preference_currencies USING btree (preference_id);


--
-- Name: index_org_preference_date_formats_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preference_date_formats_on_option_id ON public.org_preference_date_formats USING btree (option_id);


--
-- Name: index_org_preference_date_formats_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_preference_date_formats_on_preference_id ON public.org_preference_date_formats USING btree (preference_id);


--
-- Name: index_org_preference_densities_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preference_densities_on_option_id ON public.org_preference_densities USING btree (option_id);


--
-- Name: index_org_preference_densities_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_preference_densities_on_preference_id ON public.org_preference_densities USING btree (preference_id);


--
-- Name: index_org_preference_languages_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preference_languages_on_option_id ON public.org_preference_languages USING btree (option_id);


--
-- Name: index_org_preference_languages_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_preference_languages_on_preference_id ON public.org_preference_languages USING btree (preference_id);


--
-- Name: index_org_preference_motions_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preference_motions_on_option_id ON public.org_preference_motions USING btree (option_id);


--
-- Name: index_org_preference_motions_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_preference_motions_on_preference_id ON public.org_preference_motions USING btree (preference_id);


--
-- Name: index_org_preference_page_sizes_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preference_page_sizes_on_option_id ON public.org_preference_page_sizes USING btree (option_id);


--
-- Name: index_org_preference_page_sizes_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_preference_page_sizes_on_preference_id ON public.org_preference_page_sizes USING btree (preference_id);


--
-- Name: index_org_preference_regions_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preference_regions_on_option_id ON public.org_preference_regions USING btree (option_id);


--
-- Name: index_org_preference_regions_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_preference_regions_on_preference_id ON public.org_preference_regions USING btree (preference_id);


--
-- Name: index_org_preference_themes_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preference_themes_on_option_id ON public.org_preference_themes USING btree (option_id);


--
-- Name: index_org_preference_themes_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_preference_themes_on_preference_id ON public.org_preference_themes USING btree (preference_id);


--
-- Name: index_org_preference_time_formats_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preference_time_formats_on_option_id ON public.org_preference_time_formats USING btree (option_id);


--
-- Name: index_org_preference_time_formats_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_preference_time_formats_on_preference_id ON public.org_preference_time_formats USING btree (preference_id);


--
-- Name: index_org_preference_timezones_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preference_timezones_on_option_id ON public.org_preference_timezones USING btree (option_id);


--
-- Name: index_org_preference_timezones_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_preference_timezones_on_preference_id ON public.org_preference_timezones USING btree (preference_id);


--
-- Name: index_org_preferences_on_binding_method_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preferences_on_binding_method_id ON public.org_preferences USING btree (binding_method_id);


--
-- Name: index_org_preferences_on_dbsc_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_preferences_on_dbsc_session_id ON public.org_preferences USING btree (dbsc_session_id);


--
-- Name: index_org_preferences_on_dbsc_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preferences_on_dbsc_status_id ON public.org_preferences USING btree (dbsc_status_id);


--
-- Name: index_org_preferences_on_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_preferences_on_jti ON public.org_preferences USING btree (jti);


--
-- Name: index_org_preferences_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_preferences_on_public_id ON public.org_preferences USING btree (public_id);


--
-- Name: index_org_preferences_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preferences_on_purge_eligible_at ON public.org_preferences USING btree (purge_eligible_at);


--
-- Name: index_org_preferences_on_replaced_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preferences_on_replaced_by_id ON public.org_preferences USING btree (replaced_by_id);


--
-- Name: index_org_preferences_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preferences_on_status_id ON public.org_preferences USING btree (status_id);


--
-- Name: index_org_preferences_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preferences_on_token_digest ON public.org_preferences USING btree (token_digest);


--
-- Name: index_org_preferences_on_used_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preferences_on_used_at ON public.org_preferences USING btree (used_at);


--
-- Name: org_preference_languages fk_org_preference_languages_on_option_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_languages
    ADD CONSTRAINT fk_org_preference_languages_on_option_id FOREIGN KEY (option_id) REFERENCES public.org_preference_language_options(id);


--
-- Name: org_preference_regions fk_org_preference_regions_on_option_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_regions
    ADD CONSTRAINT fk_org_preference_regions_on_option_id FOREIGN KEY (option_id) REFERENCES public.org_preference_region_options(id);


--
-- Name: org_preference_themes fk_org_preference_themes_on_option_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_themes
    ADD CONSTRAINT fk_org_preference_themes_on_option_id FOREIGN KEY (option_id) REFERENCES public.org_preference_theme_options(id);


--
-- Name: org_preference_timezones fk_org_preference_timezones_on_option_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_timezones
    ADD CONSTRAINT fk_org_preference_timezones_on_option_id FOREIGN KEY (option_id) REFERENCES public.org_preference_timezone_options(id);


--
-- Name: org_preferences fk_org_preferences_on_binding_method_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preferences
    ADD CONSTRAINT fk_org_preferences_on_binding_method_id FOREIGN KEY (binding_method_id) REFERENCES public.org_preference_binding_methods(id);


--
-- Name: org_preferences fk_org_preferences_on_dbsc_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preferences
    ADD CONSTRAINT fk_org_preferences_on_dbsc_status_id FOREIGN KEY (dbsc_status_id) REFERENCES public.org_preference_dbsc_statuses(id);


--
-- Name: org_preferences fk_org_preferences_on_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preferences
    ADD CONSTRAINT fk_org_preferences_on_status_id FOREIGN KEY (status_id) REFERENCES public.org_preference_statuses(id);


--
-- Name: org_preference_languages fk_rails_1a77b3c035; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_languages
    ADD CONSTRAINT fk_rails_1a77b3c035 FOREIGN KEY (preference_id) REFERENCES public.org_preferences(id);


--
-- Name: org_preference_time_formats fk_rails_295c8580ef; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_time_formats
    ADD CONSTRAINT fk_rails_295c8580ef FOREIGN KEY (option_id) REFERENCES public.org_preference_time_format_options(id);


--
-- Name: org_preference_regions fk_rails_42f3316029; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_regions
    ADD CONSTRAINT fk_rails_42f3316029 FOREIGN KEY (preference_id) REFERENCES public.org_preferences(id);


--
-- Name: org_preference_time_formats fk_rails_4a6bf0586f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_time_formats
    ADD CONSTRAINT fk_rails_4a6bf0586f FOREIGN KEY (preference_id) REFERENCES public.org_preferences(id);


--
-- Name: org_preference_date_formats fk_rails_4d0bf5fc1c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_date_formats
    ADD CONSTRAINT fk_rails_4d0bf5fc1c FOREIGN KEY (preference_id) REFERENCES public.org_preferences(id);


--
-- Name: org_preference_currencies fk_rails_61ea4e8788; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_currencies
    ADD CONSTRAINT fk_rails_61ea4e8788 FOREIGN KEY (preference_id) REFERENCES public.org_preferences(id);


--
-- Name: org_preference_adult_content_gates fk_rails_6279b569d5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_adult_content_gates
    ADD CONSTRAINT fk_rails_6279b569d5 FOREIGN KEY (option_id) REFERENCES public.org_preference_adult_content_gate_options(id);


--
-- Name: org_preference_date_formats fk_rails_68048cb726; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_date_formats
    ADD CONSTRAINT fk_rails_68048cb726 FOREIGN KEY (option_id) REFERENCES public.org_preference_date_format_options(id);


--
-- Name: org_preference_adult_content_gates fk_rails_70b22e3a60; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_adult_content_gates
    ADD CONSTRAINT fk_rails_70b22e3a60 FOREIGN KEY (preference_id) REFERENCES public.org_preferences(id);


--
-- Name: org_preference_cookies fk_rails_73a85808d0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_cookies
    ADD CONSTRAINT fk_rails_73a85808d0 FOREIGN KEY (preference_id) REFERENCES public.org_preferences(id);


--
-- Name: org_preference_timezones fk_rails_97d21cd824; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_timezones
    ADD CONSTRAINT fk_rails_97d21cd824 FOREIGN KEY (preference_id) REFERENCES public.org_preferences(id);


--
-- Name: org_preferences fk_rails_981b4c7c84; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preferences
    ADD CONSTRAINT fk_rails_981b4c7c84 FOREIGN KEY (replaced_by_id) REFERENCES public.org_preferences(id) ON DELETE SET NULL;


--
-- Name: org_preference_densities fk_rails_a7ea743e5b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_densities
    ADD CONSTRAINT fk_rails_a7ea743e5b FOREIGN KEY (preference_id) REFERENCES public.org_preferences(id);


--
-- Name: org_preference_motions fk_rails_ae96713d34; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_motions
    ADD CONSTRAINT fk_rails_ae96713d34 FOREIGN KEY (preference_id) REFERENCES public.org_preferences(id);


--
-- Name: org_preference_currencies fk_rails_bdbecd7417; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_currencies
    ADD CONSTRAINT fk_rails_bdbecd7417 FOREIGN KEY (option_id) REFERENCES public.org_preference_currency_options(id);


--
-- Name: org_preference_densities fk_rails_ca105ded15; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_densities
    ADD CONSTRAINT fk_rails_ca105ded15 FOREIGN KEY (option_id) REFERENCES public.org_preference_density_options(id);


--
-- Name: org_preference_page_sizes fk_rails_d2b18f684e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_page_sizes
    ADD CONSTRAINT fk_rails_d2b18f684e FOREIGN KEY (option_id) REFERENCES public.org_preference_page_size_options(id);


--
-- Name: org_preference_motions fk_rails_e20b9ab261; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_motions
    ADD CONSTRAINT fk_rails_e20b9ab261 FOREIGN KEY (option_id) REFERENCES public.org_preference_motion_options(id);


--
-- Name: org_preference_page_sizes fk_rails_e78ccd1259; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_page_sizes
    ADD CONSTRAINT fk_rails_e78ccd1259 FOREIGN KEY (preference_id) REFERENCES public.org_preferences(id);


--
-- Name: org_preference_themes fk_rails_eee86b08b3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_themes
    ADD CONSTRAINT fk_rails_eee86b08b3 FOREIGN KEY (preference_id) REFERENCES public.org_preferences(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260921133000'),
('20260612000001'),
('20260530120000'),
('20260530031000'),
('20260526120201'),
('20260526090000'),
('20260518044537'),
('20260518030000');

