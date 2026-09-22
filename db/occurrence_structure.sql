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
-- Name: area_client_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.area_client_occurrences (
    id bigint NOT NULL,
    area_occurrence_id bigint NOT NULL,
    user_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: area_client_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.area_client_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: area_client_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.area_client_occurrences_id_seq OWNED BY public.area_client_occurrences.id;


--
-- Name: area_domain_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.area_domain_occurrences (
    id bigint NOT NULL,
    area_occurrence_id bigint NOT NULL,
    domain_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: area_domain_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.area_domain_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: area_domain_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.area_domain_occurrences_id_seq OWNED BY public.area_domain_occurrences.id;


--
-- Name: area_email_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.area_email_occurrences (
    id bigint NOT NULL,
    area_occurrence_id bigint NOT NULL,
    email_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: area_email_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.area_email_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: area_email_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.area_email_occurrences_id_seq OWNED BY public.area_email_occurrences.id;


--
-- Name: area_ip_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.area_ip_occurrences (
    id bigint NOT NULL,
    area_occurrence_id bigint NOT NULL,
    ip_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: area_ip_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.area_ip_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: area_ip_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.area_ip_occurrences_id_seq OWNED BY public.area_ip_occurrences.id;


--
-- Name: area_occurrence_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.area_occurrence_statuses (
    id bigint NOT NULL
);


--
-- Name: area_occurrence_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.area_occurrence_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: area_occurrence_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.area_occurrence_statuses_id_seq OWNED BY public.area_occurrence_statuses.id;


--
-- Name: area_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.area_occurrences (
    id bigint NOT NULL,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    body character varying DEFAULT ''::character varying NOT NULL,
    status_id bigint DEFAULT 0 NOT NULL,
    memo character varying DEFAULT ''::character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    purge_eligible_at timestamp with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT chk_area_occurrences_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: area_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.area_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: area_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.area_occurrences_id_seq OWNED BY public.area_occurrences.id;


--
-- Name: area_operator_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.area_operator_occurrences (
    id bigint NOT NULL,
    area_occurrence_id bigint NOT NULL,
    staff_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: area_operator_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.area_operator_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: area_operator_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.area_operator_occurrences_id_seq OWNED BY public.area_operator_occurrences.id;


--
-- Name: area_telephone_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.area_telephone_occurrences (
    id bigint NOT NULL,
    area_occurrence_id bigint NOT NULL,
    telephone_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: area_telephone_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.area_telephone_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: area_telephone_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.area_telephone_occurrences_id_seq OWNED BY public.area_telephone_occurrences.id;


--
-- Name: area_visitor_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.area_visitor_occurrences (
    id bigint NOT NULL,
    area_occurrence_id bigint NOT NULL,
    visitor_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: area_visitor_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.area_visitor_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: area_visitor_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.area_visitor_occurrences_id_seq OWNED BY public.area_visitor_occurrences.id;


--
-- Name: area_zip_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.area_zip_occurrences (
    id bigint NOT NULL,
    area_occurrence_id bigint NOT NULL,
    zip_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: area_zip_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.area_zip_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: area_zip_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.area_zip_occurrences_id_seq OWNED BY public.area_zip_occurrences.id;


--
-- Name: client_occurrence_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.client_occurrence_statuses (
    id bigint NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL
);


--
-- Name: client_occurrence_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.client_occurrence_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_occurrence_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_occurrence_statuses_id_seq OWNED BY public.client_occurrence_statuses.id;


--
-- Name: client_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.client_occurrences (
    id bigint NOT NULL,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    body character varying DEFAULT ''::character varying NOT NULL,
    status_id bigint DEFAULT 0 NOT NULL,
    memo character varying DEFAULT ''::character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    event_type character varying DEFAULT ''::character varying NOT NULL,
    context jsonb DEFAULT '{}'::jsonb NOT NULL,
    purge_eligible_at timestamp with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT chk_user_occurrences_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: client_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.client_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_occurrences_id_seq OWNED BY public.client_occurrences.id;


--
-- Name: client_zip_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.client_zip_occurrences (
    id bigint NOT NULL,
    user_occurrence_id bigint NOT NULL,
    zip_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_zip_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.client_zip_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_zip_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_zip_occurrences_id_seq OWNED BY public.client_zip_occurrences.id;


--
-- Name: domain_client_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.domain_client_occurrences (
    id bigint NOT NULL,
    domain_occurrence_id bigint NOT NULL,
    user_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: domain_client_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.domain_client_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: domain_client_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.domain_client_occurrences_id_seq OWNED BY public.domain_client_occurrences.id;


--
-- Name: domain_email_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.domain_email_occurrences (
    id bigint NOT NULL,
    domain_occurrence_id bigint NOT NULL,
    email_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: domain_email_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.domain_email_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: domain_email_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.domain_email_occurrences_id_seq OWNED BY public.domain_email_occurrences.id;


--
-- Name: domain_ip_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.domain_ip_occurrences (
    id bigint NOT NULL,
    domain_occurrence_id bigint NOT NULL,
    ip_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: domain_ip_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.domain_ip_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: domain_ip_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.domain_ip_occurrences_id_seq OWNED BY public.domain_ip_occurrences.id;


--
-- Name: domain_occurrence_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.domain_occurrence_statuses (
    id bigint NOT NULL
);


--
-- Name: domain_occurrence_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.domain_occurrence_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: domain_occurrence_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.domain_occurrence_statuses_id_seq OWNED BY public.domain_occurrence_statuses.id;


--
-- Name: domain_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.domain_occurrences (
    id bigint NOT NULL,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    body character varying DEFAULT ''::character varying NOT NULL,
    status_id bigint DEFAULT 0 NOT NULL,
    memo character varying DEFAULT ''::character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    purge_eligible_at timestamp with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT chk_domain_occurrences_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: domain_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.domain_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: domain_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.domain_occurrences_id_seq OWNED BY public.domain_occurrences.id;


--
-- Name: domain_operator_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.domain_operator_occurrences (
    id bigint NOT NULL,
    domain_occurrence_id bigint NOT NULL,
    staff_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: domain_operator_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.domain_operator_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: domain_operator_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.domain_operator_occurrences_id_seq OWNED BY public.domain_operator_occurrences.id;


--
-- Name: domain_telephone_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.domain_telephone_occurrences (
    id bigint NOT NULL,
    domain_occurrence_id bigint NOT NULL,
    telephone_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: domain_telephone_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.domain_telephone_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: domain_telephone_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.domain_telephone_occurrences_id_seq OWNED BY public.domain_telephone_occurrences.id;


--
-- Name: domain_zip_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.domain_zip_occurrences (
    id bigint NOT NULL,
    domain_occurrence_id bigint NOT NULL,
    zip_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: domain_zip_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.domain_zip_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: domain_zip_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.domain_zip_occurrences_id_seq OWNED BY public.domain_zip_occurrences.id;


--
-- Name: email_client_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.email_client_occurrences (
    id bigint NOT NULL,
    email_occurrence_id bigint NOT NULL,
    user_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: email_client_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.email_client_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_client_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.email_client_occurrences_id_seq OWNED BY public.email_client_occurrences.id;


--
-- Name: email_ip_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.email_ip_occurrences (
    id bigint NOT NULL,
    email_occurrence_id bigint NOT NULL,
    ip_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: email_ip_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.email_ip_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_ip_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.email_ip_occurrences_id_seq OWNED BY public.email_ip_occurrences.id;


--
-- Name: email_occurrence_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.email_occurrence_statuses (
    id bigint NOT NULL
);


--
-- Name: email_occurrence_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.email_occurrence_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_occurrence_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.email_occurrence_statuses_id_seq OWNED BY public.email_occurrence_statuses.id;


--
-- Name: email_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.email_occurrences (
    id bigint NOT NULL,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    body character varying DEFAULT ''::character varying NOT NULL,
    status_id bigint DEFAULT 0 NOT NULL,
    memo character varying DEFAULT ''::character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    purge_eligible_at timestamp with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT chk_email_occurrences_memo_length CHECK ((char_length((memo)::text) <= 1000)),
    CONSTRAINT chk_email_occurrences_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: email_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.email_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.email_occurrences_id_seq OWNED BY public.email_occurrences.id;


--
-- Name: email_operator_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.email_operator_occurrences (
    id bigint NOT NULL,
    email_occurrence_id bigint NOT NULL,
    staff_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: email_operator_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.email_operator_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_operator_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.email_operator_occurrences_id_seq OWNED BY public.email_operator_occurrences.id;


--
-- Name: email_telephone_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.email_telephone_occurrences (
    id bigint NOT NULL,
    email_occurrence_id bigint NOT NULL,
    telephone_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: email_telephone_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.email_telephone_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_telephone_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.email_telephone_occurrences_id_seq OWNED BY public.email_telephone_occurrences.id;


--
-- Name: email_visitor_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.email_visitor_occurrences (
    id bigint NOT NULL,
    email_occurrence_id bigint NOT NULL,
    visitor_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: email_visitor_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.email_visitor_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_visitor_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.email_visitor_occurrences_id_seq OWNED BY public.email_visitor_occurrences.id;


--
-- Name: email_zip_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.email_zip_occurrences (
    id bigint NOT NULL,
    email_occurrence_id bigint NOT NULL,
    zip_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: email_zip_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.email_zip_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_zip_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.email_zip_occurrences_id_seq OWNED BY public.email_zip_occurrences.id;


--
-- Name: ip_client_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.ip_client_occurrences (
    id bigint NOT NULL,
    ip_occurrence_id bigint NOT NULL,
    user_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: ip_client_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.ip_client_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ip_client_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ip_client_occurrences_id_seq OWNED BY public.ip_client_occurrences.id;


--
-- Name: ip_occurrence_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.ip_occurrence_statuses (
    id bigint NOT NULL
);


--
-- Name: ip_occurrence_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.ip_occurrence_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ip_occurrence_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ip_occurrence_statuses_id_seq OWNED BY public.ip_occurrence_statuses.id;


--
-- Name: ip_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.ip_occurrences (
    id bigint NOT NULL,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    body character varying DEFAULT ''::character varying NOT NULL,
    status_id bigint DEFAULT 0 NOT NULL,
    memo character varying DEFAULT ''::character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    purge_eligible_at timestamp with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT chk_ip_occurrences_memo_length CHECK ((char_length((memo)::text) <= 1000)),
    CONSTRAINT chk_ip_occurrences_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: ip_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.ip_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ip_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ip_occurrences_id_seq OWNED BY public.ip_occurrences.id;


--
-- Name: ip_operator_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.ip_operator_occurrences (
    id bigint NOT NULL,
    ip_occurrence_id bigint NOT NULL,
    staff_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: ip_operator_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.ip_operator_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ip_operator_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ip_operator_occurrences_id_seq OWNED BY public.ip_operator_occurrences.id;


--
-- Name: ip_telephone_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.ip_telephone_occurrences (
    id bigint NOT NULL,
    ip_occurrence_id bigint NOT NULL,
    telephone_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: ip_telephone_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.ip_telephone_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ip_telephone_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ip_telephone_occurrences_id_seq OWNED BY public.ip_telephone_occurrences.id;


--
-- Name: ip_visitor_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.ip_visitor_occurrences (
    id bigint NOT NULL,
    ip_occurrence_id bigint NOT NULL,
    visitor_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: ip_visitor_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.ip_visitor_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ip_visitor_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ip_visitor_occurrences_id_seq OWNED BY public.ip_visitor_occurrences.id;


--
-- Name: ip_zip_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.ip_zip_occurrences (
    id bigint NOT NULL,
    ip_occurrence_id bigint NOT NULL,
    zip_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: ip_zip_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.ip_zip_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ip_zip_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ip_zip_occurrences_id_seq OWNED BY public.ip_zip_occurrences.id;


--
-- Name: jwt_anomaly_events; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.jwt_anomaly_events (
    id bigint NOT NULL,
    jwt_occurrence_id bigint NOT NULL,
    code character varying DEFAULT ''::character varying NOT NULL,
    request_host character varying DEFAULT ''::character varying NOT NULL,
    kid character varying DEFAULT ''::character varying NOT NULL,
    alg character varying DEFAULT ''::character varying NOT NULL,
    typ character varying DEFAULT ''::character varying NOT NULL,
    issuer character varying DEFAULT ''::character varying NOT NULL,
    jti character varying DEFAULT ''::character varying NOT NULL,
    error_class character varying DEFAULT ''::character varying NOT NULL,
    error_message character varying DEFAULT ''::character varying NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: jwt_anomaly_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.jwt_anomaly_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: jwt_anomaly_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.jwt_anomaly_events_id_seq OWNED BY public.jwt_anomaly_events.id;


--
-- Name: jwt_occurrence_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.jwt_occurrence_statuses (
    id bigint NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL
);


--
-- Name: jwt_occurrence_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.jwt_occurrence_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: jwt_occurrence_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.jwt_occurrence_statuses_id_seq OWNED BY public.jwt_occurrence_statuses.id;


--
-- Name: jwt_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.jwt_occurrences (
    id bigint NOT NULL,
    body character varying DEFAULT ''::character varying NOT NULL,
    memo character varying DEFAULT ''::character varying NOT NULL,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    status_id bigint DEFAULT 1 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    purge_eligible_at timestamp with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT chk_jwt_occurrences_memo_length CHECK ((char_length((memo)::text) <= 1000)),
    CONSTRAINT chk_jwt_occurrences_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: jwt_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.jwt_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: jwt_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.jwt_occurrences_id_seq OWNED BY public.jwt_occurrences.id;


--
-- Name: operator_client_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_client_occurrences (
    id bigint NOT NULL,
    staff_occurrence_id bigint NOT NULL,
    user_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_client_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_client_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_client_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_client_occurrences_id_seq OWNED BY public.operator_client_occurrences.id;


--
-- Name: operator_occurrence_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_occurrence_statuses (
    id bigint NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL
);


--
-- Name: operator_occurrence_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_occurrence_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_occurrence_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_occurrence_statuses_id_seq OWNED BY public.operator_occurrence_statuses.id;


--
-- Name: operator_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_occurrences (
    id bigint NOT NULL,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    body character varying DEFAULT ''::character varying NOT NULL,
    status_id bigint DEFAULT 0 NOT NULL,
    memo character varying DEFAULT ''::character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    event_type character varying DEFAULT ''::character varying NOT NULL,
    context jsonb DEFAULT '{}'::jsonb NOT NULL,
    purge_eligible_at timestamp with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT chk_staff_occurrences_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: operator_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_occurrences_id_seq OWNED BY public.operator_occurrences.id;


--
-- Name: operator_telephone_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_telephone_occurrences (
    id bigint NOT NULL,
    staff_occurrence_id bigint NOT NULL,
    telephone_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_telephone_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_telephone_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_telephone_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_telephone_occurrences_id_seq OWNED BY public.operator_telephone_occurrences.id;


--
-- Name: operator_zip_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_zip_occurrences (
    id bigint NOT NULL,
    staff_occurrence_id bigint NOT NULL,
    zip_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_zip_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_zip_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_zip_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_zip_occurrences_id_seq OWNED BY public.operator_zip_occurrences.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: telephone_client_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.telephone_client_occurrences (
    id bigint NOT NULL,
    telephone_occurrence_id bigint NOT NULL,
    user_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: telephone_client_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.telephone_client_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: telephone_client_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.telephone_client_occurrences_id_seq OWNED BY public.telephone_client_occurrences.id;


--
-- Name: telephone_occurrence_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.telephone_occurrence_statuses (
    id bigint NOT NULL
);


--
-- Name: telephone_occurrence_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.telephone_occurrence_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: telephone_occurrence_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.telephone_occurrence_statuses_id_seq OWNED BY public.telephone_occurrence_statuses.id;


--
-- Name: telephone_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.telephone_occurrences (
    id bigint NOT NULL,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    body character varying DEFAULT ''::character varying NOT NULL,
    status_id bigint DEFAULT 0 NOT NULL,
    memo character varying DEFAULT ''::character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    purge_eligible_at timestamp with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT chk_telephone_occurrences_memo_length CHECK ((char_length((memo)::text) <= 1000)),
    CONSTRAINT chk_telephone_occurrences_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: telephone_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.telephone_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: telephone_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.telephone_occurrences_id_seq OWNED BY public.telephone_occurrences.id;


--
-- Name: telephone_zip_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.telephone_zip_occurrences (
    id bigint NOT NULL,
    telephone_occurrence_id bigint NOT NULL,
    zip_occurrence_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: telephone_zip_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.telephone_zip_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: telephone_zip_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.telephone_zip_occurrences_id_seq OWNED BY public.telephone_zip_occurrences.id;


--
-- Name: visitor_occurrence_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_occurrence_statuses (
    id bigint NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL
);


--
-- Name: visitor_occurrence_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_occurrence_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_occurrence_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_occurrence_statuses_id_seq OWNED BY public.visitor_occurrence_statuses.id;


--
-- Name: visitor_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_occurrences (
    id bigint NOT NULL,
    body character varying DEFAULT ''::character varying NOT NULL,
    context jsonb DEFAULT '{}'::jsonb NOT NULL,
    event_type character varying DEFAULT ''::character varying NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    memo character varying DEFAULT ''::character varying NOT NULL,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    status_id bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_customer_occurrences_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: visitor_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_occurrences_id_seq OWNED BY public.visitor_occurrences.id;


--
-- Name: zip_occurrence_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.zip_occurrence_statuses (
    id bigint NOT NULL
);


--
-- Name: zip_occurrence_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.zip_occurrence_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zip_occurrence_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zip_occurrence_statuses_id_seq OWNED BY public.zip_occurrence_statuses.id;


--
-- Name: zip_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.zip_occurrences (
    id bigint NOT NULL,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    body character varying DEFAULT ''::character varying NOT NULL,
    status_id bigint DEFAULT 0 NOT NULL,
    memo character varying DEFAULT ''::character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    purge_eligible_at timestamp with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT chk_zip_occurrences_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: zip_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.zip_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zip_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zip_occurrences_id_seq OWNED BY public.zip_occurrences.id;


--
-- Name: area_client_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_client_occurrences ALTER COLUMN id SET DEFAULT nextval('public.area_client_occurrences_id_seq'::regclass);


--
-- Name: area_domain_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_domain_occurrences ALTER COLUMN id SET DEFAULT nextval('public.area_domain_occurrences_id_seq'::regclass);


--
-- Name: area_email_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_email_occurrences ALTER COLUMN id SET DEFAULT nextval('public.area_email_occurrences_id_seq'::regclass);


--
-- Name: area_ip_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_ip_occurrences ALTER COLUMN id SET DEFAULT nextval('public.area_ip_occurrences_id_seq'::regclass);


--
-- Name: area_occurrence_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_occurrence_statuses ALTER COLUMN id SET DEFAULT nextval('public.area_occurrence_statuses_id_seq'::regclass);


--
-- Name: area_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_occurrences ALTER COLUMN id SET DEFAULT nextval('public.area_occurrences_id_seq'::regclass);


--
-- Name: area_operator_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_operator_occurrences ALTER COLUMN id SET DEFAULT nextval('public.area_operator_occurrences_id_seq'::regclass);


--
-- Name: area_telephone_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_telephone_occurrences ALTER COLUMN id SET DEFAULT nextval('public.area_telephone_occurrences_id_seq'::regclass);


--
-- Name: area_visitor_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_visitor_occurrences ALTER COLUMN id SET DEFAULT nextval('public.area_visitor_occurrences_id_seq'::regclass);


--
-- Name: area_zip_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_zip_occurrences ALTER COLUMN id SET DEFAULT nextval('public.area_zip_occurrences_id_seq'::regclass);


--
-- Name: client_occurrence_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_occurrence_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_occurrence_statuses_id_seq'::regclass);


--
-- Name: client_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_occurrences ALTER COLUMN id SET DEFAULT nextval('public.client_occurrences_id_seq'::regclass);


--
-- Name: client_zip_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_zip_occurrences ALTER COLUMN id SET DEFAULT nextval('public.client_zip_occurrences_id_seq'::regclass);


--
-- Name: domain_client_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_client_occurrences ALTER COLUMN id SET DEFAULT nextval('public.domain_client_occurrences_id_seq'::regclass);


--
-- Name: domain_email_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_email_occurrences ALTER COLUMN id SET DEFAULT nextval('public.domain_email_occurrences_id_seq'::regclass);


--
-- Name: domain_ip_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_ip_occurrences ALTER COLUMN id SET DEFAULT nextval('public.domain_ip_occurrences_id_seq'::regclass);


--
-- Name: domain_occurrence_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_occurrence_statuses ALTER COLUMN id SET DEFAULT nextval('public.domain_occurrence_statuses_id_seq'::regclass);


--
-- Name: domain_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_occurrences ALTER COLUMN id SET DEFAULT nextval('public.domain_occurrences_id_seq'::regclass);


--
-- Name: domain_operator_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_operator_occurrences ALTER COLUMN id SET DEFAULT nextval('public.domain_operator_occurrences_id_seq'::regclass);


--
-- Name: domain_telephone_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_telephone_occurrences ALTER COLUMN id SET DEFAULT nextval('public.domain_telephone_occurrences_id_seq'::regclass);


--
-- Name: domain_zip_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_zip_occurrences ALTER COLUMN id SET DEFAULT nextval('public.domain_zip_occurrences_id_seq'::regclass);


--
-- Name: email_client_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_client_occurrences ALTER COLUMN id SET DEFAULT nextval('public.email_client_occurrences_id_seq'::regclass);


--
-- Name: email_ip_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_ip_occurrences ALTER COLUMN id SET DEFAULT nextval('public.email_ip_occurrences_id_seq'::regclass);


--
-- Name: email_occurrence_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_occurrence_statuses ALTER COLUMN id SET DEFAULT nextval('public.email_occurrence_statuses_id_seq'::regclass);


--
-- Name: email_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_occurrences ALTER COLUMN id SET DEFAULT nextval('public.email_occurrences_id_seq'::regclass);


--
-- Name: email_operator_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_operator_occurrences ALTER COLUMN id SET DEFAULT nextval('public.email_operator_occurrences_id_seq'::regclass);


--
-- Name: email_telephone_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_telephone_occurrences ALTER COLUMN id SET DEFAULT nextval('public.email_telephone_occurrences_id_seq'::regclass);


--
-- Name: email_visitor_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_visitor_occurrences ALTER COLUMN id SET DEFAULT nextval('public.email_visitor_occurrences_id_seq'::regclass);


--
-- Name: email_zip_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_zip_occurrences ALTER COLUMN id SET DEFAULT nextval('public.email_zip_occurrences_id_seq'::regclass);


--
-- Name: ip_client_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_client_occurrences ALTER COLUMN id SET DEFAULT nextval('public.ip_client_occurrences_id_seq'::regclass);


--
-- Name: ip_occurrence_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_occurrence_statuses ALTER COLUMN id SET DEFAULT nextval('public.ip_occurrence_statuses_id_seq'::regclass);


--
-- Name: ip_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_occurrences ALTER COLUMN id SET DEFAULT nextval('public.ip_occurrences_id_seq'::regclass);


--
-- Name: ip_operator_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_operator_occurrences ALTER COLUMN id SET DEFAULT nextval('public.ip_operator_occurrences_id_seq'::regclass);


--
-- Name: ip_telephone_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_telephone_occurrences ALTER COLUMN id SET DEFAULT nextval('public.ip_telephone_occurrences_id_seq'::regclass);


--
-- Name: ip_visitor_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_visitor_occurrences ALTER COLUMN id SET DEFAULT nextval('public.ip_visitor_occurrences_id_seq'::regclass);


--
-- Name: ip_zip_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_zip_occurrences ALTER COLUMN id SET DEFAULT nextval('public.ip_zip_occurrences_id_seq'::regclass);


--
-- Name: jwt_anomaly_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jwt_anomaly_events ALTER COLUMN id SET DEFAULT nextval('public.jwt_anomaly_events_id_seq'::regclass);


--
-- Name: jwt_occurrence_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jwt_occurrence_statuses ALTER COLUMN id SET DEFAULT nextval('public.jwt_occurrence_statuses_id_seq'::regclass);


--
-- Name: jwt_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jwt_occurrences ALTER COLUMN id SET DEFAULT nextval('public.jwt_occurrences_id_seq'::regclass);


--
-- Name: operator_client_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_client_occurrences ALTER COLUMN id SET DEFAULT nextval('public.operator_client_occurrences_id_seq'::regclass);


--
-- Name: operator_occurrence_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_occurrence_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_occurrence_statuses_id_seq'::regclass);


--
-- Name: operator_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_occurrences ALTER COLUMN id SET DEFAULT nextval('public.operator_occurrences_id_seq'::regclass);


--
-- Name: operator_telephone_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_telephone_occurrences ALTER COLUMN id SET DEFAULT nextval('public.operator_telephone_occurrences_id_seq'::regclass);


--
-- Name: operator_zip_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_zip_occurrences ALTER COLUMN id SET DEFAULT nextval('public.operator_zip_occurrences_id_seq'::regclass);


--
-- Name: telephone_client_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.telephone_client_occurrences ALTER COLUMN id SET DEFAULT nextval('public.telephone_client_occurrences_id_seq'::regclass);


--
-- Name: telephone_occurrence_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.telephone_occurrence_statuses ALTER COLUMN id SET DEFAULT nextval('public.telephone_occurrence_statuses_id_seq'::regclass);


--
-- Name: telephone_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.telephone_occurrences ALTER COLUMN id SET DEFAULT nextval('public.telephone_occurrences_id_seq'::regclass);


--
-- Name: telephone_zip_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.telephone_zip_occurrences ALTER COLUMN id SET DEFAULT nextval('public.telephone_zip_occurrences_id_seq'::regclass);


--
-- Name: visitor_occurrence_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_occurrence_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_occurrence_statuses_id_seq'::regclass);


--
-- Name: visitor_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_occurrences ALTER COLUMN id SET DEFAULT nextval('public.visitor_occurrences_id_seq'::regclass);


--
-- Name: zip_occurrence_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zip_occurrence_statuses ALTER COLUMN id SET DEFAULT nextval('public.zip_occurrence_statuses_id_seq'::regclass);


--
-- Name: zip_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zip_occurrences ALTER COLUMN id SET DEFAULT nextval('public.zip_occurrences_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: area_client_occurrences area_client_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_client_occurrences
    ADD CONSTRAINT area_client_occurrences_pkey PRIMARY KEY (id);


--
-- Name: area_domain_occurrences area_domain_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_domain_occurrences
    ADD CONSTRAINT area_domain_occurrences_pkey PRIMARY KEY (id);


--
-- Name: area_email_occurrences area_email_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_email_occurrences
    ADD CONSTRAINT area_email_occurrences_pkey PRIMARY KEY (id);


--
-- Name: area_ip_occurrences area_ip_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_ip_occurrences
    ADD CONSTRAINT area_ip_occurrences_pkey PRIMARY KEY (id);


--
-- Name: area_occurrence_statuses area_occurrence_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_occurrence_statuses
    ADD CONSTRAINT area_occurrence_statuses_pkey PRIMARY KEY (id);


--
-- Name: area_occurrences area_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_occurrences
    ADD CONSTRAINT area_occurrences_pkey PRIMARY KEY (id);


--
-- Name: area_operator_occurrences area_operator_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_operator_occurrences
    ADD CONSTRAINT area_operator_occurrences_pkey PRIMARY KEY (id);


--
-- Name: area_telephone_occurrences area_telephone_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_telephone_occurrences
    ADD CONSTRAINT area_telephone_occurrences_pkey PRIMARY KEY (id);


--
-- Name: area_visitor_occurrences area_visitor_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_visitor_occurrences
    ADD CONSTRAINT area_visitor_occurrences_pkey PRIMARY KEY (id);


--
-- Name: area_zip_occurrences area_zip_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_zip_occurrences
    ADD CONSTRAINT area_zip_occurrences_pkey PRIMARY KEY (id);


--
-- Name: client_occurrence_statuses client_occurrence_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_occurrence_statuses
    ADD CONSTRAINT client_occurrence_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_occurrences client_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_occurrences
    ADD CONSTRAINT client_occurrences_pkey PRIMARY KEY (id);


--
-- Name: client_zip_occurrences client_zip_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_zip_occurrences
    ADD CONSTRAINT client_zip_occurrences_pkey PRIMARY KEY (id);


--
-- Name: domain_client_occurrences domain_client_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_client_occurrences
    ADD CONSTRAINT domain_client_occurrences_pkey PRIMARY KEY (id);


--
-- Name: domain_email_occurrences domain_email_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_email_occurrences
    ADD CONSTRAINT domain_email_occurrences_pkey PRIMARY KEY (id);


--
-- Name: domain_ip_occurrences domain_ip_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_ip_occurrences
    ADD CONSTRAINT domain_ip_occurrences_pkey PRIMARY KEY (id);


--
-- Name: domain_occurrence_statuses domain_occurrence_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_occurrence_statuses
    ADD CONSTRAINT domain_occurrence_statuses_pkey PRIMARY KEY (id);


--
-- Name: domain_occurrences domain_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_occurrences
    ADD CONSTRAINT domain_occurrences_pkey PRIMARY KEY (id);


--
-- Name: domain_operator_occurrences domain_operator_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_operator_occurrences
    ADD CONSTRAINT domain_operator_occurrences_pkey PRIMARY KEY (id);


--
-- Name: domain_telephone_occurrences domain_telephone_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_telephone_occurrences
    ADD CONSTRAINT domain_telephone_occurrences_pkey PRIMARY KEY (id);


--
-- Name: domain_zip_occurrences domain_zip_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_zip_occurrences
    ADD CONSTRAINT domain_zip_occurrences_pkey PRIMARY KEY (id);


--
-- Name: email_client_occurrences email_client_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_client_occurrences
    ADD CONSTRAINT email_client_occurrences_pkey PRIMARY KEY (id);


--
-- Name: email_ip_occurrences email_ip_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_ip_occurrences
    ADD CONSTRAINT email_ip_occurrences_pkey PRIMARY KEY (id);


--
-- Name: email_occurrence_statuses email_occurrence_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_occurrence_statuses
    ADD CONSTRAINT email_occurrence_statuses_pkey PRIMARY KEY (id);


--
-- Name: email_occurrences email_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_occurrences
    ADD CONSTRAINT email_occurrences_pkey PRIMARY KEY (id);


--
-- Name: email_operator_occurrences email_operator_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_operator_occurrences
    ADD CONSTRAINT email_operator_occurrences_pkey PRIMARY KEY (id);


--
-- Name: email_telephone_occurrences email_telephone_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_telephone_occurrences
    ADD CONSTRAINT email_telephone_occurrences_pkey PRIMARY KEY (id);


--
-- Name: email_visitor_occurrences email_visitor_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_visitor_occurrences
    ADD CONSTRAINT email_visitor_occurrences_pkey PRIMARY KEY (id);


--
-- Name: email_zip_occurrences email_zip_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_zip_occurrences
    ADD CONSTRAINT email_zip_occurrences_pkey PRIMARY KEY (id);


--
-- Name: ip_client_occurrences ip_client_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_client_occurrences
    ADD CONSTRAINT ip_client_occurrences_pkey PRIMARY KEY (id);


--
-- Name: ip_occurrence_statuses ip_occurrence_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_occurrence_statuses
    ADD CONSTRAINT ip_occurrence_statuses_pkey PRIMARY KEY (id);


--
-- Name: ip_occurrences ip_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_occurrences
    ADD CONSTRAINT ip_occurrences_pkey PRIMARY KEY (id);


--
-- Name: ip_operator_occurrences ip_operator_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_operator_occurrences
    ADD CONSTRAINT ip_operator_occurrences_pkey PRIMARY KEY (id);


--
-- Name: ip_telephone_occurrences ip_telephone_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_telephone_occurrences
    ADD CONSTRAINT ip_telephone_occurrences_pkey PRIMARY KEY (id);


--
-- Name: ip_visitor_occurrences ip_visitor_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_visitor_occurrences
    ADD CONSTRAINT ip_visitor_occurrences_pkey PRIMARY KEY (id);


--
-- Name: ip_zip_occurrences ip_zip_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_zip_occurrences
    ADD CONSTRAINT ip_zip_occurrences_pkey PRIMARY KEY (id);


--
-- Name: jwt_anomaly_events jwt_anomaly_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jwt_anomaly_events
    ADD CONSTRAINT jwt_anomaly_events_pkey PRIMARY KEY (id);


--
-- Name: jwt_occurrence_statuses jwt_occurrence_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jwt_occurrence_statuses
    ADD CONSTRAINT jwt_occurrence_statuses_pkey PRIMARY KEY (id);


--
-- Name: jwt_occurrences jwt_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jwt_occurrences
    ADD CONSTRAINT jwt_occurrences_pkey PRIMARY KEY (id);


--
-- Name: operator_client_occurrences operator_client_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_client_occurrences
    ADD CONSTRAINT operator_client_occurrences_pkey PRIMARY KEY (id);


--
-- Name: operator_occurrence_statuses operator_occurrence_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_occurrence_statuses
    ADD CONSTRAINT operator_occurrence_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_occurrences operator_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_occurrences
    ADD CONSTRAINT operator_occurrences_pkey PRIMARY KEY (id);


--
-- Name: operator_telephone_occurrences operator_telephone_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_telephone_occurrences
    ADD CONSTRAINT operator_telephone_occurrences_pkey PRIMARY KEY (id);


--
-- Name: operator_zip_occurrences operator_zip_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_zip_occurrences
    ADD CONSTRAINT operator_zip_occurrences_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: telephone_client_occurrences telephone_client_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.telephone_client_occurrences
    ADD CONSTRAINT telephone_client_occurrences_pkey PRIMARY KEY (id);


--
-- Name: telephone_occurrence_statuses telephone_occurrence_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.telephone_occurrence_statuses
    ADD CONSTRAINT telephone_occurrence_statuses_pkey PRIMARY KEY (id);


--
-- Name: telephone_occurrences telephone_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.telephone_occurrences
    ADD CONSTRAINT telephone_occurrences_pkey PRIMARY KEY (id);


--
-- Name: telephone_zip_occurrences telephone_zip_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.telephone_zip_occurrences
    ADD CONSTRAINT telephone_zip_occurrences_pkey PRIMARY KEY (id);


--
-- Name: visitor_occurrence_statuses visitor_occurrence_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_occurrence_statuses
    ADD CONSTRAINT visitor_occurrence_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_occurrences visitor_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_occurrences
    ADD CONSTRAINT visitor_occurrences_pkey PRIMARY KEY (id);


--
-- Name: zip_occurrence_statuses zip_occurrence_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zip_occurrence_statuses
    ADD CONSTRAINT zip_occurrence_statuses_pkey PRIMARY KEY (id);


--
-- Name: zip_occurrences zip_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zip_occurrences
    ADD CONSTRAINT zip_occurrences_pkey PRIMARY KEY (id);


--
-- Name: idx_area_domain_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_area_domain_occ_on_ids ON public.area_domain_occurrences USING btree (area_occurrence_id, domain_occurrence_id);


--
-- Name: idx_area_email_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_area_email_occ_on_ids ON public.area_email_occurrences USING btree (area_occurrence_id, email_occurrence_id);


--
-- Name: idx_area_ip_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_area_ip_occ_on_ids ON public.area_ip_occurrences USING btree (area_occurrence_id, ip_occurrence_id);


--
-- Name: idx_area_staff_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_area_staff_occ_on_ids ON public.area_operator_occurrences USING btree (area_occurrence_id, staff_occurrence_id);


--
-- Name: idx_area_telephone_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_area_telephone_occ_on_ids ON public.area_telephone_occurrences USING btree (area_occurrence_id, telephone_occurrence_id);


--
-- Name: idx_area_user_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_area_user_occ_on_ids ON public.area_client_occurrences USING btree (area_occurrence_id, user_occurrence_id);


--
-- Name: idx_area_visitor_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_area_visitor_occ_on_ids ON public.area_visitor_occurrences USING btree (area_occurrence_id, visitor_occurrence_id);


--
-- Name: idx_area_zip_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_area_zip_occ_on_ids ON public.area_zip_occurrences USING btree (area_occurrence_id, zip_occurrence_id);


--
-- Name: idx_domain_email_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_domain_email_occ_on_ids ON public.domain_email_occurrences USING btree (domain_occurrence_id, email_occurrence_id);


--
-- Name: idx_domain_ip_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_domain_ip_occ_on_ids ON public.domain_ip_occurrences USING btree (domain_occurrence_id, ip_occurrence_id);


--
-- Name: idx_domain_staff_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_domain_staff_occ_on_ids ON public.domain_operator_occurrences USING btree (domain_occurrence_id, staff_occurrence_id);


--
-- Name: idx_domain_telephone_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_domain_telephone_occ_on_ids ON public.domain_telephone_occurrences USING btree (domain_occurrence_id, telephone_occurrence_id);


--
-- Name: idx_domain_user_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_domain_user_occ_on_ids ON public.domain_client_occurrences USING btree (domain_occurrence_id, user_occurrence_id);


--
-- Name: idx_domain_zip_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_domain_zip_occ_on_ids ON public.domain_zip_occurrences USING btree (domain_occurrence_id, zip_occurrence_id);


--
-- Name: idx_email_ip_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_email_ip_occ_on_ids ON public.email_ip_occurrences USING btree (email_occurrence_id, ip_occurrence_id);


--
-- Name: idx_email_staff_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_email_staff_occ_on_ids ON public.email_operator_occurrences USING btree (email_occurrence_id, staff_occurrence_id);


--
-- Name: idx_email_telephone_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_email_telephone_occ_on_ids ON public.email_telephone_occurrences USING btree (email_occurrence_id, telephone_occurrence_id);


--
-- Name: idx_email_user_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_email_user_occ_on_ids ON public.email_client_occurrences USING btree (email_occurrence_id, user_occurrence_id);


--
-- Name: idx_email_visitor_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_email_visitor_occ_on_ids ON public.email_visitor_occurrences USING btree (email_occurrence_id, visitor_occurrence_id);


--
-- Name: idx_email_zip_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_email_zip_occ_on_ids ON public.email_zip_occurrences USING btree (email_occurrence_id, zip_occurrence_id);


--
-- Name: idx_ip_staff_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_ip_staff_occ_on_ids ON public.ip_operator_occurrences USING btree (ip_occurrence_id, staff_occurrence_id);


--
-- Name: idx_ip_telephone_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_ip_telephone_occ_on_ids ON public.ip_telephone_occurrences USING btree (ip_occurrence_id, telephone_occurrence_id);


--
-- Name: idx_ip_user_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_ip_user_occ_on_ids ON public.ip_client_occurrences USING btree (ip_occurrence_id, user_occurrence_id);


--
-- Name: idx_ip_visitor_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_ip_visitor_occ_on_ids ON public.ip_visitor_occurrences USING btree (ip_occurrence_id, visitor_occurrence_id);


--
-- Name: idx_ip_zip_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_ip_zip_occ_on_ids ON public.ip_zip_occurrences USING btree (ip_occurrence_id, zip_occurrence_id);


--
-- Name: idx_on_telephone_occurrence_id_de4dc4cae4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_telephone_occurrence_id_de4dc4cae4 ON public.operator_telephone_occurrences USING btree (telephone_occurrence_id);


--
-- Name: idx_staff_telephone_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_staff_telephone_occ_on_ids ON public.operator_telephone_occurrences USING btree (staff_occurrence_id, telephone_occurrence_id);


--
-- Name: idx_staff_user_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_staff_user_occ_on_ids ON public.operator_client_occurrences USING btree (staff_occurrence_id, user_occurrence_id);


--
-- Name: idx_staff_zip_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_staff_zip_occ_on_ids ON public.operator_zip_occurrences USING btree (staff_occurrence_id, zip_occurrence_id);


--
-- Name: idx_telephone_user_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_telephone_user_occ_on_ids ON public.telephone_client_occurrences USING btree (telephone_occurrence_id, user_occurrence_id);


--
-- Name: idx_telephone_zip_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_telephone_zip_occ_on_ids ON public.telephone_zip_occurrences USING btree (telephone_occurrence_id, zip_occurrence_id);


--
-- Name: idx_user_zip_occ_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_user_zip_occ_on_ids ON public.client_zip_occurrences USING btree (user_occurrence_id, zip_occurrence_id);


--
-- Name: index_area_client_occurrences_on_user_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_area_client_occurrences_on_user_occurrence_id ON public.area_client_occurrences USING btree (user_occurrence_id);


--
-- Name: index_area_domain_occurrences_on_domain_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_area_domain_occurrences_on_domain_occurrence_id ON public.area_domain_occurrences USING btree (domain_occurrence_id);


--
-- Name: index_area_email_occurrences_on_email_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_area_email_occurrences_on_email_occurrence_id ON public.area_email_occurrences USING btree (email_occurrence_id);


--
-- Name: index_area_ip_occurrences_on_ip_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_area_ip_occurrences_on_ip_occurrence_id ON public.area_ip_occurrences USING btree (ip_occurrence_id);


--
-- Name: index_area_occurrences_on_body; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_area_occurrences_on_body ON public.area_occurrences USING btree (body);


--
-- Name: index_area_occurrences_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_area_occurrences_on_public_id ON public.area_occurrences USING btree (public_id);


--
-- Name: index_area_occurrences_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_area_occurrences_on_purge_eligible_at ON public.area_occurrences USING btree (purge_eligible_at);


--
-- Name: index_area_occurrences_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_area_occurrences_on_status_id ON public.area_occurrences USING btree (status_id);


--
-- Name: index_area_operator_occurrences_on_staff_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_area_operator_occurrences_on_staff_occurrence_id ON public.area_operator_occurrences USING btree (staff_occurrence_id);


--
-- Name: index_area_telephone_occurrences_on_telephone_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_area_telephone_occurrences_on_telephone_occurrence_id ON public.area_telephone_occurrences USING btree (telephone_occurrence_id);


--
-- Name: index_area_visitor_occurrences_on_visitor_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_area_visitor_occurrences_on_visitor_occurrence_id ON public.area_visitor_occurrences USING btree (visitor_occurrence_id);


--
-- Name: index_area_zip_occurrences_on_zip_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_area_zip_occurrences_on_zip_occurrence_id ON public.area_zip_occurrences USING btree (zip_occurrence_id);


--
-- Name: index_client_occurrences_on_body; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_occurrences_on_body ON public.client_occurrences USING btree (body);


--
-- Name: index_client_occurrences_on_event_type_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_occurrences_on_event_type_and_created_at ON public.client_occurrences USING btree (event_type, created_at);


--
-- Name: index_client_occurrences_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_occurrences_on_public_id ON public.client_occurrences USING btree (public_id);


--
-- Name: index_client_occurrences_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_occurrences_on_purge_eligible_at ON public.client_occurrences USING btree (purge_eligible_at);


--
-- Name: index_client_occurrences_on_status_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_occurrences_on_status_id_and_created_at ON public.client_occurrences USING btree (status_id, created_at);


--
-- Name: index_client_zip_occurrences_on_zip_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_zip_occurrences_on_zip_occurrence_id ON public.client_zip_occurrences USING btree (zip_occurrence_id);


--
-- Name: index_domain_client_occurrences_on_user_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_domain_client_occurrences_on_user_occurrence_id ON public.domain_client_occurrences USING btree (user_occurrence_id);


--
-- Name: index_domain_email_occurrences_on_email_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_domain_email_occurrences_on_email_occurrence_id ON public.domain_email_occurrences USING btree (email_occurrence_id);


--
-- Name: index_domain_ip_occurrences_on_ip_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_domain_ip_occurrences_on_ip_occurrence_id ON public.domain_ip_occurrences USING btree (ip_occurrence_id);


--
-- Name: index_domain_occurrences_on_body; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_domain_occurrences_on_body ON public.domain_occurrences USING btree (body);


--
-- Name: index_domain_occurrences_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_domain_occurrences_on_public_id ON public.domain_occurrences USING btree (public_id);


--
-- Name: index_domain_occurrences_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_domain_occurrences_on_purge_eligible_at ON public.domain_occurrences USING btree (purge_eligible_at);


--
-- Name: index_domain_occurrences_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_domain_occurrences_on_status_id ON public.domain_occurrences USING btree (status_id);


--
-- Name: index_domain_operator_occurrences_on_staff_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_domain_operator_occurrences_on_staff_occurrence_id ON public.domain_operator_occurrences USING btree (staff_occurrence_id);


--
-- Name: index_domain_telephone_occurrences_on_telephone_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_domain_telephone_occurrences_on_telephone_occurrence_id ON public.domain_telephone_occurrences USING btree (telephone_occurrence_id);


--
-- Name: index_domain_zip_occurrences_on_zip_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_domain_zip_occurrences_on_zip_occurrence_id ON public.domain_zip_occurrences USING btree (zip_occurrence_id);


--
-- Name: index_email_client_occurrences_on_user_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_client_occurrences_on_user_occurrence_id ON public.email_client_occurrences USING btree (user_occurrence_id);


--
-- Name: index_email_ip_occurrences_on_ip_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_ip_occurrences_on_ip_occurrence_id ON public.email_ip_occurrences USING btree (ip_occurrence_id);


--
-- Name: index_email_occurrences_on_body; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_email_occurrences_on_body ON public.email_occurrences USING btree (body);


--
-- Name: index_email_occurrences_on_body_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_occurrences_on_body_created_at ON public.email_occurrences USING btree (body, created_at);


--
-- Name: index_email_occurrences_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_email_occurrences_on_public_id ON public.email_occurrences USING btree (public_id);


--
-- Name: index_email_occurrences_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_occurrences_on_purge_eligible_at ON public.email_occurrences USING btree (purge_eligible_at);


--
-- Name: index_email_occurrences_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_occurrences_on_status_id ON public.email_occurrences USING btree (status_id);


--
-- Name: index_email_operator_occurrences_on_staff_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_operator_occurrences_on_staff_occurrence_id ON public.email_operator_occurrences USING btree (staff_occurrence_id);


--
-- Name: index_email_telephone_occurrences_on_telephone_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_telephone_occurrences_on_telephone_occurrence_id ON public.email_telephone_occurrences USING btree (telephone_occurrence_id);


--
-- Name: index_email_visitor_occurrences_on_visitor_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_visitor_occurrences_on_visitor_occurrence_id ON public.email_visitor_occurrences USING btree (visitor_occurrence_id);


--
-- Name: index_email_zip_occurrences_on_zip_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_zip_occurrences_on_zip_occurrence_id ON public.email_zip_occurrences USING btree (zip_occurrence_id);


--
-- Name: index_ip_client_occurrences_on_user_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ip_client_occurrences_on_user_occurrence_id ON public.ip_client_occurrences USING btree (user_occurrence_id);


--
-- Name: index_ip_occurrences_on_body; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ip_occurrences_on_body ON public.ip_occurrences USING btree (body);


--
-- Name: index_ip_occurrences_on_body_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ip_occurrences_on_body_created_at ON public.ip_occurrences USING btree (body, created_at);


--
-- Name: index_ip_occurrences_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ip_occurrences_on_public_id ON public.ip_occurrences USING btree (public_id);


--
-- Name: index_ip_occurrences_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ip_occurrences_on_purge_eligible_at ON public.ip_occurrences USING btree (purge_eligible_at);


--
-- Name: index_ip_occurrences_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ip_occurrences_on_status_id ON public.ip_occurrences USING btree (status_id);


--
-- Name: index_ip_operator_occurrences_on_staff_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ip_operator_occurrences_on_staff_occurrence_id ON public.ip_operator_occurrences USING btree (staff_occurrence_id);


--
-- Name: index_ip_telephone_occurrences_on_telephone_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ip_telephone_occurrences_on_telephone_occurrence_id ON public.ip_telephone_occurrences USING btree (telephone_occurrence_id);


--
-- Name: index_ip_visitor_occurrences_on_visitor_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ip_visitor_occurrences_on_visitor_occurrence_id ON public.ip_visitor_occurrences USING btree (visitor_occurrence_id);


--
-- Name: index_ip_zip_occurrences_on_zip_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ip_zip_occurrences_on_zip_occurrence_id ON public.ip_zip_occurrences USING btree (zip_occurrence_id);


--
-- Name: index_jwt_anomaly_events_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_jwt_anomaly_events_on_code ON public.jwt_anomaly_events USING btree (code);


--
-- Name: index_jwt_anomaly_events_on_jwt_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_jwt_anomaly_events_on_jwt_occurrence_id ON public.jwt_anomaly_events USING btree (jwt_occurrence_id);


--
-- Name: index_jwt_anomaly_events_on_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_jwt_anomaly_events_on_occurred_at ON public.jwt_anomaly_events USING btree (occurred_at);


--
-- Name: index_jwt_occurrences_on_body; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_jwt_occurrences_on_body ON public.jwt_occurrences USING btree (body);


--
-- Name: index_jwt_occurrences_on_body_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_jwt_occurrences_on_body_and_created_at ON public.jwt_occurrences USING btree (body, created_at);


--
-- Name: index_jwt_occurrences_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_jwt_occurrences_on_public_id ON public.jwt_occurrences USING btree (public_id);


--
-- Name: index_jwt_occurrences_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_jwt_occurrences_on_purge_eligible_at ON public.jwt_occurrences USING btree (purge_eligible_at);


--
-- Name: index_jwt_occurrences_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_jwt_occurrences_on_status_id ON public.jwt_occurrences USING btree (status_id);


--
-- Name: index_operator_client_occurrences_on_user_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_client_occurrences_on_user_occurrence_id ON public.operator_client_occurrences USING btree (user_occurrence_id);


--
-- Name: index_operator_occurrences_on_body; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_occurrences_on_body ON public.operator_occurrences USING btree (body);


--
-- Name: index_operator_occurrences_on_event_type_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_occurrences_on_event_type_and_created_at ON public.operator_occurrences USING btree (event_type, created_at);


--
-- Name: index_operator_occurrences_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_occurrences_on_public_id ON public.operator_occurrences USING btree (public_id);


--
-- Name: index_operator_occurrences_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_occurrences_on_purge_eligible_at ON public.operator_occurrences USING btree (purge_eligible_at);


--
-- Name: index_operator_occurrences_on_status_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_occurrences_on_status_id_and_created_at ON public.operator_occurrences USING btree (status_id, created_at);


--
-- Name: index_operator_zip_occurrences_on_zip_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_zip_occurrences_on_zip_occurrence_id ON public.operator_zip_occurrences USING btree (zip_occurrence_id);


--
-- Name: index_telephone_client_occurrences_on_user_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_telephone_client_occurrences_on_user_occurrence_id ON public.telephone_client_occurrences USING btree (user_occurrence_id);


--
-- Name: index_telephone_occurrences_on_body; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_telephone_occurrences_on_body ON public.telephone_occurrences USING btree (body);


--
-- Name: index_telephone_occurrences_on_body_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_telephone_occurrences_on_body_created_at ON public.telephone_occurrences USING btree (body, created_at);


--
-- Name: index_telephone_occurrences_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_telephone_occurrences_on_public_id ON public.telephone_occurrences USING btree (public_id);


--
-- Name: index_telephone_occurrences_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_telephone_occurrences_on_purge_eligible_at ON public.telephone_occurrences USING btree (purge_eligible_at);


--
-- Name: index_telephone_occurrences_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_telephone_occurrences_on_status_id ON public.telephone_occurrences USING btree (status_id);


--
-- Name: index_telephone_zip_occurrences_on_zip_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_telephone_zip_occurrences_on_zip_occurrence_id ON public.telephone_zip_occurrences USING btree (zip_occurrence_id);


--
-- Name: index_visitor_occurrences_on_body; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_occurrences_on_body ON public.visitor_occurrences USING btree (body);


--
-- Name: index_visitor_occurrences_on_event_type_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_occurrences_on_event_type_and_created_at ON public.visitor_occurrences USING btree (event_type, created_at);


--
-- Name: index_visitor_occurrences_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_occurrences_on_public_id ON public.visitor_occurrences USING btree (public_id);


--
-- Name: index_visitor_occurrences_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_occurrences_on_purge_eligible_at ON public.visitor_occurrences USING btree (purge_eligible_at);


--
-- Name: index_visitor_occurrences_on_status_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_occurrences_on_status_id_and_created_at ON public.visitor_occurrences USING btree (status_id, created_at);


--
-- Name: index_zip_occurrences_on_body; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_zip_occurrences_on_body ON public.zip_occurrences USING btree (body);


--
-- Name: index_zip_occurrences_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_zip_occurrences_on_public_id ON public.zip_occurrences USING btree (public_id);


--
-- Name: index_zip_occurrences_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_zip_occurrences_on_purge_eligible_at ON public.zip_occurrences USING btree (purge_eligible_at);


--
-- Name: index_zip_occurrences_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_zip_occurrences_on_status_id ON public.zip_occurrences USING btree (status_id);


--
-- Name: area_occurrences fk_area_occurrences_on_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_occurrences
    ADD CONSTRAINT fk_area_occurrences_on_status_id FOREIGN KEY (status_id) REFERENCES public.area_occurrence_statuses(id);


--
-- Name: domain_occurrences fk_domain_occurrences_on_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_occurrences
    ADD CONSTRAINT fk_domain_occurrences_on_status_id FOREIGN KEY (status_id) REFERENCES public.domain_occurrence_statuses(id);


--
-- Name: email_occurrences fk_email_occurrences_on_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_occurrences
    ADD CONSTRAINT fk_email_occurrences_on_status_id FOREIGN KEY (status_id) REFERENCES public.email_occurrence_statuses(id);


--
-- Name: ip_occurrences fk_ip_occurrences_on_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_occurrences
    ADD CONSTRAINT fk_ip_occurrences_on_status_id FOREIGN KEY (status_id) REFERENCES public.ip_occurrence_statuses(id);


--
-- Name: jwt_anomaly_events fk_jwt_anomaly_events_on_jwt_occurrence_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jwt_anomaly_events
    ADD CONSTRAINT fk_jwt_anomaly_events_on_jwt_occurrence_id FOREIGN KEY (jwt_occurrence_id) REFERENCES public.jwt_occurrences(id);


--
-- Name: jwt_occurrences fk_jwt_occurrences_on_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jwt_occurrences
    ADD CONSTRAINT fk_jwt_occurrences_on_status_id FOREIGN KEY (status_id) REFERENCES public.jwt_occurrence_statuses(id);


--
-- Name: ip_visitor_occurrences fk_rails_008a174aa0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_visitor_occurrences
    ADD CONSTRAINT fk_rails_008a174aa0 FOREIGN KEY (visitor_occurrence_id) REFERENCES public.visitor_occurrences(id) NOT VALID;


--
-- Name: ip_telephone_occurrences fk_rails_0091298830; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_telephone_occurrences
    ADD CONSTRAINT fk_rails_0091298830 FOREIGN KEY (ip_occurrence_id) REFERENCES public.ip_occurrences(id) NOT VALID;


--
-- Name: ip_client_occurrences fk_rails_00e504b9ab; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_client_occurrences
    ADD CONSTRAINT fk_rails_00e504b9ab FOREIGN KEY (user_occurrence_id) REFERENCES public.client_occurrences(id) NOT VALID;


--
-- Name: area_ip_occurrences fk_rails_02206200a2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_ip_occurrences
    ADD CONSTRAINT fk_rails_02206200a2 FOREIGN KEY (ip_occurrence_id) REFERENCES public.ip_occurrences(id) NOT VALID;


--
-- Name: operator_client_occurrences fk_rails_13800338d1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_client_occurrences
    ADD CONSTRAINT fk_rails_13800338d1 FOREIGN KEY (user_occurrence_id) REFERENCES public.client_occurrences(id) NOT VALID;


--
-- Name: area_zip_occurrences fk_rails_18554dc64e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_zip_occurrences
    ADD CONSTRAINT fk_rails_18554dc64e FOREIGN KEY (area_occurrence_id) REFERENCES public.area_occurrences(id) NOT VALID;


--
-- Name: domain_email_occurrences fk_rails_190d1d7227; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_email_occurrences
    ADD CONSTRAINT fk_rails_190d1d7227 FOREIGN KEY (email_occurrence_id) REFERENCES public.email_occurrences(id) NOT VALID;


--
-- Name: email_operator_occurrences fk_rails_1b3f55514c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_operator_occurrences
    ADD CONSTRAINT fk_rails_1b3f55514c FOREIGN KEY (email_occurrence_id) REFERENCES public.email_occurrences(id) NOT VALID;


--
-- Name: operator_client_occurrences fk_rails_1e7954599d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_client_occurrences
    ADD CONSTRAINT fk_rails_1e7954599d FOREIGN KEY (staff_occurrence_id) REFERENCES public.operator_occurrences(id) NOT VALID;


--
-- Name: email_telephone_occurrences fk_rails_209d51cbd3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_telephone_occurrences
    ADD CONSTRAINT fk_rails_209d51cbd3 FOREIGN KEY (telephone_occurrence_id) REFERENCES public.telephone_occurrences(id) NOT VALID;


--
-- Name: domain_zip_occurrences fk_rails_20ab26995d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_zip_occurrences
    ADD CONSTRAINT fk_rails_20ab26995d FOREIGN KEY (zip_occurrence_id) REFERENCES public.zip_occurrences(id) NOT VALID;


--
-- Name: area_ip_occurrences fk_rails_22b982fb0e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_ip_occurrences
    ADD CONSTRAINT fk_rails_22b982fb0e FOREIGN KEY (area_occurrence_id) REFERENCES public.area_occurrences(id) NOT VALID;


--
-- Name: area_visitor_occurrences fk_rails_22c72f835b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_visitor_occurrences
    ADD CONSTRAINT fk_rails_22c72f835b FOREIGN KEY (area_occurrence_id) REFERENCES public.area_occurrences(id) NOT VALID;


--
-- Name: area_zip_occurrences fk_rails_2f56574cee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_zip_occurrences
    ADD CONSTRAINT fk_rails_2f56574cee FOREIGN KEY (zip_occurrence_id) REFERENCES public.zip_occurrences(id) NOT VALID;


--
-- Name: domain_ip_occurrences fk_rails_30c617346d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_ip_occurrences
    ADD CONSTRAINT fk_rails_30c617346d FOREIGN KEY (ip_occurrence_id) REFERENCES public.ip_occurrences(id) NOT VALID;


--
-- Name: email_telephone_occurrences fk_rails_34a4ac5d57; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_telephone_occurrences
    ADD CONSTRAINT fk_rails_34a4ac5d57 FOREIGN KEY (email_occurrence_id) REFERENCES public.email_occurrences(id) NOT VALID;


--
-- Name: email_visitor_occurrences fk_rails_363c71b53f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_visitor_occurrences
    ADD CONSTRAINT fk_rails_363c71b53f FOREIGN KEY (email_occurrence_id) REFERENCES public.email_occurrences(id) NOT VALID;


--
-- Name: email_zip_occurrences fk_rails_381f0f5f60; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_zip_occurrences
    ADD CONSTRAINT fk_rails_381f0f5f60 FOREIGN KEY (zip_occurrence_id) REFERENCES public.zip_occurrences(id) NOT VALID;


--
-- Name: client_zip_occurrences fk_rails_3e61e47523; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_zip_occurrences
    ADD CONSTRAINT fk_rails_3e61e47523 FOREIGN KEY (user_occurrence_id) REFERENCES public.client_occurrences(id) NOT VALID;


--
-- Name: area_telephone_occurrences fk_rails_42743b1b5d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_telephone_occurrences
    ADD CONSTRAINT fk_rails_42743b1b5d FOREIGN KEY (telephone_occurrence_id) REFERENCES public.telephone_occurrences(id) NOT VALID;


--
-- Name: ip_zip_occurrences fk_rails_43681b033b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_zip_occurrences
    ADD CONSTRAINT fk_rails_43681b033b FOREIGN KEY (ip_occurrence_id) REFERENCES public.ip_occurrences(id) NOT VALID;


--
-- Name: domain_telephone_occurrences fk_rails_43b450d653; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_telephone_occurrences
    ADD CONSTRAINT fk_rails_43b450d653 FOREIGN KEY (domain_occurrence_id) REFERENCES public.domain_occurrences(id) NOT VALID;


--
-- Name: ip_visitor_occurrences fk_rails_4bd9e2f547; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_visitor_occurrences
    ADD CONSTRAINT fk_rails_4bd9e2f547 FOREIGN KEY (ip_occurrence_id) REFERENCES public.ip_occurrences(id) NOT VALID;


--
-- Name: operator_telephone_occurrences fk_rails_4fe85fb8ea; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_telephone_occurrences
    ADD CONSTRAINT fk_rails_4fe85fb8ea FOREIGN KEY (staff_occurrence_id) REFERENCES public.operator_occurrences(id) NOT VALID;


--
-- Name: area_operator_occurrences fk_rails_51d4f8ec16; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_operator_occurrences
    ADD CONSTRAINT fk_rails_51d4f8ec16 FOREIGN KEY (area_occurrence_id) REFERENCES public.area_occurrences(id) NOT VALID;


--
-- Name: area_email_occurrences fk_rails_587a294924; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_email_occurrences
    ADD CONSTRAINT fk_rails_587a294924 FOREIGN KEY (email_occurrence_id) REFERENCES public.email_occurrences(id) NOT VALID;


--
-- Name: area_telephone_occurrences fk_rails_58c6f190f9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_telephone_occurrences
    ADD CONSTRAINT fk_rails_58c6f190f9 FOREIGN KEY (area_occurrence_id) REFERENCES public.area_occurrences(id) NOT VALID;


--
-- Name: email_operator_occurrences fk_rails_59212c3511; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_operator_occurrences
    ADD CONSTRAINT fk_rails_59212c3511 FOREIGN KEY (staff_occurrence_id) REFERENCES public.operator_occurrences(id) NOT VALID;


--
-- Name: area_domain_occurrences fk_rails_5bec914d67; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_domain_occurrences
    ADD CONSTRAINT fk_rails_5bec914d67 FOREIGN KEY (area_occurrence_id) REFERENCES public.area_occurrences(id) NOT VALID;


--
-- Name: domain_client_occurrences fk_rails_5fc25fbd6a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_client_occurrences
    ADD CONSTRAINT fk_rails_5fc25fbd6a FOREIGN KEY (user_occurrence_id) REFERENCES public.client_occurrences(id) NOT VALID;


--
-- Name: email_client_occurrences fk_rails_64273fb6e5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_client_occurrences
    ADD CONSTRAINT fk_rails_64273fb6e5 FOREIGN KEY (email_occurrence_id) REFERENCES public.email_occurrences(id) NOT VALID;


--
-- Name: operator_zip_occurrences fk_rails_69f99bbeaf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_zip_occurrences
    ADD CONSTRAINT fk_rails_69f99bbeaf FOREIGN KEY (staff_occurrence_id) REFERENCES public.operator_occurrences(id) NOT VALID;


--
-- Name: ip_telephone_occurrences fk_rails_6a0a2e9960; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_telephone_occurrences
    ADD CONSTRAINT fk_rails_6a0a2e9960 FOREIGN KEY (telephone_occurrence_id) REFERENCES public.telephone_occurrences(id) NOT VALID;


--
-- Name: ip_operator_occurrences fk_rails_6d03a3d401; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_operator_occurrences
    ADD CONSTRAINT fk_rails_6d03a3d401 FOREIGN KEY (staff_occurrence_id) REFERENCES public.operator_occurrences(id) NOT VALID;


--
-- Name: telephone_client_occurrences fk_rails_6f536d5ebf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.telephone_client_occurrences
    ADD CONSTRAINT fk_rails_6f536d5ebf FOREIGN KEY (user_occurrence_id) REFERENCES public.client_occurrences(id) NOT VALID;


--
-- Name: ip_client_occurrences fk_rails_72d1905cdd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_client_occurrences
    ADD CONSTRAINT fk_rails_72d1905cdd FOREIGN KEY (ip_occurrence_id) REFERENCES public.ip_occurrences(id) NOT VALID;


--
-- Name: telephone_zip_occurrences fk_rails_762eceb883; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.telephone_zip_occurrences
    ADD CONSTRAINT fk_rails_762eceb883 FOREIGN KEY (zip_occurrence_id) REFERENCES public.zip_occurrences(id) NOT VALID;


--
-- Name: domain_ip_occurrences fk_rails_77c6097609; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_ip_occurrences
    ADD CONSTRAINT fk_rails_77c6097609 FOREIGN KEY (domain_occurrence_id) REFERENCES public.domain_occurrences(id) NOT VALID;


--
-- Name: telephone_zip_occurrences fk_rails_79d04c2147; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.telephone_zip_occurrences
    ADD CONSTRAINT fk_rails_79d04c2147 FOREIGN KEY (telephone_occurrence_id) REFERENCES public.telephone_occurrences(id) NOT VALID;


--
-- Name: email_client_occurrences fk_rails_7a5ab1e241; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_client_occurrences
    ADD CONSTRAINT fk_rails_7a5ab1e241 FOREIGN KEY (user_occurrence_id) REFERENCES public.client_occurrences(id) NOT VALID;


--
-- Name: area_domain_occurrences fk_rails_8684e941ea; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_domain_occurrences
    ADD CONSTRAINT fk_rails_8684e941ea FOREIGN KEY (domain_occurrence_id) REFERENCES public.domain_occurrences(id) NOT VALID;


--
-- Name: operator_telephone_occurrences fk_rails_8b1f6ba670; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_telephone_occurrences
    ADD CONSTRAINT fk_rails_8b1f6ba670 FOREIGN KEY (telephone_occurrence_id) REFERENCES public.telephone_occurrences(id) NOT VALID;


--
-- Name: ip_zip_occurrences fk_rails_9136c2236a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_zip_occurrences
    ADD CONSTRAINT fk_rails_9136c2236a FOREIGN KEY (zip_occurrence_id) REFERENCES public.zip_occurrences(id) NOT VALID;


--
-- Name: domain_operator_occurrences fk_rails_93a08a87ce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_operator_occurrences
    ADD CONSTRAINT fk_rails_93a08a87ce FOREIGN KEY (domain_occurrence_id) REFERENCES public.domain_occurrences(id) NOT VALID;


--
-- Name: area_email_occurrences fk_rails_a358e72324; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_email_occurrences
    ADD CONSTRAINT fk_rails_a358e72324 FOREIGN KEY (area_occurrence_id) REFERENCES public.area_occurrences(id) NOT VALID;


--
-- Name: domain_operator_occurrences fk_rails_a39158f9e1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_operator_occurrences
    ADD CONSTRAINT fk_rails_a39158f9e1 FOREIGN KEY (staff_occurrence_id) REFERENCES public.operator_occurrences(id) NOT VALID;


--
-- Name: operator_zip_occurrences fk_rails_b2a9b8a8b3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_zip_occurrences
    ADD CONSTRAINT fk_rails_b2a9b8a8b3 FOREIGN KEY (zip_occurrence_id) REFERENCES public.zip_occurrences(id) NOT VALID;


--
-- Name: email_ip_occurrences fk_rails_b2fd16e596; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_ip_occurrences
    ADD CONSTRAINT fk_rails_b2fd16e596 FOREIGN KEY (email_occurrence_id) REFERENCES public.email_occurrences(id) NOT VALID;


--
-- Name: area_client_occurrences fk_rails_bc8f2fb1d9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_client_occurrences
    ADD CONSTRAINT fk_rails_bc8f2fb1d9 FOREIGN KEY (area_occurrence_id) REFERENCES public.area_occurrences(id) NOT VALID;


--
-- Name: email_zip_occurrences fk_rails_c31148b25f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_zip_occurrences
    ADD CONSTRAINT fk_rails_c31148b25f FOREIGN KEY (email_occurrence_id) REFERENCES public.email_occurrences(id) NOT VALID;


--
-- Name: email_visitor_occurrences fk_rails_c912bd4a94; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_visitor_occurrences
    ADD CONSTRAINT fk_rails_c912bd4a94 FOREIGN KEY (visitor_occurrence_id) REFERENCES public.visitor_occurrences(id) NOT VALID;


--
-- Name: client_zip_occurrences fk_rails_c91ad2be3e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_zip_occurrences
    ADD CONSTRAINT fk_rails_c91ad2be3e FOREIGN KEY (zip_occurrence_id) REFERENCES public.zip_occurrences(id) NOT VALID;


--
-- Name: area_visitor_occurrences fk_rails_cb6a0677f8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_visitor_occurrences
    ADD CONSTRAINT fk_rails_cb6a0677f8 FOREIGN KEY (visitor_occurrence_id) REFERENCES public.visitor_occurrences(id) NOT VALID;


--
-- Name: domain_client_occurrences fk_rails_cc055fd395; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_client_occurrences
    ADD CONSTRAINT fk_rails_cc055fd395 FOREIGN KEY (domain_occurrence_id) REFERENCES public.domain_occurrences(id) NOT VALID;


--
-- Name: email_ip_occurrences fk_rails_cc0f42ece0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_ip_occurrences
    ADD CONSTRAINT fk_rails_cc0f42ece0 FOREIGN KEY (ip_occurrence_id) REFERENCES public.ip_occurrences(id) NOT VALID;


--
-- Name: domain_email_occurrences fk_rails_dfecbcc166; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_email_occurrences
    ADD CONSTRAINT fk_rails_dfecbcc166 FOREIGN KEY (domain_occurrence_id) REFERENCES public.domain_occurrences(id) NOT VALID;


--
-- Name: area_operator_occurrences fk_rails_e851adb93d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_operator_occurrences
    ADD CONSTRAINT fk_rails_e851adb93d FOREIGN KEY (staff_occurrence_id) REFERENCES public.operator_occurrences(id) NOT VALID;


--
-- Name: telephone_client_occurrences fk_rails_e92d26d9f1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.telephone_client_occurrences
    ADD CONSTRAINT fk_rails_e92d26d9f1 FOREIGN KEY (telephone_occurrence_id) REFERENCES public.telephone_occurrences(id) NOT VALID;


--
-- Name: visitor_occurrences fk_rails_f0316e1852; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_occurrences
    ADD CONSTRAINT fk_rails_f0316e1852 FOREIGN KEY (status_id) REFERENCES public.visitor_occurrence_statuses(id) NOT VALID;


--
-- Name: ip_operator_occurrences fk_rails_f098ca3601; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_operator_occurrences
    ADD CONSTRAINT fk_rails_f098ca3601 FOREIGN KEY (ip_occurrence_id) REFERENCES public.ip_occurrences(id) NOT VALID;


--
-- Name: domain_zip_occurrences fk_rails_f15deee84c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_zip_occurrences
    ADD CONSTRAINT fk_rails_f15deee84c FOREIGN KEY (domain_occurrence_id) REFERENCES public.domain_occurrences(id) NOT VALID;


--
-- Name: area_client_occurrences fk_rails_f171bdb1c9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.area_client_occurrences
    ADD CONSTRAINT fk_rails_f171bdb1c9 FOREIGN KEY (user_occurrence_id) REFERENCES public.client_occurrences(id) NOT VALID;


--
-- Name: domain_telephone_occurrences fk_rails_fc2f6167c7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_telephone_occurrences
    ADD CONSTRAINT fk_rails_fc2f6167c7 FOREIGN KEY (telephone_occurrence_id) REFERENCES public.telephone_occurrences(id) NOT VALID;


--
-- Name: operator_occurrences fk_staff_occurrences_on_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_occurrences
    ADD CONSTRAINT fk_staff_occurrences_on_status_id FOREIGN KEY (status_id) REFERENCES public.operator_occurrence_statuses(id);


--
-- Name: telephone_occurrences fk_telephone_occurrences_on_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.telephone_occurrences
    ADD CONSTRAINT fk_telephone_occurrences_on_status_id FOREIGN KEY (status_id) REFERENCES public.telephone_occurrence_statuses(id);


--
-- Name: client_occurrences fk_user_occurrences_on_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_occurrences
    ADD CONSTRAINT fk_user_occurrences_on_status_id FOREIGN KEY (status_id) REFERENCES public.client_occurrence_statuses(id);


--
-- Name: zip_occurrences fk_zip_occurrences_on_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zip_occurrences
    ADD CONSTRAINT fk_zip_occurrences_on_status_id FOREIGN KEY (status_id) REFERENCES public.zip_occurrence_statuses(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260921133000'),
('20260918150000'),
('20260616150022'),
('20260616150020'),
('20260520143007'),
('20260518044459'),
('20260513130000'),
('20260513121000'),
('20260513120000'),
('20260508151000'),
('20260508140999'),
('20260508135006'),
('20260329143000'),
('20260329141500'),
('20260329140000'),
('20260329134500'),
('20260329133000'),
('20260312100000'),
('20260311151100'),
('20260311151000'),
('20260311150300'),
('20260311150200'),
('20260311150100'),
('20260311150000'),
('20260309000001'),
('20260221100001'),
('20260213111815'),
('20260213111812'),
('20260213111811'),
('20260213111809'),
('20260213111808'),
('20260212120200'),
('20260212120100'),
('20260212120000'),
('20260212000010'),
('20260202260000'),
('20260202220000'),
('20260202210000'),
('20260202183000'),
('20260201214620'),
('20260201210006'),
('20260201190011'),
('20260109141212'),
('20260102100037'),
('20260102100035'),
('20260102100027'),
('20260102100016'),
('20260102100014'),
('20260102100013'),
('20260102100005'),
('20251230080013'),
('20251230080012'),
('20251230080010'),
('20251230072206'),
('20251230072205'),
('20251230031020'),
('20251230010200'),
('20251228000006'),
('20251226020813'),
('20251226012656'),
('20251225005212'),
('20251225005205'),
('20251225005159'),
('20251225005152'),
('20251225005146'),
('20251225005139'),
('20251225005133'),
('20251225005126'),
('20251225005120'),
('20251225005114'),
('20251225005107'),
('20251225005100'),
('20251225005054'),
('20251225005048'),
('20251225005042'),
('20251225005035'),
('20251225005029'),
('20251225005023'),
('20251225005017'),
('20251225005010'),
('20251225005004'),
('20251225004958'),
('20251225004951'),
('20251225004944'),
('20251225004938'),
('20251225004932'),
('20251225004919'),
('20251225004325'),
('20251224173000'),
('20251224160100'),
('20251224154300'),
('20251224140000'),
('20251224123600'),
('20251221145000'),
('20251221144000'),
('20251221143000'),
('20251221140004'),
('20251221140003'),
('20251221140002'),
('20251221140001'),
('20251221140000'),
('20251220100000'),
('20251219093000'),
('20251219090204'),
('20251219085421'),
('20251219085418'),
('20251219085414'),
('20251219085411'),
('20251219085407'),
('20251219084315'),
('20251219084310'),
('20251219084304'),
('20251219084256'),
('20251219084023'),
('20251219082728'),
('20240627130203');

