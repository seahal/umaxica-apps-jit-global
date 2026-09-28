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


--
-- Name: check_staff_identity_emails_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_staff_identity_emails_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE emails_count integer; BEGIN IF NEW.staff_id IS NULL THEN RETURN NEW; END IF; SELECT COUNT(*) INTO emails_count FROM staff_identity_emails WHERE staff_id = NEW.staff_id; IF emails_count >= 4 THEN RAISE EXCEPTION 'staff_identity_emails limit (4) exceeded for staff %', NEW.staff_id USING ERRCODE = '23514'; END IF; RETURN NEW; END; $$;


--
-- Name: check_staff_identity_passkeys_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_staff_identity_passkeys_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE passkeys_count integer; BEGIN SELECT COUNT(*) INTO passkeys_count FROM staff_identity_passkeys WHERE staff_id = NEW.staff_id; IF passkeys_count >= 4 THEN RAISE EXCEPTION 'staff_identity_passkeys limit (4) exceeded for staff %', NEW.staff_id USING ERRCODE = '23514'; END IF; RETURN NEW; END; $$;


--
-- Name: check_staff_identity_telephones_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_staff_identity_telephones_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE telephones_count integer; BEGIN IF NEW.staff_id IS NULL THEN RETURN NEW; END IF; SELECT COUNT(*) INTO telephones_count FROM staff_identity_telephones WHERE staff_id = NEW.staff_id; IF telephones_count >= 4 THEN RAISE EXCEPTION 'staff_identity_telephones limit (4) exceeded for staff %', NEW.staff_id USING ERRCODE = '23514'; END IF; RETURN NEW; END; $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: agent_administration_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_administration_grants (
    id bigint NOT NULL,
    agent_id bigint NOT NULL,
    operator_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: agent_administration_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_administration_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_administration_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_administration_grants_id_seq OWNED BY public.agent_administration_grants.id;


--
-- Name: agent_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_assignments (
    id bigint NOT NULL,
    public_id character varying NOT NULL,
    agent_id bigint NOT NULL,
    operator_identity_id bigint NOT NULL,
    assigned_at timestamp(6) with time zone NOT NULL,
    revoked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: agent_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_assignments_id_seq OWNED BY public.agent_assignments.id;


--
-- Name: agent_authority_cutovers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_authority_cutovers (
    id bigint NOT NULL,
    cutover_at timestamp(6) with time zone DEFAULT clock_timestamp() NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_agent_authority_cutovers_finite_time CHECK (isfinite(cutover_at)),
    CONSTRAINT chk_agent_authority_cutovers_singleton CHECK ((id = 1))
);


--
-- Name: agent_authority_cutovers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_authority_cutovers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_authority_cutovers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_authority_cutovers_id_seq OWNED BY public.agent_authority_cutovers.id;


--
-- Name: agent_delegation_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_delegation_grants (
    id bigint NOT NULL,
    agent_id bigint NOT NULL,
    operator_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: agent_delegation_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_delegation_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_delegation_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_delegation_grants_id_seq OWNED BY public.agent_delegation_grants.id;


--
-- Name: agent_lifecycles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_lifecycles (
    id bigint NOT NULL,
    agent_id bigint NOT NULL,
    state character varying NOT NULL,
    state_changed_at timestamp(6) with time zone DEFAULT clock_timestamp() NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_agent_lifecycles_state CHECK (((state)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying, 'discarded'::character varying, 'deleted'::character varying, 'retained'::character varying])::text[])))
);


--
-- Name: agent_lifecycles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_lifecycles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_lifecycles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_lifecycles_id_seq OWNED BY public.agent_lifecycles.id;


--
-- Name: agent_membership_kinds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_membership_kinds (
    id bigint NOT NULL
);


--
-- Name: agent_membership_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_membership_kinds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_membership_kinds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_membership_kinds_id_seq OWNED BY public.agent_membership_kinds.id;


--
-- Name: agent_membership_revoke_reasons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_membership_revoke_reasons (
    id bigint NOT NULL
);


--
-- Name: agent_membership_revoke_reasons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_membership_revoke_reasons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_membership_revoke_reasons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_membership_revoke_reasons_id_seq OWNED BY public.agent_membership_revoke_reasons.id;


--
-- Name: agent_membership_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_membership_states (
    id bigint NOT NULL
);


--
-- Name: agent_membership_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_membership_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_membership_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_membership_states_id_seq OWNED BY public.agent_membership_states.id;


--
-- Name: agent_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_memberships (
    id bigint NOT NULL,
    agent_id bigint NOT NULL,
    bureau_id bigint NOT NULL,
    bureau_unit_id bigint NOT NULL,
    membership_kind_id bigint DEFAULT 0 NOT NULL,
    membership_state_id bigint DEFAULT 0 NOT NULL,
    "primary" boolean DEFAULT false NOT NULL,
    starts_at timestamp(6) with time zone,
    ends_at timestamp(6) with time zone,
    granted_by_agent_id bigint,
    approved_by_agent_id bigint,
    revoked_by_agent_id bigint,
    revoked_at timestamp(6) with time zone,
    revoke_reason_id bigint,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: agent_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_memberships_id_seq OWNED BY public.agent_memberships.id;


--
-- Name: agent_ownership_transfer_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_ownership_transfer_requests (
    id bigint NOT NULL,
    agent_id bigint NOT NULL,
    source_operator_id bigint NOT NULL,
    destination_operator_id bigint NOT NULL,
    public_id character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    expected_ownership_revision integer NOT NULL,
    requested_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    accepted_at timestamp(6) with time zone,
    rejected_at timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    invalidated_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_agent_transfer_requests_distinct_parties CHECK ((source_operator_id <> destination_operator_id)),
    CONSTRAINT chk_agent_transfer_requests_expiry_after_request CHECK ((requested_at < expires_at)),
    CONSTRAINT chk_agent_transfer_requests_revision_nonnegative CHECK ((expected_ownership_revision >= 0)),
    CONSTRAINT chk_agent_transfer_requests_status CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'accepted'::character varying, 'rejected'::character varying, 'cancelled'::character varying, 'expired'::character varying, 'invalidated'::character varying])::text[])))
);


--
-- Name: agent_ownership_transfer_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_ownership_transfer_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_ownership_transfer_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_ownership_transfer_requests_id_seq OWNED BY public.agent_ownership_transfer_requests.id;


--
-- Name: agent_ownerships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_ownerships (
    id bigint NOT NULL,
    agent_id bigint NOT NULL,
    operator_id bigint NOT NULL,
    ownership_revision integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_agent_ownerships_revision_nonnegative CHECK ((ownership_revision >= 0))
);


--
-- Name: agent_ownerships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_ownerships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_ownerships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_ownerships_id_seq OWNED BY public.agent_ownerships.id;


--
-- Name: agent_usage_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_usage_grants (
    id bigint NOT NULL,
    agent_id bigint NOT NULL,
    operator_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: agent_usage_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_usage_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_usage_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_usage_grants_id_seq OWNED BY public.agent_usage_grants.id;


--
-- Name: agent_view_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_view_grants (
    id bigint NOT NULL,
    agent_id bigint NOT NULL,
    operator_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: agent_view_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_view_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_view_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_view_grants_id_seq OWNED BY public.agent_view_grants.id;


--
-- Name: agents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agents (
    id bigint NOT NULL,
    operator_identity_id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    moniker character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    title character varying NOT NULL
);


--
-- Name: agents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agents_id_seq OWNED BY public.agents.id;


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
-- Name: bureau_administration_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bureau_administration_grants (
    id bigint NOT NULL,
    bureau_id bigint NOT NULL,
    operator_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: bureau_administration_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bureau_administration_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bureau_administration_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bureau_administration_grants_id_seq OWNED BY public.bureau_administration_grants.id;


--
-- Name: bureau_authority_cutovers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bureau_authority_cutovers (
    id bigint NOT NULL,
    cutover_at timestamp(6) with time zone DEFAULT clock_timestamp() NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_bureau_authority_cutovers_finite_time CHECK (isfinite(cutover_at)),
    CONSTRAINT chk_bureau_authority_cutovers_singleton CHECK ((id = 1))
);


--
-- Name: bureau_authority_cutovers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bureau_authority_cutovers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bureau_authority_cutovers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bureau_authority_cutovers_id_seq OWNED BY public.bureau_authority_cutovers.id;


--
-- Name: bureau_delegation_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bureau_delegation_grants (
    id bigint NOT NULL,
    bureau_id bigint NOT NULL,
    operator_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: bureau_delegation_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bureau_delegation_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bureau_delegation_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bureau_delegation_grants_id_seq OWNED BY public.bureau_delegation_grants.id;


--
-- Name: bureau_lifecycles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bureau_lifecycles (
    id bigint NOT NULL,
    bureau_id bigint NOT NULL,
    state character varying NOT NULL,
    state_changed_at timestamp(6) with time zone DEFAULT clock_timestamp() NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_bureau_lifecycles_state CHECK (((state)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying, 'discarded'::character varying, 'deleted'::character varying, 'retained'::character varying])::text[])))
);


--
-- Name: bureau_lifecycles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bureau_lifecycles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bureau_lifecycles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bureau_lifecycles_id_seq OWNED BY public.bureau_lifecycles.id;


--
-- Name: bureau_ownership_transfer_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bureau_ownership_transfer_requests (
    id bigint NOT NULL,
    bureau_id bigint NOT NULL,
    source_operator_id bigint NOT NULL,
    destination_operator_id bigint NOT NULL,
    public_id character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    expected_ownership_revision integer NOT NULL,
    requested_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    accepted_at timestamp(6) with time zone,
    rejected_at timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    invalidated_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_bureau_transfer_requests_distinct_parties CHECK ((source_operator_id <> destination_operator_id)),
    CONSTRAINT chk_bureau_transfer_requests_expiry_after_request CHECK ((requested_at < expires_at)),
    CONSTRAINT chk_bureau_transfer_requests_revision_nonnegative CHECK ((expected_ownership_revision >= 0)),
    CONSTRAINT chk_bureau_transfer_requests_status CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'accepted'::character varying, 'rejected'::character varying, 'cancelled'::character varying, 'expired'::character varying, 'invalidated'::character varying])::text[])))
);


--
-- Name: bureau_ownership_transfer_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bureau_ownership_transfer_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bureau_ownership_transfer_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bureau_ownership_transfer_requests_id_seq OWNED BY public.bureau_ownership_transfer_requests.id;


--
-- Name: bureau_ownerships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bureau_ownerships (
    id bigint NOT NULL,
    bureau_id bigint NOT NULL,
    operator_id bigint NOT NULL,
    ownership_revision integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_bureau_ownerships_revision_nonnegative CHECK ((ownership_revision >= 0))
);


--
-- Name: bureau_ownerships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bureau_ownerships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bureau_ownerships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bureau_ownerships_id_seq OWNED BY public.bureau_ownerships.id;


--
-- Name: bureau_unit_closures; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bureau_unit_closures (
    id bigint NOT NULL,
    ancestor_id bigint NOT NULL,
    descendant_id bigint NOT NULL,
    depth integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_bureau_unit_closures_depth_matches_self CHECK ((((ancestor_id = descendant_id) AND (depth = 0)) OR ((ancestor_id <> descendant_id) AND (depth > 0)))),
    CONSTRAINT chk_bureau_unit_closures_depth_nonnegative CHECK ((depth >= 0))
);


--
-- Name: bureau_unit_closures_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bureau_unit_closures_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bureau_unit_closures_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bureau_unit_closures_id_seq OWNED BY public.bureau_unit_closures.id;


--
-- Name: bureau_units; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bureau_units (
    id bigint NOT NULL,
    bureau_id bigint NOT NULL,
    parent_id bigint,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: bureau_units_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bureau_units_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bureau_units_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bureau_units_id_seq OWNED BY public.bureau_units.id;


--
-- Name: bureau_view_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bureau_view_grants (
    id bigint NOT NULL,
    bureau_id bigint NOT NULL,
    operator_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: bureau_view_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bureau_view_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bureau_view_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bureau_view_grants_id_seq OWNED BY public.bureau_view_grants.id;


--
-- Name: bureaus; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bureaus (
    id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    title character varying NOT NULL
);


--
-- Name: bureaus_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bureaus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bureaus_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bureaus_id_seq OWNED BY public.bureaus.id;


--
-- Name: core_org_operator_bridges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.core_org_operator_bridges (
    id bigint NOT NULL,
    operator_id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    rp_client_id character varying DEFAULT 'core_org'::character varying NOT NULL,
    audience character varying DEFAULT 'umaxica-core-org'::character varying NOT NULL,
    host character varying DEFAULT 'jpx.umaxica.org'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: core_org_operator_bridges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.core_org_operator_bridges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: core_org_operator_bridges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.core_org_operator_bridges_id_seq OWNED BY public.core_org_operator_bridges.id;


--
-- Name: department_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.department_statuses (
    id bigint NOT NULL
);


--
-- Name: department_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.department_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: department_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.department_statuses_id_seq OWNED BY public.department_statuses.id;


--
-- Name: departments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    workspace_id bigint,
    parent_id bigint,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    department_status_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: departments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.departments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: departments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.departments_id_seq OWNED BY public.departments.id;


--
-- Name: division_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.division_statuses (
    id bigint NOT NULL
);


--
-- Name: division_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.division_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: division_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.division_statuses_id_seq OWNED BY public.division_statuses.id;


--
-- Name: divisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.divisions (
    id bigint NOT NULL,
    name character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    organization_id bigint NOT NULL,
    division_status_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: divisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.divisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: divisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.divisions_id_seq OWNED BY public.divisions.id;


--
-- Name: legacy_operator_department_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_operator_department_accounts (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    department_id bigint,
    public_id character varying NOT NULL,
    moniker character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    status_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: legacy_operator_department_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.legacy_operator_department_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: legacy_operator_department_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.legacy_operator_department_accounts_id_seq OWNED BY public.legacy_operator_department_accounts.id;


--
-- Name: operator_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_accounts (
    id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    staff_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_accounts_id_seq OWNED BY public.operator_accounts.id;


--
-- Name: operator_authority_locks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_authority_locks (
    id bigint NOT NULL,
    operator_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_authority_locks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_authority_locks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_authority_locks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_authority_locks_id_seq OWNED BY public.operator_authority_locks.id;


--
-- Name: operator_banners; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_banners (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    title character varying DEFAULT ''::character varying NOT NULL,
    body text NOT NULL,
    published boolean DEFAULT false NOT NULL,
    starts_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    ends_at timestamp(6) with time zone DEFAULT '9999-12-31 23:59:59+00'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT staff_banners_ends_at_after_starts_at CHECK ((ends_at > starts_at))
);


--
-- Name: operator_banners_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_banners_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_banners_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_banners_id_seq OWNED BY public.operator_banners.id;


--
-- Name: operator_bulletins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_bulletins (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    title character varying NOT NULL,
    body text,
    read_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_bulletins_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_bulletins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_bulletins_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_bulletins_id_seq OWNED BY public.operator_bulletins.id;


--
-- Name: operator_capability_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_capability_grants (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    operator_id bigint NOT NULL,
    capability character varying NOT NULL,
    origin character varying NOT NULL,
    granted_by_operator_id bigint,
    reason_code character varying NOT NULL,
    ticket_id character varying(64),
    starts_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    revoked_at timestamp(6) with time zone,
    revoked_by_operator_id bigint,
    revoke_reason_code character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_operator_capability_grants_capability CHECK (((capability)::text = ANY ((ARRAY['support.console.read'::character varying, 'support.account.read.app'::character varying, 'support.account.read.com'::character varying, 'support.session.revoke.app'::character varying, 'support.session.revoke.com'::character varying, 'enforcement.read.app'::character varying, 'enforcement.read.com'::character varying, 'enforcement.apply.app'::character varying, 'enforcement.apply.com'::character varying, 'enforcement.approve.app'::character varying, 'enforcement.approve.com'::character varying, 'enforcement.release.app'::character varying, 'enforcement.release.com'::character varying, 'enforcement.review_appeal.app'::character varying, 'enforcement.review_appeal.com'::character varying, 'iam.capability.read'::character varying, 'iam.capability.grant'::character varying, 'iam.capability.revoke'::character varying])::text[]))),
    CONSTRAINT chk_operator_capability_grants_granter CHECK (((((origin)::text = 'grant'::text) AND (granted_by_operator_id IS NOT NULL) AND (granted_by_operator_id <> operator_id)) OR (((origin)::text = 'bootstrap'::text) AND (granted_by_operator_id IS NULL)))),
    CONSTRAINT chk_operator_capability_grants_origin CHECK (((origin)::text = ANY ((ARRAY['grant'::character varying, 'bootstrap'::character varying])::text[]))),
    CONSTRAINT chk_operator_capability_grants_reason_code CHECK ((((reason_code)::text = ANY ((ARRAY['bootstrap'::character varying, 'duty_assignment'::character varying, 'incident_response'::character varying, 'access_review'::character varying])::text[])) AND (((origin)::text = 'bootstrap'::text) = ((reason_code)::text = 'bootstrap'::text)))),
    CONSTRAINT chk_operator_capability_grants_revocation CHECK ((((revoked_at IS NULL) AND (revoke_reason_code IS NULL) AND (revoked_by_operator_id IS NULL)) OR ((revoked_at IS NOT NULL) AND (revoke_reason_code IS NOT NULL) AND ((revoke_reason_code)::text = ANY ((ARRAY['duty_ended'::character varying, 'access_review'::character varying, 'security_incident'::character varying, 'operator_error_recovery'::character varying])::text[]))))),
    CONSTRAINT chk_operator_capability_grants_validity_window CHECK ((isfinite(starts_at) AND isfinite(expires_at) AND (expires_at > starts_at) AND (expires_at <= (starts_at + '366 days'::interval))))
);


--
-- Name: operator_capability_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_capability_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_capability_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_capability_grants_id_seq OWNED BY public.operator_capability_grants.id;


--
-- Name: operator_email_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_email_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_email_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_email_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_email_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_email_statuses_id_seq OWNED BY public.operator_email_statuses.id;


--
-- Name: operator_emails; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_emails (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    address character varying NOT NULL,
    otp_private_key character varying NOT NULL,
    otp_counter text NOT NULL,
    otp_expires_at timestamp(6) with time zone,
    otp_last_sent_at timestamp(6) with time zone,
    otp_attempts_count integer DEFAULT 0 NOT NULL,
    locked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    staff_identity_email_status_id bigint DEFAULT 0 NOT NULL,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    undeletable boolean DEFAULT false NOT NULL,
    promotional boolean DEFAULT true NOT NULL,
    notifiable boolean DEFAULT true NOT NULL,
    subscribable boolean DEFAULT true NOT NULL,
    address_digest character varying
);


--
-- Name: operator_emails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_emails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_emails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_emails_id_seq OWNED BY public.operator_emails.id;


--
-- Name: operator_entra_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_entra_identities (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    operator_id bigint NOT NULL,
    connection_id bigint,
    entra_tenant_id character varying(36) NOT NULL,
    entra_object_id character varying(36) NOT NULL,
    evidence_issuer character varying(512),
    evidence_subject character varying(512),
    status_id bigint DEFAULT 0 NOT NULL,
    last_authenticated_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_entra_identities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_entra_identities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_entra_identities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_entra_identities_id_seq OWNED BY public.operator_entra_identities.id;


--
-- Name: operator_entra_identity_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_entra_identity_states (
    id bigint NOT NULL
);


--
-- Name: operator_entra_identity_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_entra_identity_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_entra_identity_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_entra_identity_states_id_seq OWNED BY public.operator_entra_identity_states.id;


--
-- Name: operator_google_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_google_identities (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    provider character varying DEFAULT 'google_org'::character varying NOT NULL,
    uid character varying DEFAULT ''::character varying NOT NULL,
    token character varying DEFAULT ''::character varying NOT NULL,
    refresh_token character varying DEFAULT ''::character varying NOT NULL,
    token_expires_at integer NOT NULL,
    status_id bigint DEFAULT 1 NOT NULL,
    last_authenticated_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_google_identities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_google_identities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_google_identities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_google_identities_id_seq OWNED BY public.operator_google_identities.id;


--
-- Name: operator_google_identity_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_google_identity_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_google_identity_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_google_identity_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_google_identity_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_google_identity_statuses_id_seq OWNED BY public.operator_google_identity_statuses.id;


--
-- Name: operator_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_identities (
    id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    issuer character varying NOT NULL,
    subject character varying NOT NULL,
    audience character varying NOT NULL,
    source_record_id bigint NOT NULL,
    status_id bigint DEFAULT 0 NOT NULL,
    last_authenticated_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_identities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_identities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_identities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_identities_id_seq OWNED BY public.operator_identities.id;


--
-- Name: operator_identity_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_identity_states (
    id bigint NOT NULL
);


--
-- Name: operator_identity_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_identity_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_identity_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_identity_states_id_seq OWNED BY public.operator_identity_states.id;


--
-- Name: operator_lifecycle_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_lifecycle_requests (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    action character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    target_operator_id bigint,
    target_email character varying,
    organization_id bigint,
    role_id bigint DEFAULT 0 NOT NULL,
    requested_by_operator_id bigint NOT NULL,
    approved_by_operator_id bigint,
    rejected_by_operator_id bigint,
    executed_by_operator_id bigint,
    invitation_id bigint,
    reason text,
    rejection_reason text,
    approved_at timestamp(6) with time zone,
    rejected_at timestamp(6) with time zone,
    executed_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_lifecycle_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_lifecycle_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_lifecycle_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_lifecycle_requests_id_seq OWNED BY public.operator_lifecycle_requests.id;


--
-- Name: operator_mfa_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_mfa_levels (
    id bigint NOT NULL
);


--
-- Name: operator_mfa_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_mfa_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_mfa_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_mfa_levels_id_seq OWNED BY public.operator_mfa_levels.id;


--
-- Name: operator_mfa_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_mfa_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_mfa_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_mfa_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_mfa_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_mfa_statuses_id_seq OWNED BY public.operator_mfa_statuses.id;


--
-- Name: operator_passkey_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_passkey_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_passkey_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_passkey_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_passkey_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_passkey_statuses_id_seq OWNED BY public.operator_passkey_statuses.id;


--
-- Name: operator_passkeys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_passkeys (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    external_id uuid NOT NULL,
    public_key text NOT NULL,
    sign_count bigint DEFAULT 0 NOT NULL,
    description character varying DEFAULT ''::character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    status_id bigint DEFAULT 0 NOT NULL,
    webauthn_id character varying DEFAULT ''::character varying NOT NULL,
    last_used_at timestamp(6) with time zone,
    aaguid uuid,
    transports jsonb,
    backup_eligible boolean,
    backup_state boolean,
    authenticator_attachment character varying,
    provider_name character varying,
    metadata_source character varying,
    uv_verified_at timestamp(6) with time zone
);


--
-- Name: operator_passkeys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_passkeys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_passkeys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_passkeys_id_seq OWNED BY public.operator_passkeys.id;


--
-- Name: operator_preference_adult_content_gate_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_adult_content_gate_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_adult_content_gate_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_adult_content_gate_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_adult_content_gate_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_adult_content_gate_options_id_seq OWNED BY public.operator_preference_adult_content_gate_options.id;


--
-- Name: operator_preference_adult_content_gates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_adult_content_gates (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_adult_content_gates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_adult_content_gates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_adult_content_gates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_adult_content_gates_id_seq OWNED BY public.operator_preference_adult_content_gates.id;


--
-- Name: operator_preference_currencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_currencies (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_currencies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_currencies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_currencies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_currencies_id_seq OWNED BY public.operator_preference_currencies.id;


--
-- Name: operator_preference_currency_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_currency_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_currency_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_currency_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_currency_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_currency_options_id_seq OWNED BY public.operator_preference_currency_options.id;


--
-- Name: operator_preference_date_format_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_date_format_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_date_format_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_date_format_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_date_format_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_date_format_options_id_seq OWNED BY public.operator_preference_date_format_options.id;


--
-- Name: operator_preference_date_formats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_date_formats (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_date_formats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_date_formats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_date_formats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_date_formats_id_seq OWNED BY public.operator_preference_date_formats.id;


--
-- Name: operator_preference_densities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_densities (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_densities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_densities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_densities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_densities_id_seq OWNED BY public.operator_preference_densities.id;


--
-- Name: operator_preference_density_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_density_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_density_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_density_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_density_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_density_options_id_seq OWNED BY public.operator_preference_density_options.id;


--
-- Name: operator_preference_language_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_language_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_language_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_language_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_language_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_language_options_id_seq OWNED BY public.operator_preference_language_options.id;


--
-- Name: operator_preference_languages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_languages (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_languages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_languages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_languages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_languages_id_seq OWNED BY public.operator_preference_languages.id;


--
-- Name: operator_preference_motion_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_motion_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_motion_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_motion_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_motion_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_motion_options_id_seq OWNED BY public.operator_preference_motion_options.id;


--
-- Name: operator_preference_motions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_motions (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_motions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_motions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_motions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_motions_id_seq OWNED BY public.operator_preference_motions.id;


--
-- Name: operator_preference_page_size_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_page_size_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_page_size_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_page_size_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_page_size_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_page_size_options_id_seq OWNED BY public.operator_preference_page_size_options.id;


--
-- Name: operator_preference_page_sizes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_page_sizes (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_page_sizes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_page_sizes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_page_sizes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_page_sizes_id_seq OWNED BY public.operator_preference_page_sizes.id;


--
-- Name: operator_preference_region_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_region_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_region_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_region_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_region_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_region_options_id_seq OWNED BY public.operator_preference_region_options.id;


--
-- Name: operator_preference_regions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_regions (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_regions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_regions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_regions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_regions_id_seq OWNED BY public.operator_preference_regions.id;


--
-- Name: operator_preference_theme_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_theme_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_theme_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_theme_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_theme_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_theme_options_id_seq OWNED BY public.operator_preference_theme_options.id;


--
-- Name: operator_preference_themes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_themes (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_themes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_themes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_themes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_themes_id_seq OWNED BY public.operator_preference_themes.id;


--
-- Name: operator_preference_time_format_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_time_format_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_time_format_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_time_format_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_time_format_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_time_format_options_id_seq OWNED BY public.operator_preference_time_format_options.id;


--
-- Name: operator_preference_time_formats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_time_formats (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_time_formats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_time_formats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_time_formats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_time_formats_id_seq OWNED BY public.operator_preference_time_formats.id;


--
-- Name: operator_preference_timezone_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_timezone_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_timezone_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_timezone_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_timezone_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_timezone_options_id_seq OWNED BY public.operator_preference_timezone_options.id;


--
-- Name: operator_preference_timezones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preference_timezones (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_timezones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preference_timezones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_timezones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_timezones_id_seq OWNED BY public.operator_preference_timezones.id;


--
-- Name: operator_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_preferences (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    consented boolean DEFAULT false NOT NULL,
    functional boolean DEFAULT false NOT NULL,
    performant boolean DEFAULT false NOT NULL,
    targetable boolean DEFAULT false NOT NULL,
    consented_at timestamp(6) with time zone,
    consent_version uuid,
    language character varying DEFAULT 'ja'::character varying NOT NULL,
    region character varying DEFAULT 'jp'::character varying NOT NULL,
    timezone character varying DEFAULT 'Asia/Tokyo'::character varying NOT NULL,
    theme character varying DEFAULT 'sy'::character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    public_id character varying(21),
    currency character varying DEFAULT 'jpy'::character varying NOT NULL,
    date_format character varying DEFAULT 'iso'::character varying NOT NULL,
    time_format character varying DEFAULT '24'::character varying NOT NULL,
    motion character varying DEFAULT 'standard'::character varying NOT NULL,
    density character varying DEFAULT 'standard'::character varying NOT NULL,
    page_size character varying DEFAULT 'infinity'::character varying NOT NULL,
    explicit_fields jsonb DEFAULT '[]'::jsonb
);


--
-- Name: operator_preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_preferences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preferences_id_seq OWNED BY public.operator_preferences.id;


--
-- Name: operator_secret_credential_kinds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_secret_credential_kinds (
    id bigint NOT NULL
);


--
-- Name: operator_secret_credential_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_secret_credential_kinds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_secret_credential_kinds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_secret_credential_kinds_id_seq OWNED BY public.operator_secret_credential_kinds.id;


--
-- Name: operator_secret_credential_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_secret_credential_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_secret_credential_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_secret_credential_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_secret_credential_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_secret_credential_statuses_id_seq OWNED BY public.operator_secret_credential_statuses.id;


--
-- Name: operator_secret_credentials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_secret_credentials (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    password_digest character varying,
    last_used_at timestamp(6) with time zone,
    name character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    staff_identity_secret_status_id bigint DEFAULT 0 NOT NULL,
    staff_secret_kind_id bigint DEFAULT 0 NOT NULL,
    public_id character varying(21) NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    secret_kind character varying,
    usage_policy character varying,
    lookup_digest character varying,
    safe_prefix character varying,
    issued_at timestamp(6) with time zone,
    issued_by_type character varying,
    issued_by_id bigint,
    issued_by_ref character varying,
    delivery_method character varying,
    scope character varying,
    use_count integer DEFAULT 0 NOT NULL,
    failure_count integer DEFAULT 0 NOT NULL,
    max_uses integer,
    max_failures integer,
    not_before_at timestamp(6) with time zone,
    consumed_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    locked_at timestamp(6) with time zone,
    last_failed_at timestamp(6) with time zone,
    CONSTRAINT chk_staff_secrets_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: operator_secret_credentials_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_secret_credentials_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_secret_credentials_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_secret_credentials_id_seq OWNED BY public.operator_secret_credentials.id;


--
-- Name: operator_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_statuses_id_seq OWNED BY public.operator_statuses.id;


--
-- Name: operator_telephone_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_telephone_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_telephone_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_telephone_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_telephone_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_telephone_statuses_id_seq OWNED BY public.operator_telephone_statuses.id;


--
-- Name: operator_telephones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_telephones (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    number character varying NOT NULL,
    otp_private_key character varying NOT NULL,
    otp_counter text NOT NULL,
    otp_expires_at timestamp(6) with time zone,
    otp_attempts_count integer DEFAULT 0 NOT NULL,
    locked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    staff_identity_telephone_status_id bigint DEFAULT 0 NOT NULL,
    number_digest character varying
);


--
-- Name: operator_telephones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_telephones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_telephones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_telephones_id_seq OWNED BY public.operator_telephones.id;


--
-- Name: operator_visibilities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_visibilities (
    id bigint NOT NULL
);


--
-- Name: operator_visibilities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_visibilities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_visibilities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_visibilities_id_seq OWNED BY public.operator_visibilities.id;


--
-- Name: operator_workspace_account_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_workspace_account_memberships (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    operator_workspace_account_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_workspace_account_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_workspace_account_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_workspace_account_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_workspace_account_memberships_id_seq OWNED BY public.operator_workspace_account_memberships.id;


--
-- Name: operator_workspace_account_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_workspace_account_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_workspace_account_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_workspace_account_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_workspace_account_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_workspace_account_statuses_id_seq OWNED BY public.operator_workspace_account_statuses.id;


--
-- Name: operator_workspace_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_workspace_accounts (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    department_id bigint,
    public_id character varying NOT NULL,
    moniker character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    status_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: operator_workspace_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_workspace_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_workspace_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_workspace_accounts_id_seq OWNED BY public.operator_workspace_accounts.id;


--
-- Name: operators; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operators (
    id bigint NOT NULL,
    webauthn_id character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    public_id character varying(16) NOT NULL,
    withdrawn_at timestamp(6) with time zone,
    status_id bigint DEFAULT 0 NOT NULL,
    mfa_level_enabled boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    visibility_id bigint DEFAULT 2 NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    mfa_level_id bigint DEFAULT 0 NOT NULL,
    mfa_status_id bigint DEFAULT 5 NOT NULL,
    withdrawal_started_at timestamp(6) with time zone,
    deactivated_at timestamp(6) with time zone,
    birthdate text,
    access_state character varying DEFAULT 'enabled'::character varying NOT NULL,
    admin_locked_at timestamp(6) with time zone,
    admin_locked_by_operator_id bigint,
    admin_locked_reason_code character varying,
    admin_locked_reason_note text,
    token_valid_after_at timestamp(6) with time zone,
    reactivated_at timestamp(6) with time zone,
    webauthn_user_handle character varying NOT NULL,
    CONSTRAINT chk_operators_access_state CHECK (((access_state)::text = ANY ((ARRAY['enabled'::character varying, 'admin_locked'::character varying])::text[]))),
    CONSTRAINT chk_operators_admin_locked_reason_code CHECK (((admin_locked_reason_code IS NULL) OR ((admin_locked_reason_code)::text = ANY ((ARRAY['abuse'::character varying, 'security_incident'::character varying, 'chargeback'::character varying, 'terms_violation'::character varying, 'support_request'::character varying, 'legal_hold'::character varying, 'operator_error_recovery'::character varying, 'other'::character varying])::text[])))),
    CONSTRAINT chk_operators_birthdate_length CHECK (((birthdate IS NULL) OR (char_length(birthdate) <= 1000))),
    CONSTRAINT chk_staffs_public_id_format CHECK (((public_id)::text ~ '^[0-9A-FGHJKMNPQRSTVWXYZ]{16}$'::text)),
    CONSTRAINT chk_staffs_public_id_length CHECK ((char_length((public_id)::text) = 16)),
    CONSTRAINT chk_staffs_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: operators_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operators_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operators_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operators_id_seq OWNED BY public.operators.id;


--
-- Name: org_enforcement_appeals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_enforcement_appeals (
    id bigint NOT NULL,
    org_enforcement_case_id bigint NOT NULL,
    public_id character varying NOT NULL,
    state character varying DEFAULT 'submitted'::character varying NOT NULL,
    reason_code character varying NOT NULL,
    statement text,
    submitted_at timestamp(6) with time zone NOT NULL,
    reviewed_at timestamp(6) with time zone,
    reviewer_operator_public_id character varying,
    resolution_code character varying,
    redacted_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_org_enforcement_appeals_state CHECK (((state)::text = ANY ((ARRAY['submitted'::character varying, 'under_review'::character varying, 'approved'::character varying, 'rejected'::character varying, 'redacted'::character varying])::text[])))
);


--
-- Name: org_enforcement_appeals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_enforcement_appeals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_enforcement_appeals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_enforcement_appeals_id_seq OWNED BY public.org_enforcement_appeals.id;


--
-- Name: org_enforcement_authentication_method_effects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_enforcement_authentication_method_effects (
    id bigint NOT NULL,
    org_enforcement_case_id bigint NOT NULL,
    principal_public_id character varying NOT NULL,
    authentication_method character varying NOT NULL,
    effect character varying NOT NULL,
    effective_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_org_enforcement_method_effects_effect CHECK (((effect)::text = ANY ((ARRAY['mutation_locked'::character varying, 'unusable'::character varying, 'permanently_frozen'::character varying])::text[]))),
    CONSTRAINT chk_org_enforcement_method_effects_method CHECK (((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'entra'::character varying])::text[])))
);


--
-- Name: org_enforcement_authentication_method_effects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_enforcement_authentication_method_effects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_enforcement_authentication_method_effects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_enforcement_authentication_method_effects_id_seq OWNED BY public.org_enforcement_authentication_method_effects.id;


--
-- Name: org_enforcement_cases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_enforcement_cases (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    kind character varying NOT NULL,
    state character varying DEFAULT 'draft'::character varying NOT NULL,
    duration_mode character varying NOT NULL,
    visibility character varying DEFAULT 'visible'::character varying NOT NULL,
    release_mode character varying NOT NULL,
    effective_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    ended_at timestamp(6) with time zone,
    end_reason character varying,
    review_due_at timestamp(6) with time zone,
    reason_code character varying NOT NULL,
    reason_note text,
    ticket_id character varying,
    principal_public_id character varying NOT NULL,
    applied_by_operator_public_id character varying NOT NULL,
    approved_by_operator_public_id character varying,
    ended_by_operator_public_id character varying,
    break_glass boolean DEFAULT false NOT NULL,
    break_glass_approved_by_operator_public_id character varying,
    sessions_revoked_at timestamp(6) with time zone,
    audited_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_org_enforcement_cases_approval_separation CHECK (((approved_by_operator_public_id IS NULL) OR ((approved_by_operator_public_id)::text <> (applied_by_operator_public_id)::text))),
    CONSTRAINT chk_org_enforcement_cases_break_glass_approver CHECK (((break_glass = false) OR (break_glass_approved_by_operator_public_id IS NOT NULL))),
    CONSTRAINT chk_org_enforcement_cases_cooldown_duration CHECK ((((kind)::text <> 'cooldown'::text) OR (((duration_mode)::text = 'timed'::text) AND (expires_at IS NOT NULL) AND (expires_at <= (effective_at + '30 days'::interval))))),
    CONSTRAINT chk_org_enforcement_cases_duration_mode CHECK (((duration_mode)::text = ANY ((ARRAY['timed'::character varying, 'indefinite'::character varying, 'permanent'::character varying])::text[]))),
    CONSTRAINT chk_org_enforcement_cases_end_reason CHECK (((end_reason IS NULL) OR ((end_reason)::text = ANY ((ARRAY['expired'::character varying, 'revoked'::character varying, 'superseded'::character varying, 'corrected'::character varying, 'appeal_approved'::character varying, 'break_glass_released'::character varying, 'verification_completed'::character varying])::text[])))),
    CONSTRAINT chk_org_enforcement_cases_hidden CHECK ((((visibility)::text <> 'hidden'::text) OR ((kind)::text = 'permanent_ban'::text))),
    CONSTRAINT chk_org_enforcement_cases_indefinite_freeze_review CHECK ((((kind)::text <> 'temporary_freeze'::text) OR ((duration_mode)::text <> 'indefinite'::text) OR ((review_due_at IS NOT NULL) AND ((release_mode)::text = 'operator'::text)))),
    CONSTRAINT chk_org_enforcement_cases_kind CHECK (((kind)::text = ANY ((ARRAY['security_lock'::character varying, 'cooldown'::character varying, 'temporary_freeze'::character varying, 'permanent_ban'::character varying, 'method_protection'::character varying])::text[]))),
    CONSTRAINT chk_org_enforcement_cases_no_self_action CHECK (((principal_public_id)::text <> (applied_by_operator_public_id)::text)),
    CONSTRAINT chk_org_enforcement_cases_permanent_ban_duration CHECK ((((kind)::text <> 'permanent_ban'::text) OR (((duration_mode)::text = 'permanent'::text) AND (expires_at IS NULL)))),
    CONSTRAINT chk_org_enforcement_cases_release_mode CHECK (((release_mode)::text = ANY ((ARRAY['automatic'::character varying, 'operator'::character varying, 'verification_required'::character varying, 'break_glass_only'::character varying])::text[]))),
    CONSTRAINT chk_org_enforcement_cases_security_lock_release CHECK ((((kind)::text <> 'security_lock'::text) OR ((release_mode)::text = 'verification_required'::text))),
    CONSTRAINT chk_org_enforcement_cases_state CHECK (((state)::text = ANY ((ARRAY['draft'::character varying, 'pending_approval'::character varying, 'active'::character varying, 'ended'::character varying, 'failed'::character varying])::text[]))),
    CONSTRAINT chk_org_enforcement_cases_temp_freeze_duration_mode CHECK ((((kind)::text <> 'temporary_freeze'::text) OR ((duration_mode)::text = ANY ((ARRAY['timed'::character varying, 'indefinite'::character varying])::text[])))),
    CONSTRAINT chk_org_enforcement_cases_visibility CHECK (((visibility)::text = ANY ((ARRAY['visible'::character varying, 'hidden'::character varying])::text[])))
);


--
-- Name: org_enforcement_cases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_enforcement_cases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_enforcement_cases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_enforcement_cases_id_seq OWNED BY public.org_enforcement_cases.id;


--
-- Name: org_enforcement_identifier_effects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_enforcement_identifier_effects (
    id bigint NOT NULL,
    org_enforcement_case_id bigint NOT NULL,
    identifier_kind character varying NOT NULL,
    lookup_digest character varying NOT NULL,
    key_version integer NOT NULL,
    digest_version integer NOT NULL,
    normalization_version integer NOT NULL,
    display_value text,
    registration_blocked boolean DEFAULT false NOT NULL,
    attachment_blocked boolean DEFAULT false NOT NULL,
    recovery_blocked boolean DEFAULT false NOT NULL,
    effective_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_org_enforcement_identifier_effects_kind CHECK (((identifier_kind)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'identity_id'::character varying])::text[])))
);


--
-- Name: org_enforcement_identifier_effects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_enforcement_identifier_effects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_enforcement_identifier_effects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_enforcement_identifier_effects_id_seq OWNED BY public.org_enforcement_identifier_effects.id;


--
-- Name: org_enforcement_principal_effects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_enforcement_principal_effects (
    id bigint NOT NULL,
    org_enforcement_case_id bigint NOT NULL,
    principal_public_id character varying NOT NULL,
    access_blocking boolean DEFAULT false NOT NULL,
    recovery_blocked boolean DEFAULT false NOT NULL,
    reactivation_blocked boolean DEFAULT false NOT NULL,
    withdrawal_purge_blocked boolean DEFAULT false NOT NULL,
    principal_hard_delete_blocked boolean DEFAULT false NOT NULL,
    profile_effect character varying,
    effective_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_enforcement_principal_effects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_enforcement_principal_effects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_enforcement_principal_effects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_enforcement_principal_effects_id_seq OWNED BY public.org_enforcement_principal_effects.id;


--
-- Name: org_enforcement_principal_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_enforcement_principal_links (
    id bigint NOT NULL,
    org_enforcement_case_id bigint NOT NULL,
    principal_kind character varying NOT NULL,
    principal_public_id character varying NOT NULL,
    relationship_kind character varying NOT NULL,
    linked_at timestamp(6) with time zone NOT NULL,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_org_enforcement_principal_links_relationship_kind CHECK (((relationship_kind)::text = ANY ((ARRAY['target_principal'::character varying, 'former_principal'::character varying, 'related_principal'::character varying, 'suspected_duplicate'::character varying, 'reinstated_principal'::character varying, 'false_positive'::character varying])::text[])))
);


--
-- Name: org_enforcement_principal_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_enforcement_principal_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_enforcement_principal_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_enforcement_principal_links_id_seq OWNED BY public.org_enforcement_principal_links.id;


--
-- Name: organization_entra_connection_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organization_entra_connection_states (
    id bigint NOT NULL
);


--
-- Name: organization_entra_connection_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organization_entra_connection_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organization_entra_connection_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organization_entra_connection_states_id_seq OWNED BY public.organization_entra_connection_states.id;


--
-- Name: organization_entra_connections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organization_entra_connections (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    organization_id bigint NOT NULL,
    entra_tenant_id character varying(36) NOT NULL,
    entra_client_id character varying(255) NOT NULL,
    status_id bigint DEFAULT 0 NOT NULL,
    last_used_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    entra_credential_key character varying NOT NULL
);


--
-- Name: organization_entra_connections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organization_entra_connections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organization_entra_connections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organization_entra_connections_id_seq OWNED BY public.organization_entra_connections.id;


--
-- Name: organization_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organization_statuses (
    id bigint NOT NULL
);


--
-- Name: organization_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organization_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organization_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organization_statuses_id_seq OWNED BY public.organization_statuses.id;


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations (
    id bigint NOT NULL,
    domain character varying DEFAULT ''::character varying NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    operator_id bigint,
    department_id bigint,
    parent_id bigint,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    workspace_status_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: organizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organizations_id_seq OWNED BY public.organizations.id;


--
-- Name: role_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_assignments (
    id bigint NOT NULL,
    user_id bigint,
    staff_id bigint,
    role_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: role_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.role_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: role_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.role_assignments_id_seq OWNED BY public.role_assignments.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: staff_identity_audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff_identity_audit_events (
    id character varying NOT NULL
);


--
-- Name: staff_identity_audits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff_identity_audits (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    event_id character varying NOT NULL,
    "timestamp" timestamp(6) with time zone,
    ip_address character varying,
    actor_id bigint,
    actor_type character varying,
    previous_value text,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: staff_identity_audits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.staff_identity_audits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_identity_audits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_identity_audits_id_seq OWNED BY public.staff_identity_audits.id;


--
-- Name: staff_identity_passkeys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff_identity_passkeys (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    webauthn_id bytea NOT NULL,
    public_key text NOT NULL,
    description character varying NOT NULL,
    sign_count bigint DEFAULT 0 NOT NULL,
    external_id uuid NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: staff_identity_passkeys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.staff_identity_passkeys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_identity_passkeys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_identity_passkeys_id_seq OWNED BY public.staff_identity_passkeys.id;


--
-- Name: staff_identity_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff_identity_statuses (
    id bigint NOT NULL
);


--
-- Name: staff_identity_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.staff_identity_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_identity_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_identity_statuses_id_seq OWNED BY public.staff_identity_statuses.id;


--
-- Name: staff_operators; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff_operators (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    operator_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: staff_operators_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.staff_operators_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_operators_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_operators_id_seq OWNED BY public.staff_operators.id;


--
-- Name: staff_recovery_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff_recovery_codes (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    recovery_code_digest character varying,
    expires_in date,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: staff_recovery_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.staff_recovery_codes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_recovery_codes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_recovery_codes_id_seq OWNED BY public.staff_recovery_codes.id;


--
-- Name: user_workspaces; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_workspaces (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: user_workspaces_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_workspaces_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_workspaces_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_workspaces_id_seq OWNED BY public.user_workspaces.id;


--
-- Name: workspace_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workspace_statuses (
    id bigint NOT NULL
);


--
-- Name: workspace_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.workspace_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: workspace_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.workspace_statuses_id_seq OWNED BY public.workspace_statuses.id;


--
-- Name: workspaces; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workspaces (
    id bigint NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: workspaces_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.workspaces_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: workspaces_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.workspaces_id_seq OWNED BY public.workspaces.id;


--
-- Name: agent_administration_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_administration_grants ALTER COLUMN id SET DEFAULT nextval('public.agent_administration_grants_id_seq'::regclass);


--
-- Name: agent_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_assignments ALTER COLUMN id SET DEFAULT nextval('public.agent_assignments_id_seq'::regclass);


--
-- Name: agent_authority_cutovers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_authority_cutovers ALTER COLUMN id SET DEFAULT nextval('public.agent_authority_cutovers_id_seq'::regclass);


--
-- Name: agent_delegation_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_delegation_grants ALTER COLUMN id SET DEFAULT nextval('public.agent_delegation_grants_id_seq'::regclass);


--
-- Name: agent_lifecycles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_lifecycles ALTER COLUMN id SET DEFAULT nextval('public.agent_lifecycles_id_seq'::regclass);


--
-- Name: agent_membership_kinds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_membership_kinds ALTER COLUMN id SET DEFAULT nextval('public.agent_membership_kinds_id_seq'::regclass);


--
-- Name: agent_membership_revoke_reasons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_membership_revoke_reasons ALTER COLUMN id SET DEFAULT nextval('public.agent_membership_revoke_reasons_id_seq'::regclass);


--
-- Name: agent_membership_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_membership_states ALTER COLUMN id SET DEFAULT nextval('public.agent_membership_states_id_seq'::regclass);


--
-- Name: agent_memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships ALTER COLUMN id SET DEFAULT nextval('public.agent_memberships_id_seq'::regclass);


--
-- Name: agent_ownership_transfer_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_ownership_transfer_requests ALTER COLUMN id SET DEFAULT nextval('public.agent_ownership_transfer_requests_id_seq'::regclass);


--
-- Name: agent_ownerships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_ownerships ALTER COLUMN id SET DEFAULT nextval('public.agent_ownerships_id_seq'::regclass);


--
-- Name: agent_usage_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_usage_grants ALTER COLUMN id SET DEFAULT nextval('public.agent_usage_grants_id_seq'::regclass);


--
-- Name: agent_view_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_view_grants ALTER COLUMN id SET DEFAULT nextval('public.agent_view_grants_id_seq'::regclass);


--
-- Name: agents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents ALTER COLUMN id SET DEFAULT nextval('public.agents_id_seq'::regclass);


--
-- Name: bureau_administration_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_administration_grants ALTER COLUMN id SET DEFAULT nextval('public.bureau_administration_grants_id_seq'::regclass);


--
-- Name: bureau_authority_cutovers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_authority_cutovers ALTER COLUMN id SET DEFAULT nextval('public.bureau_authority_cutovers_id_seq'::regclass);


--
-- Name: bureau_delegation_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_delegation_grants ALTER COLUMN id SET DEFAULT nextval('public.bureau_delegation_grants_id_seq'::regclass);


--
-- Name: bureau_lifecycles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_lifecycles ALTER COLUMN id SET DEFAULT nextval('public.bureau_lifecycles_id_seq'::regclass);


--
-- Name: bureau_ownership_transfer_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_ownership_transfer_requests ALTER COLUMN id SET DEFAULT nextval('public.bureau_ownership_transfer_requests_id_seq'::regclass);


--
-- Name: bureau_ownerships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_ownerships ALTER COLUMN id SET DEFAULT nextval('public.bureau_ownerships_id_seq'::regclass);


--
-- Name: bureau_unit_closures id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_unit_closures ALTER COLUMN id SET DEFAULT nextval('public.bureau_unit_closures_id_seq'::regclass);


--
-- Name: bureau_units id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_units ALTER COLUMN id SET DEFAULT nextval('public.bureau_units_id_seq'::regclass);


--
-- Name: bureau_view_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_view_grants ALTER COLUMN id SET DEFAULT nextval('public.bureau_view_grants_id_seq'::regclass);


--
-- Name: bureaus id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureaus ALTER COLUMN id SET DEFAULT nextval('public.bureaus_id_seq'::regclass);


--
-- Name: core_org_operator_bridges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.core_org_operator_bridges ALTER COLUMN id SET DEFAULT nextval('public.core_org_operator_bridges_id_seq'::regclass);


--
-- Name: department_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.department_statuses ALTER COLUMN id SET DEFAULT nextval('public.department_statuses_id_seq'::regclass);


--
-- Name: departments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments ALTER COLUMN id SET DEFAULT nextval('public.departments_id_seq'::regclass);


--
-- Name: division_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.division_statuses ALTER COLUMN id SET DEFAULT nextval('public.division_statuses_id_seq'::regclass);


--
-- Name: divisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.divisions ALTER COLUMN id SET DEFAULT nextval('public.divisions_id_seq'::regclass);


--
-- Name: legacy_operator_department_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_operator_department_accounts ALTER COLUMN id SET DEFAULT nextval('public.legacy_operator_department_accounts_id_seq'::regclass);


--
-- Name: operator_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_accounts ALTER COLUMN id SET DEFAULT nextval('public.operator_accounts_id_seq'::regclass);


--
-- Name: operator_authority_locks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_authority_locks ALTER COLUMN id SET DEFAULT nextval('public.operator_authority_locks_id_seq'::regclass);


--
-- Name: operator_banners id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_banners ALTER COLUMN id SET DEFAULT nextval('public.operator_banners_id_seq'::regclass);


--
-- Name: operator_bulletins id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_bulletins ALTER COLUMN id SET DEFAULT nextval('public.operator_bulletins_id_seq'::regclass);


--
-- Name: operator_capability_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_capability_grants ALTER COLUMN id SET DEFAULT nextval('public.operator_capability_grants_id_seq'::regclass);


--
-- Name: operator_email_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_email_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_email_statuses_id_seq'::regclass);


--
-- Name: operator_emails id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_emails ALTER COLUMN id SET DEFAULT nextval('public.operator_emails_id_seq'::regclass);


--
-- Name: operator_entra_identities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_entra_identities ALTER COLUMN id SET DEFAULT nextval('public.operator_entra_identities_id_seq'::regclass);


--
-- Name: operator_entra_identity_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_entra_identity_states ALTER COLUMN id SET DEFAULT nextval('public.operator_entra_identity_states_id_seq'::regclass);


--
-- Name: operator_google_identities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_google_identities ALTER COLUMN id SET DEFAULT nextval('public.operator_google_identities_id_seq'::regclass);


--
-- Name: operator_google_identity_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_google_identity_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_google_identity_statuses_id_seq'::regclass);


--
-- Name: operator_identities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_identities ALTER COLUMN id SET DEFAULT nextval('public.operator_identities_id_seq'::regclass);


--
-- Name: operator_identity_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_identity_states ALTER COLUMN id SET DEFAULT nextval('public.operator_identity_states_id_seq'::regclass);


--
-- Name: operator_lifecycle_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_lifecycle_requests ALTER COLUMN id SET DEFAULT nextval('public.operator_lifecycle_requests_id_seq'::regclass);


--
-- Name: operator_mfa_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_mfa_levels ALTER COLUMN id SET DEFAULT nextval('public.operator_mfa_levels_id_seq'::regclass);


--
-- Name: operator_mfa_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_mfa_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_mfa_statuses_id_seq'::regclass);


--
-- Name: operator_passkey_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkey_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_passkey_statuses_id_seq'::regclass);


--
-- Name: operator_passkeys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkeys ALTER COLUMN id SET DEFAULT nextval('public.operator_passkeys_id_seq'::regclass);


--
-- Name: operator_preference_adult_content_gate_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_adult_content_gate_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_adult_content_gate_options_id_seq'::regclass);


--
-- Name: operator_preference_adult_content_gates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_adult_content_gates ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_adult_content_gates_id_seq'::regclass);


--
-- Name: operator_preference_currencies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_currencies ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_currencies_id_seq'::regclass);


--
-- Name: operator_preference_currency_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_currency_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_currency_options_id_seq'::regclass);


--
-- Name: operator_preference_date_format_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_date_format_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_date_format_options_id_seq'::regclass);


--
-- Name: operator_preference_date_formats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_date_formats ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_date_formats_id_seq'::regclass);


--
-- Name: operator_preference_densities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_densities ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_densities_id_seq'::regclass);


--
-- Name: operator_preference_density_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_density_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_density_options_id_seq'::regclass);


--
-- Name: operator_preference_language_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_language_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_language_options_id_seq'::regclass);


--
-- Name: operator_preference_languages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_languages ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_languages_id_seq'::regclass);


--
-- Name: operator_preference_motion_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_motion_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_motion_options_id_seq'::regclass);


--
-- Name: operator_preference_motions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_motions ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_motions_id_seq'::regclass);


--
-- Name: operator_preference_page_size_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_page_size_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_page_size_options_id_seq'::regclass);


--
-- Name: operator_preference_page_sizes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_page_sizes ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_page_sizes_id_seq'::regclass);


--
-- Name: operator_preference_region_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_region_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_region_options_id_seq'::regclass);


--
-- Name: operator_preference_regions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_regions ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_regions_id_seq'::regclass);


--
-- Name: operator_preference_theme_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_theme_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_theme_options_id_seq'::regclass);


--
-- Name: operator_preference_themes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_themes ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_themes_id_seq'::regclass);


--
-- Name: operator_preference_time_format_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_time_format_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_time_format_options_id_seq'::regclass);


--
-- Name: operator_preference_time_formats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_time_formats ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_time_formats_id_seq'::regclass);


--
-- Name: operator_preference_timezone_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_timezone_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_timezone_options_id_seq'::regclass);


--
-- Name: operator_preference_timezones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_timezones ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_timezones_id_seq'::regclass);


--
-- Name: operator_preferences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preferences ALTER COLUMN id SET DEFAULT nextval('public.operator_preferences_id_seq'::regclass);


--
-- Name: operator_secret_credential_kinds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secret_credential_kinds ALTER COLUMN id SET DEFAULT nextval('public.operator_secret_credential_kinds_id_seq'::regclass);


--
-- Name: operator_secret_credential_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secret_credential_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_secret_credential_statuses_id_seq'::regclass);


--
-- Name: operator_secret_credentials id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secret_credentials ALTER COLUMN id SET DEFAULT nextval('public.operator_secret_credentials_id_seq'::regclass);


--
-- Name: operator_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_statuses_id_seq'::regclass);


--
-- Name: operator_telephone_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_telephone_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_telephone_statuses_id_seq'::regclass);


--
-- Name: operator_telephones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_telephones ALTER COLUMN id SET DEFAULT nextval('public.operator_telephones_id_seq'::regclass);


--
-- Name: operator_visibilities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_visibilities ALTER COLUMN id SET DEFAULT nextval('public.operator_visibilities_id_seq'::regclass);


--
-- Name: operator_workspace_account_memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_workspace_account_memberships ALTER COLUMN id SET DEFAULT nextval('public.operator_workspace_account_memberships_id_seq'::regclass);


--
-- Name: operator_workspace_account_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_workspace_account_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_workspace_account_statuses_id_seq'::regclass);


--
-- Name: operator_workspace_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_workspace_accounts ALTER COLUMN id SET DEFAULT nextval('public.operator_workspace_accounts_id_seq'::regclass);


--
-- Name: operators id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operators ALTER COLUMN id SET DEFAULT nextval('public.operators_id_seq'::regclass);


--
-- Name: org_enforcement_appeals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_enforcement_appeals ALTER COLUMN id SET DEFAULT nextval('public.org_enforcement_appeals_id_seq'::regclass);


--
-- Name: org_enforcement_authentication_method_effects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_enforcement_authentication_method_effects ALTER COLUMN id SET DEFAULT nextval('public.org_enforcement_authentication_method_effects_id_seq'::regclass);


--
-- Name: org_enforcement_cases id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_enforcement_cases ALTER COLUMN id SET DEFAULT nextval('public.org_enforcement_cases_id_seq'::regclass);


--
-- Name: org_enforcement_identifier_effects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_enforcement_identifier_effects ALTER COLUMN id SET DEFAULT nextval('public.org_enforcement_identifier_effects_id_seq'::regclass);


--
-- Name: org_enforcement_principal_effects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_enforcement_principal_effects ALTER COLUMN id SET DEFAULT nextval('public.org_enforcement_principal_effects_id_seq'::regclass);


--
-- Name: org_enforcement_principal_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_enforcement_principal_links ALTER COLUMN id SET DEFAULT nextval('public.org_enforcement_principal_links_id_seq'::regclass);


--
-- Name: organization_entra_connection_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_entra_connection_states ALTER COLUMN id SET DEFAULT nextval('public.organization_entra_connection_states_id_seq'::regclass);


--
-- Name: organization_entra_connections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_entra_connections ALTER COLUMN id SET DEFAULT nextval('public.organization_entra_connections_id_seq'::regclass);


--
-- Name: organization_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_statuses ALTER COLUMN id SET DEFAULT nextval('public.organization_statuses_id_seq'::regclass);


--
-- Name: organizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations ALTER COLUMN id SET DEFAULT nextval('public.organizations_id_seq'::regclass);


--
-- Name: role_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments ALTER COLUMN id SET DEFAULT nextval('public.role_assignments_id_seq'::regclass);


--
-- Name: staff_identity_audits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_identity_audits ALTER COLUMN id SET DEFAULT nextval('public.staff_identity_audits_id_seq'::regclass);


--
-- Name: staff_identity_passkeys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_identity_passkeys ALTER COLUMN id SET DEFAULT nextval('public.staff_identity_passkeys_id_seq'::regclass);


--
-- Name: staff_identity_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_identity_statuses ALTER COLUMN id SET DEFAULT nextval('public.staff_identity_statuses_id_seq'::regclass);


--
-- Name: staff_operators id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_operators ALTER COLUMN id SET DEFAULT nextval('public.staff_operators_id_seq'::regclass);


--
-- Name: staff_recovery_codes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_recovery_codes ALTER COLUMN id SET DEFAULT nextval('public.staff_recovery_codes_id_seq'::regclass);


--
-- Name: user_workspaces id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_workspaces ALTER COLUMN id SET DEFAULT nextval('public.user_workspaces_id_seq'::regclass);


--
-- Name: workspace_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspace_statuses ALTER COLUMN id SET DEFAULT nextval('public.workspace_statuses_id_seq'::regclass);


--
-- Name: workspaces id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspaces ALTER COLUMN id SET DEFAULT nextval('public.workspaces_id_seq'::regclass);


--
-- Name: agent_administration_grants agent_administration_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_administration_grants
    ADD CONSTRAINT agent_administration_grants_pkey PRIMARY KEY (id);


--
-- Name: agent_assignments agent_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_assignments
    ADD CONSTRAINT agent_assignments_pkey PRIMARY KEY (id);


--
-- Name: agent_authority_cutovers agent_authority_cutovers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_authority_cutovers
    ADD CONSTRAINT agent_authority_cutovers_pkey PRIMARY KEY (id);


--
-- Name: agent_delegation_grants agent_delegation_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_delegation_grants
    ADD CONSTRAINT agent_delegation_grants_pkey PRIMARY KEY (id);


--
-- Name: agent_lifecycles agent_lifecycles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_lifecycles
    ADD CONSTRAINT agent_lifecycles_pkey PRIMARY KEY (id);


--
-- Name: agent_membership_kinds agent_membership_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_membership_kinds
    ADD CONSTRAINT agent_membership_kinds_pkey PRIMARY KEY (id);


--
-- Name: agent_membership_revoke_reasons agent_membership_revoke_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_membership_revoke_reasons
    ADD CONSTRAINT agent_membership_revoke_reasons_pkey PRIMARY KEY (id);


--
-- Name: agent_membership_states agent_membership_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_membership_states
    ADD CONSTRAINT agent_membership_states_pkey PRIMARY KEY (id);


--
-- Name: agent_memberships agent_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT agent_memberships_pkey PRIMARY KEY (id);


--
-- Name: agent_ownership_transfer_requests agent_ownership_transfer_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_ownership_transfer_requests
    ADD CONSTRAINT agent_ownership_transfer_requests_pkey PRIMARY KEY (id);


--
-- Name: agent_ownerships agent_ownerships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_ownerships
    ADD CONSTRAINT agent_ownerships_pkey PRIMARY KEY (id);


--
-- Name: agent_usage_grants agent_usage_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_usage_grants
    ADD CONSTRAINT agent_usage_grants_pkey PRIMARY KEY (id);


--
-- Name: agent_view_grants agent_view_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_view_grants
    ADD CONSTRAINT agent_view_grants_pkey PRIMARY KEY (id);


--
-- Name: agents agents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents
    ADD CONSTRAINT agents_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: bureau_administration_grants bureau_administration_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_administration_grants
    ADD CONSTRAINT bureau_administration_grants_pkey PRIMARY KEY (id);


--
-- Name: bureau_authority_cutovers bureau_authority_cutovers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_authority_cutovers
    ADD CONSTRAINT bureau_authority_cutovers_pkey PRIMARY KEY (id);


--
-- Name: bureau_delegation_grants bureau_delegation_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_delegation_grants
    ADD CONSTRAINT bureau_delegation_grants_pkey PRIMARY KEY (id);


--
-- Name: bureau_lifecycles bureau_lifecycles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_lifecycles
    ADD CONSTRAINT bureau_lifecycles_pkey PRIMARY KEY (id);


--
-- Name: bureau_ownership_transfer_requests bureau_ownership_transfer_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_ownership_transfer_requests
    ADD CONSTRAINT bureau_ownership_transfer_requests_pkey PRIMARY KEY (id);


--
-- Name: bureau_ownerships bureau_ownerships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_ownerships
    ADD CONSTRAINT bureau_ownerships_pkey PRIMARY KEY (id);


--
-- Name: bureau_unit_closures bureau_unit_closures_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_unit_closures
    ADD CONSTRAINT bureau_unit_closures_pkey PRIMARY KEY (id);


--
-- Name: bureau_units bureau_units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_units
    ADD CONSTRAINT bureau_units_pkey PRIMARY KEY (id);


--
-- Name: bureau_view_grants bureau_view_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_view_grants
    ADD CONSTRAINT bureau_view_grants_pkey PRIMARY KEY (id);


--
-- Name: bureaus bureaus_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureaus
    ADD CONSTRAINT bureaus_pkey PRIMARY KEY (id);


--
-- Name: operators chk_operators_mfa_requirement_consistency; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.operators
    ADD CONSTRAINT chk_operators_mfa_requirement_consistency CHECK ((((mfa_level_enabled = false) AND (mfa_level_id = 0)) OR ((mfa_level_enabled = true) AND (mfa_level_id <> 0)))) NOT VALID;


--
-- Name: operators chk_operators_withdrawal_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.operators
    ADD CONSTRAINT chk_operators_withdrawal_order CHECK (((withdrawal_started_at IS NULL) OR (withdrawn_at IS NULL) OR (withdrawal_started_at <= withdrawn_at))) NOT VALID;


--
-- Name: core_org_operator_bridges core_org_operator_bridges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.core_org_operator_bridges
    ADD CONSTRAINT core_org_operator_bridges_pkey PRIMARY KEY (id);


--
-- Name: department_statuses department_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.department_statuses
    ADD CONSTRAINT department_statuses_pkey PRIMARY KEY (id);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- Name: division_statuses division_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.division_statuses
    ADD CONSTRAINT division_statuses_pkey PRIMARY KEY (id);


--
-- Name: divisions divisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.divisions
    ADD CONSTRAINT divisions_pkey PRIMARY KEY (id);


--
-- Name: legacy_operator_department_accounts legacy_operator_department_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_operator_department_accounts
    ADD CONSTRAINT legacy_operator_department_accounts_pkey PRIMARY KEY (id);


--
-- Name: operator_accounts operator_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_accounts
    ADD CONSTRAINT operator_accounts_pkey PRIMARY KEY (id);


--
-- Name: operator_authority_locks operator_authority_locks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_authority_locks
    ADD CONSTRAINT operator_authority_locks_pkey PRIMARY KEY (id);


--
-- Name: operator_banners operator_banners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_banners
    ADD CONSTRAINT operator_banners_pkey PRIMARY KEY (id);


--
-- Name: operator_bulletins operator_bulletins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_bulletins
    ADD CONSTRAINT operator_bulletins_pkey PRIMARY KEY (id);


--
-- Name: operator_capability_grants operator_capability_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_capability_grants
    ADD CONSTRAINT operator_capability_grants_pkey PRIMARY KEY (id);


--
-- Name: operator_email_statuses operator_email_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_email_statuses
    ADD CONSTRAINT operator_email_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_emails operator_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_emails
    ADD CONSTRAINT operator_emails_pkey PRIMARY KEY (id);


--
-- Name: operator_entra_identities operator_entra_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_entra_identities
    ADD CONSTRAINT operator_entra_identities_pkey PRIMARY KEY (id);


--
-- Name: operator_entra_identity_states operator_entra_identity_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_entra_identity_states
    ADD CONSTRAINT operator_entra_identity_states_pkey PRIMARY KEY (id);


--
-- Name: operator_google_identities operator_google_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_google_identities
    ADD CONSTRAINT operator_google_identities_pkey PRIMARY KEY (id);


--
-- Name: operator_google_identity_statuses operator_google_identity_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_google_identity_statuses
    ADD CONSTRAINT operator_google_identity_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_identities operator_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_identities
    ADD CONSTRAINT operator_identities_pkey PRIMARY KEY (id);


--
-- Name: operator_identity_states operator_identity_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_identity_states
    ADD CONSTRAINT operator_identity_states_pkey PRIMARY KEY (id);


--
-- Name: operator_lifecycle_requests operator_lifecycle_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_lifecycle_requests
    ADD CONSTRAINT operator_lifecycle_requests_pkey PRIMARY KEY (id);


--
-- Name: operator_mfa_levels operator_mfa_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_mfa_levels
    ADD CONSTRAINT operator_mfa_levels_pkey PRIMARY KEY (id);


--
-- Name: operator_mfa_statuses operator_mfa_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_mfa_statuses
    ADD CONSTRAINT operator_mfa_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_passkey_statuses operator_passkey_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkey_statuses
    ADD CONSTRAINT operator_passkey_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_passkeys operator_passkeys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkeys
    ADD CONSTRAINT operator_passkeys_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_adult_content_gate_options operator_preference_adult_content_gate_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_adult_content_gate_options
    ADD CONSTRAINT operator_preference_adult_content_gate_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_adult_content_gates operator_preference_adult_content_gates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_adult_content_gates
    ADD CONSTRAINT operator_preference_adult_content_gates_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_currencies operator_preference_currencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_currencies
    ADD CONSTRAINT operator_preference_currencies_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_currency_options operator_preference_currency_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_currency_options
    ADD CONSTRAINT operator_preference_currency_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_date_format_options operator_preference_date_format_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_date_format_options
    ADD CONSTRAINT operator_preference_date_format_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_date_formats operator_preference_date_formats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_date_formats
    ADD CONSTRAINT operator_preference_date_formats_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_densities operator_preference_densities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_densities
    ADD CONSTRAINT operator_preference_densities_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_density_options operator_preference_density_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_density_options
    ADD CONSTRAINT operator_preference_density_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_language_options operator_preference_language_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_language_options
    ADD CONSTRAINT operator_preference_language_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_languages operator_preference_languages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_languages
    ADD CONSTRAINT operator_preference_languages_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_motion_options operator_preference_motion_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_motion_options
    ADD CONSTRAINT operator_preference_motion_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_motions operator_preference_motions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_motions
    ADD CONSTRAINT operator_preference_motions_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_page_size_options operator_preference_page_size_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_page_size_options
    ADD CONSTRAINT operator_preference_page_size_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_page_sizes operator_preference_page_sizes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_page_sizes
    ADD CONSTRAINT operator_preference_page_sizes_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_region_options operator_preference_region_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_region_options
    ADD CONSTRAINT operator_preference_region_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_regions operator_preference_regions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_regions
    ADD CONSTRAINT operator_preference_regions_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_theme_options operator_preference_theme_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_theme_options
    ADD CONSTRAINT operator_preference_theme_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_themes operator_preference_themes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_themes
    ADD CONSTRAINT operator_preference_themes_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_time_format_options operator_preference_time_format_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_time_format_options
    ADD CONSTRAINT operator_preference_time_format_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_time_formats operator_preference_time_formats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_time_formats
    ADD CONSTRAINT operator_preference_time_formats_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_timezone_options operator_preference_timezone_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_timezone_options
    ADD CONSTRAINT operator_preference_timezone_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_timezones operator_preference_timezones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_timezones
    ADD CONSTRAINT operator_preference_timezones_pkey PRIMARY KEY (id);


--
-- Name: operator_preferences operator_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preferences
    ADD CONSTRAINT operator_preferences_pkey PRIMARY KEY (id);


--
-- Name: operator_secret_credential_kinds operator_secret_credential_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secret_credential_kinds
    ADD CONSTRAINT operator_secret_credential_kinds_pkey PRIMARY KEY (id);


--
-- Name: operator_secret_credential_statuses operator_secret_credential_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secret_credential_statuses
    ADD CONSTRAINT operator_secret_credential_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_secret_credentials operator_secret_credentials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secret_credentials
    ADD CONSTRAINT operator_secret_credentials_pkey PRIMARY KEY (id);


--
-- Name: operator_statuses operator_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_statuses
    ADD CONSTRAINT operator_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_telephone_statuses operator_telephone_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_telephone_statuses
    ADD CONSTRAINT operator_telephone_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_telephones operator_telephones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_telephones
    ADD CONSTRAINT operator_telephones_pkey PRIMARY KEY (id);


--
-- Name: operator_visibilities operator_visibilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_visibilities
    ADD CONSTRAINT operator_visibilities_pkey PRIMARY KEY (id);


--
-- Name: operator_workspace_account_memberships operator_workspace_account_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_workspace_account_memberships
    ADD CONSTRAINT operator_workspace_account_memberships_pkey PRIMARY KEY (id);


--
-- Name: operator_workspace_account_statuses operator_workspace_account_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_workspace_account_statuses
    ADD CONSTRAINT operator_workspace_account_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_workspace_accounts operator_workspace_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_workspace_accounts
    ADD CONSTRAINT operator_workspace_accounts_pkey PRIMARY KEY (id);


--
-- Name: operators operators_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operators
    ADD CONSTRAINT operators_pkey PRIMARY KEY (id);


--
-- Name: org_enforcement_appeals org_enforcement_appeals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_enforcement_appeals
    ADD CONSTRAINT org_enforcement_appeals_pkey PRIMARY KEY (id);


--
-- Name: org_enforcement_authentication_method_effects org_enforcement_authentication_method_effects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_enforcement_authentication_method_effects
    ADD CONSTRAINT org_enforcement_authentication_method_effects_pkey PRIMARY KEY (id);


--
-- Name: org_enforcement_cases org_enforcement_cases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_enforcement_cases
    ADD CONSTRAINT org_enforcement_cases_pkey PRIMARY KEY (id);


--
-- Name: org_enforcement_identifier_effects org_enforcement_identifier_effects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_enforcement_identifier_effects
    ADD CONSTRAINT org_enforcement_identifier_effects_pkey PRIMARY KEY (id);


--
-- Name: org_enforcement_principal_effects org_enforcement_principal_effects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_enforcement_principal_effects
    ADD CONSTRAINT org_enforcement_principal_effects_pkey PRIMARY KEY (id);


--
-- Name: org_enforcement_principal_links org_enforcement_principal_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_enforcement_principal_links
    ADD CONSTRAINT org_enforcement_principal_links_pkey PRIMARY KEY (id);


--
-- Name: organization_entra_connection_states organization_entra_connection_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_entra_connection_states
    ADD CONSTRAINT organization_entra_connection_states_pkey PRIMARY KEY (id);


--
-- Name: organization_entra_connections organization_entra_connections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_entra_connections
    ADD CONSTRAINT organization_entra_connections_pkey PRIMARY KEY (id);


--
-- Name: organization_statuses organization_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_statuses
    ADD CONSTRAINT organization_statuses_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: role_assignments role_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT role_assignments_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: staff_identity_audit_events staff_identity_audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_identity_audit_events
    ADD CONSTRAINT staff_identity_audit_events_pkey PRIMARY KEY (id);


--
-- Name: staff_identity_audits staff_identity_audits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_identity_audits
    ADD CONSTRAINT staff_identity_audits_pkey PRIMARY KEY (id);


--
-- Name: staff_identity_passkeys staff_identity_passkeys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_identity_passkeys
    ADD CONSTRAINT staff_identity_passkeys_pkey PRIMARY KEY (id);


--
-- Name: staff_identity_statuses staff_identity_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_identity_statuses
    ADD CONSTRAINT staff_identity_statuses_pkey PRIMARY KEY (id);


--
-- Name: staff_operators staff_operators_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_operators
    ADD CONSTRAINT staff_operators_pkey PRIMARY KEY (id);


--
-- Name: staff_recovery_codes staff_recovery_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_recovery_codes
    ADD CONSTRAINT staff_recovery_codes_pkey PRIMARY KEY (id);


--
-- Name: user_workspaces user_workspaces_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_workspaces
    ADD CONSTRAINT user_workspaces_pkey PRIMARY KEY (id);


--
-- Name: workspace_statuses workspace_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspace_statuses
    ADD CONSTRAINT workspace_statuses_pkey PRIMARY KEY (id);


--
-- Name: workspaces workspaces_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspaces
    ADD CONSTRAINT workspaces_pkey PRIMARY KEY (id);


--
-- Name: idx_agent_admin_grants_on_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agent_admin_grants_on_operator_id ON public.agent_administration_grants USING btree (operator_id);


--
-- Name: idx_agent_admin_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_agent_admin_grants_unique ON public.agent_administration_grants USING btree (agent_id, operator_id);


--
-- Name: idx_agent_assignments_one_active_identity_per_agent; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_agent_assignments_one_active_identity_per_agent ON public.agent_assignments USING btree (agent_id, operator_identity_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_agent_delegate_grants_on_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agent_delegate_grants_on_operator_id ON public.agent_delegation_grants USING btree (operator_id);


--
-- Name: idx_agent_delegate_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_agent_delegate_grants_unique ON public.agent_delegation_grants USING btree (agent_id, operator_id);


--
-- Name: idx_agent_lifecycles_one_agent; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_agent_lifecycles_one_agent ON public.agent_lifecycles USING btree (agent_id);


--
-- Name: idx_agent_memberships_one_active_primary; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_agent_memberships_one_active_primary ON public.agent_memberships USING btree (agent_id) WHERE (("primary" = true) AND (revoked_at IS NULL) AND (ends_at IS NULL));


--
-- Name: idx_agent_ownerships_on_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agent_ownerships_on_operator_id ON public.agent_ownerships USING btree (operator_id);


--
-- Name: idx_agent_ownerships_one_resource; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_agent_ownerships_one_resource ON public.agent_ownerships USING btree (agent_id);


--
-- Name: idx_agent_transfer_requests_destination; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agent_transfer_requests_destination ON public.agent_ownership_transfer_requests USING btree (destination_operator_id, status);


--
-- Name: idx_agent_transfer_requests_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agent_transfer_requests_due ON public.agent_ownership_transfer_requests USING btree (status, expires_at);


--
-- Name: idx_agent_transfer_requests_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_agent_transfer_requests_on_public_id ON public.agent_ownership_transfer_requests USING btree (public_id);


--
-- Name: idx_agent_transfer_requests_one_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_agent_transfer_requests_one_pending ON public.agent_ownership_transfer_requests USING btree (agent_id) WHERE ((status)::text = 'pending'::text);


--
-- Name: idx_agent_usage_grants_on_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agent_usage_grants_on_operator_id ON public.agent_usage_grants USING btree (operator_id);


--
-- Name: idx_agent_usage_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_agent_usage_grants_unique ON public.agent_usage_grants USING btree (agent_id, operator_id);


--
-- Name: idx_agent_view_grants_on_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agent_view_grants_on_operator_id ON public.agent_view_grants USING btree (operator_id);


--
-- Name: idx_agent_view_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_agent_view_grants_unique ON public.agent_view_grants USING btree (agent_id, operator_id);


--
-- Name: idx_agents_one_per_operator_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_agents_one_per_operator_identity ON public.agents USING btree (operator_identity_id);


--
-- Name: idx_bureau_admin_grants_on_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bureau_admin_grants_on_operator_id ON public.bureau_administration_grants USING btree (operator_id);


--
-- Name: idx_bureau_admin_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_bureau_admin_grants_unique ON public.bureau_administration_grants USING btree (bureau_id, operator_id);


--
-- Name: idx_bureau_delegate_grants_on_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bureau_delegate_grants_on_operator_id ON public.bureau_delegation_grants USING btree (operator_id);


--
-- Name: idx_bureau_delegate_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_bureau_delegate_grants_unique ON public.bureau_delegation_grants USING btree (bureau_id, operator_id);


--
-- Name: idx_bureau_lifecycles_one_bureau; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_bureau_lifecycles_one_bureau ON public.bureau_lifecycles USING btree (bureau_id);


--
-- Name: idx_bureau_ownerships_on_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bureau_ownerships_on_operator_id ON public.bureau_ownerships USING btree (operator_id);


--
-- Name: idx_bureau_ownerships_one_resource; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_bureau_ownerships_one_resource ON public.bureau_ownerships USING btree (bureau_id);


--
-- Name: idx_bureau_transfer_requests_destination; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bureau_transfer_requests_destination ON public.bureau_ownership_transfer_requests USING btree (destination_operator_id, status);


--
-- Name: idx_bureau_transfer_requests_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bureau_transfer_requests_due ON public.bureau_ownership_transfer_requests USING btree (status, expires_at);


--
-- Name: idx_bureau_transfer_requests_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_bureau_transfer_requests_on_public_id ON public.bureau_ownership_transfer_requests USING btree (public_id);


--
-- Name: idx_bureau_transfer_requests_one_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_bureau_transfer_requests_one_pending ON public.bureau_ownership_transfer_requests USING btree (bureau_id) WHERE ((status)::text = 'pending'::text);


--
-- Name: idx_bureau_unit_closures_unique_path; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_bureau_unit_closures_unique_path ON public.bureau_unit_closures USING btree (ancestor_id, descendant_id);


--
-- Name: idx_bureau_units_id_bureau; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_bureau_units_id_bureau ON public.bureau_units USING btree (id, bureau_id);


--
-- Name: idx_bureau_view_grants_on_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bureau_view_grants_on_operator_id ON public.bureau_view_grants USING btree (operator_id);


--
-- Name: idx_bureau_view_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_bureau_view_grants_unique ON public.bureau_view_grants USING btree (bureau_id, operator_id);


--
-- Name: idx_core_org_operator_bridges_unique_operator_rp; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_core_org_operator_bridges_unique_operator_rp ON public.core_org_operator_bridges USING btree (operator_id, rp_client_id);


--
-- Name: idx_on_org_enforcement_case_id_042cd7e4dd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_org_enforcement_case_id_042cd7e4dd ON public.org_enforcement_principal_links USING btree (org_enforcement_case_id);


--
-- Name: idx_on_org_enforcement_case_id_1bff976c33; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_org_enforcement_case_id_1bff976c33 ON public.org_enforcement_identifier_effects USING btree (org_enforcement_case_id);


--
-- Name: idx_on_org_enforcement_case_id_71c3632903; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_org_enforcement_case_id_71c3632903 ON public.org_enforcement_authentication_method_effects USING btree (org_enforcement_case_id);


--
-- Name: idx_on_org_enforcement_case_id_9c612b7fea; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_org_enforcement_case_id_9c612b7fea ON public.org_enforcement_principal_effects USING btree (org_enforcement_case_id);


--
-- Name: idx_on_staff_identity_secret_status_id_1e2bab9ca1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_staff_identity_secret_status_id_1e2bab9ca1 ON public.operator_secret_credentials USING btree (staff_identity_secret_status_id);


--
-- Name: idx_on_staff_identity_telephone_status_id_6c01767c57; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_staff_identity_telephone_status_id_6c01767c57 ON public.operator_telephones USING btree (staff_identity_telephone_status_id);


--
-- Name: idx_operator_authority_locks_on_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_authority_locks_on_operator_id ON public.operator_authority_locks USING btree (operator_id);


--
-- Name: idx_operator_capability_grants_operator_capability; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operator_capability_grants_operator_capability ON public.operator_capability_grants USING btree (operator_id, capability);


--
-- Name: idx_operator_capability_grants_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_capability_grants_public_id ON public.operator_capability_grants USING btree (public_id);


--
-- Name: idx_operator_capability_grants_unrevoked_capability; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operator_capability_grants_unrevoked_capability ON public.operator_capability_grants USING btree (capability, operator_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_operator_entra_identities_on_tid_and_oid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_entra_identities_on_tid_and_oid ON public.operator_entra_identities USING btree (entra_tenant_id, entra_object_id);


--
-- Name: idx_operator_workspace_memberships_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operator_workspace_memberships_on_account_id ON public.operator_workspace_account_memberships USING btree (operator_workspace_account_id);


--
-- Name: idx_operator_workspace_memberships_on_staff_and_account; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_workspace_memberships_on_staff_and_account ON public.operator_workspace_account_memberships USING btree (staff_id, operator_workspace_account_id);


--
-- Name: idx_org_enforcement_cases_state_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_org_enforcement_cases_state_expires_at ON public.org_enforcement_cases USING btree (state, expires_at);


--
-- Name: idx_org_enforcement_identifier_effects_one_open; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_org_enforcement_identifier_effects_one_open ON public.org_enforcement_identifier_effects USING btree (identifier_kind, lookup_digest) WHERE (ended_at IS NULL);


--
-- Name: idx_org_enforcement_method_effects_one_open_per_method; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_org_enforcement_method_effects_one_open_per_method ON public.org_enforcement_authentication_method_effects USING btree (principal_public_id, authentication_method) WHERE (ended_at IS NULL);


--
-- Name: idx_org_enforcement_principal_effects_principal_open; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_org_enforcement_principal_effects_principal_open ON public.org_enforcement_principal_effects USING btree (principal_public_id, ended_at);


--
-- Name: idx_org_entra_connections_on_org_and_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_org_entra_connections_on_org_and_tenant ON public.organization_entra_connections USING btree (organization_id, entra_tenant_id);


--
-- Name: idx_org_entra_connections_on_tenant_and_client; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_org_entra_connections_on_tenant_and_client ON public.organization_entra_connections USING btree (entra_tenant_id, entra_client_id);


--
-- Name: index_agent_assignments_on_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_assignments_on_agent_id ON public.agent_assignments USING btree (agent_id);


--
-- Name: index_agent_assignments_on_operator_identity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_assignments_on_operator_identity_id ON public.agent_assignments USING btree (operator_identity_id);


--
-- Name: index_agent_assignments_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agent_assignments_on_public_id ON public.agent_assignments USING btree (public_id);


--
-- Name: index_agent_memberships_on_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_memberships_on_agent_id ON public.agent_memberships USING btree (agent_id);


--
-- Name: index_agent_memberships_on_approved_by_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_memberships_on_approved_by_agent_id ON public.agent_memberships USING btree (approved_by_agent_id);


--
-- Name: index_agent_memberships_on_bureau_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_memberships_on_bureau_id ON public.agent_memberships USING btree (bureau_id);


--
-- Name: index_agent_memberships_on_bureau_unit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_memberships_on_bureau_unit_id ON public.agent_memberships USING btree (bureau_unit_id);


--
-- Name: index_agent_memberships_on_granted_by_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_memberships_on_granted_by_agent_id ON public.agent_memberships USING btree (granted_by_agent_id);


--
-- Name: index_agent_memberships_on_membership_kind_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_memberships_on_membership_kind_id ON public.agent_memberships USING btree (membership_kind_id);


--
-- Name: index_agent_memberships_on_membership_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_memberships_on_membership_state_id ON public.agent_memberships USING btree (membership_state_id);


--
-- Name: index_agent_memberships_on_revoke_reason_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_memberships_on_revoke_reason_id ON public.agent_memberships USING btree (revoke_reason_id);


--
-- Name: index_agent_memberships_on_revoked_by_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_memberships_on_revoked_by_agent_id ON public.agent_memberships USING btree (revoked_by_agent_id);


--
-- Name: index_agents_on_operator_identity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agents_on_operator_identity_id ON public.agents USING btree (operator_identity_id);


--
-- Name: index_agents_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agents_on_public_id ON public.agents USING btree (public_id);


--
-- Name: index_bureau_unit_closures_on_descendant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bureau_unit_closures_on_descendant_id ON public.bureau_unit_closures USING btree (descendant_id);


--
-- Name: index_bureau_units_on_bureau_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bureau_units_on_bureau_id ON public.bureau_units USING btree (bureau_id);


--
-- Name: index_bureau_units_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bureau_units_on_parent_id ON public.bureau_units USING btree (parent_id);


--
-- Name: index_bureau_units_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_bureau_units_on_public_id ON public.bureau_units USING btree (public_id);


--
-- Name: index_bureaus_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_bureaus_on_public_id ON public.bureaus USING btree (public_id);


--
-- Name: index_core_org_operator_bridges_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_core_org_operator_bridges_on_public_id ON public.core_org_operator_bridges USING btree (public_id);


--
-- Name: index_departments_on_department_status_id_and_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_departments_on_department_status_id_and_parent_id ON public.departments USING btree (department_status_id, parent_id);


--
-- Name: index_departments_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departments_on_parent_id ON public.departments USING btree (parent_id);


--
-- Name: index_departments_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departments_on_workspace_id ON public.departments USING btree (workspace_id);


--
-- Name: index_divisions_on_division_status_id_and_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_divisions_on_division_status_id_and_organization_id ON public.divisions USING btree (division_status_id, organization_id);


--
-- Name: index_divisions_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_divisions_on_organization_id ON public.divisions USING btree (organization_id);


--
-- Name: index_legacy_operator_department_accounts_on_department_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_legacy_operator_department_accounts_on_department_id ON public.legacy_operator_department_accounts USING btree (department_id);


--
-- Name: index_legacy_operator_department_accounts_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_legacy_operator_department_accounts_on_public_id ON public.legacy_operator_department_accounts USING btree (public_id);


--
-- Name: index_legacy_operator_department_accounts_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_legacy_operator_department_accounts_on_staff_id ON public.legacy_operator_department_accounts USING btree (staff_id);


--
-- Name: index_legacy_operator_department_accounts_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_legacy_operator_department_accounts_on_status_id ON public.legacy_operator_department_accounts USING btree (status_id);


--
-- Name: index_operator_accounts_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_accounts_on_public_id ON public.operator_accounts USING btree (public_id);


--
-- Name: index_operator_accounts_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_accounts_on_staff_id ON public.operator_accounts USING btree (staff_id);


--
-- Name: index_operator_banners_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_banners_on_staff_id ON public.operator_banners USING btree (staff_id);


--
-- Name: index_operator_bulletins_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_bulletins_on_public_id ON public.operator_bulletins USING btree (public_id);


--
-- Name: index_operator_bulletins_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_bulletins_on_staff_id ON public.operator_bulletins USING btree (staff_id);


--
-- Name: index_operator_emails_on_address_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_emails_on_address_digest ON public.operator_emails USING btree (address_digest) WHERE (address_digest IS NOT NULL);


--
-- Name: index_operator_emails_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_emails_on_public_id ON public.operator_emails USING btree (public_id);


--
-- Name: index_operator_emails_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_emails_on_staff_id ON public.operator_emails USING btree (staff_id);


--
-- Name: index_operator_emails_on_staff_identity_email_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_emails_on_staff_identity_email_status_id ON public.operator_emails USING btree (staff_identity_email_status_id);


--
-- Name: index_operator_entra_identities_on_connection_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_entra_identities_on_connection_id ON public.operator_entra_identities USING btree (connection_id);


--
-- Name: index_operator_entra_identities_on_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_entra_identities_on_operator_id ON public.operator_entra_identities USING btree (operator_id);


--
-- Name: index_operator_entra_identities_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_entra_identities_on_public_id ON public.operator_entra_identities USING btree (public_id);


--
-- Name: index_operator_entra_identities_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_entra_identities_on_status_id ON public.operator_entra_identities USING btree (status_id);


--
-- Name: index_operator_google_identities_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_google_identities_on_status_id ON public.operator_google_identities USING btree (status_id);


--
-- Name: index_operator_google_identities_on_token_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_google_identities_on_token_expires_at ON public.operator_google_identities USING btree (token_expires_at);


--
-- Name: index_operator_google_identities_on_uid_and_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_google_identities_on_uid_and_provider ON public.operator_google_identities USING btree (uid, provider);


--
-- Name: index_operator_identities_on_issuer_and_subject_and_audience; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_identities_on_issuer_and_subject_and_audience ON public.operator_identities USING btree (issuer, subject, audience);


--
-- Name: index_operator_identities_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_identities_on_public_id ON public.operator_identities USING btree (public_id);


--
-- Name: index_operator_identities_on_source_record_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_identities_on_source_record_id ON public.operator_identities USING btree (source_record_id);


--
-- Name: index_operator_identities_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_identities_on_status_id ON public.operator_identities USING btree (status_id);


--
-- Name: index_operator_lifecycle_requests_on_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_lifecycle_requests_on_action ON public.operator_lifecycle_requests USING btree (action);


--
-- Name: index_operator_lifecycle_requests_on_approved_by_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_lifecycle_requests_on_approved_by_operator_id ON public.operator_lifecycle_requests USING btree (approved_by_operator_id);


--
-- Name: index_operator_lifecycle_requests_on_executed_by_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_lifecycle_requests_on_executed_by_operator_id ON public.operator_lifecycle_requests USING btree (executed_by_operator_id);


--
-- Name: index_operator_lifecycle_requests_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_lifecycle_requests_on_public_id ON public.operator_lifecycle_requests USING btree (public_id);


--
-- Name: index_operator_lifecycle_requests_on_rejected_by_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_lifecycle_requests_on_rejected_by_operator_id ON public.operator_lifecycle_requests USING btree (rejected_by_operator_id);


--
-- Name: index_operator_lifecycle_requests_on_requested_by_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_lifecycle_requests_on_requested_by_operator_id ON public.operator_lifecycle_requests USING btree (requested_by_operator_id);


--
-- Name: index_operator_lifecycle_requests_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_lifecycle_requests_on_status ON public.operator_lifecycle_requests USING btree (status);


--
-- Name: index_operator_lifecycle_requests_on_target_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_lifecycle_requests_on_target_email ON public.operator_lifecycle_requests USING btree (target_email);


--
-- Name: index_operator_lifecycle_requests_on_target_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_lifecycle_requests_on_target_operator_id ON public.operator_lifecycle_requests USING btree (target_operator_id);


--
-- Name: index_operator_passkeys_on_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_passkeys_on_external_id ON public.operator_passkeys USING btree (external_id);


--
-- Name: index_operator_passkeys_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_passkeys_on_staff_id ON public.operator_passkeys USING btree (staff_id);


--
-- Name: index_operator_passkeys_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_passkeys_on_status_id ON public.operator_passkeys USING btree (status_id);


--
-- Name: index_operator_passkeys_on_webauthn_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_passkeys_on_webauthn_id ON public.operator_passkeys USING btree (webauthn_id);


--
-- Name: index_operator_preference_adult_content_gates_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_adult_content_gates_on_option_id ON public.operator_preference_adult_content_gates USING btree (option_id);


--
-- Name: index_operator_preference_adult_content_gates_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_adult_content_gates_on_preference_id ON public.operator_preference_adult_content_gates USING btree (preference_id);


--
-- Name: index_operator_preference_currencies_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_currencies_on_option_id ON public.operator_preference_currencies USING btree (option_id);


--
-- Name: index_operator_preference_currencies_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_currencies_on_preference_id ON public.operator_preference_currencies USING btree (preference_id);


--
-- Name: index_operator_preference_date_formats_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_date_formats_on_option_id ON public.operator_preference_date_formats USING btree (option_id);


--
-- Name: index_operator_preference_date_formats_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_date_formats_on_preference_id ON public.operator_preference_date_formats USING btree (preference_id);


--
-- Name: index_operator_preference_densities_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_densities_on_option_id ON public.operator_preference_densities USING btree (option_id);


--
-- Name: index_operator_preference_densities_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_densities_on_preference_id ON public.operator_preference_densities USING btree (preference_id);


--
-- Name: index_operator_preference_languages_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_languages_on_option_id ON public.operator_preference_languages USING btree (option_id);


--
-- Name: index_operator_preference_languages_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_languages_on_preference_id ON public.operator_preference_languages USING btree (preference_id);


--
-- Name: index_operator_preference_motions_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_motions_on_option_id ON public.operator_preference_motions USING btree (option_id);


--
-- Name: index_operator_preference_motions_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_motions_on_preference_id ON public.operator_preference_motions USING btree (preference_id);


--
-- Name: index_operator_preference_page_sizes_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_page_sizes_on_option_id ON public.operator_preference_page_sizes USING btree (option_id);


--
-- Name: index_operator_preference_page_sizes_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_page_sizes_on_preference_id ON public.operator_preference_page_sizes USING btree (preference_id);


--
-- Name: index_operator_preference_regions_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_regions_on_option_id ON public.operator_preference_regions USING btree (option_id);


--
-- Name: index_operator_preference_regions_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_regions_on_preference_id ON public.operator_preference_regions USING btree (preference_id);


--
-- Name: index_operator_preference_themes_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_themes_on_option_id ON public.operator_preference_themes USING btree (option_id);


--
-- Name: index_operator_preference_themes_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_themes_on_preference_id ON public.operator_preference_themes USING btree (preference_id);


--
-- Name: index_operator_preference_time_formats_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_time_formats_on_option_id ON public.operator_preference_time_formats USING btree (option_id);


--
-- Name: index_operator_preference_time_formats_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_time_formats_on_preference_id ON public.operator_preference_time_formats USING btree (preference_id);


--
-- Name: index_operator_preference_timezones_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_timezones_on_option_id ON public.operator_preference_timezones USING btree (option_id);


--
-- Name: index_operator_preference_timezones_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_timezones_on_preference_id ON public.operator_preference_timezones USING btree (preference_id);


--
-- Name: index_operator_preferences_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preferences_on_public_id ON public.operator_preferences USING btree (public_id);


--
-- Name: index_operator_preferences_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preferences_on_staff_id ON public.operator_preferences USING btree (staff_id);


--
-- Name: index_operator_secret_credentials_on_lookup_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_secret_credentials_on_lookup_digest ON public.operator_secret_credentials USING btree (lookup_digest);


--
-- Name: index_operator_secret_credentials_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_secret_credentials_on_public_id ON public.operator_secret_credentials USING btree (public_id);


--
-- Name: index_operator_secret_credentials_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_secret_credentials_on_staff_id ON public.operator_secret_credentials USING btree (staff_id);


--
-- Name: index_operator_secret_credentials_on_staff_secret_kind_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_secret_credentials_on_staff_secret_kind_id ON public.operator_secret_credentials USING btree (staff_secret_kind_id);


--
-- Name: index_operator_social_googles_on_staff_id_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_social_googles_on_staff_id_unique ON public.operator_google_identities USING btree (staff_id) WHERE (staff_id IS NOT NULL);


--
-- Name: index_operator_telephones_on_number_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_telephones_on_number_digest ON public.operator_telephones USING btree (number_digest) WHERE (number_digest IS NOT NULL);


--
-- Name: index_operator_telephones_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_telephones_on_staff_id ON public.operator_telephones USING btree (staff_id);


--
-- Name: index_operator_workspace_accounts_on_department_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_workspace_accounts_on_department_id ON public.operator_workspace_accounts USING btree (department_id);


--
-- Name: index_operator_workspace_accounts_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_workspace_accounts_on_public_id ON public.operator_workspace_accounts USING btree (public_id);


--
-- Name: index_operator_workspace_accounts_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_workspace_accounts_on_staff_id ON public.operator_workspace_accounts USING btree (staff_id);


--
-- Name: index_operator_workspace_accounts_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_workspace_accounts_on_status_id ON public.operator_workspace_accounts USING btree (status_id);


--
-- Name: index_operators_on_access_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_access_state ON public.operators USING btree (access_state);


--
-- Name: index_operators_on_admin_locked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_admin_locked_at ON public.operators USING btree (admin_locked_at) WHERE (admin_locked_at IS NOT NULL);


--
-- Name: index_operators_on_deactivated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_deactivated_at ON public.operators USING btree (deactivated_at) WHERE (deactivated_at IS NOT NULL);


--
-- Name: index_operators_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_discard_at ON public.operators USING btree (discard_at);


--
-- Name: index_operators_on_mfa_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_mfa_level_id ON public.operators USING btree (mfa_level_id);


--
-- Name: index_operators_on_mfa_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_mfa_status_id ON public.operators USING btree (mfa_status_id);


--
-- Name: index_operators_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operators_on_public_id ON public.operators USING btree (public_id);


--
-- Name: index_operators_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_purge_eligible_at ON public.operators USING btree (purge_eligible_at);


--
-- Name: index_operators_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_status_id ON public.operators USING btree (status_id);


--
-- Name: index_operators_on_token_valid_after_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_token_valid_after_at ON public.operators USING btree (token_valid_after_at) WHERE (token_valid_after_at IS NOT NULL);


--
-- Name: index_operators_on_visibility_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_visibility_id ON public.operators USING btree (visibility_id);


--
-- Name: index_operators_on_webauthn_user_handle; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operators_on_webauthn_user_handle ON public.operators USING btree (webauthn_user_handle);


--
-- Name: index_operators_on_withdrawal_started_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_withdrawal_started_at ON public.operators USING btree (withdrawal_started_at) WHERE (withdrawal_started_at IS NOT NULL);


--
-- Name: index_operators_on_withdrawn_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_withdrawn_at ON public.operators USING btree (withdrawn_at) WHERE (withdrawn_at IS NOT NULL);


--
-- Name: index_org_enforcement_appeals_on_org_enforcement_case_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_enforcement_appeals_on_org_enforcement_case_id ON public.org_enforcement_appeals USING btree (org_enforcement_case_id);


--
-- Name: index_org_enforcement_appeals_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_enforcement_appeals_on_public_id ON public.org_enforcement_appeals USING btree (public_id);


--
-- Name: index_org_enforcement_cases_on_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_enforcement_cases_on_kind ON public.org_enforcement_cases USING btree (kind);


--
-- Name: index_org_enforcement_cases_on_principal_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_enforcement_cases_on_principal_public_id ON public.org_enforcement_cases USING btree (principal_public_id);


--
-- Name: index_org_enforcement_cases_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_enforcement_cases_on_public_id ON public.org_enforcement_cases USING btree (public_id);


--
-- Name: index_org_enforcement_principal_links_on_principal_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_enforcement_principal_links_on_principal_public_id ON public.org_enforcement_principal_links USING btree (principal_public_id);


--
-- Name: index_organization_entra_connections_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_organization_entra_connections_on_public_id ON public.organization_entra_connections USING btree (public_id);


--
-- Name: index_organization_entra_connections_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organization_entra_connections_on_status_id ON public.organization_entra_connections USING btree (status_id);


--
-- Name: index_organizations_on_department_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organizations_on_department_id ON public.organizations USING btree (department_id);


--
-- Name: index_organizations_on_domain; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_organizations_on_domain ON public.organizations USING btree (domain);


--
-- Name: index_organizations_on_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organizations_on_operator_id ON public.organizations USING btree (operator_id);


--
-- Name: index_organizations_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organizations_on_parent_id ON public.organizations USING btree (parent_id);


--
-- Name: index_organizations_on_workspace_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organizations_on_workspace_status_id ON public.organizations USING btree (workspace_status_id);


--
-- Name: index_role_assignments_on_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_role_assignments_on_role_id ON public.role_assignments USING btree (role_id);


--
-- Name: index_role_assignments_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_role_assignments_on_staff_id ON public.role_assignments USING btree (staff_id);


--
-- Name: index_role_assignments_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_role_assignments_on_user_id ON public.role_assignments USING btree (user_id);


--
-- Name: index_staff_identity_audits_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_identity_audits_on_staff_id ON public.staff_identity_audits USING btree (staff_id);


--
-- Name: index_staff_identity_passkeys_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_identity_passkeys_on_staff_id ON public.staff_identity_passkeys USING btree (staff_id);


--
-- Name: index_staff_identity_passkeys_on_webauthn_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_staff_identity_passkeys_on_webauthn_id ON public.staff_identity_passkeys USING btree (webauthn_id);


--
-- Name: index_staff_operators_on_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_operators_on_operator_id ON public.staff_operators USING btree (operator_id);


--
-- Name: index_staff_operators_on_staff_id_and_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_staff_operators_on_staff_id_and_operator_id ON public.staff_operators USING btree (staff_id, operator_id);


--
-- Name: index_staff_recovery_codes_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_recovery_codes_on_staff_id ON public.staff_recovery_codes USING btree (staff_id);


--
-- Name: index_user_workspaces_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_workspaces_on_user_id ON public.user_workspaces USING btree (user_id);


--
-- Name: index_user_workspaces_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_workspaces_on_workspace_id ON public.user_workspaces USING btree (workspace_id);


--
-- Name: agent_memberships fk_agent_memberships_unit_same_bureau; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT fk_agent_memberships_unit_same_bureau FOREIGN KEY (bureau_unit_id, bureau_id) REFERENCES public.bureau_units(id, bureau_id) ON DELETE RESTRICT NOT VALID;


--
-- Name: bureau_units fk_bureau_units_parent_same_bureau; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_units
    ADD CONSTRAINT fk_bureau_units_parent_same_bureau FOREIGN KEY (parent_id, bureau_id) REFERENCES public.bureau_units(id, bureau_id) ON DELETE RESTRICT NOT VALID;


--
-- Name: departments fk_departments_on_department_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT fk_departments_on_department_status_id FOREIGN KEY (department_status_id) REFERENCES public.department_statuses(id);


--
-- Name: agents fk_rails_00d34c9052; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents
    ADD CONSTRAINT fk_rails_00d34c9052 FOREIGN KEY (operator_identity_id) REFERENCES public.operator_identities(id) ON DELETE RESTRICT NOT VALID;


--
-- Name: staff_recovery_codes fk_rails_02267b87b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_recovery_codes
    ADD CONSTRAINT fk_rails_02267b87b9 FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: organization_entra_connections fk_rails_02a548405f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_entra_connections
    ADD CONSTRAINT fk_rails_02a548405f FOREIGN KEY (status_id) REFERENCES public.organization_entra_connection_states(id);


--
-- Name: agent_memberships fk_rails_05081537eb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT fk_rails_05081537eb FOREIGN KEY (revoke_reason_id) REFERENCES public.agent_membership_revoke_reasons(id) NOT VALID;


--
-- Name: bureau_unit_closures fk_rails_098ea54ffa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_unit_closures
    ADD CONSTRAINT fk_rails_098ea54ffa FOREIGN KEY (descendant_id) REFERENCES public.bureau_units(id);


--
-- Name: org_enforcement_identifier_effects fk_rails_09a3dd541d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_enforcement_identifier_effects
    ADD CONSTRAINT fk_rails_09a3dd541d FOREIGN KEY (org_enforcement_case_id) REFERENCES public.org_enforcement_cases(id);


--
-- Name: bureau_units fk_rails_0eea1d47b8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_units
    ADD CONSTRAINT fk_rails_0eea1d47b8 FOREIGN KEY (bureau_id) REFERENCES public.bureaus(id);


--
-- Name: agent_administration_grants fk_rails_0f0de777a9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_administration_grants
    ADD CONSTRAINT fk_rails_0f0de777a9 FOREIGN KEY (operator_id) REFERENCES public.operators(id);


--
-- Name: operator_preference_densities fk_rails_11379cd530; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_densities
    ADD CONSTRAINT fk_rails_11379cd530 FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: operator_banners fk_rails_12bf867cd7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_banners
    ADD CONSTRAINT fk_rails_12bf867cd7 FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: bureau_view_grants fk_rails_15f83e6c65; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_view_grants
    ADD CONSTRAINT fk_rails_15f83e6c65 FOREIGN KEY (bureau_id) REFERENCES public.bureaus(id);


--
-- Name: operator_entra_identities fk_rails_168298cb60; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_entra_identities
    ADD CONSTRAINT fk_rails_168298cb60 FOREIGN KEY (status_id) REFERENCES public.operator_entra_identity_states(id);


--
-- Name: agent_memberships fk_rails_1a95fbbc46; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT fk_rails_1a95fbbc46 FOREIGN KEY (membership_state_id) REFERENCES public.agent_membership_states(id) NOT VALID;


--
-- Name: operator_authority_locks fk_rails_1ae498ad38; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_authority_locks
    ADD CONSTRAINT fk_rails_1ae498ad38 FOREIGN KEY (operator_id) REFERENCES public.operators(id);


--
-- Name: agent_view_grants fk_rails_1cbda78f11; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_view_grants
    ADD CONSTRAINT fk_rails_1cbda78f11 FOREIGN KEY (operator_id) REFERENCES public.operators(id);


--
-- Name: operator_capability_grants fk_rails_1ddf7a5a54; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_capability_grants
    ADD CONSTRAINT fk_rails_1ddf7a5a54 FOREIGN KEY (operator_id) REFERENCES public.operators(id);


--
-- Name: agent_lifecycles fk_rails_20006af8ea; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_lifecycles
    ADD CONSTRAINT fk_rails_20006af8ea FOREIGN KEY (agent_id) REFERENCES public.agents(id) ON DELETE RESTRICT;


--
-- Name: operator_secret_credentials fk_rails_2386c20852; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secret_credentials
    ADD CONSTRAINT fk_rails_2386c20852 FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: agent_usage_grants fk_rails_24294a28f9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_usage_grants
    ADD CONSTRAINT fk_rails_24294a28f9 FOREIGN KEY (operator_id) REFERENCES public.operators(id);


--
-- Name: operator_capability_grants fk_rails_279297ab86; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_capability_grants
    ADD CONSTRAINT fk_rails_279297ab86 FOREIGN KEY (revoked_by_operator_id) REFERENCES public.operators(id);


--
-- Name: agent_memberships fk_rails_27ba6b71fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT fk_rails_27ba6b71fd FOREIGN KEY (revoked_by_agent_id) REFERENCES public.agents(id) ON DELETE SET NULL NOT VALID;


--
-- Name: operator_preference_page_sizes fk_rails_2b838843e1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_page_sizes
    ADD CONSTRAINT fk_rails_2b838843e1 FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: legacy_operator_department_accounts fk_rails_326fe73dec; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_operator_department_accounts
    ADD CONSTRAINT fk_rails_326fe73dec FOREIGN KEY (status_id) REFERENCES public.operator_workspace_account_statuses(id);


--
-- Name: operator_preference_time_formats fk_rails_3308cb70a8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_time_formats
    ADD CONSTRAINT fk_rails_3308cb70a8 FOREIGN KEY (option_id) REFERENCES public.operator_preference_time_format_options(id);


--
-- Name: agent_memberships fk_rails_35c0a01ca1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT fk_rails_35c0a01ca1 FOREIGN KEY (bureau_unit_id) REFERENCES public.bureau_units(id);


--
-- Name: operator_preference_motions fk_rails_364d1205de; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_motions
    ADD CONSTRAINT fk_rails_364d1205de FOREIGN KEY (option_id) REFERENCES public.operator_preference_motion_options(id);


--
-- Name: staff_identity_audits fk_rails_37d8b99dd1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_identity_audits
    ADD CONSTRAINT fk_rails_37d8b99dd1 FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: bureau_administration_grants fk_rails_39b1edafa1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_administration_grants
    ADD CONSTRAINT fk_rails_39b1edafa1 FOREIGN KEY (bureau_id) REFERENCES public.bureaus(id);


--
-- Name: bureau_administration_grants fk_rails_39bbf2d359; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_administration_grants
    ADD CONSTRAINT fk_rails_39bbf2d359 FOREIGN KEY (operator_id) REFERENCES public.operators(id);


--
-- Name: operator_preference_date_formats fk_rails_3a3eaf6cd5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_date_formats
    ADD CONSTRAINT fk_rails_3a3eaf6cd5 FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: bureau_delegation_grants fk_rails_3bd7cd429a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_delegation_grants
    ADD CONSTRAINT fk_rails_3bd7cd429a FOREIGN KEY (bureau_id) REFERENCES public.bureaus(id);


--
-- Name: agent_ownership_transfer_requests fk_rails_3c2999ce68; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_ownership_transfer_requests
    ADD CONSTRAINT fk_rails_3c2999ce68 FOREIGN KEY (source_operator_id) REFERENCES public.operators(id);


--
-- Name: bureau_delegation_grants fk_rails_3fe9ef9ac8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_delegation_grants
    ADD CONSTRAINT fk_rails_3fe9ef9ac8 FOREIGN KEY (operator_id) REFERENCES public.operators(id);


--
-- Name: agent_ownership_transfer_requests fk_rails_43c4a8aea5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_ownership_transfer_requests
    ADD CONSTRAINT fk_rails_43c4a8aea5 FOREIGN KEY (destination_operator_id) REFERENCES public.operators(id);


--
-- Name: operator_bulletins fk_rails_447185451c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_bulletins
    ADD CONSTRAINT fk_rails_447185451c FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: role_assignments fk_rails_4572e29aaa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_rails_4572e29aaa FOREIGN KEY (staff_id) REFERENCES public.operators(id) ON DELETE CASCADE;


--
-- Name: operator_passkeys fk_rails_45b43df39a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkeys
    ADD CONSTRAINT fk_rails_45b43df39a FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: operator_workspace_account_memberships fk_rails_46775ba732; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_workspace_account_memberships
    ADD CONSTRAINT fk_rails_46775ba732 FOREIGN KEY (operator_workspace_account_id) REFERENCES public.operator_workspace_accounts(id) ON DELETE CASCADE NOT VALID;


--
-- Name: org_enforcement_authentication_method_effects fk_rails_46912ae025; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_enforcement_authentication_method_effects
    ADD CONSTRAINT fk_rails_46912ae025 FOREIGN KEY (org_enforcement_case_id) REFERENCES public.org_enforcement_cases(id);


--
-- Name: staff_operators fk_rails_4701fc0635; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_operators
    ADD CONSTRAINT fk_rails_4701fc0635 FOREIGN KEY (operator_id) REFERENCES public.legacy_operator_department_accounts(id) ON DELETE CASCADE;


--
-- Name: agent_ownerships fk_rails_4b33560992; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_ownerships
    ADD CONSTRAINT fk_rails_4b33560992 FOREIGN KEY (agent_id) REFERENCES public.agents(id);


--
-- Name: legacy_operator_department_accounts fk_rails_4d1b310c86; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_operator_department_accounts
    ADD CONSTRAINT fk_rails_4d1b310c86 FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE SET NULL;


--
-- Name: bureau_lifecycles fk_rails_50cebacdd7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_lifecycles
    ADD CONSTRAINT fk_rails_50cebacdd7 FOREIGN KEY (bureau_id) REFERENCES public.bureaus(id) ON DELETE RESTRICT;


--
-- Name: org_enforcement_principal_links fk_rails_522f837e23; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_enforcement_principal_links
    ADD CONSTRAINT fk_rails_522f837e23 FOREIGN KEY (org_enforcement_case_id) REFERENCES public.org_enforcement_cases(id);


--
-- Name: operator_telephones fk_rails_52c0d3ae3b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_telephones
    ADD CONSTRAINT fk_rails_52c0d3ae3b FOREIGN KEY (staff_identity_telephone_status_id) REFERENCES public.operator_telephone_statuses(id);


--
-- Name: operators fk_rails_5525188c4e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operators
    ADD CONSTRAINT fk_rails_5525188c4e FOREIGN KEY (status_id) REFERENCES public.operator_statuses(id);


--
-- Name: agent_memberships fk_rails_598d6fdb3c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT fk_rails_598d6fdb3c FOREIGN KEY (approved_by_agent_id) REFERENCES public.agents(id) ON DELETE SET NULL NOT VALID;


--
-- Name: agent_view_grants fk_rails_5dedc25034; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_view_grants
    ADD CONSTRAINT fk_rails_5dedc25034 FOREIGN KEY (agent_id) REFERENCES public.agents(id);


--
-- Name: departments fk_rails_61e60f394e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT fk_rails_61e60f394e FOREIGN KEY (workspace_id) REFERENCES public.organizations(id) ON DELETE SET NULL;


--
-- Name: operators fk_rails_64606abff9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operators
    ADD CONSTRAINT fk_rails_64606abff9 FOREIGN KEY (visibility_id) REFERENCES public.operator_visibilities(id);


--
-- Name: divisions fk_rails_648c512956; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.divisions
    ADD CONSTRAINT fk_rails_648c512956 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: agent_ownership_transfer_requests fk_rails_64a8510f03; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_ownership_transfer_requests
    ADD CONSTRAINT fk_rails_64a8510f03 FOREIGN KEY (agent_id) REFERENCES public.agents(id);


--
-- Name: agent_memberships fk_rails_684fa8a568; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT fk_rails_684fa8a568 FOREIGN KEY (bureau_id) REFERENCES public.bureaus(id);


--
-- Name: staff_identity_passkeys fk_rails_6a3a38c0e0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_identity_passkeys
    ADD CONSTRAINT fk_rails_6a3a38c0e0 FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: org_enforcement_appeals fk_rails_6a88e9a573; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_enforcement_appeals
    ADD CONSTRAINT fk_rails_6a88e9a573 FOREIGN KEY (org_enforcement_case_id) REFERENCES public.org_enforcement_cases(id);


--
-- Name: legacy_operator_department_accounts fk_rails_6ec07db706; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_operator_department_accounts
    ADD CONSTRAINT fk_rails_6ec07db706 FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: operator_preference_motions fk_rails_706f69bad6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_motions
    ADD CONSTRAINT fk_rails_706f69bad6 FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: agent_administration_grants fk_rails_7715710071; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_administration_grants
    ADD CONSTRAINT fk_rails_7715710071 FOREIGN KEY (agent_id) REFERENCES public.agents(id);


--
-- Name: bureau_ownership_transfer_requests fk_rails_7d1bffe5f3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_ownership_transfer_requests
    ADD CONSTRAINT fk_rails_7d1bffe5f3 FOREIGN KEY (destination_operator_id) REFERENCES public.operators(id);


--
-- Name: agent_memberships fk_rails_80322cea57; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT fk_rails_80322cea57 FOREIGN KEY (agent_id) REFERENCES public.agents(id);


--
-- Name: operators fk_rails_894ffe7965; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operators
    ADD CONSTRAINT fk_rails_894ffe7965 FOREIGN KEY (mfa_level_id) REFERENCES public.operator_mfa_levels(id);


--
-- Name: operator_capability_grants fk_rails_8c98d78c9c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_capability_grants
    ADD CONSTRAINT fk_rails_8c98d78c9c FOREIGN KEY (granted_by_operator_id) REFERENCES public.operators(id);


--
-- Name: organizations fk_rails_8ca3ef141d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT fk_rails_8ca3ef141d FOREIGN KEY (workspace_status_id) REFERENCES public.organization_statuses(id);


--
-- Name: operator_identities fk_rails_8d441d6c30; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_identities
    ADD CONSTRAINT fk_rails_8d441d6c30 FOREIGN KEY (status_id) REFERENCES public.operator_identity_states(id);


--
-- Name: departments fk_rails_8e1e5764fc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT fk_rails_8e1e5764fc FOREIGN KEY (parent_id) REFERENCES public.departments(id);


--
-- Name: agent_assignments fk_rails_8e7ef4f5e0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_assignments
    ADD CONSTRAINT fk_rails_8e7ef4f5e0 FOREIGN KEY (agent_id) REFERENCES public.agents(id);


--
-- Name: operator_preference_time_formats fk_rails_8e89db7603; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_time_formats
    ADD CONSTRAINT fk_rails_8e89db7603 FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: operator_secret_credentials fk_rails_8f8aed461a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secret_credentials
    ADD CONSTRAINT fk_rails_8f8aed461a FOREIGN KEY (staff_identity_secret_status_id) REFERENCES public.operator_secret_credential_statuses(id);


--
-- Name: operator_preference_adult_content_gates fk_rails_939f6081bd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_adult_content_gates
    ADD CONSTRAINT fk_rails_939f6081bd FOREIGN KEY (option_id) REFERENCES public.operator_preference_adult_content_gate_options(id);


--
-- Name: user_workspaces fk_rails_93a47871ac; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_workspaces
    ADD CONSTRAINT fk_rails_93a47871ac FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id);


--
-- Name: operator_preferences fk_rails_9b2a21cc23; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preferences
    ADD CONSTRAINT fk_rails_9b2a21cc23 FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: agent_delegation_grants fk_rails_a613aea5c6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_delegation_grants
    ADD CONSTRAINT fk_rails_a613aea5c6 FOREIGN KEY (agent_id) REFERENCES public.agents(id);


--
-- Name: operator_preference_densities fk_rails_aa06cb648f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_densities
    ADD CONSTRAINT fk_rails_aa06cb648f FOREIGN KEY (option_id) REFERENCES public.operator_preference_density_options(id);


--
-- Name: agent_delegation_grants fk_rails_af3f549b82; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_delegation_grants
    ADD CONSTRAINT fk_rails_af3f549b82 FOREIGN KEY (operator_id) REFERENCES public.operators(id);


--
-- Name: operator_emails fk_rails_b0310624d3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_emails
    ADD CONSTRAINT fk_rails_b0310624d3 FOREIGN KEY (staff_identity_email_status_id) REFERENCES public.operator_email_statuses(id);


--
-- Name: operator_passkeys fk_rails_b17ae8dc5f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkeys
    ADD CONSTRAINT fk_rails_b17ae8dc5f FOREIGN KEY (status_id) REFERENCES public.operator_passkey_statuses(id);


--
-- Name: operator_google_identities fk_rails_b2b4364acf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_google_identities
    ADD CONSTRAINT fk_rails_b2b4364acf FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: bureau_units fk_rails_b69a74fbbb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_units
    ADD CONSTRAINT fk_rails_b69a74fbbb FOREIGN KEY (parent_id) REFERENCES public.bureau_units(id);


--
-- Name: bureau_ownership_transfer_requests fk_rails_b92efe9d3e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_ownership_transfer_requests
    ADD CONSTRAINT fk_rails_b92efe9d3e FOREIGN KEY (bureau_id) REFERENCES public.bureaus(id);


--
-- Name: bureau_view_grants fk_rails_b9ffdcc451; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_view_grants
    ADD CONSTRAINT fk_rails_b9ffdcc451 FOREIGN KEY (operator_id) REFERENCES public.operators(id);


--
-- Name: operator_lifecycle_requests fk_rails_be7647e7b5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_lifecycle_requests
    ADD CONSTRAINT fk_rails_be7647e7b5 FOREIGN KEY (requested_by_operator_id) REFERENCES public.operators(id) ON DELETE RESTRICT NOT VALID;


--
-- Name: operator_preference_date_formats fk_rails_c106156372; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_date_formats
    ADD CONSTRAINT fk_rails_c106156372 FOREIGN KEY (option_id) REFERENCES public.operator_preference_date_format_options(id);


--
-- Name: operator_preference_currencies fk_rails_c2649c3bf6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_currencies
    ADD CONSTRAINT fk_rails_c2649c3bf6 FOREIGN KEY (option_id) REFERENCES public.operator_preference_currency_options(id);


--
-- Name: bureau_ownership_transfer_requests fk_rails_c9ed7857b3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_ownership_transfer_requests
    ADD CONSTRAINT fk_rails_c9ed7857b3 FOREIGN KEY (source_operator_id) REFERENCES public.operators(id);


--
-- Name: staff_operators fk_rails_cab1284f5e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_operators
    ADD CONSTRAINT fk_rails_cab1284f5e FOREIGN KEY (staff_id) REFERENCES public.operators(id) ON DELETE CASCADE;


--
-- Name: operator_emails fk_rails_cceb4b91db; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_emails
    ADD CONSTRAINT fk_rails_cceb4b91db FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: bureau_ownerships fk_rails_cd57c4dfff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_ownerships
    ADD CONSTRAINT fk_rails_cd57c4dfff FOREIGN KEY (bureau_id) REFERENCES public.bureaus(id);


--
-- Name: staff_identity_audits fk_rails_ce4872192d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_identity_audits
    ADD CONSTRAINT fk_rails_ce4872192d FOREIGN KEY (event_id) REFERENCES public.staff_identity_audit_events(id);


--
-- Name: operators fk_rails_cfd2f37948; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operators
    ADD CONSTRAINT fk_rails_cfd2f37948 FOREIGN KEY (mfa_status_id) REFERENCES public.operator_mfa_statuses(id);


--
-- Name: operator_preference_adult_content_gates fk_rails_d26854a062; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_adult_content_gates
    ADD CONSTRAINT fk_rails_d26854a062 FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: bureau_unit_closures fk_rails_d60846037f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_unit_closures
    ADD CONSTRAINT fk_rails_d60846037f FOREIGN KEY (ancestor_id) REFERENCES public.bureau_units(id);


--
-- Name: agent_usage_grants fk_rails_d644767a23; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_usage_grants
    ADD CONSTRAINT fk_rails_d644767a23 FOREIGN KEY (agent_id) REFERENCES public.agents(id);


--
-- Name: operator_preference_page_sizes fk_rails_d9a9bd2617; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_page_sizes
    ADD CONSTRAINT fk_rails_d9a9bd2617 FOREIGN KEY (option_id) REFERENCES public.operator_preference_page_size_options(id);


--
-- Name: bureau_ownerships fk_rails_daa086582f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_ownerships
    ADD CONSTRAINT fk_rails_daa086582f FOREIGN KEY (operator_id) REFERENCES public.operators(id);


--
-- Name: operator_google_identities fk_rails_db81b40794; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_google_identities
    ADD CONSTRAINT fk_rails_db81b40794 FOREIGN KEY (status_id) REFERENCES public.operator_google_identity_statuses(id);


--
-- Name: operator_telephones fk_rails_e5ae4ba106; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_telephones
    ADD CONSTRAINT fk_rails_e5ae4ba106 FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: agent_assignments fk_rails_eb2707f41c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_assignments
    ADD CONSTRAINT fk_rails_eb2707f41c FOREIGN KEY (operator_identity_id) REFERENCES public.operator_identities(id);


--
-- Name: agent_memberships fk_rails_ed6c87c035; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT fk_rails_ed6c87c035 FOREIGN KEY (membership_kind_id) REFERENCES public.agent_membership_kinds(id) NOT VALID;


--
-- Name: divisions fk_rails_eec18b8ece; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.divisions
    ADD CONSTRAINT fk_rails_eec18b8ece FOREIGN KEY (division_status_id) REFERENCES public.division_statuses(id);


--
-- Name: operator_preference_currencies fk_rails_f0cfc52f69; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_currencies
    ADD CONSTRAINT fk_rails_f0cfc52f69 FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: org_enforcement_principal_effects fk_rails_facb871ecd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_enforcement_principal_effects
    ADD CONSTRAINT fk_rails_facb871ecd FOREIGN KEY (org_enforcement_case_id) REFERENCES public.org_enforcement_cases(id);


--
-- Name: agent_ownerships fk_rails_fb3bddbf4e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_ownerships
    ADD CONSTRAINT fk_rails_fb3bddbf4e FOREIGN KEY (operator_id) REFERENCES public.operators(id);


--
-- Name: agent_memberships fk_rails_feb3a1d9a5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT fk_rails_feb3a1d9a5 FOREIGN KEY (granted_by_agent_id) REFERENCES public.agents(id) ON DELETE SET NULL NOT VALID;


--
-- Name: operator_preference_languages fk_staff_preference_languages_on_option_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_languages
    ADD CONSTRAINT fk_staff_preference_languages_on_option_id FOREIGN KEY (option_id) REFERENCES public.operator_preference_language_options(id);


--
-- Name: operator_preference_languages fk_staff_preference_languages_on_preference_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_languages
    ADD CONSTRAINT fk_staff_preference_languages_on_preference_id FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: operator_preference_regions fk_staff_preference_regions_on_option_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_regions
    ADD CONSTRAINT fk_staff_preference_regions_on_option_id FOREIGN KEY (option_id) REFERENCES public.operator_preference_region_options(id);


--
-- Name: operator_preference_regions fk_staff_preference_regions_on_preference_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_regions
    ADD CONSTRAINT fk_staff_preference_regions_on_preference_id FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: operator_preference_themes fk_staff_preference_themes_on_option_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_themes
    ADD CONSTRAINT fk_staff_preference_themes_on_option_id FOREIGN KEY (option_id) REFERENCES public.operator_preference_theme_options(id);


--
-- Name: operator_preference_themes fk_staff_preference_themes_on_preference_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_themes
    ADD CONSTRAINT fk_staff_preference_themes_on_preference_id FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: operator_preference_timezones fk_staff_preference_timezones_on_option_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_timezones
    ADD CONSTRAINT fk_staff_preference_timezones_on_option_id FOREIGN KEY (option_id) REFERENCES public.operator_preference_timezone_options(id);


--
-- Name: operator_preference_timezones fk_staff_preference_timezones_on_preference_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_timezones
    ADD CONSTRAINT fk_staff_preference_timezones_on_preference_id FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: operator_secret_credentials fk_staff_secrets_on_staff_secret_kind_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secret_credentials
    ADD CONSTRAINT fk_staff_secrets_on_staff_secret_kind_id FOREIGN KEY (staff_secret_kind_id) REFERENCES public.operator_secret_credential_kinds(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260926120000'),
('20260923180002'),
('20260923170002'),
('20260921133000'),
('20260917120002'),
('20260831064103'),
('20260830120000'),
('20260811190000'),
('20260731120000'),
('20260729120000'),
('20260727120004'),
('20260727120003'),
('20260727120002'),
('20260727120001'),
('20260727120000'),
('20260721090000'),
('20260719100001'),
('20260719100000'),
('20260630000005'),
('20260630000004'),
('20260630000003'),
('20260630000002'),
('20260630000001'),
('20260627000001'),
('20260626000004'),
('20260626000003'),
('20260626000002'),
('20260626000001'),
('20260623100000'),
('20260616150020'),
('20260616150010'),
('20260616150006'),
('20260616150005'),
('20260616150003'),
('20260614090001'),
('20260614090000'),
('20260612100000'),
('20260612000001'),
('20260530032400'),
('20260530032100'),
('20260530031000'),
('20260528162001'),
('20260526130002'),
('20260526090000'),
('20260521120000'),
('20260520193000'),
('20260520143102'),
('20260520143008'),
('20260520143002'),
('20260520133002'),
('20260520120002'),
('20260519172002'),
('20260519161001'),
('20260518181001'),
('20260518181000'),
('20260518180000'),
('20260518170001'),
('20260518170000'),
('20260518163000'),
('20260518130001'),
('20260518130000'),
('20260514153000'),
('20260514143000'),
('20260514140000'),
('20260514113000'),
('20260514100000'),
('20260513161000'),
('20260512111000'),
('20260512103100'),
('20260511223500'),
('20260511223458'),
('20260511223457'),
('20260511090001'),
('20260509120000'),
('20260508160000'),
('20260508151000'),
('20260508140999'),
('20260508140931'),
('20260508135006'),
('20260507000006'),
('20260507000005'),
('20260507000004'),
('20260507000003'),
('20260507000001'),
('20260506210800'),
('20260506020000'),
('20260329151000'),
('20260329084522'),
('20260323013709'),
('20260323000000'),
('20260319125136'),
('20260318035440'),
('20260312120000'),
('20260311130000'),
('20260311120000'),
('20260309000001'),
('20260307121000'),
('20260305000000'),
('20260226150001'),
('20260226130001'),
('20260213150001'),
('20260212000003'),
('20260210100000'),
('20260208193100'),
('20260208180001'),
('20260205150000'),
('20260204170001'),
('20260204120000'),
('20260203172000'),
('20260202260000'),
('20260202250000'),
('20260202230000'),
('20260202220000'),
('20260202210000'),
('20260202200301'),
('20260202200100'),
('20260202200000'),
('20260202170000'),
('20260201214320'),
('20260201210002'),
('20260201200004'),
('20260201200003'),
('20260201200002'),
('20260201190010'),
('20260130130001'),
('20260122130001'),
('20260122130000'),
('20260121195628'),
('20260121184600'),
('20260121141943'),
('20260121141942'),
('20260121141941'),
('20260121141859'),
('20260121083251'),
('20260121083249'),
('20260121083247'),
('20260114120236'),
('20260110194100'),
('20260109141212'),
('20260108100600'),
('20260106120001'),
('20260106110001'),
('20260103133001'),
('20260103133000'),
('20260103122221'),
('20260103122100'),
('20260103120000'),
('20260103062756'),
('20260103054521'),
('20260103054520'),
('20260103053821'),
('20260103053820'),
('20260103053811'),
('20260103053810'),
('20260103053759'),
('20260103053507'),
('20260103053506'),
('20260103052010'),
('20260103050111'),
('20260103050110'),
('20260103050101'),
('20260103050100'),
('20260102100036'),
('20260102100035'),
('20260102035351'),
('20260102035129'),
('20260102035128'),
('20260102035007'),
('20260102034918'),
('20260102034859'),
('20260102034858'),
('20260102034808'),
('20260102030400'),
('20260102030339'),
('20260102030316'),
('20260102030012'),
('20260102025820'),
('20260102025200'),
('20251230170007'),
('20251230170004'),
('20251230150020'),
('20251230150000'),
('20251230145339'),
('20251230145324'),
('20251230140828'),
('20251230133000'),
('20251230103825'),
('20251230092048'),
('20251230092046'),
('20251230090000'),
('20251230080020'),
('20251230072241'),
('20251230072240'),
('20251230072230'),
('20251230045000'),
('20251230020000'),
('20251230010101'),
('20251228000005'),
('20251226020999'),
('20251226013001'),
('20251226000000'),
('20251225213915'),
('20251225183100'),
('20251224190000'),
('20251224173429'),
('20251224173001'),
('20251224172001'),
('20251224165000'),
('20251224164001'),
('20251224162001'),
('20251224161001'),
('20251224155900'),
('20251224154200'),
('20251224152200'),
('20251224140100'),
('20251224130000'),
('20251224123200'),
('20251224122000'),
('20251222215659'),
('20251222212001'),
('20251221133000'),
('20251221121101'),
('20251221121100'),
('20251221121000'),
('20251220091500'),
('20251218130512'),
('20251218130511'),
('20251218130510'),
('20251214134055'),
('20251213160234'),
('20251213154735'),
('20251213153924'),
('20251212163548'),
('20251212163541'),
('20251212163540'),
('20251211170001'),
('20251211164122'),
('20251211164106'),
('20251211164051'),
('20251211164035'),
('20251211090000'),
('20251211075547'),
('20251211075546'),
('20251209143000'),
('20251209133000'),
('20251209020000'),
('20251209014634'),
('20251208230200'),
('20251208230132'),
('20251208223235'),
('20251208211240'),
('20251208210549'),
('20251208054612'),
('20251115083000'),
('20251115082000'),
('20251115073000'),
('20251115071000'),
('20251115060000'),
('20250808064848'),
('20250801193449'),
('20250504005603'),
('20250429234634'),
('20250429231841'),
('20240827130202');

