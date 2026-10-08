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


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account_access_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_access_events (
    id bigint NOT NULL,
    account_type character varying NOT NULL,
    account_id bigint NOT NULL,
    event_type character varying NOT NULL,
    previous_access_state character varying NOT NULL,
    next_access_state character varying NOT NULL,
    operator_id bigint NOT NULL,
    reason_code character varying NOT NULL,
    reason_note text,
    ticket_id character varying,
    occurred_at timestamp(6) with time zone NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_account_access_events_account_type CHECK (((account_type)::text = ANY (ARRAY[('Client'::character varying)::text, ('Visitor'::character varying)::text, ('Operator'::character varying)::text]))),
    CONSTRAINT chk_account_access_events_event_type CHECK (((event_type)::text = ANY (ARRAY[('admin_lock'::character varying)::text, ('admin_lock_reaffirmed'::character varying)::text, ('admin_unlock'::character varying)::text, ('emergency_session_revoke'::character varying)::text, ('session_purge'::character varying)::text]))),
    CONSTRAINT chk_account_access_events_next_access_state CHECK (((next_access_state)::text = ANY (ARRAY[('enabled'::character varying)::text, ('admin_locked'::character varying)::text]))),
    CONSTRAINT chk_account_access_events_previous_access_state CHECK (((previous_access_state)::text = ANY (ARRAY[('enabled'::character varying)::text, ('admin_locked'::character varying)::text]))),
    CONSTRAINT chk_account_access_events_reason_code CHECK (((reason_code)::text = ANY (ARRAY[('abuse'::character varying)::text, ('security_incident'::character varying)::text, ('chargeback'::character varying)::text, ('terms_violation'::character varying)::text, ('support_request'::character varying)::text, ('legal_hold'::character varying)::text, ('operator_error_recovery'::character varying)::text, ('other'::character varying)::text])))
);


--
-- Name: account_access_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.account_access_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: account_access_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.account_access_events_id_seq OWNED BY public.account_access_events.id;


--
-- Name: app_document_audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_document_audit_events (
    id bigint NOT NULL
);


--
-- Name: app_document_audit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_document_audit_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_document_audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_document_audit_events_id_seq OWNED BY public.app_document_audit_events.id;


--
-- Name: app_document_audit_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_document_audit_levels (
    id bigint NOT NULL
);


--
-- Name: app_document_audit_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_document_audit_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_document_audit_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_document_audit_levels_id_seq OWNED BY public.app_document_audit_levels.id;


--
-- Name: app_document_audits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_document_audits (
    id bigint NOT NULL,
    actor_id bigint DEFAULT 0 NOT NULL,
    actor_type text DEFAULT ''::text NOT NULL,
    context jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    current_value text DEFAULT ''::text NOT NULL,
    event_id bigint DEFAULT 0 NOT NULL,
    expires_at timestamp(6) with time zone DEFAULT (CURRENT_TIMESTAMP + '7 years'::interval) NOT NULL,
    ip_address inet DEFAULT '0.0.0.0'::inet NOT NULL,
    level_id bigint DEFAULT 0 NOT NULL,
    occurred_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    previous_value text DEFAULT ''::text NOT NULL,
    subject_id bigint NOT NULL,
    subject_type text NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT app_document_audits_event_id_non_negative_check CHECK ((event_id >= 0)),
    CONSTRAINT app_document_audits_level_id_non_negative_check CHECK ((level_id >= 0))
);


--
-- Name: app_document_audits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_document_audits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_document_audits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_document_audits_id_seq OWNED BY public.app_document_audits.id;


--
-- Name: app_document_behavior_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_document_behavior_events (
    id bigint NOT NULL
);


--
-- Name: app_document_behavior_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_document_behavior_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_document_behavior_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_document_behavior_events_id_seq OWNED BY public.app_document_behavior_events.id;


--
-- Name: app_document_behavior_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_document_behavior_levels (
    id bigint NOT NULL
);


--
-- Name: app_document_behavior_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_document_behavior_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_document_behavior_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_document_behavior_levels_id_seq OWNED BY public.app_document_behavior_levels.id;


--
-- Name: app_document_behaviors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_document_behaviors (
    id bigint NOT NULL,
    actor_id bigint,
    actor_type character varying,
    created_at timestamp(6) with time zone NOT NULL,
    event_id bigint NOT NULL,
    expires_at timestamp(6) with time zone,
    level_id bigint NOT NULL,
    occurred_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP,
    subject_id bigint NOT NULL,
    subject_type character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: app_document_behaviors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_document_behaviors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_document_behaviors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_document_behaviors_id_seq OWNED BY public.app_document_behaviors.id;


--
-- Name: app_preference_chronicle_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_preference_chronicle_events (
    id bigint NOT NULL
);


--
-- Name: app_preference_chronicle_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_preference_chronicle_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_preference_chronicle_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_preference_chronicle_events_id_seq OWNED BY public.app_preference_chronicle_events.id;


--
-- Name: app_preference_chronicle_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_preference_chronicle_levels (
    id bigint NOT NULL
);


--
-- Name: app_preference_chronicle_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_preference_chronicle_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_preference_chronicle_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_preference_chronicle_levels_id_seq OWNED BY public.app_preference_chronicle_levels.id;


--
-- Name: app_preference_chronicles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_preference_chronicles (
    id bigint NOT NULL,
    actor_id bigint DEFAULT 0 NOT NULL,
    actor_type text DEFAULT ''::text NOT NULL,
    context jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    current_value text DEFAULT ''::text NOT NULL,
    event_id bigint DEFAULT 0 NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT (CURRENT_TIMESTAMP + '7 years'::interval) NOT NULL,
    ip_address inet DEFAULT '0.0.0.0'::inet NOT NULL,
    level_id bigint DEFAULT 0 NOT NULL,
    occurred_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    previous_value text DEFAULT ''::text NOT NULL,
    subject_id bigint NOT NULL,
    subject_type text NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT app_preference_activities_event_id_non_negative_check CHECK ((event_id >= 0)),
    CONSTRAINT app_preference_activities_level_id_non_negative_check CHECK ((level_id >= 0))
);


--
-- Name: app_preference_chronicles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_preference_chronicles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_preference_chronicles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_preference_chronicles_id_seq OWNED BY public.app_preference_chronicles.id;


--
-- Name: app_timeline_audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_timeline_audit_events (
    id bigint NOT NULL
);


--
-- Name: app_timeline_audit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_timeline_audit_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_timeline_audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_timeline_audit_events_id_seq OWNED BY public.app_timeline_audit_events.id;


--
-- Name: app_timeline_audit_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_timeline_audit_levels (
    id bigint NOT NULL
);


--
-- Name: app_timeline_audit_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_timeline_audit_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_timeline_audit_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_timeline_audit_levels_id_seq OWNED BY public.app_timeline_audit_levels.id;


--
-- Name: app_timeline_audits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_timeline_audits (
    id bigint NOT NULL,
    actor_id bigint DEFAULT 0 NOT NULL,
    actor_type text DEFAULT ''::text NOT NULL,
    context jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    current_value text DEFAULT ''::text NOT NULL,
    event_id bigint DEFAULT 0 NOT NULL,
    expires_at timestamp(6) with time zone DEFAULT (CURRENT_TIMESTAMP + '7 years'::interval) NOT NULL,
    ip_address inet DEFAULT '0.0.0.0'::inet NOT NULL,
    level_id bigint DEFAULT 0 NOT NULL,
    occurred_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    previous_value text DEFAULT ''::text NOT NULL,
    subject_id bigint NOT NULL,
    subject_type text NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT app_timeline_audits_event_id_non_negative_check CHECK ((event_id >= 0)),
    CONSTRAINT app_timeline_audits_level_id_non_negative_check CHECK ((level_id >= 0))
);


--
-- Name: app_timeline_audits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_timeline_audits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_timeline_audits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_timeline_audits_id_seq OWNED BY public.app_timeline_audits.id;


--
-- Name: app_timeline_behavior_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_timeline_behavior_events (
    id bigint NOT NULL
);


--
-- Name: app_timeline_behavior_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_timeline_behavior_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_timeline_behavior_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_timeline_behavior_events_id_seq OWNED BY public.app_timeline_behavior_events.id;


--
-- Name: app_timeline_behavior_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_timeline_behavior_levels (
    id bigint NOT NULL
);


--
-- Name: app_timeline_behavior_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_timeline_behavior_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_timeline_behavior_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_timeline_behavior_levels_id_seq OWNED BY public.app_timeline_behavior_levels.id;


--
-- Name: app_timeline_behaviors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_timeline_behaviors (
    id bigint NOT NULL,
    actor_id bigint,
    actor_type character varying,
    created_at timestamp(6) with time zone NOT NULL,
    event_id bigint NOT NULL,
    expires_at timestamp(6) with time zone,
    level_id bigint NOT NULL,
    occurred_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP,
    subject_id bigint NOT NULL,
    subject_type character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: app_timeline_behaviors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_timeline_behaviors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_timeline_behaviors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_timeline_behaviors_id_seq OWNED BY public.app_timeline_behaviors.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: chronicle_outbox_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chronicle_outbox_entries (
    id bigint NOT NULL,
    chronicle_id bigint,
    event_uuid character varying NOT NULL,
    request_id character varying,
    event character varying NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    status character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: chronicle_outbox_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chronicle_outbox_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chronicle_outbox_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chronicle_outbox_entries_id_seq OWNED BY public.chronicle_outbox_entries.id;


--
-- Name: chronicle_retention_policies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chronicle_retention_policies (
    id bigint NOT NULL,
    code character varying NOT NULL,
    name character varying NOT NULL,
    duration_days integer NOT NULL,
    permanent boolean NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_chronicle_retention_policies_permanent_duration CHECK (((permanent = false) OR (duration_days = 0)))
);


--
-- Name: chronicle_retention_policies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chronicle_retention_policies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chronicle_retention_policies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chronicle_retention_policies_id_seq OWNED BY public.chronicle_retention_policies.id;


--
-- Name: chronicle_visibilities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chronicle_visibilities (
    id bigint NOT NULL,
    chronicle_id bigint NOT NULL,
    chronicle_visibility_context_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: chronicle_visibilities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chronicle_visibilities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chronicle_visibilities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chronicle_visibilities_id_seq OWNED BY public.chronicle_visibilities.id;


--
-- Name: chronicle_visibility_contexts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chronicle_visibility_contexts (
    id bigint NOT NULL,
    code character varying NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: chronicle_visibility_contexts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chronicle_visibility_contexts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chronicle_visibility_contexts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chronicle_visibility_contexts_id_seq OWNED BY public.chronicle_visibility_contexts.id;


--
-- Name: chronicles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chronicles (
    id bigint NOT NULL,
    event_uuid character varying NOT NULL,
    actor_type character varying,
    actor_id bigint,
    subject_type character varying,
    subject_id bigint,
    chronicle_retention_policy_id bigint NOT NULL,
    action character varying NOT NULL,
    result character varying NOT NULL,
    reason character varying,
    occurred_at timestamp(6) with time zone NOT NULL,
    erasable_at timestamp(6) with time zone,
    request_id character varying,
    ip_address inet,
    user_agent text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    changeset jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_chronicles_result CHECK (((result)::text = ANY (ARRAY[('intent'::character varying)::text, ('succeeded'::character varying)::text, ('failed'::character varying)::text, ('audit_incomplete'::character varying)::text, ('invalidated'::character varying)::text, ('manual_recovery_required'::character varying)::text])))
);


--
-- Name: chronicles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chronicles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chronicles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chronicles_id_seq OWNED BY public.chronicles.id;


--
-- Name: client_chronicle_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_chronicle_events (
    id bigint NOT NULL
);


--
-- Name: client_chronicle_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_chronicle_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_chronicle_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_chronicle_events_id_seq OWNED BY public.client_chronicle_events.id;


--
-- Name: client_chronicle_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_chronicle_levels (
    id bigint NOT NULL
);


--
-- Name: client_chronicle_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_chronicle_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_chronicle_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_chronicle_levels_id_seq OWNED BY public.client_chronicle_levels.id;


--
-- Name: client_chronicles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_chronicles (
    id bigint NOT NULL,
    actor_id bigint DEFAULT 0 NOT NULL,
    actor_type text DEFAULT ''::text NOT NULL,
    context jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    current_value text DEFAULT ''::text NOT NULL,
    event_id bigint DEFAULT 0 NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT (CURRENT_TIMESTAMP + '7 years'::interval) NOT NULL,
    ip_address inet DEFAULT '0.0.0.0'::inet NOT NULL,
    level_id bigint DEFAULT 0 NOT NULL,
    occurred_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    previous_value text DEFAULT ''::text NOT NULL,
    subject_id bigint NOT NULL,
    subject_type text NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT user_activities_event_id_non_negative_check CHECK ((event_id >= 0)),
    CONSTRAINT user_activities_level_id_non_negative_check CHECK ((level_id >= 0))
);


--
-- Name: client_chronicles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_chronicles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_chronicles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_chronicles_id_seq OWNED BY public.client_chronicles.id;


--
-- Name: com_document_audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.com_document_audit_events (
    id bigint NOT NULL
);


--
-- Name: com_document_audit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.com_document_audit_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_document_audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_document_audit_events_id_seq OWNED BY public.com_document_audit_events.id;


--
-- Name: com_document_audit_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.com_document_audit_levels (
    id bigint NOT NULL
);


--
-- Name: com_document_audit_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.com_document_audit_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_document_audit_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_document_audit_levels_id_seq OWNED BY public.com_document_audit_levels.id;


--
-- Name: com_document_audits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.com_document_audits (
    id bigint NOT NULL,
    actor_id bigint DEFAULT 0 NOT NULL,
    actor_type text DEFAULT ''::text NOT NULL,
    context jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    current_value text DEFAULT ''::text NOT NULL,
    event_id bigint DEFAULT 0 NOT NULL,
    expires_at timestamp(6) with time zone DEFAULT (CURRENT_TIMESTAMP + '7 years'::interval) NOT NULL,
    ip_address inet DEFAULT '0.0.0.0'::inet NOT NULL,
    level_id bigint DEFAULT 0 NOT NULL,
    occurred_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    previous_value text DEFAULT ''::text NOT NULL,
    subject_id bigint NOT NULL,
    subject_type text NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT com_document_audits_event_id_non_negative_check CHECK ((event_id >= 0)),
    CONSTRAINT com_document_audits_level_id_non_negative_check CHECK ((level_id >= 0))
);


--
-- Name: com_document_audits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.com_document_audits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_document_audits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_document_audits_id_seq OWNED BY public.com_document_audits.id;


--
-- Name: com_document_behavior_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.com_document_behavior_events (
    id bigint NOT NULL
);


--
-- Name: com_document_behavior_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.com_document_behavior_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_document_behavior_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_document_behavior_events_id_seq OWNED BY public.com_document_behavior_events.id;


--
-- Name: com_document_behavior_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.com_document_behavior_levels (
    id bigint NOT NULL
);


--
-- Name: com_document_behavior_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.com_document_behavior_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_document_behavior_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_document_behavior_levels_id_seq OWNED BY public.com_document_behavior_levels.id;


--
-- Name: com_document_behaviors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.com_document_behaviors (
    id bigint NOT NULL,
    actor_id bigint,
    actor_type character varying,
    created_at timestamp(6) with time zone NOT NULL,
    event_id bigint NOT NULL,
    expires_at timestamp(6) with time zone,
    level_id bigint NOT NULL,
    occurred_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP,
    subject_id bigint NOT NULL,
    subject_type character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: com_document_behaviors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.com_document_behaviors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_document_behaviors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_document_behaviors_id_seq OWNED BY public.com_document_behaviors.id;


--
-- Name: com_preference_chronicle_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.com_preference_chronicle_events (
    id bigint NOT NULL
);


--
-- Name: com_preference_chronicle_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.com_preference_chronicle_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_preference_chronicle_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_preference_chronicle_events_id_seq OWNED BY public.com_preference_chronicle_events.id;


--
-- Name: com_preference_chronicle_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.com_preference_chronicle_levels (
    id bigint NOT NULL
);


--
-- Name: com_preference_chronicle_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.com_preference_chronicle_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_preference_chronicle_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_preference_chronicle_levels_id_seq OWNED BY public.com_preference_chronicle_levels.id;


--
-- Name: com_preference_chronicles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.com_preference_chronicles (
    id bigint NOT NULL,
    actor_id bigint DEFAULT 0 NOT NULL,
    actor_type text DEFAULT ''::text NOT NULL,
    context jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    current_value text DEFAULT ''::text NOT NULL,
    event_id bigint DEFAULT 0 NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT (CURRENT_TIMESTAMP + '7 years'::interval) NOT NULL,
    ip_address inet DEFAULT '0.0.0.0'::inet NOT NULL,
    level_id bigint DEFAULT 0 NOT NULL,
    occurred_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    previous_value text DEFAULT ''::text NOT NULL,
    subject_id bigint NOT NULL,
    subject_type text NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT com_preference_activities_event_id_non_negative_check CHECK ((event_id >= 0)),
    CONSTRAINT com_preference_activities_level_id_non_negative_check CHECK ((level_id >= 0))
);


--
-- Name: com_preference_chronicles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.com_preference_chronicles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_preference_chronicles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_preference_chronicles_id_seq OWNED BY public.com_preference_chronicles.id;


--
-- Name: com_timeline_audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.com_timeline_audit_events (
    id bigint NOT NULL
);


--
-- Name: com_timeline_audit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.com_timeline_audit_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_timeline_audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_timeline_audit_events_id_seq OWNED BY public.com_timeline_audit_events.id;


--
-- Name: com_timeline_audit_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.com_timeline_audit_levels (
    id bigint NOT NULL
);


--
-- Name: com_timeline_audit_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.com_timeline_audit_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_timeline_audit_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_timeline_audit_levels_id_seq OWNED BY public.com_timeline_audit_levels.id;


--
-- Name: com_timeline_audits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.com_timeline_audits (
    id bigint NOT NULL,
    actor_id bigint DEFAULT 0 NOT NULL,
    actor_type text DEFAULT ''::text NOT NULL,
    context jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    current_value text DEFAULT ''::text NOT NULL,
    event_id bigint DEFAULT 0 NOT NULL,
    expires_at timestamp(6) with time zone DEFAULT (CURRENT_TIMESTAMP + '7 years'::interval) NOT NULL,
    ip_address inet DEFAULT '0.0.0.0'::inet NOT NULL,
    level_id bigint DEFAULT 0 NOT NULL,
    occurred_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    previous_value text DEFAULT ''::text NOT NULL,
    subject_id bigint NOT NULL,
    subject_type text NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT com_timeline_audits_event_id_non_negative_check CHECK ((event_id >= 0)),
    CONSTRAINT com_timeline_audits_level_id_non_negative_check CHECK ((level_id >= 0))
);


--
-- Name: com_timeline_audits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.com_timeline_audits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_timeline_audits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_timeline_audits_id_seq OWNED BY public.com_timeline_audits.id;


--
-- Name: com_timeline_behavior_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.com_timeline_behavior_events (
    id bigint NOT NULL
);


--
-- Name: com_timeline_behavior_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.com_timeline_behavior_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_timeline_behavior_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_timeline_behavior_events_id_seq OWNED BY public.com_timeline_behavior_events.id;


--
-- Name: com_timeline_behavior_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.com_timeline_behavior_levels (
    id bigint NOT NULL
);


--
-- Name: com_timeline_behavior_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.com_timeline_behavior_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_timeline_behavior_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_timeline_behavior_levels_id_seq OWNED BY public.com_timeline_behavior_levels.id;


--
-- Name: com_timeline_behaviors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.com_timeline_behaviors (
    id bigint NOT NULL,
    actor_id bigint,
    actor_type character varying,
    created_at timestamp(6) with time zone NOT NULL,
    event_id bigint NOT NULL,
    expires_at timestamp(6) with time zone,
    level_id bigint NOT NULL,
    occurred_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP,
    subject_id bigint NOT NULL,
    subject_type character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: com_timeline_behaviors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.com_timeline_behaviors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_timeline_behaviors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_timeline_behaviors_id_seq OWNED BY public.com_timeline_behaviors.id;


--
-- Name: enforcement_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enforcement_events (
    id bigint NOT NULL,
    realm character varying NOT NULL,
    case_public_id character varying NOT NULL,
    principal_public_id character varying NOT NULL,
    event_type character varying NOT NULL,
    reason_code character varying,
    operator_public_id character varying,
    break_glass boolean DEFAULT false NOT NULL,
    ticket_id character varying,
    occurred_at timestamp(6) with time zone NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_enforcement_events_event_type CHECK (((event_type)::text = ANY (ARRAY[('created'::character varying)::text, ('approval_requested'::character varying)::text, ('approved'::character varying)::text, ('applied'::character varying)::text, ('activated'::character varying)::text, ('extended'::character varying)::text, ('escalated'::character varying)::text, ('reduced'::character varying)::text, ('ended'::character varying)::text, ('expired'::character varying)::text, ('corrected'::character varying)::text, ('break_glass_released'::character varying)::text, ('appeal_submitted'::character varying)::text, ('appeal_approved'::character varying)::text, ('appeal_rejected'::character varying)::text, ('principal_linked'::character varying)::text, ('principal_reinstated'::character varying)::text, ('revocation_failed'::character varying)::text, ('revocation_reconciled'::character varying)::text]))),
    CONSTRAINT chk_enforcement_events_realm CHECK (((realm)::text = ANY (ARRAY[('app'::character varying)::text, ('com'::character varying)::text, ('org'::character varying)::text])))
);


--
-- Name: enforcement_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enforcement_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enforcement_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enforcement_events_id_seq OWNED BY public.enforcement_events.id;


--
-- Name: operator_chronicle_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_chronicle_events (
    id bigint NOT NULL
);


--
-- Name: operator_chronicle_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_chronicle_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_chronicle_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_chronicle_events_id_seq OWNED BY public.operator_chronicle_events.id;


--
-- Name: operator_chronicle_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_chronicle_levels (
    id bigint NOT NULL
);


--
-- Name: operator_chronicle_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_chronicle_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_chronicle_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_chronicle_levels_id_seq OWNED BY public.operator_chronicle_levels.id;


--
-- Name: operator_chronicles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_chronicles (
    id bigint NOT NULL,
    actor_id bigint DEFAULT 0 NOT NULL,
    actor_type text DEFAULT ''::text NOT NULL,
    context jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    current_value text DEFAULT ''::text NOT NULL,
    event_id bigint DEFAULT 0 NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT (CURRENT_TIMESTAMP + '7 years'::interval) NOT NULL,
    ip_address inet DEFAULT '0.0.0.0'::inet NOT NULL,
    level_id bigint DEFAULT 0 NOT NULL,
    occurred_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    previous_value text DEFAULT ''::text NOT NULL,
    subject_id bigint NOT NULL,
    subject_type text NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT staff_activities_event_id_non_negative_check CHECK ((event_id >= 0)),
    CONSTRAINT staff_activities_level_id_non_negative_check CHECK ((level_id >= 0))
);


--
-- Name: operator_chronicles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_chronicles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_chronicles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_chronicles_id_seq OWNED BY public.operator_chronicles.id;


--
-- Name: org_document_audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_document_audit_events (
    id bigint NOT NULL
);


--
-- Name: org_document_audit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_document_audit_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_document_audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_document_audit_events_id_seq OWNED BY public.org_document_audit_events.id;


--
-- Name: org_document_audit_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_document_audit_levels (
    id bigint NOT NULL
);


--
-- Name: org_document_audit_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_document_audit_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_document_audit_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_document_audit_levels_id_seq OWNED BY public.org_document_audit_levels.id;


--
-- Name: org_document_audits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_document_audits (
    id bigint NOT NULL,
    actor_id bigint DEFAULT 0 NOT NULL,
    actor_type text DEFAULT ''::text NOT NULL,
    context jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    current_value text DEFAULT ''::text NOT NULL,
    event_id bigint DEFAULT 0 NOT NULL,
    expires_at timestamp(6) with time zone DEFAULT (CURRENT_TIMESTAMP + '7 years'::interval) NOT NULL,
    ip_address inet DEFAULT '0.0.0.0'::inet NOT NULL,
    level_id bigint DEFAULT 0 NOT NULL,
    occurred_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    previous_value text DEFAULT ''::text NOT NULL,
    subject_id bigint NOT NULL,
    subject_type text NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT org_document_audits_event_id_non_negative_check CHECK ((event_id >= 0)),
    CONSTRAINT org_document_audits_level_id_non_negative_check CHECK ((level_id >= 0))
);


--
-- Name: org_document_audits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_document_audits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_document_audits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_document_audits_id_seq OWNED BY public.org_document_audits.id;


--
-- Name: org_document_behavior_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_document_behavior_events (
    id bigint NOT NULL
);


--
-- Name: org_document_behavior_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_document_behavior_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_document_behavior_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_document_behavior_events_id_seq OWNED BY public.org_document_behavior_events.id;


--
-- Name: org_document_behavior_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_document_behavior_levels (
    id bigint NOT NULL
);


--
-- Name: org_document_behavior_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_document_behavior_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_document_behavior_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_document_behavior_levels_id_seq OWNED BY public.org_document_behavior_levels.id;


--
-- Name: org_document_behaviors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_document_behaviors (
    id bigint NOT NULL,
    actor_id bigint,
    actor_type character varying,
    created_at timestamp(6) with time zone NOT NULL,
    event_id bigint NOT NULL,
    expires_at timestamp(6) with time zone,
    level_id bigint NOT NULL,
    occurred_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP,
    subject_id bigint NOT NULL,
    subject_type character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_document_behaviors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_document_behaviors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_document_behaviors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_document_behaviors_id_seq OWNED BY public.org_document_behaviors.id;


--
-- Name: org_preference_chronicle_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_preference_chronicle_events (
    id bigint NOT NULL
);


--
-- Name: org_preference_chronicle_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_preference_chronicle_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_chronicle_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_chronicle_events_id_seq OWNED BY public.org_preference_chronicle_events.id;


--
-- Name: org_preference_chronicle_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_preference_chronicle_levels (
    id bigint NOT NULL
);


--
-- Name: org_preference_chronicle_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_preference_chronicle_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_chronicle_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_chronicle_levels_id_seq OWNED BY public.org_preference_chronicle_levels.id;


--
-- Name: org_preference_chronicles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_preference_chronicles (
    id bigint NOT NULL,
    actor_id bigint DEFAULT 0 NOT NULL,
    actor_type text DEFAULT ''::text NOT NULL,
    context jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    current_value text DEFAULT ''::text NOT NULL,
    event_id bigint DEFAULT 0 NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT (CURRENT_TIMESTAMP + '7 years'::interval) NOT NULL,
    ip_address inet DEFAULT '0.0.0.0'::inet NOT NULL,
    level_id bigint DEFAULT 0 NOT NULL,
    occurred_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    previous_value text DEFAULT ''::text NOT NULL,
    subject_id bigint NOT NULL,
    subject_type text NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT org_preference_activities_event_id_non_negative_check CHECK ((event_id >= 0)),
    CONSTRAINT org_preference_activities_level_id_non_negative_check CHECK ((level_id >= 0))
);


--
-- Name: org_preference_chronicles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_preference_chronicles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_preference_chronicles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_preference_chronicles_id_seq OWNED BY public.org_preference_chronicles.id;


--
-- Name: org_timeline_audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_timeline_audit_events (
    id bigint NOT NULL
);


--
-- Name: org_timeline_audit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_timeline_audit_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_timeline_audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_timeline_audit_events_id_seq OWNED BY public.org_timeline_audit_events.id;


--
-- Name: org_timeline_audit_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_timeline_audit_levels (
    id bigint NOT NULL
);


--
-- Name: org_timeline_audit_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_timeline_audit_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_timeline_audit_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_timeline_audit_levels_id_seq OWNED BY public.org_timeline_audit_levels.id;


--
-- Name: org_timeline_audits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_timeline_audits (
    id bigint NOT NULL,
    actor_id bigint DEFAULT 0 NOT NULL,
    actor_type text DEFAULT ''::text NOT NULL,
    context jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    current_value text DEFAULT ''::text NOT NULL,
    event_id bigint DEFAULT 0 NOT NULL,
    expires_at timestamp(6) with time zone DEFAULT (CURRENT_TIMESTAMP + '7 years'::interval) NOT NULL,
    ip_address inet DEFAULT '0.0.0.0'::inet NOT NULL,
    level_id bigint DEFAULT 0 NOT NULL,
    occurred_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    previous_value text DEFAULT ''::text NOT NULL,
    subject_id bigint NOT NULL,
    subject_type text NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT org_timeline_audits_event_id_non_negative_check CHECK ((event_id >= 0)),
    CONSTRAINT org_timeline_audits_level_id_non_negative_check CHECK ((level_id >= 0))
);


--
-- Name: org_timeline_audits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_timeline_audits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_timeline_audits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_timeline_audits_id_seq OWNED BY public.org_timeline_audits.id;


--
-- Name: org_timeline_behavior_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_timeline_behavior_events (
    id bigint NOT NULL
);


--
-- Name: org_timeline_behavior_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_timeline_behavior_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_timeline_behavior_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_timeline_behavior_events_id_seq OWNED BY public.org_timeline_behavior_events.id;


--
-- Name: org_timeline_behavior_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_timeline_behavior_levels (
    id bigint NOT NULL
);


--
-- Name: org_timeline_behavior_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_timeline_behavior_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_timeline_behavior_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_timeline_behavior_levels_id_seq OWNED BY public.org_timeline_behavior_levels.id;


--
-- Name: org_timeline_behaviors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_timeline_behaviors (
    id bigint NOT NULL,
    actor_id bigint,
    actor_type character varying,
    created_at timestamp(6) with time zone NOT NULL,
    event_id bigint NOT NULL,
    expires_at timestamp(6) with time zone,
    level_id bigint NOT NULL,
    occurred_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP,
    subject_id bigint NOT NULL,
    subject_type character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_timeline_behaviors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_timeline_behaviors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_timeline_behaviors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_timeline_behaviors_id_seq OWNED BY public.org_timeline_behaviors.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: account_access_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_access_events ALTER COLUMN id SET DEFAULT nextval('public.account_access_events_id_seq'::regclass);


--
-- Name: app_document_audit_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_document_audit_events ALTER COLUMN id SET DEFAULT nextval('public.app_document_audit_events_id_seq'::regclass);


--
-- Name: app_document_audit_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_document_audit_levels ALTER COLUMN id SET DEFAULT nextval('public.app_document_audit_levels_id_seq'::regclass);


--
-- Name: app_document_audits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_document_audits ALTER COLUMN id SET DEFAULT nextval('public.app_document_audits_id_seq'::regclass);


--
-- Name: app_document_behavior_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_document_behavior_events ALTER COLUMN id SET DEFAULT nextval('public.app_document_behavior_events_id_seq'::regclass);


--
-- Name: app_document_behavior_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_document_behavior_levels ALTER COLUMN id SET DEFAULT nextval('public.app_document_behavior_levels_id_seq'::regclass);


--
-- Name: app_document_behaviors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_document_behaviors ALTER COLUMN id SET DEFAULT nextval('public.app_document_behaviors_id_seq'::regclass);


--
-- Name: app_preference_chronicle_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_preference_chronicle_events ALTER COLUMN id SET DEFAULT nextval('public.app_preference_chronicle_events_id_seq'::regclass);


--
-- Name: app_preference_chronicle_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_preference_chronicle_levels ALTER COLUMN id SET DEFAULT nextval('public.app_preference_chronicle_levels_id_seq'::regclass);


--
-- Name: app_preference_chronicles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_preference_chronicles ALTER COLUMN id SET DEFAULT nextval('public.app_preference_chronicles_id_seq'::regclass);


--
-- Name: app_timeline_audit_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_timeline_audit_events ALTER COLUMN id SET DEFAULT nextval('public.app_timeline_audit_events_id_seq'::regclass);


--
-- Name: app_timeline_audit_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_timeline_audit_levels ALTER COLUMN id SET DEFAULT nextval('public.app_timeline_audit_levels_id_seq'::regclass);


--
-- Name: app_timeline_audits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_timeline_audits ALTER COLUMN id SET DEFAULT nextval('public.app_timeline_audits_id_seq'::regclass);


--
-- Name: app_timeline_behavior_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_timeline_behavior_events ALTER COLUMN id SET DEFAULT nextval('public.app_timeline_behavior_events_id_seq'::regclass);


--
-- Name: app_timeline_behavior_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_timeline_behavior_levels ALTER COLUMN id SET DEFAULT nextval('public.app_timeline_behavior_levels_id_seq'::regclass);


--
-- Name: app_timeline_behaviors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_timeline_behaviors ALTER COLUMN id SET DEFAULT nextval('public.app_timeline_behaviors_id_seq'::regclass);


--
-- Name: chronicle_outbox_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chronicle_outbox_entries ALTER COLUMN id SET DEFAULT nextval('public.chronicle_outbox_entries_id_seq'::regclass);


--
-- Name: chronicle_retention_policies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chronicle_retention_policies ALTER COLUMN id SET DEFAULT nextval('public.chronicle_retention_policies_id_seq'::regclass);


--
-- Name: chronicle_visibilities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chronicle_visibilities ALTER COLUMN id SET DEFAULT nextval('public.chronicle_visibilities_id_seq'::regclass);


--
-- Name: chronicle_visibility_contexts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chronicle_visibility_contexts ALTER COLUMN id SET DEFAULT nextval('public.chronicle_visibility_contexts_id_seq'::regclass);


--
-- Name: chronicles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chronicles ALTER COLUMN id SET DEFAULT nextval('public.chronicles_id_seq'::regclass);


--
-- Name: client_chronicle_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_chronicle_events ALTER COLUMN id SET DEFAULT nextval('public.client_chronicle_events_id_seq'::regclass);


--
-- Name: client_chronicle_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_chronicle_levels ALTER COLUMN id SET DEFAULT nextval('public.client_chronicle_levels_id_seq'::regclass);


--
-- Name: client_chronicles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_chronicles ALTER COLUMN id SET DEFAULT nextval('public.client_chronicles_id_seq'::regclass);


--
-- Name: com_document_audit_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_document_audit_events ALTER COLUMN id SET DEFAULT nextval('public.com_document_audit_events_id_seq'::regclass);


--
-- Name: com_document_audit_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_document_audit_levels ALTER COLUMN id SET DEFAULT nextval('public.com_document_audit_levels_id_seq'::regclass);


--
-- Name: com_document_audits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_document_audits ALTER COLUMN id SET DEFAULT nextval('public.com_document_audits_id_seq'::regclass);


--
-- Name: com_document_behavior_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_document_behavior_events ALTER COLUMN id SET DEFAULT nextval('public.com_document_behavior_events_id_seq'::regclass);


--
-- Name: com_document_behavior_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_document_behavior_levels ALTER COLUMN id SET DEFAULT nextval('public.com_document_behavior_levels_id_seq'::regclass);


--
-- Name: com_document_behaviors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_document_behaviors ALTER COLUMN id SET DEFAULT nextval('public.com_document_behaviors_id_seq'::regclass);


--
-- Name: com_preference_chronicle_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_preference_chronicle_events ALTER COLUMN id SET DEFAULT nextval('public.com_preference_chronicle_events_id_seq'::regclass);


--
-- Name: com_preference_chronicle_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_preference_chronicle_levels ALTER COLUMN id SET DEFAULT nextval('public.com_preference_chronicle_levels_id_seq'::regclass);


--
-- Name: com_preference_chronicles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_preference_chronicles ALTER COLUMN id SET DEFAULT nextval('public.com_preference_chronicles_id_seq'::regclass);


--
-- Name: com_timeline_audit_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_timeline_audit_events ALTER COLUMN id SET DEFAULT nextval('public.com_timeline_audit_events_id_seq'::regclass);


--
-- Name: com_timeline_audit_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_timeline_audit_levels ALTER COLUMN id SET DEFAULT nextval('public.com_timeline_audit_levels_id_seq'::regclass);


--
-- Name: com_timeline_audits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_timeline_audits ALTER COLUMN id SET DEFAULT nextval('public.com_timeline_audits_id_seq'::regclass);


--
-- Name: com_timeline_behavior_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_timeline_behavior_events ALTER COLUMN id SET DEFAULT nextval('public.com_timeline_behavior_events_id_seq'::regclass);


--
-- Name: com_timeline_behavior_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_timeline_behavior_levels ALTER COLUMN id SET DEFAULT nextval('public.com_timeline_behavior_levels_id_seq'::regclass);


--
-- Name: com_timeline_behaviors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_timeline_behaviors ALTER COLUMN id SET DEFAULT nextval('public.com_timeline_behaviors_id_seq'::regclass);


--
-- Name: enforcement_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enforcement_events ALTER COLUMN id SET DEFAULT nextval('public.enforcement_events_id_seq'::regclass);


--
-- Name: operator_chronicle_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_chronicle_events ALTER COLUMN id SET DEFAULT nextval('public.operator_chronicle_events_id_seq'::regclass);


--
-- Name: operator_chronicle_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_chronicle_levels ALTER COLUMN id SET DEFAULT nextval('public.operator_chronicle_levels_id_seq'::regclass);


--
-- Name: operator_chronicles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_chronicles ALTER COLUMN id SET DEFAULT nextval('public.operator_chronicles_id_seq'::regclass);


--
-- Name: org_document_audit_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_document_audit_events ALTER COLUMN id SET DEFAULT nextval('public.org_document_audit_events_id_seq'::regclass);


--
-- Name: org_document_audit_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_document_audit_levels ALTER COLUMN id SET DEFAULT nextval('public.org_document_audit_levels_id_seq'::regclass);


--
-- Name: org_document_audits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_document_audits ALTER COLUMN id SET DEFAULT nextval('public.org_document_audits_id_seq'::regclass);


--
-- Name: org_document_behavior_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_document_behavior_events ALTER COLUMN id SET DEFAULT nextval('public.org_document_behavior_events_id_seq'::regclass);


--
-- Name: org_document_behavior_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_document_behavior_levels ALTER COLUMN id SET DEFAULT nextval('public.org_document_behavior_levels_id_seq'::regclass);


--
-- Name: org_document_behaviors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_document_behaviors ALTER COLUMN id SET DEFAULT nextval('public.org_document_behaviors_id_seq'::regclass);


--
-- Name: org_preference_chronicle_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_chronicle_events ALTER COLUMN id SET DEFAULT nextval('public.org_preference_chronicle_events_id_seq'::regclass);


--
-- Name: org_preference_chronicle_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_chronicle_levels ALTER COLUMN id SET DEFAULT nextval('public.org_preference_chronicle_levels_id_seq'::regclass);


--
-- Name: org_preference_chronicles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_chronicles ALTER COLUMN id SET DEFAULT nextval('public.org_preference_chronicles_id_seq'::regclass);


--
-- Name: org_timeline_audit_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_timeline_audit_events ALTER COLUMN id SET DEFAULT nextval('public.org_timeline_audit_events_id_seq'::regclass);


--
-- Name: org_timeline_audit_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_timeline_audit_levels ALTER COLUMN id SET DEFAULT nextval('public.org_timeline_audit_levels_id_seq'::regclass);


--
-- Name: org_timeline_audits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_timeline_audits ALTER COLUMN id SET DEFAULT nextval('public.org_timeline_audits_id_seq'::regclass);


--
-- Name: org_timeline_behavior_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_timeline_behavior_events ALTER COLUMN id SET DEFAULT nextval('public.org_timeline_behavior_events_id_seq'::regclass);


--
-- Name: org_timeline_behavior_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_timeline_behavior_levels ALTER COLUMN id SET DEFAULT nextval('public.org_timeline_behavior_levels_id_seq'::regclass);


--
-- Name: org_timeline_behaviors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_timeline_behaviors ALTER COLUMN id SET DEFAULT nextval('public.org_timeline_behaviors_id_seq'::regclass);


--
-- Name: account_access_events account_access_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_access_events
    ADD CONSTRAINT account_access_events_pkey PRIMARY KEY (id);


--
-- Name: app_document_audit_events app_document_audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_document_audit_events
    ADD CONSTRAINT app_document_audit_events_pkey PRIMARY KEY (id);


--
-- Name: app_document_audit_levels app_document_audit_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_document_audit_levels
    ADD CONSTRAINT app_document_audit_levels_pkey PRIMARY KEY (id);


--
-- Name: app_document_audits app_document_audits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_document_audits
    ADD CONSTRAINT app_document_audits_pkey PRIMARY KEY (id);


--
-- Name: app_document_behavior_events app_document_behavior_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_document_behavior_events
    ADD CONSTRAINT app_document_behavior_events_pkey PRIMARY KEY (id);


--
-- Name: app_document_behavior_levels app_document_behavior_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_document_behavior_levels
    ADD CONSTRAINT app_document_behavior_levels_pkey PRIMARY KEY (id);


--
-- Name: app_document_behaviors app_document_behaviors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_document_behaviors
    ADD CONSTRAINT app_document_behaviors_pkey PRIMARY KEY (id);


--
-- Name: app_preference_chronicle_events app_preference_chronicle_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_preference_chronicle_events
    ADD CONSTRAINT app_preference_chronicle_events_pkey PRIMARY KEY (id);


--
-- Name: app_preference_chronicle_levels app_preference_chronicle_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_preference_chronicle_levels
    ADD CONSTRAINT app_preference_chronicle_levels_pkey PRIMARY KEY (id);


--
-- Name: app_preference_chronicles app_preference_chronicles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_preference_chronicles
    ADD CONSTRAINT app_preference_chronicles_pkey PRIMARY KEY (id);


--
-- Name: app_timeline_audit_events app_timeline_audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_timeline_audit_events
    ADD CONSTRAINT app_timeline_audit_events_pkey PRIMARY KEY (id);


--
-- Name: app_timeline_audit_levels app_timeline_audit_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_timeline_audit_levels
    ADD CONSTRAINT app_timeline_audit_levels_pkey PRIMARY KEY (id);


--
-- Name: app_timeline_audits app_timeline_audits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_timeline_audits
    ADD CONSTRAINT app_timeline_audits_pkey PRIMARY KEY (id);


--
-- Name: app_timeline_behavior_events app_timeline_behavior_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_timeline_behavior_events
    ADD CONSTRAINT app_timeline_behavior_events_pkey PRIMARY KEY (id);


--
-- Name: app_timeline_behavior_levels app_timeline_behavior_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_timeline_behavior_levels
    ADD CONSTRAINT app_timeline_behavior_levels_pkey PRIMARY KEY (id);


--
-- Name: app_timeline_behaviors app_timeline_behaviors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_timeline_behaviors
    ADD CONSTRAINT app_timeline_behaviors_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: chronicle_outbox_entries chronicle_outbox_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chronicle_outbox_entries
    ADD CONSTRAINT chronicle_outbox_entries_pkey PRIMARY KEY (id);


--
-- Name: chronicle_retention_policies chronicle_retention_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chronicle_retention_policies
    ADD CONSTRAINT chronicle_retention_policies_pkey PRIMARY KEY (id);


--
-- Name: chronicle_visibilities chronicle_visibilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chronicle_visibilities
    ADD CONSTRAINT chronicle_visibilities_pkey PRIMARY KEY (id);


--
-- Name: chronicle_visibility_contexts chronicle_visibility_contexts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chronicle_visibility_contexts
    ADD CONSTRAINT chronicle_visibility_contexts_pkey PRIMARY KEY (id);


--
-- Name: chronicles chronicles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chronicles
    ADD CONSTRAINT chronicles_pkey PRIMARY KEY (id);


--
-- Name: client_chronicle_events client_chronicle_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_chronicle_events
    ADD CONSTRAINT client_chronicle_events_pkey PRIMARY KEY (id);


--
-- Name: client_chronicle_levels client_chronicle_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_chronicle_levels
    ADD CONSTRAINT client_chronicle_levels_pkey PRIMARY KEY (id);


--
-- Name: client_chronicles client_chronicles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_chronicles
    ADD CONSTRAINT client_chronicles_pkey PRIMARY KEY (id);


--
-- Name: com_document_audit_events com_document_audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_document_audit_events
    ADD CONSTRAINT com_document_audit_events_pkey PRIMARY KEY (id);


--
-- Name: com_document_audit_levels com_document_audit_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_document_audit_levels
    ADD CONSTRAINT com_document_audit_levels_pkey PRIMARY KEY (id);


--
-- Name: com_document_audits com_document_audits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_document_audits
    ADD CONSTRAINT com_document_audits_pkey PRIMARY KEY (id);


--
-- Name: com_document_behavior_events com_document_behavior_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_document_behavior_events
    ADD CONSTRAINT com_document_behavior_events_pkey PRIMARY KEY (id);


--
-- Name: com_document_behavior_levels com_document_behavior_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_document_behavior_levels
    ADD CONSTRAINT com_document_behavior_levels_pkey PRIMARY KEY (id);


--
-- Name: com_document_behaviors com_document_behaviors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_document_behaviors
    ADD CONSTRAINT com_document_behaviors_pkey PRIMARY KEY (id);


--
-- Name: com_preference_chronicle_events com_preference_chronicle_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_preference_chronicle_events
    ADD CONSTRAINT com_preference_chronicle_events_pkey PRIMARY KEY (id);


--
-- Name: com_preference_chronicle_levels com_preference_chronicle_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_preference_chronicle_levels
    ADD CONSTRAINT com_preference_chronicle_levels_pkey PRIMARY KEY (id);


--
-- Name: com_preference_chronicles com_preference_chronicles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_preference_chronicles
    ADD CONSTRAINT com_preference_chronicles_pkey PRIMARY KEY (id);


--
-- Name: com_timeline_audit_events com_timeline_audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_timeline_audit_events
    ADD CONSTRAINT com_timeline_audit_events_pkey PRIMARY KEY (id);


--
-- Name: com_timeline_audit_levels com_timeline_audit_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_timeline_audit_levels
    ADD CONSTRAINT com_timeline_audit_levels_pkey PRIMARY KEY (id);


--
-- Name: com_timeline_audits com_timeline_audits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_timeline_audits
    ADD CONSTRAINT com_timeline_audits_pkey PRIMARY KEY (id);


--
-- Name: com_timeline_behavior_events com_timeline_behavior_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_timeline_behavior_events
    ADD CONSTRAINT com_timeline_behavior_events_pkey PRIMARY KEY (id);


--
-- Name: com_timeline_behavior_levels com_timeline_behavior_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_timeline_behavior_levels
    ADD CONSTRAINT com_timeline_behavior_levels_pkey PRIMARY KEY (id);


--
-- Name: com_timeline_behaviors com_timeline_behaviors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_timeline_behaviors
    ADD CONSTRAINT com_timeline_behaviors_pkey PRIMARY KEY (id);


--
-- Name: enforcement_events enforcement_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enforcement_events
    ADD CONSTRAINT enforcement_events_pkey PRIMARY KEY (id);


--
-- Name: operator_chronicle_events operator_chronicle_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_chronicle_events
    ADD CONSTRAINT operator_chronicle_events_pkey PRIMARY KEY (id);


--
-- Name: operator_chronicle_levels operator_chronicle_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_chronicle_levels
    ADD CONSTRAINT operator_chronicle_levels_pkey PRIMARY KEY (id);


--
-- Name: operator_chronicles operator_chronicles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_chronicles
    ADD CONSTRAINT operator_chronicles_pkey PRIMARY KEY (id);


--
-- Name: org_document_audit_events org_document_audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_document_audit_events
    ADD CONSTRAINT org_document_audit_events_pkey PRIMARY KEY (id);


--
-- Name: org_document_audit_levels org_document_audit_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_document_audit_levels
    ADD CONSTRAINT org_document_audit_levels_pkey PRIMARY KEY (id);


--
-- Name: org_document_audits org_document_audits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_document_audits
    ADD CONSTRAINT org_document_audits_pkey PRIMARY KEY (id);


--
-- Name: org_document_behavior_events org_document_behavior_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_document_behavior_events
    ADD CONSTRAINT org_document_behavior_events_pkey PRIMARY KEY (id);


--
-- Name: org_document_behavior_levels org_document_behavior_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_document_behavior_levels
    ADD CONSTRAINT org_document_behavior_levels_pkey PRIMARY KEY (id);


--
-- Name: org_document_behaviors org_document_behaviors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_document_behaviors
    ADD CONSTRAINT org_document_behaviors_pkey PRIMARY KEY (id);


--
-- Name: org_preference_chronicle_events org_preference_chronicle_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_chronicle_events
    ADD CONSTRAINT org_preference_chronicle_events_pkey PRIMARY KEY (id);


--
-- Name: org_preference_chronicle_levels org_preference_chronicle_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_chronicle_levels
    ADD CONSTRAINT org_preference_chronicle_levels_pkey PRIMARY KEY (id);


--
-- Name: org_preference_chronicles org_preference_chronicles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_chronicles
    ADD CONSTRAINT org_preference_chronicles_pkey PRIMARY KEY (id);


--
-- Name: org_timeline_audit_events org_timeline_audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_timeline_audit_events
    ADD CONSTRAINT org_timeline_audit_events_pkey PRIMARY KEY (id);


--
-- Name: org_timeline_audit_levels org_timeline_audit_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_timeline_audit_levels
    ADD CONSTRAINT org_timeline_audit_levels_pkey PRIMARY KEY (id);


--
-- Name: org_timeline_audits org_timeline_audits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_timeline_audits
    ADD CONSTRAINT org_timeline_audits_pkey PRIMARY KEY (id);


--
-- Name: org_timeline_behavior_events org_timeline_behavior_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_timeline_behavior_events
    ADD CONSTRAINT org_timeline_behavior_events_pkey PRIMARY KEY (id);


--
-- Name: org_timeline_behavior_levels org_timeline_behavior_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_timeline_behavior_levels
    ADD CONSTRAINT org_timeline_behavior_levels_pkey PRIMARY KEY (id);


--
-- Name: org_timeline_behaviors org_timeline_behaviors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_timeline_behaviors
    ADD CONSTRAINT org_timeline_behaviors_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: idx_chronicle_visibilities_unique_context; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_chronicle_visibilities_unique_context ON public.chronicle_visibilities USING btree (chronicle_id, chronicle_visibility_context_id);


--
-- Name: idx_enforcement_events_case; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_enforcement_events_case ON public.enforcement_events USING btree (realm, case_public_id, occurred_at);


--
-- Name: idx_enforcement_events_principal; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_enforcement_events_principal ON public.enforcement_events USING btree (realm, principal_public_id, occurred_at);


--
-- Name: idx_on_account_type_account_id_occurred_at_950619886b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_account_type_account_id_occurred_at_950619886b ON public.account_access_events USING btree (account_type, account_id, occurred_at);


--
-- Name: idx_on_chronicle_visibility_context_id_2c36ec5eab; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_chronicle_visibility_context_id_2c36ec5eab ON public.chronicle_visibilities USING btree (chronicle_visibility_context_id);


--
-- Name: idx_on_subject_type_subject_id_occurred_at_0f4341deba; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_subject_type_subject_id_occurred_at_0f4341deba ON public.org_timeline_audits USING btree (subject_type, subject_id, occurred_at);


--
-- Name: idx_on_subject_type_subject_id_occurred_at_2e96c29236; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_subject_type_subject_id_occurred_at_2e96c29236 ON public.operator_chronicles USING btree (subject_type, subject_id, occurred_at);


--
-- Name: idx_on_subject_type_subject_id_occurred_at_99ec847a5c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_subject_type_subject_id_occurred_at_99ec847a5c ON public.com_timeline_audits USING btree (subject_type, subject_id, occurred_at);


--
-- Name: idx_on_subject_type_subject_id_occurred_at_a29eb711dd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_subject_type_subject_id_occurred_at_a29eb711dd ON public.client_chronicles USING btree (subject_type, subject_id, occurred_at);


--
-- Name: idx_on_subject_type_subject_id_occurred_at_app_pref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_subject_type_subject_id_occurred_at_app_pref ON public.app_preference_chronicles USING btree (subject_type, subject_id, occurred_at);


--
-- Name: idx_on_subject_type_subject_id_occurred_at_bf53171ad0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_subject_type_subject_id_occurred_at_bf53171ad0 ON public.org_document_audits USING btree (subject_type, subject_id, occurred_at);


--
-- Name: idx_on_subject_type_subject_id_occurred_at_c40361e81b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_subject_type_subject_id_occurred_at_c40361e81b ON public.com_document_audits USING btree (subject_type, subject_id, occurred_at);


--
-- Name: idx_on_subject_type_subject_id_occurred_at_c80b4e4f83; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_subject_type_subject_id_occurred_at_c80b4e4f83 ON public.app_timeline_audits USING btree (subject_type, subject_id, occurred_at);


--
-- Name: idx_on_subject_type_subject_id_occurred_at_cf1fa79ee4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_subject_type_subject_id_occurred_at_cf1fa79ee4 ON public.app_document_audits USING btree (subject_type, subject_id, occurred_at);


--
-- Name: idx_on_subject_type_subject_id_occurred_at_com_pref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_subject_type_subject_id_occurred_at_com_pref ON public.com_preference_chronicles USING btree (subject_type, subject_id, occurred_at);


--
-- Name: idx_on_subject_type_subject_id_occurred_at_org_pref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_subject_type_subject_id_occurred_at_org_pref ON public.org_preference_chronicles USING btree (subject_type, subject_id, occurred_at);


--
-- Name: index_account_access_events_on_event_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_account_access_events_on_event_type ON public.account_access_events USING btree (event_type);


--
-- Name: index_account_access_events_on_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_account_access_events_on_operator_id ON public.account_access_events USING btree (operator_id);


--
-- Name: index_account_access_events_on_reason_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_account_access_events_on_reason_code ON public.account_access_events USING btree (reason_code);


--
-- Name: index_account_access_events_on_ticket_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_account_access_events_on_ticket_id ON public.account_access_events USING btree (ticket_id);


--
-- Name: index_app_document_audits_on_actor_id_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_document_audits_on_actor_id_and_occurred_at ON public.app_document_audits USING btree (actor_id, occurred_at);


--
-- Name: index_app_document_audits_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_document_audits_on_event_id ON public.app_document_audits USING btree (event_id);


--
-- Name: index_app_document_audits_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_document_audits_on_expires_at ON public.app_document_audits USING btree (expires_at);


--
-- Name: index_app_document_audits_on_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_document_audits_on_level_id ON public.app_document_audits USING btree (level_id);


--
-- Name: index_app_document_audits_on_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_document_audits_on_occurred_at ON public.app_document_audits USING btree (occurred_at);


--
-- Name: index_app_document_audits_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_document_audits_on_subject_id ON public.app_document_audits USING btree (subject_id);


--
-- Name: index_app_document_behaviors_on_actor_type_and_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_document_behaviors_on_actor_type_and_actor_id ON public.app_document_behaviors USING btree (actor_type, actor_id);


--
-- Name: index_app_document_behaviors_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_document_behaviors_on_event_id ON public.app_document_behaviors USING btree (event_id);


--
-- Name: index_app_document_behaviors_on_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_document_behaviors_on_level_id ON public.app_document_behaviors USING btree (level_id);


--
-- Name: index_app_document_behaviors_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_document_behaviors_on_subject_id ON public.app_document_behaviors USING btree (subject_id);


--
-- Name: index_app_document_behaviors_on_subject_type_and_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_document_behaviors_on_subject_type_and_subject_id ON public.app_document_behaviors USING btree (subject_type, subject_id);


--
-- Name: index_app_preference_chronicles_on_actor_id_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_preference_chronicles_on_actor_id_and_occurred_at ON public.app_preference_chronicles USING btree (actor_id, occurred_at);


--
-- Name: index_app_preference_chronicles_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_preference_chronicles_on_event_id ON public.app_preference_chronicles USING btree (event_id);


--
-- Name: index_app_preference_chronicles_on_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_preference_chronicles_on_level_id ON public.app_preference_chronicles USING btree (level_id);


--
-- Name: index_app_preference_chronicles_on_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_preference_chronicles_on_occurred_at ON public.app_preference_chronicles USING btree (occurred_at);


--
-- Name: index_app_preference_chronicles_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_preference_chronicles_on_purge_eligible_at ON public.app_preference_chronicles USING btree (purge_eligible_at);


--
-- Name: index_app_preference_chronicles_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_preference_chronicles_on_subject_id ON public.app_preference_chronicles USING btree (subject_id);


--
-- Name: index_app_timeline_audits_on_actor_id_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_timeline_audits_on_actor_id_and_occurred_at ON public.app_timeline_audits USING btree (actor_id, occurred_at);


--
-- Name: index_app_timeline_audits_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_timeline_audits_on_event_id ON public.app_timeline_audits USING btree (event_id);


--
-- Name: index_app_timeline_audits_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_timeline_audits_on_expires_at ON public.app_timeline_audits USING btree (expires_at);


--
-- Name: index_app_timeline_audits_on_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_timeline_audits_on_level_id ON public.app_timeline_audits USING btree (level_id);


--
-- Name: index_app_timeline_audits_on_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_timeline_audits_on_occurred_at ON public.app_timeline_audits USING btree (occurred_at);


--
-- Name: index_app_timeline_audits_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_timeline_audits_on_subject_id ON public.app_timeline_audits USING btree (subject_id);


--
-- Name: index_app_timeline_behaviors_on_actor_type_and_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_timeline_behaviors_on_actor_type_and_actor_id ON public.app_timeline_behaviors USING btree (actor_type, actor_id);


--
-- Name: index_app_timeline_behaviors_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_timeline_behaviors_on_event_id ON public.app_timeline_behaviors USING btree (event_id);


--
-- Name: index_app_timeline_behaviors_on_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_timeline_behaviors_on_level_id ON public.app_timeline_behaviors USING btree (level_id);


--
-- Name: index_app_timeline_behaviors_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_timeline_behaviors_on_subject_id ON public.app_timeline_behaviors USING btree (subject_id);


--
-- Name: index_app_timeline_behaviors_on_subject_type_and_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_timeline_behaviors_on_subject_type_and_subject_id ON public.app_timeline_behaviors USING btree (subject_type, subject_id);


--
-- Name: index_chronicle_outbox_entries_on_chronicle_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chronicle_outbox_entries_on_chronicle_id ON public.chronicle_outbox_entries USING btree (chronicle_id);


--
-- Name: index_chronicle_outbox_entries_on_event_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chronicle_outbox_entries_on_event_uuid ON public.chronicle_outbox_entries USING btree (event_uuid);


--
-- Name: index_chronicle_outbox_entries_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chronicle_outbox_entries_on_status ON public.chronicle_outbox_entries USING btree (status);


--
-- Name: index_chronicle_retention_policies_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chronicle_retention_policies_on_code ON public.chronicle_retention_policies USING btree (code);


--
-- Name: index_chronicle_visibility_contexts_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chronicle_visibility_contexts_on_code ON public.chronicle_visibility_contexts USING btree (code);


--
-- Name: index_chronicles_on_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chronicles_on_action ON public.chronicles USING btree (action);


--
-- Name: index_chronicles_on_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chronicles_on_actor ON public.chronicles USING btree (actor_type, actor_id);


--
-- Name: index_chronicles_on_chronicle_retention_policy_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chronicles_on_chronicle_retention_policy_id ON public.chronicles USING btree (chronicle_retention_policy_id);


--
-- Name: index_chronicles_on_erasable_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chronicles_on_erasable_at ON public.chronicles USING btree (erasable_at);


--
-- Name: index_chronicles_on_event_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chronicles_on_event_uuid ON public.chronicles USING btree (event_uuid);


--
-- Name: index_chronicles_on_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chronicles_on_occurred_at ON public.chronicles USING btree (occurred_at);


--
-- Name: index_chronicles_on_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chronicles_on_request_id ON public.chronicles USING btree (request_id);


--
-- Name: index_chronicles_on_result; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chronicles_on_result ON public.chronicles USING btree (result);


--
-- Name: index_chronicles_on_subject; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chronicles_on_subject ON public.chronicles USING btree (subject_type, subject_id);


--
-- Name: index_client_chronicles_on_actor_id_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_chronicles_on_actor_id_and_occurred_at ON public.client_chronicles USING btree (actor_id, occurred_at);


--
-- Name: index_client_chronicles_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_chronicles_on_event_id ON public.client_chronicles USING btree (event_id);


--
-- Name: index_client_chronicles_on_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_chronicles_on_level_id ON public.client_chronicles USING btree (level_id);


--
-- Name: index_client_chronicles_on_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_chronicles_on_occurred_at ON public.client_chronicles USING btree (occurred_at);


--
-- Name: index_client_chronicles_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_chronicles_on_purge_eligible_at ON public.client_chronicles USING btree (purge_eligible_at);


--
-- Name: index_client_chronicles_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_chronicles_on_subject_id ON public.client_chronicles USING btree (subject_id);


--
-- Name: index_com_document_audits_on_actor_id_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_document_audits_on_actor_id_and_occurred_at ON public.com_document_audits USING btree (actor_id, occurred_at);


--
-- Name: index_com_document_audits_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_document_audits_on_event_id ON public.com_document_audits USING btree (event_id);


--
-- Name: index_com_document_audits_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_document_audits_on_expires_at ON public.com_document_audits USING btree (expires_at);


--
-- Name: index_com_document_audits_on_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_document_audits_on_level_id ON public.com_document_audits USING btree (level_id);


--
-- Name: index_com_document_audits_on_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_document_audits_on_occurred_at ON public.com_document_audits USING btree (occurred_at);


--
-- Name: index_com_document_audits_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_document_audits_on_subject_id ON public.com_document_audits USING btree (subject_id);


--
-- Name: index_com_document_behaviors_on_actor_type_and_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_document_behaviors_on_actor_type_and_actor_id ON public.com_document_behaviors USING btree (actor_type, actor_id);


--
-- Name: index_com_document_behaviors_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_document_behaviors_on_event_id ON public.com_document_behaviors USING btree (event_id);


--
-- Name: index_com_document_behaviors_on_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_document_behaviors_on_level_id ON public.com_document_behaviors USING btree (level_id);


--
-- Name: index_com_document_behaviors_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_document_behaviors_on_subject_id ON public.com_document_behaviors USING btree (subject_id);


--
-- Name: index_com_document_behaviors_on_subject_type_and_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_document_behaviors_on_subject_type_and_subject_id ON public.com_document_behaviors USING btree (subject_type, subject_id);


--
-- Name: index_com_preference_chronicles_on_actor_id_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_preference_chronicles_on_actor_id_and_occurred_at ON public.com_preference_chronicles USING btree (actor_id, occurred_at);


--
-- Name: index_com_preference_chronicles_on_actor_type_and_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_preference_chronicles_on_actor_type_and_actor_id ON public.com_preference_chronicles USING btree (actor_type, actor_id);


--
-- Name: index_com_preference_chronicles_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_preference_chronicles_on_event_id ON public.com_preference_chronicles USING btree (event_id);


--
-- Name: index_com_preference_chronicles_on_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_preference_chronicles_on_level_id ON public.com_preference_chronicles USING btree (level_id);


--
-- Name: index_com_preference_chronicles_on_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_preference_chronicles_on_occurred_at ON public.com_preference_chronicles USING btree (occurred_at);


--
-- Name: index_com_preference_chronicles_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_preference_chronicles_on_purge_eligible_at ON public.com_preference_chronicles USING btree (purge_eligible_at);


--
-- Name: index_com_preference_chronicles_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_preference_chronicles_on_subject_id ON public.com_preference_chronicles USING btree (subject_id);


--
-- Name: index_com_timeline_audits_on_actor_id_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_timeline_audits_on_actor_id_and_occurred_at ON public.com_timeline_audits USING btree (actor_id, occurred_at);


--
-- Name: index_com_timeline_audits_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_timeline_audits_on_event_id ON public.com_timeline_audits USING btree (event_id);


--
-- Name: index_com_timeline_audits_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_timeline_audits_on_expires_at ON public.com_timeline_audits USING btree (expires_at);


--
-- Name: index_com_timeline_audits_on_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_timeline_audits_on_level_id ON public.com_timeline_audits USING btree (level_id);


--
-- Name: index_com_timeline_audits_on_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_timeline_audits_on_occurred_at ON public.com_timeline_audits USING btree (occurred_at);


--
-- Name: index_com_timeline_audits_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_timeline_audits_on_subject_id ON public.com_timeline_audits USING btree (subject_id);


--
-- Name: index_com_timeline_behaviors_on_actor_type_and_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_timeline_behaviors_on_actor_type_and_actor_id ON public.com_timeline_behaviors USING btree (actor_type, actor_id);


--
-- Name: index_com_timeline_behaviors_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_timeline_behaviors_on_event_id ON public.com_timeline_behaviors USING btree (event_id);


--
-- Name: index_com_timeline_behaviors_on_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_timeline_behaviors_on_level_id ON public.com_timeline_behaviors USING btree (level_id);


--
-- Name: index_com_timeline_behaviors_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_timeline_behaviors_on_subject_id ON public.com_timeline_behaviors USING btree (subject_id);


--
-- Name: index_com_timeline_behaviors_on_subject_type_and_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_timeline_behaviors_on_subject_type_and_subject_id ON public.com_timeline_behaviors USING btree (subject_type, subject_id);


--
-- Name: index_enforcement_events_on_event_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_enforcement_events_on_event_type ON public.enforcement_events USING btree (event_type);


--
-- Name: index_operator_chronicles_on_actor_id_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_chronicles_on_actor_id_and_occurred_at ON public.operator_chronicles USING btree (actor_id, occurred_at);


--
-- Name: index_operator_chronicles_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_chronicles_on_event_id ON public.operator_chronicles USING btree (event_id);


--
-- Name: index_operator_chronicles_on_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_chronicles_on_level_id ON public.operator_chronicles USING btree (level_id);


--
-- Name: index_operator_chronicles_on_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_chronicles_on_occurred_at ON public.operator_chronicles USING btree (occurred_at);


--
-- Name: index_operator_chronicles_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_chronicles_on_purge_eligible_at ON public.operator_chronicles USING btree (purge_eligible_at);


--
-- Name: index_operator_chronicles_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_chronicles_on_subject_id ON public.operator_chronicles USING btree (subject_id);


--
-- Name: index_org_document_audits_on_actor_id_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_document_audits_on_actor_id_and_occurred_at ON public.org_document_audits USING btree (actor_id, occurred_at);


--
-- Name: index_org_document_audits_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_document_audits_on_event_id ON public.org_document_audits USING btree (event_id);


--
-- Name: index_org_document_audits_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_document_audits_on_expires_at ON public.org_document_audits USING btree (expires_at);


--
-- Name: index_org_document_audits_on_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_document_audits_on_level_id ON public.org_document_audits USING btree (level_id);


--
-- Name: index_org_document_audits_on_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_document_audits_on_occurred_at ON public.org_document_audits USING btree (occurred_at);


--
-- Name: index_org_document_audits_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_document_audits_on_subject_id ON public.org_document_audits USING btree (subject_id);


--
-- Name: index_org_document_behaviors_on_actor_type_and_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_document_behaviors_on_actor_type_and_actor_id ON public.org_document_behaviors USING btree (actor_type, actor_id);


--
-- Name: index_org_document_behaviors_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_document_behaviors_on_event_id ON public.org_document_behaviors USING btree (event_id);


--
-- Name: index_org_document_behaviors_on_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_document_behaviors_on_level_id ON public.org_document_behaviors USING btree (level_id);


--
-- Name: index_org_document_behaviors_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_document_behaviors_on_subject_id ON public.org_document_behaviors USING btree (subject_id);


--
-- Name: index_org_document_behaviors_on_subject_type_and_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_document_behaviors_on_subject_type_and_subject_id ON public.org_document_behaviors USING btree (subject_type, subject_id);


--
-- Name: index_org_preference_chronicles_on_actor_id_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preference_chronicles_on_actor_id_and_occurred_at ON public.org_preference_chronicles USING btree (actor_id, occurred_at);


--
-- Name: index_org_preference_chronicles_on_actor_type_and_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preference_chronicles_on_actor_type_and_actor_id ON public.org_preference_chronicles USING btree (actor_type, actor_id);


--
-- Name: index_org_preference_chronicles_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preference_chronicles_on_event_id ON public.org_preference_chronicles USING btree (event_id);


--
-- Name: index_org_preference_chronicles_on_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preference_chronicles_on_level_id ON public.org_preference_chronicles USING btree (level_id);


--
-- Name: index_org_preference_chronicles_on_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preference_chronicles_on_occurred_at ON public.org_preference_chronicles USING btree (occurred_at);


--
-- Name: index_org_preference_chronicles_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preference_chronicles_on_purge_eligible_at ON public.org_preference_chronicles USING btree (purge_eligible_at);


--
-- Name: index_org_preference_chronicles_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_preference_chronicles_on_subject_id ON public.org_preference_chronicles USING btree (subject_id);


--
-- Name: index_org_timeline_audits_on_actor_id_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_timeline_audits_on_actor_id_and_occurred_at ON public.org_timeline_audits USING btree (actor_id, occurred_at);


--
-- Name: index_org_timeline_audits_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_timeline_audits_on_event_id ON public.org_timeline_audits USING btree (event_id);


--
-- Name: index_org_timeline_audits_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_timeline_audits_on_expires_at ON public.org_timeline_audits USING btree (expires_at);


--
-- Name: index_org_timeline_audits_on_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_timeline_audits_on_level_id ON public.org_timeline_audits USING btree (level_id);


--
-- Name: index_org_timeline_audits_on_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_timeline_audits_on_occurred_at ON public.org_timeline_audits USING btree (occurred_at);


--
-- Name: index_org_timeline_audits_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_timeline_audits_on_subject_id ON public.org_timeline_audits USING btree (subject_id);


--
-- Name: index_org_timeline_behaviors_on_actor_type_and_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_timeline_behaviors_on_actor_type_and_actor_id ON public.org_timeline_behaviors USING btree (actor_type, actor_id);


--
-- Name: index_org_timeline_behaviors_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_timeline_behaviors_on_event_id ON public.org_timeline_behaviors USING btree (event_id);


--
-- Name: index_org_timeline_behaviors_on_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_timeline_behaviors_on_level_id ON public.org_timeline_behaviors USING btree (level_id);


--
-- Name: index_org_timeline_behaviors_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_timeline_behaviors_on_subject_id ON public.org_timeline_behaviors USING btree (subject_id);


--
-- Name: index_org_timeline_behaviors_on_subject_type_and_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_timeline_behaviors_on_subject_type_and_subject_id ON public.org_timeline_behaviors USING btree (subject_type, subject_id);


--
-- Name: index_staff_activities_on_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_activities_on_actor ON public.operator_chronicles USING btree (actor_type, actor_id);


--
-- Name: index_user_activities_on_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_activities_on_actor ON public.client_chronicles USING btree (actor_type, actor_id);


--
-- Name: app_document_audits fk_rails_04199ae3cc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_document_audits
    ADD CONSTRAINT fk_rails_04199ae3cc FOREIGN KEY (event_id) REFERENCES public.app_document_audit_events(id) NOT VALID;


--
-- Name: com_document_behaviors fk_rails_0ed5a466f6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_document_behaviors
    ADD CONSTRAINT fk_rails_0ed5a466f6 FOREIGN KEY (level_id) REFERENCES public.com_document_behavior_levels(id);


--
-- Name: app_timeline_behaviors fk_rails_19991f7b36; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_timeline_behaviors
    ADD CONSTRAINT fk_rails_19991f7b36 FOREIGN KEY (level_id) REFERENCES public.app_timeline_behavior_levels(id);


--
-- Name: org_timeline_audits fk_rails_1c8eb96fbb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_timeline_audits
    ADD CONSTRAINT fk_rails_1c8eb96fbb FOREIGN KEY (level_id) REFERENCES public.org_timeline_audit_levels(id) NOT VALID;


--
-- Name: org_document_behaviors fk_rails_288dcc9464; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_document_behaviors
    ADD CONSTRAINT fk_rails_288dcc9464 FOREIGN KEY (level_id) REFERENCES public.org_document_behavior_levels(id);


--
-- Name: app_timeline_audits fk_rails_2babaf0d7d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_timeline_audits
    ADD CONSTRAINT fk_rails_2babaf0d7d FOREIGN KEY (event_id) REFERENCES public.app_timeline_audit_events(id) NOT VALID;


--
-- Name: com_timeline_behaviors fk_rails_30821c7e45; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_timeline_behaviors
    ADD CONSTRAINT fk_rails_30821c7e45 FOREIGN KEY (event_id) REFERENCES public.com_timeline_behavior_events(id);


--
-- Name: org_preference_chronicles fk_rails_3829eb3d72; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_chronicles
    ADD CONSTRAINT fk_rails_3829eb3d72 FOREIGN KEY (event_id) REFERENCES public.org_preference_chronicle_events(id) NOT VALID;


--
-- Name: chronicle_visibilities fk_rails_3e7ddcf87e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chronicle_visibilities
    ADD CONSTRAINT fk_rails_3e7ddcf87e FOREIGN KEY (chronicle_id) REFERENCES public.chronicles(id);


--
-- Name: com_document_audits fk_rails_3f934103f6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_document_audits
    ADD CONSTRAINT fk_rails_3f934103f6 FOREIGN KEY (event_id) REFERENCES public.com_document_audit_events(id) NOT VALID;


--
-- Name: operator_chronicles fk_rails_46a8075569; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_chronicles
    ADD CONSTRAINT fk_rails_46a8075569 FOREIGN KEY (level_id) REFERENCES public.operator_chronicle_levels(id) NOT VALID;


--
-- Name: org_document_audits fk_rails_46d3b866ce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_document_audits
    ADD CONSTRAINT fk_rails_46d3b866ce FOREIGN KEY (event_id) REFERENCES public.org_document_audit_events(id) NOT VALID;


--
-- Name: chronicle_visibilities fk_rails_57c2fcf0ed; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chronicle_visibilities
    ADD CONSTRAINT fk_rails_57c2fcf0ed FOREIGN KEY (chronicle_visibility_context_id) REFERENCES public.chronicle_visibility_contexts(id);


--
-- Name: com_preference_chronicles fk_rails_592279f49b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_preference_chronicles
    ADD CONSTRAINT fk_rails_592279f49b FOREIGN KEY (level_id) REFERENCES public.com_preference_chronicle_levels(id) NOT VALID;


--
-- Name: com_timeline_audits fk_rails_683656739c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_timeline_audits
    ADD CONSTRAINT fk_rails_683656739c FOREIGN KEY (level_id) REFERENCES public.com_timeline_audit_levels(id) NOT VALID;


--
-- Name: chronicle_outbox_entries fk_rails_6a19517853; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chronicle_outbox_entries
    ADD CONSTRAINT fk_rails_6a19517853 FOREIGN KEY (chronicle_id) REFERENCES public.chronicles(id) ON DELETE SET NULL NOT VALID;


--
-- Name: org_timeline_behaviors fk_rails_749b22f756; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_timeline_behaviors
    ADD CONSTRAINT fk_rails_749b22f756 FOREIGN KEY (event_id) REFERENCES public.org_timeline_behavior_events(id);


--
-- Name: com_timeline_audits fk_rails_7c9a165758; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_timeline_audits
    ADD CONSTRAINT fk_rails_7c9a165758 FOREIGN KEY (event_id) REFERENCES public.com_timeline_audit_events(id) NOT VALID;


--
-- Name: client_chronicles fk_rails_829f1830de; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_chronicles
    ADD CONSTRAINT fk_rails_829f1830de FOREIGN KEY (event_id) REFERENCES public.client_chronicle_events(id) NOT VALID;


--
-- Name: com_document_audits fk_rails_851991baee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_document_audits
    ADD CONSTRAINT fk_rails_851991baee FOREIGN KEY (level_id) REFERENCES public.com_document_audit_levels(id) NOT VALID;


--
-- Name: client_chronicles fk_rails_868bedb021; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_chronicles
    ADD CONSTRAINT fk_rails_868bedb021 FOREIGN KEY (level_id) REFERENCES public.client_chronicle_levels(id) NOT VALID;


--
-- Name: app_document_behaviors fk_rails_8f4da9671d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_document_behaviors
    ADD CONSTRAINT fk_rails_8f4da9671d FOREIGN KEY (event_id) REFERENCES public.app_document_behavior_events(id);


--
-- Name: org_timeline_behaviors fk_rails_9ad9b7635f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_timeline_behaviors
    ADD CONSTRAINT fk_rails_9ad9b7635f FOREIGN KEY (level_id) REFERENCES public.org_timeline_behavior_levels(id);


--
-- Name: app_document_behaviors fk_rails_9d9b9db480; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_document_behaviors
    ADD CONSTRAINT fk_rails_9d9b9db480 FOREIGN KEY (level_id) REFERENCES public.app_document_behavior_levels(id);


--
-- Name: org_document_behaviors fk_rails_a761e3972e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_document_behaviors
    ADD CONSTRAINT fk_rails_a761e3972e FOREIGN KEY (event_id) REFERENCES public.org_document_behavior_events(id);


--
-- Name: app_document_audits fk_rails_a9e9b70220; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_document_audits
    ADD CONSTRAINT fk_rails_a9e9b70220 FOREIGN KEY (level_id) REFERENCES public.app_document_audit_levels(id) NOT VALID;


--
-- Name: app_timeline_audits fk_rails_b95cff528f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_timeline_audits
    ADD CONSTRAINT fk_rails_b95cff528f FOREIGN KEY (level_id) REFERENCES public.app_timeline_audit_levels(id) NOT VALID;


--
-- Name: com_preference_chronicles fk_rails_c194bd8de2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_preference_chronicles
    ADD CONSTRAINT fk_rails_c194bd8de2 FOREIGN KEY (event_id) REFERENCES public.com_preference_chronicle_events(id) NOT VALID;


--
-- Name: com_timeline_behaviors fk_rails_d2b5cbb977; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_timeline_behaviors
    ADD CONSTRAINT fk_rails_d2b5cbb977 FOREIGN KEY (level_id) REFERENCES public.com_timeline_behavior_levels(id);


--
-- Name: app_preference_chronicles fk_rails_d693b46c45; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_preference_chronicles
    ADD CONSTRAINT fk_rails_d693b46c45 FOREIGN KEY (event_id) REFERENCES public.app_preference_chronicle_events(id) NOT VALID;


--
-- Name: app_preference_chronicles fk_rails_da47dd8941; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_preference_chronicles
    ADD CONSTRAINT fk_rails_da47dd8941 FOREIGN KEY (level_id) REFERENCES public.app_preference_chronicle_levels(id) NOT VALID;


--
-- Name: com_document_behaviors fk_rails_e0b73c346a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_document_behaviors
    ADD CONSTRAINT fk_rails_e0b73c346a FOREIGN KEY (event_id) REFERENCES public.com_document_behavior_events(id);


--
-- Name: app_timeline_behaviors fk_rails_e44b3a8da7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_timeline_behaviors
    ADD CONSTRAINT fk_rails_e44b3a8da7 FOREIGN KEY (event_id) REFERENCES public.app_timeline_behavior_events(id);


--
-- Name: org_timeline_audits fk_rails_eae8a241e3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_timeline_audits
    ADD CONSTRAINT fk_rails_eae8a241e3 FOREIGN KEY (event_id) REFERENCES public.org_timeline_audit_events(id) NOT VALID;


--
-- Name: org_document_audits fk_rails_ed52fec6a9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_document_audits
    ADD CONSTRAINT fk_rails_ed52fec6a9 FOREIGN KEY (level_id) REFERENCES public.org_document_audit_levels(id) NOT VALID;


--
-- Name: operator_chronicles fk_rails_f0451c267b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_chronicles
    ADD CONSTRAINT fk_rails_f0451c267b FOREIGN KEY (event_id) REFERENCES public.operator_chronicle_events(id) NOT VALID;


--
-- Name: chronicles fk_rails_f411613567; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chronicles
    ADD CONSTRAINT fk_rails_f411613567 FOREIGN KEY (chronicle_retention_policy_id) REFERENCES public.chronicle_retention_policies(id);


--
-- Name: org_preference_chronicles fk_rails_f932dbadd7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_preference_chronicles
    ADD CONSTRAINT fk_rails_f932dbadd7 FOREIGN KEY (level_id) REFERENCES public.org_preference_chronicle_levels(id) NOT VALID;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260926130000'),
('20260921133000'),
('20260727130000'),
('20260616150020'),
('20260616150010'),
('20260616150004'),
('20260615090001'),
('20260615090000'),
('20260614090000'),
('20260612000001'),
('20260530031000'),
('20260520143004'),
('20260520072158'),
('20260520072019'),
('20260520064941'),
('20260518044346'),
('20260508151000'),
('20260508140999'),
('20260508135006'),
('20260501140100'),
('20260501000000');

