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
-- Name: operator_auth_ceremony_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_auth_ceremony_sessions (
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
    CONSTRAINT operator_auth_ceremony_sessions_admission_binding CHECK (((authorization_transaction_ref IS NULL) OR (admitted_at IS NOT NULL))),
    CONSTRAINT operator_auth_ceremony_sessions_one_terminal_timestamp CHECK ((num_nonnulls(revoked_at, completed_at, cancelled_at) <= 1))
);


--
-- Name: operator_auth_ceremony_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_auth_ceremony_sessions_id_seq
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

CREATE UNLOGGED TABLE public.operator_device_sessions (
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

CREATE UNLOGGED SEQUENCE public.operator_device_sessions_id_seq
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

CREATE UNLOGGED TABLE public.operator_dpop_proof_states (
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

CREATE UNLOGGED SEQUENCE public.operator_dpop_proof_states_id_seq
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

CREATE UNLOGGED TABLE public.operator_email_ceremony_transactions (
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
-- Name: operator_email_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_email_ceremony_transactions_id_seq
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

CREATE UNLOGGED TABLE public.operator_oauth_callback_states (
    id bigint NOT NULL,
    state_digest character varying NOT NULL,
    provider character varying NOT NULL,
    intent character varying,
    issued_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_oauth_callback_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_oauth_callback_states_id_seq
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

CREATE UNLOGGED TABLE public.operator_oidc_authorization_transactions (
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
    oidc_max_age integer
);


--
-- Name: operator_oidc_authorization_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_oidc_authorization_transactions_id_seq
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

CREATE UNLOGGED TABLE public.operator_oidc_connections (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    staff_id bigint NOT NULL,
    client_id character varying(64) NOT NULL,
    scope character varying,
    last_used_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_oidc_connections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_oidc_connections_id_seq
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
-- Name: operator_passkey_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_passkey_ceremony_transactions (
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
-- Name: operator_passkey_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_passkey_ceremony_transactions_id_seq
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
-- Name: operator_rp_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_rp_sessions (
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
    oidc_access_token_max_expires_at timestamp(6) with time zone
);


--
-- Name: operator_rp_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_rp_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_rp_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_rp_sessions_id_seq OWNED BY public.operator_rp_sessions.id;


--
-- Name: operator_secret_credential_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_secret_credential_ceremony_transactions (
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
-- Name: operator_secret_credential_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_secret_credential_ceremony_transactions_id_seq
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
-- Name: operator_sign_in_flow_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_sign_in_flow_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_sign_in_flow_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_sign_in_flow_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_sign_in_flow_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_sign_in_flow_statuses_id_seq OWNED BY public.operator_sign_in_flow_statuses.id;


--
-- Name: operator_sign_in_flows; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_sign_in_flows (
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
    CONSTRAINT chk_org_sign_in_sequence_tickets_lifetime_order CHECK ((issued_at < expires_at)),
    CONSTRAINT chk_org_sign_in_sequence_tickets_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: operator_sign_in_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_sign_in_flows_id_seq
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

CREATE UNLOGGED TABLE public.operator_sign_out_flow_kinds (
    id bigint NOT NULL
);


--
-- Name: operator_sign_out_flow_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_sign_out_flow_kinds_id_seq
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

CREATE UNLOGGED TABLE public.operator_sign_out_flow_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_sign_out_flow_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_sign_out_flow_statuses_id_seq
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

CREATE UNLOGGED TABLE public.operator_sign_out_flows (
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
    CONSTRAINT chk_operator_sign_out_cycles_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT chk_operator_sign_out_cycles_token_expiry_order CHECK ((access_expires_at <= refresh_expires_at))
);


--
-- Name: operator_sign_out_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_sign_out_flows_id_seq
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

CREATE UNLOGGED TABLE public.operator_sign_up_flow_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_sign_up_flow_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_sign_up_flow_statuses_id_seq
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

CREATE UNLOGGED TABLE public.operator_sign_up_flows (
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
    CONSTRAINT chk_org_sign_up_sequence_tickets_lifetime_order CHECK ((issued_at < expires_at)),
    CONSTRAINT chk_org_sign_up_sequence_tickets_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: operator_sign_up_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_sign_up_flows_id_seq
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

CREATE UNLOGGED TABLE public.operator_step_up_ceremony_transactions (
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
-- Name: operator_step_up_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_step_up_ceremony_transactions_id_seq
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

CREATE UNLOGGED TABLE public.operator_step_up_sessions (
    id bigint NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    method character varying,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    return_to text NOT NULL,
    scope character varying NOT NULL,
    staff_token_id bigint NOT NULL,
    status character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    verified_at timestamp(6) with time zone
);


--
-- Name: operator_step_up_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_step_up_sessions_id_seq
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

CREATE UNLOGGED TABLE public.operator_telephone_ceremony_transactions (
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
-- Name: operator_telephone_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_telephone_ceremony_transactions_id_seq
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

CREATE UNLOGGED TABLE public.operator_token_binding_methods (
    id bigint NOT NULL
);


--
-- Name: operator_token_binding_methods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_token_binding_methods_id_seq
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

CREATE UNLOGGED TABLE public.operator_token_dbsc_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_token_dbsc_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_token_dbsc_statuses_id_seq
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

CREATE UNLOGGED TABLE public.operator_token_kinds (
    id bigint NOT NULL
);


--
-- Name: operator_token_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_token_kinds_id_seq
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

CREATE UNLOGGED TABLE public.operator_token_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_token_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_token_statuses_id_seq
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

CREATE UNLOGGED TABLE public.operator_tokens (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
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
    staff_id bigint NOT NULL,
    staff_token_binding_method_id bigint DEFAULT 0 NOT NULL,
    staff_token_dbsc_status_id bigint DEFAULT 0 NOT NULL,
    staff_token_kind_id bigint DEFAULT 0 NOT NULL,
    staff_token_status_id bigint DEFAULT 1 NOT NULL,
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
    authentication_context character varying,
    authentication_event_at timestamp(6) with time zone,
    CONSTRAINT chk_operator_tokens_authentication_context CHECK (((authentication_context IS NULL) OR ((authentication_context)::text = ANY ((ARRAY['normal'::character varying, 'emergency'::character varying])::text[])))),
    CONSTRAINT chk_operator_tokens_established_authentication_method CHECK (((established_authentication_method IS NULL) OR ((established_authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'entra'::character varying])::text[])))),
    CONSTRAINT chk_staff_tokens_kind_id_positive CHECK ((staff_token_kind_id >= 0)),
    CONSTRAINT chk_staff_tokens_status_id_positive CHECK ((staff_token_status_id >= 0))
);


--
-- Name: operator_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_tokens_id_seq
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

CREATE UNLOGGED TABLE public.operator_verifications (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    last_used_at timestamp(6) with time zone,
    staff_token_id bigint NOT NULL,
    token_digest character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT chk_staff_verifications_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: operator_verifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_verifications_id_seq
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

CREATE UNLOGGED TABLE public.organization_invitations (
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

CREATE UNLOGGED SEQUENCE public.organization_invitations_id_seq
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

CREATE UNLOGGED TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: staff_verifications_staff_token_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.staff_verifications_staff_token_id_seq
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
-- Name: operator_passkey_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkey_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.operator_passkey_ceremony_transactions_id_seq'::regclass);


--
-- Name: operator_rp_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_rp_sessions ALTER COLUMN id SET DEFAULT nextval('public.operator_rp_sessions_id_seq'::regclass);


--
-- Name: operator_secret_credential_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secret_credential_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.operator_secret_credential_ceremony_transactions_id_seq'::regclass);


--
-- Name: operator_sign_in_flow_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_in_flow_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_sign_in_flow_statuses_id_seq'::regclass);


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
-- Name: operator_sign_in_flows chk_operator_sign_in_cycles_status_state; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.operator_sign_in_flows
    ADD CONSTRAINT chk_operator_sign_in_cycles_status_state CHECK (((state)::text =
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
-- Name: operator_sign_in_flows chk_operator_sign_in_cycles_status_step; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.operator_sign_in_flows
    ADD CONSTRAINT chk_operator_sign_in_cycles_status_step CHECK (((step)::text =
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
-- Name: operator_step_up_sessions chk_staff_step_up_sessions_retention_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.operator_step_up_sessions
    ADD CONSTRAINT chk_staff_step_up_sessions_retention_order CHECK ((discard_at <= purge_eligible_at)) NOT VALID;


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
-- Name: operator_passkey_ceremony_transactions operator_passkey_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkey_ceremony_transactions
    ADD CONSTRAINT operator_passkey_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: operator_rp_sessions operator_rp_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_rp_sessions
    ADD CONSTRAINT operator_rp_sessions_pkey PRIMARY KEY (id);


--
-- Name: operator_secret_credential_ceremony_transactions operator_secret_credential_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secret_credential_ceremony_transactions
    ADD CONSTRAINT operator_secret_credential_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: operator_sign_in_flow_statuses operator_sign_in_flow_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_in_flow_statuses
    ADD CONSTRAINT operator_sign_in_flow_statuses_pkey PRIMARY KEY (id);


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
-- Name: idx_active_operator_rp_session_per_rp; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_active_operator_rp_session_per_rp ON public.operator_rp_sessions USING btree (operator_token_id, oidc_client_id) WHERE (revoked_at IS NULL);


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
-- Name: index_operator_rp_sessions_on_oidc_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_rp_sessions_on_oidc_client_id ON public.operator_rp_sessions USING btree (oidc_client_id);


--
-- Name: index_operator_rp_sessions_on_operator_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_rp_sessions_on_operator_token_id ON public.operator_rp_sessions USING btree (operator_token_id);


--
-- Name: index_operator_rp_sessions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_rp_sessions_on_public_id ON public.operator_rp_sessions USING btree (public_id);


--
-- Name: index_operator_rp_sessions_on_refresh_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_rp_sessions_on_refresh_token_digest ON public.operator_rp_sessions USING btree (refresh_token_digest) WHERE (refresh_token_digest IS NOT NULL);


--
-- Name: index_operator_rp_sessions_on_revoked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_rp_sessions_on_revoked_at ON public.operator_rp_sessions USING btree (revoked_at);


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
-- Name: index_operator_sign_in_flows_on_selected_persona_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_in_flows_on_selected_persona_id ON public.operator_sign_in_flows USING btree (selected_persona_id);


--
-- Name: index_operator_sign_in_flows_on_selected_region_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_in_flows_on_selected_region_id ON public.operator_sign_in_flows USING btree (selected_region_id);


--
-- Name: index_operator_sign_in_flows_on_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_in_flows_on_state ON public.operator_sign_in_flows USING btree (state);


--
-- Name: index_operator_sign_in_flows_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_in_flows_on_status_id ON public.operator_sign_in_flows USING btree (status_id);


--
-- Name: index_operator_sign_in_flows_on_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_sign_in_flows_on_token_id ON public.operator_sign_in_flows USING btree (token_id);


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
-- Name: index_operator_step_up_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_step_up_ceremony_transactions_on_result_jti ON public.operator_step_up_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_operator_step_up_ceremony_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_step_up_ceremony_transactions_on_transaction_id ON public.operator_step_up_ceremony_transactions USING btree (transaction_id);


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
-- Name: index_operator_tokens_on_device_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_tokens_on_device_session_id ON public.operator_tokens USING btree (device_session_id);


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
-- Name: operator_step_up_sessions fk_rails_6daa6fb880; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_step_up_sessions
    ADD CONSTRAINT fk_rails_6daa6fb880 FOREIGN KEY (staff_token_id) REFERENCES public.operator_tokens(id) ON DELETE CASCADE;


--
-- Name: operator_sign_in_flows fk_rails_6ed9308623; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_in_flows
    ADD CONSTRAINT fk_rails_6ed9308623 FOREIGN KEY (status_id) REFERENCES public.operator_sign_in_flow_statuses(id);


--
-- Name: operator_sign_out_flows fk_rails_85024a94ea; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_sign_out_flows
    ADD CONSTRAINT fk_rails_85024a94ea FOREIGN KEY (status_id) REFERENCES public.operator_sign_out_flow_statuses(id);


--
-- Name: operator_rp_sessions fk_rails_c004babbad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_rp_sessions
    ADD CONSTRAINT fk_rails_c004babbad FOREIGN KEY (operator_token_id) REFERENCES public.operator_tokens(id) ON DELETE CASCADE;


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
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
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

