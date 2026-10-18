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
-- Name: enforce_client_auth_email_otp_proof(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_client_auth_email_otp_proof() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF OLD.email_otp_context->>'verified_at' IS NOT NULL AND NEW.email_otp_context IS DISTINCT FROM OLD.email_otp_context THEN RAISE EXCEPTION 'committed email OTP proof is immutable'; END IF; RETURN NEW; END; $$;


--
-- Name: enforce_client_email_terminal_otp_facts(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_client_email_terminal_otp_facts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF (OLD.otp_consumed_at IS NOT NULL OR OLD.otp_cancelled_at IS NOT NULL) AND ROW(NEW.purpose, NEW.otp_generation, NEW.otp_verifier, NEW.otp_expires_at, NEW.otp_consumed_at, NEW.otp_cancelled_at, NEW.otp_receipt_verifier, NEW.otp_result_expires_at, NEW.surface, NEW.transaction_id, NEW.actor_ref, NEW.session_ref, NEW.operation, NEW.expires_at, NEW.email_candidate_ref, NEW.normalized_email_digest, NEW.bootstrap_ceremony_transaction_ref) IS DISTINCT FROM ROW(OLD.purpose, OLD.otp_generation, OLD.otp_verifier, OLD.otp_expires_at, OLD.otp_consumed_at, OLD.otp_cancelled_at, OLD.otp_receipt_verifier, OLD.otp_result_expires_at, OLD.surface, OLD.transaction_id, OLD.actor_ref, OLD.session_ref, OLD.operation, OLD.expires_at, OLD.email_candidate_ref, OLD.normalized_email_digest, OLD.bootstrap_ceremony_transaction_ref) THEN RAISE EXCEPTION 'terminal OTP facts are immutable'; END IF; RETURN NEW; END; $$;


--
-- Name: enforce_client_telephone_terminal_otp_facts(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_client_telephone_terminal_otp_facts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF (OLD.otp_consumed_at IS NOT NULL OR OLD.otp_cancelled_at IS NOT NULL) AND ROW(NEW.purpose, NEW.otp_generation, NEW.otp_verifier, NEW.otp_expires_at, NEW.otp_consumed_at, NEW.otp_cancelled_at, NEW.otp_receipt_verifier, NEW.otp_result_expires_at, NEW.surface, NEW.transaction_id, NEW.actor_ref, NEW.session_ref, NEW.operation, NEW.expires_at, NEW.telephone_candidate_ref, NEW.normalized_number_digest) IS DISTINCT FROM ROW(OLD.purpose, OLD.otp_generation, OLD.otp_verifier, OLD.otp_expires_at, OLD.otp_consumed_at, OLD.otp_cancelled_at, OLD.otp_receipt_verifier, OLD.otp_result_expires_at, OLD.surface, OLD.transaction_id, OLD.actor_ref, OLD.session_ref, OLD.operation, OLD.expires_at, OLD.telephone_candidate_ref, OLD.normalized_number_digest) THEN RAISE EXCEPTION 'terminal OTP facts are immutable'; END IF; RETURN NEW; END; $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: acme_logout_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.acme_logout_transactions (
    id bigint NOT NULL,
    public_id character varying NOT NULL,
    origin_surface character varying NOT NULL,
    initiating_client_id character varying NOT NULL,
    completion_url text NOT NULL,
    actor_ref character varying,
    session_ref character varying,
    callback_state character varying,
    status character varying DEFAULT 'initiated'::character varying NOT NULL,
    expected_step character varying DEFAULT 'origin_cleared'::character varying NOT NULL,
    completed_steps jsonb DEFAULT '[]'::jsonb NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    finalized_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    workflow character varying DEFAULT 'legacy'::character varying NOT NULL,
    binding_version integer DEFAULT 0 NOT NULL,
    realm character varying,
    parent_session_ref character varying,
    captured_root_ref character varying,
    root_refresh_family_ref character varying,
    captured_root_generation integer,
    origin_intent_digest bytea,
    CONSTRAINT acme_logout_transactions_binding_version CHECK ((binding_version = ANY (ARRAY[0, 1]))),
    CONSTRAINT acme_logout_transactions_browser_rp_binding_shape CHECK (((binding_version = 0) OR (((realm)::text = ANY ((ARRAY['app'::character varying, 'com'::character varying, 'org'::character varying])::text[])) AND (NULLIF(btrim((parent_session_ref)::text), ''::text) IS NOT NULL) AND (NULLIF(btrim((captured_root_ref)::text), ''::text) IS NOT NULL) AND (NULLIF(btrim((root_refresh_family_ref)::text), ''::text) IS NOT NULL) AND (captured_root_generation >= 0) AND (origin_intent_digest IS NOT NULL) AND (octet_length(origin_intent_digest) = 32)))),
    CONSTRAINT acme_logout_transactions_public_id_max_length CHECK ((char_length((public_id)::text) <= 25))
);


--
-- Name: acme_logout_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.acme_logout_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: acme_logout_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.acme_logout_transactions_id_seq OWNED BY public.acme_logout_transactions.id;


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
-- Name: client_auth_admission_bindings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_auth_admission_bindings (
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
    CONSTRAINT client_admission_bindings_auth_proof_pair CHECK ((((auth_ceremony_session_id IS NULL) AND (confirmation_ref IS NULL)) OR ((auth_ceremony_session_id IS NOT NULL) AND (confirmation_ref IS NOT NULL)))),
    CONSTRAINT client_admission_bindings_confirmation_requires_auth CHECK (((base_confirmed_at IS NULL) OR ((auth_ceremony_session_id IS NOT NULL) AND (confirmation_ref IS NOT NULL)))),
    CONSTRAINT client_admission_bindings_one_parent CHECK ((num_nonnulls(sign_in_flow_id, authorization_transaction_id, step_up_ceremony_transaction_id) = 1)),
    CONSTRAINT client_admission_bindings_parent_purpose CHECK ((((sign_in_flow_id IS NULL) OR ((purpose)::text = ANY ((ARRAY['local_sign_in'::character varying, 'local_sign_up'::character varying])::text[]))) AND ((authorization_transaction_id IS NULL) OR ((purpose)::text = ANY ((ARRAY['authentication_handoff'::character varying, 'invitation_handoff'::character varying])::text[]))) AND ((step_up_ceremony_transaction_id IS NULL) OR ((purpose)::text = ANY ((ARRAY['step_up_handoff'::character varying, 'reauthentication_handoff'::character varying, 'bootstrap_handoff'::character varying, 'credential_registration_handoff'::character varying, 'credential_change_handoff'::character varying])::text[]))))),
    CONSTRAINT client_admission_bindings_redemption_pair CHECK ((((redeemed_at IS NULL) AND (admitted_auth_ceremony_session_id IS NULL)) OR ((redeemed_at IS NOT NULL) AND (admitted_auth_ceremony_session_id IS NOT NULL)))),
    CONSTRAINT client_admission_bindings_redemption_requires_confirmation CHECK (((redeemed_at IS NULL) OR (base_confirmed_at IS NOT NULL))),
    CONSTRAINT client_admission_bindings_step_up_token CHECK ((((purpose)::text <> ALL ((ARRAY['step_up_handoff'::character varying, 'reauthentication_handoff'::character varying, 'bootstrap_handoff'::character varying, 'credential_registration_handoff'::character varying, 'credential_change_handoff'::character varying])::text[])) OR (base_token_id IS NOT NULL))),
    CONSTRAINT client_admission_bindings_terminal_exclusive CHECK ((NOT ((redeemed_at IS NOT NULL) AND (retired_at IS NOT NULL))))
);


--
-- Name: client_auth_admission_bindings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_auth_admission_bindings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_auth_admission_bindings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_auth_admission_bindings_id_seq OWNED BY public.client_auth_admission_bindings.id;


--
-- Name: client_auth_ceremony_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_auth_ceremony_sessions (
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
    email_otp_context jsonb,
    CONSTRAINT client_auth_admission_purpose_valid CHECK (((admission_purpose IS NULL) OR ((admission_purpose)::text = ANY ((ARRAY['local_sign_in'::character varying, 'local_sign_up'::character varying, 'authentication_handoff'::character varying, 'invitation_handoff'::character varying, 'step_up_handoff'::character varying, 'reauthentication_handoff'::character varying, 'bootstrap_handoff'::character varying, 'credential_registration_handoff'::character varying, 'credential_change_handoff'::character varying])::text[])))),
    CONSTRAINT client_auth_ceremony_purpose_exclusive CHECK ((num_nonnulls(authorization_transaction_ref, local_sign_in_flow_ref, local_sign_up_flow_ref) <= 1)),
    CONSTRAINT client_auth_ceremony_sessions_admission_binding CHECK (((authorization_transaction_ref IS NULL) OR (admitted_at IS NOT NULL))),
    CONSTRAINT client_auth_ceremony_sessions_authentication_evidence_pair CHECK (((authentication_method IS NULL) = (authentication_event_at IS NULL))),
    CONSTRAINT client_auth_ceremony_sessions_authentication_method CHECK (((authentication_method IS NULL) OR ((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'totp'::character varying, 'google'::character varying, 'apple'::character varying, 'entra'::character varying])::text[])))),
    CONSTRAINT client_auth_ceremony_sessions_one_terminal_timestamp CHECK ((num_nonnulls(revoked_at, completed_at, cancelled_at) <= 1)),
    CONSTRAINT client_auth_ceremony_transaction_exclusive CHECK ((num_nonnulls(authorization_transaction_ref, local_sign_in_flow_ref, local_sign_up_flow_ref, step_up_ceremony_transaction_ref) <= 1)),
    CONSTRAINT client_auth_email_otp_context_shape CHECK (((email_otp_context IS NULL) OR (((jsonb_typeof(email_otp_context) = 'object'::text) AND (email_otp_context ?& ARRAY['version'::text, 'generation'::text, 'surface'::text, 'purpose'::text, 'sid_digest'::text, 'parent_kind'::text, 'parent_ref'::text, 'mode'::text, 'contact_ref'::text, 'owner_ref'::text, 'destination_digest'::text, 'binding_fact'::text, 'code_digest'::text, 'issued_at'::text, 'expires_at'::text, 'verified_at'::text, 'result_expires_at'::text]) AND ((email_otp_context -> 'version'::text) = '1'::jsonb) AND ((email_otp_context ->> 'generation'::text) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'::text) AND ((email_otp_context ->> 'mode'::text) = ANY (ARRAY['real'::text, 'fake'::text])) AND ((email_otp_context ->> 'code_digest'::text) ~ '^[0-9a-f]{64}$'::text) AND (jsonb_typeof((email_otp_context -> 'issued_at'::text)) = 'string'::text) AND (jsonb_typeof((email_otp_context -> 'expires_at'::text)) = 'string'::text) AND ((((email_otp_context -> 'verified_at'::text) = 'null'::jsonb) AND ((email_otp_context -> 'result_expires_at'::text) = 'null'::jsonb)) OR ((jsonb_typeof((email_otp_context -> 'verified_at'::text)) = 'string'::text) AND (jsonb_typeof((email_otp_context -> 'result_expires_at'::text)) = 'string'::text)))) IS TRUE)))
);


--
-- Name: client_auth_ceremony_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_auth_ceremony_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_auth_ceremony_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_auth_ceremony_sessions_id_seq OWNED BY public.client_auth_ceremony_sessions.id;


--
-- Name: client_device_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_device_sessions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    user_id bigint NOT NULL,
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
-- Name: client_device_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_device_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_device_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_device_sessions_id_seq OWNED BY public.client_device_sessions.id;


--
-- Name: client_dpop_proof_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_dpop_proof_states (
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
-- Name: client_dpop_proof_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_dpop_proof_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_dpop_proof_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_dpop_proof_states_id_seq OWNED BY public.client_dpop_proof_states.id;


--
-- Name: client_email_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_email_ceremony_transactions (
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
    CONSTRAINT client_email_ceremony_transactions_otp_material CHECK (((otp_verifier IS NULL) OR ((purpose IS NOT NULL) AND (otp_generation IS NOT NULL) AND (otp_expires_at IS NOT NULL)))),
    CONSTRAINT client_email_ceremony_transactions_otp_purpose CHECK (((purpose IS NULL) OR ((purpose)::text = ANY ((ARRAY['sign_up'::character varying, 'sign_in'::character varying, 'recovery'::character varying, 'withdrawal'::character varying, 'credential_registration'::character varying])::text[])))),
    CONSTRAINT client_email_otp_bootstrap_purpose CHECK (((bootstrap_ceremony_transaction_ref IS NULL) OR (((operation)::text = 'registration'::text) AND (purpose IS NOT NULL) AND ((purpose)::text = 'credential_registration'::text)))),
    CONSTRAINT client_email_otp_proof_shape CHECK (((otp_generation IS NULL) OR (((purpose IS NOT NULL) AND ((actor_ref)::text <> ''::text) AND ((session_ref)::text <> ''::text) AND (email_candidate_ref IS NOT NULL) AND ((email_candidate_ref)::text <> ''::text) AND ((normalized_email_digest IS NULL) OR ((normalized_email_digest)::text ~ '^[0-9a-f]{64}$'::text)) AND (otp_expires_at IS NOT NULL) AND isfinite(otp_expires_at) AND isfinite(expires_at) AND (((otp_consumed_at IS NULL) AND (otp_cancelled_at IS NULL) AND (otp_verifier IS NOT NULL) AND ((otp_verifier)::text ~ '^[0-9a-f]{64}$'::text) AND (otp_receipt_verifier IS NULL) AND (otp_result_expires_at IS NULL)) OR ((otp_consumed_at IS NOT NULL) AND isfinite(otp_consumed_at) AND (otp_consumed_at < otp_expires_at) AND (otp_cancelled_at IS NULL) AND (otp_verifier IS NULL) AND (otp_receipt_verifier IS NOT NULL) AND (otp_result_expires_at IS NOT NULL)) OR ((otp_cancelled_at IS NOT NULL) AND isfinite(otp_cancelled_at) AND (otp_consumed_at IS NULL) AND (otp_verifier IS NULL) AND (otp_receipt_verifier IS NULL) AND (otp_result_expires_at IS NULL)))) IS TRUE))),
    CONSTRAINT client_email_otp_receipt_bounds CHECK ((((otp_receipt_verifier IS NULL) AND (otp_result_expires_at IS NULL)) OR ((otp_receipt_verifier IS NOT NULL) AND ((otp_receipt_verifier)::text ~ '^[0-9a-f]{64}$'::text) AND (otp_consumed_at IS NOT NULL) AND (otp_cancelled_at IS NULL) AND (otp_verifier IS NULL) AND (otp_result_expires_at IS NOT NULL) AND isfinite(otp_result_expires_at) AND (otp_result_expires_at > otp_consumed_at) AND (otp_result_expires_at <= (otp_consumed_at + '00:01:00'::interval)) AND (otp_result_expires_at <= expires_at))))
);


--
-- Name: client_email_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_email_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_email_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_email_ceremony_transactions_id_seq OWNED BY public.client_email_ceremony_transactions.id;


--
-- Name: client_emergency_sign_in_operations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_emergency_sign_in_operations (
    id bigint NOT NULL,
    operation_id uuid NOT NULL,
    credential_public_id character varying(21) CONSTRAINT client_emergency_sign_in_operatio_credential_public_id_not_null NOT NULL,
    client_token_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_emergency_sign_in_operations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_emergency_sign_in_operations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_emergency_sign_in_operations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_emergency_sign_in_operations_id_seq OWNED BY public.client_emergency_sign_in_operations.id;


--
-- Name: client_oauth_callback_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_oauth_callback_states (
    id bigint CONSTRAINT client_social_callback_states_id_not_null NOT NULL,
    state_digest character varying CONSTRAINT client_social_callback_states_state_digest_not_null NOT NULL,
    provider character varying CONSTRAINT client_social_callback_states_provider_not_null NOT NULL,
    intent character varying,
    issued_at timestamp(6) with time zone CONSTRAINT client_social_callback_states_issued_at_not_null NOT NULL,
    expires_at timestamp(6) with time zone CONSTRAINT client_social_callback_states_expires_at_not_null NOT NULL,
    consumed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone CONSTRAINT client_social_callback_states_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT client_social_callback_states_updated_at_not_null NOT NULL
);


--
-- Name: client_oauth_callback_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_oauth_callback_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_oauth_callback_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_oauth_callback_states_id_seq OWNED BY public.client_oauth_callback_states.id;


--
-- Name: client_oidc_authorization_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_oidc_authorization_transactions (
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
    code_challenge_method character varying CONSTRAINT client_oidc_authorization_transa_code_challenge_method_not_null NOT NULL,
    login_challenge character varying NOT NULL,
    login_challenge_expires_at timestamp(6) with time zone CONSTRAINT client_oidc_authorization_t_login_challenge_expires_at_not_null NOT NULL,
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
    result_generation integer DEFAULT 0 CONSTRAINT client_oidc_authorization_transactio_result_generation_not_null NOT NULL,
    result_digest character varying(64),
    result_expires_at timestamp(6) with time zone,
    result_consumed_at timestamp(6) with time zone,
    browser_session_ref character varying,
    base_finalized_at timestamp(6) with time zone,
    authorization_grant_redeemed_at timestamp(6) with time zone,
    secret_sign_in_flow_id bigint,
    contract_epoch bigint,
    CONSTRAINT chk_client_oidc_authorization_transactions_contract_epoch CHECK (((contract_epoch IS NULL) OR (contract_epoch >= 1))),
    CONSTRAINT client_oidc_auth_transactions_result_generation_nonnegative CHECK ((result_generation >= 0))
);


--
-- Name: client_oidc_authorization_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_oidc_authorization_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_oidc_authorization_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_oidc_authorization_transactions_id_seq OWNED BY public.client_oidc_authorization_transactions.id;


--
-- Name: client_oidc_connections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_oidc_connections (
    id bigint CONSTRAINT user_oidc_connections_id_not_null NOT NULL,
    public_id character varying(21) CONSTRAINT user_oidc_connections_public_id_not_null NOT NULL,
    user_id bigint CONSTRAINT user_oidc_connections_user_id_not_null NOT NULL,
    client_id character varying(64) CONSTRAINT user_oidc_connections_client_id_not_null NOT NULL,
    scope character varying,
    last_used_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone CONSTRAINT user_oidc_connections_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_oidc_connections_updated_at_not_null NOT NULL
);


--
-- Name: client_oidc_connections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_oidc_connections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_oidc_connections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_oidc_connections_id_seq OWNED BY public.client_oidc_connections.id;


--
-- Name: client_passkey_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_passkey_ceremony_transactions (
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
-- Name: client_passkey_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_passkey_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_passkey_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_passkey_ceremony_transactions_id_seq OWNED BY public.client_passkey_ceremony_transactions.id;


--
-- Name: client_secret_credential_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_secret_credential_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying CONSTRAINT client_secret_credential_ceremony_trans_transaction_id_not_null NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying CONSTRAINT client_secret_credential_ceremony_transactio_actor_ref_not_null NOT NULL,
    session_ref character varying CONSTRAINT client_secret_credential_ceremony_transact_session_ref_not_null NOT NULL,
    operation character varying CONSTRAINT client_secret_credential_ceremony_transactio_operation_not_null NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying CONSTRAINT client_secret_credential_ceremony_transactio_grant_jti_not_null NOT NULL,
    result_jti character varying,
    credential_candidate_ref character varying,
    credential_candidate_digest character varying,
    expires_at timestamp(6) with time zone CONSTRAINT client_secret_credential_ceremony_transacti_expires_at_not_null NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 CONSTRAINT client_secret_credential_ceremony_transac_lock_version_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT client_secret_credential_ceremony_transacti_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT client_secret_credential_ceremony_transacti_updated_at_not_null NOT NULL
);


--
-- Name: client_secret_credential_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_secret_credential_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_secret_credential_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_secret_credential_ceremony_transactions_id_seq OWNED BY public.client_secret_credential_ceremony_transactions.id;


--
-- Name: client_secret_sign_in_receipts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_secret_sign_in_receipts (
    id bigint NOT NULL,
    operation_id uuid NOT NULL,
    credential_ref character varying(21) NOT NULL,
    client_ref character varying(21) NOT NULL,
    sign_in_flow_id bigint NOT NULL,
    root_token_ref character varying(21) NOT NULL,
    committed_at timestamp(6) with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_secret_sign_in_receipts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_secret_sign_in_receipts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_secret_sign_in_receipts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_secret_sign_in_receipts_id_seq OWNED BY public.client_secret_sign_in_receipts.id;


--
-- Name: client_session_limit_resolution_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_session_limit_resolution_states (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_session_limit_resolution_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_session_limit_resolution_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_session_limit_resolution_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_session_limit_resolution_states_id_seq OWNED BY public.client_session_limit_resolution_states.id;


--
-- Name: client_session_limit_resolution_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_session_limit_resolution_transactions (
    id bigint NOT NULL,
    challenge_digest character varying CONSTRAINT client_session_limit_resolution_trans_challenge_digest_not_null NOT NULL,
    actor_ref character varying NOT NULL,
    oidc_authorization_transaction_id bigint,
    selected_session_ref character varying,
    expires_at timestamp(6) with time zone CONSTRAINT client_session_limit_resolution_transaction_expires_at_not_null NOT NULL,
    selected_at timestamp(6) with time zone,
    resolved_at timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    consumed_at timestamp(6) with time zone,
    finalized_at timestamp(6) with time zone,
    audit_context jsonb DEFAULT '{}'::jsonb CONSTRAINT client_session_limit_resolution_transact_audit_context_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT client_session_limit_resolution_transaction_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT client_session_limit_resolution_transaction_updated_at_not_null NOT NULL,
    state_id bigint NOT NULL,
    sign_in_flow_id bigint CONSTRAINT client_session_limit_resolution_transa_sign_in_flow_id_not_null NOT NULL,
    browser_binding_digest character varying CONSTRAINT client_session_limit_resolution_browser_binding_digest_not_null NOT NULL,
    started_at timestamp(6) with time zone CONSTRAINT client_session_limit_resolution_transaction_started_at_not_null NOT NULL,
    expired_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp without time zone CONSTRAINT client_session_limit_resolution_transaction_discard_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp without time zone CONSTRAINT client_session_limit_resolution_tran_purge_eligible_at_not_null NOT NULL,
    waiting_slot smallint,
    CONSTRAINT chk_client_resolution_state_timestamps CHECK ((((state_id = 10) AND (selected_at IS NULL) AND (resolved_at IS NULL) AND (cancelled_at IS NULL) AND (expired_at IS NULL)) OR ((state_id = 20) AND (selected_at IS NOT NULL) AND (resolved_at IS NULL) AND (cancelled_at IS NULL) AND (expired_at IS NULL)) OR ((state_id = 100) AND (resolved_at IS NOT NULL) AND (cancelled_at IS NULL) AND (expired_at IS NULL)) OR ((state_id = 910) AND (expired_at IS NOT NULL) AND (resolved_at IS NULL) AND (cancelled_at IS NULL)) OR ((state_id = 920) AND (cancelled_at IS NOT NULL) AND (resolved_at IS NULL) AND (expired_at IS NULL)))),
    CONSTRAINT chk_client_resolution_waiting_slot_state CHECK ((((state_id = ANY (ARRAY[(10)::bigint, (20)::bigint])) AND (waiting_slot IS NOT NULL) AND (waiting_slot = 1)) OR ((state_id = ANY (ARRAY[(100)::bigint, (910)::bigint, (920)::bigint])) AND (waiting_slot IS NULL))))
);


--
-- Name: client_session_limit_resolution_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_session_limit_resolution_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_session_limit_resolution_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_session_limit_resolution_transactions_id_seq OWNED BY public.client_session_limit_resolution_transactions.id;


--
-- Name: client_sign_in_flow_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_sign_in_flow_states (
    id bigint CONSTRAINT client_sign_in_cycle_statuses_id_not_null NOT NULL
);


--
-- Name: client_sign_in_flow_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_sign_in_flow_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_sign_in_flow_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_sign_in_flow_states_id_seq OWNED BY public.client_sign_in_flow_states.id;


--
-- Name: client_sign_in_flows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_sign_in_flows (
    id bigint CONSTRAINT app_sign_in_sequence_tickets_id_not_null NOT NULL,
    public_id character varying(21) CONSTRAINT app_sign_in_sequence_tickets_public_id_not_null NOT NULL,
    principal_id bigint,
    token_id bigint,
    return_to text,
    nonce_digest character varying CONSTRAINT app_sign_in_sequence_tickets_nonce_digest_not_null NOT NULL,
    issued_at timestamp(6) with time zone CONSTRAINT app_sign_in_sequence_tickets_issued_at_not_null NOT NULL,
    expires_at timestamp(6) with time zone CONSTRAINT app_sign_in_sequence_tickets_expires_at_not_null NOT NULL,
    completed_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT app_sign_in_sequence_tickets_discarded_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT app_sign_in_sequence_tickets_purged_at_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT app_sign_in_sequence_tickets_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT app_sign_in_sequence_tickets_updated_at_not_null NOT NULL,
    state_id bigint DEFAULT 10 CONSTRAINT app_sign_in_cycles_status_id_not_null NOT NULL,
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
    CONSTRAINT chk_app_sign_in_sequence_tickets_lifetime_order CHECK ((issued_at < expires_at)),
    CONSTRAINT chk_app_sign_in_sequence_tickets_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT chk_client_sign_in_flows_state_completed_at CHECK (((state_id = 100) = (completed_at IS NOT NULL))),
    CONSTRAINT client_local_authentication_context_valid CHECK (((authentication_context IS NULL) OR ((authentication_context)::text = ANY ((ARRAY['normal'::character varying, 'standby'::character varying])::text[])))),
    CONSTRAINT client_sign_in_flows_authentication_evidence_valid CHECK ((((authentication_method IS NULL) AND (authentication_event_at IS NULL)) OR (((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'totp'::character varying, 'google'::character varying, 'apple'::character varying, 'entra'::character varying])::text[])) AND (authentication_event_at IS NOT NULL) AND (principal_id IS NOT NULL)))),
    CONSTRAINT client_sign_in_flows_base_finalization_valid CHECK (((base_finalized_at IS NULL) OR ((token_id IS NOT NULL) AND (result_digest IS NOT NULL)))),
    CONSTRAINT client_sign_in_flows_evidence_complete CHECK (((authentication_event_at IS NULL) OR (authentication_method IS NOT NULL))),
    CONSTRAINT client_sign_in_flows_result_complete CHECK (((result_generation = 0) OR ((result_digest IS NOT NULL) AND (result_expires_at IS NOT NULL) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT client_sign_in_flows_result_delivery_valid CHECK ((((result_digest IS NULL) AND (result_expires_at IS NULL) AND (result_generation = 0)) OR ((length((result_digest)::text) = 64) AND (result_expires_at IS NOT NULL) AND (result_generation > 0) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT client_sign_in_flows_result_generation_valid CHECK ((result_generation >= 0))
);


--
-- Name: client_sign_in_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_sign_in_flows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_sign_in_flows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_sign_in_flows_id_seq OWNED BY public.client_sign_in_flows.id;


--
-- Name: client_sign_out_flow_kinds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_sign_out_flow_kinds (
    id bigint CONSTRAINT client_sign_out_cycle_kinds_id_not_null NOT NULL
);


--
-- Name: client_sign_out_flow_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_sign_out_flow_kinds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_sign_out_flow_kinds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_sign_out_flow_kinds_id_seq OWNED BY public.client_sign_out_flow_kinds.id;


--
-- Name: client_sign_out_flow_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_sign_out_flow_statuses (
    id bigint CONSTRAINT client_sign_out_cycle_statuses_id_not_null NOT NULL
);


--
-- Name: client_sign_out_flow_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_sign_out_flow_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_sign_out_flow_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_sign_out_flow_statuses_id_seq OWNED BY public.client_sign_out_flow_statuses.id;


--
-- Name: client_sign_out_flows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_sign_out_flows (
    id bigint CONSTRAINT client_sign_out_cycles_id_not_null NOT NULL,
    public_id character varying(21) CONSTRAINT client_sign_out_cycles_public_id_not_null NOT NULL,
    principal_id bigint,
    token_id bigint,
    status_id bigint DEFAULT 10 CONSTRAINT client_sign_out_cycles_status_id_not_null NOT NULL,
    kind_id bigint DEFAULT 0 CONSTRAINT client_sign_out_cycles_kind_id_not_null NOT NULL,
    refresh_token_family_id character varying,
    requested_at timestamp(6) with time zone CONSTRAINT client_sign_out_cycles_requested_at_not_null NOT NULL,
    access_discarded_at timestamp(6) with time zone,
    logically_revoked_at timestamp(6) with time zone,
    access_expires_at timestamp(6) with time zone CONSTRAINT client_sign_out_cycles_access_expires_at_not_null NOT NULL,
    refresh_expires_at timestamp(6) with time zone CONSTRAINT client_sign_out_cycles_refresh_expires_at_not_null NOT NULL,
    completed_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    return_to text,
    nonce_digest character varying,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT client_sign_out_cycles_discarded_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT client_sign_out_cycles_purged_at_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT client_sign_out_cycles_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT client_sign_out_cycles_updated_at_not_null NOT NULL,
    CONSTRAINT chk_client_sign_out_cycles_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT chk_client_sign_out_cycles_token_expiry_order CHECK ((access_expires_at <= refresh_expires_at))
);


--
-- Name: client_sign_out_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_sign_out_flows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_sign_out_flows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_sign_out_flows_id_seq OWNED BY public.client_sign_out_flows.id;


--
-- Name: client_sign_up_flow_cleanup_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_sign_up_flow_cleanup_statuses (
    id bigint CONSTRAINT client_sign_up_cycle_cleanup_statuses_id_not_null NOT NULL
);


--
-- Name: client_sign_up_flow_cleanup_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_sign_up_flow_cleanup_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_sign_up_flow_cleanup_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_sign_up_flow_cleanup_statuses_id_seq OWNED BY public.client_sign_up_flow_cleanup_statuses.id;


--
-- Name: client_sign_up_flow_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_sign_up_flow_statuses (
    id bigint CONSTRAINT client_sign_up_cycle_statuses_id_not_null NOT NULL
);


--
-- Name: client_sign_up_flow_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_sign_up_flow_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_sign_up_flow_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_sign_up_flow_statuses_id_seq OWNED BY public.client_sign_up_flow_statuses.id;


--
-- Name: client_sign_up_flows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_sign_up_flows (
    id bigint CONSTRAINT app_sign_up_sequence_tickets_id_not_null NOT NULL,
    public_id character varying(21) CONSTRAINT app_sign_up_sequence_tickets_public_id_not_null NOT NULL,
    principal_id bigint,
    token_id bigint,
    state character varying CONSTRAINT app_sign_up_sequence_tickets_state_not_null NOT NULL,
    step character varying CONSTRAINT app_sign_up_sequence_tickets_step_not_null NOT NULL,
    return_to text,
    nonce_digest character varying CONSTRAINT app_sign_up_sequence_tickets_nonce_digest_not_null NOT NULL,
    issued_at timestamp(6) with time zone CONSTRAINT app_sign_up_sequence_tickets_issued_at_not_null NOT NULL,
    expires_at timestamp(6) with time zone CONSTRAINT app_sign_up_sequence_tickets_expires_at_not_null NOT NULL,
    completed_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT app_sign_up_sequence_tickets_discarded_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT app_sign_up_sequence_tickets_purged_at_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT app_sign_up_sequence_tickets_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT app_sign_up_sequence_tickets_updated_at_not_null NOT NULL,
    status_id bigint DEFAULT 10 CONSTRAINT app_sign_up_cycles_status_id_not_null NOT NULL,
    entry_method character varying NOT NULL,
    pending_contact_type character varying,
    pending_contact_id bigint,
    social_provider character varying,
    completed_requirements jsonb DEFAULT '{}'::jsonb CONSTRAINT app_sign_up_cycles_completed_requirements_not_null NOT NULL,
    failed_at timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    checkpoint_version integer DEFAULT 0 CONSTRAINT client_sign_up_cycles_checkpoint_version_not_null NOT NULL,
    cleanup_attempted_at timestamp(6) with time zone,
    cleanup_completed_at timestamp(6) with time zone,
    cleanup_error_code character varying,
    pending_passkey_registration_id bigint,
    cleanup_attempts_count integer DEFAULT 0 CONSTRAINT client_sign_up_cycles_cleanup_attempts_count_not_null NOT NULL,
    cleanup_status_id bigint DEFAULT 10 CONSTRAINT client_sign_up_cycles_cleanup_status_id_not_null NOT NULL,
    result_digest character varying(64),
    result_generation integer DEFAULT 0 NOT NULL,
    result_expires_at timestamp(6) with time zone,
    base_finalized_at timestamp(6) with time zone,
    authentication_method character varying,
    authentication_event_at timestamp(6) with time zone,
    CONSTRAINT chk_app_sign_up_sequence_tickets_lifetime_order CHECK ((issued_at < expires_at)),
    CONSTRAINT chk_app_sign_up_sequence_tickets_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT client_sign_up_flows_authentication_evidence_valid CHECK ((((authentication_method IS NULL) AND (authentication_event_at IS NULL)) OR (((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'totp'::character varying, 'google'::character varying, 'apple'::character varying, 'entra'::character varying])::text[])) AND (authentication_event_at IS NOT NULL) AND (principal_id IS NOT NULL)))),
    CONSTRAINT client_sign_up_flows_base_finalization_valid CHECK (((base_finalized_at IS NULL) OR ((token_id IS NOT NULL) AND (result_digest IS NOT NULL)))),
    CONSTRAINT client_sign_up_flows_evidence_complete CHECK (((authentication_event_at IS NULL) OR (authentication_method IS NOT NULL))),
    CONSTRAINT client_sign_up_flows_result_complete CHECK (((result_generation = 0) OR ((result_digest IS NOT NULL) AND (result_expires_at IS NOT NULL) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT client_sign_up_flows_result_delivery_valid CHECK ((((result_digest IS NULL) AND (result_expires_at IS NULL) AND (result_generation = 0)) OR ((length((result_digest)::text) = 64) AND (result_expires_at IS NOT NULL) AND (result_generation > 0) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT client_sign_up_flows_result_generation_valid CHECK ((result_generation >= 0))
);


--
-- Name: client_sign_up_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_sign_up_flows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_sign_up_flows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_sign_up_flows_id_seq OWNED BY public.client_sign_up_flows.id;


--
-- Name: client_social_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_social_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    provider character varying NOT NULL,
    resource_ref character varying,
    return_to character varying,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    provider_subject_ref character varying,
    provider_subject_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_social_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_social_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_social_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_social_ceremony_transactions_id_seq OWNED BY public.client_social_ceremony_transactions.id;


--
-- Name: client_step_up_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_step_up_ceremony_transactions (
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
    phishing_resistant_required boolean DEFAULT false CONSTRAINT client_step_up_ceremony_tra_phishing_resistant_require_not_null NOT NULL,
    phishing_resistant boolean DEFAULT false CONSTRAINT client_step_up_ceremony_transaction_phishing_resistant_not_null NOT NULL,
    purpose character varying DEFAULT 'step_up'::character varying NOT NULL,
    result_digest character varying(64),
    result_generation integer DEFAULT 0 NOT NULL,
    result_expires_at timestamp(6) with time zone,
    canceled_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    verified_credential_ref character varying,
    step_up_required boolean DEFAULT true NOT NULL,
    user_verification_required boolean DEFAULT false CONSTRAINT client_step_up_ceremony_tra_user_verification_required_not_null NOT NULL,
    full_reauthentication_required boolean DEFAULT false CONSTRAINT client_step_up_ceremony_tra_full_reauthentication_requ_not_null NOT NULL,
    audience character varying,
    token_binding character varying,
    require_session_binding boolean DEFAULT true CONSTRAINT client_step_up_ceremony_transa_require_session_binding_not_null NOT NULL,
    tenant_ref character varying,
    user_verified boolean,
    cancellation_handoff_digest character varying(64),
    cancellation_handoff_ref uuid,
    cancellation_handoff_ciphertext text,
    CONSTRAINT client_step_up_cancellation_handoff_pair CHECK ((((cancellation_handoff_ref IS NULL) AND (cancellation_handoff_ciphertext IS NULL)) OR ((cancellation_handoff_ref IS NOT NULL) AND (cancellation_handoff_ciphertext IS NOT NULL)))),
    CONSTRAINT client_step_up_cancellation_handoff_valid CHECK (((cancellation_handoff_digest IS NULL) OR ((cancellation_handoff_digest)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT client_step_up_purpose_valid CHECK (((purpose)::text = ANY ((ARRAY['step_up'::character varying, 'reauthentication'::character varying, 'bootstrap'::character varying, 'credential_registration'::character varying, 'credential_change'::character varying])::text[]))),
    CONSTRAINT client_step_up_result_valid CHECK (((result_generation >= 0) AND (((result_digest IS NULL) AND (result_expires_at IS NULL) AND (result_generation = 0)) OR ((result_digest IS NOT NULL) AND ((result_digest)::text ~ '^[0-9a-f]{64}$'::text) AND (result_expires_at IS NOT NULL) AND (result_generation > 0) AND (verified_at IS NOT NULL))))),
    CONSTRAINT client_step_up_status_valid CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'verified'::character varying, 'consumed'::character varying, 'canceled'::character varying, 'expired'::character varying, 'revoked'::character varying])::text[]))),
    CONSTRAINT client_step_up_terminal_valid CHECK ((((canceled_at IS NULL) OR ((status)::text = 'canceled'::text)) AND ((revoked_at IS NULL) OR ((status)::text = 'revoked'::text)) AND (((status)::text <> 'revoked'::text) OR (revoked_at IS NOT NULL)) AND (((status)::text <> 'verified'::text) OR ((verified_at IS NOT NULL) AND (method IS NOT NULL) AND (aal IS NOT NULL))))),
    CONSTRAINT client_step_up_verified_credential_present CHECK ((((status)::text <> 'verified'::text) OR (((purpose)::text = ANY ((ARRAY['bootstrap'::character varying, 'credential_registration'::character varying])::text[])) AND (verified_credential_ref IS NULL) AND ((aal)::text = 'none'::text) AND ((required_aal)::text = 'none'::text) AND (phishing_resistant IS FALSE) AND (phishing_resistant_required IS FALSE) AND ((method)::text = ANY ((ARRAY['passkey'::character varying, 'totp'::character varying])::text[]))) OR (((purpose)::text <> ALL ((ARRAY['bootstrap'::character varying, 'credential_registration'::character varying])::text[])) AND (verified_credential_ref IS NOT NULL) AND (length((verified_credential_ref)::text) > 0))))
);


--
-- Name: client_step_up_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_step_up_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_step_up_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_step_up_ceremony_transactions_id_seq OWNED BY public.client_step_up_ceremony_transactions.id;


--
-- Name: client_step_up_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_step_up_sessions (
    id bigint CONSTRAINT user_reauth_sessions_id_not_null NOT NULL,
    attempt_count integer DEFAULT 0 CONSTRAINT user_reauth_sessions_attempt_count_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_reauth_sessions_created_at_not_null NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT user_reauth_sessions_discarded_at_not_null NOT NULL,
    method character varying,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT user_reauth_sessions_purged_at_not_null NOT NULL,
    return_to text CONSTRAINT user_reauth_sessions_return_to_not_null NOT NULL,
    scope character varying CONSTRAINT user_reauth_sessions_scope_not_null NOT NULL,
    status character varying CONSTRAINT user_reauth_sessions_status_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_reauth_sessions_updated_at_not_null NOT NULL,
    user_token_id bigint CONSTRAINT user_reauth_sessions_user_token_id_not_null NOT NULL,
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
    CONSTRAINT client_step_up_challenge_bound CHECK (((passkey_challenge IS NULL) OR ((step_up_ceremony_transaction_ref IS NOT NULL) AND (passkey_challenge_ref IS NOT NULL) AND (passkey_rp_id IS NOT NULL) AND (passkey_origin IS NOT NULL) AND (passkey_challenge_expires_at IS NOT NULL) AND (passkey_challenge_expires_at <= discard_at)))),
    CONSTRAINT client_step_up_email_generation_valid CHECK ((((email_code_generation = 0) AND (email_credential_ref IS NULL) AND (email_code_digest IS NULL) AND (email_code_issued_at IS NULL) AND (email_code_expires_at IS NULL) AND (email_code_consumed_at IS NULL) AND (email_delivery_state IS NULL)) OR ((email_code_generation > 0) AND (email_credential_ref IS NOT NULL) AND (length((email_credential_ref)::text) > 0) AND (email_code_digest IS NOT NULL) AND ((email_code_digest)::text ~ '^[0-9a-f]{64}$'::text) AND (email_code_issued_at IS NOT NULL) AND (email_code_expires_at IS NOT NULL) AND (email_code_expires_at > email_code_issued_at) AND (email_code_expires_at <= (email_code_issued_at + '00:10:00'::interval)) AND (email_delivery_state IS NOT NULL) AND ((email_delivery_state)::text = ANY ((ARRAY['pending'::character varying, 'delivered'::character varying, 'failed'::character varying])::text[])) AND ((email_code_consumed_at IS NULL) OR (((email_delivery_state)::text = 'delivered'::text) AND (email_code_consumed_at >= email_code_issued_at) AND (email_code_consumed_at < email_code_expires_at))))))
);


--
-- Name: client_step_up_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_step_up_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_step_up_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_step_up_sessions_id_seq OWNED BY public.client_step_up_sessions.id;


--
-- Name: client_telephone_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_telephone_ceremony_transactions (
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
    CONSTRAINT client_telephone_ceremony_transactions_otp_material CHECK (((otp_verifier IS NULL) OR ((purpose IS NOT NULL) AND (otp_generation IS NOT NULL) AND (otp_expires_at IS NOT NULL)))),
    CONSTRAINT client_telephone_ceremony_transactions_otp_purpose CHECK (((purpose IS NULL) OR ((purpose)::text = ANY ((ARRAY['sign_up'::character varying, 'sign_in'::character varying, 'recovery'::character varying, 'withdrawal'::character varying, 'credential_registration'::character varying])::text[])))),
    CONSTRAINT client_telephone_otp_proof_shape CHECK (((otp_generation IS NULL) OR (((purpose IS NOT NULL) AND ((actor_ref)::text <> ''::text) AND ((session_ref)::text <> ''::text) AND (telephone_candidate_ref IS NOT NULL) AND ((telephone_candidate_ref)::text <> ''::text) AND ((normalized_number_digest IS NULL) OR ((normalized_number_digest)::text ~ '^[0-9a-f]{64}$'::text)) AND (otp_expires_at IS NOT NULL) AND isfinite(otp_expires_at) AND isfinite(expires_at) AND (((otp_consumed_at IS NULL) AND (otp_cancelled_at IS NULL) AND (otp_verifier IS NOT NULL) AND ((otp_verifier)::text ~ '^[0-9a-f]{64}$'::text) AND (otp_receipt_verifier IS NULL) AND (otp_result_expires_at IS NULL)) OR ((otp_consumed_at IS NOT NULL) AND isfinite(otp_consumed_at) AND (otp_consumed_at < otp_expires_at) AND (otp_cancelled_at IS NULL) AND (otp_verifier IS NULL) AND (otp_receipt_verifier IS NOT NULL) AND (otp_result_expires_at IS NOT NULL)) OR ((otp_cancelled_at IS NOT NULL) AND isfinite(otp_cancelled_at) AND (otp_consumed_at IS NULL) AND (otp_verifier IS NULL) AND (otp_receipt_verifier IS NULL) AND (otp_result_expires_at IS NULL)))) IS TRUE))),
    CONSTRAINT client_telephone_otp_receipt_bounds CHECK ((((otp_receipt_verifier IS NULL) AND (otp_result_expires_at IS NULL)) OR ((otp_receipt_verifier IS NOT NULL) AND ((otp_receipt_verifier)::text ~ '^[0-9a-f]{64}$'::text) AND (otp_consumed_at IS NOT NULL) AND (otp_cancelled_at IS NULL) AND (otp_verifier IS NULL) AND (otp_result_expires_at IS NOT NULL) AND isfinite(otp_result_expires_at) AND (otp_result_expires_at > otp_consumed_at) AND (otp_result_expires_at <= (otp_consumed_at + '00:01:00'::interval)) AND (otp_result_expires_at <= expires_at))))
);


--
-- Name: client_telephone_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_telephone_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_telephone_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_telephone_ceremony_transactions_id_seq OWNED BY public.client_telephone_ceremony_transactions.id;


--
-- Name: client_token_binding_methods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_token_binding_methods (
    id bigint CONSTRAINT user_token_binding_methods_id_not_null NOT NULL
);


--
-- Name: client_token_binding_methods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_token_binding_methods_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_token_binding_methods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_token_binding_methods_id_seq OWNED BY public.client_token_binding_methods.id;


--
-- Name: client_token_dbsc_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_token_dbsc_statuses (
    id bigint CONSTRAINT user_token_dbsc_statuses_id_not_null NOT NULL
);


--
-- Name: client_token_dbsc_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_token_dbsc_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_token_dbsc_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_token_dbsc_statuses_id_seq OWNED BY public.client_token_dbsc_statuses.id;


--
-- Name: client_token_kinds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_token_kinds (
    id bigint CONSTRAINT user_token_kinds_id_not_null NOT NULL
);


--
-- Name: client_token_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_token_kinds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_token_kinds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_token_kinds_id_seq OWNED BY public.client_token_kinds.id;


--
-- Name: client_token_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_token_statuses (
    id bigint CONSTRAINT user_token_statuses_id_not_null NOT NULL
);


--
-- Name: client_token_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_token_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_token_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_token_statuses_id_seq OWNED BY public.client_token_statuses.id;


--
-- Name: client_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_tokens (
    id bigint CONSTRAINT user_tokens_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_tokens_created_at_not_null NOT NULL,
    dbsc_challenge text,
    dbsc_challenge_issued_at timestamp(6) with time zone,
    dbsc_public_key jsonb,
    dbsc_session_id character varying,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT user_tokens_deletable_at_not_null NOT NULL,
    last_step_up_at timestamp(6) with time zone,
    last_step_up_scope character varying,
    last_used_at timestamp(6) with time zone,
    public_id character varying(21) DEFAULT ''::character varying CONSTRAINT user_tokens_public_id_not_null NOT NULL,
    refresh_token_digest bytea,
    refresh_token_family_id character varying,
    refresh_token_generation integer DEFAULT 0 CONSTRAINT user_tokens_refresh_token_generation_not_null NOT NULL,
    rotated_at timestamp(6) with time zone,
    updated_at timestamp(6) with time zone CONSTRAINT user_tokens_updated_at_not_null NOT NULL,
    user_id bigint CONSTRAINT user_tokens_user_id_not_null NOT NULL,
    user_token_binding_method_id bigint DEFAULT 0 CONSTRAINT user_tokens_user_token_binding_method_id_not_null NOT NULL,
    user_token_dbsc_status_id bigint DEFAULT 0 CONSTRAINT user_tokens_user_token_dbsc_status_id_not_null NOT NULL,
    user_token_kind_id bigint DEFAULT 11 CONSTRAINT user_tokens_user_token_kind_id_not_null NOT NULL,
    user_token_status_id bigint DEFAULT 1 CONSTRAINT user_tokens_user_token_status_id_not_null NOT NULL,
    dpop_jkt character varying,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT user_tokens_discarded_at_not_null NOT NULL,
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
    selected_avatar_public_id character varying,
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
    contract_epoch bigint,
    authentication_epoch bigint,
    CONSTRAINT chk_client_tokens_authentication_epoch CHECK (((authentication_epoch IS NULL) OR (authentication_epoch >= 0))),
    CONSTRAINT chk_client_tokens_contract_epoch CHECK (((contract_epoch IS NULL) OR (contract_epoch >= 1))),
    CONSTRAINT chk_client_tokens_established_authentication_method CHECK (((established_authentication_method IS NULL) OR ((established_authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'totp'::character varying, 'google'::character varying, 'apple'::character varying])::text[])))),
    CONSTRAINT chk_user_tokens_kind_id_positive CHECK ((user_token_kind_id >= 0)),
    CONSTRAINT chk_user_tokens_status_id_positive CHECK ((user_token_status_id >= 0))
);


--
-- Name: client_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_tokens_id_seq OWNED BY public.client_tokens.id;


--
-- Name: client_totp_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_totp_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
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
-- Name: client_totp_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_totp_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_totp_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_totp_ceremony_transactions_id_seq OWNED BY public.client_totp_ceremony_transactions.id;


--
-- Name: client_verifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_verifications (
    id bigint CONSTRAINT user_verifications_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_verifications_created_at_not_null NOT NULL,
    last_used_at timestamp(6) with time zone,
    token_digest character varying CONSTRAINT user_verifications_token_digest_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_verifications_updated_at_not_null NOT NULL,
    user_token_id bigint CONSTRAINT user_verifications_user_token_id_not_null NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT user_verifications_discarded_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT user_verifications_purged_at_not_null NOT NULL,
    CONSTRAINT chk_user_verifications_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: client_verifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_verifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_verifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_verifications_id_seq OWNED BY public.client_verifications.id;


--
-- Name: identity_passkey_ceremony_candidates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.identity_passkey_ceremony_candidates (
    id bigint NOT NULL,
    ref character varying NOT NULL,
    digest character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    step_up_ceremony_transaction_ref character varying CONSTRAINT identity_passkey_ceremony_c_step_up_ceremony_transacti_not_null NOT NULL,
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
-- Name: identity_passkey_ceremony_candidates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.identity_passkey_ceremony_candidates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: identity_passkey_ceremony_candidates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.identity_passkey_ceremony_candidates_id_seq OWNED BY public.identity_passkey_ceremony_candidates.id;


--
-- Name: identity_secret_credential_ceremony_candidates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.identity_secret_credential_ceremony_candidates (
    id bigint NOT NULL,
    ref character varying NOT NULL,
    digest character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying CONSTRAINT identity_secret_credential_ceremony_candidat_actor_ref_not_null NOT NULL,
    session_ref character varying CONSTRAINT identity_secret_credential_ceremony_candid_session_ref_not_null NOT NULL,
    transaction_id character varying CONSTRAINT identity_secret_credential_ceremony_can_transaction_id_not_null NOT NULL,
    operation character varying CONSTRAINT identity_secret_credential_ceremony_candidat_operation_not_null NOT NULL,
    password_digest text CONSTRAINT identity_secret_credential_ceremony_ca_password_digest_not_null NOT NULL,
    name character varying NOT NULL,
    enabled boolean NOT NULL,
    expires_at timestamp(6) with time zone CONSTRAINT identity_secret_credential_ceremony_candida_expires_at_not_null NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 CONSTRAINT identity_secret_credential_ceremony_candi_lock_version_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT identity_secret_credential_ceremony_candida_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT identity_secret_credential_ceremony_candida_updated_at_not_null NOT NULL
);


--
-- Name: identity_secret_credential_ceremony_candidates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.identity_secret_credential_ceremony_candidates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: identity_secret_credential_ceremony_candidates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.identity_secret_credential_ceremony_candidates_id_seq OWNED BY public.identity_secret_credential_ceremony_candidates.id;


--
-- Name: identity_social_ceremony_candidates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.identity_social_ceremony_candidates (
    id bigint NOT NULL,
    ref character varying NOT NULL,
    digest character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    transaction_id character varying NOT NULL,
    operation character varying NOT NULL,
    provider character varying NOT NULL,
    auth_hash text NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: identity_social_ceremony_candidates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.identity_social_ceremony_candidates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: identity_social_ceremony_candidates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.identity_social_ceremony_candidates_id_seq OWNED BY public.identity_social_ceremony_candidates.id;


--
-- Name: identity_totp_ceremony_candidates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.identity_totp_ceremony_candidates (
    id bigint NOT NULL,
    ref character varying NOT NULL,
    digest character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    private_key text NOT NULL,
    title character varying,
    last_otp_at timestamp(6) with time zone,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    step_up_ceremony_transaction_ref character varying,
    CONSTRAINT totp_candidate_pending_authority CHECK (((last_otp_at IS NOT NULL) OR (step_up_ceremony_transaction_ref IS NOT NULL)))
);


--
-- Name: identity_totp_ceremony_candidates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.identity_totp_ceremony_candidates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: identity_totp_ceremony_candidates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.identity_totp_ceremony_candidates_id_seq OWNED BY public.identity_totp_ceremony_candidates.id;


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
    CONSTRAINT chk_op_app_logout_participants_shape CHECK ((((realm)::text = 'app'::text) AND (delivery_attempts >= 0)))
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
    CONSTRAINT chk_op_app_logout_flows_realm CHECK (((realm)::text = 'app'::text))
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
-- Name: logout_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.logout_transactions (
    id bigint NOT NULL,
    public_id character varying NOT NULL,
    token_digest bytea NOT NULL,
    issuer character varying NOT NULL,
    audience character varying NOT NULL,
    purpose character varying NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    failure_code character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT logout_transactions_public_id_max_length CHECK ((char_length((public_id)::text) <= 25))
);


--
-- Name: logout_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.logout_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: logout_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.logout_transactions_id_seq OWNED BY public.logout_transactions.id;


--
-- Name: op_app_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.op_app_grants (
    id bigint NOT NULL,
    client_token_id bigint NOT NULL,
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
    CONSTRAINT chk_op_app_grants_authentication_epoch CHECK (((authentication_epoch IS NULL) OR (authentication_epoch >= 0))),
    CONSTRAINT chk_op_app_grants_contract_epoch CHECK (((contract_epoch IS NULL) OR (contract_epoch >= 1))),
    CONSTRAINT chk_op_app_grants_refresh_delivery_all_or_none CHECK ((((refresh_delivery_ciphertext IS NULL) AND (refresh_delivery_predecessor_digest IS NULL) AND (refresh_delivery_expires_at IS NULL)) OR ((refresh_delivery_ciphertext IS NOT NULL) AND (refresh_delivery_predecessor_digest IS NOT NULL) AND (refresh_delivery_expires_at IS NOT NULL))))
);


--
-- Name: op_app_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.op_app_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: op_app_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.op_app_grants_id_seq OWNED BY public.op_app_grants.id;


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
    CONSTRAINT chk_op_app_client_activations_digest_format CHECK (((source_manifest_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_op_app_client_activations_epoch_positive CHECK ((contract_epoch > 0))
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
    CONSTRAINT chk_op_app_consumed_jtis_realm CHECK (((realm)::text = 'app'::text))
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
    CONSTRAINT chk_op_app_inbound_event_receipts_realm CHECK (((realm)::text = 'app'::text))
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
    CONSTRAINT chk_op_app_outbox_events_shape CHECK ((((target_realm)::text = 'app'::text) AND (delivery_attempts >= 0)))
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
    CONSTRAINT chk_op_protocol_epochs_app_shape CHECK ((((realm)::text = 'app'::text) AND (contract_epoch >= 1))),
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
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: security_consumed_jtis; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.security_consumed_jtis (
    id bigint NOT NULL,
    purpose character varying NOT NULL,
    issuer character varying NOT NULL,
    jti_digest character varying NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: security_consumed_jtis_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.security_consumed_jtis_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: security_consumed_jtis_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.security_consumed_jtis_id_seq OWNED BY public.security_consumed_jtis.id;


--
-- Name: security_one_time_reveals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.security_one_time_reveals (
    id bigint NOT NULL,
    jti_digest character varying NOT NULL,
    actor_type character varying NOT NULL,
    actor_id bigint NOT NULL,
    session_nonce_digest character varying NOT NULL,
    purpose character varying NOT NULL,
    encrypted_payload text NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: security_one_time_reveals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.security_one_time_reveals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: security_one_time_reveals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.security_one_time_reveals_id_seq OWNED BY public.security_one_time_reveals.id;


--
-- Name: turnstile_replays; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.turnstile_replays (
    id bigint NOT NULL,
    ceremony_id character varying NOT NULL,
    token_digest character varying NOT NULL,
    action character varying,
    hostname character varying,
    cdata character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: turnstile_replays_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.turnstile_replays_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: turnstile_replays_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.turnstile_replays_id_seq OWNED BY public.turnstile_replays.id;


--
-- Name: user_verifications_user_token_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_verifications_user_token_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_verifications_user_token_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_verifications_user_token_id_seq OWNED BY public.client_verifications.user_token_id;


--
-- Name: acme_logout_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.acme_logout_transactions ALTER COLUMN id SET DEFAULT nextval('public.acme_logout_transactions_id_seq'::regclass);


--
-- Name: client_auth_admission_bindings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_auth_admission_bindings ALTER COLUMN id SET DEFAULT nextval('public.client_auth_admission_bindings_id_seq'::regclass);


--
-- Name: client_auth_ceremony_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_auth_ceremony_sessions ALTER COLUMN id SET DEFAULT nextval('public.client_auth_ceremony_sessions_id_seq'::regclass);


--
-- Name: client_device_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_device_sessions ALTER COLUMN id SET DEFAULT nextval('public.client_device_sessions_id_seq'::regclass);


--
-- Name: client_dpop_proof_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_dpop_proof_states ALTER COLUMN id SET DEFAULT nextval('public.client_dpop_proof_states_id_seq'::regclass);


--
-- Name: client_email_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_email_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.client_email_ceremony_transactions_id_seq'::regclass);


--
-- Name: client_emergency_sign_in_operations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_emergency_sign_in_operations ALTER COLUMN id SET DEFAULT nextval('public.client_emergency_sign_in_operations_id_seq'::regclass);


--
-- Name: client_oauth_callback_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_oauth_callback_states ALTER COLUMN id SET DEFAULT nextval('public.client_oauth_callback_states_id_seq'::regclass);


--
-- Name: client_oidc_authorization_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_oidc_authorization_transactions ALTER COLUMN id SET DEFAULT nextval('public.client_oidc_authorization_transactions_id_seq'::regclass);


--
-- Name: client_oidc_connections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_oidc_connections ALTER COLUMN id SET DEFAULT nextval('public.client_oidc_connections_id_seq'::regclass);


--
-- Name: client_passkey_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_passkey_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.client_passkey_ceremony_transactions_id_seq'::regclass);


--
-- Name: client_secret_credential_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_credential_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.client_secret_credential_ceremony_transactions_id_seq'::regclass);


--
-- Name: client_secret_sign_in_receipts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_sign_in_receipts ALTER COLUMN id SET DEFAULT nextval('public.client_secret_sign_in_receipts_id_seq'::regclass);


--
-- Name: client_session_limit_resolution_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_session_limit_resolution_states ALTER COLUMN id SET DEFAULT nextval('public.client_session_limit_resolution_states_id_seq'::regclass);


--
-- Name: client_session_limit_resolution_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_session_limit_resolution_transactions ALTER COLUMN id SET DEFAULT nextval('public.client_session_limit_resolution_transactions_id_seq'::regclass);


--
-- Name: client_sign_in_flow_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_in_flow_states ALTER COLUMN id SET DEFAULT nextval('public.client_sign_in_flow_states_id_seq'::regclass);


--
-- Name: client_sign_in_flows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_in_flows ALTER COLUMN id SET DEFAULT nextval('public.client_sign_in_flows_id_seq'::regclass);


--
-- Name: client_sign_out_flow_kinds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_out_flow_kinds ALTER COLUMN id SET DEFAULT nextval('public.client_sign_out_flow_kinds_id_seq'::regclass);


--
-- Name: client_sign_out_flow_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_out_flow_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_sign_out_flow_statuses_id_seq'::regclass);


--
-- Name: client_sign_out_flows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_out_flows ALTER COLUMN id SET DEFAULT nextval('public.client_sign_out_flows_id_seq'::regclass);


--
-- Name: client_sign_up_flow_cleanup_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_up_flow_cleanup_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_sign_up_flow_cleanup_statuses_id_seq'::regclass);


--
-- Name: client_sign_up_flow_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_up_flow_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_sign_up_flow_statuses_id_seq'::regclass);


--
-- Name: client_sign_up_flows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_up_flows ALTER COLUMN id SET DEFAULT nextval('public.client_sign_up_flows_id_seq'::regclass);


--
-- Name: client_social_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_social_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.client_social_ceremony_transactions_id_seq'::regclass);


--
-- Name: client_step_up_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_step_up_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.client_step_up_ceremony_transactions_id_seq'::regclass);


--
-- Name: client_step_up_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_step_up_sessions ALTER COLUMN id SET DEFAULT nextval('public.client_step_up_sessions_id_seq'::regclass);


--
-- Name: client_telephone_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_telephone_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.client_telephone_ceremony_transactions_id_seq'::regclass);


--
-- Name: client_token_binding_methods id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_token_binding_methods ALTER COLUMN id SET DEFAULT nextval('public.client_token_binding_methods_id_seq'::regclass);


--
-- Name: client_token_dbsc_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_token_dbsc_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_token_dbsc_statuses_id_seq'::regclass);


--
-- Name: client_token_kinds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_token_kinds ALTER COLUMN id SET DEFAULT nextval('public.client_token_kinds_id_seq'::regclass);


--
-- Name: client_token_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_token_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_token_statuses_id_seq'::regclass);


--
-- Name: client_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_tokens ALTER COLUMN id SET DEFAULT nextval('public.client_tokens_id_seq'::regclass);


--
-- Name: client_totp_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_totp_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.client_totp_ceremony_transactions_id_seq'::regclass);


--
-- Name: client_verifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_verifications ALTER COLUMN id SET DEFAULT nextval('public.client_verifications_id_seq'::regclass);


--
-- Name: identity_passkey_ceremony_candidates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_passkey_ceremony_candidates ALTER COLUMN id SET DEFAULT nextval('public.identity_passkey_ceremony_candidates_id_seq'::regclass);


--
-- Name: identity_secret_credential_ceremony_candidates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_secret_credential_ceremony_candidates ALTER COLUMN id SET DEFAULT nextval('public.identity_secret_credential_ceremony_candidates_id_seq'::regclass);


--
-- Name: identity_social_ceremony_candidates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_social_ceremony_candidates ALTER COLUMN id SET DEFAULT nextval('public.identity_social_ceremony_candidates_id_seq'::regclass);


--
-- Name: identity_totp_ceremony_candidates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_totp_ceremony_candidates ALTER COLUMN id SET DEFAULT nextval('public.identity_totp_ceremony_candidates_id_seq'::regclass);


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
-- Name: logout_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.logout_transactions ALTER COLUMN id SET DEFAULT nextval('public.logout_transactions_id_seq'::regclass);


--
-- Name: op_app_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_app_grants ALTER COLUMN id SET DEFAULT nextval('public.op_app_grants_id_seq'::regclass);


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
-- Name: op_outbox_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_outbox_events ALTER COLUMN id SET DEFAULT nextval('public.op_outbox_events_id_seq'::regclass);


--
-- Name: op_protocol_epochs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_protocol_epochs ALTER COLUMN id SET DEFAULT nextval('public.op_protocol_epochs_id_seq'::regclass);


--
-- Name: security_consumed_jtis id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security_consumed_jtis ALTER COLUMN id SET DEFAULT nextval('public.security_consumed_jtis_id_seq'::regclass);


--
-- Name: security_one_time_reveals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security_one_time_reveals ALTER COLUMN id SET DEFAULT nextval('public.security_one_time_reveals_id_seq'::regclass);


--
-- Name: turnstile_replays id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.turnstile_replays ALTER COLUMN id SET DEFAULT nextval('public.turnstile_replays_id_seq'::regclass);


--
-- Name: acme_logout_transactions acme_logout_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.acme_logout_transactions
    ADD CONSTRAINT acme_logout_transactions_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: client_email_ceremony_transactions chk_client_email_ceremony_evp_attempt_count; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.client_email_ceremony_transactions
    ADD CONSTRAINT chk_client_email_ceremony_evp_attempt_count CHECK ((evp_attempt_count >= 0)) NOT VALID;


--
-- Name: client_step_up_sessions chk_user_step_up_sessions_retention_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.client_step_up_sessions
    ADD CONSTRAINT chk_user_step_up_sessions_retention_order CHECK ((discard_at <= purge_eligible_at)) NOT VALID;


--
-- Name: client_auth_admission_bindings client_auth_admission_bindings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_auth_admission_bindings
    ADD CONSTRAINT client_auth_admission_bindings_pkey PRIMARY KEY (id);


--
-- Name: client_auth_ceremony_sessions client_auth_ceremony_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_auth_ceremony_sessions
    ADD CONSTRAINT client_auth_ceremony_sessions_pkey PRIMARY KEY (id);


--
-- Name: client_device_sessions client_device_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_device_sessions
    ADD CONSTRAINT client_device_sessions_pkey PRIMARY KEY (id);


--
-- Name: client_dpop_proof_states client_dpop_proof_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_dpop_proof_states
    ADD CONSTRAINT client_dpop_proof_states_pkey PRIMARY KEY (id);


--
-- Name: client_email_ceremony_transactions client_email_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_email_ceremony_transactions
    ADD CONSTRAINT client_email_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: client_emergency_sign_in_operations client_emergency_sign_in_operations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_emergency_sign_in_operations
    ADD CONSTRAINT client_emergency_sign_in_operations_pkey PRIMARY KEY (id);


--
-- Name: client_oauth_callback_states client_oauth_callback_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_oauth_callback_states
    ADD CONSTRAINT client_oauth_callback_states_pkey PRIMARY KEY (id);


--
-- Name: client_oidc_authorization_transactions client_oidc_authorization_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_oidc_authorization_transactions
    ADD CONSTRAINT client_oidc_authorization_transactions_pkey PRIMARY KEY (id);


--
-- Name: client_oidc_connections client_oidc_connections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_oidc_connections
    ADD CONSTRAINT client_oidc_connections_pkey PRIMARY KEY (id);


--
-- Name: client_passkey_ceremony_transactions client_passkey_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_passkey_ceremony_transactions
    ADD CONSTRAINT client_passkey_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: client_secret_credential_ceremony_transactions client_secret_credential_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_credential_ceremony_transactions
    ADD CONSTRAINT client_secret_credential_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: client_secret_sign_in_receipts client_secret_sign_in_receipts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_sign_in_receipts
    ADD CONSTRAINT client_secret_sign_in_receipts_pkey PRIMARY KEY (id);


--
-- Name: client_session_limit_resolution_states client_session_limit_resolution_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_session_limit_resolution_states
    ADD CONSTRAINT client_session_limit_resolution_states_pkey PRIMARY KEY (id);


--
-- Name: client_session_limit_resolution_transactions client_session_limit_resolution_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_session_limit_resolution_transactions
    ADD CONSTRAINT client_session_limit_resolution_transactions_pkey PRIMARY KEY (id);


--
-- Name: client_sign_in_flow_states client_sign_in_flow_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_in_flow_states
    ADD CONSTRAINT client_sign_in_flow_states_pkey PRIMARY KEY (id);


--
-- Name: client_sign_in_flows client_sign_in_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_in_flows
    ADD CONSTRAINT client_sign_in_flows_pkey PRIMARY KEY (id);


--
-- Name: client_sign_out_flow_kinds client_sign_out_flow_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_out_flow_kinds
    ADD CONSTRAINT client_sign_out_flow_kinds_pkey PRIMARY KEY (id);


--
-- Name: client_sign_out_flow_statuses client_sign_out_flow_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_out_flow_statuses
    ADD CONSTRAINT client_sign_out_flow_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_sign_out_flows client_sign_out_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_out_flows
    ADD CONSTRAINT client_sign_out_flows_pkey PRIMARY KEY (id);


--
-- Name: client_sign_up_flow_cleanup_statuses client_sign_up_flow_cleanup_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_up_flow_cleanup_statuses
    ADD CONSTRAINT client_sign_up_flow_cleanup_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_sign_up_flow_statuses client_sign_up_flow_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_up_flow_statuses
    ADD CONSTRAINT client_sign_up_flow_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_sign_up_flows client_sign_up_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_up_flows
    ADD CONSTRAINT client_sign_up_flows_pkey PRIMARY KEY (id);


--
-- Name: client_social_ceremony_transactions client_social_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_social_ceremony_transactions
    ADD CONSTRAINT client_social_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: client_step_up_ceremony_transactions client_step_up_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_step_up_ceremony_transactions
    ADD CONSTRAINT client_step_up_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: client_step_up_sessions client_step_up_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_step_up_sessions
    ADD CONSTRAINT client_step_up_sessions_pkey PRIMARY KEY (id);


--
-- Name: client_telephone_ceremony_transactions client_telephone_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_telephone_ceremony_transactions
    ADD CONSTRAINT client_telephone_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: client_token_binding_methods client_token_binding_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_token_binding_methods
    ADD CONSTRAINT client_token_binding_methods_pkey PRIMARY KEY (id);


--
-- Name: client_token_dbsc_statuses client_token_dbsc_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_token_dbsc_statuses
    ADD CONSTRAINT client_token_dbsc_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_token_kinds client_token_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_token_kinds
    ADD CONSTRAINT client_token_kinds_pkey PRIMARY KEY (id);


--
-- Name: client_token_statuses client_token_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_token_statuses
    ADD CONSTRAINT client_token_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_tokens client_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_tokens
    ADD CONSTRAINT client_tokens_pkey PRIMARY KEY (id);


--
-- Name: client_totp_ceremony_transactions client_totp_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_totp_ceremony_transactions
    ADD CONSTRAINT client_totp_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: client_verifications client_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_verifications
    ADD CONSTRAINT client_verifications_pkey PRIMARY KEY (id);


--
-- Name: identity_passkey_ceremony_candidates identity_passkey_ceremony_candidates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_passkey_ceremony_candidates
    ADD CONSTRAINT identity_passkey_ceremony_candidates_pkey PRIMARY KEY (id);


--
-- Name: identity_secret_credential_ceremony_candidates identity_secret_credential_ceremony_candidates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_secret_credential_ceremony_candidates
    ADD CONSTRAINT identity_secret_credential_ceremony_candidates_pkey PRIMARY KEY (id);


--
-- Name: identity_social_ceremony_candidates identity_social_ceremony_candidates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_social_ceremony_candidates
    ADD CONSTRAINT identity_social_ceremony_candidates_pkey PRIMARY KEY (id);


--
-- Name: identity_totp_ceremony_candidates identity_totp_ceremony_candidates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_totp_ceremony_candidates
    ADD CONSTRAINT identity_totp_ceremony_candidates_pkey PRIMARY KEY (id);


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
-- Name: logout_transactions logout_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.logout_transactions
    ADD CONSTRAINT logout_transactions_pkey PRIMARY KEY (id);


--
-- Name: op_app_grants op_app_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_app_grants
    ADD CONSTRAINT op_app_grants_pkey PRIMARY KEY (id);


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
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: security_consumed_jtis security_consumed_jtis_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security_consumed_jtis
    ADD CONSTRAINT security_consumed_jtis_pkey PRIMARY KEY (id);


--
-- Name: security_one_time_reveals security_one_time_reveals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security_one_time_reveals
    ADD CONSTRAINT security_one_time_reveals_pkey PRIMARY KEY (id);


--
-- Name: turnstile_replays turnstile_replays_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.turnstile_replays
    ADD CONSTRAINT turnstile_replays_pkey PRIMARY KEY (id);


--
-- Name: client_email_otp_original_bootstrap; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX client_email_otp_original_bootstrap ON public.client_email_ceremony_transactions USING btree (bootstrap_ceremony_transaction_ref);


--
-- Name: idx_active_op_app_grant_per_device_session; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_active_op_app_grant_per_device_session ON public.op_app_grants USING btree (device_session_id, oidc_client_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_auth_ceremony_sessions_on_tx_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_auth_ceremony_sessions_on_tx_ref ON public.client_auth_ceremony_sessions USING btree (authorization_transaction_ref) WHERE (authorization_transaction_ref IS NOT NULL);


--
-- Name: idx_client_admission_bindings_auth_session; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_admission_bindings_auth_session ON public.client_auth_admission_bindings USING btree (auth_ceremony_session_id) WHERE (auth_ceremony_session_id IS NOT NULL);


--
-- Name: idx_client_admission_bindings_live_oidc; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_client_admission_bindings_live_oidc ON public.client_auth_admission_bindings USING btree (authorization_transaction_id) WHERE ((authorization_transaction_id IS NOT NULL) AND (retired_at IS NULL) AND (redeemed_at IS NULL));


--
-- Name: idx_client_admission_bindings_live_sign_in; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_client_admission_bindings_live_sign_in ON public.client_auth_admission_bindings USING btree (sign_in_flow_id) WHERE ((sign_in_flow_id IS NOT NULL) AND (retired_at IS NULL) AND (redeemed_at IS NULL));


--
-- Name: idx_client_admission_bindings_live_step_up; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_client_admission_bindings_live_step_up ON public.client_auth_admission_bindings USING btree (step_up_ceremony_transaction_id) WHERE ((step_up_ceremony_transaction_id IS NOT NULL) AND (retired_at IS NULL) AND (redeemed_at IS NULL));


--
-- Name: idx_client_resolution_open_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_client_resolution_open_parent ON public.client_session_limit_resolution_transactions USING btree (sign_in_flow_id) WHERE (state_id = ANY (ARRAY[(10)::bigint, (20)::bigint]));


--
-- Name: idx_client_resolution_waiting_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_client_resolution_waiting_actor ON public.client_session_limit_resolution_transactions USING btree (actor_ref) WHERE (waiting_slot = 1);


--
-- Name: idx_client_session_limit_resolution_on_oidc_tx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_session_limit_resolution_on_oidc_tx ON public.client_session_limit_resolution_transactions USING btree (oidc_authorization_transaction_id);


--
-- Name: idx_on_actor_ref_session_ref_1470aaddcc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_1470aaddcc ON public.client_secret_credential_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_334fbe1b51; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_334fbe1b51 ON public.client_passkey_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_479aea5d5e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_479aea5d5e ON public.identity_social_ceremony_candidates USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_4f24c7001d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_4f24c7001d ON public.client_step_up_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_5df22d9da8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_5df22d9da8 ON public.identity_totp_ceremony_candidates USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_736426585a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_736426585a ON public.identity_secret_credential_ceremony_candidates USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_7d958a782d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_7d958a782d ON public.client_email_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_b5b014c24f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_b5b014c24f ON public.client_social_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_e19ee6ad85; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_e19ee6ad85 ON public.client_telephone_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_e256c5d4a6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_e256c5d4a6 ON public.client_totp_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_cancellation_handoff_digest_0854d61a10; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_cancellation_handoff_digest_0854d61a10 ON public.client_step_up_ceremony_transactions USING btree (cancellation_handoff_digest);


--
-- Name: idx_on_cancellation_handoff_ref_15a289d5f5; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_cancellation_handoff_ref_15a289d5f5 ON public.client_step_up_ceremony_transactions USING btree (cancellation_handoff_ref);


--
-- Name: idx_on_challenge_digest_84445da7db; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_challenge_digest_84445da7db ON public.client_session_limit_resolution_transactions USING btree (challenge_digest);


--
-- Name: idx_on_cleanup_status_id_purge_eligible_at_ca14322ea0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_cleanup_status_id_purge_eligible_at_ca14322ea0 ON public.client_sign_up_flows USING btree (cleanup_status_id, purge_eligible_at);


--
-- Name: idx_on_client_id_login_challenge_8f71e56454; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_client_id_login_challenge_8f71e56454 ON public.client_oidc_authorization_transactions USING btree (client_id, login_challenge);


--
-- Name: idx_on_credential_public_id_148fd60d04; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_credential_public_id_148fd60d04 ON public.client_emergency_sign_in_operations USING btree (credential_public_id);


--
-- Name: idx_on_expires_at_6a705a7bb7; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_expires_at_6a705a7bb7 ON public.client_secret_credential_ceremony_transactions USING btree (expires_at);


--
-- Name: idx_on_expires_at_e4a78ab552; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_expires_at_e4a78ab552 ON public.client_session_limit_resolution_transactions USING btree (expires_at);


--
-- Name: idx_on_expires_at_efa074713c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_expires_at_efa074713c ON public.identity_secret_credential_ceremony_candidates USING btree (expires_at);


--
-- Name: idx_on_grant_jti_58e101b1d8; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_grant_jti_58e101b1d8 ON public.client_secret_credential_ceremony_transactions USING btree (grant_jti);


--
-- Name: idx_on_login_challenge_91d464d261; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_login_challenge_91d464d261 ON public.client_oidc_authorization_transactions USING btree (login_challenge);


--
-- Name: idx_on_provider_provider_subject_digest_8b462593cd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_provider_provider_subject_digest_8b462593cd ON public.client_social_ceremony_transactions USING btree (provider, provider_subject_digest);


--
-- Name: idx_on_purpose_issuer_jti_digest_b22183f7af; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_purpose_issuer_jti_digest_b22183f7af ON public.security_consumed_jtis USING btree (purpose, issuer, jti_digest);


--
-- Name: idx_on_result_jti_b20b4e2f25; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_result_jti_b20b4e2f25 ON public.client_secret_credential_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: idx_on_secret_sign_in_flow_id_5c5b1ba175; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_secret_sign_in_flow_id_5c5b1ba175 ON public.client_oidc_authorization_transactions USING btree (secret_sign_in_flow_id);


--
-- Name: idx_on_step_up_ceremony_transaction_ref_1dac192657; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_step_up_ceremony_transaction_ref_1dac192657 ON public.client_totp_ceremony_transactions USING btree (step_up_ceremony_transaction_ref);


--
-- Name: idx_on_step_up_ceremony_transaction_ref_5dbe753227; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_step_up_ceremony_transaction_ref_5dbe753227 ON public.identity_totp_ceremony_candidates USING btree (step_up_ceremony_transaction_ref);


--
-- Name: idx_on_step_up_ceremony_transaction_ref_753ef10546; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_step_up_ceremony_transaction_ref_753ef10546 ON public.identity_passkey_ceremony_candidates USING btree (step_up_ceremony_transaction_ref);


--
-- Name: idx_on_step_up_ceremony_transaction_ref_7bec716b5b; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_step_up_ceremony_transaction_ref_7bec716b5b ON public.client_step_up_sessions USING btree (step_up_ceremony_transaction_ref);


--
-- Name: idx_on_step_up_ceremony_transaction_ref_d63907f9e6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_step_up_ceremony_transaction_ref_d63907f9e6 ON public.client_passkey_ceremony_transactions USING btree (step_up_ceremony_transaction_ref);


--
-- Name: idx_on_transaction_id_b63311dbbc; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_transaction_id_b63311dbbc ON public.client_secret_credential_ceremony_transactions USING btree (transaction_id);


--
-- Name: idx_on_transaction_id_operation_5fc247d5b7; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_transaction_id_operation_5fc247d5b7 ON public.identity_secret_credential_ceremony_candidates USING btree (transaction_id, operation);


--
-- Name: idx_on_transaction_id_operation_b010ccabdf; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_transaction_id_operation_b010ccabdf ON public.identity_social_ceremony_candidates USING btree (transaction_id, operation);


--
-- Name: idx_op_app_client_activations_client_epoch; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_app_client_activations_client_epoch ON public.op_client_activations USING btree (client_id, contract_epoch);


--
-- Name: idx_op_app_consumed_jtis_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_op_app_consumed_jtis_expires_at ON public.op_consumed_jtis USING btree (expires_at);


--
-- Name: idx_op_app_consumed_jtis_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_app_consumed_jtis_scope ON public.op_consumed_jtis USING btree (purpose, issuer, realm, client_id, jti_digest);


--
-- Name: idx_op_app_inbound_event_receipts_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_app_inbound_event_receipts_identity ON public.op_inbound_event_receipts USING btree (event_id, issuer, realm, client_id);


--
-- Name: idx_op_app_logout_flows_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_app_logout_flows_idempotency ON public.logout_flows USING btree (realm, idempotency_digest);


--
-- Name: idx_op_app_logout_flows_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_app_logout_flows_public_id ON public.logout_flows USING btree (public_id);


--
-- Name: idx_op_app_logout_participants_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_app_logout_participants_identity ON public.logout_flow_participants USING btree (logout_flow_id, issuer, realm, client_id, sid);


--
-- Name: idx_op_app_logout_receipts_nonce; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_app_logout_receipts_nonce ON public.logout_receipts USING btree (logout_flow_id, nonce_digest);


--
-- Name: idx_op_app_logout_receipts_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_app_logout_receipts_public_id ON public.logout_receipts USING btree (public_id);


--
-- Name: idx_op_app_outbox_events_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_app_outbox_events_event_id ON public.op_outbox_events USING btree (event_id);


--
-- Name: idx_op_app_outbox_events_next_attempt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_op_app_outbox_events_next_attempt ON public.op_outbox_events USING btree (next_attempt_at);


--
-- Name: idx_op_protocol_epochs_realm; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_op_protocol_epochs_realm ON public.op_protocol_epochs USING btree (realm);


--
-- Name: index_acme_logout_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_acme_logout_transactions_on_expires_at ON public.acme_logout_transactions USING btree (expires_at);


--
-- Name: index_acme_logout_transactions_on_origin_surface; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_acme_logout_transactions_on_origin_surface ON public.acme_logout_transactions USING btree (origin_surface);


--
-- Name: index_acme_logout_transactions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_acme_logout_transactions_on_public_id ON public.acme_logout_transactions USING btree (public_id);


--
-- Name: index_acme_logout_transactions_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_acme_logout_transactions_on_status ON public.acme_logout_transactions USING btree (status);


--
-- Name: index_acme_logout_transactions_on_workflow; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_acme_logout_transactions_on_workflow ON public.acme_logout_transactions USING btree (workflow);


--
-- Name: index_client_auth_admission_bindings_on_confirmation_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_auth_admission_bindings_on_confirmation_ref ON public.client_auth_admission_bindings USING btree (confirmation_ref) WHERE (confirmation_ref IS NOT NULL);


--
-- Name: index_client_auth_admission_bindings_on_entry_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_auth_admission_bindings_on_entry_ref ON public.client_auth_admission_bindings USING btree (entry_ref);


--
-- Name: index_client_auth_admission_bindings_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_auth_admission_bindings_on_expires_at ON public.client_auth_admission_bindings USING btree (expires_at);


--
-- Name: index_client_auth_ceremony_sessions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_auth_ceremony_sessions_on_expires_at ON public.client_auth_ceremony_sessions USING btree (expires_at);


--
-- Name: index_client_auth_ceremony_sessions_on_revoked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_auth_ceremony_sessions_on_revoked_at ON public.client_auth_ceremony_sessions USING btree (revoked_at);


--
-- Name: index_client_auth_ceremony_sessions_on_sid_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_auth_ceremony_sessions_on_sid_digest ON public.client_auth_ceremony_sessions USING btree (sid_digest);


--
-- Name: index_client_device_sessions_on_current_refresh_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_device_sessions_on_current_refresh_token_id ON public.client_device_sessions USING btree (current_refresh_token_id);


--
-- Name: index_client_device_sessions_on_dbsc_session_id_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_device_sessions_on_dbsc_session_id_digest ON public.client_device_sessions USING btree (dbsc_session_id_digest);


--
-- Name: index_client_device_sessions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_device_sessions_on_public_id ON public.client_device_sessions USING btree (public_id);


--
-- Name: index_client_device_sessions_on_refresh_token_family_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_device_sessions_on_refresh_token_family_id ON public.client_device_sessions USING btree (refresh_token_family_id);


--
-- Name: index_client_device_sessions_on_revoked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_device_sessions_on_revoked_at ON public.client_device_sessions USING btree (revoked_at);


--
-- Name: index_client_device_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_device_sessions_on_user_id ON public.client_device_sessions USING btree (user_id);


--
-- Name: index_client_device_sessions_on_user_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_device_sessions_on_user_id_and_id ON public.client_device_sessions USING btree (user_id, id);


--
-- Name: index_client_dpop_proof_states_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_dpop_proof_states_on_expires_at ON public.client_dpop_proof_states USING btree (expires_at);


--
-- Name: index_client_dpop_proof_states_on_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_dpop_proof_states_on_jti ON public.client_dpop_proof_states USING btree (jti) WHERE (jti IS NOT NULL);


--
-- Name: index_client_dpop_proof_states_on_nonce; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_dpop_proof_states_on_nonce ON public.client_dpop_proof_states USING btree (nonce) WHERE (nonce IS NOT NULL);


--
-- Name: index_client_email_ceremony_transactions_on_evp_nonce_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_email_ceremony_transactions_on_evp_nonce_digest ON public.client_email_ceremony_transactions USING btree (evp_nonce_digest) WHERE (evp_nonce_digest IS NOT NULL);


--
-- Name: index_client_email_ceremony_transactions_on_evp_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_email_ceremony_transactions_on_evp_token_digest ON public.client_email_ceremony_transactions USING btree (evp_token_digest) WHERE (evp_token_digest IS NOT NULL);


--
-- Name: index_client_email_ceremony_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_email_ceremony_transactions_on_expires_at ON public.client_email_ceremony_transactions USING btree (expires_at);


--
-- Name: index_client_email_ceremony_transactions_on_grant_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_email_ceremony_transactions_on_grant_jti ON public.client_email_ceremony_transactions USING btree (grant_jti);


--
-- Name: index_client_email_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_email_ceremony_transactions_on_result_jti ON public.client_email_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_client_email_ceremony_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_email_ceremony_transactions_on_transaction_id ON public.client_email_ceremony_transactions USING btree (transaction_id);


--
-- Name: index_client_emergency_sign_in_operations_on_client_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_emergency_sign_in_operations_on_client_token_id ON public.client_emergency_sign_in_operations USING btree (client_token_id);


--
-- Name: index_client_emergency_sign_in_operations_on_operation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_emergency_sign_in_operations_on_operation_id ON public.client_emergency_sign_in_operations USING btree (operation_id);


--
-- Name: index_client_oauth_callback_states_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_oauth_callback_states_on_expires_at ON public.client_oauth_callback_states USING btree (expires_at);


--
-- Name: index_client_oauth_callback_states_on_state_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_oauth_callback_states_on_state_digest ON public.client_oauth_callback_states USING btree (state_digest);


--
-- Name: index_client_oidc_authorization_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_oidc_authorization_transactions_on_transaction_id ON public.client_oidc_authorization_transactions USING btree (transaction_id);


--
-- Name: index_client_oidc_connections_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_oidc_connections_on_public_id ON public.client_oidc_connections USING btree (public_id);


--
-- Name: index_client_oidc_connections_on_user_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_oidc_connections_on_user_id_and_client_id ON public.client_oidc_connections USING btree (user_id, client_id);


--
-- Name: index_client_passkey_ceremony_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_passkey_ceremony_transactions_on_expires_at ON public.client_passkey_ceremony_transactions USING btree (expires_at);


--
-- Name: index_client_passkey_ceremony_transactions_on_grant_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_passkey_ceremony_transactions_on_grant_jti ON public.client_passkey_ceremony_transactions USING btree (grant_jti);


--
-- Name: index_client_passkey_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_passkey_ceremony_transactions_on_result_jti ON public.client_passkey_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_client_passkey_ceremony_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_passkey_ceremony_transactions_on_transaction_id ON public.client_passkey_ceremony_transactions USING btree (transaction_id);


--
-- Name: index_client_secret_sign_in_receipts_on_credential_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_secret_sign_in_receipts_on_credential_ref ON public.client_secret_sign_in_receipts USING btree (credential_ref);


--
-- Name: index_client_secret_sign_in_receipts_on_operation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_secret_sign_in_receipts_on_operation_id ON public.client_secret_sign_in_receipts USING btree (operation_id);


--
-- Name: index_client_secret_sign_in_receipts_on_root_token_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_secret_sign_in_receipts_on_root_token_ref ON public.client_secret_sign_in_receipts USING btree (root_token_ref);


--
-- Name: index_client_secret_sign_in_receipts_on_sign_in_flow_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_secret_sign_in_receipts_on_sign_in_flow_id ON public.client_secret_sign_in_receipts USING btree (sign_in_flow_id);


--
-- Name: index_client_sign_in_flows_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_in_flows_on_discard_at ON public.client_sign_in_flows USING btree (discard_at);


--
-- Name: index_client_sign_in_flows_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_in_flows_on_expires_at ON public.client_sign_in_flows USING btree (expires_at);


--
-- Name: index_client_sign_in_flows_on_principal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_in_flows_on_principal_id ON public.client_sign_in_flows USING btree (principal_id);


--
-- Name: index_client_sign_in_flows_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_sign_in_flows_on_public_id ON public.client_sign_in_flows USING btree (public_id);


--
-- Name: index_client_sign_in_flows_on_result_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_sign_in_flows_on_result_digest ON public.client_sign_in_flows USING btree (result_digest);


--
-- Name: index_client_sign_in_flows_on_selected_persona_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_in_flows_on_selected_persona_id ON public.client_sign_in_flows USING btree (selected_persona_id);


--
-- Name: index_client_sign_in_flows_on_selected_region_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_in_flows_on_selected_region_id ON public.client_sign_in_flows USING btree (selected_region_id);


--
-- Name: index_client_sign_in_flows_on_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_in_flows_on_state_id ON public.client_sign_in_flows USING btree (state_id);


--
-- Name: index_client_sign_in_flows_on_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_in_flows_on_token_id ON public.client_sign_in_flows USING btree (token_id);


--
-- Name: index_client_sign_in_flows_on_token_id_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_sign_in_flows_on_token_id_unique ON public.client_sign_in_flows USING btree (token_id) WHERE (token_id IS NOT NULL);


--
-- Name: index_client_sign_out_flows_on_access_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_out_flows_on_access_expires_at ON public.client_sign_out_flows USING btree (access_expires_at);


--
-- Name: index_client_sign_out_flows_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_out_flows_on_discard_at ON public.client_sign_out_flows USING btree (discard_at);


--
-- Name: index_client_sign_out_flows_on_kind_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_out_flows_on_kind_id ON public.client_sign_out_flows USING btree (kind_id);


--
-- Name: index_client_sign_out_flows_on_principal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_out_flows_on_principal_id ON public.client_sign_out_flows USING btree (principal_id);


--
-- Name: index_client_sign_out_flows_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_sign_out_flows_on_public_id ON public.client_sign_out_flows USING btree (public_id);


--
-- Name: index_client_sign_out_flows_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_out_flows_on_purge_eligible_at ON public.client_sign_out_flows USING btree (purge_eligible_at);


--
-- Name: index_client_sign_out_flows_on_refresh_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_out_flows_on_refresh_expires_at ON public.client_sign_out_flows USING btree (refresh_expires_at);


--
-- Name: index_client_sign_out_flows_on_refresh_token_family_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_out_flows_on_refresh_token_family_id ON public.client_sign_out_flows USING btree (refresh_token_family_id);


--
-- Name: index_client_sign_out_flows_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_out_flows_on_status_id ON public.client_sign_out_flows USING btree (status_id);


--
-- Name: index_client_sign_out_flows_on_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_out_flows_on_token_id ON public.client_sign_out_flows USING btree (token_id);


--
-- Name: index_client_sign_up_flows_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_up_flows_on_discard_at ON public.client_sign_up_flows USING btree (discard_at);


--
-- Name: index_client_sign_up_flows_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_up_flows_on_expires_at ON public.client_sign_up_flows USING btree (expires_at);


--
-- Name: index_client_sign_up_flows_on_pending_contact_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_up_flows_on_pending_contact_id ON public.client_sign_up_flows USING btree (pending_contact_id);


--
-- Name: index_client_sign_up_flows_on_pending_passkey_registration_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_up_flows_on_pending_passkey_registration_id ON public.client_sign_up_flows USING btree (pending_passkey_registration_id);


--
-- Name: index_client_sign_up_flows_on_principal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_up_flows_on_principal_id ON public.client_sign_up_flows USING btree (principal_id);


--
-- Name: index_client_sign_up_flows_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_sign_up_flows_on_public_id ON public.client_sign_up_flows USING btree (public_id);


--
-- Name: index_client_sign_up_flows_on_result_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_sign_up_flows_on_result_digest ON public.client_sign_up_flows USING btree (result_digest);


--
-- Name: index_client_sign_up_flows_on_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_up_flows_on_state ON public.client_sign_up_flows USING btree (state);


--
-- Name: index_client_sign_up_flows_on_status_id_and_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_up_flows_on_status_id_and_expires_at ON public.client_sign_up_flows USING btree (status_id, expires_at);


--
-- Name: index_client_sign_up_flows_on_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_up_flows_on_token_id ON public.client_sign_up_flows USING btree (token_id);


--
-- Name: index_client_social_ceremony_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_social_ceremony_transactions_on_expires_at ON public.client_social_ceremony_transactions USING btree (expires_at);


--
-- Name: index_client_social_ceremony_transactions_on_grant_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_social_ceremony_transactions_on_grant_jti ON public.client_social_ceremony_transactions USING btree (grant_jti);


--
-- Name: index_client_social_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_social_ceremony_transactions_on_result_jti ON public.client_social_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_client_social_ceremony_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_social_ceremony_transactions_on_transaction_id ON public.client_social_ceremony_transactions USING btree (transaction_id);


--
-- Name: index_client_step_up_ceremony_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_step_up_ceremony_transactions_on_expires_at ON public.client_step_up_ceremony_transactions USING btree (expires_at);


--
-- Name: index_client_step_up_ceremony_transactions_on_grant_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_step_up_ceremony_transactions_on_grant_jti ON public.client_step_up_ceremony_transactions USING btree (grant_jti);


--
-- Name: index_client_step_up_ceremony_transactions_on_required_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_step_up_ceremony_transactions_on_required_scope ON public.client_step_up_ceremony_transactions USING btree (required_scope);


--
-- Name: index_client_step_up_ceremony_transactions_on_result_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_step_up_ceremony_transactions_on_result_digest ON public.client_step_up_ceremony_transactions USING btree (result_digest);


--
-- Name: index_client_step_up_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_step_up_ceremony_transactions_on_result_jti ON public.client_step_up_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_client_step_up_ceremony_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_step_up_ceremony_transactions_on_transaction_id ON public.client_step_up_ceremony_transactions USING btree (transaction_id);


--
-- Name: index_client_step_up_sessions_on_passkey_challenge_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_step_up_sessions_on_passkey_challenge_ref ON public.client_step_up_sessions USING btree (passkey_challenge_ref);


--
-- Name: index_client_step_up_sessions_on_user_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_step_up_sessions_on_user_token_id ON public.client_step_up_sessions USING btree (user_token_id);


--
-- Name: index_client_telephone_ceremony_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_telephone_ceremony_transactions_on_expires_at ON public.client_telephone_ceremony_transactions USING btree (expires_at);


--
-- Name: index_client_telephone_ceremony_transactions_on_grant_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_telephone_ceremony_transactions_on_grant_jti ON public.client_telephone_ceremony_transactions USING btree (grant_jti);


--
-- Name: index_client_telephone_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_telephone_ceremony_transactions_on_result_jti ON public.client_telephone_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_client_telephone_ceremony_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_telephone_ceremony_transactions_on_transaction_id ON public.client_telephone_ceremony_transactions USING btree (transaction_id);


--
-- Name: index_client_tokens_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_created_at ON public.client_tokens USING btree (created_at);


--
-- Name: index_client_tokens_on_dbsc_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_tokens_on_dbsc_session_id ON public.client_tokens USING btree (dbsc_session_id);


--
-- Name: index_client_tokens_on_device_session_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_tokens_on_device_session_id_and_id ON public.client_tokens USING btree (device_session_id, id);


--
-- Name: index_client_tokens_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_discard_at ON public.client_tokens USING btree (discard_at);


--
-- Name: index_client_tokens_on_established_authentication_method; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_established_authentication_method ON public.client_tokens USING btree (established_authentication_method);


--
-- Name: index_client_tokens_on_oidc_connection_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_oidc_connection_id ON public.client_tokens USING btree (oidc_connection_id);


--
-- Name: index_client_tokens_on_oidc_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_oidc_jti ON public.client_tokens USING btree (oidc_jti);


--
-- Name: index_client_tokens_on_oidc_sid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_oidc_sid ON public.client_tokens USING btree (oidc_sid);


--
-- Name: index_client_tokens_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_tokens_on_public_id ON public.client_tokens USING btree (public_id);


--
-- Name: index_client_tokens_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_purge_eligible_at ON public.client_tokens USING btree (purge_eligible_at);


--
-- Name: index_client_tokens_on_refresh_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_tokens_on_refresh_token_digest ON public.client_tokens USING btree (refresh_token_digest);


--
-- Name: index_client_tokens_on_refresh_token_family_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_refresh_token_family_id ON public.client_tokens USING btree (refresh_token_family_id);


--
-- Name: index_client_tokens_on_rotated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_rotated_at ON public.client_tokens USING btree (rotated_at);


--
-- Name: index_client_tokens_on_selected_account_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_selected_account_public_id ON public.client_tokens USING btree (selected_account_public_id);


--
-- Name: index_client_tokens_on_selected_avatar_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_selected_avatar_public_id ON public.client_tokens USING btree (selected_avatar_public_id);


--
-- Name: index_client_tokens_on_selected_collective_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_selected_collective_public_id ON public.client_tokens USING btree (selected_collective_public_id);


--
-- Name: index_client_tokens_on_user_id_and_last_step_up_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_user_id_and_last_step_up_at ON public.client_tokens USING btree (user_id, last_step_up_at);


--
-- Name: index_client_tokens_on_user_id_and_oidc_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_user_id_and_oidc_client_id ON public.client_tokens USING btree (user_id, oidc_client_id);


--
-- Name: index_client_tokens_on_user_id_root_login_established_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_user_id_root_login_established_at ON public.client_tokens USING btree (user_id, root_login_established_at) WHERE (root_login_established_at IS NOT NULL);


--
-- Name: index_client_tokens_on_user_token_binding_method_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_user_token_binding_method_id ON public.client_tokens USING btree (user_token_binding_method_id);


--
-- Name: index_client_tokens_on_user_token_dbsc_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_user_token_dbsc_status_id ON public.client_tokens USING btree (user_token_dbsc_status_id);


--
-- Name: index_client_tokens_on_user_token_kind_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_user_token_kind_id ON public.client_tokens USING btree (user_token_kind_id);


--
-- Name: index_client_tokens_on_user_token_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_user_token_status_id ON public.client_tokens USING btree (user_token_status_id);


--
-- Name: index_client_totp_ceremony_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_totp_ceremony_transactions_on_expires_at ON public.client_totp_ceremony_transactions USING btree (expires_at);


--
-- Name: index_client_totp_ceremony_transactions_on_grant_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_totp_ceremony_transactions_on_grant_jti ON public.client_totp_ceremony_transactions USING btree (grant_jti);


--
-- Name: index_client_totp_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_totp_ceremony_transactions_on_result_jti ON public.client_totp_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_client_totp_ceremony_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_totp_ceremony_transactions_on_transaction_id ON public.client_totp_ceremony_transactions USING btree (transaction_id);


--
-- Name: index_client_verifications_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_verifications_on_token_digest ON public.client_verifications USING btree (token_digest);


--
-- Name: index_client_verifications_on_user_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_verifications_on_user_token_id ON public.client_verifications USING btree (user_token_id);


--
-- Name: index_identity_passkey_ceremony_candidates_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_identity_passkey_ceremony_candidates_on_expires_at ON public.identity_passkey_ceremony_candidates USING btree (expires_at);


--
-- Name: index_identity_passkey_ceremony_candidates_on_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_identity_passkey_ceremony_candidates_on_ref ON public.identity_passkey_ceremony_candidates USING btree (ref);


--
-- Name: index_identity_secret_credential_ceremony_candidates_on_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_identity_secret_credential_ceremony_candidates_on_ref ON public.identity_secret_credential_ceremony_candidates USING btree (ref);


--
-- Name: index_identity_social_ceremony_candidates_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_identity_social_ceremony_candidates_on_expires_at ON public.identity_social_ceremony_candidates USING btree (expires_at);


--
-- Name: index_identity_social_ceremony_candidates_on_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_identity_social_ceremony_candidates_on_ref ON public.identity_social_ceremony_candidates USING btree (ref);


--
-- Name: index_identity_totp_ceremony_candidates_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_identity_totp_ceremony_candidates_on_expires_at ON public.identity_totp_ceremony_candidates USING btree (expires_at);


--
-- Name: index_identity_totp_ceremony_candidates_on_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_identity_totp_ceremony_candidates_on_ref ON public.identity_totp_ceremony_candidates USING btree (ref);


--
-- Name: index_logout_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_logout_transactions_on_expires_at ON public.logout_transactions USING btree (expires_at);


--
-- Name: index_logout_transactions_on_issuer_and_audience_and_purpose; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_logout_transactions_on_issuer_and_audience_and_purpose ON public.logout_transactions USING btree (issuer, audience, purpose);


--
-- Name: index_logout_transactions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_logout_transactions_on_public_id ON public.logout_transactions USING btree (public_id);


--
-- Name: index_logout_transactions_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_logout_transactions_on_token_digest ON public.logout_transactions USING btree (token_digest);


--
-- Name: index_op_app_grants_on_client_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_op_app_grants_on_client_token_id ON public.op_app_grants USING btree (client_token_id);


--
-- Name: index_op_app_grants_on_oidc_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_op_app_grants_on_oidc_client_id ON public.op_app_grants USING btree (oidc_client_id);


--
-- Name: index_op_app_grants_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_op_app_grants_on_public_id ON public.op_app_grants USING btree (public_id);


--
-- Name: index_op_app_grants_on_refresh_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_op_app_grants_on_refresh_token_digest ON public.op_app_grants USING btree (refresh_token_digest) WHERE (refresh_token_digest IS NOT NULL);


--
-- Name: index_op_app_grants_on_revoked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_op_app_grants_on_revoked_at ON public.op_app_grants USING btree (revoked_at);


--
-- Name: index_security_consumed_jtis_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_security_consumed_jtis_on_expires_at ON public.security_consumed_jtis USING btree (expires_at);


--
-- Name: index_security_one_time_reveals_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_security_one_time_reveals_on_expires_at ON public.security_one_time_reveals USING btree (expires_at);


--
-- Name: index_security_one_time_reveals_on_jti_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_security_one_time_reveals_on_jti_digest ON public.security_one_time_reveals USING btree (jti_digest);


--
-- Name: index_turnstile_replays_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_turnstile_replays_on_expires_at ON public.turnstile_replays USING btree (expires_at);


--
-- Name: index_turnstile_replays_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_turnstile_replays_on_token_digest ON public.turnstile_replays USING btree (token_digest);


--
-- Name: client_auth_ceremony_sessions client_auth_email_otp_proof_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_auth_email_otp_proof_trigger BEFORE UPDATE OF email_otp_context ON public.client_auth_ceremony_sessions FOR EACH ROW EXECUTE FUNCTION public.enforce_client_auth_email_otp_proof();


--
-- Name: client_email_ceremony_transactions client_email_terminal_otp_facts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_email_terminal_otp_facts BEFORE UPDATE ON public.client_email_ceremony_transactions FOR EACH ROW EXECUTE FUNCTION public.enforce_client_email_terminal_otp_facts();


--
-- Name: client_telephone_ceremony_transactions client_telephone_terminal_otp_facts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_telephone_terminal_otp_facts BEFORE UPDATE ON public.client_telephone_ceremony_transactions FOR EACH ROW EXECUTE FUNCTION public.enforce_client_telephone_terminal_otp_facts();


--
-- Name: client_email_ceremony_transactions client_email_otp_original_bootstrap_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_email_ceremony_transactions
    ADD CONSTRAINT client_email_otp_original_bootstrap_fk FOREIGN KEY (bootstrap_ceremony_transaction_ref) REFERENCES public.client_step_up_ceremony_transactions(transaction_id);


--
-- Name: client_auth_admission_bindings fk_client_auth_admission_bindings_admitted_session; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_auth_admission_bindings
    ADD CONSTRAINT fk_client_auth_admission_bindings_admitted_session FOREIGN KEY (admitted_auth_ceremony_session_id) REFERENCES public.client_auth_ceremony_sessions(id) ON DELETE RESTRICT;


--
-- Name: client_device_sessions fk_client_device_sessions_on_current_refresh_token_owner; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_device_sessions
    ADD CONSTRAINT fk_client_device_sessions_on_current_refresh_token_owner FOREIGN KEY (id, current_refresh_token_id) REFERENCES public.client_tokens(device_session_id, id) ON DELETE SET NULL (current_refresh_token_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: client_tokens fk_client_tokens_on_device_session_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_tokens
    ADD CONSTRAINT fk_client_tokens_on_device_session_id FOREIGN KEY (device_session_id) REFERENCES public.client_device_sessions(id) ON DELETE RESTRICT;


--
-- Name: client_tokens fk_client_tokens_on_user_id_and_device_session_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_tokens
    ADD CONSTRAINT fk_client_tokens_on_user_id_and_device_session_id FOREIGN KEY (user_id, device_session_id) REFERENCES public.client_device_sessions(user_id, id) ON DELETE RESTRICT;


--
-- Name: op_app_grants fk_op_app_grants_on_device_session_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.op_app_grants
    ADD CONSTRAINT fk_op_app_grants_on_device_session_id FOREIGN KEY (device_session_id) REFERENCES public.client_device_sessions(id) ON DELETE RESTRICT;


--
-- Name: client_oidc_authorization_transactions fk_rails_033ead371e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_oidc_authorization_transactions
    ADD CONSTRAINT fk_rails_033ead371e FOREIGN KEY (secret_sign_in_flow_id) REFERENCES public.client_sign_in_flows(id) ON DELETE RESTRICT;


--
-- Name: client_verifications fk_rails_18a774c144; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_verifications
    ADD CONSTRAINT fk_rails_18a774c144 FOREIGN KEY (user_token_id) REFERENCES public.client_tokens(id) ON DELETE CASCADE;


--
-- Name: logout_flow_participants fk_rails_1b37d291d0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.logout_flow_participants
    ADD CONSTRAINT fk_rails_1b37d291d0 FOREIGN KEY (logout_flow_id) REFERENCES public.logout_flows(id);


--
-- Name: client_totp_ceremony_transactions fk_rails_23f495015b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_totp_ceremony_transactions
    ADD CONSTRAINT fk_rails_23f495015b FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.client_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;


--
-- Name: client_auth_ceremony_sessions fk_rails_268e296ad7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_auth_ceremony_sessions
    ADD CONSTRAINT fk_rails_268e296ad7 FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.client_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;


--
-- Name: client_sign_in_flows fk_rails_270e4e1241; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_in_flows
    ADD CONSTRAINT fk_rails_270e4e1241 FOREIGN KEY (state_id) REFERENCES public.client_sign_in_flow_states(id) ON DELETE RESTRICT;


--
-- Name: client_secret_sign_in_receipts fk_rails_33b6c86074; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_sign_in_receipts
    ADD CONSTRAINT fk_rails_33b6c86074 FOREIGN KEY (sign_in_flow_id) REFERENCES public.client_sign_in_flows(id);


--
-- Name: identity_passkey_ceremony_candidates fk_rails_361c3e050e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_passkey_ceremony_candidates
    ADD CONSTRAINT fk_rails_361c3e050e FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.client_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;


--
-- Name: client_auth_admission_bindings fk_rails_39848a51b7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_auth_admission_bindings
    ADD CONSTRAINT fk_rails_39848a51b7 FOREIGN KEY (auth_ceremony_session_id) REFERENCES public.client_auth_ceremony_sessions(id) ON DELETE RESTRICT;


--
-- Name: client_sign_out_flows fk_rails_39d731f429; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_out_flows
    ADD CONSTRAINT fk_rails_39d731f429 FOREIGN KEY (kind_id) REFERENCES public.client_sign_out_flow_kinds(id);


--
-- Name: client_session_limit_resolution_transactions fk_rails_43ba40ab14; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_session_limit_resolution_transactions
    ADD CONSTRAINT fk_rails_43ba40ab14 FOREIGN KEY (oidc_authorization_transaction_id) REFERENCES public.client_oidc_authorization_transactions(id) ON DELETE RESTRICT;


--
-- Name: client_auth_admission_bindings fk_rails_4b33a13a31; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_auth_admission_bindings
    ADD CONSTRAINT fk_rails_4b33a13a31 FOREIGN KEY (sign_in_flow_id) REFERENCES public.client_sign_in_flows(id) ON DELETE RESTRICT;


--
-- Name: client_sign_out_flows fk_rails_4bbbc632e2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_out_flows
    ADD CONSTRAINT fk_rails_4bbbc632e2 FOREIGN KEY (token_id) REFERENCES public.client_tokens(id) ON DELETE CASCADE;


--
-- Name: client_sign_up_flows fk_rails_533362926d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_up_flows
    ADD CONSTRAINT fk_rails_533362926d FOREIGN KEY (status_id) REFERENCES public.client_sign_up_flow_statuses(id) ON DELETE RESTRICT;


--
-- Name: identity_totp_ceremony_candidates fk_rails_5e9f08645d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_totp_ceremony_candidates
    ADD CONSTRAINT fk_rails_5e9f08645d FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.client_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;


--
-- Name: client_auth_ceremony_sessions fk_rails_6413141ed8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_auth_ceremony_sessions
    ADD CONSTRAINT fk_rails_6413141ed8 FOREIGN KEY (local_sign_up_flow_ref) REFERENCES public.client_sign_up_flows(public_id) ON DELETE RESTRICT;


--
-- Name: client_step_up_sessions fk_rails_64ec203fd3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_step_up_sessions
    ADD CONSTRAINT fk_rails_64ec203fd3 FOREIGN KEY (user_token_id) REFERENCES public.client_tokens(id) ON DELETE CASCADE;


--
-- Name: client_auth_ceremony_sessions fk_rails_694b855234; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_auth_ceremony_sessions
    ADD CONSTRAINT fk_rails_694b855234 FOREIGN KEY (local_sign_in_flow_ref) REFERENCES public.client_sign_in_flows(public_id) ON DELETE RESTRICT;


--
-- Name: client_auth_admission_bindings fk_rails_75a744b56d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_auth_admission_bindings
    ADD CONSTRAINT fk_rails_75a744b56d FOREIGN KEY (step_up_ceremony_transaction_id) REFERENCES public.client_step_up_ceremony_transactions(id) ON DELETE RESTRICT;


--
-- Name: client_sign_up_flows fk_rails_7b193122e7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_up_flows
    ADD CONSTRAINT fk_rails_7b193122e7 FOREIGN KEY (token_id) REFERENCES public.client_tokens(id) ON DELETE RESTRICT;


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
-- Name: client_step_up_sessions fk_rails_96e42d5326; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_step_up_sessions
    ADD CONSTRAINT fk_rails_96e42d5326 FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.client_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;


--
-- Name: client_sign_up_flows fk_rails_9b0b63a0c6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_up_flows
    ADD CONSTRAINT fk_rails_9b0b63a0c6 FOREIGN KEY (cleanup_status_id) REFERENCES public.client_sign_up_flow_cleanup_statuses(id);


--
-- Name: client_session_limit_resolution_transactions fk_rails_9b828d9261; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_session_limit_resolution_transactions
    ADD CONSTRAINT fk_rails_9b828d9261 FOREIGN KEY (state_id) REFERENCES public.client_session_limit_resolution_states(id) ON DELETE RESTRICT;


--
-- Name: client_session_limit_resolution_transactions fk_rails_a143c4909c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_session_limit_resolution_transactions
    ADD CONSTRAINT fk_rails_a143c4909c FOREIGN KEY (sign_in_flow_id) REFERENCES public.client_sign_in_flows(id) ON DELETE RESTRICT;


--
-- Name: client_passkey_ceremony_transactions fk_rails_aac854f11a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_passkey_ceremony_transactions
    ADD CONSTRAINT fk_rails_aac854f11a FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.client_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;


--
-- Name: client_sign_out_flows fk_rails_bbc7001388; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_out_flows
    ADD CONSTRAINT fk_rails_bbc7001388 FOREIGN KEY (status_id) REFERENCES public.client_sign_out_flow_statuses(id);


--
-- Name: client_sign_in_flows fk_rails_bd772deef1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_in_flows
    ADD CONSTRAINT fk_rails_bd772deef1 FOREIGN KEY (token_id) REFERENCES public.client_tokens(id) ON DELETE CASCADE;


--
-- Name: client_tokens fk_rails_c11b41180d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_tokens
    ADD CONSTRAINT fk_rails_c11b41180d FOREIGN KEY (user_token_status_id) REFERENCES public.client_token_statuses(id) ON DELETE RESTRICT;


--
-- Name: client_auth_admission_bindings fk_rails_cb75eed72c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_auth_admission_bindings
    ADD CONSTRAINT fk_rails_cb75eed72c FOREIGN KEY (base_token_id) REFERENCES public.client_tokens(id) ON DELETE RESTRICT;


--
-- Name: client_emergency_sign_in_operations fk_rails_e979437e5d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_emergency_sign_in_operations
    ADD CONSTRAINT fk_rails_e979437e5d FOREIGN KEY (client_token_id) REFERENCES public.client_tokens(id);


--
-- Name: client_auth_admission_bindings fk_rails_eafe7e9042; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_auth_admission_bindings
    ADD CONSTRAINT fk_rails_eafe7e9042 FOREIGN KEY (authorization_transaction_id) REFERENCES public.client_oidc_authorization_transactions(id) ON DELETE RESTRICT;


--
-- Name: client_tokens fk_rails_f69bf5b8f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_tokens
    ADD CONSTRAINT fk_rails_f69bf5b8f0 FOREIGN KEY (user_token_kind_id) REFERENCES public.client_token_kinds(id) ON DELETE RESTRICT;


--
-- Name: client_tokens fk_user_tokens_on_user_token_binding_method_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_tokens
    ADD CONSTRAINT fk_user_tokens_on_user_token_binding_method_id FOREIGN KEY (user_token_binding_method_id) REFERENCES public.client_token_binding_methods(id);


--
-- Name: client_tokens fk_user_tokens_on_user_token_dbsc_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_tokens
    ADD CONSTRAINT fk_user_tokens_on_user_token_dbsc_status_id FOREIGN KEY (user_token_dbsc_status_id) REFERENCES public.client_token_dbsc_statuses(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261017150000'),
('20261017140000'),
('20261017070000'),
('20261016210020'),
('20261016210013'),
('20261016210010'),
('20261016200000'),
('20261016160070'),
('20261016160060'),
('20261016160050'),
('20261016160040'),
('20261016160030'),
('20261016160020'),
('20261016160010'),
('20261016160000'),
('20261014120000'),
('20261012093101'),
('20261012093001'),
('20261012092103'),
('20261012092003'),
('20261008150716'),
('20261008145850'),
('20261008094435'),
('20261008093810'),
('20261008062953'),
('20261008062818'),
('20261007223842'),
('20261007223739'),
('20261007161124'),
('20261007160107'),
('20261007153150'),
('20261006230003'),
('20261006230002'),
('20261006230001'),
('20261006230000'),
('20261006220000'),
('20261006210010'),
('20261006210000'),
('20261006200000'),
('20261006195000'),
('20261006190100'),
('20261006190000'),
('20261006170000'),
('20261006160000'),
('20261006150000'),
('20261006140000'),
('20261006130000'),
('20261006120000'),
('20261006110003'),
('20261005080938'),
('20261005080855'),
('20261005045901'),
('20261003221628'),
('20261003215633'),
('20261003215004'),
('20261003202100'),
('20261003185506'),
('20261003183659'),
('20261003181712'),
('20261003175614'),
('20261002120000'),
('20260926170000'),
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
('20260917130000'),
('20260915180000'),
('20260915170000'),
('20260915160000'),
('20260913150000'),
('20260913140000'),
('20260905000000'),
('20260831064124'),
('20260831064102'),
('20260727100001'),
('20260727100000'),
('20260710220000'),
('20260626000000'),
('20260624000000'),
('20260623120000'),
('20260621150000'),
('20260619120000'),
('20260618130000'),
('20260618120000'),
('20260616150020'),
('20260616150010'),
('20260616150005'),
('20260616150000'),
('20260612000001'),
('20260611150000'),
('20260611100000'),
('20260606120000'),
('20260603140000'),
('20260603130000'),
('20260603124000'),
('20260603123000'),
('20260603122000'),
('20260603121000'),
('20260603120000'),
('20260530130100'),
('20260530130000'),
('20260528183000'),
('20260528162100'),
('20260526120100'),
('20260526120000'),
('20260525233000'),
('20260525210000'),
('20260525200500'),
('20260525200000'),
('20260525131500'),
('20260525124500'),
('20260525123000'),
('20260520190000'),
('20260520143011'),
('20260520143002'),
('20260520130000'),
('20260519111000'),
('20260519110000'),
('20260519092000'),
('20260519091000'),
('20260519090000'),
('20260518085548'),
('20260518084934'),
('20260518044313'),
('20260518020000'),
('20260517120000'),
('20260508202600'),
('20260508160000'),
('20260508151000'),
('20260508140999'),
('20260508135006'),
('20260507010001'),
('20260501000000');

