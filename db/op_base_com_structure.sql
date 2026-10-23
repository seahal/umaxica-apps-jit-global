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
-- Name: enforce_visitor_auth_email_otp_proof(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_visitor_auth_email_otp_proof() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF OLD.email_otp_context->>'verified_at' IS NOT NULL AND NEW.email_otp_context IS DISTINCT FROM OLD.email_otp_context THEN RAISE EXCEPTION 'committed email OTP proof is immutable'; END IF; RETURN NEW; END; $$;


--
-- Name: enforce_visitor_email_terminal_otp_facts(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_visitor_email_terminal_otp_facts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF (OLD.otp_consumed_at IS NOT NULL OR OLD.otp_cancelled_at IS NOT NULL) AND ROW(NEW.purpose, NEW.otp_generation, NEW.otp_verifier, NEW.otp_expires_at, NEW.otp_consumed_at, NEW.otp_cancelled_at, NEW.otp_receipt_verifier, NEW.otp_result_expires_at, NEW.surface, NEW.transaction_id, NEW.actor_ref, NEW.session_ref, NEW.operation, NEW.expires_at, NEW.email_candidate_ref, NEW.normalized_email_digest, NEW.bootstrap_ceremony_transaction_ref) IS DISTINCT FROM ROW(OLD.purpose, OLD.otp_generation, OLD.otp_verifier, OLD.otp_expires_at, OLD.otp_consumed_at, OLD.otp_cancelled_at, OLD.otp_receipt_verifier, OLD.otp_result_expires_at, OLD.surface, OLD.transaction_id, OLD.actor_ref, OLD.session_ref, OLD.operation, OLD.expires_at, OLD.email_candidate_ref, OLD.normalized_email_digest, OLD.bootstrap_ceremony_transaction_ref) THEN RAISE EXCEPTION 'terminal OTP facts are immutable'; END IF; RETURN NEW; END; $$;


--
-- Name: enforce_visitor_telephone_terminal_otp_facts(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_visitor_telephone_terminal_otp_facts() RETURNS trigger
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
-- Name: visitor_verifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_verifications (
    id bigint CONSTRAINT customer_verifications_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT customer_verifications_created_at_not_null NOT NULL,
    visitor_token_id bigint CONSTRAINT customer_verifications_customer_token_id_not_null NOT NULL,
    last_used_at timestamp(6) with time zone,
    token_digest character varying CONSTRAINT customer_verifications_token_digest_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT customer_verifications_updated_at_not_null NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT customer_verifications_discarded_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT customer_verifications_purged_at_not_null NOT NULL,
    CONSTRAINT chk_customer_verifications_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: customer_verifications_customer_token_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.customer_verifications_customer_token_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: customer_verifications_customer_token_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.customer_verifications_customer_token_id_seq OWNED BY public.visitor_verifications.visitor_token_id;


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
    CONSTRAINT chk_op_com_logout_participants_shape CHECK ((((realm)::text = 'com'::text) AND (delivery_attempts >= 0)))
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
    CONSTRAINT chk_op_com_logout_flows_realm CHECK (((realm)::text = 'com'::text))
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
-- Name: op_com_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.op_com_grants (
    id bigint NOT NULL,
    visitor_token_id bigint NOT NULL,
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
    authentication_epoch bigint NOT NULL,
    CONSTRAINT chk_op_com_grants_authentication_epoch CHECK ((authentication_epoch >= 0)),
    CONSTRAINT chk_op_com_grants_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_op_com_grants_refresh_delivery_all_or_none CHECK ((((refresh_delivery_ciphertext IS NULL) AND (refresh_delivery_predecessor_digest IS NULL) AND (refresh_delivery_expires_at IS NULL)) OR ((refresh_delivery_ciphertext IS NOT NULL) AND (refresh_delivery_predecessor_digest IS NOT NULL) AND (refresh_delivery_expires_at IS NOT NULL))))
);


--
-- Name: op_com_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.op_com_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: op_com_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.op_com_grants_id_seq OWNED BY public.op_com_grants.id;


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
    CONSTRAINT chk_op_com_consumed_jtis_realm CHECK (((realm)::text = 'com'::text))
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
    CONSTRAINT chk_op_com_inbound_event_receipts_realm CHECK (((realm)::text = 'com'::text))
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
    CONSTRAINT chk_op_com_outbox_events_shape CHECK ((((target_realm)::text = 'com'::text) AND (delivery_attempts >= 0)))
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
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: visitor_auth_admission_bindings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_auth_admission_bindings (
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
    CONSTRAINT visitor_admission_binding_entry_intent CHECK (((((purpose)::text = ANY ((ARRAY['authentication_handoff'::character varying, 'invitation_handoff'::character varying])::text[])) AND ((entry_intent)::text = ANY ((ARRAY['sign_in'::character varying, 'sign_up'::character varying])::text[]))) OR (((purpose)::text = ANY ((ARRAY['step_up_handoff'::character varying, 'reauthentication_handoff'::character varying, 'bootstrap_handoff'::character varying, 'credential_registration_handoff'::character varying, 'credential_change_handoff'::character varying])::text[])) AND ((entry_intent)::text = 'not_applicable'::text)))),
    CONSTRAINT visitor_admission_bindings_auth_proof_pair CHECK ((((auth_ceremony_session_id IS NULL) AND (confirmation_ref IS NULL)) OR ((auth_ceremony_session_id IS NOT NULL) AND (confirmation_ref IS NOT NULL)))),
    CONSTRAINT visitor_admission_bindings_confirmation_requires_auth CHECK (((base_confirmed_at IS NULL) OR ((auth_ceremony_session_id IS NOT NULL) AND (confirmation_ref IS NOT NULL)))),
    CONSTRAINT visitor_admission_bindings_one_parent CHECK ((num_nonnulls(authorization_transaction_id, step_up_ceremony_transaction_id) = 1)),
    CONSTRAINT visitor_admission_bindings_parent_purpose CHECK ((((authorization_transaction_id IS NULL) OR ((purpose)::text = ANY (ARRAY[('authentication_handoff'::character varying)::text, ('invitation_handoff'::character varying)::text]))) AND ((step_up_ceremony_transaction_id IS NULL) OR ((purpose)::text = ANY (ARRAY[('step_up_handoff'::character varying)::text, ('reauthentication_handoff'::character varying)::text, ('bootstrap_handoff'::character varying)::text, ('credential_registration_handoff'::character varying)::text, ('credential_change_handoff'::character varying)::text]))))),
    CONSTRAINT visitor_admission_bindings_redemption_pair CHECK ((((redeemed_at IS NULL) AND (admitted_auth_ceremony_session_id IS NULL)) OR ((redeemed_at IS NOT NULL) AND (admitted_auth_ceremony_session_id IS NOT NULL)))),
    CONSTRAINT visitor_admission_bindings_redemption_requires_confirmation CHECK (((redeemed_at IS NULL) OR (base_confirmed_at IS NOT NULL))),
    CONSTRAINT visitor_admission_bindings_step_up_token CHECK ((((purpose)::text <> ALL (ARRAY[('step_up_handoff'::character varying)::text, ('reauthentication_handoff'::character varying)::text, ('bootstrap_handoff'::character varying)::text, ('credential_registration_handoff'::character varying)::text, ('credential_change_handoff'::character varying)::text])) OR (base_token_id IS NOT NULL))),
    CONSTRAINT visitor_admission_bindings_terminal_exclusive CHECK ((NOT ((redeemed_at IS NOT NULL) AND (retired_at IS NOT NULL))))
);


--
-- Name: visitor_auth_admission_bindings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_auth_admission_bindings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_auth_admission_bindings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_auth_admission_bindings_id_seq OWNED BY public.visitor_auth_admission_bindings.id;


--
-- Name: visitor_auth_ceremony_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_auth_ceremony_sessions (
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
    email_otp_context jsonb,
    CONSTRAINT visitor_auth_admission_purpose_valid CHECK (((admission_purpose IS NULL) OR ((admission_purpose)::text = ANY (ARRAY[('authentication_handoff'::character varying)::text, ('invitation_handoff'::character varying)::text, ('step_up_handoff'::character varying)::text, ('reauthentication_handoff'::character varying)::text, ('bootstrap_handoff'::character varying)::text, ('credential_registration_handoff'::character varying)::text, ('credential_change_handoff'::character varying)::text])))),
    CONSTRAINT visitor_auth_ceremony_sessions_admission_binding CHECK (((authorization_transaction_ref IS NULL) OR (admitted_at IS NOT NULL))),
    CONSTRAINT visitor_auth_ceremony_sessions_authentication_evidence_pair CHECK (((authentication_method IS NULL) = (authentication_event_at IS NULL))),
    CONSTRAINT visitor_auth_ceremony_sessions_authentication_method CHECK (((authentication_method IS NULL) OR ((authentication_method)::text = ANY (ARRAY[('email'::character varying)::text, ('telephone'::character varying)::text, ('secret'::character varying)::text, ('passkey'::character varying)::text, ('totp'::character varying)::text, ('google'::character varying)::text, ('apple'::character varying)::text, ('entra'::character varying)::text])))),
    CONSTRAINT visitor_auth_ceremony_sessions_one_terminal_timestamp CHECK ((num_nonnulls(revoked_at, completed_at, cancelled_at) <= 1)),
    CONSTRAINT visitor_auth_ceremony_transaction_exclusive CHECK ((num_nonnulls(authorization_transaction_ref, step_up_ceremony_transaction_ref) <= 1)),
    CONSTRAINT visitor_auth_email_otp_context_shape CHECK (((email_otp_context IS NULL) OR (((jsonb_typeof(email_otp_context) = 'object'::text) AND (email_otp_context ?& ARRAY['version'::text, 'generation'::text, 'surface'::text, 'purpose'::text, 'sid_digest'::text, 'parent_kind'::text, 'parent_ref'::text, 'mode'::text, 'contact_ref'::text, 'owner_ref'::text, 'destination_digest'::text, 'binding_fact'::text, 'code_digest'::text, 'issued_at'::text, 'expires_at'::text, 'verified_at'::text, 'result_expires_at'::text]) AND ((email_otp_context -> 'version'::text) = '1'::jsonb) AND ((email_otp_context ->> 'generation'::text) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'::text) AND ((email_otp_context ->> 'mode'::text) = ANY (ARRAY['real'::text, 'fake'::text])) AND ((email_otp_context ->> 'code_digest'::text) ~ '^[0-9a-f]{64}$'::text) AND (jsonb_typeof((email_otp_context -> 'issued_at'::text)) = 'string'::text) AND (jsonb_typeof((email_otp_context -> 'expires_at'::text)) = 'string'::text) AND ((((email_otp_context -> 'verified_at'::text) = 'null'::jsonb) AND ((email_otp_context -> 'result_expires_at'::text) = 'null'::jsonb)) OR ((jsonb_typeof((email_otp_context -> 'verified_at'::text)) = 'string'::text) AND (jsonb_typeof((email_otp_context -> 'result_expires_at'::text)) = 'string'::text)))) IS TRUE)))
);


--
-- Name: visitor_auth_ceremony_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_auth_ceremony_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_auth_ceremony_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_auth_ceremony_sessions_id_seq OWNED BY public.visitor_auth_ceremony_sessions.id;


--
-- Name: visitor_device_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_device_sessions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    visitor_id bigint NOT NULL,
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
    CONSTRAINT chk_visitor_device_sessions_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: visitor_device_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_device_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_device_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_device_sessions_id_seq OWNED BY public.visitor_device_sessions.id;


--
-- Name: visitor_dpop_proof_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_dpop_proof_states (
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
-- Name: visitor_dpop_proof_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_dpop_proof_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_dpop_proof_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_dpop_proof_states_id_seq OWNED BY public.visitor_dpop_proof_states.id;


--
-- Name: visitor_email_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_email_ceremony_transactions (
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
    CONSTRAINT visitor_email_ceremony_transactions_otp_material CHECK (((otp_verifier IS NULL) OR ((purpose IS NOT NULL) AND (otp_generation IS NOT NULL) AND (otp_expires_at IS NOT NULL)))),
    CONSTRAINT visitor_email_ceremony_transactions_otp_purpose CHECK (((purpose IS NULL) OR ((purpose)::text = ANY (ARRAY[('sign_up'::character varying)::text, ('sign_in'::character varying)::text, ('recovery'::character varying)::text, ('withdrawal'::character varying)::text, ('credential_registration'::character varying)::text])))),
    CONSTRAINT visitor_email_otp_bootstrap_purpose CHECK (((bootstrap_ceremony_transaction_ref IS NULL) OR (((operation)::text = 'registration'::text) AND (purpose IS NOT NULL) AND ((purpose)::text = 'credential_registration'::text)))),
    CONSTRAINT visitor_email_otp_proof_shape CHECK (((otp_generation IS NULL) OR (((purpose IS NOT NULL) AND ((actor_ref)::text <> ''::text) AND ((session_ref)::text <> ''::text) AND (email_candidate_ref IS NOT NULL) AND ((email_candidate_ref)::text <> ''::text) AND ((normalized_email_digest IS NULL) OR ((normalized_email_digest)::text ~ '^[0-9a-f]{64}$'::text)) AND (otp_expires_at IS NOT NULL) AND isfinite(otp_expires_at) AND isfinite(expires_at) AND (((otp_consumed_at IS NULL) AND (otp_cancelled_at IS NULL) AND (otp_verifier IS NOT NULL) AND ((otp_verifier)::text ~ '^[0-9a-f]{64}$'::text) AND (otp_receipt_verifier IS NULL) AND (otp_result_expires_at IS NULL)) OR ((otp_consumed_at IS NOT NULL) AND isfinite(otp_consumed_at) AND (otp_consumed_at < otp_expires_at) AND (otp_cancelled_at IS NULL) AND (otp_verifier IS NULL) AND (otp_receipt_verifier IS NOT NULL) AND (otp_result_expires_at IS NOT NULL)) OR ((otp_cancelled_at IS NOT NULL) AND isfinite(otp_cancelled_at) AND (otp_consumed_at IS NULL) AND (otp_verifier IS NULL) AND (otp_receipt_verifier IS NULL) AND (otp_result_expires_at IS NULL)))) IS TRUE))),
    CONSTRAINT visitor_email_otp_receipt_bounds CHECK ((((otp_receipt_verifier IS NULL) AND (otp_result_expires_at IS NULL)) OR ((otp_receipt_verifier IS NOT NULL) AND ((otp_receipt_verifier)::text ~ '^[0-9a-f]{64}$'::text) AND (otp_consumed_at IS NOT NULL) AND (otp_cancelled_at IS NULL) AND (otp_verifier IS NULL) AND (otp_result_expires_at IS NOT NULL) AND isfinite(otp_result_expires_at) AND (otp_result_expires_at > otp_consumed_at) AND (otp_result_expires_at <= (otp_consumed_at + '00:01:00'::interval)) AND (otp_result_expires_at <= expires_at))))
);


--
-- Name: visitor_email_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_email_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_email_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_email_ceremony_transactions_id_seq OWNED BY public.visitor_email_ceremony_transactions.id;


--
-- Name: visitor_oidc_authorization_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_oidc_authorization_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    intent character varying NOT NULL,
    client_id character varying NOT NULL,
    redirect_uri character varying NOT NULL,
    response_type character varying NOT NULL,
    scope character varying NOT NULL,
    state character varying NOT NULL,
    nonce character varying NOT NULL,
    code_challenge character varying NOT NULL,
    code_challenge_method character varying CONSTRAINT visitor_oidc_authorization_trans_code_challenge_method_not_null NOT NULL,
    login_challenge character varying CONSTRAINT visitor_oidc_authorization_transaction_login_challenge_not_null NOT NULL,
    login_challenge_expires_at timestamp(6) with time zone CONSTRAINT visitor_oidc_authorization__login_challenge_expires_at_not_null NOT NULL,
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
    result_generation integer DEFAULT 0 CONSTRAINT visitor_oidc_authorization_transacti_result_generation_not_null NOT NULL,
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
    CONSTRAINT chk_visitor_oidc_txns_max_age CHECK ((oidc_max_age >= 0)),
    CONSTRAINT visitor_oidc_auth_canceled_terminal CHECK (((canceled_at IS NULL) = ((status)::text <> 'canceled'::text))),
    CONSTRAINT visitor_oidc_auth_cancellation_handoff_pair CHECK ((((cancellation_handoff_ref IS NULL) AND (cancellation_handoff_ciphertext IS NULL)) OR ((cancellation_handoff_ref IS NOT NULL) AND (cancellation_handoff_ciphertext IS NOT NULL)))),
    CONSTRAINT visitor_oidc_auth_cancellation_handoff_valid CHECK (((cancellation_handoff_digest IS NULL) OR ((cancellation_handoff_digest)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT visitor_oidc_auth_transactions_result_generation_nonnegative CHECK ((result_generation >= 0))
);


--
-- Name: visitor_oidc_authorization_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_oidc_authorization_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_oidc_authorization_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_oidc_authorization_transactions_id_seq OWNED BY public.visitor_oidc_authorization_transactions.id;


--
-- Name: visitor_oidc_connections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_oidc_connections (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    visitor_id bigint NOT NULL,
    client_id character varying(64) NOT NULL,
    scope character varying,
    last_used_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_visitor_oidc_connections_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: visitor_oidc_connections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_oidc_connections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_oidc_connections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_oidc_connections_id_seq OWNED BY public.visitor_oidc_connections.id;


--
-- Name: visitor_passkey_ceremony_candidates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_passkey_ceremony_candidates (
    id bigint NOT NULL,
    ref character varying NOT NULL,
    digest character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    step_up_ceremony_transaction_ref character varying CONSTRAINT visitor_passkey_ceremony_ca_step_up_ceremony_transacti_not_null NOT NULL,
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
    CONSTRAINT chk_visitor_passkey_candidates_sign_count CHECK ((sign_count >= 0))
);


--
-- Name: visitor_passkey_ceremony_candidates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_passkey_ceremony_candidates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_passkey_ceremony_candidates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_passkey_ceremony_candidates_id_seq OWNED BY public.visitor_passkey_ceremony_candidates.id;


--
-- Name: visitor_passkey_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_passkey_ceremony_transactions (
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
-- Name: visitor_passkey_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_passkey_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_passkey_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_passkey_ceremony_transactions_id_seq OWNED BY public.visitor_passkey_ceremony_transactions.id;


--
-- Name: visitor_secret_credential_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_secret_credential_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying CONSTRAINT visitor_secret_credential_ceremony_tran_transaction_id_not_null NOT NULL,
    surface character varying CONSTRAINT visitor_secret_credential_ceremony_transaction_surface_not_null NOT NULL,
    actor_ref character varying CONSTRAINT visitor_secret_credential_ceremony_transacti_actor_ref_not_null NOT NULL,
    session_ref character varying CONSTRAINT visitor_secret_credential_ceremony_transac_session_ref_not_null NOT NULL,
    operation character varying CONSTRAINT visitor_secret_credential_ceremony_transacti_operation_not_null NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying CONSTRAINT visitor_secret_credential_ceremony_transacti_grant_jti_not_null NOT NULL,
    result_jti character varying,
    credential_candidate_ref character varying,
    credential_candidate_digest character varying,
    expires_at timestamp(6) with time zone CONSTRAINT visitor_secret_credential_ceremony_transact_expires_at_not_null NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 CONSTRAINT visitor_secret_credential_ceremony_transa_lock_version_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT visitor_secret_credential_ceremony_transact_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT visitor_secret_credential_ceremony_transact_updated_at_not_null NOT NULL
);


--
-- Name: visitor_secret_credential_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_secret_credential_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_secret_credential_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_secret_credential_ceremony_transactions_id_seq OWNED BY public.visitor_secret_credential_ceremony_transactions.id;


--
-- Name: visitor_session_limit_resolution_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_session_limit_resolution_states (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_session_limit_resolution_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_session_limit_resolution_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_session_limit_resolution_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_session_limit_resolution_states_id_seq OWNED BY public.visitor_session_limit_resolution_states.id;


--
-- Name: visitor_session_limit_resolution_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_session_limit_resolution_transactions (
    id bigint NOT NULL,
    challenge_digest character varying CONSTRAINT visitor_session_limit_resolution_tran_challenge_digest_not_null NOT NULL,
    state_id bigint NOT NULL,
    sign_in_flow_id bigint CONSTRAINT visitor_session_limit_resolution_trans_sign_in_flow_id_not_null NOT NULL,
    oidc_authorization_transaction_id bigint,
    actor_ref character varying CONSTRAINT visitor_session_limit_resolution_transaction_actor_ref_not_null NOT NULL,
    browser_binding_digest character varying CONSTRAINT visitor_session_limit_resolutio_browser_binding_digest_not_null NOT NULL,
    selected_session_ref character varying,
    started_at timestamp(6) with time zone CONSTRAINT visitor_session_limit_resolution_transactio_started_at_not_null NOT NULL,
    expires_at timestamp(6) with time zone CONSTRAINT visitor_session_limit_resolution_transactio_expires_at_not_null NOT NULL,
    selected_at timestamp(6) with time zone,
    resolved_at timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    expired_at timestamp(6) with time zone,
    consumed_at timestamp(6) with time zone,
    finalized_at timestamp(6) with time zone,
    audit_context jsonb DEFAULT '{}'::jsonb CONSTRAINT visitor_session_limit_resolution_transac_audit_context_not_null NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp without time zone CONSTRAINT visitor_session_limit_resolution_transactio_discard_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp without time zone CONSTRAINT visitor_session_limit_resolution_tra_purge_eligible_at_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT visitor_session_limit_resolution_transactio_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT visitor_session_limit_resolution_transactio_updated_at_not_null NOT NULL,
    waiting_slot smallint,
    CONSTRAINT chk_visitor_resolution_state_timestamps CHECK ((((state_id = 10) AND (selected_at IS NULL) AND (resolved_at IS NULL) AND (cancelled_at IS NULL) AND (expired_at IS NULL)) OR ((state_id = 20) AND (selected_at IS NOT NULL) AND (resolved_at IS NULL) AND (cancelled_at IS NULL) AND (expired_at IS NULL)) OR ((state_id = 100) AND (resolved_at IS NOT NULL) AND (cancelled_at IS NULL) AND (expired_at IS NULL)) OR ((state_id = 910) AND (expired_at IS NOT NULL) AND (resolved_at IS NULL) AND (cancelled_at IS NULL)) OR ((state_id = 920) AND (cancelled_at IS NOT NULL) AND (resolved_at IS NULL) AND (expired_at IS NULL)))),
    CONSTRAINT chk_visitor_resolution_waiting_slot_state CHECK ((((state_id = ANY (ARRAY[(10)::bigint, (20)::bigint])) AND (waiting_slot IS NOT NULL) AND (waiting_slot = 1)) OR ((state_id = ANY (ARRAY[(100)::bigint, (910)::bigint, (920)::bigint])) AND (waiting_slot IS NULL))))
);


--
-- Name: visitor_session_limit_resolution_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_session_limit_resolution_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_session_limit_resolution_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_session_limit_resolution_transactions_id_seq OWNED BY public.visitor_session_limit_resolution_transactions.id;


--
-- Name: visitor_sign_in_flow_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_sign_in_flow_states (
    id bigint CONSTRAINT visitor_sign_in_cycle_statuses_id_not_null NOT NULL
);


--
-- Name: visitor_sign_in_flow_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_sign_in_flow_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_sign_in_flow_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_sign_in_flow_states_id_seq OWNED BY public.visitor_sign_in_flow_states.id;


--
-- Name: visitor_sign_in_flows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_sign_in_flows (
    id bigint CONSTRAINT com_sign_in_sequence_tickets_id_not_null NOT NULL,
    public_id character varying(21) CONSTRAINT com_sign_in_sequence_tickets_public_id_not_null NOT NULL,
    principal_id bigint,
    token_id bigint,
    return_to text,
    nonce_digest character varying CONSTRAINT com_sign_in_sequence_tickets_nonce_digest_not_null NOT NULL,
    issued_at timestamp(6) with time zone CONSTRAINT com_sign_in_sequence_tickets_issued_at_not_null NOT NULL,
    expires_at timestamp(6) with time zone CONSTRAINT com_sign_in_sequence_tickets_expires_at_not_null NOT NULL,
    completed_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT com_sign_in_sequence_tickets_discarded_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT com_sign_in_sequence_tickets_purged_at_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT com_sign_in_sequence_tickets_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT com_sign_in_sequence_tickets_updated_at_not_null NOT NULL,
    state_id bigint DEFAULT 10 CONSTRAINT com_sign_in_cycles_status_id_not_null NOT NULL,
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
    CONSTRAINT chk_com_sign_in_sequence_tickets_lifetime_order CHECK ((issued_at < expires_at)),
    CONSTRAINT chk_com_sign_in_sequence_tickets_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT chk_visitor_sign_in_flows_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_visitor_sign_in_flows_state_completed_at CHECK (((state_id = 100) = (completed_at IS NOT NULL))),
    CONSTRAINT visitor_local_authentication_context_valid CHECK (((authentication_context IS NULL) OR ((authentication_context)::text = ANY (ARRAY[('normal'::character varying)::text, ('standby'::character varying)::text])))),
    CONSTRAINT visitor_sign_in_flows_authentication_evidence_valid CHECK ((((authentication_method IS NULL) AND (authentication_event_at IS NULL)) OR (((authentication_method)::text = ANY (ARRAY[('email'::character varying)::text, ('telephone'::character varying)::text, ('secret'::character varying)::text, ('passkey'::character varying)::text, ('totp'::character varying)::text, ('google'::character varying)::text, ('apple'::character varying)::text, ('entra'::character varying)::text])) AND (authentication_event_at IS NOT NULL) AND (principal_id IS NOT NULL)))),
    CONSTRAINT visitor_sign_in_flows_base_finalization_valid CHECK (((base_finalized_at IS NULL) OR ((token_id IS NOT NULL) AND (result_digest IS NOT NULL)))),
    CONSTRAINT visitor_sign_in_flows_evidence_complete CHECK (((authentication_event_at IS NULL) OR (authentication_method IS NOT NULL))),
    CONSTRAINT visitor_sign_in_flows_result_complete CHECK (((result_generation = 0) OR ((result_digest IS NOT NULL) AND (result_expires_at IS NOT NULL) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT visitor_sign_in_flows_result_delivery_valid CHECK ((((result_digest IS NULL) AND (result_expires_at IS NULL) AND (result_generation = 0)) OR ((length((result_digest)::text) = 64) AND (result_expires_at IS NOT NULL) AND (result_generation > 0) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT visitor_sign_in_flows_result_generation_valid CHECK ((result_generation >= 0))
);


--
-- Name: visitor_sign_in_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_sign_in_flows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_sign_in_flows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_sign_in_flows_id_seq OWNED BY public.visitor_sign_in_flows.id;


--
-- Name: visitor_sign_out_flow_kinds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_sign_out_flow_kinds (
    id bigint CONSTRAINT visitor_sign_out_cycle_kinds_id_not_null NOT NULL
);


--
-- Name: visitor_sign_out_flow_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_sign_out_flow_kinds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_sign_out_flow_kinds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_sign_out_flow_kinds_id_seq OWNED BY public.visitor_sign_out_flow_kinds.id;


--
-- Name: visitor_sign_out_flow_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_sign_out_flow_statuses (
    id bigint CONSTRAINT visitor_sign_out_cycle_statuses_id_not_null NOT NULL
);


--
-- Name: visitor_sign_out_flow_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_sign_out_flow_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_sign_out_flow_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_sign_out_flow_statuses_id_seq OWNED BY public.visitor_sign_out_flow_statuses.id;


--
-- Name: visitor_sign_out_flows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_sign_out_flows (
    id bigint CONSTRAINT visitor_sign_out_cycles_id_not_null NOT NULL,
    public_id character varying(21) CONSTRAINT visitor_sign_out_cycles_public_id_not_null NOT NULL,
    principal_id bigint,
    token_id bigint,
    status_id bigint DEFAULT 10 CONSTRAINT visitor_sign_out_cycles_status_id_not_null NOT NULL,
    kind_id bigint DEFAULT 0 CONSTRAINT visitor_sign_out_cycles_kind_id_not_null NOT NULL,
    refresh_token_family_id character varying,
    requested_at timestamp(6) with time zone CONSTRAINT visitor_sign_out_cycles_requested_at_not_null NOT NULL,
    access_discarded_at timestamp(6) with time zone,
    logically_revoked_at timestamp(6) with time zone,
    access_expires_at timestamp(6) with time zone CONSTRAINT visitor_sign_out_cycles_access_expires_at_not_null NOT NULL,
    refresh_expires_at timestamp(6) with time zone CONSTRAINT visitor_sign_out_cycles_refresh_expires_at_not_null NOT NULL,
    completed_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    return_to text,
    nonce_digest character varying,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT visitor_sign_out_cycles_discarded_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT visitor_sign_out_cycles_purged_at_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT visitor_sign_out_cycles_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT visitor_sign_out_cycles_updated_at_not_null NOT NULL,
    CONSTRAINT chk_visitor_sign_out_cycles_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT chk_visitor_sign_out_cycles_token_expiry_order CHECK ((access_expires_at <= refresh_expires_at)),
    CONSTRAINT chk_visitor_sign_out_flows_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: visitor_sign_out_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_sign_out_flows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_sign_out_flows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_sign_out_flows_id_seq OWNED BY public.visitor_sign_out_flows.id;


--
-- Name: visitor_sign_up_flow_cleanup_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_sign_up_flow_cleanup_statuses (
    id bigint CONSTRAINT visitor_sign_up_cycle_cleanup_statuses_id_not_null NOT NULL
);


--
-- Name: visitor_sign_up_flow_cleanup_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_sign_up_flow_cleanup_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_sign_up_flow_cleanup_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_sign_up_flow_cleanup_statuses_id_seq OWNED BY public.visitor_sign_up_flow_cleanup_statuses.id;


--
-- Name: visitor_sign_up_flow_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_sign_up_flow_statuses (
    id bigint CONSTRAINT visitor_sign_up_cycle_statuses_id_not_null NOT NULL
);


--
-- Name: visitor_sign_up_flow_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_sign_up_flow_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_sign_up_flow_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_sign_up_flow_statuses_id_seq OWNED BY public.visitor_sign_up_flow_statuses.id;


--
-- Name: visitor_sign_up_flows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_sign_up_flows (
    id bigint CONSTRAINT com_sign_up_sequence_tickets_id_not_null NOT NULL,
    public_id character varying(21) CONSTRAINT com_sign_up_sequence_tickets_public_id_not_null NOT NULL,
    principal_id bigint,
    token_id bigint,
    state character varying CONSTRAINT com_sign_up_sequence_tickets_state_not_null NOT NULL,
    step character varying CONSTRAINT com_sign_up_sequence_tickets_step_not_null NOT NULL,
    return_to text,
    nonce_digest character varying CONSTRAINT com_sign_up_sequence_tickets_nonce_digest_not_null NOT NULL,
    issued_at timestamp(6) with time zone CONSTRAINT com_sign_up_sequence_tickets_issued_at_not_null NOT NULL,
    expires_at timestamp(6) with time zone CONSTRAINT com_sign_up_sequence_tickets_expires_at_not_null NOT NULL,
    completed_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT com_sign_up_sequence_tickets_discarded_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT com_sign_up_sequence_tickets_purged_at_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT com_sign_up_sequence_tickets_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT com_sign_up_sequence_tickets_updated_at_not_null NOT NULL,
    status_id bigint DEFAULT 10 CONSTRAINT com_sign_up_cycles_status_id_not_null NOT NULL,
    entry_method character varying NOT NULL,
    pending_contact_type character varying,
    pending_contact_id bigint,
    social_provider character varying,
    completed_requirements jsonb DEFAULT '{}'::jsonb CONSTRAINT com_sign_up_cycles_completed_requirements_not_null NOT NULL,
    failed_at timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    checkpoint_version integer DEFAULT 0 CONSTRAINT visitor_sign_up_cycles_checkpoint_version_not_null NOT NULL,
    cleanup_attempted_at timestamp(6) with time zone,
    cleanup_completed_at timestamp(6) with time zone,
    cleanup_error_code character varying,
    pending_passkey_registration_id bigint,
    cleanup_attempts_count integer DEFAULT 0 CONSTRAINT visitor_sign_up_cycles_cleanup_attempts_count_not_null NOT NULL,
    cleanup_status_id bigint DEFAULT 10 CONSTRAINT visitor_sign_up_cycles_cleanup_status_id_not_null NOT NULL,
    result_digest character varying(64),
    result_generation integer DEFAULT 0 NOT NULL,
    result_expires_at timestamp(6) with time zone,
    base_finalized_at timestamp(6) with time zone,
    authentication_method character varying,
    authentication_event_at timestamp(6) with time zone,
    CONSTRAINT chk_com_sign_up_sequence_tickets_lifetime_order CHECK ((issued_at < expires_at)),
    CONSTRAINT chk_com_sign_up_sequence_tickets_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT chk_visitor_sign_up_flows_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT visitor_sign_up_flows_authentication_evidence_valid CHECK ((((authentication_method IS NULL) AND (authentication_event_at IS NULL)) OR (((authentication_method)::text = ANY (ARRAY[('email'::character varying)::text, ('telephone'::character varying)::text, ('secret'::character varying)::text, ('passkey'::character varying)::text, ('totp'::character varying)::text, ('google'::character varying)::text, ('apple'::character varying)::text, ('entra'::character varying)::text])) AND (authentication_event_at IS NOT NULL) AND (principal_id IS NOT NULL)))),
    CONSTRAINT visitor_sign_up_flows_base_finalization_valid CHECK (((base_finalized_at IS NULL) OR ((token_id IS NOT NULL) AND (result_digest IS NOT NULL)))),
    CONSTRAINT visitor_sign_up_flows_evidence_complete CHECK (((authentication_event_at IS NULL) OR (authentication_method IS NOT NULL))),
    CONSTRAINT visitor_sign_up_flows_result_complete CHECK (((result_generation = 0) OR ((result_digest IS NOT NULL) AND (result_expires_at IS NOT NULL) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT visitor_sign_up_flows_result_delivery_valid CHECK ((((result_digest IS NULL) AND (result_expires_at IS NULL) AND (result_generation = 0)) OR ((length((result_digest)::text) = 64) AND (result_expires_at IS NOT NULL) AND (result_generation > 0) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT visitor_sign_up_flows_result_generation_valid CHECK ((result_generation >= 0))
);


--
-- Name: visitor_sign_up_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_sign_up_flows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_sign_up_flows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_sign_up_flows_id_seq OWNED BY public.visitor_sign_up_flows.id;


--
-- Name: visitor_step_up_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_step_up_ceremony_transactions (
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
    phishing_resistant_required boolean DEFAULT false CONSTRAINT visitor_step_up_ceremony_tr_phishing_resistant_require_not_null NOT NULL,
    phishing_resistant boolean DEFAULT false CONSTRAINT visitor_step_up_ceremony_transactio_phishing_resistant_not_null NOT NULL,
    purpose character varying DEFAULT 'step_up'::character varying NOT NULL,
    result_digest character varying(64),
    result_generation integer DEFAULT 0 CONSTRAINT visitor_step_up_ceremony_transaction_result_generation_not_null NOT NULL,
    result_expires_at timestamp(6) with time zone,
    canceled_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    verified_credential_ref character varying,
    step_up_required boolean DEFAULT true NOT NULL,
    user_verification_required boolean DEFAULT false CONSTRAINT visitor_step_up_ceremony_tr_user_verification_required_not_null NOT NULL,
    full_reauthentication_required boolean DEFAULT false CONSTRAINT visitor_step_up_ceremony_tr_full_reauthentication_requ_not_null NOT NULL,
    audience character varying NOT NULL,
    token_binding character varying NOT NULL,
    require_session_binding boolean DEFAULT true CONSTRAINT visitor_step_up_ceremony_trans_require_session_binding_not_null NOT NULL,
    tenant_ref character varying,
    user_verified boolean,
    cancellation_handoff_digest character varying(64),
    cancellation_handoff_ref uuid,
    cancellation_handoff_ciphertext text,
    CONSTRAINT visitor_step_up_cancellation_handoff_pair CHECK ((((cancellation_handoff_ref IS NULL) AND (cancellation_handoff_ciphertext IS NULL)) OR ((cancellation_handoff_ref IS NOT NULL) AND (cancellation_handoff_ciphertext IS NOT NULL)))),
    CONSTRAINT visitor_step_up_cancellation_handoff_valid CHECK (((cancellation_handoff_digest IS NULL) OR ((cancellation_handoff_digest)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT visitor_step_up_purpose_valid CHECK (((purpose)::text = ANY (ARRAY[('step_up'::character varying)::text, ('reauthentication'::character varying)::text, ('bootstrap'::character varying)::text, ('credential_registration'::character varying)::text, ('credential_change'::character varying)::text]))),
    CONSTRAINT visitor_step_up_result_valid CHECK (((result_generation >= 0) AND (((result_digest IS NULL) AND (result_expires_at IS NULL) AND (result_generation = 0)) OR ((result_digest IS NOT NULL) AND ((result_digest)::text ~ '^[0-9a-f]{64}$'::text) AND (result_expires_at IS NOT NULL) AND (result_generation > 0) AND (verified_at IS NOT NULL))))),
    CONSTRAINT visitor_step_up_status_valid CHECK (((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('verified'::character varying)::text, ('consumed'::character varying)::text, ('canceled'::character varying)::text, ('expired'::character varying)::text, ('revoked'::character varying)::text]))),
    CONSTRAINT visitor_step_up_terminal_valid CHECK ((((canceled_at IS NULL) OR ((status)::text = 'canceled'::text)) AND ((revoked_at IS NULL) OR ((status)::text = 'revoked'::text)) AND (((status)::text <> 'revoked'::text) OR (revoked_at IS NOT NULL)) AND (((status)::text <> 'verified'::text) OR ((verified_at IS NOT NULL) AND (method IS NOT NULL) AND (aal IS NOT NULL))))),
    CONSTRAINT visitor_step_up_verified_credential_present CHECK ((((status)::text <> 'verified'::text) OR (((purpose)::text = ANY (ARRAY[('bootstrap'::character varying)::text, ('credential_registration'::character varying)::text])) AND (verified_credential_ref IS NULL) AND ((aal)::text = 'none'::text) AND ((required_aal)::text = 'none'::text) AND (phishing_resistant IS FALSE) AND (phishing_resistant_required IS FALSE) AND ((method)::text = ANY (ARRAY[('passkey'::character varying)::text, ('totp'::character varying)::text]))) OR (((purpose)::text <> ALL (ARRAY[('bootstrap'::character varying)::text, ('credential_registration'::character varying)::text])) AND (verified_credential_ref IS NOT NULL) AND (length((verified_credential_ref)::text) > 0))))
);


--
-- Name: visitor_step_up_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_step_up_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_step_up_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_step_up_ceremony_transactions_id_seq OWNED BY public.visitor_step_up_ceremony_transactions.id;


--
-- Name: visitor_step_up_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_step_up_sessions (
    id bigint CONSTRAINT customer_reauth_sessions_id_not_null NOT NULL,
    attempt_count integer DEFAULT 0 CONSTRAINT customer_reauth_sessions_attempt_count_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT customer_reauth_sessions_created_at_not_null NOT NULL,
    visitor_token_id bigint CONSTRAINT customer_reauth_sessions_customer_token_id_not_null NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT customer_reauth_sessions_discarded_at_not_null NOT NULL,
    method character varying,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT customer_reauth_sessions_purged_at_not_null NOT NULL,
    return_to text CONSTRAINT customer_reauth_sessions_return_to_not_null NOT NULL,
    scope character varying CONSTRAINT customer_reauth_sessions_scope_not_null NOT NULL,
    status character varying CONSTRAINT customer_reauth_sessions_status_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT customer_reauth_sessions_updated_at_not_null NOT NULL,
    verified_at timestamp(6) with time zone,
    step_up_ceremony_transaction_ref character varying,
    passkey_challenge text,
    passkey_challenge_ref character varying,
    passkey_rp_id character varying,
    passkey_origin character varying,
    passkey_challenge_expires_at timestamp(6) with time zone,
    passkey_challenge_consumed_at timestamp(6) with time zone,
    email_credential_ref character varying,
    email_code_digest character varying(64),
    email_code_generation integer DEFAULT 0 NOT NULL,
    email_code_issued_at timestamp(6) with time zone,
    email_code_expires_at timestamp(6) with time zone,
    email_code_consumed_at timestamp(6) with time zone,
    email_delivery_state character varying,
    CONSTRAINT chk_visitor_step_up_sessions_attempt_count CHECK ((attempt_count >= 0)),
    CONSTRAINT visitor_step_up_challenge_bound CHECK (((passkey_challenge IS NULL) OR ((step_up_ceremony_transaction_ref IS NOT NULL) AND (passkey_challenge_ref IS NOT NULL) AND (passkey_rp_id IS NOT NULL) AND (passkey_origin IS NOT NULL) AND (passkey_challenge_expires_at IS NOT NULL) AND (passkey_challenge_expires_at <= discard_at)))),
    CONSTRAINT visitor_step_up_email_generation_valid CHECK ((((email_code_generation = 0) AND (email_credential_ref IS NULL) AND (email_code_digest IS NULL) AND (email_code_issued_at IS NULL) AND (email_code_expires_at IS NULL) AND (email_code_consumed_at IS NULL) AND (email_delivery_state IS NULL)) OR ((email_code_generation > 0) AND (email_credential_ref IS NOT NULL) AND (length((email_credential_ref)::text) > 0) AND (email_code_digest IS NOT NULL) AND ((email_code_digest)::text ~ '^[0-9a-f]{64}$'::text) AND (email_code_issued_at IS NOT NULL) AND (email_code_expires_at IS NOT NULL) AND (email_code_expires_at > email_code_issued_at) AND (email_code_expires_at <= (email_code_issued_at + '00:10:00'::interval)) AND (email_delivery_state IS NOT NULL) AND ((email_delivery_state)::text = ANY (ARRAY[('pending'::character varying)::text, ('delivered'::character varying)::text, ('failed'::character varying)::text])) AND ((email_code_consumed_at IS NULL) OR (((email_delivery_state)::text = 'delivered'::text) AND (email_code_consumed_at >= email_code_issued_at) AND (email_code_consumed_at < email_code_expires_at))))))
);


--
-- Name: visitor_step_up_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_step_up_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_step_up_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_step_up_sessions_id_seq OWNED BY public.visitor_step_up_sessions.id;


--
-- Name: visitor_telephone_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_telephone_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
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
    CONSTRAINT visitor_telephone_ceremony_transactions_otp_material CHECK (((otp_verifier IS NULL) OR ((purpose IS NOT NULL) AND (otp_generation IS NOT NULL) AND (otp_expires_at IS NOT NULL)))),
    CONSTRAINT visitor_telephone_ceremony_transactions_otp_purpose CHECK (((purpose IS NULL) OR ((purpose)::text = ANY (ARRAY[('sign_up'::character varying)::text, ('sign_in'::character varying)::text, ('recovery'::character varying)::text, ('withdrawal'::character varying)::text, ('credential_registration'::character varying)::text])))),
    CONSTRAINT visitor_telephone_otp_proof_shape CHECK (((otp_generation IS NULL) OR (((purpose IS NOT NULL) AND ((actor_ref)::text <> ''::text) AND ((session_ref)::text <> ''::text) AND (telephone_candidate_ref IS NOT NULL) AND ((telephone_candidate_ref)::text <> ''::text) AND ((normalized_number_digest IS NULL) OR ((normalized_number_digest)::text ~ '^[0-9a-f]{64}$'::text)) AND (otp_expires_at IS NOT NULL) AND isfinite(otp_expires_at) AND isfinite(expires_at) AND (((otp_consumed_at IS NULL) AND (otp_cancelled_at IS NULL) AND (otp_verifier IS NOT NULL) AND ((otp_verifier)::text ~ '^[0-9a-f]{64}$'::text) AND (otp_receipt_verifier IS NULL) AND (otp_result_expires_at IS NULL)) OR ((otp_consumed_at IS NOT NULL) AND isfinite(otp_consumed_at) AND (otp_consumed_at < otp_expires_at) AND (otp_cancelled_at IS NULL) AND (otp_verifier IS NULL) AND (otp_receipt_verifier IS NOT NULL) AND (otp_result_expires_at IS NOT NULL)) OR ((otp_cancelled_at IS NOT NULL) AND isfinite(otp_cancelled_at) AND (otp_consumed_at IS NULL) AND (otp_verifier IS NULL) AND (otp_receipt_verifier IS NULL) AND (otp_result_expires_at IS NULL)))) IS TRUE))),
    CONSTRAINT visitor_telephone_otp_receipt_bounds CHECK ((((otp_receipt_verifier IS NULL) AND (otp_result_expires_at IS NULL)) OR ((otp_receipt_verifier IS NOT NULL) AND ((otp_receipt_verifier)::text ~ '^[0-9a-f]{64}$'::text) AND (otp_consumed_at IS NOT NULL) AND (otp_cancelled_at IS NULL) AND (otp_verifier IS NULL) AND (otp_result_expires_at IS NOT NULL) AND isfinite(otp_result_expires_at) AND (otp_result_expires_at > otp_consumed_at) AND (otp_result_expires_at <= (otp_consumed_at + '00:01:00'::interval)) AND (otp_result_expires_at <= expires_at))))
);


--
-- Name: visitor_telephone_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_telephone_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_telephone_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_telephone_ceremony_transactions_id_seq OWNED BY public.visitor_telephone_ceremony_transactions.id;


--
-- Name: visitor_token_binding_methods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_token_binding_methods (
    id bigint CONSTRAINT customer_token_binding_methods_id_not_null NOT NULL
);


--
-- Name: visitor_token_binding_methods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_token_binding_methods_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_token_binding_methods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_token_binding_methods_id_seq OWNED BY public.visitor_token_binding_methods.id;


--
-- Name: visitor_token_dbsc_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_token_dbsc_statuses (
    id bigint CONSTRAINT customer_token_dbsc_statuses_id_not_null NOT NULL
);


--
-- Name: visitor_token_dbsc_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_token_dbsc_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_token_dbsc_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_token_dbsc_statuses_id_seq OWNED BY public.visitor_token_dbsc_statuses.id;


--
-- Name: visitor_token_kinds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_token_kinds (
    id bigint CONSTRAINT customer_token_kinds_id_not_null NOT NULL
);


--
-- Name: visitor_token_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_token_kinds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_token_kinds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_token_kinds_id_seq OWNED BY public.visitor_token_kinds.id;


--
-- Name: visitor_token_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_token_statuses (
    id bigint CONSTRAINT customer_token_statuses_id_not_null NOT NULL
);


--
-- Name: visitor_token_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_token_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_token_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_token_statuses_id_seq OWNED BY public.visitor_token_statuses.id;


--
-- Name: visitor_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitor_tokens (
    id bigint CONSTRAINT customer_tokens_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT customer_tokens_created_at_not_null NOT NULL,
    visitor_id bigint CONSTRAINT customer_tokens_customer_id_not_null NOT NULL,
    visitor_token_binding_method_id bigint DEFAULT 0 CONSTRAINT customer_tokens_customer_token_binding_method_id_not_null NOT NULL,
    visitor_token_dbsc_status_id bigint DEFAULT 0 CONSTRAINT customer_tokens_customer_token_dbsc_status_id_not_null NOT NULL,
    visitor_token_kind_id bigint DEFAULT 1 CONSTRAINT customer_tokens_customer_token_kind_id_not_null NOT NULL,
    visitor_token_status_id bigint DEFAULT 1 CONSTRAINT customer_tokens_customer_token_status_id_not_null NOT NULL,
    dbsc_challenge text,
    dbsc_challenge_issued_at timestamp(6) with time zone,
    dbsc_public_key jsonb,
    dbsc_session_id character varying,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT customer_tokens_deletable_at_not_null NOT NULL,
    last_step_up_at timestamp(6) with time zone,
    last_step_up_scope character varying,
    last_used_at timestamp(6) with time zone,
    public_id character varying(21) DEFAULT ''::character varying CONSTRAINT customer_tokens_public_id_not_null NOT NULL,
    refresh_token_digest bytea,
    refresh_token_family_id character varying,
    refresh_token_generation integer DEFAULT 0 CONSTRAINT customer_tokens_refresh_token_generation_not_null NOT NULL,
    rotated_at timestamp(6) with time zone,
    updated_at timestamp(6) with time zone CONSTRAINT customer_tokens_updated_at_not_null NOT NULL,
    dpop_jkt character varying,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT customer_tokens_discarded_at_not_null NOT NULL,
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
    authentication_event_at timestamp(6) with time zone,
    root_login_established_at timestamp with time zone,
    last_step_up_user_verified boolean,
    last_step_up_credential_ref character varying,
    last_step_up_full_reauthentication boolean,
    last_step_up_resource_ref character varying,
    last_step_up_tenant_ref character varying,
    authentication_epoch bigint NOT NULL,
    CONSTRAINT chk_customer_tokens_kind_id_positive CHECK ((visitor_token_kind_id >= 0)),
    CONSTRAINT chk_customer_tokens_status_id_positive CHECK ((visitor_token_status_id >= 0)),
    CONSTRAINT chk_visitor_tokens_authentication_epoch CHECK ((authentication_epoch >= 0)),
    CONSTRAINT chk_visitor_tokens_established_authentication_method CHECK (((established_authentication_method IS NULL) OR ((established_authentication_method)::text = ANY (ARRAY[('email'::character varying)::text, ('telephone'::character varying)::text, ('secret'::character varying)::text, ('passkey'::character varying)::text])))),
    CONSTRAINT chk_visitor_tokens_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: visitor_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_tokens_id_seq OWNED BY public.visitor_tokens.id;


--
-- Name: visitor_verifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitor_verifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_verifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_verifications_id_seq OWNED BY public.visitor_verifications.id;


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
-- Name: op_com_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_com_grants ALTER COLUMN id SET DEFAULT nextval('public.op_com_grants_id_seq'::regclass);


--
-- Name: op_consumed_jtis id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_consumed_jtis ALTER COLUMN id SET DEFAULT nextval('public.op_consumed_jtis_id_seq'::regclass);


--
-- Name: op_inbound_event_receipts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_inbound_event_receipts ALTER COLUMN id SET DEFAULT nextval('public.op_inbound_event_receipts_id_seq'::regclass);


--
-- Name: op_outbox_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_outbox_events ALTER COLUMN id SET DEFAULT nextval('public.op_outbox_events_id_seq'::regclass);


--
-- Name: visitor_auth_admission_bindings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_auth_admission_bindings ALTER COLUMN id SET DEFAULT nextval('public.visitor_auth_admission_bindings_id_seq'::regclass);


--
-- Name: visitor_auth_ceremony_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_auth_ceremony_sessions ALTER COLUMN id SET DEFAULT nextval('public.visitor_auth_ceremony_sessions_id_seq'::regclass);


--
-- Name: visitor_device_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_device_sessions ALTER COLUMN id SET DEFAULT nextval('public.visitor_device_sessions_id_seq'::regclass);


--
-- Name: visitor_dpop_proof_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_dpop_proof_states ALTER COLUMN id SET DEFAULT nextval('public.visitor_dpop_proof_states_id_seq'::regclass);


--
-- Name: visitor_email_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_email_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.visitor_email_ceremony_transactions_id_seq'::regclass);


--
-- Name: visitor_oidc_authorization_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_oidc_authorization_transactions ALTER COLUMN id SET DEFAULT nextval('public.visitor_oidc_authorization_transactions_id_seq'::regclass);


--
-- Name: visitor_oidc_connections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_oidc_connections ALTER COLUMN id SET DEFAULT nextval('public.visitor_oidc_connections_id_seq'::regclass);


--
-- Name: visitor_passkey_ceremony_candidates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_passkey_ceremony_candidates ALTER COLUMN id SET DEFAULT nextval('public.visitor_passkey_ceremony_candidates_id_seq'::regclass);


--
-- Name: visitor_passkey_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_passkey_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.visitor_passkey_ceremony_transactions_id_seq'::regclass);


--
-- Name: visitor_secret_credential_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credential_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.visitor_secret_credential_ceremony_transactions_id_seq'::regclass);


--
-- Name: visitor_session_limit_resolution_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_session_limit_resolution_states ALTER COLUMN id SET DEFAULT nextval('public.visitor_session_limit_resolution_states_id_seq'::regclass);


--
-- Name: visitor_session_limit_resolution_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_session_limit_resolution_transactions ALTER COLUMN id SET DEFAULT nextval('public.visitor_session_limit_resolution_transactions_id_seq'::regclass);


--
-- Name: visitor_sign_in_flow_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_in_flow_states ALTER COLUMN id SET DEFAULT nextval('public.visitor_sign_in_flow_states_id_seq'::regclass);


--
-- Name: visitor_sign_in_flows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_in_flows ALTER COLUMN id SET DEFAULT nextval('public.visitor_sign_in_flows_id_seq'::regclass);


--
-- Name: visitor_sign_out_flow_kinds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_out_flow_kinds ALTER COLUMN id SET DEFAULT nextval('public.visitor_sign_out_flow_kinds_id_seq'::regclass);


--
-- Name: visitor_sign_out_flow_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_out_flow_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_sign_out_flow_statuses_id_seq'::regclass);


--
-- Name: visitor_sign_out_flows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_out_flows ALTER COLUMN id SET DEFAULT nextval('public.visitor_sign_out_flows_id_seq'::regclass);


--
-- Name: visitor_sign_up_flow_cleanup_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_up_flow_cleanup_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_sign_up_flow_cleanup_statuses_id_seq'::regclass);


--
-- Name: visitor_sign_up_flow_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_up_flow_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_sign_up_flow_statuses_id_seq'::regclass);


--
-- Name: visitor_sign_up_flows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_up_flows ALTER COLUMN id SET DEFAULT nextval('public.visitor_sign_up_flows_id_seq'::regclass);


--
-- Name: visitor_step_up_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_step_up_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.visitor_step_up_ceremony_transactions_id_seq'::regclass);


--
-- Name: visitor_step_up_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_step_up_sessions ALTER COLUMN id SET DEFAULT nextval('public.visitor_step_up_sessions_id_seq'::regclass);


--
-- Name: visitor_telephone_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_telephone_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.visitor_telephone_ceremony_transactions_id_seq'::regclass);


--
-- Name: visitor_token_binding_methods id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_token_binding_methods ALTER COLUMN id SET DEFAULT nextval('public.visitor_token_binding_methods_id_seq'::regclass);


--
-- Name: visitor_token_dbsc_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_token_dbsc_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_token_dbsc_statuses_id_seq'::regclass);


--
-- Name: visitor_token_kinds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_token_kinds ALTER COLUMN id SET DEFAULT nextval('public.visitor_token_kinds_id_seq'::regclass);


--
-- Name: visitor_token_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_token_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_token_statuses_id_seq'::regclass);


--
-- Name: visitor_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_tokens ALTER COLUMN id SET DEFAULT nextval('public.visitor_tokens_id_seq'::regclass);


--
-- Name: visitor_verifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_verifications ALTER COLUMN id SET DEFAULT nextval('public.visitor_verifications_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: visitor_email_ceremony_transactions chk_visitor_email_ceremony_evp_attempt_count; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.visitor_email_ceremony_transactions
    ADD CONSTRAINT chk_visitor_email_ceremony_evp_attempt_count CHECK ((evp_attempt_count >= 0)) NOT VALID;


--
-- Name: visitor_step_up_sessions chk_visitor_step_up_sessions_retention_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.visitor_step_up_sessions
    ADD CONSTRAINT chk_visitor_step_up_sessions_retention_order CHECK ((discard_at <= purge_eligible_at)) NOT VALID;


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
-- Name: op_com_grants op_com_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_com_grants
    ADD CONSTRAINT op_com_grants_pkey PRIMARY KEY (id);


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
-- Name: op_outbox_events op_outbox_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_outbox_events
    ADD CONSTRAINT op_outbox_events_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: visitor_auth_admission_bindings visitor_auth_admission_bindings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_auth_admission_bindings
    ADD CONSTRAINT visitor_auth_admission_bindings_pkey PRIMARY KEY (id);


--
-- Name: visitor_auth_ceremony_sessions visitor_auth_ceremony_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_auth_ceremony_sessions
    ADD CONSTRAINT visitor_auth_ceremony_sessions_pkey PRIMARY KEY (id);


--
-- Name: visitor_device_sessions visitor_device_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_device_sessions
    ADD CONSTRAINT visitor_device_sessions_pkey PRIMARY KEY (id);


--
-- Name: visitor_dpop_proof_states visitor_dpop_proof_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_dpop_proof_states
    ADD CONSTRAINT visitor_dpop_proof_states_pkey PRIMARY KEY (id);


--
-- Name: visitor_email_ceremony_transactions visitor_email_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_email_ceremony_transactions
    ADD CONSTRAINT visitor_email_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: visitor_oidc_authorization_transactions visitor_oidc_authorization_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_oidc_authorization_transactions
    ADD CONSTRAINT visitor_oidc_authorization_transactions_pkey PRIMARY KEY (id);


--
-- Name: visitor_oidc_connections visitor_oidc_connections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_oidc_connections
    ADD CONSTRAINT visitor_oidc_connections_pkey PRIMARY KEY (id);


--
-- Name: visitor_passkey_ceremony_candidates visitor_passkey_ceremony_candidates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_passkey_ceremony_candidates
    ADD CONSTRAINT visitor_passkey_ceremony_candidates_pkey PRIMARY KEY (id);


--
-- Name: visitor_passkey_ceremony_transactions visitor_passkey_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_passkey_ceremony_transactions
    ADD CONSTRAINT visitor_passkey_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: visitor_secret_credential_ceremony_transactions visitor_secret_credential_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credential_ceremony_transactions
    ADD CONSTRAINT visitor_secret_credential_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: visitor_session_limit_resolution_states visitor_session_limit_resolution_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_session_limit_resolution_states
    ADD CONSTRAINT visitor_session_limit_resolution_states_pkey PRIMARY KEY (id);


--
-- Name: visitor_session_limit_resolution_transactions visitor_session_limit_resolution_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_session_limit_resolution_transactions
    ADD CONSTRAINT visitor_session_limit_resolution_transactions_pkey PRIMARY KEY (id);


--
-- Name: visitor_sign_in_flow_states visitor_sign_in_flow_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_in_flow_states
    ADD CONSTRAINT visitor_sign_in_flow_states_pkey PRIMARY KEY (id);


--
-- Name: visitor_sign_in_flows visitor_sign_in_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_in_flows
    ADD CONSTRAINT visitor_sign_in_flows_pkey PRIMARY KEY (id);


--
-- Name: visitor_sign_out_flow_kinds visitor_sign_out_flow_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_out_flow_kinds
    ADD CONSTRAINT visitor_sign_out_flow_kinds_pkey PRIMARY KEY (id);


--
-- Name: visitor_sign_out_flow_statuses visitor_sign_out_flow_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_out_flow_statuses
    ADD CONSTRAINT visitor_sign_out_flow_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_sign_out_flows visitor_sign_out_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_out_flows
    ADD CONSTRAINT visitor_sign_out_flows_pkey PRIMARY KEY (id);


--
-- Name: visitor_sign_up_flow_cleanup_statuses visitor_sign_up_flow_cleanup_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_up_flow_cleanup_statuses
    ADD CONSTRAINT visitor_sign_up_flow_cleanup_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_sign_up_flow_statuses visitor_sign_up_flow_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_up_flow_statuses
    ADD CONSTRAINT visitor_sign_up_flow_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_sign_up_flows visitor_sign_up_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_up_flows
    ADD CONSTRAINT visitor_sign_up_flows_pkey PRIMARY KEY (id);


--
-- Name: visitor_step_up_ceremony_transactions visitor_step_up_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_step_up_ceremony_transactions
    ADD CONSTRAINT visitor_step_up_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: visitor_step_up_sessions visitor_step_up_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_step_up_sessions
    ADD CONSTRAINT visitor_step_up_sessions_pkey PRIMARY KEY (id);


--
-- Name: visitor_telephone_ceremony_transactions visitor_telephone_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_telephone_ceremony_transactions
    ADD CONSTRAINT visitor_telephone_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: visitor_token_binding_methods visitor_token_binding_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_token_binding_methods
    ADD CONSTRAINT visitor_token_binding_methods_pkey PRIMARY KEY (id);


--
-- Name: visitor_token_dbsc_statuses visitor_token_dbsc_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_token_dbsc_statuses
    ADD CONSTRAINT visitor_token_dbsc_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_token_kinds visitor_token_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_token_kinds
    ADD CONSTRAINT visitor_token_kinds_pkey PRIMARY KEY (id);


--
-- Name: visitor_token_statuses visitor_token_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_token_statuses
    ADD CONSTRAINT visitor_token_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_tokens visitor_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_tokens
    ADD CONSTRAINT visitor_tokens_pkey PRIMARY KEY (id);


--
-- Name: visitor_verifications visitor_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_verifications
    ADD CONSTRAINT visitor_verifications_pkey PRIMARY KEY (id);


--
-- Name: idx_active_op_com_grant_per_device_session; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_active_op_com_grant_per_device_session ON public.op_com_grants USING btree (device_session_id, oidc_client_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_auth_ceremony_sessions_on_live_tx_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_auth_ceremony_sessions_on_live_tx_ref ON public.visitor_auth_ceremony_sessions USING btree (authorization_transaction_ref) WHERE ((authorization_transaction_ref IS NOT NULL) AND (cancelled_at IS NULL));


--
-- Name: idx_on_actor_ref_session_ref_099f811ef3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_099f811ef3 ON public.visitor_email_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_6038539041; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_6038539041 ON public.visitor_passkey_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_7e0a1d7d4c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_7e0a1d7d4c ON public.visitor_step_up_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_b5f7b88ec0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_b5f7b88ec0 ON public.visitor_telephone_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_b6a6aeb3f9; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_b6a6aeb3f9 ON public.visitor_secret_credential_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_cancellation_handoff_digest_3514b7fb07; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_cancellation_handoff_digest_3514b7fb07 ON public.visitor_oidc_authorization_transactions USING btree (cancellation_handoff_digest);


--
-- Name: idx_on_cancellation_handoff_digest_4c74b9916d; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_cancellation_handoff_digest_4c74b9916d ON public.visitor_step_up_ceremony_transactions USING btree (cancellation_handoff_digest);


--
-- Name: idx_on_cancellation_handoff_ref_6f48086762; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_cancellation_handoff_ref_6f48086762 ON public.visitor_step_up_ceremony_transactions USING btree (cancellation_handoff_ref);


--
-- Name: idx_on_cancellation_handoff_ref_902019dea4; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_cancellation_handoff_ref_902019dea4 ON public.visitor_oidc_authorization_transactions USING btree (cancellation_handoff_ref);


--
-- Name: idx_on_challenge_digest_68019de67e; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_challenge_digest_68019de67e ON public.visitor_session_limit_resolution_transactions USING btree (challenge_digest);


--
-- Name: idx_on_client_id_login_challenge_8056723634; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_client_id_login_challenge_8056723634 ON public.visitor_oidc_authorization_transactions USING btree (client_id, login_challenge);


--
-- Name: idx_on_expires_at_bcbf526321; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_expires_at_bcbf526321 ON public.visitor_secret_credential_ceremony_transactions USING btree (expires_at);


--
-- Name: idx_on_grant_jti_3ce786ea06; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_grant_jti_3ce786ea06 ON public.visitor_secret_credential_ceremony_transactions USING btree (grant_jti);


--
-- Name: idx_on_login_challenge_8c09aab77b; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_login_challenge_8c09aab77b ON public.visitor_oidc_authorization_transactions USING btree (login_challenge);


--
-- Name: idx_on_result_jti_9191bba74d; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_result_jti_9191bba74d ON public.visitor_secret_credential_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: idx_on_step_up_ceremony_transaction_ref_9b80d2d495; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_step_up_ceremony_transaction_ref_9b80d2d495 ON public.visitor_passkey_ceremony_candidates USING btree (step_up_ceremony_transaction_ref);


--
-- Name: idx_on_step_up_ceremony_transaction_ref_a7b9c7b4fe; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_step_up_ceremony_transaction_ref_a7b9c7b4fe ON public.visitor_step_up_sessions USING btree (step_up_ceremony_transaction_ref);


--
-- Name: idx_on_step_up_ceremony_transaction_ref_f3463ea9d2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_step_up_ceremony_transaction_ref_f3463ea9d2 ON public.visitor_passkey_ceremony_transactions USING btree (step_up_ceremony_transaction_ref);


--
-- Name: idx_on_transaction_id_1caf724349; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_transaction_id_1caf724349 ON public.visitor_telephone_ceremony_transactions USING btree (transaction_id);


--
-- Name: idx_on_transaction_id_391ee3ac66; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_transaction_id_391ee3ac66 ON public.visitor_oidc_authorization_transactions USING btree (transaction_id);


--
-- Name: idx_on_transaction_id_759e16c588; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_transaction_id_759e16c588 ON public.visitor_secret_credential_ceremony_transactions USING btree (transaction_id);


--
-- Name: idx_op_com_consumed_jtis_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_op_com_consumed_jtis_expires_at ON public.op_consumed_jtis USING btree (expires_at);


--
-- Name: idx_op_com_consumed_jtis_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_com_consumed_jtis_scope ON public.op_consumed_jtis USING btree (purpose, issuer, realm, client_id, jti_digest);


--
-- Name: idx_op_com_inbound_event_receipts_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_com_inbound_event_receipts_identity ON public.op_inbound_event_receipts USING btree (event_id, issuer, realm, client_id);


--
-- Name: idx_op_com_logout_flows_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_com_logout_flows_idempotency ON public.logout_flows USING btree (realm, idempotency_digest);


--
-- Name: idx_op_com_logout_flows_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_com_logout_flows_public_id ON public.logout_flows USING btree (public_id);


--
-- Name: idx_op_com_logout_participants_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_com_logout_participants_identity ON public.logout_flow_participants USING btree (logout_flow_id, issuer, realm, client_id, sid);


--
-- Name: idx_op_com_logout_receipts_nonce; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_com_logout_receipts_nonce ON public.logout_receipts USING btree (logout_flow_id, nonce_digest);


--
-- Name: idx_op_com_logout_receipts_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_com_logout_receipts_public_id ON public.logout_receipts USING btree (public_id);


--
-- Name: idx_op_com_outbox_events_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_com_outbox_events_event_id ON public.op_outbox_events USING btree (event_id);


--
-- Name: idx_op_com_outbox_events_next_attempt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_op_com_outbox_events_next_attempt ON public.op_outbox_events USING btree (next_attempt_at);


--
-- Name: idx_visitor_admission_bindings_auth_session; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_visitor_admission_bindings_auth_session ON public.visitor_auth_admission_bindings USING btree (auth_ceremony_session_id) WHERE (auth_ceremony_session_id IS NOT NULL);


--
-- Name: idx_visitor_admission_bindings_live_oidc; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_visitor_admission_bindings_live_oidc ON public.visitor_auth_admission_bindings USING btree (authorization_transaction_id) WHERE ((authorization_transaction_id IS NOT NULL) AND (retired_at IS NULL) AND (redeemed_at IS NULL));


--
-- Name: idx_visitor_admission_bindings_live_step_up; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_visitor_admission_bindings_live_step_up ON public.visitor_auth_admission_bindings USING btree (step_up_ceremony_transaction_id) WHERE ((step_up_ceremony_transaction_id IS NOT NULL) AND (retired_at IS NULL) AND (redeemed_at IS NULL));


--
-- Name: idx_visitor_resolution_open_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_visitor_resolution_open_parent ON public.visitor_session_limit_resolution_transactions USING btree (sign_in_flow_id) WHERE (state_id = ANY (ARRAY[(10)::bigint, (20)::bigint]));


--
-- Name: idx_visitor_resolution_waiting_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_visitor_resolution_waiting_actor ON public.visitor_session_limit_resolution_transactions USING btree (actor_ref) WHERE (waiting_slot = 1);


--
-- Name: idx_visitor_session_limit_resolution_txns_on_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_visitor_session_limit_resolution_txns_on_state_id ON public.visitor_session_limit_resolution_transactions USING btree (state_id);


--
-- Name: idx_visitor_sign_up_flows_cleanup_status_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_visitor_sign_up_flows_cleanup_status_purge_eligible_at ON public.visitor_sign_up_flows USING btree (cleanup_status_id, purge_eligible_at);


--
-- Name: index_op_com_grants_on_oidc_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_op_com_grants_on_oidc_client_id ON public.op_com_grants USING btree (oidc_client_id);


--
-- Name: index_op_com_grants_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_op_com_grants_on_public_id ON public.op_com_grants USING btree (public_id);


--
-- Name: index_op_com_grants_on_refresh_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_op_com_grants_on_refresh_token_digest ON public.op_com_grants USING btree (refresh_token_digest) WHERE (refresh_token_digest IS NOT NULL);


--
-- Name: index_op_com_grants_on_revoked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_op_com_grants_on_revoked_at ON public.op_com_grants USING btree (revoked_at);


--
-- Name: index_op_com_grants_on_visitor_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_op_com_grants_on_visitor_token_id ON public.op_com_grants USING btree (visitor_token_id);


--
-- Name: index_op_outbox_events_on_logout_flow_participant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_op_outbox_events_on_logout_flow_participant_id ON public.op_outbox_events USING btree (logout_flow_participant_id);


--
-- Name: index_visitor_auth_admission_bindings_on_confirmation_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_auth_admission_bindings_on_confirmation_ref ON public.visitor_auth_admission_bindings USING btree (confirmation_ref) WHERE (confirmation_ref IS NOT NULL);


--
-- Name: index_visitor_auth_admission_bindings_on_entry_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_auth_admission_bindings_on_entry_ref ON public.visitor_auth_admission_bindings USING btree (entry_ref);


--
-- Name: index_visitor_auth_admission_bindings_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_auth_admission_bindings_on_expires_at ON public.visitor_auth_admission_bindings USING btree (expires_at);


--
-- Name: index_visitor_auth_ceremony_sessions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_auth_ceremony_sessions_on_expires_at ON public.visitor_auth_ceremony_sessions USING btree (expires_at);


--
-- Name: index_visitor_auth_ceremony_sessions_on_revoked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_auth_ceremony_sessions_on_revoked_at ON public.visitor_auth_ceremony_sessions USING btree (revoked_at);


--
-- Name: index_visitor_auth_ceremony_sessions_on_sid_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_auth_ceremony_sessions_on_sid_digest ON public.visitor_auth_ceremony_sessions USING btree (sid_digest);


--
-- Name: index_visitor_device_sessions_on_current_refresh_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_device_sessions_on_current_refresh_token_id ON public.visitor_device_sessions USING btree (current_refresh_token_id);


--
-- Name: index_visitor_device_sessions_on_dbsc_session_id_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_device_sessions_on_dbsc_session_id_digest ON public.visitor_device_sessions USING btree (dbsc_session_id_digest);


--
-- Name: index_visitor_device_sessions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_device_sessions_on_public_id ON public.visitor_device_sessions USING btree (public_id);


--
-- Name: index_visitor_device_sessions_on_refresh_token_family_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_device_sessions_on_refresh_token_family_id ON public.visitor_device_sessions USING btree (refresh_token_family_id);


--
-- Name: index_visitor_device_sessions_on_revoked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_device_sessions_on_revoked_at ON public.visitor_device_sessions USING btree (revoked_at);


--
-- Name: index_visitor_device_sessions_on_visitor_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_device_sessions_on_visitor_id_and_id ON public.visitor_device_sessions USING btree (visitor_id, id);


--
-- Name: index_visitor_dpop_proof_states_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_dpop_proof_states_on_expires_at ON public.visitor_dpop_proof_states USING btree (expires_at);


--
-- Name: index_visitor_dpop_proof_states_on_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_dpop_proof_states_on_jti ON public.visitor_dpop_proof_states USING btree (jti) WHERE (jti IS NOT NULL);


--
-- Name: index_visitor_dpop_proof_states_on_nonce; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_dpop_proof_states_on_nonce ON public.visitor_dpop_proof_states USING btree (nonce) WHERE (nonce IS NOT NULL);


--
-- Name: index_visitor_email_ceremony_transactions_on_evp_nonce_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_email_ceremony_transactions_on_evp_nonce_digest ON public.visitor_email_ceremony_transactions USING btree (evp_nonce_digest) WHERE (evp_nonce_digest IS NOT NULL);


--
-- Name: index_visitor_email_ceremony_transactions_on_evp_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_email_ceremony_transactions_on_evp_token_digest ON public.visitor_email_ceremony_transactions USING btree (evp_token_digest) WHERE (evp_token_digest IS NOT NULL);


--
-- Name: index_visitor_email_ceremony_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_email_ceremony_transactions_on_expires_at ON public.visitor_email_ceremony_transactions USING btree (expires_at);


--
-- Name: index_visitor_email_ceremony_transactions_on_grant_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_email_ceremony_transactions_on_grant_jti ON public.visitor_email_ceremony_transactions USING btree (grant_jti);


--
-- Name: index_visitor_email_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_email_ceremony_transactions_on_result_jti ON public.visitor_email_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_visitor_email_ceremony_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_email_ceremony_transactions_on_transaction_id ON public.visitor_email_ceremony_transactions USING btree (transaction_id);


--
-- Name: index_visitor_oidc_connections_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_oidc_connections_on_public_id ON public.visitor_oidc_connections USING btree (public_id);


--
-- Name: index_visitor_oidc_connections_on_visitor_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_oidc_connections_on_visitor_id_and_client_id ON public.visitor_oidc_connections USING btree (visitor_id, client_id);


--
-- Name: index_visitor_passkey_ceremony_candidates_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_passkey_ceremony_candidates_on_expires_at ON public.visitor_passkey_ceremony_candidates USING btree (expires_at);


--
-- Name: index_visitor_passkey_ceremony_candidates_on_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_passkey_ceremony_candidates_on_ref ON public.visitor_passkey_ceremony_candidates USING btree (ref);


--
-- Name: index_visitor_passkey_ceremony_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_passkey_ceremony_transactions_on_expires_at ON public.visitor_passkey_ceremony_transactions USING btree (expires_at);


--
-- Name: index_visitor_passkey_ceremony_transactions_on_grant_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_passkey_ceremony_transactions_on_grant_jti ON public.visitor_passkey_ceremony_transactions USING btree (grant_jti);


--
-- Name: index_visitor_passkey_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_passkey_ceremony_transactions_on_result_jti ON public.visitor_passkey_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_visitor_passkey_ceremony_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_passkey_ceremony_transactions_on_transaction_id ON public.visitor_passkey_ceremony_transactions USING btree (transaction_id);


--
-- Name: index_visitor_sign_in_flows_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_in_flows_on_discard_at ON public.visitor_sign_in_flows USING btree (discard_at);


--
-- Name: index_visitor_sign_in_flows_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_in_flows_on_expires_at ON public.visitor_sign_in_flows USING btree (expires_at);


--
-- Name: index_visitor_sign_in_flows_on_principal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_in_flows_on_principal_id ON public.visitor_sign_in_flows USING btree (principal_id);


--
-- Name: index_visitor_sign_in_flows_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_sign_in_flows_on_public_id ON public.visitor_sign_in_flows USING btree (public_id);


--
-- Name: index_visitor_sign_in_flows_on_result_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_sign_in_flows_on_result_digest ON public.visitor_sign_in_flows USING btree (result_digest);


--
-- Name: index_visitor_sign_in_flows_on_selected_persona_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_in_flows_on_selected_persona_id ON public.visitor_sign_in_flows USING btree (selected_persona_id);


--
-- Name: index_visitor_sign_in_flows_on_selected_region_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_in_flows_on_selected_region_id ON public.visitor_sign_in_flows USING btree (selected_region_id);


--
-- Name: index_visitor_sign_in_flows_on_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_in_flows_on_state_id ON public.visitor_sign_in_flows USING btree (state_id);


--
-- Name: index_visitor_sign_in_flows_on_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_in_flows_on_token_id ON public.visitor_sign_in_flows USING btree (token_id);


--
-- Name: index_visitor_sign_in_flows_on_token_id_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_sign_in_flows_on_token_id_unique ON public.visitor_sign_in_flows USING btree (token_id) WHERE (token_id IS NOT NULL);


--
-- Name: index_visitor_sign_out_flows_on_access_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_out_flows_on_access_expires_at ON public.visitor_sign_out_flows USING btree (access_expires_at);


--
-- Name: index_visitor_sign_out_flows_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_out_flows_on_discard_at ON public.visitor_sign_out_flows USING btree (discard_at);


--
-- Name: index_visitor_sign_out_flows_on_kind_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_out_flows_on_kind_id ON public.visitor_sign_out_flows USING btree (kind_id);


--
-- Name: index_visitor_sign_out_flows_on_principal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_out_flows_on_principal_id ON public.visitor_sign_out_flows USING btree (principal_id);


--
-- Name: index_visitor_sign_out_flows_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_sign_out_flows_on_public_id ON public.visitor_sign_out_flows USING btree (public_id);


--
-- Name: index_visitor_sign_out_flows_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_out_flows_on_purge_eligible_at ON public.visitor_sign_out_flows USING btree (purge_eligible_at);


--
-- Name: index_visitor_sign_out_flows_on_refresh_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_out_flows_on_refresh_expires_at ON public.visitor_sign_out_flows USING btree (refresh_expires_at);


--
-- Name: index_visitor_sign_out_flows_on_refresh_token_family_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_out_flows_on_refresh_token_family_id ON public.visitor_sign_out_flows USING btree (refresh_token_family_id);


--
-- Name: index_visitor_sign_out_flows_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_out_flows_on_status_id ON public.visitor_sign_out_flows USING btree (status_id);


--
-- Name: index_visitor_sign_out_flows_on_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_out_flows_on_token_id ON public.visitor_sign_out_flows USING btree (token_id);


--
-- Name: index_visitor_sign_up_cycles_on_pending_passkey_registration_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_up_cycles_on_pending_passkey_registration_id ON public.visitor_sign_up_flows USING btree (pending_passkey_registration_id);


--
-- Name: index_visitor_sign_up_flows_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_up_flows_on_discard_at ON public.visitor_sign_up_flows USING btree (discard_at);


--
-- Name: index_visitor_sign_up_flows_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_up_flows_on_expires_at ON public.visitor_sign_up_flows USING btree (expires_at);


--
-- Name: index_visitor_sign_up_flows_on_pending_contact_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_up_flows_on_pending_contact_id ON public.visitor_sign_up_flows USING btree (pending_contact_id);


--
-- Name: index_visitor_sign_up_flows_on_principal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_up_flows_on_principal_id ON public.visitor_sign_up_flows USING btree (principal_id);


--
-- Name: index_visitor_sign_up_flows_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_sign_up_flows_on_public_id ON public.visitor_sign_up_flows USING btree (public_id);


--
-- Name: index_visitor_sign_up_flows_on_result_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_sign_up_flows_on_result_digest ON public.visitor_sign_up_flows USING btree (result_digest);


--
-- Name: index_visitor_sign_up_flows_on_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_up_flows_on_state ON public.visitor_sign_up_flows USING btree (state);


--
-- Name: index_visitor_sign_up_flows_on_status_id_and_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_up_flows_on_status_id_and_expires_at ON public.visitor_sign_up_flows USING btree (status_id, expires_at);


--
-- Name: index_visitor_sign_up_flows_on_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_up_flows_on_token_id ON public.visitor_sign_up_flows USING btree (token_id);


--
-- Name: index_visitor_step_up_ceremony_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_step_up_ceremony_transactions_on_expires_at ON public.visitor_step_up_ceremony_transactions USING btree (expires_at);


--
-- Name: index_visitor_step_up_ceremony_transactions_on_grant_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_step_up_ceremony_transactions_on_grant_jti ON public.visitor_step_up_ceremony_transactions USING btree (grant_jti);


--
-- Name: index_visitor_step_up_ceremony_transactions_on_required_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_step_up_ceremony_transactions_on_required_scope ON public.visitor_step_up_ceremony_transactions USING btree (required_scope);


--
-- Name: index_visitor_step_up_ceremony_transactions_on_result_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_step_up_ceremony_transactions_on_result_digest ON public.visitor_step_up_ceremony_transactions USING btree (result_digest);


--
-- Name: index_visitor_step_up_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_step_up_ceremony_transactions_on_result_jti ON public.visitor_step_up_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_visitor_step_up_ceremony_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_step_up_ceremony_transactions_on_transaction_id ON public.visitor_step_up_ceremony_transactions USING btree (transaction_id);


--
-- Name: index_visitor_step_up_sessions_on_passkey_challenge_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_step_up_sessions_on_passkey_challenge_ref ON public.visitor_step_up_sessions USING btree (passkey_challenge_ref);


--
-- Name: index_visitor_step_up_sessions_on_visitor_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_step_up_sessions_on_visitor_token_id ON public.visitor_step_up_sessions USING btree (visitor_token_id);


--
-- Name: index_visitor_telephone_ceremony_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_telephone_ceremony_transactions_on_expires_at ON public.visitor_telephone_ceremony_transactions USING btree (expires_at);


--
-- Name: index_visitor_telephone_ceremony_transactions_on_grant_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_telephone_ceremony_transactions_on_grant_jti ON public.visitor_telephone_ceremony_transactions USING btree (grant_jti);


--
-- Name: index_visitor_telephone_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_telephone_ceremony_transactions_on_result_jti ON public.visitor_telephone_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_visitor_tokens_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_tokens_on_created_at ON public.visitor_tokens USING btree (created_at);


--
-- Name: index_visitor_tokens_on_dbsc_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_tokens_on_dbsc_session_id ON public.visitor_tokens USING btree (dbsc_session_id);


--
-- Name: index_visitor_tokens_on_device_session_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_tokens_on_device_session_id_and_id ON public.visitor_tokens USING btree (device_session_id, id);


--
-- Name: index_visitor_tokens_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_tokens_on_discard_at ON public.visitor_tokens USING btree (discard_at);


--
-- Name: index_visitor_tokens_on_established_authentication_method; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_tokens_on_established_authentication_method ON public.visitor_tokens USING btree (established_authentication_method);


--
-- Name: index_visitor_tokens_on_oidc_connection_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_tokens_on_oidc_connection_id ON public.visitor_tokens USING btree (oidc_connection_id);


--
-- Name: index_visitor_tokens_on_oidc_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_tokens_on_oidc_jti ON public.visitor_tokens USING btree (oidc_jti);


--
-- Name: index_visitor_tokens_on_oidc_sid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_tokens_on_oidc_sid ON public.visitor_tokens USING btree (oidc_sid);


--
-- Name: index_visitor_tokens_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_tokens_on_public_id ON public.visitor_tokens USING btree (public_id);


--
-- Name: index_visitor_tokens_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_tokens_on_purge_eligible_at ON public.visitor_tokens USING btree (purge_eligible_at);


--
-- Name: index_visitor_tokens_on_refresh_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_tokens_on_refresh_token_digest ON public.visitor_tokens USING btree (refresh_token_digest);


--
-- Name: index_visitor_tokens_on_refresh_token_family_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_tokens_on_refresh_token_family_id ON public.visitor_tokens USING btree (refresh_token_family_id);


--
-- Name: index_visitor_tokens_on_rotated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_tokens_on_rotated_at ON public.visitor_tokens USING btree (rotated_at);


--
-- Name: index_visitor_tokens_on_selected_account_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_tokens_on_selected_account_public_id ON public.visitor_tokens USING btree (selected_account_public_id);


--
-- Name: index_visitor_tokens_on_selected_collective_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_tokens_on_selected_collective_public_id ON public.visitor_tokens USING btree (selected_collective_public_id);


--
-- Name: index_visitor_tokens_on_visitor_id_and_last_step_up_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_tokens_on_visitor_id_and_last_step_up_at ON public.visitor_tokens USING btree (visitor_id, last_step_up_at);


--
-- Name: index_visitor_tokens_on_visitor_id_and_oidc_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_tokens_on_visitor_id_and_oidc_client_id ON public.visitor_tokens USING btree (visitor_id, oidc_client_id);


--
-- Name: index_visitor_tokens_on_visitor_id_root_login_established_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_tokens_on_visitor_id_root_login_established_at ON public.visitor_tokens USING btree (visitor_id, root_login_established_at) WHERE (root_login_established_at IS NOT NULL);


--
-- Name: index_visitor_tokens_on_visitor_token_binding_method_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_tokens_on_visitor_token_binding_method_id ON public.visitor_tokens USING btree (visitor_token_binding_method_id);


--
-- Name: index_visitor_tokens_on_visitor_token_dbsc_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_tokens_on_visitor_token_dbsc_status_id ON public.visitor_tokens USING btree (visitor_token_dbsc_status_id);


--
-- Name: index_visitor_tokens_on_visitor_token_kind_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_tokens_on_visitor_token_kind_id ON public.visitor_tokens USING btree (visitor_token_kind_id);


--
-- Name: index_visitor_tokens_on_visitor_token_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_tokens_on_visitor_token_status_id ON public.visitor_tokens USING btree (visitor_token_status_id);


--
-- Name: index_visitor_verifications_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_verifications_on_token_digest ON public.visitor_verifications USING btree (token_digest);


--
-- Name: index_visitor_verifications_on_visitor_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_verifications_on_visitor_token_id ON public.visitor_verifications USING btree (visitor_token_id);


--
-- Name: visitor_email_otp_original_bootstrap; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX visitor_email_otp_original_bootstrap ON public.visitor_email_ceremony_transactions USING btree (bootstrap_ceremony_transaction_ref);


--
-- Name: visitor_auth_ceremony_sessions visitor_auth_email_otp_proof_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER visitor_auth_email_otp_proof_trigger BEFORE UPDATE OF email_otp_context ON public.visitor_auth_ceremony_sessions FOR EACH ROW EXECUTE FUNCTION public.enforce_visitor_auth_email_otp_proof();


--
-- Name: visitor_email_ceremony_transactions visitor_email_terminal_otp_facts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER visitor_email_terminal_otp_facts BEFORE UPDATE ON public.visitor_email_ceremony_transactions FOR EACH ROW EXECUTE FUNCTION public.enforce_visitor_email_terminal_otp_facts();


--
-- Name: visitor_telephone_ceremony_transactions visitor_telephone_terminal_otp_facts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER visitor_telephone_terminal_otp_facts BEFORE UPDATE ON public.visitor_telephone_ceremony_transactions FOR EACH ROW EXECUTE FUNCTION public.enforce_visitor_telephone_terminal_otp_facts();


--
-- Name: visitor_tokens fk_customer_tokens_on_customer_token_binding_method_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_tokens
    ADD CONSTRAINT fk_customer_tokens_on_customer_token_binding_method_id FOREIGN KEY (visitor_token_binding_method_id) REFERENCES public.visitor_token_binding_methods(id);


--
-- Name: visitor_tokens fk_customer_tokens_on_customer_token_dbsc_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_tokens
    ADD CONSTRAINT fk_customer_tokens_on_customer_token_dbsc_status_id FOREIGN KEY (visitor_token_dbsc_status_id) REFERENCES public.visitor_token_dbsc_statuses(id);


--
-- Name: visitor_tokens fk_customer_tokens_on_customer_token_kind_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_tokens
    ADD CONSTRAINT fk_customer_tokens_on_customer_token_kind_id FOREIGN KEY (visitor_token_kind_id) REFERENCES public.visitor_token_kinds(id);


--
-- Name: visitor_tokens fk_customer_tokens_on_customer_token_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_tokens
    ADD CONSTRAINT fk_customer_tokens_on_customer_token_status_id FOREIGN KEY (visitor_token_status_id) REFERENCES public.visitor_token_statuses(id);


--
-- Name: op_com_grants fk_op_com_grants_on_device_session_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_com_grants
    ADD CONSTRAINT fk_op_com_grants_on_device_session_id FOREIGN KEY (device_session_id) REFERENCES public.visitor_device_sessions(id) ON DELETE RESTRICT;


--
-- Name: visitor_sign_out_flows fk_rails_0289bc0560; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_out_flows
    ADD CONSTRAINT fk_rails_0289bc0560 FOREIGN KEY (status_id) REFERENCES public.visitor_sign_out_flow_statuses(id);


--
-- Name: visitor_auth_admission_bindings fk_rails_055b3ce7ce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_auth_admission_bindings
    ADD CONSTRAINT fk_rails_055b3ce7ce FOREIGN KEY (authorization_transaction_id) REFERENCES public.visitor_oidc_authorization_transactions(id) ON DELETE RESTRICT;


--
-- Name: visitor_passkey_ceremony_candidates fk_rails_106d7fd203; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_passkey_ceremony_candidates
    ADD CONSTRAINT fk_rails_106d7fd203 FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.visitor_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;


--
-- Name: visitor_sign_out_flows fk_rails_173a30a232; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_out_flows
    ADD CONSTRAINT fk_rails_173a30a232 FOREIGN KEY (token_id) REFERENCES public.visitor_tokens(id) ON DELETE CASCADE;


--
-- Name: logout_flow_participants fk_rails_1b37d291d0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.logout_flow_participants
    ADD CONSTRAINT fk_rails_1b37d291d0 FOREIGN KEY (logout_flow_id) REFERENCES public.logout_flows(id);


--
-- Name: visitor_auth_admission_bindings fk_rails_3bf50dd6ed; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_auth_admission_bindings
    ADD CONSTRAINT fk_rails_3bf50dd6ed FOREIGN KEY (base_token_id) REFERENCES public.visitor_tokens(id) ON DELETE RESTRICT;


--
-- Name: visitor_session_limit_resolution_transactions fk_rails_72a4663401; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_session_limit_resolution_transactions
    ADD CONSTRAINT fk_rails_72a4663401 FOREIGN KEY (state_id) REFERENCES public.visitor_session_limit_resolution_states(id) ON DELETE RESTRICT;


--
-- Name: logout_receipts fk_rails_854223f724; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.logout_receipts
    ADD CONSTRAINT fk_rails_854223f724 FOREIGN KEY (logout_flow_id) REFERENCES public.logout_flows(id);


--
-- Name: visitor_sign_up_flows fk_rails_85a641d47f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_up_flows
    ADD CONSTRAINT fk_rails_85a641d47f FOREIGN KEY (token_id) REFERENCES public.visitor_tokens(id) ON DELETE RESTRICT;


--
-- Name: visitor_sign_up_flows fk_rails_8cef237db7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_up_flows
    ADD CONSTRAINT fk_rails_8cef237db7 FOREIGN KEY (status_id) REFERENCES public.visitor_sign_up_flow_statuses(id) ON DELETE RESTRICT;


--
-- Name: op_outbox_events fk_rails_8d56cd14a9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_outbox_events
    ADD CONSTRAINT fk_rails_8d56cd14a9 FOREIGN KEY (logout_flow_participant_id) REFERENCES public.logout_flow_participants(id);


--
-- Name: visitor_sign_out_flows fk_rails_8ef47d5e3c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_out_flows
    ADD CONSTRAINT fk_rails_8ef47d5e3c FOREIGN KEY (kind_id) REFERENCES public.visitor_sign_out_flow_kinds(id);


--
-- Name: visitor_sign_in_flows fk_rails_9797ae40cc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_in_flows
    ADD CONSTRAINT fk_rails_9797ae40cc FOREIGN KEY (token_id) REFERENCES public.visitor_tokens(id) ON DELETE CASCADE;


--
-- Name: visitor_step_up_sessions fk_rails_b5a90759d5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_step_up_sessions
    ADD CONSTRAINT fk_rails_b5a90759d5 FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.visitor_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;


--
-- Name: visitor_auth_admission_bindings fk_rails_b65db01257; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_auth_admission_bindings
    ADD CONSTRAINT fk_rails_b65db01257 FOREIGN KEY (step_up_ceremony_transaction_id) REFERENCES public.visitor_step_up_ceremony_transactions(id) ON DELETE RESTRICT;


--
-- Name: visitor_session_limit_resolution_transactions fk_rails_bde56340fe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_session_limit_resolution_transactions
    ADD CONSTRAINT fk_rails_bde56340fe FOREIGN KEY (sign_in_flow_id) REFERENCES public.visitor_sign_in_flows(id) ON DELETE RESTRICT;


--
-- Name: visitor_auth_admission_bindings fk_rails_c64ad6240d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_auth_admission_bindings
    ADD CONSTRAINT fk_rails_c64ad6240d FOREIGN KEY (auth_ceremony_session_id) REFERENCES public.visitor_auth_ceremony_sessions(id) ON DELETE RESTRICT;


--
-- Name: visitor_sign_in_flows fk_rails_cc3a487ae7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_in_flows
    ADD CONSTRAINT fk_rails_cc3a487ae7 FOREIGN KEY (state_id) REFERENCES public.visitor_sign_in_flow_states(id) ON DELETE RESTRICT;


--
-- Name: visitor_step_up_sessions fk_rails_cd1cdc6b2d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_step_up_sessions
    ADD CONSTRAINT fk_rails_cd1cdc6b2d FOREIGN KEY (visitor_token_id) REFERENCES public.visitor_tokens(id) ON DELETE CASCADE;


--
-- Name: visitor_sign_up_flows fk_rails_cf6ee54a77; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_up_flows
    ADD CONSTRAINT fk_rails_cf6ee54a77 FOREIGN KEY (cleanup_status_id) REFERENCES public.visitor_sign_up_flow_cleanup_statuses(id);


--
-- Name: visitor_auth_ceremony_sessions fk_rails_d273fa69d4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_auth_ceremony_sessions
    ADD CONSTRAINT fk_rails_d273fa69d4 FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.visitor_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;


--
-- Name: visitor_session_limit_resolution_transactions fk_rails_e479a8b4ad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_session_limit_resolution_transactions
    ADD CONSTRAINT fk_rails_e479a8b4ad FOREIGN KEY (oidc_authorization_transaction_id) REFERENCES public.visitor_oidc_authorization_transactions(id) ON DELETE RESTRICT;


--
-- Name: visitor_passkey_ceremony_transactions fk_rails_ebaeb32aa4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_passkey_ceremony_transactions
    ADD CONSTRAINT fk_rails_ebaeb32aa4 FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.visitor_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;


--
-- Name: visitor_auth_admission_bindings fk_visitor_auth_admission_bindings_admitted_session; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_auth_admission_bindings
    ADD CONSTRAINT fk_visitor_auth_admission_bindings_admitted_session FOREIGN KEY (admitted_auth_ceremony_session_id) REFERENCES public.visitor_auth_ceremony_sessions(id) ON DELETE RESTRICT;


--
-- Name: visitor_device_sessions fk_visitor_device_sessions_on_current_refresh_token_owner; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_device_sessions
    ADD CONSTRAINT fk_visitor_device_sessions_on_current_refresh_token_owner FOREIGN KEY (id, current_refresh_token_id) REFERENCES public.visitor_tokens(device_session_id, id) ON DELETE SET NULL (current_refresh_token_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: visitor_tokens fk_visitor_tokens_on_device_session_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_tokens
    ADD CONSTRAINT fk_visitor_tokens_on_device_session_id FOREIGN KEY (device_session_id) REFERENCES public.visitor_device_sessions(id) ON DELETE RESTRICT;


--
-- Name: visitor_tokens fk_visitor_tokens_on_oidc_connection_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_tokens
    ADD CONSTRAINT fk_visitor_tokens_on_oidc_connection_id FOREIGN KEY (oidc_connection_id) REFERENCES public.visitor_oidc_connections(id) ON DELETE SET NULL;


--
-- Name: visitor_tokens fk_visitor_tokens_on_visitor_id_and_device_session_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_tokens
    ADD CONSTRAINT fk_visitor_tokens_on_visitor_id_and_device_session_id FOREIGN KEY (visitor_id, device_session_id) REFERENCES public.visitor_device_sessions(visitor_id, id) ON DELETE RESTRICT;


--
-- Name: visitor_verifications fk_visitor_verifications_on_visitor_token_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_verifications
    ADD CONSTRAINT fk_visitor_verifications_on_visitor_token_id FOREIGN KEY (visitor_token_id) REFERENCES public.visitor_tokens(id) ON DELETE CASCADE;


--
-- Name: visitor_email_ceremony_transactions visitor_email_otp_original_bootstrap_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_email_ceremony_transactions
    ADD CONSTRAINT visitor_email_otp_original_bootstrap_fk FOREIGN KEY (bootstrap_ceremony_transaction_ref) REFERENCES public.visitor_step_up_ceremony_transactions(transaction_id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261023191145'),
('20261023191115'),
('20261023130003'),
('20261023130002'),
('20261023130001'),
('20261023130000'),
('20261023120004'),
('20261023120001'),
('20261020130001'),
('20261020130000'),
('20261020120001'),
('20261020120000'),
('20261020110001'),
('20261020110000'),
('20261020100001'),
('20261020100000'),
('20261019110901'),
('20261019110858'),
('20261019110854'),
('20261019110850'),
('20261019035655'),
('20261019035540'),
('20261019032923'),
('20261017150000'),
('20261017140000'),
('20261017070000'),
('20261016210021'),
('20261016210014'),
('20261016210011'),
('20261016200001'),
('20261016160071'),
('20261016160061'),
('20261016160051'),
('20261016160041'),
('20261016160031'),
('20261016160021'),
('20261016160011'),
('20261016160001'),
('20261008150743'),
('20261008145937'),
('20261008094450'),
('20261008093843'),
('20261008062954'),
('20261008062847'),
('20261007223847'),
('20261007223744'),
('20261007161150'),
('20261007160130'),
('20261007153444'),
('20261007010003'),
('20261007010002'),
('20261007010001'),
('20261007010000'),
('20261006230001'),
('20261006220001'),
('20261006210011'),
('20261006210001'),
('20261006200001'),
('20261006190101'),
('20261006190001'),
('20261006170001'),
('20261006160001'),
('20261006150001'),
('20261006140001'),
('20261006130001'),
('20261006120001'),
('20261006110004'),
('20261003221639'),
('20261003215022'),
('20261003202134'),
('20261003185507'),
('20261003183734'),
('20261003181718'),
('20261003175643'),
('20261002120000'),
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
('20260920152001'),
('20260920152000'),
('20260920151000'),
('20260920150000'),
('20260917130001'),
('20260915180000'),
('20260915170000'),
('20260915160000'),
('20260913150000'),
('20260913140000'),
('20260831064132'),
('20260831064103'),
('20260727100001'),
('20260727100000'),
('20260710220001'),
('20260624000000'),
('20260616150020'),
('20260616150010'),
('20260616150006'),
('20260616150001'),
('20260612000001'),
('20260611150001'),
('20260611100200'),
('20260606120001'),
('20260603130002'),
('20260603123002'),
('20260603122002'),
('20260603121002'),
('20260603120002'),
('20260530031000'),
('20260528183002'),
('20260528162102'),
('20260526120102'),
('20260526120002'),
('20260525233000'),
('20260525210000'),
('20260525200500'),
('20260525200000'),
('20260525131500'),
('20260525124500'),
('20260525123000'),
('20260520190002'),
('20260520143006'),
('20260520130001'),
('20260519111001'),
('20260519110001'),
('20260519092001'),
('20260519091001'),
('20260519090001'),
('20260518085549'),
('20260518084935'),
('20260518044439'),
('20260518020002'),
('20260517120002'),
('20260514110000'),
('20260513161542'),
('20260513130000'),
('20260510195945'),
('20260508160000'),
('20260508151000'),
('20260508140999'),
('20260508135006'),
('20260507010003'),
('20260501000000');

