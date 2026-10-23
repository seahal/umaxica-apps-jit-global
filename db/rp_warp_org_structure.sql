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
    CONSTRAINT chk_rp_warp_org_callback_states_cell CHECK ((((realm)::text = 'org'::text) AND ((client_id)::text = 'warp-org-jp'::text)))
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
    CONSTRAINT chk_rp_warp_org_event_receipts_cell CHECK ((((realm)::text = 'org'::text) AND ((client_id)::text = 'warp-org-jp'::text)))
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
    CONSTRAINT chk_rp_warp_org_identity_bindings_cell CHECK ((((realm)::text = 'org'::text) AND ((client_id)::text = 'warp-org-jp'::text)))
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
    CONSTRAINT chk_rp_warp_org_op_session_bindings_cell CHECK ((((realm)::text = 'org'::text) AND ((client_id)::text = 'warp-org-jp'::text)))
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
-- Name: rp_refresh_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rp_refresh_attempts (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    session_id bigint NOT NULL,
    input_hmac bytea NOT NULL,
    expected_installed_generation bigint NOT NULL,
    dispatched_at timestamp(6) with time zone,
    uncertain_at timestamp(6) with time zone,
    installed_at timestamp(6) with time zone,
    expires_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_rp_refresh_attempts_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_rp_warp_org_refresh_attempts_shape CHECK ((expected_installed_generation >= 0))
);


--
-- Name: rp_refresh_attempts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rp_refresh_attempts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rp_refresh_attempts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rp_refresh_attempts_id_seq OWNED BY public.rp_refresh_attempts.id;


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
    CONSTRAINT chk_rp_sessions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_rp_warp_org_sessions_shape CHECK ((installed_generation >= 0))
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
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


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
-- Name: rp_refresh_attempts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_refresh_attempts ALTER COLUMN id SET DEFAULT nextval('public.rp_refresh_attempts_id_seq'::regclass);


--
-- Name: rp_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_sessions ALTER COLUMN id SET DEFAULT nextval('public.rp_sessions_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


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
-- Name: rp_refresh_attempts rp_refresh_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_refresh_attempts
    ADD CONSTRAINT rp_refresh_attempts_pkey PRIMARY KEY (id);


--
-- Name: rp_sessions rp_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_sessions
    ADD CONSTRAINT rp_sessions_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: idx_rp_warp_org_callback_states_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rp_warp_org_callback_states_expiry ON public.rp_callback_states USING btree (expires_at);


--
-- Name: idx_rp_warp_org_callback_states_state; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_warp_org_callback_states_state ON public.rp_callback_states USING btree (state_digest);


--
-- Name: idx_rp_warp_org_event_receipts_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_warp_org_event_receipts_identity ON public.rp_event_receipts USING btree (issuer, realm, client_id, event_type, jti_digest);


--
-- Name: idx_rp_warp_org_identity_bindings_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_warp_org_identity_bindings_identity ON public.rp_identity_bindings USING btree (issuer, realm, client_id, subject);


--
-- Name: idx_rp_warp_org_op_session_bindings_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_warp_org_op_session_bindings_identity ON public.rp_op_session_bindings USING btree (issuer, realm, client_id, sid);


--
-- Name: idx_rp_warp_org_principals_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_warp_org_principals_public_id ON public.rp_principals USING btree (public_id);


--
-- Name: idx_rp_warp_org_refresh_attempts_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rp_warp_org_refresh_attempts_expiry ON public.rp_refresh_attempts USING btree (expires_at);


--
-- Name: idx_rp_warp_org_refresh_attempts_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_warp_org_refresh_attempts_public_id ON public.rp_refresh_attempts USING btree (public_id);


--
-- Name: idx_rp_warp_org_sessions_live_binding; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_warp_org_sessions_live_binding ON public.rp_sessions USING btree (op_session_binding_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_rp_warp_org_sessions_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_warp_org_sessions_public_id ON public.rp_sessions USING btree (public_id);


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
-- Name: index_rp_refresh_attempts_on_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rp_refresh_attempts_on_session_id ON public.rp_refresh_attempts USING btree (session_id);


--
-- Name: rp_event_receipts fk_rp_warp_org_event_receipts_op_binding; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_event_receipts
    ADD CONSTRAINT fk_rp_warp_org_event_receipts_op_binding FOREIGN KEY (op_session_binding_id) REFERENCES public.rp_op_session_bindings(id);


--
-- Name: rp_identity_bindings fk_rp_warp_org_identity_bindings_principal; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_identity_bindings
    ADD CONSTRAINT fk_rp_warp_org_identity_bindings_principal FOREIGN KEY (principal_id) REFERENCES public.rp_principals(id);


--
-- Name: rp_op_session_bindings fk_rp_warp_org_op_session_bindings_identity; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_op_session_bindings
    ADD CONSTRAINT fk_rp_warp_org_op_session_bindings_identity FOREIGN KEY (identity_binding_id) REFERENCES public.rp_identity_bindings(id);


--
-- Name: rp_refresh_attempts fk_rp_warp_org_refresh_attempts_session; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_refresh_attempts
    ADD CONSTRAINT fk_rp_warp_org_refresh_attempts_session FOREIGN KEY (session_id) REFERENCES public.rp_sessions(id);


--
-- Name: rp_sessions fk_rp_warp_org_sessions_op_binding; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rp_sessions
    ADD CONSTRAINT fk_rp_warp_org_sessions_op_binding FOREIGN KEY (op_session_binding_id) REFERENCES public.rp_op_session_bindings(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261023130001'),
('20261023130000'),
('20261020130001'),
('20261020130000'),
('20261019111041'),
('20261016220059'),
('20261016220039');

