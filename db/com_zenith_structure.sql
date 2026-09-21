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
-- Name: action_push_native_devices; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.action_push_native_devices (
    id bigint NOT NULL,
    name character varying,
    platform character varying NOT NULL,
    token character varying NOT NULL,
    owner_type character varying,
    owner_id bigint,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: action_push_native_devices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.action_push_native_devices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: action_push_native_devices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.action_push_native_devices_id_seq OWNED BY public.action_push_native_devices.id;


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
-- Name: com_enforcement_appeals; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.com_enforcement_appeals (
    id bigint NOT NULL,
    com_enforcement_case_id bigint NOT NULL,
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
    CONSTRAINT chk_com_enforcement_appeals_state CHECK (((state)::text = ANY ((ARRAY['submitted'::character varying, 'under_review'::character varying, 'approved'::character varying, 'rejected'::character varying, 'redacted'::character varying])::text[])))
);


--
-- Name: com_enforcement_appeals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.com_enforcement_appeals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_enforcement_appeals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_enforcement_appeals_id_seq OWNED BY public.com_enforcement_appeals.id;


--
-- Name: com_enforcement_authentication_method_effects; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.com_enforcement_authentication_method_effects (
    id bigint NOT NULL,
    com_enforcement_case_id bigint NOT NULL,
    principal_public_id character varying NOT NULL,
    authentication_method character varying NOT NULL,
    effect character varying NOT NULL,
    effective_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_com_enforcement_method_effects_effect CHECK (((effect)::text = ANY ((ARRAY['mutation_locked'::character varying, 'unusable'::character varying, 'permanently_frozen'::character varying])::text[]))),
    CONSTRAINT chk_com_enforcement_method_effects_method CHECK (((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying])::text[])))
);


--
-- Name: com_enforcement_authentication_method_effects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.com_enforcement_authentication_method_effects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_enforcement_authentication_method_effects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_enforcement_authentication_method_effects_id_seq OWNED BY public.com_enforcement_authentication_method_effects.id;


--
-- Name: com_enforcement_cases; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.com_enforcement_cases (
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
    CONSTRAINT chk_com_enforcement_cases_approval_separation CHECK (((approved_by_operator_public_id IS NULL) OR ((approved_by_operator_public_id)::text <> (applied_by_operator_public_id)::text))),
    CONSTRAINT chk_com_enforcement_cases_break_glass_approver CHECK (((break_glass = false) OR (break_glass_approved_by_operator_public_id IS NOT NULL))),
    CONSTRAINT chk_com_enforcement_cases_cooldown_duration CHECK ((((kind)::text <> 'cooldown'::text) OR (((duration_mode)::text = 'timed'::text) AND (expires_at IS NOT NULL) AND (expires_at <= (effective_at + '30 days'::interval))))),
    CONSTRAINT chk_com_enforcement_cases_duration_mode CHECK (((duration_mode)::text = ANY ((ARRAY['timed'::character varying, 'indefinite'::character varying, 'permanent'::character varying])::text[]))),
    CONSTRAINT chk_com_enforcement_cases_end_reason CHECK (((end_reason IS NULL) OR ((end_reason)::text = ANY ((ARRAY['expired'::character varying, 'revoked'::character varying, 'superseded'::character varying, 'corrected'::character varying, 'appeal_approved'::character varying, 'break_glass_released'::character varying, 'verification_completed'::character varying])::text[])))),
    CONSTRAINT chk_com_enforcement_cases_hidden CHECK ((((visibility)::text <> 'hidden'::text) OR ((kind)::text = 'permanent_ban'::text))),
    CONSTRAINT chk_com_enforcement_cases_indefinite_freeze_review CHECK ((((kind)::text <> 'temporary_freeze'::text) OR ((duration_mode)::text <> 'indefinite'::text) OR ((review_due_at IS NOT NULL) AND ((release_mode)::text = 'operator'::text)))),
    CONSTRAINT chk_com_enforcement_cases_kind CHECK (((kind)::text = ANY ((ARRAY['security_lock'::character varying, 'cooldown'::character varying, 'temporary_freeze'::character varying, 'permanent_ban'::character varying, 'method_protection'::character varying])::text[]))),
    CONSTRAINT chk_com_enforcement_cases_no_self_action CHECK (((principal_public_id)::text <> (applied_by_operator_public_id)::text)),
    CONSTRAINT chk_com_enforcement_cases_permanent_ban_duration CHECK ((((kind)::text <> 'permanent_ban'::text) OR (((duration_mode)::text = 'permanent'::text) AND (expires_at IS NULL)))),
    CONSTRAINT chk_com_enforcement_cases_release_mode CHECK (((release_mode)::text = ANY ((ARRAY['automatic'::character varying, 'operator'::character varying, 'verification_required'::character varying, 'break_glass_only'::character varying])::text[]))),
    CONSTRAINT chk_com_enforcement_cases_security_lock_release CHECK ((((kind)::text <> 'security_lock'::text) OR ((release_mode)::text = 'verification_required'::text))),
    CONSTRAINT chk_com_enforcement_cases_state CHECK (((state)::text = ANY ((ARRAY['draft'::character varying, 'pending_approval'::character varying, 'active'::character varying, 'ended'::character varying, 'failed'::character varying])::text[]))),
    CONSTRAINT chk_com_enforcement_cases_temp_freeze_duration_mode CHECK ((((kind)::text <> 'temporary_freeze'::text) OR ((duration_mode)::text = ANY ((ARRAY['timed'::character varying, 'indefinite'::character varying])::text[])))),
    CONSTRAINT chk_com_enforcement_cases_visibility CHECK (((visibility)::text = ANY ((ARRAY['visible'::character varying, 'hidden'::character varying])::text[])))
);


--
-- Name: com_enforcement_cases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.com_enforcement_cases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_enforcement_cases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_enforcement_cases_id_seq OWNED BY public.com_enforcement_cases.id;


--
-- Name: com_enforcement_identifier_effects; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.com_enforcement_identifier_effects (
    id bigint NOT NULL,
    com_enforcement_case_id bigint NOT NULL,
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
    CONSTRAINT chk_com_enforcement_identifier_effects_kind CHECK (((identifier_kind)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'identity_id'::character varying])::text[])))
);


--
-- Name: com_enforcement_identifier_effects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.com_enforcement_identifier_effects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_enforcement_identifier_effects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_enforcement_identifier_effects_id_seq OWNED BY public.com_enforcement_identifier_effects.id;


--
-- Name: com_enforcement_principal_effects; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.com_enforcement_principal_effects (
    id bigint NOT NULL,
    com_enforcement_case_id bigint NOT NULL,
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
-- Name: com_enforcement_principal_effects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.com_enforcement_principal_effects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_enforcement_principal_effects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_enforcement_principal_effects_id_seq OWNED BY public.com_enforcement_principal_effects.id;


--
-- Name: com_enforcement_principal_links; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.com_enforcement_principal_links (
    id bigint NOT NULL,
    com_enforcement_case_id bigint NOT NULL,
    principal_kind character varying NOT NULL,
    principal_public_id character varying NOT NULL,
    relationship_kind character varying NOT NULL,
    linked_at timestamp(6) with time zone NOT NULL,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_com_enforcement_principal_links_relationship_kind CHECK (((relationship_kind)::text = ANY ((ARRAY['target_principal'::character varying, 'former_principal'::character varying, 'related_principal'::character varying, 'suspected_duplicate'::character varying, 'reinstated_principal'::character varying, 'false_positive'::character varying])::text[])))
);


--
-- Name: com_enforcement_principal_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.com_enforcement_principal_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_enforcement_principal_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_enforcement_principal_links_id_seq OWNED BY public.com_enforcement_principal_links.id;


--
-- Name: companies; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.companies (
    id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    title character varying NOT NULL
);


--
-- Name: companies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.companies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: companies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.companies_id_seq OWNED BY public.companies.id;


--
-- Name: company_administration_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.company_administration_grants (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    visitor_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: company_administration_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.company_administration_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: company_administration_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.company_administration_grants_id_seq OWNED BY public.company_administration_grants.id;


--
-- Name: company_delegation_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.company_delegation_grants (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    visitor_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: company_delegation_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.company_delegation_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: company_delegation_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.company_delegation_grants_id_seq OWNED BY public.company_delegation_grants.id;


--
-- Name: company_ownership_transfer_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.company_ownership_transfer_requests (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    source_visitor_id bigint NOT NULL,
    destination_visitor_id bigint NOT NULL,
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
    CONSTRAINT chk_company_transfer_requests_distinct_parties CHECK ((source_visitor_id <> destination_visitor_id)),
    CONSTRAINT chk_company_transfer_requests_expiry_after_request CHECK ((requested_at < expires_at)),
    CONSTRAINT chk_company_transfer_requests_revision_nonnegative CHECK ((expected_ownership_revision >= 0)),
    CONSTRAINT chk_company_transfer_requests_status CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'accepted'::character varying, 'rejected'::character varying, 'cancelled'::character varying, 'expired'::character varying, 'invalidated'::character varying])::text[])))
);


--
-- Name: company_ownership_transfer_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.company_ownership_transfer_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: company_ownership_transfer_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.company_ownership_transfer_requests_id_seq OWNED BY public.company_ownership_transfer_requests.id;


--
-- Name: company_ownerships; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.company_ownerships (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    visitor_id bigint NOT NULL,
    ownership_revision integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_company_ownerships_revision_nonnegative CHECK ((ownership_revision >= 0))
);


--
-- Name: company_ownerships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.company_ownerships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: company_ownerships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.company_ownerships_id_seq OWNED BY public.company_ownerships.id;


--
-- Name: company_unit_closures; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.company_unit_closures (
    id bigint NOT NULL,
    ancestor_id bigint NOT NULL,
    descendant_id bigint NOT NULL,
    depth integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_company_unit_closures_depth_matches_self CHECK ((((ancestor_id = descendant_id) AND (depth = 0)) OR ((ancestor_id <> descendant_id) AND (depth > 0)))),
    CONSTRAINT chk_company_unit_closures_depth_nonnegative CHECK ((depth >= 0))
);


--
-- Name: company_unit_closures_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.company_unit_closures_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: company_unit_closures_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.company_unit_closures_id_seq OWNED BY public.company_unit_closures.id;


--
-- Name: company_units; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.company_units (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    parent_id bigint,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: company_units_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.company_units_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: company_units_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.company_units_id_seq OWNED BY public.company_units.id;


--
-- Name: company_view_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.company_view_grants (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    visitor_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: company_view_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.company_view_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: company_view_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.company_view_grants_id_seq OWNED BY public.company_view_grants.id;


--
-- Name: core_com_visitor_bridges; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.core_com_visitor_bridges (
    id bigint NOT NULL,
    visitor_id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    rp_client_id character varying DEFAULT 'core_com'::character varying NOT NULL,
    audience character varying DEFAULT 'umaxica-core-com'::character varying NOT NULL,
    host character varying DEFAULT 'jpx.umaxica.com'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: core_com_visitor_bridges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.core_com_visitor_bridges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: core_com_visitor_bridges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.core_com_visitor_bridges_id_seq OWNED BY public.core_com_visitor_bridges.id;


--
-- Name: individual_administration_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.individual_administration_grants (
    id bigint NOT NULL,
    individual_id bigint NOT NULL,
    visitor_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: individual_administration_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.individual_administration_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_administration_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_administration_grants_id_seq OWNED BY public.individual_administration_grants.id;


--
-- Name: individual_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.individual_assignments (
    id bigint NOT NULL,
    public_id character varying NOT NULL,
    individual_id bigint NOT NULL,
    visitor_identity_id bigint NOT NULL,
    assigned_at timestamp(6) with time zone NOT NULL,
    revoked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: individual_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.individual_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_assignments_id_seq OWNED BY public.individual_assignments.id;


--
-- Name: individual_delegation_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.individual_delegation_grants (
    id bigint NOT NULL,
    individual_id bigint NOT NULL,
    visitor_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: individual_delegation_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.individual_delegation_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_delegation_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_delegation_grants_id_seq OWNED BY public.individual_delegation_grants.id;


--
-- Name: individual_membership_kinds; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.individual_membership_kinds (
    id bigint NOT NULL
);


--
-- Name: individual_membership_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.individual_membership_kinds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_membership_kinds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_membership_kinds_id_seq OWNED BY public.individual_membership_kinds.id;


--
-- Name: individual_membership_revoke_reasons; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.individual_membership_revoke_reasons (
    id bigint NOT NULL
);


--
-- Name: individual_membership_revoke_reasons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.individual_membership_revoke_reasons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_membership_revoke_reasons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_membership_revoke_reasons_id_seq OWNED BY public.individual_membership_revoke_reasons.id;


--
-- Name: individual_membership_states; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.individual_membership_states (
    id bigint NOT NULL
);


--
-- Name: individual_membership_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.individual_membership_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_membership_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_membership_states_id_seq OWNED BY public.individual_membership_states.id;


--
-- Name: individual_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.individual_memberships (
    id bigint NOT NULL,
    individual_id bigint NOT NULL,
    company_id bigint NOT NULL,
    company_unit_id bigint NOT NULL,
    membership_kind_id bigint DEFAULT 0 NOT NULL,
    membership_state_id bigint DEFAULT 0 NOT NULL,
    "primary" boolean DEFAULT false NOT NULL,
    starts_at timestamp(6) with time zone,
    ends_at timestamp(6) with time zone,
    granted_by_individual_id bigint,
    approved_by_individual_id bigint,
    revoked_by_individual_id bigint,
    revoked_at timestamp(6) with time zone,
    revoke_reason_id bigint,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: individual_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.individual_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_memberships_id_seq OWNED BY public.individual_memberships.id;


--
-- Name: individual_ownership_transfer_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.individual_ownership_transfer_requests (
    id bigint NOT NULL,
    individual_id bigint NOT NULL,
    source_visitor_id bigint NOT NULL,
    destination_visitor_id bigint NOT NULL,
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
    CONSTRAINT chk_individual_transfer_requests_distinct_parties CHECK ((source_visitor_id <> destination_visitor_id)),
    CONSTRAINT chk_individual_transfer_requests_expiry_after_request CHECK ((requested_at < expires_at)),
    CONSTRAINT chk_individual_transfer_requests_revision_nonnegative CHECK ((expected_ownership_revision >= 0)),
    CONSTRAINT chk_individual_transfer_requests_status CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'accepted'::character varying, 'rejected'::character varying, 'cancelled'::character varying, 'expired'::character varying, 'invalidated'::character varying])::text[])))
);


--
-- Name: individual_ownership_transfer_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.individual_ownership_transfer_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_ownership_transfer_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_ownership_transfer_requests_id_seq OWNED BY public.individual_ownership_transfer_requests.id;


--
-- Name: individual_ownerships; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.individual_ownerships (
    id bigint NOT NULL,
    individual_id bigint NOT NULL,
    visitor_id bigint NOT NULL,
    ownership_revision integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_individual_ownerships_revision_nonnegative CHECK ((ownership_revision >= 0))
);


--
-- Name: individual_ownerships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.individual_ownerships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_ownerships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_ownerships_id_seq OWNED BY public.individual_ownerships.id;


--
-- Name: individual_usage_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.individual_usage_grants (
    id bigint NOT NULL,
    individual_id bigint NOT NULL,
    visitor_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: individual_usage_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.individual_usage_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_usage_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_usage_grants_id_seq OWNED BY public.individual_usage_grants.id;


--
-- Name: individual_view_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.individual_view_grants (
    id bigint NOT NULL,
    individual_id bigint NOT NULL,
    visitor_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: individual_view_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.individual_view_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_view_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_view_grants_id_seq OWNED BY public.individual_view_grants.id;


--
-- Name: individuals; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.individuals (
    id bigint NOT NULL,
    visitor_identity_id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    moniker character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    title character varying NOT NULL
);


--
-- Name: individuals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.individuals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individuals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individuals_id_seq OWNED BY public.individuals.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: visitor_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_accounts (
    id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    visitor_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_accounts_id_seq OWNED BY public.visitor_accounts.id;


--
-- Name: visitor_authority_locks; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_authority_locks (
    id bigint NOT NULL,
    visitor_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_authority_locks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_authority_locks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_authority_locks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_authority_locks_id_seq OWNED BY public.visitor_authority_locks.id;


--
-- Name: visitor_banners; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_banners (
    id bigint NOT NULL,
    visitor_id bigint NOT NULL,
    title character varying DEFAULT ''::character varying NOT NULL,
    body text NOT NULL,
    published boolean DEFAULT false NOT NULL,
    starts_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    ends_at timestamp(6) with time zone DEFAULT '9999-12-31 23:59:59+00'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT visitor_banners_ends_at_after_starts_at CHECK ((ends_at > starts_at))
);


--
-- Name: visitor_banners_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_banners_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_banners_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_banners_id_seq OWNED BY public.visitor_banners.id;


--
-- Name: visitor_email_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_email_statuses (
    id bigint NOT NULL
);


--
-- Name: visitor_email_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_email_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_email_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_email_statuses_id_seq OWNED BY public.visitor_email_statuses.id;


--
-- Name: visitor_emails; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_emails (
    id bigint NOT NULL,
    address character varying DEFAULT ''::character varying NOT NULL,
    address_digest character varying,
    locked_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    otp_attempts_count integer DEFAULT 0 NOT NULL,
    otp_counter text DEFAULT ''::text NOT NULL,
    otp_expires_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    otp_last_sent_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    otp_private_key character varying DEFAULT ''::character varying NOT NULL,
    undeletable boolean DEFAULT false NOT NULL,
    verification_token_digest bytea,
    public_id character varying(21) NOT NULL,
    visitor_id bigint NOT NULL,
    visitor_email_status_id bigint DEFAULT 1 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    promotional boolean DEFAULT true NOT NULL,
    notifiable boolean DEFAULT true NOT NULL,
    subscribable boolean DEFAULT true NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL
);


--
-- Name: visitor_emails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_emails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_emails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_emails_id_seq OWNED BY public.visitor_emails.id;


--
-- Name: visitor_enforcement_recovery_ceremonies; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_enforcement_recovery_ceremonies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    visitor_id bigint NOT NULL,
    status_id integer DEFAULT 1 NOT NULL,
    token_digest bytea NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    ip_digest bytea,
    user_agent_digest bytea,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_enforcement_recovery_ceremonies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_enforcement_recovery_ceremonies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_enforcement_recovery_ceremonies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_enforcement_recovery_ceremonies_id_seq OWNED BY public.visitor_enforcement_recovery_ceremonies.id;


--
-- Name: visitor_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_identities (
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
-- Name: visitor_identities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_identities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_identities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_identities_id_seq OWNED BY public.visitor_identities.id;


--
-- Name: visitor_identity_states; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_identity_states (
    id bigint NOT NULL
);


--
-- Name: visitor_identity_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_identity_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_identity_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_identity_states_id_seq OWNED BY public.visitor_identity_states.id;


--
-- Name: visitor_mfa_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_mfa_levels (
    id bigint NOT NULL
);


--
-- Name: visitor_mfa_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_mfa_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_mfa_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_mfa_levels_id_seq OWNED BY public.visitor_mfa_levels.id;


--
-- Name: visitor_mfa_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_mfa_statuses (
    id bigint NOT NULL
);


--
-- Name: visitor_mfa_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_mfa_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_mfa_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_mfa_statuses_id_seq OWNED BY public.visitor_mfa_statuses.id;


--
-- Name: visitor_passkey_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_passkey_statuses (
    id bigint NOT NULL
);


--
-- Name: visitor_passkey_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_passkey_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_passkey_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_passkey_statuses_id_seq OWNED BY public.visitor_passkey_statuses.id;


--
-- Name: visitor_passkeys; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_passkeys (
    id bigint NOT NULL,
    description character varying DEFAULT ''::character varying NOT NULL,
    external_id uuid NOT NULL,
    last_used_at timestamp(6) with time zone,
    public_key text NOT NULL,
    sign_count bigint DEFAULT 0 NOT NULL,
    public_id character varying(21) NOT NULL,
    webauthn_id character varying DEFAULT ''::character varying NOT NULL,
    visitor_id bigint NOT NULL,
    status_id bigint DEFAULT 1 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
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
-- Name: visitor_passkeys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_passkeys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_passkeys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_passkeys_id_seq OWNED BY public.visitor_passkeys.id;


--
-- Name: visitor_preference_adult_content_gate_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_adult_content_gate_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_adult_content_gate_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_adult_content_gate_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_adult_content_gate_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_adult_content_gate_options_id_seq OWNED BY public.visitor_preference_adult_content_gate_options.id;


--
-- Name: visitor_preference_adult_content_gates; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_adult_content_gates (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_adult_content_gates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_adult_content_gates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_adult_content_gates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_adult_content_gates_id_seq OWNED BY public.visitor_preference_adult_content_gates.id;


--
-- Name: visitor_preference_currencies; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_currencies (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_currencies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_currencies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_currencies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_currencies_id_seq OWNED BY public.visitor_preference_currencies.id;


--
-- Name: visitor_preference_currency_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_currency_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_currency_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_currency_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_currency_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_currency_options_id_seq OWNED BY public.visitor_preference_currency_options.id;


--
-- Name: visitor_preference_date_format_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_date_format_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_date_format_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_date_format_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_date_format_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_date_format_options_id_seq OWNED BY public.visitor_preference_date_format_options.id;


--
-- Name: visitor_preference_date_formats; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_date_formats (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_date_formats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_date_formats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_date_formats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_date_formats_id_seq OWNED BY public.visitor_preference_date_formats.id;


--
-- Name: visitor_preference_densities; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_densities (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_densities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_densities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_densities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_densities_id_seq OWNED BY public.visitor_preference_densities.id;


--
-- Name: visitor_preference_density_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_density_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_density_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_density_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_density_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_density_options_id_seq OWNED BY public.visitor_preference_density_options.id;


--
-- Name: visitor_preference_language_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_language_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_language_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_language_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_language_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_language_options_id_seq OWNED BY public.visitor_preference_language_options.id;


--
-- Name: visitor_preference_languages; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_languages (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_languages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_languages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_languages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_languages_id_seq OWNED BY public.visitor_preference_languages.id;


--
-- Name: visitor_preference_motion_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_motion_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_motion_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_motion_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_motion_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_motion_options_id_seq OWNED BY public.visitor_preference_motion_options.id;


--
-- Name: visitor_preference_motions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_motions (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_motions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_motions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_motions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_motions_id_seq OWNED BY public.visitor_preference_motions.id;


--
-- Name: visitor_preference_page_size_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_page_size_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_page_size_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_page_size_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_page_size_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_page_size_options_id_seq OWNED BY public.visitor_preference_page_size_options.id;


--
-- Name: visitor_preference_page_sizes; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_page_sizes (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_page_sizes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_page_sizes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_page_sizes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_page_sizes_id_seq OWNED BY public.visitor_preference_page_sizes.id;


--
-- Name: visitor_preference_region_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_region_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_region_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_region_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_region_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_region_options_id_seq OWNED BY public.visitor_preference_region_options.id;


--
-- Name: visitor_preference_regions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_regions (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_regions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_regions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_regions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_regions_id_seq OWNED BY public.visitor_preference_regions.id;


--
-- Name: visitor_preference_theme_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_theme_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_theme_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_theme_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_theme_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_theme_options_id_seq OWNED BY public.visitor_preference_theme_options.id;


--
-- Name: visitor_preference_themes; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_themes (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_themes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_themes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_themes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_themes_id_seq OWNED BY public.visitor_preference_themes.id;


--
-- Name: visitor_preference_time_format_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_time_format_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_time_format_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_time_format_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_time_format_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_time_format_options_id_seq OWNED BY public.visitor_preference_time_format_options.id;


--
-- Name: visitor_preference_time_formats; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_time_formats (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_time_formats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_time_formats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_time_formats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_time_formats_id_seq OWNED BY public.visitor_preference_time_formats.id;


--
-- Name: visitor_preference_timezone_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_timezone_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_timezone_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_timezone_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_timezone_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_timezone_options_id_seq OWNED BY public.visitor_preference_timezone_options.id;


--
-- Name: visitor_preference_timezones; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_timezones (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_timezones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_timezones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_timezones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_timezones_id_seq OWNED BY public.visitor_preference_timezones.id;


--
-- Name: visitor_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preferences (
    id bigint NOT NULL,
    visitor_id bigint NOT NULL,
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
    currency character varying DEFAULT 'jpy'::character varying NOT NULL,
    date_format character varying DEFAULT 'iso'::character varying NOT NULL,
    time_format character varying DEFAULT '24'::character varying NOT NULL,
    motion character varying DEFAULT 'standard'::character varying NOT NULL,
    density character varying DEFAULT 'standard'::character varying NOT NULL,
    page_size character varying DEFAULT 'infinity'::character varying NOT NULL,
    public_id character varying(21),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    explicit_fields jsonb DEFAULT '[]'::jsonb
);


--
-- Name: visitor_preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preferences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preferences_id_seq OWNED BY public.visitor_preferences.id;


--
-- Name: visitor_privacy_request_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_privacy_request_statuses (
    id bigint NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL
);


--
-- Name: visitor_privacy_request_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_privacy_request_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_privacy_request_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_privacy_request_statuses_id_seq OWNED BY public.visitor_privacy_request_statuses.id;


--
-- Name: visitor_privacy_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_privacy_requests (
    id bigint NOT NULL,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    visitor_id bigint NOT NULL,
    request_kind character varying DEFAULT 'erasure'::character varying NOT NULL,
    jurisdiction character varying DEFAULT 'unknown'::character varying NOT NULL,
    request_source character varying DEFAULT 'self_service'::character varying NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    received_at timestamp(6) with time zone NOT NULL,
    verified_at timestamp(6) with time zone,
    processing_started_at timestamp(6) with time zone,
    response_due_at timestamp(6) with time zone NOT NULL,
    extended_until timestamp(6) with time zone,
    completed_at timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    denial_reason character varying DEFAULT ''::character varying NOT NULL,
    retention_exception_code character varying DEFAULT ''::character varying NOT NULL,
    legal_hold_blocked_at timestamp(6) with time zone,
    final_response_sent_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_visitor_privacy_requests_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: visitor_privacy_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_privacy_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_privacy_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_privacy_requests_id_seq OWNED BY public.visitor_privacy_requests.id;


--
-- Name: visitor_processor_erasure_notification_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_processor_erasure_notification_statuses (
    id bigint NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL
);


--
-- Name: visitor_processor_erasure_notification_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_processor_erasure_notification_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_processor_erasure_notification_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_processor_erasure_notification_statuses_id_seq OWNED BY public.visitor_processor_erasure_notification_statuses.id;


--
-- Name: visitor_processor_erasure_notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_processor_erasure_notifications (
    id bigint NOT NULL,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    visitor_privacy_request_id bigint NOT NULL,
    processor_key character varying DEFAULT ''::character varying NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    requested_at timestamp(6) with time zone NOT NULL,
    notified_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    last_error_code character varying DEFAULT ''::character varying NOT NULL,
    last_error_message character varying DEFAULT ''::character varying NOT NULL,
    retry_count integer DEFAULT 0 NOT NULL,
    next_retry_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_visitor_proc_erase_notifications_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: visitor_processor_erasure_notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_processor_erasure_notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_processor_erasure_notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_processor_erasure_notifications_id_seq OWNED BY public.visitor_processor_erasure_notifications.id;


--
-- Name: visitor_retention_hold_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_retention_hold_statuses (
    id bigint NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL
);


--
-- Name: visitor_retention_hold_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_retention_hold_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_retention_hold_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_retention_hold_statuses_id_seq OWNED BY public.visitor_retention_hold_statuses.id;


--
-- Name: visitor_retention_holds; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_retention_holds (
    id bigint NOT NULL,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    visitor_id bigint NOT NULL,
    hold_kind character varying DEFAULT 'legal_hold'::character varying NOT NULL,
    reason_code character varying DEFAULT 'legal_hold'::character varying NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    applied_at timestamp(6) with time zone NOT NULL,
    released_at timestamp(6) with time zone,
    expires_at timestamp(6) with time zone,
    applied_by_type character varying DEFAULT ''::character varying NOT NULL,
    applied_by_public_id character varying DEFAULT ''::character varying NOT NULL,
    memo character varying DEFAULT ''::character varying NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_visitor_retention_holds_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: visitor_retention_holds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_retention_holds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_retention_holds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_retention_holds_id_seq OWNED BY public.visitor_retention_holds.id;


--
-- Name: visitor_secret_credential_kinds; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_secret_credential_kinds (
    id bigint NOT NULL
);


--
-- Name: visitor_secret_credential_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_secret_credential_kinds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_secret_credential_kinds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_secret_credential_kinds_id_seq OWNED BY public.visitor_secret_credential_kinds.id;


--
-- Name: visitor_secret_credential_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_secret_credential_statuses (
    id bigint NOT NULL
);


--
-- Name: visitor_secret_credential_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_secret_credential_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_secret_credential_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_secret_credential_statuses_id_seq OWNED BY public.visitor_secret_credential_statuses.id;


--
-- Name: visitor_secret_credentials; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_secret_credentials (
    id bigint NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    password_digest character varying DEFAULT ''::character varying NOT NULL,
    last_used_at timestamp(6) with time zone,
    uses_remaining integer DEFAULT 1 NOT NULL,
    public_id character varying(21) NOT NULL,
    visitor_id bigint NOT NULL,
    visitor_secret_credential_status_id bigint DEFAULT 1 NOT NULL,
    visitor_secret_credential_kind_id bigint DEFAULT 1 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
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
    CONSTRAINT chk_customer_secrets_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: visitor_secret_credentials_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_secret_credentials_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_secret_credentials_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_secret_credentials_id_seq OWNED BY public.visitor_secret_credentials.id;


--
-- Name: visitor_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_statuses (
    id bigint NOT NULL
);


--
-- Name: visitor_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_statuses_id_seq OWNED BY public.visitor_statuses.id;


--
-- Name: visitor_telephone_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_telephone_statuses (
    id bigint NOT NULL
);


--
-- Name: visitor_telephone_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_telephone_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_telephone_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_telephone_statuses_id_seq OWNED BY public.visitor_telephone_statuses.id;


--
-- Name: visitor_telephones; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_telephones (
    id bigint NOT NULL,
    number character varying DEFAULT ''::character varying NOT NULL,
    number_digest character varying,
    locked_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    otp_attempts_count integer DEFAULT 0 NOT NULL,
    otp_counter text DEFAULT ''::text NOT NULL,
    otp_expires_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    otp_private_key character varying DEFAULT ''::character varying NOT NULL,
    public_id character varying(21) NOT NULL,
    visitor_id bigint NOT NULL,
    visitor_telephone_status_id bigint DEFAULT 1 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL
);


--
-- Name: visitor_telephones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_telephones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_telephones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_telephones_id_seq OWNED BY public.visitor_telephones.id;


--
-- Name: visitor_visibilities; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_visibilities (
    id bigint NOT NULL
);


--
-- Name: visitor_visibilities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_visibilities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_visibilities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_visibilities_id_seq OWNED BY public.visitor_visibilities.id;


--
-- Name: visitor_withdrawal_ceremonies; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_withdrawal_ceremonies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    visitor_id bigint NOT NULL,
    purpose character varying NOT NULL,
    status_id integer DEFAULT 1 NOT NULL,
    token_digest bytea NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    ip_digest bytea,
    user_agent_digest bytea,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_withdrawal_ceremonies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_withdrawal_ceremonies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_withdrawal_ceremonies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_withdrawal_ceremonies_id_seq OWNED BY public.visitor_withdrawal_ceremonies.id;


--
-- Name: visitor_withdrawal_flow_events; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_withdrawal_flow_events (
    id bigint NOT NULL,
    visitor_withdrawal_flow_id bigint NOT NULL,
    visitor_id bigint NOT NULL,
    from_status_id bigint,
    to_status_id bigint NOT NULL,
    occurred_at timestamp(6) with time zone NOT NULL,
    token_public_id character varying(64) DEFAULT ''::character varying NOT NULL,
    reason character varying(64) DEFAULT ''::character varying NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_withdrawal_flow_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_withdrawal_flow_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_withdrawal_flow_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_withdrawal_flow_events_id_seq OWNED BY public.visitor_withdrawal_flow_events.id;


--
-- Name: visitor_withdrawal_flow_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_withdrawal_flow_statuses (
    id bigint NOT NULL
);


--
-- Name: visitor_withdrawal_flow_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_withdrawal_flow_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_withdrawal_flow_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_withdrawal_flow_statuses_id_seq OWNED BY public.visitor_withdrawal_flow_statuses.id;


--
-- Name: visitor_withdrawal_flows; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_withdrawal_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    visitor_id bigint NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    began_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_visitor_withdrawal_cycles_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: visitor_withdrawal_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_withdrawal_flows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_withdrawal_flows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_withdrawal_flows_id_seq OWNED BY public.visitor_withdrawal_flows.id;


--
-- Name: visitors; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitors (
    id bigint NOT NULL,
    deactivated_at timestamp(6) with time zone,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    mfa_level_enabled boolean DEFAULT false NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    status_id bigint DEFAULT 2 NOT NULL,
    visibility_id bigint DEFAULT 1 NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    withdrawn_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp without time zone,
    withdrawal_started_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    mfa_level_id bigint DEFAULT 0 NOT NULL,
    mfa_status_id bigint DEFAULT 5 NOT NULL,
    terminated_at timestamp(6) with time zone,
    birthdate text,
    access_state character varying DEFAULT 'enabled'::character varying NOT NULL,
    admin_locked_at timestamp(6) with time zone,
    admin_locked_by_operator_id bigint,
    admin_locked_reason_code character varying,
    admin_locked_reason_note text,
    token_valid_after_at timestamp(6) with time zone,
    reactivated_at timestamp(6) with time zone,
    webauthn_user_handle character varying NOT NULL,
    CONSTRAINT chk_customers_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT chk_visitors_access_state CHECK (((access_state)::text = ANY ((ARRAY['enabled'::character varying, 'admin_locked'::character varying])::text[]))),
    CONSTRAINT chk_visitors_admin_locked_reason_code CHECK (((admin_locked_reason_code IS NULL) OR ((admin_locked_reason_code)::text = ANY ((ARRAY['abuse'::character varying, 'security_incident'::character varying, 'chargeback'::character varying, 'terms_violation'::character varying, 'support_request'::character varying, 'legal_hold'::character varying, 'operator_error_recovery'::character varying, 'other'::character varying])::text[])))),
    CONSTRAINT chk_visitors_birthdate_length CHECK (((birthdate IS NULL) OR (char_length(birthdate) <= 1000)))
);


--
-- Name: visitors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitors_id_seq OWNED BY public.visitors.id;


--
-- Name: action_push_native_devices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_push_native_devices ALTER COLUMN id SET DEFAULT nextval('public.action_push_native_devices_id_seq'::regclass);


--
-- Name: com_enforcement_appeals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_enforcement_appeals ALTER COLUMN id SET DEFAULT nextval('public.com_enforcement_appeals_id_seq'::regclass);


--
-- Name: com_enforcement_authentication_method_effects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_enforcement_authentication_method_effects ALTER COLUMN id SET DEFAULT nextval('public.com_enforcement_authentication_method_effects_id_seq'::regclass);


--
-- Name: com_enforcement_cases id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_enforcement_cases ALTER COLUMN id SET DEFAULT nextval('public.com_enforcement_cases_id_seq'::regclass);


--
-- Name: com_enforcement_identifier_effects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_enforcement_identifier_effects ALTER COLUMN id SET DEFAULT nextval('public.com_enforcement_identifier_effects_id_seq'::regclass);


--
-- Name: com_enforcement_principal_effects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_enforcement_principal_effects ALTER COLUMN id SET DEFAULT nextval('public.com_enforcement_principal_effects_id_seq'::regclass);


--
-- Name: com_enforcement_principal_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_enforcement_principal_links ALTER COLUMN id SET DEFAULT nextval('public.com_enforcement_principal_links_id_seq'::regclass);


--
-- Name: companies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies ALTER COLUMN id SET DEFAULT nextval('public.companies_id_seq'::regclass);


--
-- Name: company_administration_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_administration_grants ALTER COLUMN id SET DEFAULT nextval('public.company_administration_grants_id_seq'::regclass);


--
-- Name: company_delegation_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_delegation_grants ALTER COLUMN id SET DEFAULT nextval('public.company_delegation_grants_id_seq'::regclass);


--
-- Name: company_ownership_transfer_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_ownership_transfer_requests ALTER COLUMN id SET DEFAULT nextval('public.company_ownership_transfer_requests_id_seq'::regclass);


--
-- Name: company_ownerships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_ownerships ALTER COLUMN id SET DEFAULT nextval('public.company_ownerships_id_seq'::regclass);


--
-- Name: company_unit_closures id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_unit_closures ALTER COLUMN id SET DEFAULT nextval('public.company_unit_closures_id_seq'::regclass);


--
-- Name: company_units id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_units ALTER COLUMN id SET DEFAULT nextval('public.company_units_id_seq'::regclass);


--
-- Name: company_view_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_view_grants ALTER COLUMN id SET DEFAULT nextval('public.company_view_grants_id_seq'::regclass);


--
-- Name: core_com_visitor_bridges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.core_com_visitor_bridges ALTER COLUMN id SET DEFAULT nextval('public.core_com_visitor_bridges_id_seq'::regclass);


--
-- Name: individual_administration_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_administration_grants ALTER COLUMN id SET DEFAULT nextval('public.individual_administration_grants_id_seq'::regclass);


--
-- Name: individual_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_assignments ALTER COLUMN id SET DEFAULT nextval('public.individual_assignments_id_seq'::regclass);


--
-- Name: individual_delegation_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_delegation_grants ALTER COLUMN id SET DEFAULT nextval('public.individual_delegation_grants_id_seq'::regclass);


--
-- Name: individual_membership_kinds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_membership_kinds ALTER COLUMN id SET DEFAULT nextval('public.individual_membership_kinds_id_seq'::regclass);


--
-- Name: individual_membership_revoke_reasons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_membership_revoke_reasons ALTER COLUMN id SET DEFAULT nextval('public.individual_membership_revoke_reasons_id_seq'::regclass);


--
-- Name: individual_membership_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_membership_states ALTER COLUMN id SET DEFAULT nextval('public.individual_membership_states_id_seq'::regclass);


--
-- Name: individual_memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships ALTER COLUMN id SET DEFAULT nextval('public.individual_memberships_id_seq'::regclass);


--
-- Name: individual_ownership_transfer_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_ownership_transfer_requests ALTER COLUMN id SET DEFAULT nextval('public.individual_ownership_transfer_requests_id_seq'::regclass);


--
-- Name: individual_ownerships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_ownerships ALTER COLUMN id SET DEFAULT nextval('public.individual_ownerships_id_seq'::regclass);


--
-- Name: individual_usage_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_usage_grants ALTER COLUMN id SET DEFAULT nextval('public.individual_usage_grants_id_seq'::regclass);


--
-- Name: individual_view_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_view_grants ALTER COLUMN id SET DEFAULT nextval('public.individual_view_grants_id_seq'::regclass);


--
-- Name: individuals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individuals ALTER COLUMN id SET DEFAULT nextval('public.individuals_id_seq'::regclass);


--
-- Name: visitor_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_accounts ALTER COLUMN id SET DEFAULT nextval('public.visitor_accounts_id_seq'::regclass);


--
-- Name: visitor_authority_locks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_authority_locks ALTER COLUMN id SET DEFAULT nextval('public.visitor_authority_locks_id_seq'::regclass);


--
-- Name: visitor_banners id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_banners ALTER COLUMN id SET DEFAULT nextval('public.visitor_banners_id_seq'::regclass);


--
-- Name: visitor_email_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_email_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_email_statuses_id_seq'::regclass);


--
-- Name: visitor_emails id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_emails ALTER COLUMN id SET DEFAULT nextval('public.visitor_emails_id_seq'::regclass);


--
-- Name: visitor_enforcement_recovery_ceremonies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_enforcement_recovery_ceremonies ALTER COLUMN id SET DEFAULT nextval('public.visitor_enforcement_recovery_ceremonies_id_seq'::regclass);


--
-- Name: visitor_identities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_identities ALTER COLUMN id SET DEFAULT nextval('public.visitor_identities_id_seq'::regclass);


--
-- Name: visitor_identity_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_identity_states ALTER COLUMN id SET DEFAULT nextval('public.visitor_identity_states_id_seq'::regclass);


--
-- Name: visitor_mfa_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_mfa_levels ALTER COLUMN id SET DEFAULT nextval('public.visitor_mfa_levels_id_seq'::regclass);


--
-- Name: visitor_mfa_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_mfa_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_mfa_statuses_id_seq'::regclass);


--
-- Name: visitor_passkey_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_passkey_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_passkey_statuses_id_seq'::regclass);


--
-- Name: visitor_passkeys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_passkeys ALTER COLUMN id SET DEFAULT nextval('public.visitor_passkeys_id_seq'::regclass);


--
-- Name: visitor_preference_adult_content_gate_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_adult_content_gate_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_adult_content_gate_options_id_seq'::regclass);


--
-- Name: visitor_preference_adult_content_gates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_adult_content_gates ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_adult_content_gates_id_seq'::regclass);


--
-- Name: visitor_preference_currencies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_currencies ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_currencies_id_seq'::regclass);


--
-- Name: visitor_preference_currency_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_currency_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_currency_options_id_seq'::regclass);


--
-- Name: visitor_preference_date_format_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_date_format_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_date_format_options_id_seq'::regclass);


--
-- Name: visitor_preference_date_formats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_date_formats ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_date_formats_id_seq'::regclass);


--
-- Name: visitor_preference_densities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_densities ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_densities_id_seq'::regclass);


--
-- Name: visitor_preference_density_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_density_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_density_options_id_seq'::regclass);


--
-- Name: visitor_preference_language_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_language_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_language_options_id_seq'::regclass);


--
-- Name: visitor_preference_languages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_languages ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_languages_id_seq'::regclass);


--
-- Name: visitor_preference_motion_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_motion_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_motion_options_id_seq'::regclass);


--
-- Name: visitor_preference_motions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_motions ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_motions_id_seq'::regclass);


--
-- Name: visitor_preference_page_size_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_page_size_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_page_size_options_id_seq'::regclass);


--
-- Name: visitor_preference_page_sizes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_page_sizes ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_page_sizes_id_seq'::regclass);


--
-- Name: visitor_preference_region_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_region_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_region_options_id_seq'::regclass);


--
-- Name: visitor_preference_regions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_regions ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_regions_id_seq'::regclass);


--
-- Name: visitor_preference_theme_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_theme_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_theme_options_id_seq'::regclass);


--
-- Name: visitor_preference_themes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_themes ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_themes_id_seq'::regclass);


--
-- Name: visitor_preference_time_format_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_time_format_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_time_format_options_id_seq'::regclass);


--
-- Name: visitor_preference_time_formats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_time_formats ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_time_formats_id_seq'::regclass);


--
-- Name: visitor_preference_timezone_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_timezone_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_timezone_options_id_seq'::regclass);


--
-- Name: visitor_preference_timezones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_timezones ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_timezones_id_seq'::regclass);


--
-- Name: visitor_preferences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preferences ALTER COLUMN id SET DEFAULT nextval('public.visitor_preferences_id_seq'::regclass);


--
-- Name: visitor_privacy_request_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_privacy_request_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_privacy_request_statuses_id_seq'::regclass);


--
-- Name: visitor_privacy_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_privacy_requests ALTER COLUMN id SET DEFAULT nextval('public.visitor_privacy_requests_id_seq'::regclass);


--
-- Name: visitor_processor_erasure_notification_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_processor_erasure_notification_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_processor_erasure_notification_statuses_id_seq'::regclass);


--
-- Name: visitor_processor_erasure_notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_processor_erasure_notifications ALTER COLUMN id SET DEFAULT nextval('public.visitor_processor_erasure_notifications_id_seq'::regclass);


--
-- Name: visitor_retention_hold_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_retention_hold_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_retention_hold_statuses_id_seq'::regclass);


--
-- Name: visitor_retention_holds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_retention_holds ALTER COLUMN id SET DEFAULT nextval('public.visitor_retention_holds_id_seq'::regclass);


--
-- Name: visitor_secret_credential_kinds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credential_kinds ALTER COLUMN id SET DEFAULT nextval('public.visitor_secret_credential_kinds_id_seq'::regclass);


--
-- Name: visitor_secret_credential_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credential_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_secret_credential_statuses_id_seq'::regclass);


--
-- Name: visitor_secret_credentials id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credentials ALTER COLUMN id SET DEFAULT nextval('public.visitor_secret_credentials_id_seq'::regclass);


--
-- Name: visitor_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_statuses_id_seq'::regclass);


--
-- Name: visitor_telephone_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_telephone_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_telephone_statuses_id_seq'::regclass);


--
-- Name: visitor_telephones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_telephones ALTER COLUMN id SET DEFAULT nextval('public.visitor_telephones_id_seq'::regclass);


--
-- Name: visitor_visibilities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_visibilities ALTER COLUMN id SET DEFAULT nextval('public.visitor_visibilities_id_seq'::regclass);


--
-- Name: visitor_withdrawal_ceremonies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_ceremonies ALTER COLUMN id SET DEFAULT nextval('public.visitor_withdrawal_ceremonies_id_seq'::regclass);


--
-- Name: visitor_withdrawal_flow_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flow_events ALTER COLUMN id SET DEFAULT nextval('public.visitor_withdrawal_flow_events_id_seq'::regclass);


--
-- Name: visitor_withdrawal_flow_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flow_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_withdrawal_flow_statuses_id_seq'::regclass);


--
-- Name: visitor_withdrawal_flows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flows ALTER COLUMN id SET DEFAULT nextval('public.visitor_withdrawal_flows_id_seq'::regclass);


--
-- Name: visitors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitors ALTER COLUMN id SET DEFAULT nextval('public.visitors_id_seq'::regclass);


--
-- Name: action_push_native_devices action_push_native_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_push_native_devices
    ADD CONSTRAINT action_push_native_devices_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: visitor_emails chk_visitor_emails_retention_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.visitor_emails
    ADD CONSTRAINT chk_visitor_emails_retention_order CHECK ((discard_at <= purge_eligible_at)) NOT VALID;


--
-- Name: visitor_passkeys chk_visitor_passkeys_retention_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.visitor_passkeys
    ADD CONSTRAINT chk_visitor_passkeys_retention_order CHECK ((discard_at <= purge_eligible_at)) NOT VALID;


--
-- Name: visitor_telephones chk_visitor_telephones_retention_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.visitor_telephones
    ADD CONSTRAINT chk_visitor_telephones_retention_order CHECK ((discard_at <= purge_eligible_at)) NOT VALID;


--
-- Name: visitors chk_visitors_mfa_requirement_consistency; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.visitors
    ADD CONSTRAINT chk_visitors_mfa_requirement_consistency CHECK ((((mfa_level_enabled = false) AND (mfa_level_id = 0)) OR ((mfa_level_enabled = true) AND (mfa_level_id <> 0)))) NOT VALID;


--
-- Name: visitors chk_visitors_terminated_requires_withdrawn; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.visitors
    ADD CONSTRAINT chk_visitors_terminated_requires_withdrawn CHECK (((terminated_at IS NULL) OR ((withdrawn_at IS NOT NULL) AND (withdrawn_at < 'infinity'::timestamp without time zone)))) NOT VALID;


--
-- Name: visitors chk_visitors_withdrawal_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.visitors
    ADD CONSTRAINT chk_visitors_withdrawal_order CHECK (((withdrawal_started_at IS NULL) OR (withdrawn_at IS NULL) OR (withdrawn_at = 'infinity'::timestamp without time zone) OR (withdrawal_started_at <= withdrawn_at))) NOT VALID;


--
-- Name: com_enforcement_appeals com_enforcement_appeals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_enforcement_appeals
    ADD CONSTRAINT com_enforcement_appeals_pkey PRIMARY KEY (id);


--
-- Name: com_enforcement_authentication_method_effects com_enforcement_authentication_method_effects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_enforcement_authentication_method_effects
    ADD CONSTRAINT com_enforcement_authentication_method_effects_pkey PRIMARY KEY (id);


--
-- Name: com_enforcement_cases com_enforcement_cases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_enforcement_cases
    ADD CONSTRAINT com_enforcement_cases_pkey PRIMARY KEY (id);


--
-- Name: com_enforcement_identifier_effects com_enforcement_identifier_effects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_enforcement_identifier_effects
    ADD CONSTRAINT com_enforcement_identifier_effects_pkey PRIMARY KEY (id);


--
-- Name: com_enforcement_principal_effects com_enforcement_principal_effects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_enforcement_principal_effects
    ADD CONSTRAINT com_enforcement_principal_effects_pkey PRIMARY KEY (id);


--
-- Name: com_enforcement_principal_links com_enforcement_principal_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_enforcement_principal_links
    ADD CONSTRAINT com_enforcement_principal_links_pkey PRIMARY KEY (id);


--
-- Name: companies companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (id);


--
-- Name: company_administration_grants company_administration_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_administration_grants
    ADD CONSTRAINT company_administration_grants_pkey PRIMARY KEY (id);


--
-- Name: company_delegation_grants company_delegation_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_delegation_grants
    ADD CONSTRAINT company_delegation_grants_pkey PRIMARY KEY (id);


--
-- Name: company_ownership_transfer_requests company_ownership_transfer_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_ownership_transfer_requests
    ADD CONSTRAINT company_ownership_transfer_requests_pkey PRIMARY KEY (id);


--
-- Name: company_ownerships company_ownerships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_ownerships
    ADD CONSTRAINT company_ownerships_pkey PRIMARY KEY (id);


--
-- Name: company_unit_closures company_unit_closures_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_unit_closures
    ADD CONSTRAINT company_unit_closures_pkey PRIMARY KEY (id);


--
-- Name: company_units company_units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_units
    ADD CONSTRAINT company_units_pkey PRIMARY KEY (id);


--
-- Name: company_view_grants company_view_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_view_grants
    ADD CONSTRAINT company_view_grants_pkey PRIMARY KEY (id);


--
-- Name: core_com_visitor_bridges core_com_visitor_bridges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.core_com_visitor_bridges
    ADD CONSTRAINT core_com_visitor_bridges_pkey PRIMARY KEY (id);


--
-- Name: individual_administration_grants individual_administration_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_administration_grants
    ADD CONSTRAINT individual_administration_grants_pkey PRIMARY KEY (id);


--
-- Name: individual_assignments individual_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_assignments
    ADD CONSTRAINT individual_assignments_pkey PRIMARY KEY (id);


--
-- Name: individual_delegation_grants individual_delegation_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_delegation_grants
    ADD CONSTRAINT individual_delegation_grants_pkey PRIMARY KEY (id);


--
-- Name: individual_membership_kinds individual_membership_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_membership_kinds
    ADD CONSTRAINT individual_membership_kinds_pkey PRIMARY KEY (id);


--
-- Name: individual_membership_revoke_reasons individual_membership_revoke_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_membership_revoke_reasons
    ADD CONSTRAINT individual_membership_revoke_reasons_pkey PRIMARY KEY (id);


--
-- Name: individual_membership_states individual_membership_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_membership_states
    ADD CONSTRAINT individual_membership_states_pkey PRIMARY KEY (id);


--
-- Name: individual_memberships individual_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT individual_memberships_pkey PRIMARY KEY (id);


--
-- Name: individual_ownership_transfer_requests individual_ownership_transfer_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_ownership_transfer_requests
    ADD CONSTRAINT individual_ownership_transfer_requests_pkey PRIMARY KEY (id);


--
-- Name: individual_ownerships individual_ownerships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_ownerships
    ADD CONSTRAINT individual_ownerships_pkey PRIMARY KEY (id);


--
-- Name: individual_usage_grants individual_usage_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_usage_grants
    ADD CONSTRAINT individual_usage_grants_pkey PRIMARY KEY (id);


--
-- Name: individual_view_grants individual_view_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_view_grants
    ADD CONSTRAINT individual_view_grants_pkey PRIMARY KEY (id);


--
-- Name: individuals individuals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individuals
    ADD CONSTRAINT individuals_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: visitor_accounts visitor_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_accounts
    ADD CONSTRAINT visitor_accounts_pkey PRIMARY KEY (id);


--
-- Name: visitor_authority_locks visitor_authority_locks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_authority_locks
    ADD CONSTRAINT visitor_authority_locks_pkey PRIMARY KEY (id);


--
-- Name: visitor_banners visitor_banners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_banners
    ADD CONSTRAINT visitor_banners_pkey PRIMARY KEY (id);


--
-- Name: visitor_email_statuses visitor_email_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_email_statuses
    ADD CONSTRAINT visitor_email_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_emails visitor_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_emails
    ADD CONSTRAINT visitor_emails_pkey PRIMARY KEY (id);


--
-- Name: visitor_enforcement_recovery_ceremonies visitor_enforcement_recovery_ceremonies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_enforcement_recovery_ceremonies
    ADD CONSTRAINT visitor_enforcement_recovery_ceremonies_pkey PRIMARY KEY (id);


--
-- Name: visitor_identities visitor_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_identities
    ADD CONSTRAINT visitor_identities_pkey PRIMARY KEY (id);


--
-- Name: visitor_identity_states visitor_identity_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_identity_states
    ADD CONSTRAINT visitor_identity_states_pkey PRIMARY KEY (id);


--
-- Name: visitor_mfa_levels visitor_mfa_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_mfa_levels
    ADD CONSTRAINT visitor_mfa_levels_pkey PRIMARY KEY (id);


--
-- Name: visitor_mfa_statuses visitor_mfa_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_mfa_statuses
    ADD CONSTRAINT visitor_mfa_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_passkey_statuses visitor_passkey_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_passkey_statuses
    ADD CONSTRAINT visitor_passkey_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_passkeys visitor_passkeys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_passkeys
    ADD CONSTRAINT visitor_passkeys_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_adult_content_gate_options visitor_preference_adult_content_gate_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_adult_content_gate_options
    ADD CONSTRAINT visitor_preference_adult_content_gate_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_adult_content_gates visitor_preference_adult_content_gates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_adult_content_gates
    ADD CONSTRAINT visitor_preference_adult_content_gates_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_currencies visitor_preference_currencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_currencies
    ADD CONSTRAINT visitor_preference_currencies_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_currency_options visitor_preference_currency_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_currency_options
    ADD CONSTRAINT visitor_preference_currency_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_date_format_options visitor_preference_date_format_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_date_format_options
    ADD CONSTRAINT visitor_preference_date_format_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_date_formats visitor_preference_date_formats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_date_formats
    ADD CONSTRAINT visitor_preference_date_formats_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_densities visitor_preference_densities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_densities
    ADD CONSTRAINT visitor_preference_densities_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_density_options visitor_preference_density_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_density_options
    ADD CONSTRAINT visitor_preference_density_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_language_options visitor_preference_language_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_language_options
    ADD CONSTRAINT visitor_preference_language_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_languages visitor_preference_languages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_languages
    ADD CONSTRAINT visitor_preference_languages_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_motion_options visitor_preference_motion_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_motion_options
    ADD CONSTRAINT visitor_preference_motion_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_motions visitor_preference_motions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_motions
    ADD CONSTRAINT visitor_preference_motions_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_page_size_options visitor_preference_page_size_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_page_size_options
    ADD CONSTRAINT visitor_preference_page_size_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_page_sizes visitor_preference_page_sizes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_page_sizes
    ADD CONSTRAINT visitor_preference_page_sizes_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_region_options visitor_preference_region_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_region_options
    ADD CONSTRAINT visitor_preference_region_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_regions visitor_preference_regions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_regions
    ADD CONSTRAINT visitor_preference_regions_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_theme_options visitor_preference_theme_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_theme_options
    ADD CONSTRAINT visitor_preference_theme_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_themes visitor_preference_themes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_themes
    ADD CONSTRAINT visitor_preference_themes_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_time_format_options visitor_preference_time_format_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_time_format_options
    ADD CONSTRAINT visitor_preference_time_format_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_time_formats visitor_preference_time_formats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_time_formats
    ADD CONSTRAINT visitor_preference_time_formats_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_timezone_options visitor_preference_timezone_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_timezone_options
    ADD CONSTRAINT visitor_preference_timezone_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_timezones visitor_preference_timezones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_timezones
    ADD CONSTRAINT visitor_preference_timezones_pkey PRIMARY KEY (id);


--
-- Name: visitor_preferences visitor_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preferences
    ADD CONSTRAINT visitor_preferences_pkey PRIMARY KEY (id);


--
-- Name: visitor_privacy_request_statuses visitor_privacy_request_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_privacy_request_statuses
    ADD CONSTRAINT visitor_privacy_request_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_privacy_requests visitor_privacy_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_privacy_requests
    ADD CONSTRAINT visitor_privacy_requests_pkey PRIMARY KEY (id);


--
-- Name: visitor_processor_erasure_notification_statuses visitor_processor_erasure_notification_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_processor_erasure_notification_statuses
    ADD CONSTRAINT visitor_processor_erasure_notification_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_processor_erasure_notifications visitor_processor_erasure_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_processor_erasure_notifications
    ADD CONSTRAINT visitor_processor_erasure_notifications_pkey PRIMARY KEY (id);


--
-- Name: visitor_retention_hold_statuses visitor_retention_hold_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_retention_hold_statuses
    ADD CONSTRAINT visitor_retention_hold_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_retention_holds visitor_retention_holds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_retention_holds
    ADD CONSTRAINT visitor_retention_holds_pkey PRIMARY KEY (id);


--
-- Name: visitor_secret_credential_kinds visitor_secret_credential_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credential_kinds
    ADD CONSTRAINT visitor_secret_credential_kinds_pkey PRIMARY KEY (id);


--
-- Name: visitor_secret_credential_statuses visitor_secret_credential_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credential_statuses
    ADD CONSTRAINT visitor_secret_credential_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_secret_credentials visitor_secret_credentials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credentials
    ADD CONSTRAINT visitor_secret_credentials_pkey PRIMARY KEY (id);


--
-- Name: visitor_statuses visitor_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_statuses
    ADD CONSTRAINT visitor_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_telephone_statuses visitor_telephone_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_telephone_statuses
    ADD CONSTRAINT visitor_telephone_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_telephones visitor_telephones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_telephones
    ADD CONSTRAINT visitor_telephones_pkey PRIMARY KEY (id);


--
-- Name: visitor_visibilities visitor_visibilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_visibilities
    ADD CONSTRAINT visitor_visibilities_pkey PRIMARY KEY (id);


--
-- Name: visitor_withdrawal_ceremonies visitor_withdrawal_ceremonies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_ceremonies
    ADD CONSTRAINT visitor_withdrawal_ceremonies_pkey PRIMARY KEY (id);


--
-- Name: visitor_withdrawal_flow_events visitor_withdrawal_flow_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flow_events
    ADD CONSTRAINT visitor_withdrawal_flow_events_pkey PRIMARY KEY (id);


--
-- Name: visitor_withdrawal_flow_statuses visitor_withdrawal_flow_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flow_statuses
    ADD CONSTRAINT visitor_withdrawal_flow_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_withdrawal_flows visitor_withdrawal_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flows
    ADD CONSTRAINT visitor_withdrawal_flows_pkey PRIMARY KEY (id);


--
-- Name: visitors visitors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitors
    ADD CONSTRAINT visitors_pkey PRIMARY KEY (id);


--
-- Name: idx_com_enforcement_cases_state_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_com_enforcement_cases_state_expires_at ON public.com_enforcement_cases USING btree (state, expires_at);


--
-- Name: idx_com_enforcement_identifier_effects_one_open; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_com_enforcement_identifier_effects_one_open ON public.com_enforcement_identifier_effects USING btree (identifier_kind, lookup_digest) WHERE (ended_at IS NULL);


--
-- Name: idx_com_enforcement_method_effects_one_open_per_method; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_com_enforcement_method_effects_one_open_per_method ON public.com_enforcement_authentication_method_effects USING btree (principal_public_id, authentication_method) WHERE (ended_at IS NULL);


--
-- Name: idx_com_enforcement_principal_effects_principal_open; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_com_enforcement_principal_effects_principal_open ON public.com_enforcement_principal_effects USING btree (principal_public_id, ended_at);


--
-- Name: idx_company_admin_grants_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_company_admin_grants_on_visitor_id ON public.company_administration_grants USING btree (visitor_id);


--
-- Name: idx_company_admin_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_company_admin_grants_unique ON public.company_administration_grants USING btree (company_id, visitor_id);


--
-- Name: idx_company_delegate_grants_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_company_delegate_grants_on_visitor_id ON public.company_delegation_grants USING btree (visitor_id);


--
-- Name: idx_company_delegate_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_company_delegate_grants_unique ON public.company_delegation_grants USING btree (company_id, visitor_id);


--
-- Name: idx_company_ownerships_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_company_ownerships_on_visitor_id ON public.company_ownerships USING btree (visitor_id);


--
-- Name: idx_company_ownerships_one_resource; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_company_ownerships_one_resource ON public.company_ownerships USING btree (company_id);


--
-- Name: idx_company_transfer_requests_destination; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_company_transfer_requests_destination ON public.company_ownership_transfer_requests USING btree (destination_visitor_id, status);


--
-- Name: idx_company_transfer_requests_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_company_transfer_requests_due ON public.company_ownership_transfer_requests USING btree (status, expires_at);


--
-- Name: idx_company_transfer_requests_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_company_transfer_requests_on_public_id ON public.company_ownership_transfer_requests USING btree (public_id);


--
-- Name: idx_company_transfer_requests_one_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_company_transfer_requests_one_pending ON public.company_ownership_transfer_requests USING btree (company_id) WHERE ((status)::text = 'pending'::text);


--
-- Name: idx_company_unit_closures_unique_path; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_company_unit_closures_unique_path ON public.company_unit_closures USING btree (ancestor_id, descendant_id);


--
-- Name: idx_company_units_id_company; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_company_units_id_company ON public.company_units USING btree (id, company_id);


--
-- Name: idx_company_view_grants_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_company_view_grants_on_visitor_id ON public.company_view_grants USING btree (visitor_id);


--
-- Name: idx_company_view_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_company_view_grants_unique ON public.company_view_grants USING btree (company_id, visitor_id);


--
-- Name: idx_core_com_visitor_bridges_unique_visitor_rp; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_core_com_visitor_bridges_unique_visitor_rp ON public.core_com_visitor_bridges USING btree (visitor_id, rp_client_id);


--
-- Name: idx_individual_admin_grants_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_individual_admin_grants_on_visitor_id ON public.individual_administration_grants USING btree (visitor_id);


--
-- Name: idx_individual_admin_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_individual_admin_grants_unique ON public.individual_administration_grants USING btree (individual_id, visitor_id);


--
-- Name: idx_individual_assignments_one_active_identity_per_individual; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_individual_assignments_one_active_identity_per_individual ON public.individual_assignments USING btree (individual_id, visitor_identity_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_individual_delegate_grants_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_individual_delegate_grants_on_visitor_id ON public.individual_delegation_grants USING btree (visitor_id);


--
-- Name: idx_individual_delegate_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_individual_delegate_grants_unique ON public.individual_delegation_grants USING btree (individual_id, visitor_id);


--
-- Name: idx_individual_memberships_one_active_primary; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_individual_memberships_one_active_primary ON public.individual_memberships USING btree (individual_id) WHERE (("primary" = true) AND (revoked_at IS NULL) AND (ends_at IS NULL));


--
-- Name: idx_individual_ownerships_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_individual_ownerships_on_visitor_id ON public.individual_ownerships USING btree (visitor_id);


--
-- Name: idx_individual_ownerships_one_resource; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_individual_ownerships_one_resource ON public.individual_ownerships USING btree (individual_id);


--
-- Name: idx_individual_transfer_requests_destination; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_individual_transfer_requests_destination ON public.individual_ownership_transfer_requests USING btree (destination_visitor_id, status);


--
-- Name: idx_individual_transfer_requests_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_individual_transfer_requests_due ON public.individual_ownership_transfer_requests USING btree (status, expires_at);


--
-- Name: idx_individual_transfer_requests_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_individual_transfer_requests_on_public_id ON public.individual_ownership_transfer_requests USING btree (public_id);


--
-- Name: idx_individual_transfer_requests_one_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_individual_transfer_requests_one_pending ON public.individual_ownership_transfer_requests USING btree (individual_id) WHERE ((status)::text = 'pending'::text);


--
-- Name: idx_individual_usage_grants_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_individual_usage_grants_on_visitor_id ON public.individual_usage_grants USING btree (visitor_id);


--
-- Name: idx_individual_usage_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_individual_usage_grants_unique ON public.individual_usage_grants USING btree (individual_id, visitor_id);


--
-- Name: idx_individual_view_grants_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_individual_view_grants_on_visitor_id ON public.individual_view_grants USING btree (visitor_id);


--
-- Name: idx_individual_view_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_individual_view_grants_unique ON public.individual_view_grants USING btree (individual_id, visitor_id);


--
-- Name: idx_individuals_one_per_visitor_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_individuals_one_per_visitor_identity ON public.individuals USING btree (visitor_identity_id);


--
-- Name: idx_on_com_enforcement_case_id_6a553f22e2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_com_enforcement_case_id_6a553f22e2 ON public.com_enforcement_principal_links USING btree (com_enforcement_case_id);


--
-- Name: idx_on_com_enforcement_case_id_895a8105d4; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_com_enforcement_case_id_895a8105d4 ON public.com_enforcement_principal_effects USING btree (com_enforcement_case_id);


--
-- Name: idx_on_com_enforcement_case_id_8c00419fb5; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_com_enforcement_case_id_8c00419fb5 ON public.com_enforcement_authentication_method_effects USING btree (com_enforcement_case_id);


--
-- Name: idx_on_com_enforcement_case_id_8de7407406; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_com_enforcement_case_id_8de7407406 ON public.com_enforcement_identifier_effects USING btree (com_enforcement_case_id);


--
-- Name: idx_on_purge_eligible_at_e6bf3a42a8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_purge_eligible_at_e6bf3a42a8 ON public.visitor_processor_erasure_notifications USING btree (purge_eligible_at) WHERE (purge_eligible_at < 'infinity'::timestamp with time zone);


--
-- Name: idx_on_visitor_id_status_id_expires_at_be8a9b85e8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_visitor_id_status_id_expires_at_be8a9b85e8 ON public.visitor_enforcement_recovery_ceremonies USING btree (visitor_id, status_id, expires_at);


--
-- Name: idx_on_visitor_id_status_id_expires_at_f1c3d6493a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_visitor_id_status_id_expires_at_f1c3d6493a ON public.visitor_withdrawal_ceremonies USING btree (visitor_id, status_id, expires_at);


--
-- Name: idx_on_visitor_privacy_request_id_4225260194; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_visitor_privacy_request_id_4225260194 ON public.visitor_processor_erasure_notifications USING btree (visitor_privacy_request_id);


--
-- Name: idx_on_visitor_secret_credential_kind_id_80c2fa07fe; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_visitor_secret_credential_kind_id_80c2fa07fe ON public.visitor_secret_credentials USING btree (visitor_secret_credential_kind_id);


--
-- Name: idx_on_visitor_secret_credential_status_id_a8132e5a1a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_visitor_secret_credential_status_id_a8132e5a1a ON public.visitor_secret_credentials USING btree (visitor_secret_credential_status_id);


--
-- Name: idx_on_visitor_withdrawal_flow_id_dada4f9f5b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_visitor_withdrawal_flow_id_dada4f9f5b ON public.visitor_withdrawal_flow_events USING btree (visitor_withdrawal_flow_id);


--
-- Name: idx_visitor_authority_locks_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_visitor_authority_locks_on_visitor_id ON public.visitor_authority_locks USING btree (visitor_id);


--
-- Name: idx_visitor_privacy_requests_subject_kind_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_visitor_privacy_requests_subject_kind_status ON public.visitor_privacy_requests USING btree (visitor_id, request_kind, status_id);


--
-- Name: idx_visitor_proc_erase_notifications_retry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_visitor_proc_erase_notifications_retry ON public.visitor_processor_erasure_notifications USING btree (status_id, next_retry_at);


--
-- Name: idx_visitor_proc_erase_notifications_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_visitor_proc_erase_notifications_unique ON public.visitor_processor_erasure_notifications USING btree (visitor_privacy_request_id, processor_key);


--
-- Name: idx_visitor_retention_holds_on_subject_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_visitor_retention_holds_on_subject_status ON public.visitor_retention_holds USING btree (visitor_id, status_id);


--
-- Name: index_action_push_native_devices_on_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_action_push_native_devices_on_owner ON public.action_push_native_devices USING btree (owner_type, owner_id);


--
-- Name: index_com_enforcement_appeals_on_com_enforcement_case_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_com_enforcement_appeals_on_com_enforcement_case_id ON public.com_enforcement_appeals USING btree (com_enforcement_case_id);


--
-- Name: index_com_enforcement_appeals_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_com_enforcement_appeals_on_public_id ON public.com_enforcement_appeals USING btree (public_id);


--
-- Name: index_com_enforcement_cases_on_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_enforcement_cases_on_kind ON public.com_enforcement_cases USING btree (kind);


--
-- Name: index_com_enforcement_cases_on_principal_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_enforcement_cases_on_principal_public_id ON public.com_enforcement_cases USING btree (principal_public_id);


--
-- Name: index_com_enforcement_cases_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_com_enforcement_cases_on_public_id ON public.com_enforcement_cases USING btree (public_id);


--
-- Name: index_com_enforcement_principal_links_on_principal_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_enforcement_principal_links_on_principal_public_id ON public.com_enforcement_principal_links USING btree (principal_public_id);


--
-- Name: index_companies_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_companies_on_public_id ON public.companies USING btree (public_id);


--
-- Name: index_company_unit_closures_on_descendant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_company_unit_closures_on_descendant_id ON public.company_unit_closures USING btree (descendant_id);


--
-- Name: index_company_units_on_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_company_units_on_company_id ON public.company_units USING btree (company_id);


--
-- Name: index_company_units_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_company_units_on_parent_id ON public.company_units USING btree (parent_id);


--
-- Name: index_company_units_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_company_units_on_public_id ON public.company_units USING btree (public_id);


--
-- Name: index_core_com_visitor_bridges_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_core_com_visitor_bridges_on_public_id ON public.core_com_visitor_bridges USING btree (public_id);


--
-- Name: index_individual_assignments_on_individual_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individual_assignments_on_individual_id ON public.individual_assignments USING btree (individual_id);


--
-- Name: index_individual_assignments_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_individual_assignments_on_public_id ON public.individual_assignments USING btree (public_id);


--
-- Name: index_individual_assignments_on_visitor_identity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individual_assignments_on_visitor_identity_id ON public.individual_assignments USING btree (visitor_identity_id);


--
-- Name: index_individual_memberships_on_approved_by_individual_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individual_memberships_on_approved_by_individual_id ON public.individual_memberships USING btree (approved_by_individual_id);


--
-- Name: index_individual_memberships_on_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individual_memberships_on_company_id ON public.individual_memberships USING btree (company_id);


--
-- Name: index_individual_memberships_on_company_unit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individual_memberships_on_company_unit_id ON public.individual_memberships USING btree (company_unit_id);


--
-- Name: index_individual_memberships_on_granted_by_individual_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individual_memberships_on_granted_by_individual_id ON public.individual_memberships USING btree (granted_by_individual_id);


--
-- Name: index_individual_memberships_on_individual_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individual_memberships_on_individual_id ON public.individual_memberships USING btree (individual_id);


--
-- Name: index_individual_memberships_on_membership_kind_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individual_memberships_on_membership_kind_id ON public.individual_memberships USING btree (membership_kind_id);


--
-- Name: index_individual_memberships_on_membership_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individual_memberships_on_membership_state_id ON public.individual_memberships USING btree (membership_state_id);


--
-- Name: index_individual_memberships_on_revoke_reason_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individual_memberships_on_revoke_reason_id ON public.individual_memberships USING btree (revoke_reason_id);


--
-- Name: index_individual_memberships_on_revoked_by_individual_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individual_memberships_on_revoked_by_individual_id ON public.individual_memberships USING btree (revoked_by_individual_id);


--
-- Name: index_individuals_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_individuals_on_public_id ON public.individuals USING btree (public_id);


--
-- Name: index_individuals_on_visitor_identity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individuals_on_visitor_identity_id ON public.individuals USING btree (visitor_identity_id);


--
-- Name: index_visitor_accounts_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_accounts_on_public_id ON public.visitor_accounts USING btree (public_id);


--
-- Name: index_visitor_accounts_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_accounts_on_visitor_id ON public.visitor_accounts USING btree (visitor_id);


--
-- Name: index_visitor_banners_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_banners_on_visitor_id ON public.visitor_banners USING btree (visitor_id);


--
-- Name: index_visitor_emails_on_active_address_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_emails_on_active_address_digest ON public.visitor_emails USING btree (address_digest) WHERE ((address_digest IS NOT NULL) AND (visitor_email_status_id <> 4));


--
-- Name: index_visitor_emails_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_emails_on_discard_at ON public.visitor_emails USING btree (discard_at);


--
-- Name: index_visitor_emails_on_otp_last_sent_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_emails_on_otp_last_sent_at ON public.visitor_emails USING btree (otp_last_sent_at);


--
-- Name: index_visitor_emails_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_emails_on_public_id ON public.visitor_emails USING btree (public_id);


--
-- Name: index_visitor_emails_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_emails_on_purge_eligible_at ON public.visitor_emails USING btree (purge_eligible_at);


--
-- Name: index_visitor_emails_on_visitor_email_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_emails_on_visitor_email_status_id ON public.visitor_emails USING btree (visitor_email_status_id);


--
-- Name: index_visitor_emails_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_emails_on_visitor_id ON public.visitor_emails USING btree (visitor_id);


--
-- Name: index_visitor_enforcement_recovery_ceremonies_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_enforcement_recovery_ceremonies_on_public_id ON public.visitor_enforcement_recovery_ceremonies USING btree (public_id);


--
-- Name: index_visitor_enforcement_recovery_ceremonies_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_enforcement_recovery_ceremonies_on_token_digest ON public.visitor_enforcement_recovery_ceremonies USING btree (token_digest);


--
-- Name: index_visitor_enforcement_recovery_ceremonies_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_enforcement_recovery_ceremonies_on_visitor_id ON public.visitor_enforcement_recovery_ceremonies USING btree (visitor_id);


--
-- Name: index_visitor_identities_on_issuer_and_subject_and_audience; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_identities_on_issuer_and_subject_and_audience ON public.visitor_identities USING btree (issuer, subject, audience);


--
-- Name: index_visitor_identities_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_identities_on_public_id ON public.visitor_identities USING btree (public_id);


--
-- Name: index_visitor_identities_on_source_record_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_identities_on_source_record_id ON public.visitor_identities USING btree (source_record_id);


--
-- Name: index_visitor_identities_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_identities_on_status_id ON public.visitor_identities USING btree (status_id);


--
-- Name: index_visitor_passkeys_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_passkeys_on_discard_at ON public.visitor_passkeys USING btree (discard_at);


--
-- Name: index_visitor_passkeys_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_passkeys_on_public_id ON public.visitor_passkeys USING btree (public_id);


--
-- Name: index_visitor_passkeys_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_passkeys_on_purge_eligible_at ON public.visitor_passkeys USING btree (purge_eligible_at);


--
-- Name: index_visitor_passkeys_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_passkeys_on_status_id ON public.visitor_passkeys USING btree (status_id);


--
-- Name: index_visitor_passkeys_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_passkeys_on_visitor_id ON public.visitor_passkeys USING btree (visitor_id);


--
-- Name: index_visitor_passkeys_on_webauthn_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_passkeys_on_webauthn_id ON public.visitor_passkeys USING btree (webauthn_id);


--
-- Name: index_visitor_preference_adult_content_gates_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_adult_content_gates_on_option_id ON public.visitor_preference_adult_content_gates USING btree (option_id);


--
-- Name: index_visitor_preference_adult_content_gates_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_adult_content_gates_on_preference_id ON public.visitor_preference_adult_content_gates USING btree (preference_id);


--
-- Name: index_visitor_preference_currencies_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_currencies_on_option_id ON public.visitor_preference_currencies USING btree (option_id);


--
-- Name: index_visitor_preference_currencies_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_currencies_on_preference_id ON public.visitor_preference_currencies USING btree (preference_id);


--
-- Name: index_visitor_preference_date_formats_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_date_formats_on_option_id ON public.visitor_preference_date_formats USING btree (option_id);


--
-- Name: index_visitor_preference_date_formats_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_date_formats_on_preference_id ON public.visitor_preference_date_formats USING btree (preference_id);


--
-- Name: index_visitor_preference_densities_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_densities_on_option_id ON public.visitor_preference_densities USING btree (option_id);


--
-- Name: index_visitor_preference_densities_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_densities_on_preference_id ON public.visitor_preference_densities USING btree (preference_id);


--
-- Name: index_visitor_preference_language_options_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_language_options_on_id ON public.visitor_preference_language_options USING btree (id);


--
-- Name: index_visitor_preference_languages_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_languages_on_option_id ON public.visitor_preference_languages USING btree (option_id);


--
-- Name: index_visitor_preference_languages_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_languages_on_preference_id ON public.visitor_preference_languages USING btree (preference_id);


--
-- Name: index_visitor_preference_motions_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_motions_on_option_id ON public.visitor_preference_motions USING btree (option_id);


--
-- Name: index_visitor_preference_motions_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_motions_on_preference_id ON public.visitor_preference_motions USING btree (preference_id);


--
-- Name: index_visitor_preference_page_sizes_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_page_sizes_on_option_id ON public.visitor_preference_page_sizes USING btree (option_id);


--
-- Name: index_visitor_preference_page_sizes_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_page_sizes_on_preference_id ON public.visitor_preference_page_sizes USING btree (preference_id);


--
-- Name: index_visitor_preference_region_options_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_region_options_on_id ON public.visitor_preference_region_options USING btree (id);


--
-- Name: index_visitor_preference_regions_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_regions_on_option_id ON public.visitor_preference_regions USING btree (option_id);


--
-- Name: index_visitor_preference_regions_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_regions_on_preference_id ON public.visitor_preference_regions USING btree (preference_id);


--
-- Name: index_visitor_preference_theme_options_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_theme_options_on_id ON public.visitor_preference_theme_options USING btree (id);


--
-- Name: index_visitor_preference_themes_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_themes_on_option_id ON public.visitor_preference_themes USING btree (option_id);


--
-- Name: index_visitor_preference_themes_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_themes_on_preference_id ON public.visitor_preference_themes USING btree (preference_id);


--
-- Name: index_visitor_preference_time_formats_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_time_formats_on_option_id ON public.visitor_preference_time_formats USING btree (option_id);


--
-- Name: index_visitor_preference_time_formats_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_time_formats_on_preference_id ON public.visitor_preference_time_formats USING btree (preference_id);


--
-- Name: index_visitor_preference_timezone_options_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_timezone_options_on_id ON public.visitor_preference_timezone_options USING btree (id);


--
-- Name: index_visitor_preference_timezones_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_timezones_on_option_id ON public.visitor_preference_timezones USING btree (option_id);


--
-- Name: index_visitor_preference_timezones_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_timezones_on_preference_id ON public.visitor_preference_timezones USING btree (preference_id);


--
-- Name: index_visitor_preferences_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preferences_on_public_id ON public.visitor_preferences USING btree (public_id);


--
-- Name: index_visitor_preferences_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preferences_on_visitor_id ON public.visitor_preferences USING btree (visitor_id);


--
-- Name: index_visitor_privacy_requests_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_privacy_requests_on_discard_at ON public.visitor_privacy_requests USING btree (discard_at);


--
-- Name: index_visitor_privacy_requests_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_privacy_requests_on_public_id ON public.visitor_privacy_requests USING btree (public_id);


--
-- Name: index_visitor_privacy_requests_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_privacy_requests_on_purge_eligible_at ON public.visitor_privacy_requests USING btree (purge_eligible_at) WHERE (purge_eligible_at < 'infinity'::timestamp with time zone);


--
-- Name: index_visitor_privacy_requests_on_response_due_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_privacy_requests_on_response_due_at ON public.visitor_privacy_requests USING btree (response_due_at);


--
-- Name: index_visitor_privacy_requests_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_privacy_requests_on_visitor_id ON public.visitor_privacy_requests USING btree (visitor_id);


--
-- Name: index_visitor_processor_erasure_notifications_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_processor_erasure_notifications_on_discard_at ON public.visitor_processor_erasure_notifications USING btree (discard_at);


--
-- Name: index_visitor_processor_erasure_notifications_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_processor_erasure_notifications_on_public_id ON public.visitor_processor_erasure_notifications USING btree (public_id);


--
-- Name: index_visitor_retention_holds_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_retention_holds_on_discard_at ON public.visitor_retention_holds USING btree (discard_at);


--
-- Name: index_visitor_retention_holds_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_retention_holds_on_expires_at ON public.visitor_retention_holds USING btree (expires_at);


--
-- Name: index_visitor_retention_holds_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_retention_holds_on_public_id ON public.visitor_retention_holds USING btree (public_id);


--
-- Name: index_visitor_retention_holds_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_retention_holds_on_purge_eligible_at ON public.visitor_retention_holds USING btree (purge_eligible_at) WHERE (purge_eligible_at < 'infinity'::timestamp with time zone);


--
-- Name: index_visitor_retention_holds_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_retention_holds_on_visitor_id ON public.visitor_retention_holds USING btree (visitor_id);


--
-- Name: index_visitor_secret_credentials_on_lookup_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_secret_credentials_on_lookup_digest ON public.visitor_secret_credentials USING btree (lookup_digest);


--
-- Name: index_visitor_secret_credentials_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_secret_credentials_on_public_id ON public.visitor_secret_credentials USING btree (public_id);


--
-- Name: index_visitor_secret_credentials_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_secret_credentials_on_visitor_id ON public.visitor_secret_credentials USING btree (visitor_id);


--
-- Name: index_visitor_telephones_on_active_number_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_telephones_on_active_number_digest ON public.visitor_telephones USING btree (number_digest) WHERE ((number_digest IS NOT NULL) AND (visitor_telephone_status_id <> 4));


--
-- Name: index_visitor_telephones_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_telephones_on_discard_at ON public.visitor_telephones USING btree (discard_at);


--
-- Name: index_visitor_telephones_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_telephones_on_public_id ON public.visitor_telephones USING btree (public_id);


--
-- Name: index_visitor_telephones_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_telephones_on_purge_eligible_at ON public.visitor_telephones USING btree (purge_eligible_at);


--
-- Name: index_visitor_telephones_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_telephones_on_visitor_id ON public.visitor_telephones USING btree (visitor_id);


--
-- Name: index_visitor_telephones_on_visitor_telephone_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_telephones_on_visitor_telephone_status_id ON public.visitor_telephones USING btree (visitor_telephone_status_id);


--
-- Name: index_visitor_withdrawal_ceremonies_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_ceremonies_on_expires_at ON public.visitor_withdrawal_ceremonies USING btree (expires_at);


--
-- Name: index_visitor_withdrawal_ceremonies_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_withdrawal_ceremonies_on_public_id ON public.visitor_withdrawal_ceremonies USING btree (public_id);


--
-- Name: index_visitor_withdrawal_ceremonies_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_withdrawal_ceremonies_on_token_digest ON public.visitor_withdrawal_ceremonies USING btree (token_digest);


--
-- Name: index_visitor_withdrawal_ceremonies_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_ceremonies_on_visitor_id ON public.visitor_withdrawal_ceremonies USING btree (visitor_id);


--
-- Name: index_visitor_withdrawal_flow_events_on_from_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_flow_events_on_from_status_id ON public.visitor_withdrawal_flow_events USING btree (from_status_id);


--
-- Name: index_visitor_withdrawal_flow_events_on_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_flow_events_on_occurred_at ON public.visitor_withdrawal_flow_events USING btree (occurred_at);


--
-- Name: index_visitor_withdrawal_flow_events_on_to_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_flow_events_on_to_status_id ON public.visitor_withdrawal_flow_events USING btree (to_status_id);


--
-- Name: index_visitor_withdrawal_flow_events_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_flow_events_on_visitor_id ON public.visitor_withdrawal_flow_events USING btree (visitor_id);


--
-- Name: index_visitor_withdrawal_flows_on_began_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_flows_on_began_at ON public.visitor_withdrawal_flows USING btree (began_at);


--
-- Name: index_visitor_withdrawal_flows_on_completed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_flows_on_completed_at ON public.visitor_withdrawal_flows USING btree (completed_at);


--
-- Name: index_visitor_withdrawal_flows_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_flows_on_discard_at ON public.visitor_withdrawal_flows USING btree (discard_at);


--
-- Name: index_visitor_withdrawal_flows_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_withdrawal_flows_on_public_id ON public.visitor_withdrawal_flows USING btree (public_id);


--
-- Name: index_visitor_withdrawal_flows_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_flows_on_purge_eligible_at ON public.visitor_withdrawal_flows USING btree (purge_eligible_at);


--
-- Name: index_visitor_withdrawal_flows_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_flows_on_status_id ON public.visitor_withdrawal_flows USING btree (status_id);


--
-- Name: index_visitor_withdrawal_flows_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_flows_on_visitor_id ON public.visitor_withdrawal_flows USING btree (visitor_id);


--
-- Name: index_visitors_on_access_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_access_state ON public.visitors USING btree (access_state);


--
-- Name: index_visitors_on_admin_locked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_admin_locked_at ON public.visitors USING btree (admin_locked_at) WHERE (admin_locked_at IS NOT NULL);


--
-- Name: index_visitors_on_deactivated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_deactivated_at ON public.visitors USING btree (deactivated_at) WHERE (deactivated_at IS NOT NULL);


--
-- Name: index_visitors_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_discard_at ON public.visitors USING btree (discard_at);


--
-- Name: index_visitors_on_mfa_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_mfa_level_id ON public.visitors USING btree (mfa_level_id);


--
-- Name: index_visitors_on_mfa_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_mfa_status_id ON public.visitors USING btree (mfa_status_id);


--
-- Name: index_visitors_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitors_on_public_id ON public.visitors USING btree (public_id);


--
-- Name: index_visitors_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_purge_eligible_at ON public.visitors USING btree (purge_eligible_at);


--
-- Name: index_visitors_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_status_id ON public.visitors USING btree (status_id);


--
-- Name: index_visitors_on_terminated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_terminated_at ON public.visitors USING btree (terminated_at) WHERE (terminated_at IS NOT NULL);


--
-- Name: index_visitors_on_token_valid_after_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_token_valid_after_at ON public.visitors USING btree (token_valid_after_at) WHERE (token_valid_after_at IS NOT NULL);


--
-- Name: index_visitors_on_visibility_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_visibility_id ON public.visitors USING btree (visibility_id);


--
-- Name: index_visitors_on_webauthn_user_handle; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitors_on_webauthn_user_handle ON public.visitors USING btree (webauthn_user_handle);


--
-- Name: index_visitors_on_withdrawal_started_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_withdrawal_started_at ON public.visitors USING btree (withdrawal_started_at) WHERE (withdrawal_started_at IS NOT NULL);


--
-- Name: index_visitors_on_withdrawn_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_withdrawn_at ON public.visitors USING btree (withdrawn_at) WHERE (withdrawn_at IS NOT NULL);


--
-- Name: company_units fk_company_units_parent_same_company; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_units
    ADD CONSTRAINT fk_company_units_parent_same_company FOREIGN KEY (parent_id, company_id) REFERENCES public.company_units(id, company_id) ON DELETE RESTRICT;


--
-- Name: individual_memberships fk_individual_memberships_unit_same_company; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT fk_individual_memberships_unit_same_company FOREIGN KEY (company_unit_id, company_id) REFERENCES public.company_units(id, company_id) ON DELETE RESTRICT;


--
-- Name: visitor_preference_page_sizes fk_rails_014019b4c4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_page_sizes
    ADD CONSTRAINT fk_rails_014019b4c4 FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: visitor_preference_page_sizes fk_rails_06044e10ed; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_page_sizes
    ADD CONSTRAINT fk_rails_06044e10ed FOREIGN KEY (option_id) REFERENCES public.visitor_preference_page_size_options(id);


--
-- Name: company_delegation_grants fk_rails_076c88f672; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_delegation_grants
    ADD CONSTRAINT fk_rails_076c88f672 FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitor_emails fk_rails_07ea0750f3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_emails
    ADD CONSTRAINT fk_rails_07ea0750f3 FOREIGN KEY (visitor_email_status_id) REFERENCES public.visitor_email_statuses(id);


--
-- Name: visitor_retention_holds fk_rails_0b00e2e900; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_retention_holds
    ADD CONSTRAINT fk_rails_0b00e2e900 FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: com_enforcement_authentication_method_effects fk_rails_0e70aae130; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_enforcement_authentication_method_effects
    ADD CONSTRAINT fk_rails_0e70aae130 FOREIGN KEY (com_enforcement_case_id) REFERENCES public.com_enforcement_cases(id);


--
-- Name: visitors fk_rails_15c7fee824; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitors
    ADD CONSTRAINT fk_rails_15c7fee824 FOREIGN KEY (mfa_level_id) REFERENCES public.visitor_mfa_levels(id);


--
-- Name: individual_memberships fk_rails_1652eb28d9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT fk_rails_1652eb28d9 FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: visitor_preference_languages fk_rails_1bfc60dac9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_languages
    ADD CONSTRAINT fk_rails_1bfc60dac9 FOREIGN KEY (option_id) REFERENCES public.visitor_preference_language_options(id);


--
-- Name: individual_ownership_transfer_requests fk_rails_21e598725f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_ownership_transfer_requests
    ADD CONSTRAINT fk_rails_21e598725f FOREIGN KEY (destination_visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitor_withdrawal_flow_events fk_rails_241fa58f6a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_241fa58f6a FOREIGN KEY (visitor_id) REFERENCES public.visitors(id) ON DELETE CASCADE;


--
-- Name: com_enforcement_identifier_effects fk_rails_25cb89edf0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_enforcement_identifier_effects
    ADD CONSTRAINT fk_rails_25cb89edf0 FOREIGN KEY (com_enforcement_case_id) REFERENCES public.com_enforcement_cases(id);


--
-- Name: individual_delegation_grants fk_rails_2705c030d3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_delegation_grants
    ADD CONSTRAINT fk_rails_2705c030d3 FOREIGN KEY (individual_id) REFERENCES public.individuals(id);


--
-- Name: individual_memberships fk_rails_282317620e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT fk_rails_282317620e FOREIGN KEY (individual_id) REFERENCES public.individuals(id);


--
-- Name: visitor_telephones fk_rails_2de4d12c9f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_telephones
    ADD CONSTRAINT fk_rails_2de4d12c9f FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitor_secret_credentials fk_rails_2ee7e81748; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credentials
    ADD CONSTRAINT fk_rails_2ee7e81748 FOREIGN KEY (visitor_secret_credential_status_id) REFERENCES public.visitor_secret_credential_statuses(id);


--
-- Name: individual_ownership_transfer_requests fk_rails_30884b2d54; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_ownership_transfer_requests
    ADD CONSTRAINT fk_rails_30884b2d54 FOREIGN KEY (source_visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitor_banners fk_rails_329012d103; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_banners
    ADD CONSTRAINT fk_rails_329012d103 FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitor_preference_adult_content_gates fk_rails_33ff94718e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_adult_content_gates
    ADD CONSTRAINT fk_rails_33ff94718e FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: individual_assignments fk_rails_35d7073162; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_assignments
    ADD CONSTRAINT fk_rails_35d7073162 FOREIGN KEY (individual_id) REFERENCES public.individuals(id);


--
-- Name: com_enforcement_principal_effects fk_rails_36c24dea97; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_enforcement_principal_effects
    ADD CONSTRAINT fk_rails_36c24dea97 FOREIGN KEY (com_enforcement_case_id) REFERENCES public.com_enforcement_cases(id);


--
-- Name: visitor_preference_densities fk_rails_3804faa7b8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_densities
    ADD CONSTRAINT fk_rails_3804faa7b8 FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: company_ownership_transfer_requests fk_rails_394ed31da6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_ownership_transfer_requests
    ADD CONSTRAINT fk_rails_394ed31da6 FOREIGN KEY (source_visitor_id) REFERENCES public.visitors(id);


--
-- Name: individual_memberships fk_rails_39edef8680; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT fk_rails_39edef8680 FOREIGN KEY (approved_by_individual_id) REFERENCES public.individuals(id) ON DELETE SET NULL;


--
-- Name: visitor_preference_densities fk_rails_3ae8df8c50; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_densities
    ADD CONSTRAINT fk_rails_3ae8df8c50 FOREIGN KEY (option_id) REFERENCES public.visitor_preference_density_options(id);


--
-- Name: visitor_passkeys fk_rails_3ced60caec; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_passkeys
    ADD CONSTRAINT fk_rails_3ced60caec FOREIGN KEY (status_id) REFERENCES public.visitor_passkey_statuses(id);


--
-- Name: visitor_withdrawal_flows fk_rails_3e7b55d34f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flows
    ADD CONSTRAINT fk_rails_3e7b55d34f FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitor_preference_time_formats fk_rails_3ec34cc9a9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_time_formats
    ADD CONSTRAINT fk_rails_3ec34cc9a9 FOREIGN KEY (option_id) REFERENCES public.visitor_preference_time_format_options(id);


--
-- Name: individual_memberships fk_rails_4065f69d7a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT fk_rails_4065f69d7a FOREIGN KEY (company_unit_id) REFERENCES public.company_units(id);


--
-- Name: visitor_secret_credentials fk_rails_41951b924f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credentials
    ADD CONSTRAINT fk_rails_41951b924f FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: company_units fk_rails_41ac273cbf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_units
    ADD CONSTRAINT fk_rails_41ac273cbf FOREIGN KEY (parent_id) REFERENCES public.company_units(id);


--
-- Name: visitor_preference_date_formats fk_rails_4433ba0e7f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_date_formats
    ADD CONSTRAINT fk_rails_4433ba0e7f FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: visitor_processor_erasure_notifications fk_rails_4944a6f18c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_processor_erasure_notifications
    ADD CONSTRAINT fk_rails_4944a6f18c FOREIGN KEY (visitor_privacy_request_id) REFERENCES public.visitor_privacy_requests(id);


--
-- Name: company_administration_grants fk_rails_4cef54cbd2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_administration_grants
    ADD CONSTRAINT fk_rails_4cef54cbd2 FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: visitor_withdrawal_flow_events fk_rails_4d4952ecfc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_4d4952ecfc FOREIGN KEY (to_status_id) REFERENCES public.visitor_withdrawal_flow_statuses(id) ON DELETE RESTRICT;


--
-- Name: individual_assignments fk_rails_4f28b22a88; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_assignments
    ADD CONSTRAINT fk_rails_4f28b22a88 FOREIGN KEY (visitor_identity_id) REFERENCES public.visitor_identities(id);


--
-- Name: company_units fk_rails_4f54e57b8b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_units
    ADD CONSTRAINT fk_rails_4f54e57b8b FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: company_ownership_transfer_requests fk_rails_515623d9b1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_ownership_transfer_requests
    ADD CONSTRAINT fk_rails_515623d9b1 FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: company_view_grants fk_rails_5254e8ba54; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_view_grants
    ADD CONSTRAINT fk_rails_5254e8ba54 FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: visitor_preference_themes fk_rails_55a774df73; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_themes
    ADD CONSTRAINT fk_rails_55a774df73 FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: individual_memberships fk_rails_59516aa7d8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT fk_rails_59516aa7d8 FOREIGN KEY (granted_by_individual_id) REFERENCES public.individuals(id) ON DELETE SET NULL;


--
-- Name: visitor_withdrawal_ceremonies fk_rails_5cdc4d0fad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_ceremonies
    ADD CONSTRAINT fk_rails_5cdc4d0fad FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitor_withdrawal_flow_events fk_rails_606617dd12; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_606617dd12 FOREIGN KEY (visitor_withdrawal_flow_id) REFERENCES public.visitor_withdrawal_flows(id);


--
-- Name: individual_memberships fk_rails_641ad18d67; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT fk_rails_641ad18d67 FOREIGN KEY (revoked_by_individual_id) REFERENCES public.individuals(id) ON DELETE SET NULL;


--
-- Name: visitor_preference_motions fk_rails_654c495cfe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_motions
    ADD CONSTRAINT fk_rails_654c495cfe FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: company_ownership_transfer_requests fk_rails_6b040db491; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_ownership_transfer_requests
    ADD CONSTRAINT fk_rails_6b040db491 FOREIGN KEY (destination_visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitor_preference_regions fk_rails_6caa4ea665; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_regions
    ADD CONSTRAINT fk_rails_6caa4ea665 FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: individual_ownerships fk_rails_6d961be465; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_ownerships
    ADD CONSTRAINT fk_rails_6d961be465 FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitors fk_rails_6e2a03b63d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitors
    ADD CONSTRAINT fk_rails_6e2a03b63d FOREIGN KEY (mfa_status_id) REFERENCES public.visitor_mfa_statuses(id);


--
-- Name: com_enforcement_appeals fk_rails_761c041c0c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_enforcement_appeals
    ADD CONSTRAINT fk_rails_761c041c0c FOREIGN KEY (com_enforcement_case_id) REFERENCES public.com_enforcement_cases(id);


--
-- Name: company_view_grants fk_rails_76b4415d0a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_view_grants
    ADD CONSTRAINT fk_rails_76b4415d0a FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitor_preference_regions fk_rails_77bf53dc27; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_regions
    ADD CONSTRAINT fk_rails_77bf53dc27 FOREIGN KEY (option_id) REFERENCES public.visitor_preference_region_options(id);


--
-- Name: individual_memberships fk_rails_77f6de8097; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT fk_rails_77f6de8097 FOREIGN KEY (membership_kind_id) REFERENCES public.individual_membership_kinds(id);


--
-- Name: individual_memberships fk_rails_790f1edfff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT fk_rails_790f1edfff FOREIGN KEY (membership_state_id) REFERENCES public.individual_membership_states(id);


--
-- Name: visitor_retention_holds fk_rails_7c4b79d5a2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_retention_holds
    ADD CONSTRAINT fk_rails_7c4b79d5a2 FOREIGN KEY (status_id) REFERENCES public.visitor_retention_hold_statuses(id);


--
-- Name: visitor_withdrawal_flows fk_rails_8021cd7888; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flows
    ADD CONSTRAINT fk_rails_8021cd7888 FOREIGN KEY (status_id) REFERENCES public.visitor_withdrawal_flow_statuses(id);


--
-- Name: individual_ownership_transfer_requests fk_rails_809e7fba81; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_ownership_transfer_requests
    ADD CONSTRAINT fk_rails_809e7fba81 FOREIGN KEY (individual_id) REFERENCES public.individuals(id);


--
-- Name: visitor_preference_languages fk_rails_8bf3bcafe7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_languages
    ADD CONSTRAINT fk_rails_8bf3bcafe7 FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: individual_view_grants fk_rails_8d32ee04a2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_view_grants
    ADD CONSTRAINT fk_rails_8d32ee04a2 FOREIGN KEY (individual_id) REFERENCES public.individuals(id);


--
-- Name: visitor_withdrawal_flow_events fk_rails_8ff74bc1cb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_8ff74bc1cb FOREIGN KEY (from_status_id) REFERENCES public.visitor_withdrawal_flow_statuses(id) ON DELETE RESTRICT;


--
-- Name: individuals fk_rails_9297b83ebd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individuals
    ADD CONSTRAINT fk_rails_9297b83ebd FOREIGN KEY (visitor_identity_id) REFERENCES public.visitor_identities(id) ON DELETE RESTRICT;


--
-- Name: visitor_emails fk_rails_9525e3bd11; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_emails
    ADD CONSTRAINT fk_rails_9525e3bd11 FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitor_preference_timezones fk_rails_9581543eba; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_timezones
    ADD CONSTRAINT fk_rails_9581543eba FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: company_ownerships fk_rails_99164ced21; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_ownerships
    ADD CONSTRAINT fk_rails_99164ced21 FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitor_preference_currencies fk_rails_9aa83176b2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_currencies
    ADD CONSTRAINT fk_rails_9aa83176b2 FOREIGN KEY (option_id) REFERENCES public.visitor_preference_currency_options(id);


--
-- Name: visitor_preference_adult_content_gates fk_rails_a04d2550c9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_adult_content_gates
    ADD CONSTRAINT fk_rails_a04d2550c9 FOREIGN KEY (option_id) REFERENCES public.visitor_preference_adult_content_gate_options(id);


--
-- Name: visitor_authority_locks fk_rails_a518b01f16; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_authority_locks
    ADD CONSTRAINT fk_rails_a518b01f16 FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: individual_administration_grants fk_rails_a6727d20dc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_administration_grants
    ADD CONSTRAINT fk_rails_a6727d20dc FOREIGN KEY (individual_id) REFERENCES public.individuals(id);


--
-- Name: company_administration_grants fk_rails_ac2f4f999e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_administration_grants
    ADD CONSTRAINT fk_rails_ac2f4f999e FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: individual_memberships fk_rails_ad4bcaff08; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT fk_rails_ad4bcaff08 FOREIGN KEY (revoke_reason_id) REFERENCES public.individual_membership_revoke_reasons(id);


--
-- Name: company_unit_closures fk_rails_aebf41d710; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_unit_closures
    ADD CONSTRAINT fk_rails_aebf41d710 FOREIGN KEY (descendant_id) REFERENCES public.company_units(id);


--
-- Name: visitor_preference_currencies fk_rails_b17c0b68b8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_currencies
    ADD CONSTRAINT fk_rails_b17c0b68b8 FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: com_enforcement_principal_links fk_rails_b1a1063626; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_enforcement_principal_links
    ADD CONSTRAINT fk_rails_b1a1063626 FOREIGN KEY (com_enforcement_case_id) REFERENCES public.com_enforcement_cases(id);


--
-- Name: individual_usage_grants fk_rails_b3b336dfac; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_usage_grants
    ADD CONSTRAINT fk_rails_b3b336dfac FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitors fk_rails_b66f17957a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitors
    ADD CONSTRAINT fk_rails_b66f17957a FOREIGN KEY (status_id) REFERENCES public.visitor_statuses(id);


--
-- Name: visitor_privacy_requests fk_rails_baf0223015; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_privacy_requests
    ADD CONSTRAINT fk_rails_baf0223015 FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitor_identities fk_rails_bc90881f37; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_identities
    ADD CONSTRAINT fk_rails_bc90881f37 FOREIGN KEY (status_id) REFERENCES public.visitor_identity_states(id);


--
-- Name: visitor_processor_erasure_notifications fk_rails_c1757266a2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_processor_erasure_notifications
    ADD CONSTRAINT fk_rails_c1757266a2 FOREIGN KEY (status_id) REFERENCES public.visitor_processor_erasure_notification_statuses(id);


--
-- Name: visitor_telephones fk_rails_c534739d95; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_telephones
    ADD CONSTRAINT fk_rails_c534739d95 FOREIGN KEY (visitor_telephone_status_id) REFERENCES public.visitor_telephone_statuses(id);


--
-- Name: visitor_preferences fk_rails_c56f0041b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preferences
    ADD CONSTRAINT fk_rails_c56f0041b9 FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: company_ownerships fk_rails_c81d09206c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_ownerships
    ADD CONSTRAINT fk_rails_c81d09206c FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: visitor_passkeys fk_rails_cb59e99a6f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_passkeys
    ADD CONSTRAINT fk_rails_cb59e99a6f FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: individual_delegation_grants fk_rails_cc68d0c1b6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_delegation_grants
    ADD CONSTRAINT fk_rails_cc68d0c1b6 FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitor_preference_motions fk_rails_d111a7bfa7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_motions
    ADD CONSTRAINT fk_rails_d111a7bfa7 FOREIGN KEY (option_id) REFERENCES public.visitor_preference_motion_options(id);


--
-- Name: visitor_preference_time_formats fk_rails_d178d34815; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_time_formats
    ADD CONSTRAINT fk_rails_d178d34815 FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: visitor_preference_date_formats fk_rails_d2280f99f6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_date_formats
    ADD CONSTRAINT fk_rails_d2280f99f6 FOREIGN KEY (option_id) REFERENCES public.visitor_preference_date_format_options(id);


--
-- Name: visitors fk_rails_d25b75677b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitors
    ADD CONSTRAINT fk_rails_d25b75677b FOREIGN KEY (visibility_id) REFERENCES public.visitor_visibilities(id);


--
-- Name: individual_ownerships fk_rails_dc18c4bfb3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_ownerships
    ADD CONSTRAINT fk_rails_dc18c4bfb3 FOREIGN KEY (individual_id) REFERENCES public.individuals(id);


--
-- Name: company_delegation_grants fk_rails_ddeff82c9f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_delegation_grants
    ADD CONSTRAINT fk_rails_ddeff82c9f FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: visitor_secret_credentials fk_rails_e1dad63cb9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credentials
    ADD CONSTRAINT fk_rails_e1dad63cb9 FOREIGN KEY (visitor_secret_credential_kind_id) REFERENCES public.visitor_secret_credential_kinds(id);


--
-- Name: individual_view_grants fk_rails_e5f67b94dc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_view_grants
    ADD CONSTRAINT fk_rails_e5f67b94dc FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitor_preference_timezones fk_rails_e71018d351; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_timezones
    ADD CONSTRAINT fk_rails_e71018d351 FOREIGN KEY (option_id) REFERENCES public.visitor_preference_timezone_options(id);


--
-- Name: individual_administration_grants fk_rails_e7f83bfbb4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_administration_grants
    ADD CONSTRAINT fk_rails_e7f83bfbb4 FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitor_preference_themes fk_rails_eb8a488b93; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_themes
    ADD CONSTRAINT fk_rails_eb8a488b93 FOREIGN KEY (option_id) REFERENCES public.visitor_preference_theme_options(id);


--
-- Name: individual_usage_grants fk_rails_ee1eb56cae; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_usage_grants
    ADD CONSTRAINT fk_rails_ee1eb56cae FOREIGN KEY (individual_id) REFERENCES public.individuals(id);


--
-- Name: visitor_privacy_requests fk_rails_efd7dbc62c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_privacy_requests
    ADD CONSTRAINT fk_rails_efd7dbc62c FOREIGN KEY (status_id) REFERENCES public.visitor_privacy_request_statuses(id);


--
-- Name: visitor_enforcement_recovery_ceremonies fk_rails_f886bbbdce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_enforcement_recovery_ceremonies
    ADD CONSTRAINT fk_rails_f886bbbdce FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: company_unit_closures fk_rails_ff8f5a8c85; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_unit_closures
    ADD CONSTRAINT fk_rails_ff8f5a8c85 FOREIGN KEY (ancestor_id) REFERENCES public.company_units(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260921133000'),
('20260917120001'),
('20260831064102'),
('20260830120000'),
('20260729130000'),
('20260729120000'),
('20260727120004'),
('20260727120003'),
('20260727120002'),
('20260727120001'),
('20260727120000'),
('20260721090000'),
('20260719100001'),
('20260719100000'),
('20260703020003'),
('20260703020002'),
('20260703020001'),
('20260703020000'),
('20260703010000'),
('20260627000001'),
('20260626000004'),
('20260626000003'),
('20260626000002'),
('20260626000001'),
('20260623100000'),
('20260616150021'),
('20260616150020'),
('20260616150011'),
('20260616150010'),
('20260616150005'),
('20260614090001'),
('20260614090000'),
('20260612100000'),
('20260612000001'),
('20260530032500'),
('20260530032400'),
('20260530032200'),
('20260530032100'),
('20260530031000'),
('20260528162002'),
('20260526130001'),
('20260526090000'),
('20260525131000'),
('20260525120000'),
('20260520143101'),
('20260520143001'),
('20260520133001'),
('20260520120001'),
('20260519173000'),
('20260519161002'),
('20260519094001'),
('20260518181000'),
('20260518180000'),
('20260518170600'),
('20260518170500'),
('20260518170001'),
('20260518170000'),
('20260518163000'),
('20260518121001'),
('20260518121000'),
('20260518120000'),
('20260514143000'),
('20260514140000'),
('20260513161000'),
('20260513130001'),
('20260513130000'),
('20260513121500'),
('20260512111000'),
('20260511223500'),
('20260511223458'),
('20260511223457'),
('20260511090002'),
('20260508151000'),
('20260508150000'),
('20260508140999'),
('20260508140932'),
('20260508135008'),
('20260508135006'),
('20260506194400'),
('20260329120000'),
('20260329084527'),
('20260329021000'),
('20260329020000'),
('20260329010000'),
('20260325143000'),
('20260309000001'),
('20260202220000'),
('20251230080061'),
('20251230060001'),
('20251228000007'),
('20251228000001'),
('20251226012721'),
('20251224171000'),
('20240627130203');

