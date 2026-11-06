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
-- Name: enforce_operator_email_terminal_otp_facts(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_operator_email_terminal_otp_facts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF (OLD.otp_consumed_at IS NOT NULL OR OLD.otp_cancelled_at IS NOT NULL) AND ROW(NEW.purpose, NEW.otp_generation, NEW.otp_verifier, NEW.otp_expires_at, NEW.otp_consumed_at, NEW.otp_cancelled_at, NEW.otp_receipt_verifier, NEW.otp_result_expires_at, NEW.surface, NEW.transaction_id, NEW.actor_ref, NEW.session_ref, NEW.operation, NEW.expires_at, NEW.email_candidate_ref, NEW.normalized_email_digest, NEW.bootstrap_ceremony_transaction_ref) IS DISTINCT FROM ROW(OLD.purpose, OLD.otp_generation, OLD.otp_verifier, OLD.otp_expires_at, OLD.otp_consumed_at, OLD.otp_cancelled_at, OLD.otp_receipt_verifier, OLD.otp_result_expires_at, OLD.surface, OLD.transaction_id, OLD.actor_ref, OLD.session_ref, OLD.operation, OLD.expires_at, OLD.email_candidate_ref, OLD.normalized_email_digest, OLD.bootstrap_ceremony_transaction_ref) THEN RAISE EXCEPTION 'terminal OTP facts are immutable'; END IF; RETURN NEW; END; $$;


--
-- Name: enforce_operator_telephone_terminal_otp_facts(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_operator_telephone_terminal_otp_facts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF (OLD.otp_consumed_at IS NOT NULL OR OLD.otp_cancelled_at IS NOT NULL) AND ROW(NEW.purpose, NEW.otp_generation, NEW.otp_verifier, NEW.otp_expires_at, NEW.otp_consumed_at, NEW.otp_cancelled_at, NEW.otp_receipt_verifier, NEW.otp_result_expires_at, NEW.surface, NEW.transaction_id, NEW.actor_ref, NEW.session_ref, NEW.operation, NEW.expires_at, NEW.telephone_candidate_ref, NEW.normalized_number_digest) IS DISTINCT FROM ROW(OLD.purpose, OLD.otp_generation, OLD.otp_verifier, OLD.otp_expires_at, OLD.otp_consumed_at, OLD.otp_cancelled_at, OLD.otp_receipt_verifier, OLD.otp_result_expires_at, OLD.surface, OLD.transaction_id, OLD.actor_ref, OLD.session_ref, OLD.operation, OLD.expires_at, OLD.telephone_candidate_ref, OLD.normalized_number_digest) THEN RAISE EXCEPTION 'terminal OTP facts are immutable'; END IF; RETURN NEW; END; $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

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
-- Name: op_consumed_jtis; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.op_consumed_jtis (
    id bigint NOT NULL,
    purpose character varying(64) NOT NULL,
    issuer character varying(255) NOT NULL,
    realm character varying(3) NOT NULL,
    client_id character varying(64) NOT NULL,
    jti_digest character varying(64) NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_op_org_consumed_jtis_realm CHECK (((realm)::text = 'org'::text))
);


--
-- Name: op_consumed_jtis_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.op_consumed_jtis_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: op_consumed_jtis_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.op_consumed_jtis_id_seq OWNED BY public.op_consumed_jtis.id;


--
-- Name: op_inbound_event_receipts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.op_inbound_event_receipts (
    id bigint NOT NULL,
    event_id uuid NOT NULL,
    issuer character varying(255) NOT NULL,
    realm character varying(3) NOT NULL,
    client_id character varying(64) NOT NULL,
    event_type character varying(64) NOT NULL,
    committed_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_op_org_inbound_event_receipts_realm CHECK (((realm)::text = 'org'::text))
);


--
-- Name: op_inbound_event_receipts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.op_inbound_event_receipts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: op_inbound_event_receipts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.op_inbound_event_receipts_id_seq OWNED BY public.op_inbound_event_receipts.id;


--
-- Name: op_org_authority_stop_causes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.op_org_authority_stop_causes (
    id bigint CONSTRAINT op_authority_stop_causes_id_not_null NOT NULL
);


--
-- Name: op_org_authority_stop_causes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.op_org_authority_stop_causes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: op_org_authority_stop_causes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.op_org_authority_stop_causes_id_seq OWNED BY public.op_org_authority_stop_causes.id;


--
-- Name: op_org_authority_stop_epoch_cutoffs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.op_org_authority_stop_epoch_cutoffs (
    id bigint CONSTRAINT op_authority_stop_epoch_cutoffs_id_not_null NOT NULL,
    stop_id bigint CONSTRAINT op_authority_stop_epoch_cutoffs_stop_id_not_null NOT NULL,
    cutoff_epoch bigint CONSTRAINT op_authority_stop_epoch_cutoffs_cutoff_epoch_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT op_authority_stop_epoch_cutoffs_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT op_authority_stop_epoch_cutoffs_updated_at_not_null NOT NULL,
    CONSTRAINT chk_op_org_stop_cutoffs_epoch CHECK ((cutoff_epoch >= 1))
);


--
-- Name: op_org_authority_stop_epoch_cutoffs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.op_org_authority_stop_epoch_cutoffs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: op_org_authority_stop_epoch_cutoffs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.op_org_authority_stop_epoch_cutoffs_id_seq OWNED BY public.op_org_authority_stop_epoch_cutoffs.id;


--
-- Name: op_org_authority_stop_grant_targets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.op_org_authority_stop_grant_targets (
    id bigint CONSTRAINT op_authority_stop_grant_targets_id_not_null NOT NULL,
    stop_id bigint CONSTRAINT op_authority_stop_grant_targets_stop_id_not_null NOT NULL,
    grant_id bigint CONSTRAINT op_authority_stop_grant_targets_grant_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT op_authority_stop_grant_targets_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT op_authority_stop_grant_targets_updated_at_not_null NOT NULL
);


--
-- Name: op_org_authority_stop_grant_targets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.op_org_authority_stop_grant_targets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: op_org_authority_stop_grant_targets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.op_org_authority_stop_grant_targets_id_seq OWNED BY public.op_org_authority_stop_grant_targets.id;


--
-- Name: op_org_authority_stop_participant_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.op_org_authority_stop_participant_statuses (
    id bigint CONSTRAINT op_authority_stop_participant_statuses_id_not_null NOT NULL
);


--
-- Name: op_org_authority_stop_participant_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.op_org_authority_stop_participant_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: op_org_authority_stop_participant_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.op_org_authority_stop_participant_statuses_id_seq OWNED BY public.op_org_authority_stop_participant_statuses.id;


--
-- Name: op_org_authority_stop_participants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.op_org_authority_stop_participants (
    id bigint CONSTRAINT op_authority_stop_participants_id_not_null NOT NULL,
    stop_id bigint CONSTRAINT op_authority_stop_participants_stop_id_not_null NOT NULL,
    grant_id bigint CONSTRAINT op_authority_stop_participants_grant_id_not_null NOT NULL,
    status_id bigint CONSTRAINT op_authority_stop_participants_status_id_not_null NOT NULL,
    issuer character varying(255) CONSTRAINT op_authority_stop_participants_issuer_not_null NOT NULL,
    client_id character varying(64) CONSTRAINT op_authority_stop_participants_client_id_not_null NOT NULL,
    sid character varying(255) CONSTRAINT op_authority_stop_participants_sid_not_null NOT NULL,
    endpoint_identity character varying(255) CONSTRAINT op_authority_stop_participants_endpoint_identity_not_null NOT NULL,
    delivery_attempts integer DEFAULT 0 CONSTRAINT op_authority_stop_participants_delivery_attempts_not_null NOT NULL,
    next_attempt_at timestamp(6) with time zone CONSTRAINT op_authority_stop_participants_next_attempt_at_not_null NOT NULL,
    deadline_at timestamp(6) with time zone CONSTRAINT op_authority_stop_participants_deadline_at_not_null NOT NULL,
    lease_expires_at timestamp(6) with time zone CONSTRAINT op_authority_stop_participants_lease_expires_at_not_null NOT NULL,
    last_outcome character varying(64) CONSTRAINT op_authority_stop_participants_last_outcome_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT op_authority_stop_participants_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT op_authority_stop_participants_updated_at_not_null NOT NULL,
    CONSTRAINT chk_op_org_stop_participants_shape CHECK (((delivery_attempts >= 0) AND (deadline_at >= created_at)))
);


--
-- Name: op_org_authority_stop_participants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.op_org_authority_stop_participants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: op_org_authority_stop_participants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.op_org_authority_stop_participants_id_seq OWNED BY public.op_org_authority_stop_participants.id;


--
-- Name: op_org_authority_stop_root_targets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.op_org_authority_stop_root_targets (
    id bigint CONSTRAINT op_authority_stop_root_targets_id_not_null NOT NULL,
    stop_id bigint CONSTRAINT op_authority_stop_root_targets_stop_id_not_null NOT NULL,
    root_id bigint CONSTRAINT op_authority_stop_root_targets_root_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT op_authority_stop_root_targets_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT op_authority_stop_root_targets_updated_at_not_null NOT NULL
);


--
-- Name: op_org_authority_stop_root_targets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.op_org_authority_stop_root_targets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: op_org_authority_stop_root_targets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.op_org_authority_stop_root_targets_id_seq OWNED BY public.op_org_authority_stop_root_targets.id;


--
-- Name: op_org_authority_stop_scopes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.op_org_authority_stop_scopes (
    id bigint CONSTRAINT op_authority_stop_scopes_id_not_null NOT NULL
);


--
-- Name: op_org_authority_stop_scopes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.op_org_authority_stop_scopes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: op_org_authority_stop_scopes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.op_org_authority_stop_scopes_id_seq OWNED BY public.op_org_authority_stop_scopes.id;


--
-- Name: op_org_authority_stops; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.op_org_authority_stops (
    id bigint CONSTRAINT op_authority_stops_id_not_null NOT NULL,
    public_id character varying(21) CONSTRAINT op_authority_stops_public_id_not_null NOT NULL,
    realm character varying(3) CONSTRAINT op_authority_stops_realm_not_null NOT NULL,
    cause_id bigint CONSTRAINT op_authority_stops_cause_id_not_null NOT NULL,
    scope_id bigint CONSTRAINT op_authority_stops_scope_id_not_null NOT NULL,
    principal_public_id character varying(255) CONSTRAINT op_authority_stops_principal_public_id_not_null NOT NULL,
    authority_evidence_ref character varying(128) CONSTRAINT op_authority_stops_authority_evidence_ref_not_null NOT NULL,
    idempotency_digest bytea CONSTRAINT op_authority_stops_idempotency_digest_not_null NOT NULL,
    occurred_at timestamp(6) with time zone CONSTRAINT op_authority_stops_occurred_at_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT op_authority_stops_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT op_authority_stops_updated_at_not_null NOT NULL,
    CONSTRAINT chk_op_org_authority_stops_realm CHECK (((realm)::text = 'org'::text))
);


--
-- Name: op_org_authority_stops_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.op_org_authority_stops_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: op_org_authority_stops_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.op_org_authority_stops_id_seq OWNED BY public.op_org_authority_stops.id;


--
-- Name: op_org_grant_logout_hints; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.op_org_grant_logout_hints (
    id bigint NOT NULL,
    grant_id bigint NOT NULL,
    id_token text NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: op_org_grant_logout_hints_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.op_org_grant_logout_hints_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: op_org_grant_logout_hints_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.op_org_grant_logout_hints_id_seq OWNED BY public.op_org_grant_logout_hints.id;


--
-- Name: op_org_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.op_org_grants (
    id bigint NOT NULL,
    operator_token_id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    oidc_client_id character varying(64) NOT NULL,
    oidc_scope text,
    oidc_jti character varying,
    refresh_token_digest character varying,
    previous_refresh_token_digest character varying,
    refresh_token_expires_at timestamp(6) with time zone,
    refresh_token_rotated_at timestamp(6) with time zone,
    dpop_jkt character varying,
    last_used_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    last_logout_status character varying,
    last_logout_attempted_at timestamp(6) with time zone,
    logged_out_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    oidc_auth_time timestamp(6) with time zone,
    oidc_acr character varying,
    oidc_amr text,
    oidc_nonce character varying,
    oidc_access_token_max_expires_at timestamp(6) with time zone,
    device_session_id bigint NOT NULL,
    refresh_generation bigint DEFAULT 0 NOT NULL,
    authentication_epoch bigint NOT NULL,
    CONSTRAINT chk_op_org_grants_authentication_epoch CHECK ((authentication_epoch >= 0)),
    CONSTRAINT chk_op_org_grants_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: op_org_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.op_org_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: op_org_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.op_org_grants_id_seq OWNED BY public.op_org_grants.id;


--
-- Name: operator_auth_admission_binding_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_auth_admission_binding_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_auth_admission_binding_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_auth_admission_binding_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_auth_admission_binding_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_auth_admission_binding_statuses_id_seq OWNED BY public.operator_auth_admission_binding_statuses.id;


--
-- Name: operator_auth_admission_bindings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_auth_admission_bindings (
    id bigint NOT NULL,
    entry_ref uuid NOT NULL,
    purpose character varying NOT NULL,
    authorization_transaction_id bigint,
    step_up_ceremony_transaction_id bigint,
    base_token_id bigint,
    base_browser_digest character varying(64) NOT NULL,
    auth_ceremony_session_id bigint,
    confirmation_ref uuid,
    base_confirmed_at timestamp with time zone,
    redeemed_at timestamp with time zone,
    admitted_auth_ceremony_session_id bigint,
    retired_at timestamp with time zone,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    entry_intent character varying NOT NULL,
    curfew_at timestamp(6) with time zone NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    CONSTRAINT operator_admission_binding_entry_intent CHECK (((((purpose)::text = ANY ((ARRAY['authentication_handoff'::character varying, 'invitation_handoff'::character varying])::text[])) AND ((entry_intent)::text = ANY ((ARRAY['sign_in'::character varying, 'sign_up'::character varying])::text[]))) OR (((purpose)::text = ANY ((ARRAY['step_up_handoff'::character varying, 'reauthentication_handoff'::character varying, 'bootstrap_handoff'::character varying, 'credential_registration_handoff'::character varying, 'credential_change_handoff'::character varying])::text[])) AND ((entry_intent)::text = 'not_applicable'::text)))),
    CONSTRAINT operator_admission_binding_status_facts CHECK ((((status_id = 10) AND (auth_ceremony_session_id IS NULL) AND (confirmation_ref IS NULL) AND (base_confirmed_at IS NULL) AND (redeemed_at IS NULL) AND (admitted_auth_ceremony_session_id IS NULL) AND (retired_at IS NULL)) OR ((status_id = 20) AND (auth_ceremony_session_id IS NOT NULL) AND (confirmation_ref IS NOT NULL) AND (base_confirmed_at IS NULL) AND (redeemed_at IS NULL) AND (admitted_auth_ceremony_session_id IS NULL) AND (retired_at IS NULL)) OR ((status_id = 30) AND (auth_ceremony_session_id IS NOT NULL) AND (confirmation_ref IS NOT NULL) AND (base_confirmed_at IS NOT NULL) AND (redeemed_at IS NULL) AND (admitted_auth_ceremony_session_id IS NULL) AND (retired_at IS NULL)) OR ((status_id = 40) AND (auth_ceremony_session_id IS NOT NULL) AND (confirmation_ref IS NOT NULL) AND (base_confirmed_at IS NOT NULL) AND (redeemed_at IS NOT NULL) AND (admitted_auth_ceremony_session_id IS NOT NULL) AND (retired_at IS NULL)) OR ((status_id = 90) AND (redeemed_at IS NULL) AND (admitted_auth_ceremony_session_id IS NULL) AND (retired_at IS NOT NULL)) OR ((status_id = 91) AND (auth_ceremony_session_id IS NOT NULL) AND (confirmation_ref IS NOT NULL) AND (base_confirmed_at IS NOT NULL) AND (redeemed_at IS NOT NULL) AND (admitted_auth_ceremony_session_id IS NOT NULL) AND (retired_at IS NULL)))),
    CONSTRAINT operator_admission_bindings_auth_proof_pair CHECK ((((auth_ceremony_session_id IS NULL) AND (confirmation_ref IS NULL)) OR ((auth_ceremony_session_id IS NOT NULL) AND (confirmation_ref IS NOT NULL)))),
    CONSTRAINT operator_admission_bindings_confirmation_requires_auth CHECK (((base_confirmed_at IS NULL) OR ((auth_ceremony_session_id IS NOT NULL) AND (confirmation_ref IS NOT NULL)))),
    CONSTRAINT operator_admission_bindings_one_parent CHECK ((num_nonnulls(authorization_transaction_id, step_up_ceremony_transaction_id) = 1)),
    CONSTRAINT operator_admission_bindings_parent_purpose CHECK ((((authorization_transaction_id IS NULL) OR ((purpose)::text = ANY ((ARRAY['authentication_handoff'::character varying, 'invitation_handoff'::character varying])::text[]))) AND ((step_up_ceremony_transaction_id IS NULL) OR ((purpose)::text = ANY ((ARRAY['step_up_handoff'::character varying, 'reauthentication_handoff'::character varying, 'bootstrap_handoff'::character varying, 'credential_registration_handoff'::character varying, 'credential_change_handoff'::character varying])::text[]))))),
    CONSTRAINT operator_admission_bindings_redemption_pair CHECK ((((redeemed_at IS NULL) AND (admitted_auth_ceremony_session_id IS NULL)) OR ((redeemed_at IS NOT NULL) AND (admitted_auth_ceremony_session_id IS NOT NULL)))),
    CONSTRAINT operator_admission_bindings_redemption_requires_confirmation CHECK (((redeemed_at IS NULL) OR (base_confirmed_at IS NOT NULL))),
    CONSTRAINT operator_admission_bindings_step_up_token CHECK ((((purpose)::text <> ALL ((ARRAY['step_up_handoff'::character varying, 'reauthentication_handoff'::character varying, 'bootstrap_handoff'::character varying, 'credential_registration_handoff'::character varying, 'credential_change_handoff'::character varying])::text[])) OR (base_token_id IS NOT NULL))),
    CONSTRAINT operator_admission_bindings_terminal_exclusive CHECK ((NOT ((redeemed_at IS NOT NULL) AND (retired_at IS NOT NULL))))
);


--
-- Name: operator_auth_admission_bindings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_auth_admission_bindings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_auth_admission_bindings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_auth_admission_bindings_id_seq OWNED BY public.operator_auth_admission_bindings.id;


--
-- Name: operator_auth_ceremony_session_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_auth_ceremony_session_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_auth_ceremony_session_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_auth_ceremony_session_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_auth_ceremony_session_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_auth_ceremony_session_statuses_id_seq OWNED BY public.operator_auth_ceremony_session_statuses.id;


--
-- Name: operator_auth_ceremony_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_auth_ceremony_sessions (
    id bigint NOT NULL,
    sid_digest character varying(64) NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    revoked_at timestamp(6) with time zone,
    rotated_at timestamp(6) with time zone,
    previous_sid_digest character varying(64),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    authorization_transaction_ref character varying,
    admitted_at timestamp(6) with time zone,
    completed_at timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    authentication_method character varying,
    authentication_event_at timestamp(6) with time zone,
    admission_purpose character varying,
    step_up_ceremony_transaction_ref character varying,
    status_id bigint NOT NULL,
    CONSTRAINT operator_auth_admission_purpose_valid CHECK (((admission_purpose IS NULL) OR ((admission_purpose)::text = ANY ((ARRAY['authentication_handoff'::character varying, 'invitation_handoff'::character varying, 'step_up_handoff'::character varying, 'reauthentication_handoff'::character varying, 'bootstrap_handoff'::character varying, 'credential_registration_handoff'::character varying, 'credential_change_handoff'::character varying])::text[])))),
    CONSTRAINT operator_auth_ceremony_session_status_facts CHECK ((((status_id = 10) AND (admitted_at IS NULL) AND (authentication_method IS NULL) AND (authentication_event_at IS NULL) AND (revoked_at IS NULL) AND (completed_at IS NULL) AND (cancelled_at IS NULL)) OR ((status_id = 20) AND (admitted_at IS NOT NULL) AND (authentication_method IS NULL) AND (authentication_event_at IS NULL) AND (revoked_at IS NULL) AND (completed_at IS NULL) AND (cancelled_at IS NULL)) OR ((status_id = 30) AND (admitted_at IS NOT NULL) AND (authentication_method IS NOT NULL) AND (authentication_event_at IS NOT NULL) AND (revoked_at IS NULL) AND (completed_at IS NULL) AND (cancelled_at IS NULL)) OR ((status_id = ANY (ARRAY[(40)::bigint, (90)::bigint])) AND (revoked_at IS NOT NULL) AND (completed_at IS NULL) AND (cancelled_at IS NULL)) OR ((status_id = 91) AND (admitted_at IS NOT NULL) AND (revoked_at IS NULL) AND (completed_at IS NOT NULL) AND (cancelled_at IS NULL)) OR ((status_id = 92) AND (admitted_at IS NOT NULL) AND (authentication_method IS NULL) AND (authentication_event_at IS NULL) AND (revoked_at IS NULL) AND (completed_at IS NULL) AND (cancelled_at IS NOT NULL)) OR ((status_id = 93) AND (admitted_at IS NOT NULL) AND (authentication_method IS NOT NULL) AND (authentication_event_at IS NOT NULL) AND (revoked_at IS NULL) AND (completed_at IS NULL) AND (cancelled_at IS NOT NULL)))),
    CONSTRAINT operator_auth_ceremony_sessions_admission_binding CHECK (((authorization_transaction_ref IS NULL) OR (admitted_at IS NOT NULL))),
    CONSTRAINT operator_auth_ceremony_sessions_authentication_evidence_pair CHECK (((authentication_method IS NULL) = (authentication_event_at IS NULL))),
    CONSTRAINT operator_auth_ceremony_sessions_authentication_method CHECK (((authentication_method IS NULL) OR ((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'totp'::character varying, 'google'::character varying, 'apple'::character varying, 'entra'::character varying])::text[])))),
    CONSTRAINT operator_auth_ceremony_sessions_one_terminal_timestamp CHECK ((num_nonnulls(revoked_at, completed_at, cancelled_at) <= 1)),
    CONSTRAINT operator_auth_ceremony_transaction_exclusive CHECK ((num_nonnulls(authorization_transaction_ref, step_up_ceremony_transaction_ref) <= 1))
);


--
-- Name: operator_auth_ceremony_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_auth_ceremony_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_auth_ceremony_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_auth_ceremony_sessions_id_seq OWNED BY public.operator_auth_ceremony_sessions.id;


--
-- Name: operator_device_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_device_sessions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    staff_id bigint NOT NULL,
    dbsc_session_id_digest character varying,
    dbsc_public_key_thumbprint character varying,
    dbsc_bound_at timestamp(6) with time zone,
    dpop_jkt character varying,
    status_id bigint DEFAULT 1 NOT NULL,
    current_refresh_token_id bigint,
    refresh_token_family_id character varying,
    last_seen_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    revoke_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    last_network_hmac character varying,
    CONSTRAINT chk_operator_device_sessions_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: operator_device_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_device_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_device_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_device_sessions_id_seq OWNED BY public.operator_device_sessions.id;


--
-- Name: operator_dpop_proof_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_dpop_proof_states (
    id bigint NOT NULL,
    jti character varying,
    jkt character varying,
    nonce character varying,
    htm character varying,
    htu character varying,
    seen_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    nonce_used_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_dpop_proof_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_dpop_proof_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_dpop_proof_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_dpop_proof_states_id_seq OWNED BY public.operator_dpop_proof_states.id;


--
-- Name: operator_email_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_email_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    email_candidate_ref character varying,
    normalized_email_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    evp_nonce_digest character varying,
    evp_token_digest character varying,
    evp_outcome character varying,
    evp_failure_reason character varying,
    evp_issuer character varying,
    evp_issued_at timestamp(6) with time zone,
    evp_verified_at timestamp(6) with time zone,
    evp_consumed_at timestamp(6) with time zone,
    evp_attempt_count integer DEFAULT 0 NOT NULL,
    purpose character varying,
    otp_generation uuid,
    otp_verifier character varying,
    otp_expires_at timestamp(6) with time zone,
    otp_consumed_at timestamp(6) with time zone,
    otp_cancelled_at timestamp(6) with time zone,
    otp_receipt_verifier character varying,
    otp_result_expires_at timestamp(6) with time zone,
    bootstrap_ceremony_transaction_ref character varying,
    CONSTRAINT operator_email_ceremony_transactions_otp_material CHECK (((otp_verifier IS NULL) OR ((purpose IS NOT NULL) AND (otp_generation IS NOT NULL) AND (otp_expires_at IS NOT NULL)))),
    CONSTRAINT operator_email_ceremony_transactions_otp_purpose CHECK (((purpose IS NULL) OR ((purpose)::text = ANY ((ARRAY['sign_up'::character varying, 'sign_in'::character varying, 'recovery'::character varying, 'withdrawal'::character varying, 'credential_registration'::character varying])::text[])))),
    CONSTRAINT operator_email_otp_bootstrap_purpose CHECK (((bootstrap_ceremony_transaction_ref IS NULL) OR (((operation)::text = 'registration'::text) AND (purpose IS NOT NULL) AND ((purpose)::text = 'credential_registration'::text)))),
    CONSTRAINT operator_email_otp_proof_shape CHECK (((otp_generation IS NULL) OR (((purpose IS NOT NULL) AND ((actor_ref)::text <> ''::text) AND ((session_ref)::text <> ''::text) AND (email_candidate_ref IS NOT NULL) AND ((email_candidate_ref)::text <> ''::text) AND ((normalized_email_digest IS NULL) OR ((normalized_email_digest)::text ~ '^[0-9a-f]{64}$'::text)) AND (otp_expires_at IS NOT NULL) AND isfinite(otp_expires_at) AND isfinite(expires_at) AND (((otp_consumed_at IS NULL) AND (otp_cancelled_at IS NULL) AND (otp_verifier IS NOT NULL) AND ((otp_verifier)::text ~ '^[0-9a-f]{64}$'::text) AND (otp_receipt_verifier IS NULL) AND (otp_result_expires_at IS NULL)) OR ((otp_consumed_at IS NOT NULL) AND isfinite(otp_consumed_at) AND (otp_consumed_at < otp_expires_at) AND (otp_cancelled_at IS NULL) AND (otp_verifier IS NULL) AND (otp_receipt_verifier IS NOT NULL) AND (otp_result_expires_at IS NOT NULL)) OR ((otp_cancelled_at IS NOT NULL) AND isfinite(otp_cancelled_at) AND (otp_consumed_at IS NULL) AND (otp_verifier IS NULL) AND (otp_receipt_verifier IS NULL) AND (otp_result_expires_at IS NULL)))) IS TRUE))),
    CONSTRAINT operator_email_otp_receipt_bounds CHECK ((((otp_receipt_verifier IS NULL) AND (otp_result_expires_at IS NULL)) OR ((otp_receipt_verifier IS NOT NULL) AND ((otp_receipt_verifier)::text ~ '^[0-9a-f]{64}$'::text) AND (otp_consumed_at IS NOT NULL) AND (otp_cancelled_at IS NULL) AND (otp_verifier IS NULL) AND (otp_result_expires_at IS NOT NULL) AND isfinite(otp_result_expires_at) AND (otp_result_expires_at > otp_consumed_at) AND (otp_result_expires_at <= (otp_consumed_at + '00:01:00'::interval)) AND (otp_result_expires_at <= expires_at))))
);


--
-- Name: operator_email_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_email_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_email_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_email_ceremony_transactions_id_seq OWNED BY public.operator_email_ceremony_transactions.id;


--
-- Name: operator_oauth_callback_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_oauth_callback_states (
    id bigint CONSTRAINT operator_social_callback_states_id_not_null NOT NULL,
    state_digest character varying CONSTRAINT operator_social_callback_states_state_digest_not_null NOT NULL,
    provider character varying CONSTRAINT operator_social_callback_states_provider_not_null NOT NULL,
    intent character varying,
    issued_at timestamp(6) with time zone CONSTRAINT operator_social_callback_states_issued_at_not_null NOT NULL,
    expires_at timestamp(6) with time zone CONSTRAINT operator_social_callback_states_expires_at_not_null NOT NULL,
    consumed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone CONSTRAINT operator_social_callback_states_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT operator_social_callback_states_updated_at_not_null NOT NULL
);


--
-- Name: operator_oauth_callback_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_oauth_callback_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_oauth_callback_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_oauth_callback_states_id_seq OWNED BY public.operator_oauth_callback_states.id;


--
-- Name: operator_oidc_authorization_transaction_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_oidc_authorization_transaction_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_oidc_authorization_transaction_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_oidc_authorization_transaction_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_oidc_authorization_transaction_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_oidc_authorization_transaction_statuses_id_seq OWNED BY public.operator_oidc_authorization_transaction_statuses.id;


--
-- Name: operator_oidc_authorization_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_oidc_authorization_transactions (
    id bigint NOT NULL,
    transaction_id character varying CONSTRAINT operator_oidc_authorization_transaction_transaction_id_not_null NOT NULL,
    surface character varying NOT NULL,
    intent character varying NOT NULL,
    client_id character varying NOT NULL,
    redirect_uri character varying NOT NULL,
    response_type character varying NOT NULL,
    scope character varying NOT NULL,
    state character varying NOT NULL,
    nonce character varying NOT NULL,
    code_challenge character varying CONSTRAINT operator_oidc_authorization_transaction_code_challenge_not_null NOT NULL,
    code_challenge_method character varying CONSTRAINT operator_oidc_authorization_tran_code_challenge_method_not_null NOT NULL,
    login_challenge character varying CONSTRAINT operator_oidc_authorization_transactio_login_challenge_not_null NOT NULL,
    login_challenge_expires_at timestamp(6) with time zone CONSTRAINT operator_oidc_authorization_login_challenge_expires_at_not_null NOT NULL,
    authenticated_at timestamp(6) with time zone,
    actor_ref character varying,
    session_ref character varying,
    auth_method character varying,
    acr character varying,
    consumed_at timestamp(6) with time zone,
    expires_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    oidc_prompt character varying,
    oidc_max_age integer,
    result_generation integer DEFAULT 0 CONSTRAINT operator_oidc_authorization_transact_result_generation_not_null NOT NULL,
    result_digest character varying(64),
    result_expires_at timestamp(6) with time zone,
    result_consumed_at timestamp(6) with time zone,
    browser_session_ref character varying,
    base_finalized_at timestamp(6) with time zone,
    authorization_grant_redeemed_at timestamp(6) with time zone,
    canceled_at timestamp with time zone,
    cancellation_handoff_digest character varying(64),
    cancellation_handoff_ref uuid,
    cancellation_handoff_ciphertext text,
    status_id bigint NOT NULL,
    CONSTRAINT chk_operator_oidc_txns_max_age CHECK ((oidc_max_age >= 0)),
    CONSTRAINT operator_oidc_auth_cancellation_handoff_pair CHECK ((((cancellation_handoff_ref IS NULL) AND (cancellation_handoff_ciphertext IS NULL)) OR ((cancellation_handoff_ref IS NOT NULL) AND (cancellation_handoff_ciphertext IS NOT NULL)))),
    CONSTRAINT operator_oidc_auth_cancellation_handoff_valid CHECK (((cancellation_handoff_digest IS NULL) OR ((cancellation_handoff_digest)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT operator_oidc_auth_transactions_result_generation_nonnegative CHECK ((result_generation >= 0)),
    CONSTRAINT operator_oidc_authorization_transaction_status_facts CHECK ((((status_id = 10) AND (authenticated_at IS NULL) AND (consumed_at IS NULL) AND (canceled_at IS NULL) AND (base_finalized_at IS NULL) AND (browser_session_ref IS NULL)) OR ((status_id = 20) AND (authenticated_at IS NOT NULL) AND (consumed_at IS NULL) AND (canceled_at IS NULL) AND (base_finalized_at IS NULL) AND (browser_session_ref IS NULL)) OR ((status_id = 30) AND (authenticated_at IS NOT NULL) AND (consumed_at IS NOT NULL) AND (canceled_at IS NULL) AND (((base_finalized_at IS NULL) AND (browser_session_ref IS NULL)) OR ((base_finalized_at IS NOT NULL) AND (browser_session_ref IS NOT NULL)))) OR ((status_id = 90) AND (canceled_at IS NOT NULL) AND (consumed_at IS NULL) AND (base_finalized_at IS NULL) AND (browser_session_ref IS NULL))))
);


--
-- Name: operator_oidc_authorization_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_oidc_authorization_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_oidc_authorization_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_oidc_authorization_transactions_id_seq OWNED BY public.operator_oidc_authorization_transactions.id;


--
-- Name: operator_oidc_connections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_oidc_connections (
    id bigint CONSTRAINT staff_oidc_connections_id_not_null NOT NULL,
    public_id character varying(21) CONSTRAINT staff_oidc_connections_public_id_not_null NOT NULL,
    staff_id bigint CONSTRAINT staff_oidc_connections_staff_id_not_null NOT NULL,
    client_id character varying(64) CONSTRAINT staff_oidc_connections_client_id_not_null NOT NULL,
    scope character varying,
    last_used_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone CONSTRAINT staff_oidc_connections_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT staff_oidc_connections_updated_at_not_null NOT NULL,
    CONSTRAINT chk_operator_oidc_connections_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: operator_oidc_connections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_oidc_connections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_oidc_connections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_oidc_connections_id_seq OWNED BY public.operator_oidc_connections.id;


--
-- Name: operator_passkey_ceremony_candidates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_passkey_ceremony_candidates (
    id bigint NOT NULL,
    ref character varying NOT NULL,
    digest character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    step_up_ceremony_transaction_ref character varying CONSTRAINT operator_passkey_ceremony_c_step_up_ceremony_transacti_not_null NOT NULL,
    webauthn_id character varying NOT NULL,
    public_key text NOT NULL,
    sign_count bigint DEFAULT 0 NOT NULL,
    description character varying NOT NULL,
    transports jsonb DEFAULT '[]'::jsonb NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    consumed_at timestamp with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_operator_passkey_candidates_sign_count CHECK ((sign_count >= 0))
);


--
-- Name: operator_passkey_ceremony_candidates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_passkey_ceremony_candidates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_passkey_ceremony_candidates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_passkey_ceremony_candidates_id_seq OWNED BY public.operator_passkey_ceremony_candidates.id;


--
-- Name: operator_passkey_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_passkey_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    rp_id character varying NOT NULL,
    origin character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    credential_candidate_ref character varying,
    credential_candidate_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    step_up_ceremony_transaction_ref character varying
);


--
-- Name: operator_passkey_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_passkey_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_passkey_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_passkey_ceremony_transactions_id_seq OWNED BY public.operator_passkey_ceremony_transactions.id;


--
-- Name: operator_secret_credential_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_secret_credential_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying CONSTRAINT operator_secret_credential_ceremony_tra_transaction_id_not_null NOT NULL,
    surface character varying CONSTRAINT operator_secret_credential_ceremony_transactio_surface_not_null NOT NULL,
    actor_ref character varying CONSTRAINT operator_secret_credential_ceremony_transact_actor_ref_not_null NOT NULL,
    session_ref character varying CONSTRAINT operator_secret_credential_ceremony_transa_session_ref_not_null NOT NULL,
    operation character varying CONSTRAINT operator_secret_credential_ceremony_transact_operation_not_null NOT NULL,
    status character varying DEFAULT 'pending'::character varying CONSTRAINT operator_secret_credential_ceremony_transaction_status_not_null NOT NULL,
    grant_jti character varying CONSTRAINT operator_secret_credential_ceremony_transact_grant_jti_not_null NOT NULL,
    result_jti character varying,
    credential_candidate_ref character varying,
    credential_candidate_digest character varying,
    expires_at timestamp(6) with time zone CONSTRAINT operator_secret_credential_ceremony_transac_expires_at_not_null NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 CONSTRAINT operator_secret_credential_ceremony_trans_lock_version_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT operator_secret_credential_ceremony_transac_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT operator_secret_credential_ceremony_transac_updated_at_not_null NOT NULL
);


--
-- Name: operator_secret_credential_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_secret_credential_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_secret_credential_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_secret_credential_ceremony_transactions_id_seq OWNED BY public.operator_secret_credential_ceremony_transactions.id;


--
-- Name: operator_sensitive_admission_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_sensitive_admission_attachments (
    id bigint NOT NULL,
    sensitive_admission_id bigint CONSTRAINT operator_sensitive_admission_at_sensitive_admission_id_not_null NOT NULL,
    auth_ceremony_session_digest character varying(64) CONSTRAINT operator_sensitive_admissio_auth_ceremony_session_dige_not_null NOT NULL,
    confirmation_ref uuid CONSTRAINT operator_sensitive_admission_attachme_confirmation_ref_not_null NOT NULL,
    attached_at timestamp with time zone NOT NULL,
    CONSTRAINT operator_sensitive_attach_digest CHECK (((auth_ceremony_session_digest)::text ~ '^[0-9a-f]{64}$'::text))
);


--
-- Name: operator_sensitive_admission_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_sensitive_admission_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_sensitive_admission_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_sensitive_admission_attachments_id_seq OWNED BY public.operator_sensitive_admission_attachments.id;


--
-- Name: operator_sensitive_admission_audit_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_sensitive_admission_audit_attempts (
    id bigint NOT NULL,
    outbox_id bigint NOT NULL,
    attempt_number integer CONSTRAINT operator_sensitive_admission_audit_atte_attempt_number_not_null NOT NULL,
    attempted_at timestamp with time zone CONSTRAINT operator_sensitive_admission_audit_attemp_attempted_at_not_null NOT NULL,
    outcome character varying(16) NOT NULL,
    failure_code character varying(64) CONSTRAINT operator_sensitive_admission_audit_attemp_failure_code_not_null NOT NULL,
    CONSTRAINT operator_sensitive_attempt_failure CHECK ((((failure_code)::text = ANY ((ARRAY['none'::character varying, 'chronicle_unavailable'::character varying, 'retention_policy_missing'::character varying, 'event_identity_conflict'::character varying, 'chronicle_record_invalid'::character varying, 'delivery_failed'::character varying])::text[])) AND (((outcome)::text <> 'delivered'::text) OR ((failure_code)::text = 'none'::text)))),
    CONSTRAINT operator_sensitive_attempt_outcome CHECK (((attempt_number > 0) AND ((outcome)::text = ANY ((ARRAY['delivered'::character varying, 'failed'::character varying])::text[]))))
);


--
-- Name: operator_sensitive_admission_audit_attempts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_sensitive_admission_audit_attempts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_sensitive_admission_audit_attempts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_sensitive_admission_audit_attempts_id_seq OWNED BY public.operator_sensitive_admission_audit_attempts.id;


--
-- Name: operator_sensitive_admission_audit_outboxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_sensitive_admission_audit_outboxes (
    id bigint NOT NULL,
    event_uuid uuid NOT NULL,
    event_type character varying(64) NOT NULL,
    realm character varying(3) NOT NULL,
    client_id character varying(64) NOT NULL,
    subject_ref character varying(255) CONSTRAINT operator_sensitive_admission_audit_outboxe_subject_ref_not_null NOT NULL,
    context_ref character varying(21) CONSTRAINT operator_sensitive_admission_audit_outboxe_context_ref_not_null NOT NULL,
    reason_code character varying(64) CONSTRAINT operator_sensitive_admission_audit_outboxe_reason_code_not_null NOT NULL,
    payload jsonb NOT NULL,
    occurred_at timestamp with time zone CONSTRAINT operator_sensitive_admission_audit_outboxe_occurred_at_not_null NOT NULL,
    delivery_state_id bigint CONSTRAINT operator_sensitive_admission_audit_o_delivery_state_id_not_null NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT operator_sensitive_audit_identity CHECK ((((event_type)::text = 'sensitive_admission.closed'::text) AND ((realm)::text = 'ORG'::text) AND ((client_id)::text = 'base-org-ww'::text))),
    CONSTRAINT operator_sensitive_audit_payload CHECK (((jsonb_typeof(payload) = 'object'::text) AND (payload ? 'admission_ref'::text) AND (jsonb_typeof((payload -> 'admission_ref'::text)) = 'string'::text) AND ((payload - 'admission_ref'::text) = '{}'::jsonb) AND ((payload ->> 'admission_ref'::text) = (context_ref)::text))),
    CONSTRAINT operator_sensitive_audit_reason CHECK (((reason_code)::text = ANY ((ARRAY['completed'::character varying, 'expired'::character varying, 'user_cancelled'::character varying])::text[])))
);


--
-- Name: operator_sensitive_admission_audit_outboxes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_sensitive_admission_audit_outboxes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_sensitive_admission_audit_outboxes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_sensitive_admission_audit_outboxes_id_seq OWNED BY public.operator_sensitive_admission_audit_outboxes.id;


--
-- Name: operator_sensitive_admission_confirmations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_sensitive_admission_confirmations (
    id bigint NOT NULL,
    sensitive_admission_id bigint CONSTRAINT operator_sensitive_admission_co_sensitive_admission_id_not_null NOT NULL,
    confirmed_at timestamp with time zone CONSTRAINT operator_sensitive_admission_confirmation_confirmed_at_not_null NOT NULL
);


--
-- Name: operator_sensitive_admission_confirmations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_sensitive_admission_confirmations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_sensitive_admission_confirmations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_sensitive_admission_confirmations_id_seq OWNED BY public.operator_sensitive_admission_confirmations.id;


--
-- Name: operator_sensitive_admission_redemptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_sensitive_admission_redemptions (
    id bigint NOT NULL,
    sensitive_admission_id bigint CONSTRAINT operator_sensitive_admission_re_sensitive_admission_id_not_null NOT NULL,
    auth_ceremony_session_digest character varying(64) CONSTRAINT operator_sensitive_admissi_auth_ceremony_session_dige_not_null1 NOT NULL,
    ceremony_ref character varying(21) NOT NULL,
    redeemed_at timestamp with time zone NOT NULL,
    continuation_expires_at timestamp with time zone CONSTRAINT operator_sensitive_admission_r_continuation_expires_at_not_null NOT NULL,
    CONSTRAINT operator_sensitive_redeem_values CHECK ((((auth_ceremony_session_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((ceremony_ref)::text ~ '^[A-Za-z0-9_-]{21}$'::text) AND (continuation_expires_at > redeemed_at)))
);


--
-- Name: operator_sensitive_admission_redemptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_sensitive_admission_redemptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_sensitive_admission_redemptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_sensitive_admission_redemptions_id_seq OWNED BY public.operator_sensitive_admission_redemptions.id;


--
-- Name: operator_sensitive_admission_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_sensitive_admission_sessions (
    id bigint NOT NULL,
    sensitive_admission_id bigint CONSTRAINT operator_sensitive_admission_se_sensitive_admission_id_not_null NOT NULL,
    sid_digest character varying(64) NOT NULL,
    phase character varying(16) NOT NULL,
    status character varying(16) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT operator_sensitive_session_deadline CHECK ((expires_at > created_at)),
    CONSTRAINT operator_sensitive_session_state CHECK ((((sid_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((phase)::text = ANY ((ARRAY['attached'::character varying, 'admitted'::character varying])::text[])) AND ((status)::text = ANY ((ARRAY['active'::character varying, 'revoked'::character varying])::text[]))))
);


--
-- Name: operator_sensitive_admission_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_sensitive_admission_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_sensitive_admission_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_sensitive_admission_sessions_id_seq OWNED BY public.operator_sensitive_admission_sessions.id;


--
-- Name: operator_sensitive_admissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_sensitive_admissions (
    id bigint NOT NULL,
    public_ref character varying(21) NOT NULL,
    secret_digest character varying(64) NOT NULL,
    realm character varying(3) NOT NULL,
    client_id character varying(64) NOT NULL,
    actor_subject character varying(255) NOT NULL,
    grant_sid character varying(64) NOT NULL,
    rp_session_ref character varying(64) NOT NULL,
    browser_binding_digest character varying(64) NOT NULL,
    purpose character varying(32) NOT NULL,
    provider character varying(16) NOT NULL,
    event_jti character varying(255) NOT NULL,
    event_auth_time bigint NOT NULL,
    issued_at timestamp with time zone NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    status character varying(16) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT operator_sensitive_admission_deadline CHECK (((expires_at > issued_at) AND (event_auth_time > 0))),
    CONSTRAINT operator_sensitive_admission_digests CHECK ((((secret_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((browser_binding_digest)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT operator_sensitive_admission_purpose CHECK ((((purpose)::text = 'passkey_registration'::text) AND ((provider)::text = 'none'::text))),
    CONSTRAINT operator_sensitive_admission_realm CHECK ((((realm)::text = 'org'::text) AND ((client_id)::text = 'base-org-ww'::text))),
    CONSTRAINT operator_sensitive_admission_references CHECK ((((public_ref)::text ~ '^[A-Za-z0-9_-]{21}$'::text) AND (length((actor_subject)::text) > 0) AND (length((grant_sid)::text) > 0) AND (length((rp_session_ref)::text) > 0) AND (length((event_jti)::text) > 0))),
    CONSTRAINT operator_sensitive_admission_status CHECK (((status)::text = ANY ((ARRAY['issued'::character varying, 'attached'::character varying, 'confirmed'::character varying, 'redeemed'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: operator_sensitive_admissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_sensitive_admissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_sensitive_admissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_sensitive_admissions_id_seq OWNED BY public.operator_sensitive_admissions.id;


--
-- Name: operator_session_limit_resolution_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_session_limit_resolution_states (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_session_limit_resolution_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_session_limit_resolution_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_session_limit_resolution_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_session_limit_resolution_states_id_seq OWNED BY public.operator_session_limit_resolution_states.id;


--
-- Name: operator_session_limit_resolution_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_session_limit_resolution_transactions (
    id bigint NOT NULL,
    challenge_digest character varying CONSTRAINT operator_session_limit_resolution_tra_challenge_digest_not_null NOT NULL,
    state_id bigint CONSTRAINT operator_session_limit_resolution_transaction_state_id_not_null NOT NULL,
    sign_in_flow_id bigint CONSTRAINT operator_session_limit_resolution_tran_sign_in_flow_id_not_null NOT NULL,
    oidc_authorization_transaction_id bigint,
    actor_ref character varying CONSTRAINT operator_session_limit_resolution_transactio_actor_ref_not_null NOT NULL,
    browser_binding_digest character varying CONSTRAINT operator_session_limit_resoluti_browser_binding_digest_not_null NOT NULL,
    selected_session_ref character varying,
    started_at timestamp(6) with time zone CONSTRAINT operator_session_limit_resolution_transacti_started_at_not_null NOT NULL,
    expires_at timestamp(6) with time zone CONSTRAINT operator_session_limit_resolution_transacti_expires_at_not_null NOT NULL,
    selected_at timestamp(6) with time zone,
    resolved_at timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    expired_at timestamp(6) with time zone,
    consumed_at timestamp(6) with time zone,
    finalized_at timestamp(6) with time zone,
    audit_context jsonb DEFAULT '{}'::jsonb CONSTRAINT operator_session_limit_resolution_transa_audit_context_not_null NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp without time zone CONSTRAINT operator_session_limit_resolution_transacti_discard_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp without time zone CONSTRAINT operator_session_limit_resolution_tr_purge_eligible_at_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT operator_session_limit_resolution_transacti_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT operator_session_limit_resolution_transacti_updated_at_not_null NOT NULL,
    waiting_slot smallint,
    CONSTRAINT chk_operator_resolution_state_timestamps CHECK ((((state_id = 10) AND (selected_at IS NULL) AND (resolved_at IS NULL) AND (cancelled_at IS NULL) AND (expired_at IS NULL)) OR ((state_id = 20) AND (selected_at IS NOT NULL) AND (resolved_at IS NULL) AND (cancelled_at IS NULL) AND (expired_at IS NULL)) OR ((state_id = 100) AND (resolved_at IS NOT NULL) AND (cancelled_at IS NULL) AND (expired_at IS NULL)) OR ((state_id = 910) AND (expired_at IS NOT NULL) AND (resolved_at IS NULL) AND (cancelled_at IS NULL)) OR ((state_id = 920) AND (cancelled_at IS NOT NULL) AND (resolved_at IS NULL) AND (expired_at IS NULL)))),
    CONSTRAINT chk_operator_resolution_waiting_slot_state CHECK ((((state_id = ANY (ARRAY[(10)::bigint, (20)::bigint])) AND (waiting_slot IS NOT NULL) AND (waiting_slot = 1)) OR ((state_id = ANY (ARRAY[(100)::bigint, (910)::bigint, (920)::bigint])) AND (waiting_slot IS NULL))))
);


--
-- Name: operator_session_limit_resolution_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_session_limit_resolution_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_session_limit_resolution_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_session_limit_resolution_transactions_id_seq OWNED BY public.operator_session_limit_resolution_transactions.id;


--
-- Name: operator_sign_in_flow_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_sign_in_flow_states (
    id bigint CONSTRAINT operator_sign_in_cycle_statuses_id_not_null NOT NULL
);


--
-- Name: operator_sign_in_flow_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_sign_in_flow_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_sign_in_flow_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_sign_in_flow_states_id_seq OWNED BY public.operator_sign_in_flow_states.id;


--
-- Name: operator_sign_in_flows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_sign_in_flows (
    id bigint CONSTRAINT org_sign_in_sequence_tickets_id_not_null NOT NULL,
    public_id character varying(21) CONSTRAINT org_sign_in_sequence_tickets_public_id_not_null NOT NULL,
    principal_id bigint,
    token_id bigint,
    return_to text,
    nonce_digest character varying CONSTRAINT org_sign_in_sequence_tickets_nonce_digest_not_null NOT NULL,
    issued_at timestamp(6) with time zone CONSTRAINT org_sign_in_sequence_tickets_issued_at_not_null NOT NULL,
    expires_at timestamp(6) with time zone CONSTRAINT org_sign_in_sequence_tickets_expires_at_not_null NOT NULL,
    completed_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT org_sign_in_sequence_tickets_discarded_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT org_sign_in_sequence_tickets_purged_at_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT org_sign_in_sequence_tickets_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT org_sign_in_sequence_tickets_updated_at_not_null NOT NULL,
    state_id bigint DEFAULT 10 CONSTRAINT org_sign_in_cycles_status_id_not_null NOT NULL,
    selected_region_id bigint,
    selected_persona_id bigint,
    selector_completed_at timestamp(6) with time zone,
    session_issued_at timestamp(6) with time zone,
    result_digest character varying(64),
    result_generation integer DEFAULT 0 NOT NULL,
    result_expires_at timestamp(6) with time zone,
    base_finalized_at timestamp(6) with time zone,
    authentication_method character varying,
    authentication_event_at timestamp(6) with time zone,
    authentication_context character varying,
    CONSTRAINT chk_operator_sign_in_flows_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_operator_sign_in_flows_state_completed_at CHECK (((state_id = 100) = (completed_at IS NOT NULL))),
    CONSTRAINT chk_org_sign_in_sequence_tickets_lifetime_order CHECK ((issued_at < expires_at)),
    CONSTRAINT chk_org_sign_in_sequence_tickets_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT operator_local_authentication_context_valid CHECK (((authentication_context IS NULL) OR ((authentication_context)::text = ANY ((ARRAY['normal'::character varying, 'standby'::character varying])::text[])))),
    CONSTRAINT operator_sign_in_flows_authentication_evidence_valid CHECK ((((authentication_method IS NULL) AND (authentication_event_at IS NULL)) OR (((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'totp'::character varying, 'google'::character varying, 'apple'::character varying, 'entra'::character varying])::text[])) AND (authentication_event_at IS NOT NULL) AND (principal_id IS NOT NULL)))),
    CONSTRAINT operator_sign_in_flows_base_finalization_valid CHECK (((base_finalized_at IS NULL) OR ((token_id IS NOT NULL) AND (result_digest IS NOT NULL)))),
    CONSTRAINT operator_sign_in_flows_evidence_complete CHECK (((authentication_event_at IS NULL) OR (authentication_method IS NOT NULL))),
    CONSTRAINT operator_sign_in_flows_result_complete CHECK (((result_generation = 0) OR ((result_digest IS NOT NULL) AND (result_expires_at IS NOT NULL) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT operator_sign_in_flows_result_delivery_valid CHECK ((((result_digest IS NULL) AND (result_expires_at IS NULL) AND (result_generation = 0)) OR ((length((result_digest)::text) = 64) AND (result_expires_at IS NOT NULL) AND (result_generation > 0) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT operator_sign_in_flows_result_generation_valid CHECK ((result_generation >= 0))
);


--
-- Name: operator_sign_in_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_sign_in_flows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_sign_in_flows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_sign_in_flows_id_seq OWNED BY public.operator_sign_in_flows.id;


--
-- Name: operator_sign_up_flow_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_sign_up_flow_statuses (
    id bigint CONSTRAINT operator_sign_up_cycle_statuses_id_not_null NOT NULL
);


--
-- Name: operator_sign_up_flow_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_sign_up_flow_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_sign_up_flow_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_sign_up_flow_statuses_id_seq OWNED BY public.operator_sign_up_flow_statuses.id;


--
-- Name: operator_sign_up_flows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_sign_up_flows (
    id bigint CONSTRAINT org_sign_up_sequence_tickets_id_not_null NOT NULL,
    public_id character varying(21) CONSTRAINT org_sign_up_sequence_tickets_public_id_not_null NOT NULL,
    principal_id bigint,
    token_id bigint,
    state character varying CONSTRAINT org_sign_up_sequence_tickets_state_not_null NOT NULL,
    step character varying CONSTRAINT org_sign_up_sequence_tickets_step_not_null NOT NULL,
    return_to text,
    nonce_digest character varying CONSTRAINT org_sign_up_sequence_tickets_nonce_digest_not_null NOT NULL,
    issued_at timestamp(6) with time zone CONSTRAINT org_sign_up_sequence_tickets_issued_at_not_null NOT NULL,
    expires_at timestamp(6) with time zone CONSTRAINT org_sign_up_sequence_tickets_expires_at_not_null NOT NULL,
    completed_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT org_sign_up_sequence_tickets_discarded_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT org_sign_up_sequence_tickets_purged_at_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT org_sign_up_sequence_tickets_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT org_sign_up_sequence_tickets_updated_at_not_null NOT NULL,
    status_id bigint DEFAULT 10 CONSTRAINT org_sign_up_cycles_status_id_not_null NOT NULL,
    result_digest character varying(64),
    result_generation integer DEFAULT 0 NOT NULL,
    result_expires_at timestamp(6) with time zone,
    base_finalized_at timestamp(6) with time zone,
    authentication_method character varying,
    authentication_event_at timestamp(6) with time zone,
    CONSTRAINT chk_operator_sign_up_flows_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_org_sign_up_sequence_tickets_lifetime_order CHECK ((issued_at < expires_at)),
    CONSTRAINT chk_org_sign_up_sequence_tickets_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT operator_sign_up_flows_authentication_evidence_valid CHECK ((((authentication_method IS NULL) AND (authentication_event_at IS NULL)) OR (((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'totp'::character varying, 'google'::character varying, 'apple'::character varying, 'entra'::character varying])::text[])) AND (authentication_event_at IS NOT NULL) AND (principal_id IS NOT NULL)))),
    CONSTRAINT operator_sign_up_flows_base_finalization_valid CHECK (((base_finalized_at IS NULL) OR ((token_id IS NOT NULL) AND (result_digest IS NOT NULL)))),
    CONSTRAINT operator_sign_up_flows_evidence_complete CHECK (((authentication_event_at IS NULL) OR (authentication_method IS NOT NULL))),
    CONSTRAINT operator_sign_up_flows_result_complete CHECK (((result_generation = 0) OR ((result_digest IS NOT NULL) AND (result_expires_at IS NOT NULL) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT operator_sign_up_flows_result_delivery_valid CHECK ((((result_digest IS NULL) AND (result_expires_at IS NULL) AND (result_generation = 0)) OR ((length((result_digest)::text) = 64) AND (result_expires_at IS NOT NULL) AND (result_generation > 0) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT operator_sign_up_flows_result_generation_valid CHECK ((result_generation >= 0))
);


--
-- Name: operator_sign_up_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_sign_up_flows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_sign_up_flows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_sign_up_flows_id_seq OWNED BY public.operator_sign_up_flows.id;


--
-- Name: operator_step_up_audit_outbox_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_step_up_audit_outbox_attempts (
    id bigint NOT NULL,
    outbox_id bigint NOT NULL,
    attempt_number integer NOT NULL,
    attempted_at timestamp(6) with time zone NOT NULL,
    outcome character varying(16) NOT NULL,
    failure_code character varying(64) NOT NULL,
    CONSTRAINT chk_operator_step_up_attempt_failure_codes CHECK (((failure_code)::text = ANY ((ARRAY['none'::character varying, 'chronicle_unavailable'::character varying, 'retention_policy_missing'::character varying, 'event_identity_conflict'::character varying, 'chronicle_record_invalid'::character varying, 'delivery_failed'::character varying])::text[]))),
    CONSTRAINT chk_operator_step_up_audit_attempt_failure CHECK ((length((failure_code)::text) > 0)),
    CONSTRAINT chk_operator_step_up_audit_attempt_number CHECK ((attempt_number > 0)),
    CONSTRAINT chk_operator_step_up_audit_attempt_outcome CHECK (((outcome)::text = ANY ((ARRAY['delivered'::character varying, 'failed'::character varying])::text[]))),
    CONSTRAINT chk_operator_step_up_delivered_failure_none CHECK ((((outcome)::text <> 'delivered'::text) OR ((failure_code)::text = 'none'::text)))
);


--
-- Name: operator_step_up_audit_outbox_attempts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_step_up_audit_outbox_attempts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_step_up_audit_outbox_attempts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_step_up_audit_outbox_attempts_id_seq OWNED BY public.operator_step_up_audit_outbox_attempts.id;


--
-- Name: operator_step_up_audit_outbox_delivery_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_step_up_audit_outbox_delivery_states (
    id bigint NOT NULL
);


--
-- Name: operator_step_up_audit_outbox_delivery_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_step_up_audit_outbox_delivery_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_step_up_audit_outbox_delivery_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_step_up_audit_outbox_delivery_states_id_seq OWNED BY public.operator_step_up_audit_outbox_delivery_states.id;


--
-- Name: operator_step_up_audit_outboxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_step_up_audit_outboxes (
    id bigint NOT NULL,
    event_uuid uuid NOT NULL,
    event_type character varying(64) NOT NULL,
    realm character varying(3) NOT NULL,
    client_id character varying NOT NULL,
    subject_ref character varying(255) NOT NULL,
    context_ref character varying(21) NOT NULL,
    reason_code character varying(64) NOT NULL,
    payload jsonb NOT NULL,
    occurred_at timestamp(6) with time zone NOT NULL,
    delivery_state_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_operator_step_up_audit_event CHECK (((event_type)::text = ANY ((ARRAY['step_up.requested'::character varying, 'step_up.committed'::character varying, 'step_up.installed'::character varying, 'step_up.cancelled'::character varying, 'step_up.expired'::character varying, 'step_up.failed'::character varying, 'step_up.refused'::character varying, 'step_up.indeterminate'::character varying, 'step_up.attempt_rejected'::character varying])::text[]))),
    CONSTRAINT chk_operator_step_up_audit_payload CHECK (((jsonb_typeof(payload) = 'object'::text) AND ((((event_type)::text = 'step_up.requested'::text) AND (payload ?& ARRAY['rp_state_ref'::text, 'return_target_kind'::text]) AND ((payload - ARRAY['rp_state_ref'::text, 'return_target_kind'::text]) = '{}'::jsonb)) OR (((event_type)::text = 'step_up.committed'::text) AND (payload ?& ARRAY['op_context_ref'::text, 'grant_ref'::text, 'verified_method'::text, 'auth_time'::text]) AND ((payload - ARRAY['op_context_ref'::text, 'grant_ref'::text, 'verified_method'::text, 'auth_time'::text]) = '{}'::jsonb)) OR (((event_type)::text = 'step_up.installed'::text) AND (payload ?& ARRAY['rp_state_ref'::text, 'grant_ref'::text, 'installed_generation'::text]) AND ((payload - ARRAY['rp_state_ref'::text, 'grant_ref'::text, 'installed_generation'::text]) = '{}'::jsonb)) OR (((event_type)::text = ANY ((ARRAY['step_up.cancelled'::character varying, 'step_up.expired'::character varying])::text[])) AND ((payload ? 'op_context_ref'::text) <> (payload ? 'rp_state_ref'::text)) AND ((payload - ARRAY['op_context_ref'::text, 'rp_state_ref'::text]) = '{}'::jsonb)) OR (((event_type)::text = 'step_up.failed'::text) AND (payload ?& ARRAY['op_context_ref'::text, 'failure_code'::text]) AND ((payload - ARRAY['op_context_ref'::text, 'failure_code'::text]) = '{}'::jsonb)) OR (((event_type)::text = ANY ((ARRAY['step_up.refused'::character varying, 'step_up.indeterminate'::character varying])::text[])) AND (payload ?& ARRAY['rp_state_ref'::text, 'failure_code'::text]) AND ((payload - ARRAY['rp_state_ref'::text, 'failure_code'::text]) = '{}'::jsonb)) OR (((event_type)::text = 'step_up.attempt_rejected'::text) AND (payload ?& ARRAY['context_ref'::text, 'rejection_code'::text]) AND ((payload - ARRAY['context_ref'::text, 'rejection_code'::text]) = '{}'::jsonb))))),
    CONSTRAINT chk_operator_step_up_audit_payload_codes CHECK (((((event_type)::text <> 'step_up.failed'::text) OR (COALESCE((payload ->> 'failure_code'::text), ''::text) = ANY (ARRAY['binding_mismatch'::text, 'expectation_mismatch'::text, 'policy_refused'::text, 'unsatisfiable_class'::text]))) AND (((event_type)::text <> ALL ((ARRAY['step_up.refused'::character varying, 'step_up.indeterminate'::character varying])::text[])) OR (COALESCE((payload ->> 'failure_code'::text), ''::text) = ANY (ARRAY['op_error'::text, 'generation_superseded'::text, 'session_invalid'::text, 'exchange_timeout'::text, 'dispatch_deadline_passed'::text]))) AND (((event_type)::text <> 'step_up.attempt_rejected'::text) OR (COALESCE((payload ->> 'rejection_code'::text), ''::text) = ANY (ARRAY['foreign_browser'::text, 'state_mismatch'::text, 'duplicate_callback'::text]))))),
    CONSTRAINT chk_operator_step_up_audit_realm CHECK (((realm)::text = 'ORG'::text)),
    CONSTRAINT chk_operator_step_up_audit_reason CHECK ((length((reason_code)::text) > 0)),
    CONSTRAINT chk_operator_step_up_audit_reason_codes CHECK (((reason_code)::text = ANY ((ARRAY['requested'::character varying, 'dispatch_started'::character varying, 'completed'::character varying, 'user_cancelled'::character varying, 'expired'::character varying, 'binding_mismatch'::character varying, 'expectation_mismatch'::character varying, 'policy_refused'::character varying, 'unsatisfiable_class'::character varying, 'op_error'::character varying, 'generation_superseded'::character varying, 'session_invalid'::character varying, 'exchange_timeout'::character varying, 'dispatch_deadline_passed'::character varying, 'foreign_browser'::character varying, 'state_mismatch'::character varying, 'duplicate_callback'::character varying])::text[])))
);


--
-- Name: operator_step_up_audit_outboxes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_step_up_audit_outboxes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_step_up_audit_outboxes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_step_up_audit_outboxes_id_seq OWNED BY public.operator_step_up_audit_outboxes.id;


--
-- Name: operator_step_up_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_step_up_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    required_scope character varying NOT NULL,
    required_aal character varying NOT NULL,
    allowed_methods text NOT NULL,
    resource_ref character varying,
    return_to character varying,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    method character varying,
    aal character varying,
    verified_at timestamp(6) with time zone,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    phishing_resistant_required boolean DEFAULT false CONSTRAINT operator_step_up_ceremony_t_phishing_resistant_require_not_null NOT NULL,
    phishing_resistant boolean DEFAULT false CONSTRAINT operator_step_up_ceremony_transacti_phishing_resistant_not_null NOT NULL,
    purpose character varying DEFAULT 'step_up'::character varying NOT NULL,
    result_digest character varying(64),
    result_generation integer DEFAULT 0 CONSTRAINT operator_step_up_ceremony_transactio_result_generation_not_null NOT NULL,
    result_expires_at timestamp(6) with time zone,
    canceled_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    verified_credential_ref character varying,
    step_up_required boolean DEFAULT true CONSTRAINT operator_step_up_ceremony_transaction_step_up_required_not_null NOT NULL,
    user_verification_required boolean DEFAULT false CONSTRAINT operator_step_up_ceremony_t_user_verification_required_not_null NOT NULL,
    full_reauthentication_required boolean DEFAULT false CONSTRAINT operator_step_up_ceremony_t_full_reauthentication_requ_not_null NOT NULL,
    audience character varying NOT NULL,
    token_binding character varying NOT NULL,
    require_session_binding boolean DEFAULT true CONSTRAINT operator_step_up_ceremony_tran_require_session_binding_not_null NOT NULL,
    tenant_ref character varying,
    user_verified boolean,
    cancellation_handoff_digest character varying(64),
    cancellation_handoff_ref uuid,
    cancellation_handoff_ciphertext text,
    CONSTRAINT operator_step_up_cancellation_handoff_pair CHECK ((((cancellation_handoff_ref IS NULL) AND (cancellation_handoff_ciphertext IS NULL)) OR ((cancellation_handoff_ref IS NOT NULL) AND (cancellation_handoff_ciphertext IS NOT NULL)))),
    CONSTRAINT operator_step_up_cancellation_handoff_valid CHECK (((cancellation_handoff_digest IS NULL) OR ((cancellation_handoff_digest)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT operator_step_up_purpose_valid CHECK (((purpose)::text = ANY ((ARRAY['step_up'::character varying, 'reauthentication'::character varying, 'bootstrap'::character varying, 'credential_registration'::character varying, 'credential_change'::character varying])::text[]))),
    CONSTRAINT operator_step_up_result_valid CHECK (((result_generation >= 0) AND (((result_digest IS NULL) AND (result_expires_at IS NULL) AND (result_generation = 0)) OR ((result_digest IS NOT NULL) AND ((result_digest)::text ~ '^[0-9a-f]{64}$'::text) AND (result_expires_at IS NOT NULL) AND (result_generation > 0) AND (verified_at IS NOT NULL))))),
    CONSTRAINT operator_step_up_status_valid CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'verified'::character varying, 'consumed'::character varying, 'canceled'::character varying, 'expired'::character varying, 'revoked'::character varying])::text[]))),
    CONSTRAINT operator_step_up_terminal_valid CHECK ((((canceled_at IS NULL) OR ((status)::text = 'canceled'::text)) AND ((revoked_at IS NULL) OR ((status)::text = 'revoked'::text)) AND (((status)::text <> 'revoked'::text) OR (revoked_at IS NOT NULL)) AND (((status)::text <> 'verified'::text) OR ((verified_at IS NOT NULL) AND (method IS NOT NULL) AND (aal IS NOT NULL))))),
    CONSTRAINT operator_step_up_verified_credential_present CHECK ((((status)::text <> 'verified'::text) OR (((purpose)::text = ANY ((ARRAY['bootstrap'::character varying, 'credential_registration'::character varying])::text[])) AND (verified_credential_ref IS NULL) AND ((aal)::text = 'none'::text) AND ((required_aal)::text = 'none'::text) AND (phishing_resistant IS FALSE) AND (phishing_resistant_required IS FALSE) AND ((method)::text = ANY ((ARRAY['passkey'::character varying, 'totp'::character varying])::text[]))) OR (((purpose)::text <> ALL ((ARRAY['bootstrap'::character varying, 'credential_registration'::character varying])::text[])) AND (verified_credential_ref IS NOT NULL) AND (length((verified_credential_ref)::text) > 0))))
);


--
-- Name: operator_step_up_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_step_up_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_step_up_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_step_up_ceremony_transactions_id_seq OWNED BY public.operator_step_up_ceremony_transactions.id;


--
-- Name: operator_step_up_commits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_step_up_commits (
    id bigint NOT NULL,
    grant_id bigint NOT NULL,
    root_token_id bigint NOT NULL,
    context_ref character varying(21) NOT NULL,
    verified_method character varying(16) NOT NULL,
    committed_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_operator_step_up_commits_method CHECK (((verified_method)::text = ANY ((ARRAY['passkey'::character varying, 'totp'::character varying, 'email_otp'::character varying])::text[])))
);


--
-- Name: operator_step_up_commits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_step_up_commits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_step_up_commits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_step_up_commits_id_seq OWNED BY public.operator_step_up_commits.id;


--
-- Name: operator_step_up_context_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_step_up_context_states (
    id bigint NOT NULL
);


--
-- Name: operator_step_up_context_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_step_up_context_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_step_up_context_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_step_up_context_states_id_seq OWNED BY public.operator_step_up_context_states.id;


--
-- Name: operator_step_up_context_transitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_step_up_context_transitions (
    id bigint NOT NULL,
    owner_id bigint NOT NULL,
    from_state_id bigint NOT NULL,
    to_state_id bigint NOT NULL,
    reason_code character varying(64) NOT NULL,
    occurred_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_operator_step_up_transition_reason CHECK (((reason_code)::text = ANY ((ARRAY['requested'::character varying, 'dispatch_started'::character varying, 'completed'::character varying, 'user_cancelled'::character varying, 'expired'::character varying, 'binding_mismatch'::character varying, 'expectation_mismatch'::character varying, 'policy_refused'::character varying, 'unsatisfiable_class'::character varying, 'op_error'::character varying, 'generation_superseded'::character varying, 'session_invalid'::character varying, 'exchange_timeout'::character varying, 'dispatch_deadline_passed'::character varying, 'foreign_browser'::character varying, 'state_mismatch'::character varying, 'duplicate_callback'::character varying])::text[])))
);


--
-- Name: operator_step_up_context_transitions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_step_up_context_transitions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_step_up_context_transitions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_step_up_context_transitions_id_seq OWNED BY public.operator_step_up_context_transitions.id;


--
-- Name: operator_step_up_contexts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_step_up_contexts (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    oidc_authorization_transaction_id bigint CONSTRAINT operator_step_up_contexts_oidc_authorization_transacti_not_null NOT NULL,
    grant_id bigint NOT NULL,
    bound_subject character varying(255) NOT NULL,
    requested_acr character varying(255) NOT NULL,
    state_id bigint NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_operator_step_up_contexts_acr CHECK (((requested_acr)::text = 'https://visa.umaxica.app/acr/reauthentication'::text))
);


--
-- Name: operator_step_up_contexts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_step_up_contexts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_step_up_contexts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_step_up_contexts_id_seq OWNED BY public.operator_step_up_contexts.id;


--
-- Name: operator_step_up_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_step_up_sessions (
    id bigint CONSTRAINT staff_reauth_sessions_id_not_null NOT NULL,
    attempt_count integer DEFAULT 0 CONSTRAINT staff_reauth_sessions_attempt_count_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT staff_reauth_sessions_created_at_not_null NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT staff_reauth_sessions_discarded_at_not_null NOT NULL,
    method character varying,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT staff_reauth_sessions_purged_at_not_null NOT NULL,
    return_to text CONSTRAINT staff_reauth_sessions_return_to_not_null NOT NULL,
    scope character varying CONSTRAINT staff_reauth_sessions_scope_not_null NOT NULL,
    staff_token_id bigint CONSTRAINT staff_reauth_sessions_staff_token_id_not_null NOT NULL,
    status character varying CONSTRAINT staff_reauth_sessions_status_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT staff_reauth_sessions_updated_at_not_null NOT NULL,
    verified_at timestamp(6) with time zone,
    step_up_ceremony_transaction_ref character varying,
    passkey_challenge text,
    passkey_challenge_ref character varying,
    passkey_rp_id character varying,
    passkey_origin character varying,
    passkey_challenge_expires_at timestamp(6) with time zone,
    passkey_challenge_consumed_at timestamp(6) with time zone,
    CONSTRAINT chk_operator_step_up_sessions_attempt_count CHECK ((attempt_count >= 0)),
    CONSTRAINT operator_step_up_challenge_bound CHECK (((passkey_challenge IS NULL) OR ((step_up_ceremony_transaction_ref IS NOT NULL) AND (passkey_challenge_ref IS NOT NULL) AND (passkey_rp_id IS NOT NULL) AND (passkey_origin IS NOT NULL) AND (passkey_challenge_expires_at IS NOT NULL) AND (passkey_challenge_expires_at <= discard_at))))
);


--
-- Name: operator_step_up_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_step_up_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_step_up_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_step_up_sessions_id_seq OWNED BY public.operator_step_up_sessions.id;


--
-- Name: operator_telephone_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_telephone_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying CONSTRAINT operator_telephone_ceremony_transaction_transaction_id_not_null NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    telephone_candidate_ref character varying,
    normalized_number_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    purpose character varying,
    otp_generation uuid,
    otp_verifier character varying,
    otp_expires_at timestamp(6) with time zone,
    otp_consumed_at timestamp(6) with time zone,
    otp_cancelled_at timestamp(6) with time zone,
    otp_receipt_verifier character varying,
    otp_result_expires_at timestamp(6) with time zone,
    CONSTRAINT operator_telephone_ceremony_transactions_otp_material CHECK (((otp_verifier IS NULL) OR ((purpose IS NOT NULL) AND (otp_generation IS NOT NULL) AND (otp_expires_at IS NOT NULL)))),
    CONSTRAINT operator_telephone_ceremony_transactions_otp_purpose CHECK (((purpose IS NULL) OR ((purpose)::text = ANY ((ARRAY['sign_up'::character varying, 'sign_in'::character varying, 'recovery'::character varying, 'withdrawal'::character varying, 'credential_registration'::character varying])::text[])))),
    CONSTRAINT operator_telephone_otp_proof_shape CHECK (((otp_generation IS NULL) OR (((purpose IS NOT NULL) AND ((actor_ref)::text <> ''::text) AND ((session_ref)::text <> ''::text) AND (telephone_candidate_ref IS NOT NULL) AND ((telephone_candidate_ref)::text <> ''::text) AND ((normalized_number_digest IS NULL) OR ((normalized_number_digest)::text ~ '^[0-9a-f]{64}$'::text)) AND (otp_expires_at IS NOT NULL) AND isfinite(otp_expires_at) AND isfinite(expires_at) AND (((otp_consumed_at IS NULL) AND (otp_cancelled_at IS NULL) AND (otp_verifier IS NOT NULL) AND ((otp_verifier)::text ~ '^[0-9a-f]{64}$'::text) AND (otp_receipt_verifier IS NULL) AND (otp_result_expires_at IS NULL)) OR ((otp_consumed_at IS NOT NULL) AND isfinite(otp_consumed_at) AND (otp_consumed_at < otp_expires_at) AND (otp_cancelled_at IS NULL) AND (otp_verifier IS NULL) AND (otp_receipt_verifier IS NOT NULL) AND (otp_result_expires_at IS NOT NULL)) OR ((otp_cancelled_at IS NOT NULL) AND isfinite(otp_cancelled_at) AND (otp_consumed_at IS NULL) AND (otp_verifier IS NULL) AND (otp_receipt_verifier IS NULL) AND (otp_result_expires_at IS NULL)))) IS TRUE))),
    CONSTRAINT operator_telephone_otp_receipt_bounds CHECK ((((otp_receipt_verifier IS NULL) AND (otp_result_expires_at IS NULL)) OR ((otp_receipt_verifier IS NOT NULL) AND ((otp_receipt_verifier)::text ~ '^[0-9a-f]{64}$'::text) AND (otp_consumed_at IS NOT NULL) AND (otp_cancelled_at IS NULL) AND (otp_verifier IS NULL) AND (otp_result_expires_at IS NOT NULL) AND isfinite(otp_result_expires_at) AND (otp_result_expires_at > otp_consumed_at) AND (otp_result_expires_at <= (otp_consumed_at + '00:01:00'::interval)) AND (otp_result_expires_at <= expires_at))))
);


--
-- Name: operator_telephone_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_telephone_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_telephone_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_telephone_ceremony_transactions_id_seq OWNED BY public.operator_telephone_ceremony_transactions.id;


--
-- Name: operator_token_binding_methods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_token_binding_methods (
    id bigint CONSTRAINT staff_token_binding_methods_id_not_null NOT NULL
);


--
-- Name: operator_token_binding_methods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_token_binding_methods_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_token_binding_methods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_token_binding_methods_id_seq OWNED BY public.operator_token_binding_methods.id;


--
-- Name: operator_token_dbsc_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_token_dbsc_statuses (
    id bigint CONSTRAINT staff_token_dbsc_statuses_id_not_null NOT NULL
);


--
-- Name: operator_token_dbsc_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_token_dbsc_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_token_dbsc_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_token_dbsc_statuses_id_seq OWNED BY public.operator_token_dbsc_statuses.id;


--
-- Name: operator_token_kinds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_token_kinds (
    id bigint CONSTRAINT staff_token_kinds_id_not_null NOT NULL
);


--
-- Name: operator_token_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_token_kinds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_token_kinds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_token_kinds_id_seq OWNED BY public.operator_token_kinds.id;


--
-- Name: operator_token_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_token_statuses (
    id bigint CONSTRAINT staff_token_statuses_id_not_null NOT NULL
);


--
-- Name: operator_token_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_token_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_token_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_token_statuses_id_seq OWNED BY public.operator_token_statuses.id;


--
-- Name: operator_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_tokens (
    id bigint CONSTRAINT staff_tokens_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT staff_tokens_created_at_not_null NOT NULL,
    dbsc_challenge text,
    dbsc_challenge_issued_at timestamp(6) with time zone,
    dbsc_public_key jsonb,
    dbsc_session_id character varying,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT staff_tokens_deletable_at_not_null NOT NULL,
    last_step_up_at timestamp(6) with time zone,
    last_step_up_scope character varying,
    last_used_at timestamp(6) with time zone,
    public_id character varying(21) DEFAULT ''::character varying CONSTRAINT staff_tokens_public_id_not_null NOT NULL,
    refresh_token_digest bytea,
    refresh_token_family_id character varying,
    refresh_token_generation integer DEFAULT 0 CONSTRAINT staff_tokens_refresh_token_generation_not_null NOT NULL,
    rotated_at timestamp(6) with time zone,
    staff_id bigint CONSTRAINT staff_tokens_staff_id_not_null NOT NULL,
    staff_token_binding_method_id bigint DEFAULT 0 CONSTRAINT staff_tokens_staff_token_binding_method_id_not_null NOT NULL,
    staff_token_dbsc_status_id bigint DEFAULT 0 CONSTRAINT staff_tokens_staff_token_dbsc_status_id_not_null NOT NULL,
    staff_token_kind_id bigint DEFAULT 0 CONSTRAINT staff_tokens_staff_token_kind_id_not_null NOT NULL,
    staff_token_status_id bigint DEFAULT 1 CONSTRAINT staff_tokens_staff_token_status_id_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT staff_tokens_updated_at_not_null NOT NULL,
    dpop_jkt character varying,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT staff_tokens_discarded_at_not_null NOT NULL,
    oidc_connection_id bigint,
    oidc_client_id character varying(64),
    oidc_scope character varying,
    oidc_sid uuid DEFAULT gen_random_uuid(),
    oidc_jti uuid DEFAULT gen_random_uuid(),
    device_session_id bigint NOT NULL,
    last_step_up_aal character varying,
    last_step_up_method character varying,
    last_step_up_purpose character varying,
    last_step_up_audience character varying,
    last_step_up_session_public_id character varying,
    selected_account_public_id character varying,
    selected_collective_public_id character varying,
    selected_collective_unit_public_id character varying,
    selected_at timestamp(6) with time zone,
    established_authentication_method character varying,
    last_step_up_phishing_resistant boolean DEFAULT false NOT NULL,
    authentication_context character varying,
    authentication_event_at timestamp(6) with time zone,
    selected_avatar_public_id character varying,
    root_login_established_at timestamp with time zone,
    last_step_up_user_verified boolean,
    last_step_up_credential_ref character varying,
    last_step_up_full_reauthentication boolean,
    last_step_up_resource_ref character varying,
    last_step_up_tenant_ref character varying,
    authentication_epoch bigint NOT NULL,
    CONSTRAINT chk_operator_tokens_authentication_context CHECK (((authentication_context IS NULL) OR ((authentication_context)::text = ANY ((ARRAY['normal'::character varying, 'standby'::character varying])::text[])))),
    CONSTRAINT chk_operator_tokens_authentication_epoch CHECK ((authentication_epoch >= 0)),
    CONSTRAINT chk_operator_tokens_established_authentication_method CHECK (((established_authentication_method IS NULL) OR ((established_authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'entra'::character varying])::text[])))),
    CONSTRAINT chk_operator_tokens_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_staff_tokens_kind_id_positive CHECK ((staff_token_kind_id >= 0)),
    CONSTRAINT chk_staff_tokens_status_id_positive CHECK ((staff_token_status_id >= 0))
);


--
-- Name: operator_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_tokens_id_seq OWNED BY public.operator_tokens.id;


--
-- Name: operator_verifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_verifications (
    id bigint CONSTRAINT staff_verifications_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT staff_verifications_created_at_not_null NOT NULL,
    last_used_at timestamp(6) with time zone,
    staff_token_id bigint CONSTRAINT staff_verifications_staff_token_id_not_null NOT NULL,
    token_digest character varying CONSTRAINT staff_verifications_token_digest_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT staff_verifications_updated_at_not_null NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT staff_verifications_discarded_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT staff_verifications_purged_at_not_null NOT NULL,
    CONSTRAINT chk_staff_verifications_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: operator_verifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_verifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_verifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_verifications_id_seq OWNED BY public.operator_verifications.id;


--
-- Name: operator_visa_sensitive_admissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_visa_sensitive_admissions (
    id bigint NOT NULL,
    public_ref character varying(21) NOT NULL,
    oidc_authorization_transaction_id bigint CONSTRAINT operator_visa_sensitive_adm_oidc_authorization_transac_not_null NOT NULL,
    step_up_ceremony_transaction_id bigint CONSTRAINT operator_visa_sensitive_adm_step_up_ceremony_transacti_not_null NOT NULL,
    auth_admission_binding_id bigint CONSTRAINT operator_visa_sensitive_admi_auth_admission_binding_id_not_null NOT NULL,
    realm character varying(3) NOT NULL,
    client_id character varying(64) NOT NULL,
    actor_subject character varying(255) NOT NULL,
    grant_sid character varying(64) NOT NULL,
    rp_session_ref character varying(64) NOT NULL,
    rp_session_expires_at timestamp with time zone CONSTRAINT operator_visa_sensitive_admissio_rp_session_expires_at_not_null NOT NULL,
    browser_binding_digest character varying(64) CONSTRAINT operator_visa_sensitive_admissi_browser_binding_digest_not_null NOT NULL,
    purpose character varying(32) NOT NULL,
    provider character varying(16) NOT NULL,
    event_jti character varying(255) NOT NULL,
    event_auth_time bigint NOT NULL,
    event_acr character varying(64) NOT NULL,
    event_amr jsonb NOT NULL,
    status character varying(24) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT operator_visa_admission_purpose CHECK ((((purpose)::text = 'passkey_registration'::text) AND ((provider)::text = 'none'::text))),
    CONSTRAINT operator_visa_admission_realm CHECK ((((realm)::text = 'org'::text) AND ((client_id)::text = 'base-org-ww'::text))),
    CONSTRAINT operator_visa_admission_status CHECK (((status)::text = ANY ((ARRAY['issued'::character varying, 'browser_confirmed'::character varying, 'source_committed'::character varying, 'refused'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT operator_visa_admission_values CHECK ((((public_ref)::text ~ '^[A-Za-z0-9_-]{21}$'::text) AND (event_auth_time > 0) AND ((event_acr)::text <> ''::text) AND ((browser_binding_digest)::text ~ '^[0-9a-f]{64}$'::text) AND (jsonb_typeof(event_amr) = 'array'::text) AND (jsonb_array_length(event_amr) > 0) AND (expires_at > created_at) AND (expires_at <= rp_session_expires_at)))
);


--
-- Name: operator_visa_sensitive_admissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_visa_sensitive_admissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_visa_sensitive_admissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_visa_sensitive_admissions_id_seq OWNED BY public.operator_visa_sensitive_admissions.id;


--
-- Name: organization_invitations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organization_invitations (
    id bigint NOT NULL,
    code character varying(32) NOT NULL,
    consumed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    email character varying NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    invited_by_id bigint NOT NULL,
    organization_id bigint NOT NULL,
    role_id bigint DEFAULT 0 NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: organization_invitations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organization_invitations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organization_invitations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organization_invitations_id_seq OWNED BY public.organization_invitations.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: staff_verifications_staff_token_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.staff_verifications_staff_token_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_verifications_staff_token_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_verifications_staff_token_id_seq OWNED BY public.operator_verifications.staff_token_id;


--
-- Name: op_consumed_jtis id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_consumed_jtis ALTER COLUMN id SET DEFAULT nextval('public.op_consumed_jtis_id_seq'::regclass);


--
-- Name: op_inbound_event_receipts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_inbound_event_receipts ALTER COLUMN id SET DEFAULT nextval('public.op_inbound_event_receipts_id_seq'::regclass);


--
-- Name: op_org_authority_stop_causes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_causes ALTER COLUMN id SET DEFAULT nextval('public.op_org_authority_stop_causes_id_seq'::regclass);


--
-- Name: op_org_authority_stop_epoch_cutoffs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_epoch_cutoffs ALTER COLUMN id SET DEFAULT nextval('public.op_org_authority_stop_epoch_cutoffs_id_seq'::regclass);


--
-- Name: op_org_authority_stop_grant_targets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_grant_targets ALTER COLUMN id SET DEFAULT nextval('public.op_org_authority_stop_grant_targets_id_seq'::regclass);


--
-- Name: op_org_authority_stop_participant_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_participant_statuses ALTER COLUMN id SET DEFAULT nextval('public.op_org_authority_stop_participant_statuses_id_seq'::regclass);


--
-- Name: op_org_authority_stop_participants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_participants ALTER COLUMN id SET DEFAULT nextval('public.op_org_authority_stop_participants_id_seq'::regclass);


--
-- Name: op_org_authority_stop_root_targets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_root_targets ALTER COLUMN id SET DEFAULT nextval('public.op_org_authority_stop_root_targets_id_seq'::regclass);


--
-- Name: op_org_authority_stop_scopes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_scopes ALTER COLUMN id SET DEFAULT nextval('public.op_org_authority_stop_scopes_id_seq'::regclass);


--
-- Name: op_org_authority_stops id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stops ALTER COLUMN id SET DEFAULT nextval('public.op_org_authority_stops_id_seq'::regclass);


--
-- Name: op_org_grant_logout_hints id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_grant_logout_hints ALTER COLUMN id SET DEFAULT nextval('public.op_org_grant_logout_hints_id_seq'::regclass);


--
-- Name: op_org_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_grants ALTER COLUMN id SET DEFAULT nextval('public.op_org_grants_id_seq'::regclass);


--
-- Name: operator_auth_admission_binding_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_admission_binding_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_auth_admission_binding_statuses_id_seq'::regclass);


--
-- Name: operator_auth_admission_bindings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_admission_bindings ALTER COLUMN id SET DEFAULT nextval('public.operator_auth_admission_bindings_id_seq'::regclass);


--
-- Name: operator_auth_ceremony_session_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_ceremony_session_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_auth_ceremony_session_statuses_id_seq'::regclass);


--
-- Name: operator_auth_ceremony_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_ceremony_sessions ALTER COLUMN id SET DEFAULT nextval('public.operator_auth_ceremony_sessions_id_seq'::regclass);


--
-- Name: operator_device_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_device_sessions ALTER COLUMN id SET DEFAULT nextval('public.operator_device_sessions_id_seq'::regclass);


--
-- Name: operator_dpop_proof_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_dpop_proof_states ALTER COLUMN id SET DEFAULT nextval('public.operator_dpop_proof_states_id_seq'::regclass);


--
-- Name: operator_email_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_email_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.operator_email_ceremony_transactions_id_seq'::regclass);


--
-- Name: operator_oauth_callback_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_oauth_callback_states ALTER COLUMN id SET DEFAULT nextval('public.operator_oauth_callback_states_id_seq'::regclass);


--
-- Name: operator_oidc_authorization_transaction_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_oidc_authorization_transaction_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_oidc_authorization_transaction_statuses_id_seq'::regclass);


--
-- Name: operator_oidc_authorization_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_oidc_authorization_transactions ALTER COLUMN id SET DEFAULT nextval('public.operator_oidc_authorization_transactions_id_seq'::regclass);


--
-- Name: operator_oidc_connections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_oidc_connections ALTER COLUMN id SET DEFAULT nextval('public.operator_oidc_connections_id_seq'::regclass);


--
-- Name: operator_passkey_ceremony_candidates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkey_ceremony_candidates ALTER COLUMN id SET DEFAULT nextval('public.operator_passkey_ceremony_candidates_id_seq'::regclass);


--
-- Name: operator_passkey_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkey_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.operator_passkey_ceremony_transactions_id_seq'::regclass);


--
-- Name: operator_secret_credential_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secret_credential_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.operator_secret_credential_ceremony_transactions_id_seq'::regclass);


--
-- Name: operator_sensitive_admission_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sensitive_admission_attachments ALTER COLUMN id SET DEFAULT nextval('public.operator_sensitive_admission_attachments_id_seq'::regclass);


--
-- Name: operator_sensitive_admission_audit_attempts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sensitive_admission_audit_attempts ALTER COLUMN id SET DEFAULT nextval('public.operator_sensitive_admission_audit_attempts_id_seq'::regclass);


--
-- Name: operator_sensitive_admission_audit_outboxes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sensitive_admission_audit_outboxes ALTER COLUMN id SET DEFAULT nextval('public.operator_sensitive_admission_audit_outboxes_id_seq'::regclass);


--
-- Name: operator_sensitive_admission_confirmations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sensitive_admission_confirmations ALTER COLUMN id SET DEFAULT nextval('public.operator_sensitive_admission_confirmations_id_seq'::regclass);


--
-- Name: operator_sensitive_admission_redemptions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sensitive_admission_redemptions ALTER COLUMN id SET DEFAULT nextval('public.operator_sensitive_admission_redemptions_id_seq'::regclass);


--
-- Name: operator_sensitive_admission_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sensitive_admission_sessions ALTER COLUMN id SET DEFAULT nextval('public.operator_sensitive_admission_sessions_id_seq'::regclass);


--
-- Name: operator_sensitive_admissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sensitive_admissions ALTER COLUMN id SET DEFAULT nextval('public.operator_sensitive_admissions_id_seq'::regclass);


--
-- Name: operator_session_limit_resolution_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_session_limit_resolution_states ALTER COLUMN id SET DEFAULT nextval('public.operator_session_limit_resolution_states_id_seq'::regclass);


--
-- Name: operator_session_limit_resolution_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_session_limit_resolution_transactions ALTER COLUMN id SET DEFAULT nextval('public.operator_session_limit_resolution_transactions_id_seq'::regclass);


--
-- Name: operator_sign_in_flow_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_in_flow_states ALTER COLUMN id SET DEFAULT nextval('public.operator_sign_in_flow_states_id_seq'::regclass);


--
-- Name: operator_sign_in_flows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_in_flows ALTER COLUMN id SET DEFAULT nextval('public.operator_sign_in_flows_id_seq'::regclass);


--
-- Name: operator_sign_up_flow_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_up_flow_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_sign_up_flow_statuses_id_seq'::regclass);


--
-- Name: operator_sign_up_flows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_up_flows ALTER COLUMN id SET DEFAULT nextval('public.operator_sign_up_flows_id_seq'::regclass);


--
-- Name: operator_step_up_audit_outbox_attempts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_audit_outbox_attempts ALTER COLUMN id SET DEFAULT nextval('public.operator_step_up_audit_outbox_attempts_id_seq'::regclass);


--
-- Name: operator_step_up_audit_outbox_delivery_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_audit_outbox_delivery_states ALTER COLUMN id SET DEFAULT nextval('public.operator_step_up_audit_outbox_delivery_states_id_seq'::regclass);


--
-- Name: operator_step_up_audit_outboxes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_audit_outboxes ALTER COLUMN id SET DEFAULT nextval('public.operator_step_up_audit_outboxes_id_seq'::regclass);


--
-- Name: operator_step_up_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.operator_step_up_ceremony_transactions_id_seq'::regclass);


--
-- Name: operator_step_up_commits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_commits ALTER COLUMN id SET DEFAULT nextval('public.operator_step_up_commits_id_seq'::regclass);


--
-- Name: operator_step_up_context_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_context_states ALTER COLUMN id SET DEFAULT nextval('public.operator_step_up_context_states_id_seq'::regclass);


--
-- Name: operator_step_up_context_transitions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_context_transitions ALTER COLUMN id SET DEFAULT nextval('public.operator_step_up_context_transitions_id_seq'::regclass);


--
-- Name: operator_step_up_contexts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_contexts ALTER COLUMN id SET DEFAULT nextval('public.operator_step_up_contexts_id_seq'::regclass);


--
-- Name: operator_step_up_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_sessions ALTER COLUMN id SET DEFAULT nextval('public.operator_step_up_sessions_id_seq'::regclass);


--
-- Name: operator_telephone_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_telephone_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.operator_telephone_ceremony_transactions_id_seq'::regclass);


--
-- Name: operator_token_binding_methods id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_token_binding_methods ALTER COLUMN id SET DEFAULT nextval('public.operator_token_binding_methods_id_seq'::regclass);


--
-- Name: operator_token_dbsc_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_token_dbsc_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_token_dbsc_statuses_id_seq'::regclass);


--
-- Name: operator_token_kinds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_token_kinds ALTER COLUMN id SET DEFAULT nextval('public.operator_token_kinds_id_seq'::regclass);


--
-- Name: operator_token_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_token_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_token_statuses_id_seq'::regclass);


--
-- Name: operator_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_tokens ALTER COLUMN id SET DEFAULT nextval('public.operator_tokens_id_seq'::regclass);


--
-- Name: operator_verifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_verifications ALTER COLUMN id SET DEFAULT nextval('public.operator_verifications_id_seq'::regclass);


--
-- Name: operator_visa_sensitive_admissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_visa_sensitive_admissions ALTER COLUMN id SET DEFAULT nextval('public.operator_visa_sensitive_admissions_id_seq'::regclass);


--
-- Name: organization_invitations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_invitations ALTER COLUMN id SET DEFAULT nextval('public.organization_invitations_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: operator_email_ceremony_transactions chk_operator_email_ceremony_evp_attempt_count; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.operator_email_ceremony_transactions
    ADD CONSTRAINT chk_operator_email_ceremony_evp_attempt_count CHECK ((evp_attempt_count >= 0)) NOT VALID;


--
-- Name: operator_step_up_sessions chk_staff_step_up_sessions_retention_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.operator_step_up_sessions
    ADD CONSTRAINT chk_staff_step_up_sessions_retention_order CHECK ((discard_at <= purge_eligible_at)) NOT VALID;


--
-- Name: op_consumed_jtis op_consumed_jtis_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_consumed_jtis
    ADD CONSTRAINT op_consumed_jtis_pkey PRIMARY KEY (id);


--
-- Name: op_inbound_event_receipts op_inbound_event_receipts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_inbound_event_receipts
    ADD CONSTRAINT op_inbound_event_receipts_pkey PRIMARY KEY (id);


--
-- Name: op_org_authority_stop_causes op_org_authority_stop_causes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_causes
    ADD CONSTRAINT op_org_authority_stop_causes_pkey PRIMARY KEY (id);


--
-- Name: op_org_authority_stop_epoch_cutoffs op_org_authority_stop_epoch_cutoffs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_epoch_cutoffs
    ADD CONSTRAINT op_org_authority_stop_epoch_cutoffs_pkey PRIMARY KEY (id);


--
-- Name: op_org_authority_stop_grant_targets op_org_authority_stop_grant_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_grant_targets
    ADD CONSTRAINT op_org_authority_stop_grant_targets_pkey PRIMARY KEY (id);


--
-- Name: op_org_authority_stop_participant_statuses op_org_authority_stop_participant_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_participant_statuses
    ADD CONSTRAINT op_org_authority_stop_participant_statuses_pkey PRIMARY KEY (id);


--
-- Name: op_org_authority_stop_participants op_org_authority_stop_participants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_participants
    ADD CONSTRAINT op_org_authority_stop_participants_pkey PRIMARY KEY (id);


--
-- Name: op_org_authority_stop_root_targets op_org_authority_stop_root_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_root_targets
    ADD CONSTRAINT op_org_authority_stop_root_targets_pkey PRIMARY KEY (id);


--
-- Name: op_org_authority_stop_scopes op_org_authority_stop_scopes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_scopes
    ADD CONSTRAINT op_org_authority_stop_scopes_pkey PRIMARY KEY (id);


--
-- Name: op_org_authority_stops op_org_authority_stops_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stops
    ADD CONSTRAINT op_org_authority_stops_pkey PRIMARY KEY (id);


--
-- Name: op_org_grant_logout_hints op_org_grant_logout_hints_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_grant_logout_hints
    ADD CONSTRAINT op_org_grant_logout_hints_pkey PRIMARY KEY (id);


--
-- Name: op_org_grants op_org_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_grants
    ADD CONSTRAINT op_org_grants_pkey PRIMARY KEY (id);


--
-- Name: operator_auth_admission_binding_statuses operator_auth_admission_binding_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_admission_binding_statuses
    ADD CONSTRAINT operator_auth_admission_binding_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_auth_admission_bindings operator_auth_admission_bindings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_admission_bindings
    ADD CONSTRAINT operator_auth_admission_bindings_pkey PRIMARY KEY (id);


--
-- Name: operator_auth_ceremony_session_statuses operator_auth_ceremony_session_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_ceremony_session_statuses
    ADD CONSTRAINT operator_auth_ceremony_session_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_auth_ceremony_sessions operator_auth_ceremony_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_ceremony_sessions
    ADD CONSTRAINT operator_auth_ceremony_sessions_pkey PRIMARY KEY (id);


--
-- Name: operator_device_sessions operator_device_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_device_sessions
    ADD CONSTRAINT operator_device_sessions_pkey PRIMARY KEY (id);


--
-- Name: operator_dpop_proof_states operator_dpop_proof_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_dpop_proof_states
    ADD CONSTRAINT operator_dpop_proof_states_pkey PRIMARY KEY (id);


--
-- Name: operator_email_ceremony_transactions operator_email_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_email_ceremony_transactions
    ADD CONSTRAINT operator_email_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: operator_oauth_callback_states operator_oauth_callback_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_oauth_callback_states
    ADD CONSTRAINT operator_oauth_callback_states_pkey PRIMARY KEY (id);


--
-- Name: operator_oidc_authorization_transaction_statuses operator_oidc_authorization_transaction_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_oidc_authorization_transaction_statuses
    ADD CONSTRAINT operator_oidc_authorization_transaction_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_oidc_authorization_transactions operator_oidc_authorization_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_oidc_authorization_transactions
    ADD CONSTRAINT operator_oidc_authorization_transactions_pkey PRIMARY KEY (id);


--
-- Name: operator_oidc_connections operator_oidc_connections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_oidc_connections
    ADD CONSTRAINT operator_oidc_connections_pkey PRIMARY KEY (id);


--
-- Name: operator_passkey_ceremony_candidates operator_passkey_ceremony_candidates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkey_ceremony_candidates
    ADD CONSTRAINT operator_passkey_ceremony_candidates_pkey PRIMARY KEY (id);


--
-- Name: operator_passkey_ceremony_transactions operator_passkey_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkey_ceremony_transactions
    ADD CONSTRAINT operator_passkey_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: operator_secret_credential_ceremony_transactions operator_secret_credential_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secret_credential_ceremony_transactions
    ADD CONSTRAINT operator_secret_credential_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: operator_sensitive_admission_attachments operator_sensitive_admission_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sensitive_admission_attachments
    ADD CONSTRAINT operator_sensitive_admission_attachments_pkey PRIMARY KEY (id);


--
-- Name: operator_sensitive_admission_audit_attempts operator_sensitive_admission_audit_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sensitive_admission_audit_attempts
    ADD CONSTRAINT operator_sensitive_admission_audit_attempts_pkey PRIMARY KEY (id);


--
-- Name: operator_sensitive_admission_audit_outboxes operator_sensitive_admission_audit_outboxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sensitive_admission_audit_outboxes
    ADD CONSTRAINT operator_sensitive_admission_audit_outboxes_pkey PRIMARY KEY (id);


--
-- Name: operator_sensitive_admission_confirmations operator_sensitive_admission_confirmations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sensitive_admission_confirmations
    ADD CONSTRAINT operator_sensitive_admission_confirmations_pkey PRIMARY KEY (id);


--
-- Name: operator_sensitive_admission_redemptions operator_sensitive_admission_redemptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sensitive_admission_redemptions
    ADD CONSTRAINT operator_sensitive_admission_redemptions_pkey PRIMARY KEY (id);


--
-- Name: operator_sensitive_admission_sessions operator_sensitive_admission_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sensitive_admission_sessions
    ADD CONSTRAINT operator_sensitive_admission_sessions_pkey PRIMARY KEY (id);


--
-- Name: operator_sensitive_admissions operator_sensitive_admissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sensitive_admissions
    ADD CONSTRAINT operator_sensitive_admissions_pkey PRIMARY KEY (id);


--
-- Name: operator_session_limit_resolution_states operator_session_limit_resolution_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_session_limit_resolution_states
    ADD CONSTRAINT operator_session_limit_resolution_states_pkey PRIMARY KEY (id);


--
-- Name: operator_session_limit_resolution_transactions operator_session_limit_resolution_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_session_limit_resolution_transactions
    ADD CONSTRAINT operator_session_limit_resolution_transactions_pkey PRIMARY KEY (id);


--
-- Name: operator_sign_in_flow_states operator_sign_in_flow_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_in_flow_states
    ADD CONSTRAINT operator_sign_in_flow_states_pkey PRIMARY KEY (id);


--
-- Name: operator_sign_in_flows operator_sign_in_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_in_flows
    ADD CONSTRAINT operator_sign_in_flows_pkey PRIMARY KEY (id);


--
-- Name: operator_sign_up_flow_statuses operator_sign_up_flow_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_up_flow_statuses
    ADD CONSTRAINT operator_sign_up_flow_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_sign_up_flows operator_sign_up_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_up_flows
    ADD CONSTRAINT operator_sign_up_flows_pkey PRIMARY KEY (id);


--
-- Name: operator_step_up_audit_outbox_attempts operator_step_up_audit_outbox_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_audit_outbox_attempts
    ADD CONSTRAINT operator_step_up_audit_outbox_attempts_pkey PRIMARY KEY (id);


--
-- Name: operator_step_up_audit_outbox_delivery_states operator_step_up_audit_outbox_delivery_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_audit_outbox_delivery_states
    ADD CONSTRAINT operator_step_up_audit_outbox_delivery_states_pkey PRIMARY KEY (id);


--
-- Name: operator_step_up_audit_outboxes operator_step_up_audit_outboxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_audit_outboxes
    ADD CONSTRAINT operator_step_up_audit_outboxes_pkey PRIMARY KEY (id);


--
-- Name: operator_step_up_ceremony_transactions operator_step_up_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_ceremony_transactions
    ADD CONSTRAINT operator_step_up_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: operator_step_up_commits operator_step_up_commits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_commits
    ADD CONSTRAINT operator_step_up_commits_pkey PRIMARY KEY (id);


--
-- Name: operator_step_up_context_states operator_step_up_context_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_context_states
    ADD CONSTRAINT operator_step_up_context_states_pkey PRIMARY KEY (id);


--
-- Name: operator_step_up_context_transitions operator_step_up_context_transitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_context_transitions
    ADD CONSTRAINT operator_step_up_context_transitions_pkey PRIMARY KEY (id);


--
-- Name: operator_step_up_contexts operator_step_up_contexts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_contexts
    ADD CONSTRAINT operator_step_up_contexts_pkey PRIMARY KEY (id);


--
-- Name: operator_step_up_sessions operator_step_up_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_sessions
    ADD CONSTRAINT operator_step_up_sessions_pkey PRIMARY KEY (id);


--
-- Name: operator_telephone_ceremony_transactions operator_telephone_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_telephone_ceremony_transactions
    ADD CONSTRAINT operator_telephone_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: operator_token_binding_methods operator_token_binding_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_token_binding_methods
    ADD CONSTRAINT operator_token_binding_methods_pkey PRIMARY KEY (id);


--
-- Name: operator_token_dbsc_statuses operator_token_dbsc_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_token_dbsc_statuses
    ADD CONSTRAINT operator_token_dbsc_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_token_kinds operator_token_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_token_kinds
    ADD CONSTRAINT operator_token_kinds_pkey PRIMARY KEY (id);


--
-- Name: operator_token_statuses operator_token_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_token_statuses
    ADD CONSTRAINT operator_token_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_tokens operator_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT operator_tokens_pkey PRIMARY KEY (id);


--
-- Name: operator_verifications operator_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_verifications
    ADD CONSTRAINT operator_verifications_pkey PRIMARY KEY (id);


--
-- Name: operator_visa_sensitive_admissions operator_visa_sensitive_admissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_visa_sensitive_admissions
    ADD CONSTRAINT operator_visa_sensitive_admissions_pkey PRIMARY KEY (id);


--
-- Name: organization_invitations organization_invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_invitations
    ADD CONSTRAINT organization_invitations_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: idx_active_op_org_grant_per_device_session; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_active_op_org_grant_per_device_session ON public.op_org_grants USING btree (device_session_id, oidc_client_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_on_actor_ref_session_ref_091a0506ae; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_091a0506ae ON public.operator_telephone_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_2ccab820e8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_2ccab820e8 ON public.operator_email_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_95b7cba3f2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_95b7cba3f2 ON public.operator_passkey_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_9b37b22018; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_9b37b22018 ON public.operator_step_up_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_dce233ec55; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_dce233ec55 ON public.operator_secret_credential_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_cancellation_handoff_digest_073bb4822f; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_cancellation_handoff_digest_073bb4822f ON public.operator_oidc_authorization_transactions USING btree (cancellation_handoff_digest);


--
-- Name: idx_on_cancellation_handoff_digest_dc759b9c45; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_cancellation_handoff_digest_dc759b9c45 ON public.operator_step_up_ceremony_transactions USING btree (cancellation_handoff_digest);


--
-- Name: idx_on_cancellation_handoff_ref_92180f8825; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_cancellation_handoff_ref_92180f8825 ON public.operator_step_up_ceremony_transactions USING btree (cancellation_handoff_ref);


--
-- Name: idx_on_cancellation_handoff_ref_c6e82074fb; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_cancellation_handoff_ref_c6e82074fb ON public.operator_oidc_authorization_transactions USING btree (cancellation_handoff_ref);


--
-- Name: idx_on_challenge_digest_fae4113ba2; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_challenge_digest_fae4113ba2 ON public.operator_session_limit_resolution_transactions USING btree (challenge_digest);


--
-- Name: idx_on_client_id_login_challenge_bf0bf3ad3f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_client_id_login_challenge_bf0bf3ad3f ON public.operator_oidc_authorization_transactions USING btree (client_id, login_challenge);


--
-- Name: idx_on_expires_at_feac3d8c3e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_expires_at_feac3d8c3e ON public.operator_secret_credential_ceremony_transactions USING btree (expires_at);


--
-- Name: idx_on_grant_jti_3681a4d031; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_grant_jti_3681a4d031 ON public.operator_secret_credential_ceremony_transactions USING btree (grant_jti);


--
-- Name: idx_on_login_challenge_48fb6dd61c; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_login_challenge_48fb6dd61c ON public.operator_oidc_authorization_transactions USING btree (login_challenge);


--
-- Name: idx_on_oidc_authorization_transaction_id_395c9e4d12; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_oidc_authorization_transaction_id_395c9e4d12 ON public.operator_step_up_contexts USING btree (oidc_authorization_transaction_id);


--
-- Name: idx_on_result_jti_6830d7796f; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_result_jti_6830d7796f ON public.operator_secret_credential_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: idx_on_status_id_next_attempt_at_a804551e3d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_status_id_next_attempt_at_a804551e3d ON public.op_org_authority_stop_participants USING btree (status_id, next_attempt_at);


--
-- Name: idx_on_step_up_ceremony_transaction_ref_4eea0a0e27; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_step_up_ceremony_transaction_ref_4eea0a0e27 ON public.operator_passkey_ceremony_transactions USING btree (step_up_ceremony_transaction_ref);


--
-- Name: idx_on_step_up_ceremony_transaction_ref_f5867f0b3e; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_step_up_ceremony_transaction_ref_f5867f0b3e ON public.operator_passkey_ceremony_candidates USING btree (step_up_ceremony_transaction_ref);


--
-- Name: idx_on_step_up_ceremony_transaction_ref_fea762a569; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_step_up_ceremony_transaction_ref_fea762a569 ON public.operator_step_up_sessions USING btree (step_up_ceremony_transaction_ref);


--
-- Name: idx_on_stop_id_grant_id_1e98486a66; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_stop_id_grant_id_1e98486a66 ON public.op_org_authority_stop_grant_targets USING btree (stop_id, grant_id);


--
-- Name: idx_on_stop_id_grant_id_d7c02feece; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_stop_id_grant_id_d7c02feece ON public.op_org_authority_stop_participants USING btree (stop_id, grant_id);


--
-- Name: idx_on_stop_id_root_id_65ee336a20; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_stop_id_root_id_65ee336a20 ON public.op_org_authority_stop_root_targets USING btree (stop_id, root_id);


--
-- Name: idx_on_transaction_id_45064136d6; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_transaction_id_45064136d6 ON public.operator_oidc_authorization_transactions USING btree (transaction_id);


--
-- Name: idx_on_transaction_id_578b62ae6d; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_transaction_id_578b62ae6d ON public.operator_telephone_ceremony_transactions USING btree (transaction_id);


--
-- Name: idx_on_transaction_id_c4257bc798; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_transaction_id_c4257bc798 ON public.operator_secret_credential_ceremony_transactions USING btree (transaction_id);


--
-- Name: idx_op_org_consumed_jtis_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_op_org_consumed_jtis_expires_at ON public.op_consumed_jtis USING btree (expires_at);


--
-- Name: idx_op_org_consumed_jtis_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_org_consumed_jtis_scope ON public.op_consumed_jtis USING btree (purpose, issuer, realm, client_id, jti_digest);


--
-- Name: idx_op_org_inbound_event_receipts_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_org_inbound_event_receipts_identity ON public.op_inbound_event_receipts USING btree (event_id, issuer, realm, client_id);


--
-- Name: idx_operator_admission_active_oidc_purpose; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_admission_active_oidc_purpose ON public.operator_auth_admission_bindings USING btree (authorization_transaction_id, purpose) WHERE ((authorization_transaction_id IS NOT NULL) AND (status_id = ANY (ARRAY[(10)::bigint, (20)::bigint, (30)::bigint])));


--
-- Name: idx_operator_admission_active_step_purpose; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_admission_active_step_purpose ON public.operator_auth_admission_bindings USING btree (step_up_ceremony_transaction_id, purpose) WHERE ((step_up_ceremony_transaction_id IS NOT NULL) AND (status_id = ANY (ARRAY[(10)::bigint, (20)::bigint, (30)::bigint])));


--
-- Name: idx_operator_admission_bindings_auth_session; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operator_admission_bindings_auth_session ON public.operator_auth_admission_bindings USING btree (auth_ceremony_session_id) WHERE (auth_ceremony_session_id IS NOT NULL);


--
-- Name: idx_operator_auth_ceremony_sessions_state_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_auth_ceremony_sessions_state_parent ON public.operator_auth_ceremony_sessions USING btree (authorization_transaction_ref) WHERE ((authorization_transaction_ref IS NOT NULL) AND (status_id <> ALL (ARRAY[(92)::bigint, (93)::bigint])));


--
-- Name: idx_operator_resolution_open_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_resolution_open_parent ON public.operator_session_limit_resolution_transactions USING btree (sign_in_flow_id) WHERE (state_id = ANY (ARRAY[(10)::bigint, (20)::bigint]));


--
-- Name: idx_operator_resolution_waiting_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_resolution_waiting_actor ON public.operator_session_limit_resolution_transactions USING btree (actor_ref) WHERE (waiting_slot = 1);


--
-- Name: idx_operator_sensitive_attach_admission; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_sensitive_attach_admission ON public.operator_sensitive_admission_attachments USING btree (sensitive_admission_id);


--
-- Name: idx_operator_sensitive_attach_confirmation; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_sensitive_attach_confirmation ON public.operator_sensitive_admission_attachments USING btree (confirmation_ref);


--
-- Name: idx_operator_sensitive_attach_session; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_sensitive_attach_session ON public.operator_sensitive_admission_attachments USING btree (auth_ceremony_session_digest);


--
-- Name: idx_operator_sensitive_audit_attempt_delivered; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_sensitive_audit_attempt_delivered ON public.operator_sensitive_admission_audit_attempts USING btree (outbox_id) WHERE ((outcome)::text = 'delivered'::text);


--
-- Name: idx_operator_sensitive_audit_attempt_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_sensitive_audit_attempt_number ON public.operator_sensitive_admission_audit_attempts USING btree (outbox_id, attempt_number);


--
-- Name: idx_operator_sensitive_audit_context; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_sensitive_audit_context ON public.operator_sensitive_admission_audit_outboxes USING btree (context_ref);


--
-- Name: idx_operator_sensitive_audit_delivery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operator_sensitive_audit_delivery ON public.operator_sensitive_admission_audit_outboxes USING btree (delivery_state_id);


--
-- Name: idx_operator_sensitive_audit_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_sensitive_audit_uuid ON public.operator_sensitive_admission_audit_outboxes USING btree (event_uuid);


--
-- Name: idx_operator_sensitive_confirm_admission; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_sensitive_confirm_admission ON public.operator_sensitive_admission_confirmations USING btree (sensitive_admission_id);


--
-- Name: idx_operator_sensitive_redeem_admission; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_sensitive_redeem_admission ON public.operator_sensitive_admission_redemptions USING btree (sensitive_admission_id);


--
-- Name: idx_operator_sensitive_redeem_ceremony; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_sensitive_redeem_ceremony ON public.operator_sensitive_admission_redemptions USING btree (ceremony_ref);


--
-- Name: idx_operator_sensitive_session_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_sensitive_session_digest ON public.operator_sensitive_admission_sessions USING btree (sid_digest);


--
-- Name: idx_operator_sensitive_session_phase; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_sensitive_session_phase ON public.operator_sensitive_admission_sessions USING btree (sensitive_admission_id, phase);


--
-- Name: idx_operator_session_limit_resolution_txns_on_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operator_session_limit_resolution_txns_on_state_id ON public.operator_session_limit_resolution_transactions USING btree (state_id);


--
-- Name: idx_operator_step_up_audit_attempts_delivered; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_step_up_audit_attempts_delivered ON public.operator_step_up_audit_outbox_attempts USING btree (outbox_id) WHERE ((outcome)::text = 'delivered'::text);


--
-- Name: idx_operator_step_up_audit_attempts_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_step_up_audit_attempts_number ON public.operator_step_up_audit_outbox_attempts USING btree (outbox_id, attempt_number);


--
-- Name: idx_operator_step_up_audit_outboxes_delivery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operator_step_up_audit_outboxes_delivery ON public.operator_step_up_audit_outboxes USING btree (delivery_state_id);


--
-- Name: idx_operator_step_up_audit_outboxes_event_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_step_up_audit_outboxes_event_uuid ON public.operator_step_up_audit_outboxes USING btree (event_uuid);


--
-- Name: idx_operator_step_up_audit_outboxes_rejected; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_step_up_audit_outboxes_rejected ON public.operator_step_up_audit_outboxes USING btree (realm, client_id, context_ref, reason_code) WHERE ((event_type)::text = 'step_up.attempt_rejected'::text);


--
-- Name: idx_operator_step_up_commits_context_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_step_up_commits_context_ref ON public.operator_step_up_commits USING btree (context_ref);


--
-- Name: idx_operator_step_up_commits_root_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operator_step_up_commits_root_time ON public.operator_step_up_commits USING btree (root_token_id, committed_at);


--
-- Name: idx_operator_step_up_context_transitions_owner_to; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_step_up_context_transitions_owner_to ON public.operator_step_up_context_transitions USING btree (owner_id, to_state_id);


--
-- Name: idx_operator_step_up_contexts_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_step_up_contexts_public_id ON public.operator_step_up_contexts USING btree (public_id);


--
-- Name: idx_operator_visa_admission_binding; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_visa_admission_binding ON public.operator_visa_sensitive_admissions USING btree (auth_admission_binding_id);


--
-- Name: idx_operator_visa_admission_oidc; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_visa_admission_oidc ON public.operator_visa_sensitive_admissions USING btree (oidc_authorization_transaction_id);


--
-- Name: idx_operator_visa_admission_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_visa_admission_ref ON public.operator_visa_sensitive_admissions USING btree (public_ref);


--
-- Name: idx_operator_visa_admission_rp_session; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operator_visa_admission_rp_session ON public.operator_visa_sensitive_admissions USING btree (rp_session_ref, status);


--
-- Name: idx_operator_visa_admission_ticket; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_visa_admission_ticket ON public.operator_visa_sensitive_admissions USING btree (step_up_ceremony_transaction_id);


--
-- Name: index_op_org_authority_stop_epoch_cutoffs_on_stop_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_op_org_authority_stop_epoch_cutoffs_on_stop_id ON public.op_org_authority_stop_epoch_cutoffs USING btree (stop_id);


--
-- Name: index_op_org_authority_stop_grant_targets_on_grant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_op_org_authority_stop_grant_targets_on_grant_id ON public.op_org_authority_stop_grant_targets USING btree (grant_id);


--
-- Name: index_op_org_authority_stop_participants_on_grant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_op_org_authority_stop_participants_on_grant_id ON public.op_org_authority_stop_participants USING btree (grant_id);


--
-- Name: index_op_org_authority_stop_participants_on_stop_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_op_org_authority_stop_participants_on_stop_id ON public.op_org_authority_stop_participants USING btree (stop_id);


--
-- Name: index_op_org_authority_stop_root_targets_on_root_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_op_org_authority_stop_root_targets_on_root_id ON public.op_org_authority_stop_root_targets USING btree (root_id);


--
-- Name: index_op_org_authority_stops_on_cause_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_op_org_authority_stops_on_cause_id ON public.op_org_authority_stops USING btree (cause_id);


--
-- Name: index_op_org_authority_stops_on_principal_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_op_org_authority_stops_on_principal_public_id ON public.op_org_authority_stops USING btree (principal_public_id);


--
-- Name: index_op_org_authority_stops_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_op_org_authority_stops_on_public_id ON public.op_org_authority_stops USING btree (public_id);


--
-- Name: index_op_org_authority_stops_on_realm_and_idempotency_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_op_org_authority_stops_on_realm_and_idempotency_digest ON public.op_org_authority_stops USING btree (realm, idempotency_digest);


--
-- Name: index_op_org_authority_stops_on_scope_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_op_org_authority_stops_on_scope_id ON public.op_org_authority_stops USING btree (scope_id);


--
-- Name: index_op_org_grant_logout_hints_on_grant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_op_org_grant_logout_hints_on_grant_id ON public.op_org_grant_logout_hints USING btree (grant_id);


--
-- Name: index_op_org_grants_on_oidc_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_op_org_grants_on_oidc_client_id ON public.op_org_grants USING btree (oidc_client_id);


--
-- Name: index_op_org_grants_on_operator_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_op_org_grants_on_operator_token_id ON public.op_org_grants USING btree (operator_token_id);


--
-- Name: index_op_org_grants_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_op_org_grants_on_public_id ON public.op_org_grants USING btree (public_id);


--
-- Name: index_op_org_grants_on_refresh_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_op_org_grants_on_refresh_token_digest ON public.op_org_grants USING btree (refresh_token_digest) WHERE (refresh_token_digest IS NOT NULL);


--
-- Name: index_op_org_grants_on_revoked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_op_org_grants_on_revoked_at ON public.op_org_grants USING btree (revoked_at);


--
-- Name: index_operator_auth_admission_bindings_on_confirmation_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_auth_admission_bindings_on_confirmation_ref ON public.operator_auth_admission_bindings USING btree (confirmation_ref) WHERE (confirmation_ref IS NOT NULL);


--
-- Name: index_operator_auth_admission_bindings_on_entry_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_auth_admission_bindings_on_entry_ref ON public.operator_auth_admission_bindings USING btree (entry_ref);


--
-- Name: index_operator_auth_admission_bindings_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_auth_admission_bindings_on_expires_at ON public.operator_auth_admission_bindings USING btree (expires_at);


--
-- Name: index_operator_auth_ceremony_sessions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_auth_ceremony_sessions_on_expires_at ON public.operator_auth_ceremony_sessions USING btree (expires_at);


--
-- Name: index_operator_auth_ceremony_sessions_on_revoked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_auth_ceremony_sessions_on_revoked_at ON public.operator_auth_ceremony_sessions USING btree (revoked_at);


--
-- Name: index_operator_auth_ceremony_sessions_on_sid_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_auth_ceremony_sessions_on_sid_digest ON public.operator_auth_ceremony_sessions USING btree (sid_digest);


--
-- Name: index_operator_device_sessions_on_current_refresh_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_device_sessions_on_current_refresh_token_id ON public.operator_device_sessions USING btree (current_refresh_token_id);


--
-- Name: index_operator_device_sessions_on_dbsc_session_id_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_device_sessions_on_dbsc_session_id_digest ON public.operator_device_sessions USING btree (dbsc_session_id_digest);


--
-- Name: index_operator_device_sessions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_device_sessions_on_public_id ON public.operator_device_sessions USING btree (public_id);


--
-- Name: index_operator_device_sessions_on_refresh_token_family_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_device_sessions_on_refresh_token_family_id ON public.operator_device_sessions USING btree (refresh_token_family_id);


--
-- Name: index_operator_device_sessions_on_revoked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_device_sessions_on_revoked_at ON public.operator_device_sessions USING btree (revoked_at);


--
-- Name: index_operator_device_sessions_on_staff_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_device_sessions_on_staff_id_and_id ON public.operator_device_sessions USING btree (staff_id, id);


--
-- Name: index_operator_dpop_proof_states_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_dpop_proof_states_on_expires_at ON public.operator_dpop_proof_states USING btree (expires_at);


--
-- Name: index_operator_dpop_proof_states_on_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_dpop_proof_states_on_jti ON public.operator_dpop_proof_states USING btree (jti) WHERE (jti IS NOT NULL);


--
-- Name: index_operator_dpop_proof_states_on_nonce; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_dpop_proof_states_on_nonce ON public.operator_dpop_proof_states USING btree (nonce) WHERE (nonce IS NOT NULL);


--
-- Name: index_operator_email_ceremony_transactions_on_evp_nonce_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_email_ceremony_transactions_on_evp_nonce_digest ON public.operator_email_ceremony_transactions USING btree (evp_nonce_digest) WHERE (evp_nonce_digest IS NOT NULL);


--
-- Name: index_operator_email_ceremony_transactions_on_evp_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_email_ceremony_transactions_on_evp_token_digest ON public.operator_email_ceremony_transactions USING btree (evp_token_digest) WHERE (evp_token_digest IS NOT NULL);


--
-- Name: index_operator_email_ceremony_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_email_ceremony_transactions_on_expires_at ON public.operator_email_ceremony_transactions USING btree (expires_at);


--
-- Name: index_operator_email_ceremony_transactions_on_grant_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_email_ceremony_transactions_on_grant_jti ON public.operator_email_ceremony_transactions USING btree (grant_jti);


--
-- Name: index_operator_email_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_email_ceremony_transactions_on_result_jti ON public.operator_email_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_operator_email_ceremony_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_email_ceremony_transactions_on_transaction_id ON public.operator_email_ceremony_transactions USING btree (transaction_id);


--
-- Name: index_operator_oauth_callback_states_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_oauth_callback_states_on_expires_at ON public.operator_oauth_callback_states USING btree (expires_at);


--
-- Name: index_operator_oauth_callback_states_on_state_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_oauth_callback_states_on_state_digest ON public.operator_oauth_callback_states USING btree (state_digest);


--
-- Name: index_operator_oidc_connections_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_oidc_connections_on_public_id ON public.operator_oidc_connections USING btree (public_id);


--
-- Name: index_operator_oidc_connections_on_staff_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_oidc_connections_on_staff_id_and_client_id ON public.operator_oidc_connections USING btree (staff_id, client_id);


--
-- Name: index_operator_passkey_ceremony_candidates_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_passkey_ceremony_candidates_on_expires_at ON public.operator_passkey_ceremony_candidates USING btree (expires_at);


--
-- Name: index_operator_passkey_ceremony_candidates_on_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_passkey_ceremony_candidates_on_ref ON public.operator_passkey_ceremony_candidates USING btree (ref);


--
-- Name: index_operator_passkey_ceremony_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_passkey_ceremony_transactions_on_expires_at ON public.operator_passkey_ceremony_transactions USING btree (expires_at);


--
-- Name: index_operator_passkey_ceremony_transactions_on_grant_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_passkey_ceremony_transactions_on_grant_jti ON public.operator_passkey_ceremony_transactions USING btree (grant_jti);


--
-- Name: index_operator_passkey_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_passkey_ceremony_transactions_on_result_jti ON public.operator_passkey_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_operator_passkey_ceremony_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_passkey_ceremony_transactions_on_transaction_id ON public.operator_passkey_ceremony_transactions USING btree (transaction_id);


--
-- Name: index_operator_sensitive_admissions_on_public_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_sensitive_admissions_on_public_ref ON public.operator_sensitive_admissions USING btree (public_ref);


--
-- Name: index_operator_sensitive_admissions_on_secret_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_sensitive_admissions_on_secret_digest ON public.operator_sensitive_admissions USING btree (secret_digest);


--
-- Name: index_operator_sign_in_flows_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_in_flows_on_discard_at ON public.operator_sign_in_flows USING btree (discard_at);


--
-- Name: index_operator_sign_in_flows_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_in_flows_on_expires_at ON public.operator_sign_in_flows USING btree (expires_at);


--
-- Name: index_operator_sign_in_flows_on_principal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_in_flows_on_principal_id ON public.operator_sign_in_flows USING btree (principal_id);


--
-- Name: index_operator_sign_in_flows_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_sign_in_flows_on_public_id ON public.operator_sign_in_flows USING btree (public_id);


--
-- Name: index_operator_sign_in_flows_on_result_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_sign_in_flows_on_result_digest ON public.operator_sign_in_flows USING btree (result_digest);


--
-- Name: index_operator_sign_in_flows_on_selected_persona_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_in_flows_on_selected_persona_id ON public.operator_sign_in_flows USING btree (selected_persona_id);


--
-- Name: index_operator_sign_in_flows_on_selected_region_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_in_flows_on_selected_region_id ON public.operator_sign_in_flows USING btree (selected_region_id);


--
-- Name: index_operator_sign_in_flows_on_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_in_flows_on_state_id ON public.operator_sign_in_flows USING btree (state_id);


--
-- Name: index_operator_sign_in_flows_on_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_in_flows_on_token_id ON public.operator_sign_in_flows USING btree (token_id);


--
-- Name: index_operator_sign_in_flows_on_token_id_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_sign_in_flows_on_token_id_unique ON public.operator_sign_in_flows USING btree (token_id) WHERE (token_id IS NOT NULL);


--
-- Name: index_operator_sign_up_flows_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_up_flows_on_discard_at ON public.operator_sign_up_flows USING btree (discard_at);


--
-- Name: index_operator_sign_up_flows_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_up_flows_on_expires_at ON public.operator_sign_up_flows USING btree (expires_at);


--
-- Name: index_operator_sign_up_flows_on_principal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_up_flows_on_principal_id ON public.operator_sign_up_flows USING btree (principal_id);


--
-- Name: index_operator_sign_up_flows_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_sign_up_flows_on_public_id ON public.operator_sign_up_flows USING btree (public_id);


--
-- Name: index_operator_sign_up_flows_on_result_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_sign_up_flows_on_result_digest ON public.operator_sign_up_flows USING btree (result_digest);


--
-- Name: index_operator_sign_up_flows_on_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_up_flows_on_state ON public.operator_sign_up_flows USING btree (state);


--
-- Name: index_operator_sign_up_flows_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_up_flows_on_status_id ON public.operator_sign_up_flows USING btree (status_id);


--
-- Name: index_operator_sign_up_flows_on_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_up_flows_on_token_id ON public.operator_sign_up_flows USING btree (token_id);


--
-- Name: index_operator_step_up_audit_outbox_attempts_on_outbox_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_step_up_audit_outbox_attempts_on_outbox_id ON public.operator_step_up_audit_outbox_attempts USING btree (outbox_id);


--
-- Name: index_operator_step_up_audit_outboxes_on_delivery_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_step_up_audit_outboxes_on_delivery_state_id ON public.operator_step_up_audit_outboxes USING btree (delivery_state_id);


--
-- Name: index_operator_step_up_ceremony_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_step_up_ceremony_transactions_on_expires_at ON public.operator_step_up_ceremony_transactions USING btree (expires_at);


--
-- Name: index_operator_step_up_ceremony_transactions_on_grant_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_step_up_ceremony_transactions_on_grant_jti ON public.operator_step_up_ceremony_transactions USING btree (grant_jti);


--
-- Name: index_operator_step_up_ceremony_transactions_on_required_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_step_up_ceremony_transactions_on_required_scope ON public.operator_step_up_ceremony_transactions USING btree (required_scope);


--
-- Name: index_operator_step_up_ceremony_transactions_on_result_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_step_up_ceremony_transactions_on_result_digest ON public.operator_step_up_ceremony_transactions USING btree (result_digest);


--
-- Name: index_operator_step_up_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_step_up_ceremony_transactions_on_result_jti ON public.operator_step_up_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_operator_step_up_ceremony_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_step_up_ceremony_transactions_on_transaction_id ON public.operator_step_up_ceremony_transactions USING btree (transaction_id);


--
-- Name: index_operator_step_up_commits_on_grant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_step_up_commits_on_grant_id ON public.operator_step_up_commits USING btree (grant_id);


--
-- Name: index_operator_step_up_commits_on_root_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_step_up_commits_on_root_token_id ON public.operator_step_up_commits USING btree (root_token_id);


--
-- Name: index_operator_step_up_context_transitions_on_from_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_step_up_context_transitions_on_from_state_id ON public.operator_step_up_context_transitions USING btree (from_state_id);


--
-- Name: index_operator_step_up_context_transitions_on_to_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_step_up_context_transitions_on_to_state_id ON public.operator_step_up_context_transitions USING btree (to_state_id);


--
-- Name: index_operator_step_up_contexts_on_grant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_step_up_contexts_on_grant_id ON public.operator_step_up_contexts USING btree (grant_id);


--
-- Name: index_operator_step_up_contexts_on_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_step_up_contexts_on_state_id ON public.operator_step_up_contexts USING btree (state_id);


--
-- Name: index_operator_step_up_sessions_on_passkey_challenge_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_step_up_sessions_on_passkey_challenge_ref ON public.operator_step_up_sessions USING btree (passkey_challenge_ref);


--
-- Name: index_operator_step_up_sessions_on_staff_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_step_up_sessions_on_staff_token_id ON public.operator_step_up_sessions USING btree (staff_token_id);


--
-- Name: index_operator_telephone_ceremony_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_telephone_ceremony_transactions_on_expires_at ON public.operator_telephone_ceremony_transactions USING btree (expires_at);


--
-- Name: index_operator_telephone_ceremony_transactions_on_grant_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_telephone_ceremony_transactions_on_grant_jti ON public.operator_telephone_ceremony_transactions USING btree (grant_jti);


--
-- Name: index_operator_telephone_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_telephone_ceremony_transactions_on_result_jti ON public.operator_telephone_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_operator_tokens_on_authentication_context; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_authentication_context ON public.operator_tokens USING btree (authentication_context);


--
-- Name: index_operator_tokens_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_created_at ON public.operator_tokens USING btree (created_at);


--
-- Name: index_operator_tokens_on_dbsc_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_tokens_on_dbsc_session_id ON public.operator_tokens USING btree (dbsc_session_id);


--
-- Name: index_operator_tokens_on_device_session_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_tokens_on_device_session_id_and_id ON public.operator_tokens USING btree (device_session_id, id);


--
-- Name: index_operator_tokens_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_discard_at ON public.operator_tokens USING btree (discard_at);


--
-- Name: index_operator_tokens_on_established_authentication_method; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_established_authentication_method ON public.operator_tokens USING btree (established_authentication_method);


--
-- Name: index_operator_tokens_on_oidc_connection_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_oidc_connection_id ON public.operator_tokens USING btree (oidc_connection_id);


--
-- Name: index_operator_tokens_on_oidc_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_oidc_jti ON public.operator_tokens USING btree (oidc_jti);


--
-- Name: index_operator_tokens_on_oidc_sid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_oidc_sid ON public.operator_tokens USING btree (oidc_sid);


--
-- Name: index_operator_tokens_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_tokens_on_public_id ON public.operator_tokens USING btree (public_id);


--
-- Name: index_operator_tokens_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_purge_eligible_at ON public.operator_tokens USING btree (purge_eligible_at);


--
-- Name: index_operator_tokens_on_refresh_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_tokens_on_refresh_token_digest ON public.operator_tokens USING btree (refresh_token_digest);


--
-- Name: index_operator_tokens_on_refresh_token_family_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_refresh_token_family_id ON public.operator_tokens USING btree (refresh_token_family_id);


--
-- Name: index_operator_tokens_on_rotated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_rotated_at ON public.operator_tokens USING btree (rotated_at);


--
-- Name: index_operator_tokens_on_selected_account_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_selected_account_public_id ON public.operator_tokens USING btree (selected_account_public_id);


--
-- Name: index_operator_tokens_on_selected_avatar_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_selected_avatar_public_id ON public.operator_tokens USING btree (selected_avatar_public_id);


--
-- Name: index_operator_tokens_on_selected_collective_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_selected_collective_public_id ON public.operator_tokens USING btree (selected_collective_public_id);


--
-- Name: index_operator_tokens_on_staff_id_and_last_step_up_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_staff_id_and_last_step_up_at ON public.operator_tokens USING btree (staff_id, last_step_up_at);


--
-- Name: index_operator_tokens_on_staff_id_and_oidc_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_staff_id_and_oidc_client_id ON public.operator_tokens USING btree (staff_id, oidc_client_id);


--
-- Name: index_operator_tokens_on_staff_id_root_login_established_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_staff_id_root_login_established_at ON public.operator_tokens USING btree (staff_id, root_login_established_at) WHERE (root_login_established_at IS NOT NULL);


--
-- Name: index_operator_tokens_on_staff_token_binding_method_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_staff_token_binding_method_id ON public.operator_tokens USING btree (staff_token_binding_method_id);


--
-- Name: index_operator_tokens_on_staff_token_dbsc_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_staff_token_dbsc_status_id ON public.operator_tokens USING btree (staff_token_dbsc_status_id);


--
-- Name: index_operator_tokens_on_staff_token_kind_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_staff_token_kind_id ON public.operator_tokens USING btree (staff_token_kind_id);


--
-- Name: index_operator_tokens_on_staff_token_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_staff_token_status_id ON public.operator_tokens USING btree (staff_token_status_id);


--
-- Name: index_operator_verifications_on_staff_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_verifications_on_staff_token_id ON public.operator_verifications USING btree (staff_token_id);


--
-- Name: index_operator_verifications_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_verifications_on_token_digest ON public.operator_verifications USING btree (token_digest);


--
-- Name: index_organization_invitations_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_organization_invitations_on_code ON public.organization_invitations USING btree (code);


--
-- Name: index_organization_invitations_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organization_invitations_on_email ON public.organization_invitations USING btree (email);


--
-- Name: index_organization_invitations_on_invited_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organization_invitations_on_invited_by_id ON public.organization_invitations USING btree (invited_by_id);


--
-- Name: index_organization_invitations_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organization_invitations_on_organization_id ON public.organization_invitations USING btree (organization_id);


--
-- Name: operator_email_otp_original_bootstrap; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX operator_email_otp_original_bootstrap ON public.operator_email_ceremony_transactions USING btree (bootstrap_ceremony_transaction_ref);


--
-- Name: operator_email_ceremony_transactions operator_email_terminal_otp_facts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER operator_email_terminal_otp_facts BEFORE UPDATE ON public.operator_email_ceremony_transactions FOR EACH ROW EXECUTE FUNCTION public.enforce_operator_email_terminal_otp_facts();


--
-- Name: operator_telephone_ceremony_transactions operator_telephone_terminal_otp_facts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER operator_telephone_terminal_otp_facts BEFORE UPDATE ON public.operator_telephone_ceremony_transactions FOR EACH ROW EXECUTE FUNCTION public.enforce_operator_telephone_terminal_otp_facts();


--
-- Name: op_org_grants fk_op_org_grants_on_device_session_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_grants
    ADD CONSTRAINT fk_op_org_grants_on_device_session_id FOREIGN KEY (device_session_id) REFERENCES public.operator_device_sessions(id) ON DELETE RESTRICT;


--
-- Name: operator_auth_admission_bindings fk_operator_admission_bindings_status; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_admission_bindings
    ADD CONSTRAINT fk_operator_admission_bindings_status FOREIGN KEY (status_id) REFERENCES public.operator_auth_admission_binding_statuses(id) ON DELETE RESTRICT;


--
-- Name: operator_auth_admission_bindings fk_operator_auth_admission_bindings_admitted_session; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_admission_bindings
    ADD CONSTRAINT fk_operator_auth_admission_bindings_admitted_session FOREIGN KEY (admitted_auth_ceremony_session_id) REFERENCES public.operator_auth_ceremony_sessions(id) ON DELETE RESTRICT;


--
-- Name: operator_auth_ceremony_sessions fk_operator_auth_ceremony_sessions_status; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_ceremony_sessions
    ADD CONSTRAINT fk_operator_auth_ceremony_sessions_status FOREIGN KEY (status_id) REFERENCES public.operator_auth_ceremony_session_statuses(id) ON DELETE RESTRICT;


--
-- Name: operator_device_sessions fk_operator_device_sessions_on_current_refresh_token_owner; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_device_sessions
    ADD CONSTRAINT fk_operator_device_sessions_on_current_refresh_token_owner FOREIGN KEY (id, current_refresh_token_id) REFERENCES public.operator_tokens(device_session_id, id) ON DELETE SET NULL (current_refresh_token_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: operator_oidc_authorization_transactions fk_operator_oidc_authorization_transactions_status; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_oidc_authorization_transactions
    ADD CONSTRAINT fk_operator_oidc_authorization_transactions_status FOREIGN KEY (status_id) REFERENCES public.operator_oidc_authorization_transaction_statuses(id) ON DELETE RESTRICT;


--
-- Name: operator_tokens fk_operator_tokens_on_device_session_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT fk_operator_tokens_on_device_session_id FOREIGN KEY (device_session_id) REFERENCES public.operator_device_sessions(id) ON DELETE RESTRICT;


--
-- Name: operator_tokens fk_operator_tokens_on_oidc_connection_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT fk_operator_tokens_on_oidc_connection_id FOREIGN KEY (oidc_connection_id) REFERENCES public.operator_oidc_connections(id) ON DELETE SET NULL;


--
-- Name: operator_tokens fk_operator_tokens_on_staff_id_and_device_session_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT fk_operator_tokens_on_staff_id_and_device_session_id FOREIGN KEY (staff_id, device_session_id) REFERENCES public.operator_device_sessions(staff_id, id) ON DELETE RESTRICT;


--
-- Name: op_org_authority_stops fk_org_stop_restrict_01; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stops
    ADD CONSTRAINT fk_org_stop_restrict_01 FOREIGN KEY (cause_id) REFERENCES public.op_org_authority_stop_causes(id) ON DELETE RESTRICT;


--
-- Name: op_org_authority_stops fk_org_stop_restrict_02; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stops
    ADD CONSTRAINT fk_org_stop_restrict_02 FOREIGN KEY (scope_id) REFERENCES public.op_org_authority_stop_scopes(id) ON DELETE RESTRICT;


--
-- Name: op_org_authority_stop_root_targets fk_org_stop_restrict_03; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_root_targets
    ADD CONSTRAINT fk_org_stop_restrict_03 FOREIGN KEY (stop_id) REFERENCES public.op_org_authority_stops(id) ON DELETE RESTRICT;


--
-- Name: op_org_authority_stop_root_targets fk_org_stop_restrict_04; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_root_targets
    ADD CONSTRAINT fk_org_stop_restrict_04 FOREIGN KEY (root_id) REFERENCES public.operator_tokens(id) ON DELETE RESTRICT;


--
-- Name: op_org_authority_stop_grant_targets fk_org_stop_restrict_05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_grant_targets
    ADD CONSTRAINT fk_org_stop_restrict_05 FOREIGN KEY (stop_id) REFERENCES public.op_org_authority_stops(id) ON DELETE RESTRICT;


--
-- Name: op_org_authority_stop_grant_targets fk_org_stop_restrict_06; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_grant_targets
    ADD CONSTRAINT fk_org_stop_restrict_06 FOREIGN KEY (grant_id) REFERENCES public.op_org_grants(id) ON DELETE RESTRICT;


--
-- Name: op_org_authority_stop_epoch_cutoffs fk_org_stop_restrict_07; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_epoch_cutoffs
    ADD CONSTRAINT fk_org_stop_restrict_07 FOREIGN KEY (stop_id) REFERENCES public.op_org_authority_stops(id) ON DELETE RESTRICT;


--
-- Name: op_org_authority_stop_participants fk_org_stop_restrict_08; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_participants
    ADD CONSTRAINT fk_org_stop_restrict_08 FOREIGN KEY (stop_id) REFERENCES public.op_org_authority_stops(id) ON DELETE RESTRICT;


--
-- Name: op_org_authority_stop_participants fk_org_stop_restrict_09; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_participants
    ADD CONSTRAINT fk_org_stop_restrict_09 FOREIGN KEY (grant_id) REFERENCES public.op_org_grants(id) ON DELETE RESTRICT;


--
-- Name: op_org_authority_stop_participants fk_org_stop_restrict_10; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_authority_stop_participants
    ADD CONSTRAINT fk_org_stop_restrict_10 FOREIGN KEY (status_id) REFERENCES public.op_org_authority_stop_participant_statuses(id) ON DELETE RESTRICT;


--
-- Name: operator_step_up_audit_outboxes fk_rails_02dd7688b4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_audit_outboxes
    ADD CONSTRAINT fk_rails_02dd7688b4 FOREIGN KEY (delivery_state_id) REFERENCES public.operator_step_up_audit_outbox_delivery_states(id);


--
-- Name: operator_sign_in_flows fk_rails_0451f7d1d6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_in_flows
    ADD CONSTRAINT fk_rails_0451f7d1d6 FOREIGN KEY (token_id) REFERENCES public.operator_tokens(id) ON DELETE CASCADE NOT VALID;


--
-- Name: operator_step_up_context_transitions fk_rails_0f4b02cd69; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_context_transitions
    ADD CONSTRAINT fk_rails_0f4b02cd69 FOREIGN KEY (from_state_id) REFERENCES public.operator_step_up_context_states(id);


--
-- Name: operator_step_up_sessions fk_rails_100937c5e6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_sessions
    ADD CONSTRAINT fk_rails_100937c5e6 FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.operator_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;


--
-- Name: operator_sign_up_flows fk_rails_10f95a7068; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_up_flows
    ADD CONSTRAINT fk_rails_10f95a7068 FOREIGN KEY (token_id) REFERENCES public.operator_tokens(id) ON DELETE CASCADE NOT VALID;


--
-- Name: operator_tokens fk_rails_1a807f181b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT fk_rails_1a807f181b FOREIGN KEY (staff_token_status_id) REFERENCES public.operator_token_statuses(id) ON DELETE RESTRICT NOT VALID;


--
-- Name: operator_step_up_commits fk_rails_26b4d7aef3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_commits
    ADD CONSTRAINT fk_rails_26b4d7aef3 FOREIGN KEY (root_token_id) REFERENCES public.operator_tokens(id) ON DELETE CASCADE;


--
-- Name: operator_sensitive_admission_audit_outboxes fk_rails_2eb1090857; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sensitive_admission_audit_outboxes
    ADD CONSTRAINT fk_rails_2eb1090857 FOREIGN KEY (delivery_state_id) REFERENCES public.operator_step_up_audit_outbox_delivery_states(id);


--
-- Name: operator_step_up_contexts fk_rails_2faed4d00d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_contexts
    ADD CONSTRAINT fk_rails_2faed4d00d FOREIGN KEY (oidc_authorization_transaction_id) REFERENCES public.operator_oidc_authorization_transactions(id) ON DELETE CASCADE;


--
-- Name: operator_step_up_context_transitions fk_rails_42281f6f1a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_context_transitions
    ADD CONSTRAINT fk_rails_42281f6f1a FOREIGN KEY (owner_id) REFERENCES public.operator_step_up_contexts(id) ON DELETE CASCADE;


--
-- Name: operator_step_up_context_transitions fk_rails_43a3d1b1c5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_context_transitions
    ADD CONSTRAINT fk_rails_43a3d1b1c5 FOREIGN KEY (to_state_id) REFERENCES public.operator_step_up_context_states(id);


--
-- Name: operator_auth_admission_bindings fk_rails_45e80eb054; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_admission_bindings
    ADD CONSTRAINT fk_rails_45e80eb054 FOREIGN KEY (authorization_transaction_id) REFERENCES public.operator_oidc_authorization_transactions(id) ON DELETE RESTRICT;


--
-- Name: operator_session_limit_resolution_transactions fk_rails_4b8c3412fb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_session_limit_resolution_transactions
    ADD CONSTRAINT fk_rails_4b8c3412fb FOREIGN KEY (oidc_authorization_transaction_id) REFERENCES public.operator_oidc_authorization_transactions(id) ON DELETE RESTRICT;


--
-- Name: operator_auth_ceremony_sessions fk_rails_562d790641; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_ceremony_sessions
    ADD CONSTRAINT fk_rails_562d790641 FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.operator_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;


--
-- Name: operator_step_up_contexts fk_rails_5eeee99357; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_contexts
    ADD CONSTRAINT fk_rails_5eeee99357 FOREIGN KEY (grant_id) REFERENCES public.op_org_grants(id);


--
-- Name: operator_visa_sensitive_admissions fk_rails_67c40c5bee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_visa_sensitive_admissions
    ADD CONSTRAINT fk_rails_67c40c5bee FOREIGN KEY (oidc_authorization_transaction_id) REFERENCES public.operator_oidc_authorization_transactions(id) ON DELETE RESTRICT;


--
-- Name: operator_step_up_sessions fk_rails_6daa6fb880; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_sessions
    ADD CONSTRAINT fk_rails_6daa6fb880 FOREIGN KEY (staff_token_id) REFERENCES public.operator_tokens(id) ON DELETE CASCADE NOT VALID;


--
-- Name: operator_auth_admission_bindings fk_rails_781188228f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_admission_bindings
    ADD CONSTRAINT fk_rails_781188228f FOREIGN KEY (auth_ceremony_session_id) REFERENCES public.operator_auth_ceremony_sessions(id) ON DELETE RESTRICT NOT VALID;


--
-- Name: operator_step_up_commits fk_rails_865350f7e1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_commits
    ADD CONSTRAINT fk_rails_865350f7e1 FOREIGN KEY (grant_id) REFERENCES public.op_org_grants(id);


--
-- Name: op_org_grant_logout_hints fk_rails_8e27a86796; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_grant_logout_hints
    ADD CONSTRAINT fk_rails_8e27a86796 FOREIGN KEY (grant_id) REFERENCES public.op_org_grants(id) ON DELETE CASCADE;


--
-- Name: operator_visa_sensitive_admissions fk_rails_92d6eb1f93; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_visa_sensitive_admissions
    ADD CONSTRAINT fk_rails_92d6eb1f93 FOREIGN KEY (auth_admission_binding_id) REFERENCES public.operator_auth_admission_bindings(id) ON DELETE RESTRICT;


--
-- Name: operator_passkey_ceremony_candidates fk_rails_9740344565; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkey_ceremony_candidates
    ADD CONSTRAINT fk_rails_9740344565 FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.operator_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;


--
-- Name: operator_step_up_contexts fk_rails_aa7b9090a8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_contexts
    ADD CONSTRAINT fk_rails_aa7b9090a8 FOREIGN KEY (state_id) REFERENCES public.operator_step_up_context_states(id);


--
-- Name: operator_auth_admission_bindings fk_rails_ab24cfb189; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_admission_bindings
    ADD CONSTRAINT fk_rails_ab24cfb189 FOREIGN KEY (step_up_ceremony_transaction_id) REFERENCES public.operator_step_up_ceremony_transactions(id) ON DELETE RESTRICT;


--
-- Name: operator_session_limit_resolution_transactions fk_rails_ae3cdca20d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_session_limit_resolution_transactions
    ADD CONSTRAINT fk_rails_ae3cdca20d FOREIGN KEY (sign_in_flow_id) REFERENCES public.operator_sign_in_flows(id) ON DELETE RESTRICT;


--
-- Name: operator_sensitive_admission_audit_attempts fk_rails_b4a8f677d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sensitive_admission_audit_attempts
    ADD CONSTRAINT fk_rails_b4a8f677d2 FOREIGN KEY (outbox_id) REFERENCES public.operator_sensitive_admission_audit_outboxes(id);


--
-- Name: operator_sensitive_admission_redemptions fk_rails_b617903316; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sensitive_admission_redemptions
    ADD CONSTRAINT fk_rails_b617903316 FOREIGN KEY (sensitive_admission_id) REFERENCES public.operator_sensitive_admissions(id);


--
-- Name: operator_auth_admission_bindings fk_rails_bed2bdd1dc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_admission_bindings
    ADD CONSTRAINT fk_rails_bed2bdd1dc FOREIGN KEY (base_token_id) REFERENCES public.operator_tokens(id) ON DELETE RESTRICT;


--
-- Name: operator_session_limit_resolution_transactions fk_rails_c58833695b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_session_limit_resolution_transactions
    ADD CONSTRAINT fk_rails_c58833695b FOREIGN KEY (state_id) REFERENCES public.operator_session_limit_resolution_states(id) ON DELETE RESTRICT;


--
-- Name: operator_passkey_ceremony_transactions fk_rails_c78dc3cda8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkey_ceremony_transactions
    ADD CONSTRAINT fk_rails_c78dc3cda8 FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.operator_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;


--
-- Name: operator_verifications fk_rails_c8ab8d08df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_verifications
    ADD CONSTRAINT fk_rails_c8ab8d08df FOREIGN KEY (staff_token_id) REFERENCES public.operator_tokens(id) ON DELETE CASCADE NOT VALID;


--
-- Name: operator_visa_sensitive_admissions fk_rails_cd39196537; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_visa_sensitive_admissions
    ADD CONSTRAINT fk_rails_cd39196537 FOREIGN KEY (step_up_ceremony_transaction_id) REFERENCES public.operator_step_up_ceremony_transactions(id) ON DELETE RESTRICT;


--
-- Name: operator_sensitive_admission_attachments fk_rails_cdb1c75b73; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sensitive_admission_attachments
    ADD CONSTRAINT fk_rails_cdb1c75b73 FOREIGN KEY (sensitive_admission_id) REFERENCES public.operator_sensitive_admissions(id);


--
-- Name: operator_sensitive_admission_confirmations fk_rails_e2e415a1d1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sensitive_admission_confirmations
    ADD CONSTRAINT fk_rails_e2e415a1d1 FOREIGN KEY (sensitive_admission_id) REFERENCES public.operator_sensitive_admissions(id);


--
-- Name: operator_sign_in_flows fk_rails_e665ad2a06; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_in_flows
    ADD CONSTRAINT fk_rails_e665ad2a06 FOREIGN KEY (state_id) REFERENCES public.operator_sign_in_flow_states(id) ON DELETE RESTRICT;


--
-- Name: operator_sensitive_admission_sessions fk_rails_eb9725c264; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sensitive_admission_sessions
    ADD CONSTRAINT fk_rails_eb9725c264 FOREIGN KEY (sensitive_admission_id) REFERENCES public.operator_sensitive_admissions(id);


--
-- Name: operator_tokens fk_rails_f211b6bc2e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT fk_rails_f211b6bc2e FOREIGN KEY (staff_token_kind_id) REFERENCES public.operator_token_kinds(id) ON DELETE RESTRICT NOT VALID;


--
-- Name: operator_sign_up_flows fk_rails_fb3acc316b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_up_flows
    ADD CONSTRAINT fk_rails_fb3acc316b FOREIGN KEY (status_id) REFERENCES public.operator_sign_up_flow_statuses(id) NOT VALID;


--
-- Name: operator_step_up_audit_outbox_attempts fk_rails_fd53139e7e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_audit_outbox_attempts
    ADD CONSTRAINT fk_rails_fd53139e7e FOREIGN KEY (outbox_id) REFERENCES public.operator_step_up_audit_outboxes(id) ON DELETE CASCADE;


--
-- Name: operator_tokens fk_staff_tokens_on_staff_token_binding_method_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT fk_staff_tokens_on_staff_token_binding_method_id FOREIGN KEY (staff_token_binding_method_id) REFERENCES public.operator_token_binding_methods(id) NOT VALID;


--
-- Name: operator_tokens fk_staff_tokens_on_staff_token_dbsc_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT fk_staff_tokens_on_staff_token_dbsc_status_id FOREIGN KEY (staff_token_dbsc_status_id) REFERENCES public.operator_token_dbsc_statuses(id) NOT VALID;


--
-- Name: operator_email_ceremony_transactions operator_email_otp_original_bootstrap_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_email_ceremony_transactions
    ADD CONSTRAINT operator_email_otp_original_bootstrap_fk FOREIGN KEY (bootstrap_ceremony_transaction_ref) REFERENCES public.operator_step_up_ceremony_transactions(transaction_id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261105050417'),
('20261105050239'),
('20261105044800'),
('20261105035154'),
('20261104102819'),
('20261104102804'),
('20261104101959'),
('20261104101941'),
('20261104101417'),
('20261104101057'),
('20261103183205'),
('20261103183204'),
('20261103112933'),
('20261103112929'),
('20261101073144'),
('20261101073143'),
('20261101073142'),
('20261101041007'),
('20261101041006'),
('20261101041005'),
('20261101041004'),
('20261101041003'),
('20261101034355'),
('20261101034354'),
('20261101034353'),
('20261101034348'),
('20261101034343'),
('20261101031900'),
('20261101031821'),
('20261101031811'),
('20261101031720'),
('20261101031710'),
('20261026190831'),
('20261025120400'),
('20261025120301'),
('20261025120300'),
('20261025120200'),
('20261025120100'),
('20261025120000'),
('20261025100100'),
('20261024143000'),
('20261023191149'),
('20261023191130'),
('20261023130003'),
('20261023130002'),
('20261023130001'),
('20261023130000'),
('20261023120005'),
('20261023120002'),
('20261020130001'),
('20261020130000'),
('20261020120001'),
('20261020120000'),
('20261020110001'),
('20261020110000'),
('20261019110846'),
('20261019110842'),
('20261019110838'),
('20261019110834'),
('20261019035659'),
('20261019035544'),
('20261019032927'),
('20261017150000'),
('20261017140000'),
('20261017070000'),
('20261016210022'),
('20261016210015'),
('20261016210012'),
('20261016200002'),
('20261016160072'),
('20261016160062'),
('20261016160052'),
('20261016160042'),
('20261016160032'),
('20261016160022'),
('20261016160012'),
('20261016160002'),
('20261008150817'),
('20261008145947'),
('20261008094505'),
('20261008093932'),
('20261008062955'),
('20261008062848'),
('20261007223858'),
('20261007223751'),
('20261007010004'),
('20261007010003'),
('20261007010002'),
('20261007010001'),
('20261006230002'),
('20261006220002'),
('20261006210012'),
('20261006210002'),
('20261006200002'),
('20261006190102'),
('20261006190002'),
('20261006160002'),
('20261006150002'),
('20261006140002'),
('20261006130002'),
('20261006120002'),
('20261006110005'),
('20261003221725'),
('20261003215031'),
('20261003185508'),
('20261003183915'),
('20261003181725'),
('20261003175658'),
('20261002120000'),
('20260924177000'),
('20260924156000'),
('20260924155000'),
('20260924154000'),
('20260924153000'),
('20260924152000'),
('20260924151000'),
('20260924150000'),
('20260922120100'),
('20260922120000'),
('20260921140100'),
('20260921140000'),
('20260921133000'),
('20260920151000'),
('20260920150000'),
('20260917130002'),
('20260915180000'),
('20260915170000'),
('20260915160000'),
('20260913150000'),
('20260913140000'),
('20260909100001'),
('20260909100000'),
('20260831064140'),
('20260831064102'),
('20260727100001'),
('20260727100000'),
('20260710220002'),
('20260624000000'),
('20260616150020'),
('20260616150010'),
('20260612000001'),
('20260611150002'),
('20260611100100'),
('20260606120002'),
('20260603130001'),
('20260603123001'),
('20260603122001'),
('20260603121001'),
('20260603120001'),
('20260530130101'),
('20260530130001'),
('20260528183001'),
('20260528162101'),
('20260526120101'),
('20260526120001'),
('20260525233000'),
('20260520190001'),
('20260520143012'),
('20260520143010'),
('20260519111002'),
('20260519110002'),
('20260519092002'),
('20260519091002'),
('20260519090002'),
('20260518085550'),
('20260518084936'),
('20260518044556'),
('20260518020001'),
('20260517120001'),
('20260508160000'),
('20260508151000'),
('20260508140999'),
('20260508135006'),
('20260507010002'),
('20260501000000');

