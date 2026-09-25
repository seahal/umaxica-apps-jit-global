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
-- Name: visitor_verifications; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_verifications (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    visitor_token_id bigint NOT NULL,
    last_used_at timestamp(6) with time zone,
    token_digest character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT chk_customer_verifications_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: customer_verifications_customer_token_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.customer_verifications_customer_token_id_seq
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
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: visitor_auth_ceremony_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_auth_ceremony_sessions (
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
    CONSTRAINT visitor_auth_ceremony_sessions_admission_binding CHECK (((authorization_transaction_ref IS NULL) OR (admitted_at IS NOT NULL))),
    CONSTRAINT visitor_auth_ceremony_sessions_authentication_evidence_pair CHECK (((authentication_method IS NULL) = (authentication_event_at IS NULL))),
    CONSTRAINT visitor_auth_ceremony_sessions_authentication_method CHECK (((authentication_method IS NULL) OR ((authentication_method)::text = ANY (ARRAY[('email'::character varying)::text, ('telephone'::character varying)::text, ('secret'::character varying)::text, ('passkey'::character varying)::text, ('totp'::character varying)::text, ('google'::character varying)::text, ('apple'::character varying)::text, ('entra'::character varying)::text])))),
    CONSTRAINT visitor_auth_ceremony_sessions_one_terminal_timestamp CHECK ((num_nonnulls(revoked_at, completed_at, cancelled_at) <= 1))
);


--
-- Name: visitor_auth_ceremony_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_auth_ceremony_sessions_id_seq
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

CREATE UNLOGGED TABLE public.visitor_device_sessions (
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
    last_network_hmac character varying
);


--
-- Name: visitor_device_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_device_sessions_id_seq
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

CREATE UNLOGGED TABLE public.visitor_dpop_proof_states (
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

CREATE UNLOGGED SEQUENCE public.visitor_dpop_proof_states_id_seq
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

CREATE UNLOGGED TABLE public.visitor_email_ceremony_transactions (
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
    evp_attempt_count integer DEFAULT 0 NOT NULL
);


--
-- Name: visitor_email_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_email_ceremony_transactions_id_seq
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

CREATE UNLOGGED TABLE public.visitor_oidc_authorization_transactions (
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
    code_challenge_method character varying NOT NULL,
    login_challenge character varying NOT NULL,
    login_challenge_expires_at timestamp(6) with time zone NOT NULL,
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
    result_generation integer DEFAULT 0 NOT NULL,
    result_digest character varying(64),
    result_expires_at timestamp(6) with time zone,
    result_consumed_at timestamp(6) with time zone,
    browser_session_ref character varying,
    base_finalized_at timestamp(6) with time zone,
    authorization_grant_redeemed_at timestamp(6) with time zone,
    CONSTRAINT visitor_oidc_auth_transactions_result_generation_nonnegative CHECK ((result_generation >= 0))
);


--
-- Name: visitor_oidc_authorization_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_oidc_authorization_transactions_id_seq
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

CREATE UNLOGGED TABLE public.visitor_oidc_connections (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    visitor_id bigint NOT NULL,
    client_id character varying(64) NOT NULL,
    scope character varying,
    last_used_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_oidc_connections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_oidc_connections_id_seq
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
-- Name: visitor_passkey_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_passkey_ceremony_transactions (
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
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_passkey_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_passkey_ceremony_transactions_id_seq
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
-- Name: visitor_rp_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_rp_sessions (
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
    oidc_access_token_max_expires_at timestamp(6) with time zone
);


--
-- Name: visitor_rp_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_rp_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_rp_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_rp_sessions_id_seq OWNED BY public.visitor_rp_sessions.id;


--
-- Name: visitor_secret_credential_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_secret_credential_ceremony_transactions (
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
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_secret_credential_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_secret_credential_ceremony_transactions_id_seq
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
-- Name: visitor_sign_in_flow_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_sign_in_flow_statuses (
    id bigint NOT NULL
);


--
-- Name: visitor_sign_in_flow_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_sign_in_flow_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_sign_in_flow_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_sign_in_flow_statuses_id_seq OWNED BY public.visitor_sign_in_flow_statuses.id;


--
-- Name: visitor_sign_in_flows; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_sign_in_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    principal_id bigint,
    token_id bigint,
    state character varying NOT NULL,
    step character varying NOT NULL,
    return_to text,
    nonce_digest character varying NOT NULL,
    issued_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    selected_region_id bigint,
    selected_persona_id bigint,
    selector_completed_at timestamp(6) with time zone,
    session_issued_at timestamp(6) with time zone,
    CONSTRAINT chk_com_sign_in_sequence_tickets_lifetime_order CHECK ((issued_at < expires_at)),
    CONSTRAINT chk_com_sign_in_sequence_tickets_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: visitor_sign_in_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_sign_in_flows_id_seq
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

CREATE UNLOGGED TABLE public.visitor_sign_out_flow_kinds (
    id bigint NOT NULL
);


--
-- Name: visitor_sign_out_flow_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_sign_out_flow_kinds_id_seq
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

CREATE UNLOGGED TABLE public.visitor_sign_out_flow_statuses (
    id bigint NOT NULL
);


--
-- Name: visitor_sign_out_flow_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_sign_out_flow_statuses_id_seq
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

CREATE UNLOGGED TABLE public.visitor_sign_out_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    principal_id bigint,
    token_id bigint,
    status_id bigint DEFAULT 10 NOT NULL,
    kind_id bigint DEFAULT 0 NOT NULL,
    refresh_token_family_id character varying,
    requested_at timestamp(6) with time zone NOT NULL,
    access_discarded_at timestamp(6) with time zone,
    logically_revoked_at timestamp(6) with time zone,
    access_expires_at timestamp(6) with time zone NOT NULL,
    refresh_expires_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    return_to text,
    nonce_digest character varying,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_visitor_sign_out_cycles_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT chk_visitor_sign_out_cycles_token_expiry_order CHECK ((access_expires_at <= refresh_expires_at))
);


--
-- Name: visitor_sign_out_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_sign_out_flows_id_seq
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

CREATE UNLOGGED TABLE public.visitor_sign_up_flow_cleanup_statuses (
    id bigint NOT NULL
);


--
-- Name: visitor_sign_up_flow_cleanup_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_sign_up_flow_cleanup_statuses_id_seq
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

CREATE UNLOGGED TABLE public.visitor_sign_up_flow_statuses (
    id bigint NOT NULL
);


--
-- Name: visitor_sign_up_flow_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_sign_up_flow_statuses_id_seq
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

CREATE UNLOGGED TABLE public.visitor_sign_up_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    principal_id bigint,
    token_id bigint,
    state character varying NOT NULL,
    step character varying NOT NULL,
    return_to text,
    nonce_digest character varying NOT NULL,
    issued_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    entry_method character varying NOT NULL,
    pending_contact_type character varying,
    pending_contact_id bigint,
    social_provider character varying,
    completed_requirements jsonb DEFAULT '{}'::jsonb NOT NULL,
    failed_at timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    checkpoint_version integer DEFAULT 0 NOT NULL,
    cleanup_attempted_at timestamp(6) with time zone,
    cleanup_completed_at timestamp(6) with time zone,
    cleanup_error_code character varying,
    pending_passkey_registration_id bigint,
    cleanup_attempts_count integer DEFAULT 0 NOT NULL,
    cleanup_status_id bigint DEFAULT 10 NOT NULL,
    CONSTRAINT chk_com_sign_up_sequence_tickets_lifetime_order CHECK ((issued_at < expires_at)),
    CONSTRAINT chk_com_sign_up_sequence_tickets_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: visitor_sign_up_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_sign_up_flows_id_seq
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

CREATE UNLOGGED TABLE public.visitor_step_up_ceremony_transactions (
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
    phishing_resistant_required boolean DEFAULT false NOT NULL,
    phishing_resistant boolean DEFAULT false NOT NULL
);


--
-- Name: visitor_step_up_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_step_up_ceremony_transactions_id_seq
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

CREATE UNLOGGED TABLE public.visitor_step_up_sessions (
    id bigint NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    visitor_token_id bigint NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    method character varying,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    return_to text NOT NULL,
    scope character varying NOT NULL,
    status character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    verified_at timestamp(6) with time zone
);


--
-- Name: visitor_step_up_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_step_up_sessions_id_seq
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

CREATE UNLOGGED TABLE public.visitor_telephone_ceremony_transactions (
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
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_telephone_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_telephone_ceremony_transactions_id_seq
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

CREATE UNLOGGED TABLE public.visitor_token_binding_methods (
    id bigint NOT NULL
);


--
-- Name: visitor_token_binding_methods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_token_binding_methods_id_seq
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

CREATE UNLOGGED TABLE public.visitor_token_dbsc_statuses (
    id bigint NOT NULL
);


--
-- Name: visitor_token_dbsc_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_token_dbsc_statuses_id_seq
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

CREATE UNLOGGED TABLE public.visitor_token_kinds (
    id bigint NOT NULL
);


--
-- Name: visitor_token_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_token_kinds_id_seq
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

CREATE UNLOGGED TABLE public.visitor_token_statuses (
    id bigint NOT NULL
);


--
-- Name: visitor_token_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_token_statuses_id_seq
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

CREATE UNLOGGED TABLE public.visitor_tokens (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    visitor_id bigint NOT NULL,
    visitor_token_binding_method_id bigint DEFAULT 0 NOT NULL,
    visitor_token_dbsc_status_id bigint DEFAULT 0 NOT NULL,
    visitor_token_kind_id bigint DEFAULT 1 NOT NULL,
    visitor_token_status_id bigint DEFAULT 1 NOT NULL,
    dbsc_challenge text,
    dbsc_challenge_issued_at timestamp(6) with time zone,
    dbsc_public_key jsonb,
    dbsc_session_id character varying,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    last_step_up_at timestamp(6) with time zone,
    last_step_up_scope character varying,
    last_used_at timestamp(6) with time zone,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    refresh_token_digest bytea,
    refresh_token_family_id character varying,
    refresh_token_generation integer DEFAULT 0 NOT NULL,
    rotated_at timestamp(6) with time zone,
    updated_at timestamp(6) with time zone NOT NULL,
    dpop_jkt character varying,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    oidc_connection_id bigint,
    oidc_client_id character varying(64),
    oidc_scope character varying,
    oidc_sid uuid DEFAULT gen_random_uuid(),
    oidc_jti uuid DEFAULT gen_random_uuid(),
    device_session_id bigint,
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
    CONSTRAINT chk_customer_tokens_kind_id_positive CHECK ((visitor_token_kind_id >= 0)),
    CONSTRAINT chk_customer_tokens_status_id_positive CHECK ((visitor_token_status_id >= 0)),
    CONSTRAINT chk_visitor_tokens_established_authentication_method CHECK (((established_authentication_method IS NULL) OR ((established_authentication_method)::text = ANY (ARRAY[('email'::character varying)::text, ('telephone'::character varying)::text, ('secret'::character varying)::text, ('passkey'::character varying)::text]))))
);


--
-- Name: visitor_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_tokens_id_seq
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

CREATE UNLOGGED SEQUENCE public.visitor_verifications_id_seq
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
-- Name: visitor_passkey_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_passkey_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.visitor_passkey_ceremony_transactions_id_seq'::regclass);


--
-- Name: visitor_rp_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_rp_sessions ALTER COLUMN id SET DEFAULT nextval('public.visitor_rp_sessions_id_seq'::regclass);


--
-- Name: visitor_secret_credential_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credential_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.visitor_secret_credential_ceremony_transactions_id_seq'::regclass);


--
-- Name: visitor_sign_in_flow_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_in_flow_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_sign_in_flow_statuses_id_seq'::regclass);


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
-- Name: visitor_sign_in_flows chk_visitor_sign_in_cycles_status_state; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.visitor_sign_in_flows
    ADD CONSTRAINT chk_visitor_sign_in_cycles_status_state CHECK (((state)::text =
CASE status_id
    WHEN 10 THEN 'PRIMARY_PENDING'::text
    WHEN 20 THEN 'MFA_PENDING'::text
    WHEN 30 THEN 'SESSION_LIMIT_PENDING'::text
    WHEN 40 THEN 'GUARDRAIL_PENDING'::text
    WHEN 50 THEN 'SESSION_ISSUANCE_PENDING'::text
    WHEN 60 THEN 'CHECKPOINT_PENDING'::text
    WHEN 65 THEN 'SELECTOR_PENDING'::text
    WHEN 70 THEN 'DASHBOARD_PENDING'::text
    WHEN 80 THEN 'RETURN_PENDING'::text
    WHEN 100 THEN 'COMPLETED'::text
    WHEN 900 THEN 'FAILED'::text
    ELSE NULL::text
END)) NOT VALID;


--
-- Name: visitor_sign_in_flows chk_visitor_sign_in_cycles_status_step; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.visitor_sign_in_flows
    ADD CONSTRAINT chk_visitor_sign_in_cycles_status_step CHECK (((step)::text =
CASE status_id
    WHEN 10 THEN 'primary'::text
    WHEN 20 THEN 'mfa'::text
    WHEN 30 THEN 'session_limit'::text
    WHEN 40 THEN 'guardrail'::text
    WHEN 50 THEN 'session_issuance'::text
    WHEN 60 THEN 'checkpoint'::text
    WHEN 65 THEN 'selector'::text
    WHEN 70 THEN 'dashboard'::text
    WHEN 80 THEN 'return_to'::text
    WHEN 100 THEN 'completed'::text
    WHEN 900 THEN 'failed'::text
    ELSE NULL::text
END)) NOT VALID;


--
-- Name: visitor_step_up_sessions chk_visitor_step_up_sessions_retention_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.visitor_step_up_sessions
    ADD CONSTRAINT chk_visitor_step_up_sessions_retention_order CHECK ((discard_at <= purge_eligible_at)) NOT VALID;


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


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
-- Name: visitor_passkey_ceremony_transactions visitor_passkey_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_passkey_ceremony_transactions
    ADD CONSTRAINT visitor_passkey_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: visitor_rp_sessions visitor_rp_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_rp_sessions
    ADD CONSTRAINT visitor_rp_sessions_pkey PRIMARY KEY (id);


--
-- Name: visitor_secret_credential_ceremony_transactions visitor_secret_credential_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credential_ceremony_transactions
    ADD CONSTRAINT visitor_secret_credential_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: visitor_sign_in_flow_statuses visitor_sign_in_flow_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_in_flow_statuses
    ADD CONSTRAINT visitor_sign_in_flow_statuses_pkey PRIMARY KEY (id);


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
-- Name: idx_active_visitor_rp_session_per_rp; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_active_visitor_rp_session_per_rp ON public.visitor_rp_sessions USING btree (visitor_token_id, oidc_client_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_auth_ceremony_sessions_on_tx_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_auth_ceremony_sessions_on_tx_ref ON public.visitor_auth_ceremony_sessions USING btree (authorization_transaction_ref) WHERE (authorization_transaction_ref IS NOT NULL);


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
-- Name: idx_visitor_sign_up_flows_cleanup_status_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_visitor_sign_up_flows_cleanup_status_purge_eligible_at ON public.visitor_sign_up_flows USING btree (cleanup_status_id, purge_eligible_at);


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
-- Name: index_visitor_device_sessions_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_device_sessions_on_visitor_id ON public.visitor_device_sessions USING btree (visitor_id);


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
-- Name: index_visitor_rp_sessions_on_oidc_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_rp_sessions_on_oidc_client_id ON public.visitor_rp_sessions USING btree (oidc_client_id);


--
-- Name: index_visitor_rp_sessions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_rp_sessions_on_public_id ON public.visitor_rp_sessions USING btree (public_id);


--
-- Name: index_visitor_rp_sessions_on_refresh_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_rp_sessions_on_refresh_token_digest ON public.visitor_rp_sessions USING btree (refresh_token_digest) WHERE (refresh_token_digest IS NOT NULL);


--
-- Name: index_visitor_rp_sessions_on_revoked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_rp_sessions_on_revoked_at ON public.visitor_rp_sessions USING btree (revoked_at);


--
-- Name: index_visitor_rp_sessions_on_visitor_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_rp_sessions_on_visitor_token_id ON public.visitor_rp_sessions USING btree (visitor_token_id);


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
-- Name: index_visitor_sign_in_flows_on_selected_persona_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_in_flows_on_selected_persona_id ON public.visitor_sign_in_flows USING btree (selected_persona_id);


--
-- Name: index_visitor_sign_in_flows_on_selected_region_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_in_flows_on_selected_region_id ON public.visitor_sign_in_flows USING btree (selected_region_id);


--
-- Name: index_visitor_sign_in_flows_on_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_in_flows_on_state ON public.visitor_sign_in_flows USING btree (state);


--
-- Name: index_visitor_sign_in_flows_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_in_flows_on_status_id ON public.visitor_sign_in_flows USING btree (status_id);


--
-- Name: index_visitor_sign_in_flows_on_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_sign_in_flows_on_token_id ON public.visitor_sign_in_flows USING btree (token_id);


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
-- Name: index_visitor_step_up_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_step_up_ceremony_transactions_on_result_jti ON public.visitor_step_up_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_visitor_step_up_ceremony_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_step_up_ceremony_transactions_on_transaction_id ON public.visitor_step_up_ceremony_transactions USING btree (transaction_id);


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
-- Name: visitor_tokens fk_customer_tokens_on_customer_token_binding_method_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_tokens
    ADD CONSTRAINT fk_customer_tokens_on_customer_token_binding_method_id FOREIGN KEY (visitor_token_binding_method_id) REFERENCES public.visitor_token_binding_methods(id) NOT VALID;


--
-- Name: visitor_tokens fk_customer_tokens_on_customer_token_dbsc_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_tokens
    ADD CONSTRAINT fk_customer_tokens_on_customer_token_dbsc_status_id FOREIGN KEY (visitor_token_dbsc_status_id) REFERENCES public.visitor_token_dbsc_statuses(id) NOT VALID;


--
-- Name: visitor_tokens fk_customer_tokens_on_customer_token_kind_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_tokens
    ADD CONSTRAINT fk_customer_tokens_on_customer_token_kind_id FOREIGN KEY (visitor_token_kind_id) REFERENCES public.visitor_token_kinds(id) NOT VALID;


--
-- Name: visitor_tokens fk_customer_tokens_on_customer_token_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_tokens
    ADD CONSTRAINT fk_customer_tokens_on_customer_token_status_id FOREIGN KEY (visitor_token_status_id) REFERENCES public.visitor_token_statuses(id) NOT VALID;


--
-- Name: visitor_sign_out_flows fk_rails_0289bc0560; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_out_flows
    ADD CONSTRAINT fk_rails_0289bc0560 FOREIGN KEY (status_id) REFERENCES public.visitor_sign_out_flow_statuses(id) NOT VALID;


--
-- Name: visitor_sign_out_flows fk_rails_173a30a232; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_out_flows
    ADD CONSTRAINT fk_rails_173a30a232 FOREIGN KEY (token_id) REFERENCES public.visitor_tokens(id) ON DELETE CASCADE NOT VALID;


--
-- Name: visitor_verifications fk_rails_2b1e12b132; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_verifications
    ADD CONSTRAINT fk_rails_2b1e12b132 FOREIGN KEY (visitor_token_id) REFERENCES public.visitor_tokens(id) NOT VALID;


--
-- Name: visitor_rp_sessions fk_rails_367c8ed0a4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_rp_sessions
    ADD CONSTRAINT fk_rails_367c8ed0a4 FOREIGN KEY (visitor_token_id) REFERENCES public.visitor_tokens(id) ON DELETE CASCADE;


--
-- Name: visitor_sign_in_flows fk_rails_75353bbdcf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_in_flows
    ADD CONSTRAINT fk_rails_75353bbdcf FOREIGN KEY (status_id) REFERENCES public.visitor_sign_in_flow_statuses(id) NOT VALID;


--
-- Name: visitor_sign_up_flows fk_rails_85a641d47f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_up_flows
    ADD CONSTRAINT fk_rails_85a641d47f FOREIGN KEY (token_id) REFERENCES public.visitor_tokens(id) ON DELETE RESTRICT;


--
-- Name: visitor_sign_up_flows fk_rails_8cef237db7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_up_flows
    ADD CONSTRAINT fk_rails_8cef237db7 FOREIGN KEY (status_id) REFERENCES public.visitor_sign_up_flow_statuses(id) ON DELETE RESTRICT NOT VALID;


--
-- Name: visitor_sign_out_flows fk_rails_8ef47d5e3c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_out_flows
    ADD CONSTRAINT fk_rails_8ef47d5e3c FOREIGN KEY (kind_id) REFERENCES public.visitor_sign_out_flow_kinds(id) NOT VALID;


--
-- Name: visitor_sign_in_flows fk_rails_9797ae40cc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_in_flows
    ADD CONSTRAINT fk_rails_9797ae40cc FOREIGN KEY (token_id) REFERENCES public.visitor_tokens(id) ON DELETE CASCADE NOT VALID;


--
-- Name: visitor_step_up_sessions fk_rails_cd1cdc6b2d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_step_up_sessions
    ADD CONSTRAINT fk_rails_cd1cdc6b2d FOREIGN KEY (visitor_token_id) REFERENCES public.visitor_tokens(id) ON DELETE CASCADE NOT VALID;


--
-- Name: visitor_sign_up_flows fk_rails_cf6ee54a77; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_sign_up_flows
    ADD CONSTRAINT fk_rails_cf6ee54a77 FOREIGN KEY (cleanup_status_id) REFERENCES public.visitor_sign_up_flow_cleanup_statuses(id) NOT VALID;


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
-- Name: visitor_tokens fk_visitor_tokens_on_visitor_id_and_device_session_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_tokens
    ADD CONSTRAINT fk_visitor_tokens_on_visitor_id_and_device_session_id FOREIGN KEY (visitor_id, device_session_id) REFERENCES public.visitor_device_sessions(visitor_id, id) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
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
