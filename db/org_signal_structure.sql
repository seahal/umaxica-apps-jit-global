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
-- Name: operator_notification_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_notification_records (
    id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    staff_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_notification_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_notification_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_notification_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_notification_records_id_seq OWNED BY public.operator_notification_records.id;


--
-- Name: operator_notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_notifications (
    id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    staff_notification_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_notifications_id_seq OWNED BY public.operator_notifications.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: operator_notification_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_notification_records ALTER COLUMN id SET DEFAULT nextval('public.operator_notification_records_id_seq'::regclass);


--
-- Name: operator_notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_notifications ALTER COLUMN id SET DEFAULT nextval('public.operator_notifications_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: operator_notification_records operator_notification_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_notification_records
    ADD CONSTRAINT operator_notification_records_pkey PRIMARY KEY (id);


--
-- Name: operator_notifications operator_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_notifications
    ADD CONSTRAINT operator_notifications_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: index_operator_notification_records_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_notification_records_on_public_id ON public.operator_notification_records USING btree (public_id);


--
-- Name: index_operator_notification_records_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_notification_records_on_staff_id ON public.operator_notification_records USING btree (staff_id);


--
-- Name: index_operator_notifications_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_notifications_on_public_id ON public.operator_notifications USING btree (public_id);


--
-- Name: index_operator_notifications_on_staff_notification_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_notifications_on_staff_notification_id ON public.operator_notifications USING btree (staff_notification_id);


--
-- Name: operator_notifications fk_rails_18cd968454; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_notifications
    ADD CONSTRAINT fk_rails_18cd968454 FOREIGN KEY (staff_notification_id) REFERENCES public.operator_notification_records(id) ON DELETE CASCADE NOT VALID;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260612000001'),
('20260520143009'),
('20260507000000');

