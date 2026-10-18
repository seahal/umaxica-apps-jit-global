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
-- Name: logout_flow_participants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.logout_flow_participants (
    id bigint NOT NULL,
    logout_flow_id bigint NOT NULL,
    issuer character varying(255) NOT NULL,
    realm character varying(3) NOT NULL,
    client_id character varying(64) NOT NULL,
    sid character varying(255) NOT NULL,
    endpoint_identity character varying(255) NOT NULL,
    delivery_attempts integer DEFAULT 0 NOT NULL,
    next_attempt_at timestamp(6) with time zone,
    lease_expires_at timestamp(6) with time zone,
    dispatched_at timestamp(6) with time zone,
    acknowledged_at timestamp(6) with time zone,
    purge_response_at timestamp(6) with time zone,
    completed_at timestamp(6) with time zone,
    last_error_code character varying(64),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_op_org_logout_participants_shape CHECK ((((realm)::text = 'org'::text) AND (delivery_attempts >= 0)))
);


--
-- Name: logout_flow_participants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.logout_flow_participants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: logout_flow_participants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.logout_flow_participants_id_seq OWNED BY public.logout_flow_participants.id;


--
-- Name: logout_flows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.logout_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    realm character varying(3) NOT NULL,
    target_root_ref character varying(255) NOT NULL,
    idempotency_digest bytea NOT NULL,
    browser_binding_digest bytea NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    op_revoked_at timestamp(6) with time zone,
    audit_ref character varying(128) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_op_org_logout_flows_realm CHECK (((realm)::text = 'org'::text))
);


--
-- Name: logout_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.logout_flows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: logout_flows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.logout_flows_id_seq OWNED BY public.logout_flows.id;


--
-- Name: logout_receipts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.logout_receipts (
    id bigint NOT NULL,
    logout_flow_id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    nonce_digest bytea NOT NULL,
    browser_binding_digest bytea NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: logout_receipts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.logout_receipts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: logout_receipts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.logout_receipts_id_seq OWNED BY public.logout_receipts.id;


--
-- Name: op_client_activations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.op_client_activations (
    id bigint NOT NULL,
    client_id character varying(64) NOT NULL,
    contract_epoch bigint NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    changed_at timestamp(6) with time zone NOT NULL,
    actor_ref character varying(255) NOT NULL,
    audit_ref character varying(255) NOT NULL,
    source_manifest_digest character varying(64) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_op_org_client_activations_digest_format CHECK (((source_manifest_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_op_org_client_activations_epoch_positive CHECK ((contract_epoch > 0))
);


--
-- Name: op_client_activations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.op_client_activations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: op_client_activations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.op_client_activations_id_seq OWNED BY public.op_client_activations.id;


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
    refresh_delivery_ciphertext text,
    refresh_delivery_predecessor_digest character varying,
    refresh_delivery_expires_at timestamp(6) with time zone,
    contract_epoch bigint,
    authentication_epoch bigint,
    CONSTRAINT chk_op_org_grants_authentication_epoch CHECK (((authentication_epoch IS NULL) OR (authentication_epoch >= 0))),
    CONSTRAINT chk_op_org_grants_contract_epoch CHECK (((contract_epoch IS NULL) OR (contract_epoch >= 1))),
    CONSTRAINT chk_op_org_grants_refresh_delivery_all_or_none CHECK ((((refresh_delivery_ciphertext IS NULL) AND (refresh_delivery_predecessor_digest IS NULL) AND (refresh_delivery_expires_at IS NULL)) OR ((refresh_delivery_ciphertext IS NOT NULL) AND (refresh_delivery_predecessor_digest IS NOT NULL) AND (refresh_delivery_expires_at IS NOT NULL))))
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
-- Name: op_outbox_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.op_outbox_events (
    id bigint NOT NULL,
    event_id uuid DEFAULT gen_random_uuid() NOT NULL,
    logout_flow_participant_id bigint,
    event_type character varying(64) NOT NULL,
    target_realm character varying(3) NOT NULL,
    target_client_id character varying(64) NOT NULL,
    target_endpoint_identity character varying(255) NOT NULL,
    stable_event_ref character varying(128) NOT NULL,
    delivery_attempts integer DEFAULT 0 NOT NULL,
    next_attempt_at timestamp(6) with time zone NOT NULL,
    lease_expires_at timestamp(6) with time zone,
    dispatched_at timestamp(6) with time zone,
    completed_at timestamp(6) with time zone,
    last_error_code character varying(64),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_op_org_outbox_events_shape CHECK ((((target_realm)::text = 'org'::text) AND (delivery_attempts >= 0)))
);


--
-- Name: op_outbox_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.op_outbox_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: op_outbox_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.op_outbox_events_id_seq OWNED BY public.op_outbox_events.id;


--
-- Name: op_protocol_epochs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.op_protocol_epochs (
    id bigint NOT NULL,
    realm character varying(3) NOT NULL,
    contract_epoch bigint DEFAULT 1 NOT NULL,
    changed_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_op_protocol_epochs_org_shape CHECK ((((realm)::text = 'org'::text) AND (contract_epoch >= 1))),
    CONSTRAINT chk_op_protocol_epochs_singleton CHECK ((id = 1))
);


--
-- Name: op_protocol_epochs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.op_protocol_epochs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: op_protocol_epochs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.op_protocol_epochs_id_seq OWNED BY public.op_protocol_epochs.id;


--
-- Name: operator_auth_admission_bindings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_auth_admission_bindings (
    id bigint NOT NULL,
    entry_ref uuid NOT NULL,
    purpose character varying NOT NULL,
    sign_in_flow_id bigint,
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
    CONSTRAINT operator_admission_bindings_auth_proof_pair CHECK ((((auth_ceremony_session_id IS NULL) AND (confirmation_ref IS NULL)) OR ((auth_ceremony_session_id IS NOT NULL) AND (confirmation_ref IS NOT NULL)))),
    CONSTRAINT operator_admission_bindings_confirmation_requires_auth CHECK (((base_confirmed_at IS NULL) OR ((auth_ceremony_session_id IS NOT NULL) AND (confirmation_ref IS NOT NULL)))),
    CONSTRAINT operator_admission_bindings_one_parent CHECK ((num_nonnulls(sign_in_flow_id, authorization_transaction_id, step_up_ceremony_transaction_id) = 1)),
    CONSTRAINT operator_admission_bindings_parent_purpose CHECK ((((sign_in_flow_id IS NULL) OR ((purpose)::text = ANY ((ARRAY['local_sign_in'::character varying, 'local_sign_up'::character varying])::text[]))) AND ((authorization_transaction_id IS NULL) OR ((purpose)::text = ANY ((ARRAY['authentication_handoff'::character varying, 'invitation_handoff'::character varying])::text[]))) AND ((step_up_ceremony_transaction_id IS NULL) OR ((purpose)::text = ANY ((ARRAY['step_up_handoff'::character varying, 'reauthentication_handoff'::character varying, 'bootstrap_handoff'::character varying, 'credential_registration_handoff'::character varying, 'credential_change_handoff'::character varying])::text[]))))),
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
    local_sign_in_flow_ref character varying,
    local_sign_up_flow_ref character varying,
    admission_purpose character varying,
    step_up_ceremony_transaction_ref character varying,
    CONSTRAINT operator_auth_admission_purpose_valid CHECK (((admission_purpose IS NULL) OR ((admission_purpose)::text = ANY ((ARRAY['local_sign_in'::character varying, 'local_sign_up'::character varying, 'authentication_handoff'::character varying, 'invitation_handoff'::character varying, 'step_up_handoff'::character varying, 'reauthentication_handoff'::character varying, 'bootstrap_handoff'::character varying, 'credential_registration_handoff'::character varying, 'credential_change_handoff'::character varying])::text[])))),
    CONSTRAINT operator_auth_ceremony_purpose_exclusive CHECK ((num_nonnulls(authorization_transaction_ref, local_sign_in_flow_ref, local_sign_up_flow_ref) <= 1)),
    CONSTRAINT operator_auth_ceremony_sessions_admission_binding CHECK (((authorization_transaction_ref IS NULL) OR (admitted_at IS NOT NULL))),
    CONSTRAINT operator_auth_ceremony_sessions_authentication_evidence_pair CHECK (((authentication_method IS NULL) = (authentication_event_at IS NULL))),
    CONSTRAINT operator_auth_ceremony_sessions_authentication_method CHECK (((authentication_method IS NULL) OR ((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'totp'::character varying, 'google'::character varying, 'apple'::character varying, 'entra'::character varying])::text[])))),
    CONSTRAINT operator_auth_ceremony_sessions_one_terminal_timestamp CHECK ((num_nonnulls(revoked_at, completed_at, cancelled_at) <= 1)),
    CONSTRAINT operator_auth_ceremony_transaction_exclusive CHECK ((num_nonnulls(authorization_transaction_ref, local_sign_in_flow_ref, local_sign_up_flow_ref, step_up_ceremony_transaction_ref) <= 1))
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
    last_network_hmac character varying
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
    status character varying NOT NULL,
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
    contract_epoch bigint,
    CONSTRAINT chk_operator_oidc_authorization_transactions_contract_epoch CHECK (((contract_epoch IS NULL) OR (contract_epoch >= 1))),
    CONSTRAINT operator_oidc_auth_transactions_result_generation_nonnegative CHECK ((result_generation >= 0))
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
    updated_at timestamp(6) with time zone CONSTRAINT staff_oidc_connections_updated_at_not_null NOT NULL
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
    updated_at timestamp(6) with time zone NOT NULL
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
-- Name: operator_sign_out_flow_kinds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_sign_out_flow_kinds (
    id bigint CONSTRAINT operator_sign_out_cycle_kinds_id_not_null NOT NULL
);


--
-- Name: operator_sign_out_flow_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_sign_out_flow_kinds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_sign_out_flow_kinds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_sign_out_flow_kinds_id_seq OWNED BY public.operator_sign_out_flow_kinds.id;


--
-- Name: operator_sign_out_flow_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_sign_out_flow_statuses (
    id bigint CONSTRAINT operator_sign_out_cycle_statuses_id_not_null NOT NULL
);


--
-- Name: operator_sign_out_flow_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_sign_out_flow_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_sign_out_flow_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_sign_out_flow_statuses_id_seq OWNED BY public.operator_sign_out_flow_statuses.id;


--
-- Name: operator_sign_out_flows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_sign_out_flows (
    id bigint CONSTRAINT operator_sign_out_cycles_id_not_null NOT NULL,
    public_id character varying(21) CONSTRAINT operator_sign_out_cycles_public_id_not_null NOT NULL,
    principal_id bigint,
    token_id bigint,
    status_id bigint DEFAULT 10 CONSTRAINT operator_sign_out_cycles_status_id_not_null NOT NULL,
    kind_id bigint DEFAULT 0 CONSTRAINT operator_sign_out_cycles_kind_id_not_null NOT NULL,
    refresh_token_family_id character varying,
    requested_at timestamp(6) with time zone CONSTRAINT operator_sign_out_cycles_requested_at_not_null NOT NULL,
    access_discarded_at timestamp(6) with time zone,
    logically_revoked_at timestamp(6) with time zone,
    access_expires_at timestamp(6) with time zone CONSTRAINT operator_sign_out_cycles_access_expires_at_not_null NOT NULL,
    refresh_expires_at timestamp(6) with time zone CONSTRAINT operator_sign_out_cycles_refresh_expires_at_not_null NOT NULL,
    completed_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    return_to text,
    nonce_digest character varying,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT operator_sign_out_cycles_discarded_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT operator_sign_out_cycles_purged_at_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT operator_sign_out_cycles_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT operator_sign_out_cycles_updated_at_not_null NOT NULL,
    CONSTRAINT chk_operator_sign_out_cycles_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT chk_operator_sign_out_cycles_token_expiry_order CHECK ((access_expires_at <= refresh_expires_at))
);


--
-- Name: operator_sign_out_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_sign_out_flows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_sign_out_flows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_sign_out_flows_id_seq OWNED BY public.operator_sign_out_flows.id;


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
    audience character varying,
    token_binding character varying,
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
    contract_epoch bigint,
    authentication_epoch bigint,
    CONSTRAINT chk_operator_tokens_authentication_context CHECK (((authentication_context IS NULL) OR ((authentication_context)::text = ANY ((ARRAY['normal'::character varying, 'standby'::character varying])::text[])))),
    CONSTRAINT chk_operator_tokens_authentication_epoch CHECK (((authentication_epoch IS NULL) OR (authentication_epoch >= 0))),
    CONSTRAINT chk_operator_tokens_contract_epoch CHECK (((contract_epoch IS NULL) OR (contract_epoch >= 1))),
    CONSTRAINT chk_operator_tokens_established_authentication_method CHECK (((established_authentication_method IS NULL) OR ((established_authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'entra'::character varying])::text[])))),
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
-- Name: logout_flow_participants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.logout_flow_participants ALTER COLUMN id SET DEFAULT nextval('public.logout_flow_participants_id_seq'::regclass);


--
-- Name: logout_flows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.logout_flows ALTER COLUMN id SET DEFAULT nextval('public.logout_flows_id_seq'::regclass);


--
-- Name: logout_receipts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.logout_receipts ALTER COLUMN id SET DEFAULT nextval('public.logout_receipts_id_seq'::regclass);


--
-- Name: op_client_activations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_client_activations ALTER COLUMN id SET DEFAULT nextval('public.op_client_activations_id_seq'::regclass);


--
-- Name: op_consumed_jtis id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_consumed_jtis ALTER COLUMN id SET DEFAULT nextval('public.op_consumed_jtis_id_seq'::regclass);


--
-- Name: op_inbound_event_receipts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_inbound_event_receipts ALTER COLUMN id SET DEFAULT nextval('public.op_inbound_event_receipts_id_seq'::regclass);


--
-- Name: op_org_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_grants ALTER COLUMN id SET DEFAULT nextval('public.op_org_grants_id_seq'::regclass);


--
-- Name: op_outbox_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_outbox_events ALTER COLUMN id SET DEFAULT nextval('public.op_outbox_events_id_seq'::regclass);


--
-- Name: op_protocol_epochs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_protocol_epochs ALTER COLUMN id SET DEFAULT nextval('public.op_protocol_epochs_id_seq'::regclass);


--
-- Name: operator_auth_admission_bindings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_admission_bindings ALTER COLUMN id SET DEFAULT nextval('public.operator_auth_admission_bindings_id_seq'::regclass);


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
-- Name: operator_sign_out_flow_kinds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_out_flow_kinds ALTER COLUMN id SET DEFAULT nextval('public.operator_sign_out_flow_kinds_id_seq'::regclass);


--
-- Name: operator_sign_out_flow_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_out_flow_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_sign_out_flow_statuses_id_seq'::regclass);


--
-- Name: operator_sign_out_flows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_out_flows ALTER COLUMN id SET DEFAULT nextval('public.operator_sign_out_flows_id_seq'::regclass);


--
-- Name: operator_sign_up_flow_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_up_flow_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_sign_up_flow_statuses_id_seq'::regclass);


--
-- Name: operator_sign_up_flows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_up_flows ALTER COLUMN id SET DEFAULT nextval('public.operator_sign_up_flows_id_seq'::regclass);


--
-- Name: operator_step_up_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.operator_step_up_ceremony_transactions_id_seq'::regclass);


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
-- Name: logout_flow_participants logout_flow_participants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.logout_flow_participants
    ADD CONSTRAINT logout_flow_participants_pkey PRIMARY KEY (id);


--
-- Name: logout_flows logout_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.logout_flows
    ADD CONSTRAINT logout_flows_pkey PRIMARY KEY (id);


--
-- Name: logout_receipts logout_receipts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.logout_receipts
    ADD CONSTRAINT logout_receipts_pkey PRIMARY KEY (id);


--
-- Name: op_client_activations op_client_activations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_client_activations
    ADD CONSTRAINT op_client_activations_pkey PRIMARY KEY (id);


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
-- Name: op_org_grants op_org_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_org_grants
    ADD CONSTRAINT op_org_grants_pkey PRIMARY KEY (id);


--
-- Name: op_outbox_events op_outbox_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_outbox_events
    ADD CONSTRAINT op_outbox_events_pkey PRIMARY KEY (id);


--
-- Name: op_protocol_epochs op_protocol_epochs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_protocol_epochs
    ADD CONSTRAINT op_protocol_epochs_pkey PRIMARY KEY (id);


--
-- Name: operator_auth_admission_bindings operator_auth_admission_bindings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_admission_bindings
    ADD CONSTRAINT operator_auth_admission_bindings_pkey PRIMARY KEY (id);


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
-- Name: operator_sign_out_flow_kinds operator_sign_out_flow_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_out_flow_kinds
    ADD CONSTRAINT operator_sign_out_flow_kinds_pkey PRIMARY KEY (id);


--
-- Name: operator_sign_out_flow_statuses operator_sign_out_flow_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_out_flow_statuses
    ADD CONSTRAINT operator_sign_out_flow_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_sign_out_flows operator_sign_out_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_out_flows
    ADD CONSTRAINT operator_sign_out_flows_pkey PRIMARY KEY (id);


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
-- Name: operator_step_up_ceremony_transactions operator_step_up_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_ceremony_transactions
    ADD CONSTRAINT operator_step_up_ceremony_transactions_pkey PRIMARY KEY (id);


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
-- Name: idx_auth_ceremony_sessions_on_tx_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_auth_ceremony_sessions_on_tx_ref ON public.operator_auth_ceremony_sessions USING btree (authorization_transaction_ref) WHERE (authorization_transaction_ref IS NOT NULL);


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
-- Name: idx_on_cancellation_handoff_digest_dc759b9c45; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_cancellation_handoff_digest_dc759b9c45 ON public.operator_step_up_ceremony_transactions USING btree (cancellation_handoff_digest);


--
-- Name: idx_on_cancellation_handoff_ref_92180f8825; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_cancellation_handoff_ref_92180f8825 ON public.operator_step_up_ceremony_transactions USING btree (cancellation_handoff_ref);


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
-- Name: idx_on_result_jti_6830d7796f; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_result_jti_6830d7796f ON public.operator_secret_credential_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


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
-- Name: idx_op_org_client_activations_client_epoch; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_org_client_activations_client_epoch ON public.op_client_activations USING btree (client_id, contract_epoch);


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
-- Name: idx_op_org_logout_flows_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_org_logout_flows_idempotency ON public.logout_flows USING btree (realm, idempotency_digest);


--
-- Name: idx_op_org_logout_flows_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_org_logout_flows_public_id ON public.logout_flows USING btree (public_id);


--
-- Name: idx_op_org_logout_participants_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_org_logout_participants_identity ON public.logout_flow_participants USING btree (logout_flow_id, issuer, realm, client_id, sid);


--
-- Name: idx_op_org_logout_receipts_nonce; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_org_logout_receipts_nonce ON public.logout_receipts USING btree (logout_flow_id, nonce_digest);


--
-- Name: idx_op_org_logout_receipts_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_org_logout_receipts_public_id ON public.logout_receipts USING btree (public_id);


--
-- Name: idx_op_org_outbox_events_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_org_outbox_events_event_id ON public.op_outbox_events USING btree (event_id);


--
-- Name: idx_op_org_outbox_events_next_attempt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_op_org_outbox_events_next_attempt ON public.op_outbox_events USING btree (next_attempt_at);


--
-- Name: idx_op_protocol_epochs_realm; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_protocol_epochs_realm ON public.op_protocol_epochs USING btree (realm);


--
-- Name: idx_operator_admission_bindings_auth_session; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operator_admission_bindings_auth_session ON public.operator_auth_admission_bindings USING btree (auth_ceremony_session_id) WHERE (auth_ceremony_session_id IS NOT NULL);


--
-- Name: idx_operator_admission_bindings_live_oidc; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_admission_bindings_live_oidc ON public.operator_auth_admission_bindings USING btree (authorization_transaction_id) WHERE ((authorization_transaction_id IS NOT NULL) AND (retired_at IS NULL) AND (redeemed_at IS NULL));


--
-- Name: idx_operator_admission_bindings_live_sign_in; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_admission_bindings_live_sign_in ON public.operator_auth_admission_bindings USING btree (sign_in_flow_id) WHERE ((sign_in_flow_id IS NOT NULL) AND (retired_at IS NULL) AND (redeemed_at IS NULL));


--
-- Name: idx_operator_admission_bindings_live_step_up; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_admission_bindings_live_step_up ON public.operator_auth_admission_bindings USING btree (step_up_ceremony_transaction_id) WHERE ((step_up_ceremony_transaction_id IS NOT NULL) AND (retired_at IS NULL) AND (redeemed_at IS NULL));


--
-- Name: idx_operator_resolution_open_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_resolution_open_parent ON public.operator_session_limit_resolution_transactions USING btree (sign_in_flow_id) WHERE (state_id = ANY (ARRAY[(10)::bigint, (20)::bigint]));


--
-- Name: idx_operator_resolution_waiting_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_resolution_waiting_actor ON public.operator_session_limit_resolution_transactions USING btree (actor_ref) WHERE (waiting_slot = 1);


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
-- Name: index_operator_device_sessions_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_device_sessions_on_staff_id ON public.operator_device_sessions USING btree (staff_id);


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
-- Name: index_operator_sign_out_flows_on_access_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_out_flows_on_access_expires_at ON public.operator_sign_out_flows USING btree (access_expires_at);


--
-- Name: index_operator_sign_out_flows_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_out_flows_on_discard_at ON public.operator_sign_out_flows USING btree (discard_at);


--
-- Name: index_operator_sign_out_flows_on_kind_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_out_flows_on_kind_id ON public.operator_sign_out_flows USING btree (kind_id);


--
-- Name: index_operator_sign_out_flows_on_principal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_out_flows_on_principal_id ON public.operator_sign_out_flows USING btree (principal_id);


--
-- Name: index_operator_sign_out_flows_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_sign_out_flows_on_public_id ON public.operator_sign_out_flows USING btree (public_id);


--
-- Name: index_operator_sign_out_flows_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_out_flows_on_purge_eligible_at ON public.operator_sign_out_flows USING btree (purge_eligible_at);


--
-- Name: index_operator_sign_out_flows_on_refresh_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_out_flows_on_refresh_expires_at ON public.operator_sign_out_flows USING btree (refresh_expires_at);


--
-- Name: index_operator_sign_out_flows_on_refresh_token_family_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_out_flows_on_refresh_token_family_id ON public.operator_sign_out_flows USING btree (refresh_token_family_id);


--
-- Name: index_operator_sign_out_flows_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_out_flows_on_status_id ON public.operator_sign_out_flows USING btree (status_id);


--
-- Name: index_operator_sign_out_flows_on_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_out_flows_on_token_id ON public.operator_sign_out_flows USING btree (token_id);


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
-- Name: operator_auth_admission_bindings fk_operator_auth_admission_bindings_admitted_session; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_admission_bindings
    ADD CONSTRAINT fk_operator_auth_admission_bindings_admitted_session FOREIGN KEY (admitted_auth_ceremony_session_id) REFERENCES public.operator_auth_ceremony_sessions(id) ON DELETE RESTRICT;


--
-- Name: operator_device_sessions fk_operator_device_sessions_on_current_refresh_token_owner; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_device_sessions
    ADD CONSTRAINT fk_operator_device_sessions_on_current_refresh_token_owner FOREIGN KEY (id, current_refresh_token_id) REFERENCES public.operator_tokens(device_session_id, id) ON DELETE SET NULL (current_refresh_token_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: operator_tokens fk_operator_tokens_on_device_session_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT fk_operator_tokens_on_device_session_id FOREIGN KEY (device_session_id) REFERENCES public.operator_device_sessions(id) ON DELETE RESTRICT;


--
-- Name: operator_tokens fk_operator_tokens_on_staff_id_and_device_session_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT fk_operator_tokens_on_staff_id_and_device_session_id FOREIGN KEY (staff_id, device_session_id) REFERENCES public.operator_device_sessions(staff_id, id) ON DELETE RESTRICT;


--
-- Name: operator_sign_in_flows fk_rails_0451f7d1d6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_in_flows
    ADD CONSTRAINT fk_rails_0451f7d1d6 FOREIGN KEY (token_id) REFERENCES public.operator_tokens(id) ON DELETE CASCADE;


--
-- Name: operator_sign_out_flows fk_rails_0467d6b6d1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_out_flows
    ADD CONSTRAINT fk_rails_0467d6b6d1 FOREIGN KEY (kind_id) REFERENCES public.operator_sign_out_flow_kinds(id);


--
-- Name: operator_step_up_sessions fk_rails_100937c5e6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_sessions
    ADD CONSTRAINT fk_rails_100937c5e6 FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.operator_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;


--
-- Name: operator_sign_up_flows fk_rails_10f95a7068; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_up_flows
    ADD CONSTRAINT fk_rails_10f95a7068 FOREIGN KEY (token_id) REFERENCES public.operator_tokens(id) ON DELETE CASCADE;


--
-- Name: operator_tokens fk_rails_1a807f181b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT fk_rails_1a807f181b FOREIGN KEY (staff_token_status_id) REFERENCES public.operator_token_statuses(id) ON DELETE RESTRICT;


--
-- Name: logout_flow_participants fk_rails_1b37d291d0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.logout_flow_participants
    ADD CONSTRAINT fk_rails_1b37d291d0 FOREIGN KEY (logout_flow_id) REFERENCES public.logout_flows(id);


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
-- Name: operator_auth_ceremony_sessions fk_rails_5ea4994c1a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_ceremony_sessions
    ADD CONSTRAINT fk_rails_5ea4994c1a FOREIGN KEY (local_sign_up_flow_ref) REFERENCES public.operator_sign_up_flows(public_id) ON DELETE RESTRICT;


--
-- Name: operator_step_up_sessions fk_rails_6daa6fb880; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_sessions
    ADD CONSTRAINT fk_rails_6daa6fb880 FOREIGN KEY (staff_token_id) REFERENCES public.operator_tokens(id) ON DELETE CASCADE;


--
-- Name: operator_auth_admission_bindings fk_rails_781188228f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_admission_bindings
    ADD CONSTRAINT fk_rails_781188228f FOREIGN KEY (auth_ceremony_session_id) REFERENCES public.operator_auth_ceremony_sessions(id) ON DELETE RESTRICT;


--
-- Name: operator_sign_out_flows fk_rails_85024a94ea; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_out_flows
    ADD CONSTRAINT fk_rails_85024a94ea FOREIGN KEY (status_id) REFERENCES public.operator_sign_out_flow_statuses(id);


--
-- Name: logout_receipts fk_rails_854223f724; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.logout_receipts
    ADD CONSTRAINT fk_rails_854223f724 FOREIGN KEY (logout_flow_id) REFERENCES public.logout_flows(id);


--
-- Name: op_outbox_events fk_rails_8d56cd14a9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_outbox_events
    ADD CONSTRAINT fk_rails_8d56cd14a9 FOREIGN KEY (logout_flow_participant_id) REFERENCES public.logout_flow_participants(id);


--
-- Name: operator_passkey_ceremony_candidates fk_rails_9740344565; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkey_ceremony_candidates
    ADD CONSTRAINT fk_rails_9740344565 FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.operator_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;


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
-- Name: operator_auth_admission_bindings fk_rails_afcf0bd184; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_admission_bindings
    ADD CONSTRAINT fk_rails_afcf0bd184 FOREIGN KEY (sign_in_flow_id) REFERENCES public.operator_sign_in_flows(id) ON DELETE RESTRICT;


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
    ADD CONSTRAINT fk_rails_c8ab8d08df FOREIGN KEY (staff_token_id) REFERENCES public.operator_tokens(id) ON DELETE CASCADE;


--
-- Name: operator_sign_out_flows fk_rails_caa3cf1c6d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_out_flows
    ADD CONSTRAINT fk_rails_caa3cf1c6d FOREIGN KEY (token_id) REFERENCES public.operator_tokens(id) ON DELETE CASCADE;


--
-- Name: operator_sign_in_flows fk_rails_e665ad2a06; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_in_flows
    ADD CONSTRAINT fk_rails_e665ad2a06 FOREIGN KEY (state_id) REFERENCES public.operator_sign_in_flow_states(id) ON DELETE RESTRICT;


--
-- Name: operator_auth_ceremony_sessions fk_rails_ed41a3bf04; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_auth_ceremony_sessions
    ADD CONSTRAINT fk_rails_ed41a3bf04 FOREIGN KEY (local_sign_in_flow_ref) REFERENCES public.operator_sign_in_flows(public_id) ON DELETE RESTRICT;


--
-- Name: operator_tokens fk_rails_f211b6bc2e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT fk_rails_f211b6bc2e FOREIGN KEY (staff_token_kind_id) REFERENCES public.operator_token_kinds(id) ON DELETE RESTRICT;


--
-- Name: operator_sign_up_flows fk_rails_fb3acc316b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_up_flows
    ADD CONSTRAINT fk_rails_fb3acc316b FOREIGN KEY (status_id) REFERENCES public.operator_sign_up_flow_statuses(id);


--
-- Name: operator_tokens fk_staff_tokens_on_staff_token_binding_method_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT fk_staff_tokens_on_staff_token_binding_method_id FOREIGN KEY (staff_token_binding_method_id) REFERENCES public.operator_token_binding_methods(id);


--
-- Name: operator_tokens fk_staff_tokens_on_staff_token_dbsc_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT fk_staff_tokens_on_staff_token_dbsc_status_id FOREIGN KEY (staff_token_dbsc_status_id) REFERENCES public.operator_token_dbsc_statuses(id);


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

