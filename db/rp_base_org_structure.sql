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
-- Name: rp_base_org_session_selections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rp_base_org_session_selections (
    id bigint NOT NULL,
    rp_session_id bigint NOT NULL,
    account_public_id character varying(21) NOT NULL,
    organization_public_id character varying(21) NOT NULL,
    organization_unit_public_id character varying(21) CONSTRAINT rp_base_org_session_selecti_organization_unit_public_i_not_null NOT NULL,
    selected_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_rp_base_org_selection_public_ids CHECK (((char_length((account_public_id)::text) = 21) AND (char_length((organization_public_id)::text) = 21) AND (char_length((organization_unit_public_id)::text) = 21)))
);


--
-- Name: rp_base_org_session_selections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rp_base_org_session_selections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rp_base_org_session_selections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rp_base_org_session_selections_id_seq OWNED BY public.rp_base_org_session_selections.id;


--
-- Name: rp_callback_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rp_callback_states (
    id bigint NOT NULL,
    state_digest bytea NOT NULL,
    browser_binding_digest bytea NOT NULL,
    nonce_digest bytea NOT NULL,
    pkce_challenge character varying(128) NOT NULL,
    pkce_verifier_ciphertext text NOT NULL,
    issuer character varying(255) NOT NULL,
    realm character varying(3) NOT NULL,
    client_id character varying(64) NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_rp_base_org_callback_states_cell CHECK ((((realm)::text = 'org'::text) AND ((client_id)::text = 'base-org-ww'::text)))
);


--
-- Name: rp_callback_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rp_callback_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rp_callback_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rp_callback_states_id_seq OWNED BY public.rp_callback_states.id;


--
-- Name: rp_event_receipts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rp_event_receipts (
    id bigint NOT NULL,
    op_session_binding_id bigint NOT NULL,
    issuer character varying(255) NOT NULL,
    realm character varying(3) NOT NULL,
    client_id character varying(64) NOT NULL,
    event_type character varying(64) NOT NULL,
    jti_digest bytea NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    committed_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_rp_base_org_event_receipts_cell CHECK ((((realm)::text = 'org'::text) AND ((client_id)::text = 'base-org-ww'::text)))
);


--
-- Name: rp_event_receipts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rp_event_receipts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rp_event_receipts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rp_event_receipts_id_seq OWNED BY public.rp_event_receipts.id;


--
-- Name: rp_identity_bindings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rp_identity_bindings (
    id bigint NOT NULL,
    principal_id bigint NOT NULL,
    issuer character varying(255) NOT NULL,
    realm character varying(3) NOT NULL,
    client_id character varying(64) NOT NULL,
    subject character varying(255) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_rp_base_org_identity_bindings_cell CHECK ((((realm)::text = 'org'::text) AND ((client_id)::text = 'base-org-ww'::text)))
);


--
-- Name: rp_identity_bindings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rp_identity_bindings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rp_identity_bindings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rp_identity_bindings_id_seq OWNED BY public.rp_identity_bindings.id;


--
-- Name: rp_op_session_bindings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rp_op_session_bindings (
    id bigint NOT NULL,
    identity_binding_id bigint,
    issuer character varying(255) NOT NULL,
    realm character varying(3) NOT NULL,
    client_id character varying(64) NOT NULL,
    sid character varying(255) NOT NULL,
    revoked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_rp_base_org_op_session_bindings_cell CHECK ((((realm)::text = 'org'::text) AND ((client_id)::text = 'base-org-ww'::text)))
);


--
-- Name: rp_op_session_bindings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rp_op_session_bindings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rp_op_session_bindings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rp_op_session_bindings_id_seq OWNED BY public.rp_op_session_bindings.id;


--
-- Name: rp_principals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rp_principals (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    disabled_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_rp_principals_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: rp_principals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rp_principals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rp_principals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rp_principals_id_seq OWNED BY public.rp_principals.id;


--
-- Name: rp_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rp_sessions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    op_session_binding_id bigint NOT NULL,
    absolute_expires_at timestamp(6) with time zone NOT NULL,
    revoked_at timestamp(6) with time zone,
    installed_generation bigint DEFAULT 0 NOT NULL,
    current_access_jti_digest character varying(64),
    current_access_expires_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_rp_base_org_sessions_shape CHECK ((installed_generation >= 0)),
    CONSTRAINT chk_rp_sessions_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: rp_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rp_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rp_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rp_sessions_id_seq OWNED BY public.rp_sessions.id;


--
-- Name: rp_step_up_audit_outbox_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rp_step_up_audit_outbox_attempts (
    id bigint NOT NULL,
    outbox_id bigint NOT NULL,
    attempt_number integer NOT NULL,
    attempted_at timestamp(6) with time zone NOT NULL,
    outcome character varying(16) NOT NULL,
    failure_code character varying(64) NOT NULL,
    CONSTRAINT chk_rp_step_up_attempt_failure_codes CHECK (((failure_code)::text = ANY ((ARRAY['none'::character varying, 'chronicle_unavailable'::character varying, 'retention_policy_missing'::character varying, 'event_identity_conflict'::character varying, 'chronicle_record_invalid'::character varying, 'delivery_failed'::character varying])::text[]))),
    CONSTRAINT chk_rp_step_up_audit_attempt_failure CHECK ((length((failure_code)::text) > 0)),
    CONSTRAINT chk_rp_step_up_audit_attempt_number CHECK ((attempt_number > 0)),
    CONSTRAINT chk_rp_step_up_audit_attempt_outcome CHECK (((outcome)::text = ANY ((ARRAY['delivered'::character varying, 'failed'::character varying])::text[]))),
    CONSTRAINT chk_rp_step_up_delivered_failure_none CHECK ((((outcome)::text <> 'delivered'::text) OR ((failure_code)::text = 'none'::text)))
);


--
-- Name: rp_step_up_audit_outbox_attempts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rp_step_up_audit_outbox_attempts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rp_step_up_audit_outbox_attempts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rp_step_up_audit_outbox_attempts_id_seq OWNED BY public.rp_step_up_audit_outbox_attempts.id;


--
-- Name: rp_step_up_audit_outbox_delivery_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rp_step_up_audit_outbox_delivery_states (
    id bigint NOT NULL
);


--
-- Name: rp_step_up_audit_outbox_delivery_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rp_step_up_audit_outbox_delivery_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rp_step_up_audit_outbox_delivery_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rp_step_up_audit_outbox_delivery_states_id_seq OWNED BY public.rp_step_up_audit_outbox_delivery_states.id;


--
-- Name: rp_step_up_audit_outboxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rp_step_up_audit_outboxes (
    id bigint NOT NULL,
    event_uuid uuid NOT NULL,
    event_type character varying(64) NOT NULL,
    realm character varying(3) NOT NULL,
    client_id character varying(64) NOT NULL,
    subject_ref character varying(255) NOT NULL,
    context_ref character varying(21) NOT NULL,
    reason_code character varying(64) NOT NULL,
    payload jsonb NOT NULL,
    occurred_at timestamp(6) with time zone NOT NULL,
    delivery_state_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_rp_step_up_audit_event CHECK (((event_type)::text = ANY ((ARRAY['step_up.requested'::character varying, 'step_up.committed'::character varying, 'step_up.installed'::character varying, 'step_up.cancelled'::character varying, 'step_up.expired'::character varying, 'step_up.failed'::character varying, 'step_up.refused'::character varying, 'step_up.indeterminate'::character varying, 'step_up.attempt_rejected'::character varying])::text[]))),
    CONSTRAINT chk_rp_step_up_audit_payload CHECK (((jsonb_typeof(payload) = 'object'::text) AND ((((event_type)::text = 'step_up.requested'::text) AND (payload ?& ARRAY['rp_state_ref'::text, 'return_target_kind'::text]) AND ((payload - ARRAY['rp_state_ref'::text, 'return_target_kind'::text]) = '{}'::jsonb)) OR (((event_type)::text = 'step_up.committed'::text) AND (payload ?& ARRAY['op_context_ref'::text, 'grant_ref'::text, 'verified_method'::text, 'auth_time'::text]) AND ((payload - ARRAY['op_context_ref'::text, 'grant_ref'::text, 'verified_method'::text, 'auth_time'::text]) = '{}'::jsonb)) OR (((event_type)::text = 'step_up.installed'::text) AND (payload ?& ARRAY['rp_state_ref'::text, 'grant_ref'::text, 'installed_generation'::text]) AND ((payload - ARRAY['rp_state_ref'::text, 'grant_ref'::text, 'installed_generation'::text]) = '{}'::jsonb)) OR (((event_type)::text = ANY ((ARRAY['step_up.cancelled'::character varying, 'step_up.expired'::character varying])::text[])) AND ((payload ? 'op_context_ref'::text) <> (payload ? 'rp_state_ref'::text)) AND ((payload - ARRAY['op_context_ref'::text, 'rp_state_ref'::text]) = '{}'::jsonb)) OR (((event_type)::text = 'step_up.failed'::text) AND (payload ?& ARRAY['op_context_ref'::text, 'failure_code'::text]) AND ((payload - ARRAY['op_context_ref'::text, 'failure_code'::text]) = '{}'::jsonb)) OR (((event_type)::text = ANY ((ARRAY['step_up.refused'::character varying, 'step_up.indeterminate'::character varying])::text[])) AND (payload ?& ARRAY['rp_state_ref'::text, 'failure_code'::text]) AND ((payload - ARRAY['rp_state_ref'::text, 'failure_code'::text]) = '{}'::jsonb)) OR (((event_type)::text = 'step_up.attempt_rejected'::text) AND (payload ?& ARRAY['context_ref'::text, 'rejection_code'::text]) AND ((payload - ARRAY['context_ref'::text, 'rejection_code'::text]) = '{}'::jsonb))))),
    CONSTRAINT chk_rp_step_up_audit_payload_codes CHECK (((((event_type)::text <> 'step_up.failed'::text) OR (COALESCE((payload ->> 'failure_code'::text), ''::text) = ANY (ARRAY['binding_mismatch'::text, 'expectation_mismatch'::text, 'policy_refused'::text, 'unsatisfiable_class'::text]))) AND (((event_type)::text <> ALL ((ARRAY['step_up.refused'::character varying, 'step_up.indeterminate'::character varying])::text[])) OR (COALESCE((payload ->> 'failure_code'::text), ''::text) = ANY (ARRAY['op_error'::text, 'generation_superseded'::text, 'session_invalid'::text, 'exchange_timeout'::text, 'dispatch_deadline_passed'::text]))) AND (((event_type)::text <> 'step_up.attempt_rejected'::text) OR (COALESCE((payload ->> 'rejection_code'::text), ''::text) = ANY (ARRAY['foreign_browser'::text, 'state_mismatch'::text, 'duplicate_callback'::text]))))),
    CONSTRAINT chk_rp_step_up_audit_realm CHECK (((realm)::text = 'ORG'::text)),
    CONSTRAINT chk_rp_step_up_audit_reason CHECK ((length((reason_code)::text) > 0)),
    CONSTRAINT chk_rp_step_up_audit_reason_codes CHECK (((reason_code)::text = ANY ((ARRAY['requested'::character varying, 'dispatch_started'::character varying, 'completed'::character varying, 'user_cancelled'::character varying, 'expired'::character varying, 'binding_mismatch'::character varying, 'expectation_mismatch'::character varying, 'policy_refused'::character varying, 'unsatisfiable_class'::character varying, 'op_error'::character varying, 'generation_superseded'::character varying, 'session_invalid'::character varying, 'exchange_timeout'::character varying, 'dispatch_deadline_passed'::character varying, 'foreign_browser'::character varying, 'state_mismatch'::character varying, 'duplicate_callback'::character varying])::text[])))
);


--
-- Name: rp_step_up_audit_outboxes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rp_step_up_audit_outboxes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rp_step_up_audit_outboxes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rp_step_up_audit_outboxes_id_seq OWNED BY public.rp_step_up_audit_outboxes.id;


--
-- Name: rp_step_up_state_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rp_step_up_state_statuses (
    id bigint NOT NULL
);


--
-- Name: rp_step_up_state_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rp_step_up_state_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rp_step_up_state_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rp_step_up_state_statuses_id_seq OWNED BY public.rp_step_up_state_statuses.id;


--
-- Name: rp_step_up_state_transitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rp_step_up_state_transitions (
    id bigint NOT NULL,
    owner_id bigint NOT NULL,
    from_state_id bigint NOT NULL,
    to_state_id bigint NOT NULL,
    reason_code character varying(64) NOT NULL,
    occurred_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_rp_step_up_transition_reason CHECK (((reason_code)::text = ANY ((ARRAY['requested'::character varying, 'dispatch_started'::character varying, 'completed'::character varying, 'user_cancelled'::character varying, 'expired'::character varying, 'binding_mismatch'::character varying, 'expectation_mismatch'::character varying, 'policy_refused'::character varying, 'unsatisfiable_class'::character varying, 'op_error'::character varying, 'generation_superseded'::character varying, 'session_invalid'::character varying, 'exchange_timeout'::character varying, 'dispatch_deadline_passed'::character varying, 'foreign_browser'::character varying, 'state_mismatch'::character varying, 'duplicate_callback'::character varying])::text[])))
);


--
-- Name: rp_step_up_state_transitions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rp_step_up_state_transitions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rp_step_up_state_transitions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rp_step_up_state_transitions_id_seq OWNED BY public.rp_step_up_state_transitions.id;


--
-- Name: rp_step_up_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rp_step_up_states (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    rp_session_id bigint NOT NULL,
    state_digest character varying(64) NOT NULL,
    browser_binding_digest character varying(64) NOT NULL,
    nonce_digest character varying(64) NOT NULL,
    pkce_challenge character varying(128) NOT NULL,
    pkce_verifier_ciphertext text NOT NULL,
    issuer character varying(255) NOT NULL,
    realm character varying(3) NOT NULL,
    client_id character varying(64) NOT NULL,
    return_target character varying(512) NOT NULL,
    initiating_generation bigint NOT NULL,
    state_id bigint NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_rp_step_up_state_generation CHECK ((initiating_generation >= 0)),
    CONSTRAINT chk_rp_step_up_states_realm CHECK (((realm)::text = 'ORG'::text))
);


--
-- Name: rp_step_up_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rp_step_up_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rp_step_up_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rp_step_up_states_id_seq OWNED BY public.rp_step_up_states.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: rp_base_org_session_selections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_base_org_session_selections ALTER COLUMN id SET DEFAULT nextval('public.rp_base_org_session_selections_id_seq'::regclass);


--
-- Name: rp_callback_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_callback_states ALTER COLUMN id SET DEFAULT nextval('public.rp_callback_states_id_seq'::regclass);


--
-- Name: rp_event_receipts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_event_receipts ALTER COLUMN id SET DEFAULT nextval('public.rp_event_receipts_id_seq'::regclass);


--
-- Name: rp_identity_bindings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_identity_bindings ALTER COLUMN id SET DEFAULT nextval('public.rp_identity_bindings_id_seq'::regclass);


--
-- Name: rp_op_session_bindings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_op_session_bindings ALTER COLUMN id SET DEFAULT nextval('public.rp_op_session_bindings_id_seq'::regclass);


--
-- Name: rp_principals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_principals ALTER COLUMN id SET DEFAULT nextval('public.rp_principals_id_seq'::regclass);


--
-- Name: rp_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_sessions ALTER COLUMN id SET DEFAULT nextval('public.rp_sessions_id_seq'::regclass);


--
-- Name: rp_step_up_audit_outbox_attempts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_step_up_audit_outbox_attempts ALTER COLUMN id SET DEFAULT nextval('public.rp_step_up_audit_outbox_attempts_id_seq'::regclass);


--
-- Name: rp_step_up_audit_outbox_delivery_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_step_up_audit_outbox_delivery_states ALTER COLUMN id SET DEFAULT nextval('public.rp_step_up_audit_outbox_delivery_states_id_seq'::regclass);


--
-- Name: rp_step_up_audit_outboxes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_step_up_audit_outboxes ALTER COLUMN id SET DEFAULT nextval('public.rp_step_up_audit_outboxes_id_seq'::regclass);


--
-- Name: rp_step_up_state_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_step_up_state_statuses ALTER COLUMN id SET DEFAULT nextval('public.rp_step_up_state_statuses_id_seq'::regclass);


--
-- Name: rp_step_up_state_transitions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_step_up_state_transitions ALTER COLUMN id SET DEFAULT nextval('public.rp_step_up_state_transitions_id_seq'::regclass);


--
-- Name: rp_step_up_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_step_up_states ALTER COLUMN id SET DEFAULT nextval('public.rp_step_up_states_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: rp_base_org_session_selections rp_base_org_session_selections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_base_org_session_selections
    ADD CONSTRAINT rp_base_org_session_selections_pkey PRIMARY KEY (id);


--
-- Name: rp_callback_states rp_callback_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_callback_states
    ADD CONSTRAINT rp_callback_states_pkey PRIMARY KEY (id);


--
-- Name: rp_event_receipts rp_event_receipts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_event_receipts
    ADD CONSTRAINT rp_event_receipts_pkey PRIMARY KEY (id);


--
-- Name: rp_identity_bindings rp_identity_bindings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_identity_bindings
    ADD CONSTRAINT rp_identity_bindings_pkey PRIMARY KEY (id);


--
-- Name: rp_op_session_bindings rp_op_session_bindings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_op_session_bindings
    ADD CONSTRAINT rp_op_session_bindings_pkey PRIMARY KEY (id);


--
-- Name: rp_principals rp_principals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_principals
    ADD CONSTRAINT rp_principals_pkey PRIMARY KEY (id);


--
-- Name: rp_sessions rp_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_sessions
    ADD CONSTRAINT rp_sessions_pkey PRIMARY KEY (id);


--
-- Name: rp_step_up_audit_outbox_attempts rp_step_up_audit_outbox_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_step_up_audit_outbox_attempts
    ADD CONSTRAINT rp_step_up_audit_outbox_attempts_pkey PRIMARY KEY (id);


--
-- Name: rp_step_up_audit_outbox_delivery_states rp_step_up_audit_outbox_delivery_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_step_up_audit_outbox_delivery_states
    ADD CONSTRAINT rp_step_up_audit_outbox_delivery_states_pkey PRIMARY KEY (id);


--
-- Name: rp_step_up_audit_outboxes rp_step_up_audit_outboxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_step_up_audit_outboxes
    ADD CONSTRAINT rp_step_up_audit_outboxes_pkey PRIMARY KEY (id);


--
-- Name: rp_step_up_state_statuses rp_step_up_state_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_step_up_state_statuses
    ADD CONSTRAINT rp_step_up_state_statuses_pkey PRIMARY KEY (id);


--
-- Name: rp_step_up_state_transitions rp_step_up_state_transitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_step_up_state_transitions
    ADD CONSTRAINT rp_step_up_state_transitions_pkey PRIMARY KEY (id);


--
-- Name: rp_step_up_states rp_step_up_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_step_up_states
    ADD CONSTRAINT rp_step_up_states_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: idx_rp_base_org_callback_states_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rp_base_org_callback_states_expiry ON public.rp_callback_states USING btree (expires_at);


--
-- Name: idx_rp_base_org_callback_states_state; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_base_org_callback_states_state ON public.rp_callback_states USING btree (state_digest);


--
-- Name: idx_rp_base_org_event_receipts_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_base_org_event_receipts_identity ON public.rp_event_receipts USING btree (issuer, realm, client_id, event_type, jti_digest);


--
-- Name: idx_rp_base_org_identity_bindings_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_base_org_identity_bindings_identity ON public.rp_identity_bindings USING btree (issuer, realm, client_id, subject);


--
-- Name: idx_rp_base_org_op_session_bindings_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_base_org_op_session_bindings_identity ON public.rp_op_session_bindings USING btree (issuer, realm, client_id, sid);


--
-- Name: idx_rp_base_org_principals_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_base_org_principals_public_id ON public.rp_principals USING btree (public_id);


--
-- Name: idx_rp_base_org_selection_session; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_base_org_selection_session ON public.rp_base_org_session_selections USING btree (rp_session_id);


--
-- Name: idx_rp_base_org_sessions_live_binding; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_base_org_sessions_live_binding ON public.rp_sessions USING btree (op_session_binding_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_rp_base_org_sessions_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_base_org_sessions_public_id ON public.rp_sessions USING btree (public_id);


--
-- Name: idx_rp_step_up_audit_attempts_delivered; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_step_up_audit_attempts_delivered ON public.rp_step_up_audit_outbox_attempts USING btree (outbox_id) WHERE ((outcome)::text = 'delivered'::text);


--
-- Name: idx_rp_step_up_audit_attempts_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_step_up_audit_attempts_number ON public.rp_step_up_audit_outbox_attempts USING btree (outbox_id, attempt_number);


--
-- Name: idx_rp_step_up_audit_outboxes_delivery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rp_step_up_audit_outboxes_delivery ON public.rp_step_up_audit_outboxes USING btree (delivery_state_id);


--
-- Name: idx_rp_step_up_audit_outboxes_event_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_step_up_audit_outboxes_event_uuid ON public.rp_step_up_audit_outboxes USING btree (event_uuid);


--
-- Name: idx_rp_step_up_audit_outboxes_rejected; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_step_up_audit_outboxes_rejected ON public.rp_step_up_audit_outboxes USING btree (realm, client_id, context_ref, reason_code) WHERE ((event_type)::text = 'step_up.attempt_rejected'::text);


--
-- Name: idx_rp_step_up_state_transitions_owner_to; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_step_up_state_transitions_owner_to ON public.rp_step_up_state_transitions USING btree (owner_id, to_state_id);


--
-- Name: idx_rp_step_up_states_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rp_step_up_states_expires_at ON public.rp_step_up_states USING btree (expires_at);


--
-- Name: idx_rp_step_up_states_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_step_up_states_public_id ON public.rp_step_up_states USING btree (public_id);


--
-- Name: idx_rp_step_up_states_state_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_step_up_states_state_digest ON public.rp_step_up_states USING btree (state_digest);


--
-- Name: index_rp_event_receipts_on_op_session_binding_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rp_event_receipts_on_op_session_binding_id ON public.rp_event_receipts USING btree (op_session_binding_id);


--
-- Name: index_rp_identity_bindings_on_principal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rp_identity_bindings_on_principal_id ON public.rp_identity_bindings USING btree (principal_id);


--
-- Name: index_rp_op_session_bindings_on_identity_binding_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rp_op_session_bindings_on_identity_binding_id ON public.rp_op_session_bindings USING btree (identity_binding_id);


--
-- Name: index_rp_step_up_audit_outbox_attempts_on_outbox_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rp_step_up_audit_outbox_attempts_on_outbox_id ON public.rp_step_up_audit_outbox_attempts USING btree (outbox_id);


--
-- Name: index_rp_step_up_audit_outboxes_on_delivery_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rp_step_up_audit_outboxes_on_delivery_state_id ON public.rp_step_up_audit_outboxes USING btree (delivery_state_id);


--
-- Name: index_rp_step_up_state_transitions_on_from_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rp_step_up_state_transitions_on_from_state_id ON public.rp_step_up_state_transitions USING btree (from_state_id);


--
-- Name: index_rp_step_up_state_transitions_on_to_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rp_step_up_state_transitions_on_to_state_id ON public.rp_step_up_state_transitions USING btree (to_state_id);


--
-- Name: index_rp_step_up_states_on_rp_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rp_step_up_states_on_rp_session_id ON public.rp_step_up_states USING btree (rp_session_id);


--
-- Name: index_rp_step_up_states_on_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rp_step_up_states_on_state_id ON public.rp_step_up_states USING btree (state_id);


--
-- Name: rp_step_up_states fk_rails_35e30829e0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_step_up_states
    ADD CONSTRAINT fk_rails_35e30829e0 FOREIGN KEY (rp_session_id) REFERENCES public.rp_sessions(id);


--
-- Name: rp_step_up_state_transitions fk_rails_42bc1ac3a0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_step_up_state_transitions
    ADD CONSTRAINT fk_rails_42bc1ac3a0 FOREIGN KEY (owner_id) REFERENCES public.rp_step_up_states(id) ON DELETE CASCADE;


--
-- Name: rp_step_up_audit_outboxes fk_rails_544d18ae9b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_step_up_audit_outboxes
    ADD CONSTRAINT fk_rails_544d18ae9b FOREIGN KEY (delivery_state_id) REFERENCES public.rp_step_up_audit_outbox_delivery_states(id);


--
-- Name: rp_step_up_state_transitions fk_rails_80016e61ee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_step_up_state_transitions
    ADD CONSTRAINT fk_rails_80016e61ee FOREIGN KEY (from_state_id) REFERENCES public.rp_step_up_state_statuses(id);


--
-- Name: rp_step_up_states fk_rails_8cf2fe3468; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_step_up_states
    ADD CONSTRAINT fk_rails_8cf2fe3468 FOREIGN KEY (state_id) REFERENCES public.rp_step_up_state_statuses(id);


--
-- Name: rp_step_up_audit_outbox_attempts fk_rails_9735bc9c9b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_step_up_audit_outbox_attempts
    ADD CONSTRAINT fk_rails_9735bc9c9b FOREIGN KEY (outbox_id) REFERENCES public.rp_step_up_audit_outboxes(id) ON DELETE CASCADE;


--
-- Name: rp_step_up_state_transitions fk_rails_bcea73ea8c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_step_up_state_transitions
    ADD CONSTRAINT fk_rails_bcea73ea8c FOREIGN KEY (to_state_id) REFERENCES public.rp_step_up_state_statuses(id);


--
-- Name: rp_event_receipts fk_rp_base_org_event_receipts_op_binding; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_event_receipts
    ADD CONSTRAINT fk_rp_base_org_event_receipts_op_binding FOREIGN KEY (op_session_binding_id) REFERENCES public.rp_op_session_bindings(id);


--
-- Name: rp_identity_bindings fk_rp_base_org_identity_bindings_principal; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_identity_bindings
    ADD CONSTRAINT fk_rp_base_org_identity_bindings_principal FOREIGN KEY (principal_id) REFERENCES public.rp_principals(id);


--
-- Name: rp_op_session_bindings fk_rp_base_org_op_session_bindings_identity; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_op_session_bindings
    ADD CONSTRAINT fk_rp_base_org_op_session_bindings_identity FOREIGN KEY (identity_binding_id) REFERENCES public.rp_identity_bindings(id);


--
-- Name: rp_base_org_session_selections fk_rp_base_org_selection_session; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_base_org_session_selections
    ADD CONSTRAINT fk_rp_base_org_selection_session FOREIGN KEY (rp_session_id) REFERENCES public.rp_sessions(id) ON DELETE CASCADE;


--
-- Name: rp_sessions fk_rp_base_org_sessions_op_binding; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_sessions
    ADD CONSTRAINT fk_rp_base_org_sessions_op_binding FOREIGN KEY (op_session_binding_id) REFERENCES public.rp_op_session_bindings(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261106064619'),
('20261106064615'),
('20261106064611'),
('20261106064607'),
('20261106064603'),
('20261106064341'),
('20261106005748'),
('20261106005646'),
('20261103183213'),
('20261103183212'),
('20261103112949'),
('20261103112945'),
('20261025100000'),
('20261023130001'),
('20261023130000'),
('20261020130001'),
('20261020130000'),
('20261019111033'),
('20261016220057'),
('20261016220037');

