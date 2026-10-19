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
-- Name: check_user_identity_emails_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_user_identity_emails_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE emails_count integer; BEGIN IF NEW.user_id IS NULL THEN RETURN NEW; END IF; SELECT COUNT(*) INTO emails_count FROM user_identity_emails WHERE user_id = NEW.user_id; IF emails_count >= 4 THEN RAISE EXCEPTION 'user_identity_emails limit (4) exceeded for user %', NEW.user_id USING ERRCODE = '23514'; END IF; RETURN NEW; END; $$;


--
-- Name: check_user_identity_passkeys_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_user_identity_passkeys_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE passkeys_count integer; BEGIN SELECT COUNT(*) INTO passkeys_count FROM user_identity_passkeys WHERE user_id = NEW.user_id; IF passkeys_count >= 4 THEN RAISE EXCEPTION 'user_identity_passkeys limit (4) exceeded for user %', NEW.user_id USING ERRCODE = '23514'; END IF; RETURN NEW; END; $$;


--
-- Name: check_user_identity_secrets_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_user_identity_secrets_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE secrets_count integer; BEGIN SELECT COUNT(*) INTO secrets_count FROM user_identity_secrets WHERE user_id = NEW.user_id; IF secrets_count >= 10 THEN RAISE EXCEPTION 'user_identity_secrets limit (10) exceeded for user %', NEW.user_id USING ERRCODE = '23514'; END IF; RETURN NEW; END; $$;


--
-- Name: check_user_identity_telephones_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_user_identity_telephones_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE telephones_count integer; BEGIN IF NEW.user_id IS NULL THEN RETURN NEW; END IF; SELECT COUNT(*) INTO telephones_count FROM user_identity_telephones WHERE user_id = NEW.user_id; IF telephones_count >= 4 THEN RAISE EXCEPTION 'user_identity_telephones limit (4) exceeded for user %', NEW.user_id USING ERRCODE = '23514'; END IF; RETURN NEW; END; $$;


--
-- Name: check_user_identity_totp_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_user_identity_totp_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE totp_count integer; BEGIN SELECT COUNT(*) INTO totp_count FROM user_identity_one_time_passwords WHERE user_id = NEW.user_id; IF totp_count >= 2 THEN RAISE EXCEPTION 'user_identity_one_time_passwords limit (2) exceeded for user %', NEW.user_id USING ERRCODE = '23514'; END IF; RETURN NEW; END; $$;


--
-- Name: enforce_client_emails_binding_facts(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_client_emails_binding_facts() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $$ BEGIN IF current_user = 'umaxica_app_email_hmac_definer_5d2e3f6bb4ae' AND (to_jsonb(NEW) - 'address_digest') IS DISTINCT FROM (to_jsonb(OLD) - 'address_digest') THEN RAISE EXCEPTION 'identifier rotation may change only its digest'; END IF; IF OLD.binding_finalized_at IS NOT NULL AND (NEW.user_id IS DISTINCT FROM OLD.user_id OR (NEW.address_digest IS DISTINCT FROM OLD.address_digest AND current_user <> 'umaxica_app_email_hmac_definer_5d2e3f6bb4ae')) THEN RAISE EXCEPTION 'effective contact binding owner and digest are immutable'; END IF; IF OLD.binding_finalized_at IS NOT NULL AND NEW.binding_finalized_at IS DISTINCT FROM OLD.binding_finalized_at THEN RAISE EXCEPTION 'effective contact binding finalization is immutable'; END IF; IF OLD.binding_released_at IS NOT NULL AND NEW.binding_released_at IS DISTINCT FROM OLD.binding_released_at THEN RAISE EXCEPTION 'released contact binding cannot be reactivated or rewritten'; END IF; RETURN NEW; END; $$;


--
-- Name: enforce_client_external_identity_binding_facts(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_client_external_identity_binding_facts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF NEW.client_id IS DISTINCT FROM OLD.client_id OR NEW.provider IS DISTINCT FROM OLD.provider OR NEW.issuer IS DISTINCT FROM OLD.issuer OR NEW.subject IS DISTINCT FROM OLD.subject THEN RAISE EXCEPTION 'external identity binding owner and subject are immutable'; END IF; IF OLD.released_at IS NOT NULL AND NEW.released_at IS DISTINCT FROM OLD.released_at THEN RAISE EXCEPTION 'released external identity cannot be reactivated or rewritten'; END IF; RETURN NEW; END; $$;


--
-- Name: enforce_client_rotation_audit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_client_rotation_audit() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $$ BEGIN IF TG_OP = 'UPDATE' THEN RAISE EXCEPTION 'identifier rotation audit is append-only'; END IF; IF NOT ((current_user = 'umaxica_app_email_hmac_definer_5d2e3f6bb4ae' AND NEW.channel = 'email') OR (current_user = 'umaxica_app_telephone_hmac_definer_5d2e3f6bb4ae' AND NEW.channel = 'telephone')) THEN RAISE EXCEPTION 'identifier rotation audit requires its domain function'; END IF; RETURN NEW; END; $$;


--
-- Name: enforce_client_telephones_binding_facts(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_client_telephones_binding_facts() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $$ BEGIN IF current_user = 'umaxica_app_telephone_hmac_definer_5d2e3f6bb4ae' AND (to_jsonb(NEW) - 'number_digest') IS DISTINCT FROM (to_jsonb(OLD) - 'number_digest') THEN RAISE EXCEPTION 'identifier rotation may change only its digest'; END IF; IF OLD.binding_finalized_at IS NOT NULL AND (NEW.user_id IS DISTINCT FROM OLD.user_id OR (NEW.number_digest IS DISTINCT FROM OLD.number_digest AND current_user <> 'umaxica_app_telephone_hmac_definer_5d2e3f6bb4ae')) THEN RAISE EXCEPTION 'effective contact binding owner and digest are immutable'; END IF; IF OLD.binding_finalized_at IS NOT NULL AND NEW.binding_finalized_at IS DISTINCT FROM OLD.binding_finalized_at THEN RAISE EXCEPTION 'effective contact binding finalization is immutable'; END IF; IF OLD.binding_released_at IS NOT NULL AND NEW.binding_released_at IS DISTINCT FROM OLD.binding_released_at THEN RAISE EXCEPTION 'released contact binding cannot be reactivated or rewritten'; END IF; RETURN NEW; END; $$;


--
-- Name: enforcement_protect_client_emails_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforcement_protect_client_emails_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF EXISTS ( SELECT 1 FROM app_enforcement_authentication_method_effects AS effect JOIN clients ON clients.public_id = effect.principal_public_id WHERE clients.id = OLD.user_id AND effect.authentication_method = 'email' AND effect.effect = 'permanently_frozen' AND effect.ended_at IS NULL ) THEN RAISE EXCEPTION 'client_emails row % is protected by a permanently_frozen Authentication Method Effect', OLD.id USING ERRCODE = 'P0001'; END IF; RETURN OLD; END; $$;


--
-- Name: enforcement_protect_clients_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforcement_protect_clients_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF EXISTS ( SELECT 1 FROM app_enforcement_principal_effects AS effect JOIN app_enforcement_cases AS enforcement_case ON enforcement_case.id = effect.app_enforcement_case_id WHERE effect.principal_public_id = OLD.public_id AND effect.principal_hard_delete_blocked = TRUE AND effect.ended_at IS NULL AND enforcement_case.state = 'active' AND enforcement_case.ended_at IS NULL AND enforcement_case.effective_at <= clock_timestamp() AND (enforcement_case.expires_at IS NULL OR enforcement_case.expires_at > clock_timestamp()) ) THEN RAISE EXCEPTION 'clients row % is protected by an in-force principal_hard_delete_blocked Principal Effect', OLD.id USING ERRCODE = 'P0001'; END IF; RETURN OLD; END; $$;


--
-- Name: rotate_client_emails_hmac(bigint, text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rotate_client_emails_hmac(p_record_id bigint, p_new_digest text, p_expected_digest text, p_operation_ref uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$ DECLARE prior_digest text; BEGIN IF current_user <> 'umaxica_app_email_hmac_definer_5d2e3f6bb4ae' THEN RAISE EXCEPTION 'identifier rotation function owner is invalid'; END IF; IF p_record_id IS NULL OR p_record_id <= 0 OR p_operation_ref IS NULL OR p_new_digest IS NULL OR p_new_digest !~ '^[0-9a-f]{64}$' THEN RAISE EXCEPTION 'invalid identifier rotation arguments'; END IF; SELECT address_digest INTO prior_digest FROM public.client_emails WHERE id = p_record_id FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION 'identifier rotation source is unavailable'; END IF; IF prior_digest IS DISTINCT FROM p_expected_digest THEN RAISE EXCEPTION 'identifier rotation source changed' USING ERRCODE = '40001'; END IF; IF prior_digest IS NOT DISTINCT FROM p_new_digest THEN RETURN FALSE; END IF; UPDATE public.client_emails SET address_digest = p_new_digest WHERE id = p_record_id; INSERT INTO public.client_identifier_rotation_audits(operation_ref, channel, record_id, actor_role, occurred_at) VALUES (p_operation_ref, 'email', p_record_id, session_user, clock_timestamp()); RETURN TRUE; END; $_$;


--
-- Name: rotate_client_telephones_hmac(bigint, text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rotate_client_telephones_hmac(p_record_id bigint, p_new_digest text, p_expected_digest text, p_operation_ref uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$ DECLARE prior_digest text; BEGIN IF current_user <> 'umaxica_app_telephone_hmac_definer_5d2e3f6bb4ae' THEN RAISE EXCEPTION 'identifier rotation function owner is invalid'; END IF; IF p_record_id IS NULL OR p_record_id <= 0 OR p_operation_ref IS NULL OR p_new_digest IS NULL OR p_new_digest !~ '^[0-9a-f]{64}$' THEN RAISE EXCEPTION 'invalid identifier rotation arguments'; END IF; SELECT number_digest INTO prior_digest FROM public.client_telephones WHERE id = p_record_id FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION 'identifier rotation source is unavailable'; END IF; IF prior_digest IS DISTINCT FROM p_expected_digest THEN RAISE EXCEPTION 'identifier rotation source changed' USING ERRCODE = '40001'; END IF; IF prior_digest IS NOT DISTINCT FROM p_new_digest THEN RETURN FALSE; END IF; UPDATE public.client_telephones SET number_digest = p_new_digest WHERE id = p_record_id; INSERT INTO public.client_identifier_rotation_audits(operation_ref, channel, record_id, actor_role, occurred_at) VALUES (p_operation_ref, 'telephone', p_record_id, session_user, clock_timestamp()); RETURN TRUE; END; $_$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounts (
    id bigint NOT NULL,
    accountable_id bigint NOT NULL,
    accountable_type character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    email character varying NOT NULL,
    password_digest character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.accounts_id_seq OWNED BY public.accounts.id;


--
-- Name: app_enforcement_appeals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_enforcement_appeals (
    id bigint NOT NULL,
    app_enforcement_case_id bigint NOT NULL,
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
    CONSTRAINT app_enforcement_appeals_public_id_max_length CHECK ((char_length((public_id)::text) <= 25)),
    CONSTRAINT chk_app_enforcement_appeals_state CHECK (((state)::text = ANY ((ARRAY['submitted'::character varying, 'under_review'::character varying, 'approved'::character varying, 'rejected'::character varying, 'redacted'::character varying])::text[])))
);


--
-- Name: app_enforcement_appeals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_enforcement_appeals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_enforcement_appeals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_enforcement_appeals_id_seq OWNED BY public.app_enforcement_appeals.id;


--
-- Name: app_enforcement_authentication_method_effects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_enforcement_authentication_method_effects (
    id bigint NOT NULL,
    app_enforcement_case_id bigint CONSTRAINT app_enforcement_authentication_app_enforcement_case_id_not_null NOT NULL,
    principal_public_id character varying CONSTRAINT app_enforcement_authentication_met_principal_public_id_not_null NOT NULL,
    authentication_method character varying CONSTRAINT app_enforcement_authentication_m_authentication_method_not_null NOT NULL,
    effect character varying NOT NULL,
    effective_at timestamp(6) with time zone CONSTRAINT app_enforcement_authentication_method_eff_effective_at_not_null NOT NULL,
    expires_at timestamp(6) with time zone,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone CONSTRAINT app_enforcement_authentication_method_effec_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT app_enforcement_authentication_method_effec_updated_at_not_null NOT NULL,
    CONSTRAINT chk_app_enforcement_method_effects_effect CHECK (((effect)::text = ANY ((ARRAY['mutation_locked'::character varying, 'unusable'::character varying, 'permanently_frozen'::character varying])::text[]))),
    CONSTRAINT chk_app_enforcement_method_effects_method CHECK (((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'totp'::character varying, 'google'::character varying, 'apple'::character varying])::text[]))),
    CONSTRAINT chk_app_enforcement_method_effects_no_social_freeze CHECK ((((effect)::text <> 'permanently_frozen'::text) OR ((authentication_method)::text <> ALL ((ARRAY['google'::character varying, 'apple'::character varying])::text[]))))
);


--
-- Name: app_enforcement_authentication_method_effects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_enforcement_authentication_method_effects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_enforcement_authentication_method_effects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_enforcement_authentication_method_effects_id_seq OWNED BY public.app_enforcement_authentication_method_effects.id;


--
-- Name: app_enforcement_cases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_enforcement_cases (
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
    CONSTRAINT chk_app_enforcement_cases_approval_separation CHECK (((approved_by_operator_public_id IS NULL) OR ((approved_by_operator_public_id)::text <> (applied_by_operator_public_id)::text))),
    CONSTRAINT chk_app_enforcement_cases_break_glass_approver CHECK (((break_glass = false) OR (break_glass_approved_by_operator_public_id IS NOT NULL))),
    CONSTRAINT chk_app_enforcement_cases_cooldown_duration CHECK ((((kind)::text <> 'cooldown'::text) OR (((duration_mode)::text = 'timed'::text) AND (expires_at IS NOT NULL) AND (expires_at <= (effective_at + '30 days'::interval))))),
    CONSTRAINT chk_app_enforcement_cases_duration_mode CHECK (((duration_mode)::text = ANY ((ARRAY['timed'::character varying, 'indefinite'::character varying, 'permanent'::character varying])::text[]))),
    CONSTRAINT chk_app_enforcement_cases_end_reason CHECK (((end_reason IS NULL) OR ((end_reason)::text = ANY ((ARRAY['expired'::character varying, 'revoked'::character varying, 'superseded'::character varying, 'corrected'::character varying, 'appeal_approved'::character varying, 'break_glass_released'::character varying, 'verification_completed'::character varying])::text[])))),
    CONSTRAINT chk_app_enforcement_cases_hidden CHECK ((((visibility)::text <> 'hidden'::text) OR ((kind)::text = 'permanent_ban'::text))),
    CONSTRAINT chk_app_enforcement_cases_indefinite_freeze_review CHECK ((((kind)::text <> 'temporary_freeze'::text) OR ((duration_mode)::text <> 'indefinite'::text) OR ((review_due_at IS NOT NULL) AND ((release_mode)::text = 'operator'::text)))),
    CONSTRAINT chk_app_enforcement_cases_kind CHECK (((kind)::text = ANY ((ARRAY['security_lock'::character varying, 'cooldown'::character varying, 'temporary_freeze'::character varying, 'permanent_ban'::character varying, 'method_protection'::character varying])::text[]))),
    CONSTRAINT chk_app_enforcement_cases_no_self_action CHECK (((principal_public_id)::text <> (applied_by_operator_public_id)::text)),
    CONSTRAINT chk_app_enforcement_cases_permanent_ban_duration CHECK ((((kind)::text <> 'permanent_ban'::text) OR (((duration_mode)::text = 'permanent'::text) AND (expires_at IS NULL)))),
    CONSTRAINT chk_app_enforcement_cases_release_mode CHECK (((release_mode)::text = ANY ((ARRAY['automatic'::character varying, 'operator'::character varying, 'verification_required'::character varying, 'break_glass_only'::character varying])::text[]))),
    CONSTRAINT chk_app_enforcement_cases_security_lock_release CHECK ((((kind)::text <> 'security_lock'::text) OR ((release_mode)::text = 'verification_required'::text))),
    CONSTRAINT chk_app_enforcement_cases_state CHECK (((state)::text = ANY ((ARRAY['draft'::character varying, 'pending_approval'::character varying, 'active'::character varying, 'ended'::character varying, 'failed'::character varying])::text[]))),
    CONSTRAINT chk_app_enforcement_cases_temp_freeze_duration_mode CHECK ((((kind)::text <> 'temporary_freeze'::text) OR ((duration_mode)::text = ANY ((ARRAY['timed'::character varying, 'indefinite'::character varying])::text[])))),
    CONSTRAINT chk_app_enforcement_cases_visibility CHECK (((visibility)::text = ANY ((ARRAY['visible'::character varying, 'hidden'::character varying])::text[])))
);


--
-- Name: app_enforcement_cases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_enforcement_cases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_enforcement_cases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_enforcement_cases_id_seq OWNED BY public.app_enforcement_cases.id;


--
-- Name: app_enforcement_identifier_effects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_enforcement_identifier_effects (
    id bigint NOT NULL,
    app_enforcement_case_id bigint CONSTRAINT app_enforcement_identifier_eff_app_enforcement_case_id_not_null NOT NULL,
    identifier_kind character varying NOT NULL,
    lookup_digest character varying NOT NULL,
    key_version integer NOT NULL,
    digest_version integer NOT NULL,
    normalization_version integer CONSTRAINT app_enforcement_identifier_effec_normalization_version_not_null NOT NULL,
    display_value text,
    registration_blocked boolean DEFAULT false CONSTRAINT app_enforcement_identifier_effect_registration_blocked_not_null NOT NULL,
    attachment_blocked boolean DEFAULT false NOT NULL,
    recovery_blocked boolean DEFAULT false NOT NULL,
    effective_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_app_enforcement_identifier_effects_kind CHECK (((identifier_kind)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'google_subject'::character varying, 'apple_subject'::character varying, 'identity_id'::character varying])::text[])))
);


--
-- Name: app_enforcement_identifier_effects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_enforcement_identifier_effects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_enforcement_identifier_effects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_enforcement_identifier_effects_id_seq OWNED BY public.app_enforcement_identifier_effects.id;


--
-- Name: app_enforcement_principal_effects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_enforcement_principal_effects (
    id bigint NOT NULL,
    app_enforcement_case_id bigint CONSTRAINT app_enforcement_principal_effe_app_enforcement_case_id_not_null NOT NULL,
    principal_public_id character varying NOT NULL,
    access_blocking boolean DEFAULT false NOT NULL,
    recovery_blocked boolean DEFAULT false NOT NULL,
    reactivation_blocked boolean DEFAULT false NOT NULL,
    withdrawal_purge_blocked boolean DEFAULT false CONSTRAINT app_enforcement_principal_eff_withdrawal_purge_blocked_not_null NOT NULL,
    principal_hard_delete_blocked boolean DEFAULT false CONSTRAINT app_enforcement_principal_e_principal_hard_delete_bloc_not_null NOT NULL,
    profile_effect character varying,
    effective_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: app_enforcement_principal_effects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_enforcement_principal_effects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_enforcement_principal_effects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_enforcement_principal_effects_id_seq OWNED BY public.app_enforcement_principal_effects.id;


--
-- Name: app_enforcement_principal_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_enforcement_principal_links (
    id bigint NOT NULL,
    app_enforcement_case_id bigint CONSTRAINT app_enforcement_principal_link_app_enforcement_case_id_not_null NOT NULL,
    principal_kind character varying NOT NULL,
    principal_public_id character varying NOT NULL,
    relationship_kind character varying NOT NULL,
    linked_at timestamp(6) with time zone NOT NULL,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_app_enforcement_principal_links_relationship_kind CHECK (((relationship_kind)::text = ANY ((ARRAY['target_principal'::character varying, 'former_principal'::character varying, 'related_principal'::character varying, 'suspected_duplicate'::character varying, 'reinstated_principal'::character varying, 'false_positive'::character varying])::text[])))
);


--
-- Name: app_enforcement_principal_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_enforcement_principal_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_enforcement_principal_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_enforcement_principal_links_id_seq OWNED BY public.app_enforcement_principal_links.id;


--
-- Name: apple_auths; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.apple_auths (
    id bigint NOT NULL,
    access_token text NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    provider character varying DEFAULT ''::character varying NOT NULL,
    refresh_token text NOT NULL,
    uid character varying DEFAULT ''::character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: apple_auths_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.apple_auths_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: apple_auths_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.apple_auths_id_seq OWNED BY public.apple_auths.id;


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
-- Name: client_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_accounts (
    id bigint CONSTRAINT user_accounts_id_not_null NOT NULL,
    public_id character varying DEFAULT ''::character varying CONSTRAINT user_accounts_public_id_not_null NOT NULL,
    user_id bigint CONSTRAINT user_accounts_user_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_accounts_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_accounts_updated_at_not_null NOT NULL,
    CONSTRAINT client_accounts_public_id_max_length CHECK ((char_length((public_id)::text) <= 25))
);


--
-- Name: client_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_accounts_id_seq OWNED BY public.client_accounts.id;


--
-- Name: client_apple_notification_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_apple_notification_events (
    id bigint NOT NULL,
    jti character varying NOT NULL,
    event_type character varying(32) NOT NULL,
    client_external_identity_id bigint,
    received_at timestamp(6) with time zone NOT NULL,
    occurred_at timestamp(6) with time zone NOT NULL,
    status character varying(32) DEFAULT 'received'::character varying NOT NULL,
    processing_attempts integer DEFAULT 0 NOT NULL,
    next_retry_at timestamp(6) with time zone,
    processed_at timestamp(6) with time zone,
    dead_lettered_at timestamp(6) with time zone,
    failure_code character varying DEFAULT ''::character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    client_id bigint,
    CONSTRAINT chk_client_apple_notification_events_attempts CHECK ((processing_attempts >= 0)),
    CONSTRAINT chk_client_apple_notification_events_status CHECK (((status)::text = ANY ((ARRAY['received'::character varying, 'retrying'::character varying, 'completed'::character varying, 'dead_letter'::character varying])::text[]))),
    CONSTRAINT chk_client_apple_notification_events_type CHECK (((event_type)::text = ANY ((ARRAY['email-enabled'::character varying, 'email-disabled'::character varying, 'consent-revoked'::character varying, 'account-deleted'::character varying])::text[])))
);


--
-- Name: client_apple_notification_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_apple_notification_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_apple_notification_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_apple_notification_events_id_seq OWNED BY public.client_apple_notification_events.id;


--
-- Name: client_authority_locks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_authority_locks (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_authority_locks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_authority_locks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_authority_locks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_authority_locks_id_seq OWNED BY public.client_authority_locks.id;


--
-- Name: client_banners; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_banners (
    id bigint CONSTRAINT user_banners_id_not_null NOT NULL,
    user_id bigint CONSTRAINT user_banners_user_id_not_null NOT NULL,
    title character varying DEFAULT ''::character varying CONSTRAINT user_banners_title_not_null NOT NULL,
    body text CONSTRAINT user_banners_body_not_null NOT NULL,
    published boolean DEFAULT false CONSTRAINT user_banners_published_not_null NOT NULL,
    starts_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT user_banners_starts_at_not_null NOT NULL,
    ends_at timestamp(6) with time zone DEFAULT '9999-12-31 23:59:59+00'::timestamp with time zone CONSTRAINT user_banners_ends_at_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_banners_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_banners_updated_at_not_null NOT NULL,
    CONSTRAINT user_banners_ends_at_after_starts_at CHECK ((ends_at > starts_at))
);


--
-- Name: client_banners_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_banners_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_banners_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_banners_id_seq OWNED BY public.client_banners.id;


--
-- Name: client_bulletins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_bulletins (
    id bigint CONSTRAINT user_bulletins_id_not_null NOT NULL,
    user_id bigint CONSTRAINT user_bulletins_user_id_not_null NOT NULL,
    public_id character varying(21) CONSTRAINT user_bulletins_public_id_not_null NOT NULL,
    title character varying CONSTRAINT user_bulletins_title_not_null NOT NULL,
    body text,
    read_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone CONSTRAINT user_bulletins_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_bulletins_updated_at_not_null NOT NULL
);


--
-- Name: client_bulletins_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_bulletins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_bulletins_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_bulletins_id_seq OWNED BY public.client_bulletins.id;


--
-- Name: client_contact_audit_outboxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_contact_audit_outboxes (
    id bigint NOT NULL,
    event_uuid uuid NOT NULL,
    contact_kind character varying NOT NULL,
    event_name character varying NOT NULL,
    owner_ref character varying NOT NULL,
    contact_ref character varying NOT NULL,
    operation_ref character varying NOT NULL,
    actor_ref character varying,
    occurred_at timestamp(6) with time zone NOT NULL,
    acknowledged_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT client_contact_audit_acknowledgment CHECK (((acknowledged_at IS NULL) OR (acknowledged_at >= occurred_at))),
    CONSTRAINT client_contact_audit_event CHECK (((event_name)::text = ANY ((ARRAY['finalized'::character varying, 'released'::character varying])::text[]))),
    CONSTRAINT client_contact_audit_kind CHECK (((contact_kind)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying])::text[]))),
    CONSTRAINT client_contact_audit_references CHECK ((((owner_ref)::text <> ''::text) AND ((contact_ref)::text <> ''::text) AND ((operation_ref)::text <> ''::text)))
);


--
-- Name: client_contact_audit_outboxes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_contact_audit_outboxes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_contact_audit_outboxes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_contact_audit_outboxes_id_seq OWNED BY public.client_contact_audit_outboxes.id;


--
-- Name: client_email_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_email_histories (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    fingerprint character varying NOT NULL,
    attached_at timestamp(6) with time zone NOT NULL,
    detached_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_email_histories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_email_histories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_email_histories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_email_histories_id_seq OWNED BY public.client_email_histories.id;


--
-- Name: client_email_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_email_statuses (
    id bigint CONSTRAINT user_email_statuses_id_not_null NOT NULL
);


--
-- Name: client_email_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_email_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_email_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_email_statuses_id_seq OWNED BY public.client_email_statuses.id;


--
-- Name: client_emails; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_emails (
    id bigint CONSTRAINT user_emails_id_not_null NOT NULL,
    address character varying DEFAULT ''::character varying CONSTRAINT user_emails_address_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_emails_created_at_not_null NOT NULL,
    locked_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT user_emails_locked_at_not_null NOT NULL,
    otp_attempts_count integer DEFAULT 0 CONSTRAINT user_emails_otp_attempts_count_not_null NOT NULL,
    otp_last_sent_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone CONSTRAINT user_emails_otp_last_sent_at_not_null NOT NULL,
    public_id character varying(21) CONSTRAINT user_emails_public_id_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_emails_updated_at_not_null NOT NULL,
    user_id bigint CONSTRAINT user_emails_user_id_not_null NOT NULL,
    verification_token_digest bytea,
    user_email_status_id bigint DEFAULT 0 CONSTRAINT user_emails_user_identity_email_status_id_not_null NOT NULL,
    address_digest character varying,
    undeletable boolean DEFAULT false CONSTRAINT user_emails_undeletable_not_null NOT NULL,
    promotional boolean DEFAULT true CONSTRAINT user_emails_promotional_not_null NOT NULL,
    notifiable boolean DEFAULT true CONSTRAINT user_emails_notifiable_not_null NOT NULL,
    subscribable boolean DEFAULT true CONSTRAINT user_emails_subscribable_not_null NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT client_emails_discarded_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT client_emails_purged_at_not_null NOT NULL,
    step_up_otp_failures integer DEFAULT 0 NOT NULL,
    step_up_otp_locked_until timestamp(6) with time zone,
    step_up_otp_last_issued_at timestamp(6) with time zone,
    binding_finalized_at timestamp(6) with time zone,
    binding_released_at timestamp(6) with time zone,
    CONSTRAINT client_email_step_up_failures_nonnegative CHECK ((step_up_otp_failures >= 0)),
    CONSTRAINT client_emails_binding_digest_nonblank CHECK (((binding_finalized_at IS NULL) OR ((address_digest IS NOT NULL) AND ((address_digest)::text ~ '[^[:space:]]'::text)))),
    CONSTRAINT client_emails_binding_digest_unicode_nonblank CHECK (((binding_finalized_at IS NULL) OR ((address_digest IS NOT NULL) AND ((address_digest)::text ~ '[^[:space:]   -     　]'::text)))),
    CONSTRAINT client_emails_binding_effective_digest_present CHECK (((binding_finalized_at IS NULL) OR ((address_digest IS NOT NULL) AND ((address_digest)::text <> ''::text)))),
    CONSTRAINT client_emails_binding_release_requires_finalization CHECK (((binding_released_at IS NULL) OR (binding_finalized_at IS NOT NULL)))
);


--
-- Name: client_emails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_emails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_emails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_emails_id_seq OWNED BY public.client_emails.id;


--
-- Name: client_enforcement_recovery_ceremonies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_enforcement_recovery_ceremonies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    client_id bigint NOT NULL,
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
-- Name: client_enforcement_recovery_ceremonies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_enforcement_recovery_ceremonies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_enforcement_recovery_ceremonies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_enforcement_recovery_ceremonies_id_seq OWNED BY public.client_enforcement_recovery_ceremonies.id;


--
-- Name: client_external_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_external_identities (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    provider character varying(16) NOT NULL,
    issuer character varying NOT NULL,
    subject text NOT NULL,
    audience character varying NOT NULL,
    state character varying(32) DEFAULT 'active'::character varying NOT NULL,
    verification_authority character varying NOT NULL,
    verified_at timestamp(6) with time zone NOT NULL,
    last_authenticated_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    last_provider_event_at timestamp(6) with time zone,
    released_at timestamp(6) with time zone,
    CONSTRAINT chk_client_external_identities_provider CHECK (((provider)::text = ANY ((ARRAY['apple'::character varying, 'google'::character varying])::text[]))),
    CONSTRAINT chk_client_external_identities_state CHECK (((state)::text = ANY ((ARRAY['active'::character varying, 'consent_revoked'::character varying, 'account_deleted'::character varying])::text[])))
);


--
-- Name: client_external_identities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_external_identities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_external_identities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_external_identities_id_seq OWNED BY public.client_external_identities.id;


--
-- Name: client_identifier_rotation_audits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_identifier_rotation_audits (
    id bigint NOT NULL,
    operation_ref uuid NOT NULL,
    channel character varying NOT NULL,
    record_id bigint NOT NULL,
    actor_role character varying NOT NULL,
    occurred_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT client_rotation_channel CHECK (((channel)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying])::text[]))),
    CONSTRAINT client_rotation_subject CHECK (((record_id > 0) AND ((actor_role)::text <> ''::text)))
);


--
-- Name: client_identifier_rotation_audits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_identifier_rotation_audits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_identifier_rotation_audits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_identifier_rotation_audits_id_seq OWNED BY public.client_identifier_rotation_audits.id;


--
-- Name: client_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_identities (
    id bigint CONSTRAINT user_residents_id_not_null NOT NULL,
    public_id character varying DEFAULT ''::character varying CONSTRAINT user_residents_public_id_not_null NOT NULL,
    issuer character varying CONSTRAINT user_residents_issuer_not_null NOT NULL,
    subject character varying CONSTRAINT user_residents_subject_not_null NOT NULL,
    audience character varying CONSTRAINT user_residents_audience_not_null NOT NULL,
    source_record_id bigint CONSTRAINT user_residents_source_record_id_not_null NOT NULL,
    status_id bigint DEFAULT 0 CONSTRAINT user_residents_status_id_not_null NOT NULL,
    last_authenticated_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 CONSTRAINT user_residents_lock_version_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_residents_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_residents_updated_at_not_null NOT NULL,
    CONSTRAINT client_identities_public_id_max_length CHECK ((char_length((public_id)::text) <= 25))
);


--
-- Name: client_identities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_identities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_identities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_identities_id_seq OWNED BY public.client_identities.id;


--
-- Name: client_identity_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_identity_states (
    id bigint CONSTRAINT user_resident_statuses_id_not_null NOT NULL
);


--
-- Name: client_identity_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_identity_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_identity_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_identity_states_id_seq OWNED BY public.client_identity_states.id;


--
-- Name: client_member_deletions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_member_deletions (
    id bigint CONSTRAINT user_member_deletions_id_not_null NOT NULL,
    user_id bigint CONSTRAINT user_member_deletions_user_id_not_null NOT NULL,
    member_id bigint CONSTRAINT user_member_deletions_member_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_member_deletions_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_member_deletions_updated_at_not_null NOT NULL
);


--
-- Name: client_member_deletions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_member_deletions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_member_deletions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_member_deletions_id_seq OWNED BY public.client_member_deletions.id;


--
-- Name: client_member_discoveries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_member_discoveries (
    id bigint CONSTRAINT user_member_discoveries_id_not_null NOT NULL,
    user_id bigint CONSTRAINT user_member_discoveries_user_id_not_null NOT NULL,
    member_id bigint CONSTRAINT user_member_discoveries_member_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_member_discoveries_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_member_discoveries_updated_at_not_null NOT NULL
);


--
-- Name: client_member_discoveries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_member_discoveries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_member_discoveries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_member_discoveries_id_seq OWNED BY public.client_member_discoveries.id;


--
-- Name: client_member_impersonations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_member_impersonations (
    id bigint CONSTRAINT user_member_impersonations_id_not_null NOT NULL,
    user_id bigint CONSTRAINT user_member_impersonations_user_id_not_null NOT NULL,
    member_id bigint CONSTRAINT user_member_impersonations_member_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_member_impersonations_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_member_impersonations_updated_at_not_null NOT NULL
);


--
-- Name: client_member_impersonations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_member_impersonations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_member_impersonations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_member_impersonations_id_seq OWNED BY public.client_member_impersonations.id;


--
-- Name: client_member_observations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_member_observations (
    id bigint CONSTRAINT user_member_observations_id_not_null NOT NULL,
    user_id bigint CONSTRAINT user_member_observations_user_id_not_null NOT NULL,
    member_id bigint CONSTRAINT user_member_observations_member_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_member_observations_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_member_observations_updated_at_not_null NOT NULL
);


--
-- Name: client_member_observations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_member_observations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_member_observations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_member_observations_id_seq OWNED BY public.client_member_observations.id;


--
-- Name: client_member_revocations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_member_revocations (
    id bigint CONSTRAINT user_member_revocations_id_not_null NOT NULL,
    user_id bigint CONSTRAINT user_member_revocations_user_id_not_null NOT NULL,
    member_id bigint CONSTRAINT user_member_revocations_member_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_member_revocations_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_member_revocations_updated_at_not_null NOT NULL
);


--
-- Name: client_member_revocations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_member_revocations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_member_revocations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_member_revocations_id_seq OWNED BY public.client_member_revocations.id;


--
-- Name: client_member_suspensions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_member_suspensions (
    id bigint CONSTRAINT user_member_suspensions_id_not_null NOT NULL,
    user_id bigint CONSTRAINT user_member_suspensions_user_id_not_null NOT NULL,
    member_id bigint CONSTRAINT user_member_suspensions_member_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_member_suspensions_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_member_suspensions_updated_at_not_null NOT NULL
);


--
-- Name: client_member_suspensions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_member_suspensions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_member_suspensions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_member_suspensions_id_seq OWNED BY public.client_member_suspensions.id;


--
-- Name: client_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_members (
    id bigint CONSTRAINT user_members_id_not_null NOT NULL,
    user_id bigint CONSTRAINT user_members_user_id_not_null NOT NULL,
    member_id bigint CONSTRAINT user_members_member_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_members_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_members_updated_at_not_null NOT NULL
);


--
-- Name: client_members_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_members_id_seq OWNED BY public.client_members.id;


--
-- Name: client_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_memberships (
    id bigint CONSTRAINT user_memberships_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_memberships_created_at_not_null NOT NULL,
    joined_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT user_memberships_joined_at_not_null NOT NULL,
    left_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone CONSTRAINT user_memberships_left_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_memberships_updated_at_not_null NOT NULL,
    user_id bigint CONSTRAINT user_memberships_user_id_not_null NOT NULL,
    workspace_id bigint CONSTRAINT user_memberships_workspace_id_not_null NOT NULL
);


--
-- Name: client_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_memberships_id_seq OWNED BY public.client_memberships.id;


--
-- Name: client_mfa_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_mfa_levels (
    id bigint CONSTRAINT user_multi_factors_id_not_null NOT NULL
);


--
-- Name: client_mfa_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_mfa_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_mfa_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_mfa_levels_id_seq OWNED BY public.client_mfa_levels.id;


--
-- Name: client_mfa_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_mfa_statuses (
    id bigint CONSTRAINT user_multi_factor_statuses_id_not_null NOT NULL
);


--
-- Name: client_mfa_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_mfa_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_mfa_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_mfa_statuses_id_seq OWNED BY public.client_mfa_statuses.id;


--
-- Name: client_oidc_identity_bindings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_oidc_identity_bindings (
    id bigint NOT NULL,
    client_identity_id bigint NOT NULL,
    issuer character varying NOT NULL,
    subject character varying NOT NULL,
    audience character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_oidc_identity_bindings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_oidc_identity_bindings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_oidc_identity_bindings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_oidc_identity_bindings_id_seq OWNED BY public.client_oidc_identity_bindings.id;


--
-- Name: client_passkey_audit_outboxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_passkey_audit_outboxes (
    id bigint NOT NULL,
    event_uuid uuid NOT NULL,
    event_type character varying NOT NULL,
    surface character varying NOT NULL,
    external_id uuid NOT NULL,
    actor_ref character varying,
    operation_ref character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamp(6) with time zone NOT NULL,
    acknowledged_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT client_passkey_audit_acknowledgment CHECK (((acknowledged_at IS NULL) OR (acknowledged_at >= occurred_at))),
    CONSTRAINT client_passkey_audit_event CHECK (((event_type)::text = ANY ((ARRAY['passkey.registered.signup'::character varying, 'passkey.registered.settings'::character varying, 'passkey.description_changed'::character varying, 'passkey.removed'::character varying, 'passkey.revoked'::character varying, 'passkey.registration_cancelled'::character varying, 'passkey.purged'::character varying])::text[]))),
    CONSTRAINT client_passkey_audit_surface CHECK (((surface)::text = 'app'::text))
);


--
-- Name: client_passkey_audit_outboxes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_passkey_audit_outboxes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_passkey_audit_outboxes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_passkey_audit_outboxes_id_seq OWNED BY public.client_passkey_audit_outboxes.id;


--
-- Name: client_passkey_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_passkey_statuses (
    id bigint CONSTRAINT user_passkey_statuses_id_not_null NOT NULL
);


--
-- Name: client_passkey_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_passkey_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_passkey_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_passkey_statuses_id_seq OWNED BY public.client_passkey_statuses.id;


--
-- Name: client_passkeys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_passkeys (
    id bigint CONSTRAINT user_passkeys_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_passkeys_created_at_not_null NOT NULL,
    description character varying DEFAULT ''::character varying CONSTRAINT user_passkeys_description_not_null NOT NULL,
    external_id uuid CONSTRAINT user_passkeys_external_id_not_null NOT NULL,
    public_key text CONSTRAINT user_passkeys_public_key_not_null NOT NULL,
    sign_count bigint DEFAULT 0 CONSTRAINT user_passkeys_sign_count_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_passkeys_updated_at_not_null NOT NULL,
    user_id bigint CONSTRAINT user_passkeys_user_id_not_null NOT NULL,
    webauthn_id character varying DEFAULT ''::character varying CONSTRAINT user_passkeys_webauthn_id_not_null NOT NULL,
    status_id bigint DEFAULT 1 CONSTRAINT user_passkeys_user_passkey_status_id_not_null NOT NULL,
    last_used_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT client_passkeys_discarded_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT client_passkeys_purged_at_not_null NOT NULL,
    public_id character varying(21) CONSTRAINT client_passkeys_public_id_not_null1 NOT NULL,
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
-- Name: client_passkeys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_passkeys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_passkeys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_passkeys_id_seq OWNED BY public.client_passkeys.id;


--
-- Name: client_persona_administration_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_persona_administration_grants (
    id bigint NOT NULL,
    client_persona_id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_persona_administration_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_persona_administration_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_persona_administration_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_persona_administration_grants_id_seq OWNED BY public.client_persona_administration_grants.id;


--
-- Name: client_persona_authority_cutovers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_persona_authority_cutovers (
    id bigint NOT NULL,
    cutover_at timestamp(6) with time zone DEFAULT clock_timestamp() NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_client_persona_authority_cutovers_finite_time CHECK (isfinite(cutover_at)),
    CONSTRAINT chk_client_persona_authority_cutovers_singleton CHECK ((id = 1))
);


--
-- Name: client_persona_authority_cutovers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_persona_authority_cutovers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_persona_authority_cutovers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_persona_authority_cutovers_id_seq OWNED BY public.client_persona_authority_cutovers.id;


--
-- Name: client_persona_delegation_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_persona_delegation_grants (
    id bigint NOT NULL,
    client_persona_id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_persona_delegation_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_persona_delegation_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_persona_delegation_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_persona_delegation_grants_id_seq OWNED BY public.client_persona_delegation_grants.id;


--
-- Name: client_persona_lifecycles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_persona_lifecycles (
    id bigint NOT NULL,
    client_persona_id bigint NOT NULL,
    state character varying NOT NULL,
    state_changed_at timestamp(6) with time zone DEFAULT clock_timestamp() NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_client_persona_lifecycles_state CHECK (((state)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying, 'discarded'::character varying, 'deleted'::character varying, 'retained'::character varying])::text[])))
);


--
-- Name: client_persona_lifecycles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_persona_lifecycles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_persona_lifecycles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_persona_lifecycles_id_seq OWNED BY public.client_persona_lifecycles.id;


--
-- Name: client_persona_ownership_transfer_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_persona_ownership_transfer_requests (
    id bigint NOT NULL,
    client_persona_id bigint CONSTRAINT client_persona_ownership_transfer_re_client_persona_id_not_null NOT NULL,
    source_client_id bigint CONSTRAINT client_persona_ownership_transfer_req_source_client_id_not_null NOT NULL,
    destination_client_id bigint CONSTRAINT client_persona_ownership_transfe_destination_client_id_not_null NOT NULL,
    public_id character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    expected_ownership_revision integer CONSTRAINT client_persona_ownership_tr_expected_ownership_revisio_not_null NOT NULL,
    requested_at timestamp(6) with time zone CONSTRAINT client_persona_ownership_transfer_request_requested_at_not_null NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    accepted_at timestamp(6) with time zone,
    rejected_at timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    invalidated_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_client_persona_transfer_requests_distinct_parties CHECK ((source_client_id <> destination_client_id)),
    CONSTRAINT chk_client_persona_transfer_requests_expiry_after_request CHECK ((requested_at < expires_at)),
    CONSTRAINT chk_client_persona_transfer_requests_revision_nonnegative CHECK ((expected_ownership_revision >= 0)),
    CONSTRAINT chk_client_persona_transfer_requests_status CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'accepted'::character varying, 'rejected'::character varying, 'cancelled'::character varying, 'expired'::character varying, 'invalidated'::character varying])::text[]))),
    CONSTRAINT client_persona_ownership_transfer_requests_public_id_max_length CHECK ((char_length((public_id)::text) <= 25))
);


--
-- Name: client_persona_ownership_transfer_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_persona_ownership_transfer_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_persona_ownership_transfer_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_persona_ownership_transfer_requests_id_seq OWNED BY public.client_persona_ownership_transfer_requests.id;


--
-- Name: client_persona_ownerships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_persona_ownerships (
    id bigint NOT NULL,
    client_persona_id bigint NOT NULL,
    client_id bigint NOT NULL,
    ownership_revision integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_client_persona_ownerships_revision_nonnegative CHECK ((ownership_revision >= 0))
);


--
-- Name: client_persona_ownerships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_persona_ownerships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_persona_ownerships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_persona_ownerships_id_seq OWNED BY public.client_persona_ownerships.id;


--
-- Name: client_persona_usage_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_persona_usage_grants (
    id bigint NOT NULL,
    client_persona_id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_persona_usage_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_persona_usage_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_persona_usage_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_persona_usage_grants_id_seq OWNED BY public.client_persona_usage_grants.id;


--
-- Name: client_persona_view_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_persona_view_grants (
    id bigint NOT NULL,
    client_persona_id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_persona_view_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_persona_view_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_persona_view_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_persona_view_grants_id_seq OWNED BY public.client_persona_view_grants.id;


--
-- Name: client_preference_adult_content_gate_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_adult_content_gate_options (
    id bigint CONSTRAINT client_preference_r18_display_stopper_options_id_not_null NOT NULL
);


--
-- Name: client_preference_adult_content_gate_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_adult_content_gate_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_adult_content_gate_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_adult_content_gate_options_id_seq OWNED BY public.client_preference_adult_content_gate_options.id;


--
-- Name: client_preference_adult_content_gates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_adult_content_gates (
    id bigint CONSTRAINT client_preference_r18_display_stoppers_id_not_null NOT NULL,
    preference_id bigint CONSTRAINT client_preference_r18_display_stoppers_preference_id_not_null NOT NULL,
    option_id bigint CONSTRAINT client_preference_r18_display_stoppers_option_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT client_preference_r18_display_stoppers_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT client_preference_r18_display_stoppers_updated_at_not_null NOT NULL
);


--
-- Name: client_preference_adult_content_gates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_adult_content_gates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_adult_content_gates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_adult_content_gates_id_seq OWNED BY public.client_preference_adult_content_gates.id;


--
-- Name: client_preference_currencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_currencies (
    id bigint CONSTRAINT user_preference_currencies_id_not_null NOT NULL,
    preference_id bigint CONSTRAINT user_preference_currencies_preference_id_not_null NOT NULL,
    option_id bigint CONSTRAINT user_preference_currencies_option_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_preference_currencies_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_preference_currencies_updated_at_not_null NOT NULL
);


--
-- Name: client_preference_currencies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_currencies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_currencies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_currencies_id_seq OWNED BY public.client_preference_currencies.id;


--
-- Name: client_preference_currency_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_currency_options (
    id bigint CONSTRAINT user_preference_currency_options_id_not_null NOT NULL
);


--
-- Name: client_preference_currency_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_currency_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_currency_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_currency_options_id_seq OWNED BY public.client_preference_currency_options.id;


--
-- Name: client_preference_date_format_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_date_format_options (
    id bigint CONSTRAINT user_preference_date_format_options_id_not_null NOT NULL
);


--
-- Name: client_preference_date_format_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_date_format_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_date_format_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_date_format_options_id_seq OWNED BY public.client_preference_date_format_options.id;


--
-- Name: client_preference_date_formats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_date_formats (
    id bigint CONSTRAINT user_preference_date_formats_id_not_null NOT NULL,
    preference_id bigint CONSTRAINT user_preference_date_formats_preference_id_not_null NOT NULL,
    option_id bigint CONSTRAINT user_preference_date_formats_option_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_preference_date_formats_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_preference_date_formats_updated_at_not_null NOT NULL
);


--
-- Name: client_preference_date_formats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_date_formats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_date_formats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_date_formats_id_seq OWNED BY public.client_preference_date_formats.id;


--
-- Name: client_preference_densities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_densities (
    id bigint CONSTRAINT user_preference_densities_id_not_null NOT NULL,
    preference_id bigint CONSTRAINT user_preference_densities_preference_id_not_null NOT NULL,
    option_id bigint CONSTRAINT user_preference_densities_option_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_preference_densities_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_preference_densities_updated_at_not_null NOT NULL
);


--
-- Name: client_preference_densities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_densities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_densities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_densities_id_seq OWNED BY public.client_preference_densities.id;


--
-- Name: client_preference_density_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_density_options (
    id bigint CONSTRAINT user_preference_density_options_id_not_null NOT NULL
);


--
-- Name: client_preference_density_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_density_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_density_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_density_options_id_seq OWNED BY public.client_preference_density_options.id;


--
-- Name: client_preference_language_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_language_options (
    id bigint CONSTRAINT user_preference_language_options_id_not_null NOT NULL
);


--
-- Name: client_preference_language_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_language_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_language_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_language_options_id_seq OWNED BY public.client_preference_language_options.id;


--
-- Name: client_preference_languages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_languages (
    id bigint CONSTRAINT user_preference_languages_id_not_null NOT NULL,
    preference_id bigint CONSTRAINT user_preference_languages_preference_id_not_null NOT NULL,
    option_id bigint CONSTRAINT user_preference_languages_option_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_preference_languages_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_preference_languages_updated_at_not_null NOT NULL
);


--
-- Name: client_preference_languages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_languages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_languages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_languages_id_seq OWNED BY public.client_preference_languages.id;


--
-- Name: client_preference_motion_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_motion_options (
    id bigint CONSTRAINT user_preference_motion_options_id_not_null NOT NULL
);


--
-- Name: client_preference_motion_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_motion_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_motion_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_motion_options_id_seq OWNED BY public.client_preference_motion_options.id;


--
-- Name: client_preference_motions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_motions (
    id bigint CONSTRAINT user_preference_motions_id_not_null NOT NULL,
    preference_id bigint CONSTRAINT user_preference_motions_preference_id_not_null NOT NULL,
    option_id bigint CONSTRAINT user_preference_motions_option_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_preference_motions_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_preference_motions_updated_at_not_null NOT NULL
);


--
-- Name: client_preference_motions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_motions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_motions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_motions_id_seq OWNED BY public.client_preference_motions.id;


--
-- Name: client_preference_page_size_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_page_size_options (
    id bigint CONSTRAINT user_preference_items_per_page_options_id_not_null NOT NULL
);


--
-- Name: client_preference_page_size_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_page_size_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_page_size_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_page_size_options_id_seq OWNED BY public.client_preference_page_size_options.id;


--
-- Name: client_preference_page_sizes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_page_sizes (
    id bigint CONSTRAINT user_preference_items_per_pages_id_not_null NOT NULL,
    preference_id bigint CONSTRAINT user_preference_items_per_pages_preference_id_not_null NOT NULL,
    option_id bigint CONSTRAINT user_preference_items_per_pages_option_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_preference_items_per_pages_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_preference_items_per_pages_updated_at_not_null NOT NULL
);


--
-- Name: client_preference_page_sizes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_page_sizes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_page_sizes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_page_sizes_id_seq OWNED BY public.client_preference_page_sizes.id;


--
-- Name: client_preference_region_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_region_options (
    id bigint CONSTRAINT user_preference_region_options_id_not_null NOT NULL
);


--
-- Name: client_preference_region_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_region_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_region_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_region_options_id_seq OWNED BY public.client_preference_region_options.id;


--
-- Name: client_preference_regions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_regions (
    id bigint CONSTRAINT user_preference_regions_id_not_null NOT NULL,
    preference_id bigint CONSTRAINT user_preference_regions_preference_id_not_null NOT NULL,
    option_id bigint CONSTRAINT user_preference_regions_option_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_preference_regions_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_preference_regions_updated_at_not_null NOT NULL
);


--
-- Name: client_preference_regions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_regions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_regions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_regions_id_seq OWNED BY public.client_preference_regions.id;


--
-- Name: client_preference_theme_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_theme_options (
    id bigint CONSTRAINT user_preference_colortheme_options_id_not_null NOT NULL
);


--
-- Name: client_preference_theme_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_theme_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_theme_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_theme_options_id_seq OWNED BY public.client_preference_theme_options.id;


--
-- Name: client_preference_themes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_themes (
    id bigint CONSTRAINT user_preference_colorthemes_id_not_null NOT NULL,
    preference_id bigint CONSTRAINT user_preference_colorthemes_preference_id_not_null NOT NULL,
    option_id bigint CONSTRAINT user_preference_colorthemes_option_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_preference_colorthemes_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_preference_colorthemes_updated_at_not_null NOT NULL
);


--
-- Name: client_preference_themes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_themes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_themes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_themes_id_seq OWNED BY public.client_preference_themes.id;


--
-- Name: client_preference_time_format_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_time_format_options (
    id bigint CONSTRAINT user_preference_time_format_options_id_not_null NOT NULL
);


--
-- Name: client_preference_time_format_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_time_format_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_time_format_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_time_format_options_id_seq OWNED BY public.client_preference_time_format_options.id;


--
-- Name: client_preference_time_formats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_time_formats (
    id bigint CONSTRAINT user_preference_time_formats_id_not_null NOT NULL,
    preference_id bigint CONSTRAINT user_preference_time_formats_preference_id_not_null NOT NULL,
    option_id bigint CONSTRAINT user_preference_time_formats_option_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_preference_time_formats_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_preference_time_formats_updated_at_not_null NOT NULL
);


--
-- Name: client_preference_time_formats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_time_formats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_time_formats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_time_formats_id_seq OWNED BY public.client_preference_time_formats.id;


--
-- Name: client_preference_timezone_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_timezone_options (
    id bigint CONSTRAINT user_preference_timezone_options_id_not_null NOT NULL
);


--
-- Name: client_preference_timezone_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_timezone_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_timezone_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_timezone_options_id_seq OWNED BY public.client_preference_timezone_options.id;


--
-- Name: client_preference_timezones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_timezones (
    id bigint CONSTRAINT user_preference_timezones_id_not_null NOT NULL,
    preference_id bigint CONSTRAINT user_preference_timezones_preference_id_not_null NOT NULL,
    option_id bigint CONSTRAINT user_preference_timezones_option_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_preference_timezones_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_preference_timezones_updated_at_not_null NOT NULL
);


--
-- Name: client_preference_timezones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_timezones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_timezones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_timezones_id_seq OWNED BY public.client_preference_timezones.id;


--
-- Name: client_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preferences (
    id bigint CONSTRAINT user_preferences_id_not_null NOT NULL,
    user_id bigint CONSTRAINT user_preferences_user_id_not_null NOT NULL,
    consented boolean DEFAULT false CONSTRAINT user_preferences_consented_not_null NOT NULL,
    functional boolean DEFAULT false CONSTRAINT user_preferences_functional_not_null NOT NULL,
    performant boolean DEFAULT false CONSTRAINT user_preferences_performant_not_null NOT NULL,
    targetable boolean DEFAULT false CONSTRAINT user_preferences_targetable_not_null NOT NULL,
    consented_at timestamp(6) with time zone,
    consent_version uuid,
    created_at timestamp(6) with time zone CONSTRAINT user_preferences_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_preferences_updated_at_not_null NOT NULL,
    language character varying DEFAULT 'ja'::character varying CONSTRAINT user_preferences_language_not_null NOT NULL,
    region character varying DEFAULT 'jp'::character varying CONSTRAINT user_preferences_region_not_null NOT NULL,
    timezone character varying DEFAULT 'Asia/Tokyo'::character varying CONSTRAINT user_preferences_timezone_not_null NOT NULL,
    theme character varying DEFAULT 'sy'::character varying CONSTRAINT user_preferences_theme_not_null NOT NULL,
    public_id character varying(21) CONSTRAINT client_preferences_public_id_not_null1 NOT NULL,
    currency character varying DEFAULT 'jpy'::character varying CONSTRAINT user_preferences_currency_not_null NOT NULL,
    date_format character varying DEFAULT 'iso'::character varying CONSTRAINT user_preferences_date_format_not_null NOT NULL,
    time_format character varying DEFAULT '24'::character varying CONSTRAINT user_preferences_time_format_not_null NOT NULL,
    motion character varying DEFAULT 'standard'::character varying CONSTRAINT user_preferences_motion_not_null NOT NULL,
    density character varying DEFAULT 'standard'::character varying CONSTRAINT user_preferences_density_not_null NOT NULL,
    page_size character varying DEFAULT 'infinity'::character varying CONSTRAINT user_preferences_items_per_page_not_null NOT NULL,
    explicit_fields jsonb DEFAULT '[]'::jsonb
);


--
-- Name: client_preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preferences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preferences_id_seq OWNED BY public.client_preferences.id;


--
-- Name: client_privacy_request_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_privacy_request_statuses (
    id bigint NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL
);


--
-- Name: client_privacy_request_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_privacy_request_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_privacy_request_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_privacy_request_statuses_id_seq OWNED BY public.client_privacy_request_statuses.id;


--
-- Name: client_privacy_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_privacy_requests (
    id bigint NOT NULL,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    client_id bigint NOT NULL,
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
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT client_privacy_requests_discarded_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT client_privacy_requests_purged_at_not_null NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_client_privacy_requests_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: client_privacy_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_privacy_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_privacy_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_privacy_requests_id_seq OWNED BY public.client_privacy_requests.id;


--
-- Name: client_processor_erasure_notification_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_processor_erasure_notification_attempts (
    id bigint NOT NULL,
    client_processor_erasure_notification_id bigint CONSTRAINT client_processor_erasure_no_client_processor_erasure_n_not_null NOT NULL,
    delivery_generation bigint CONSTRAINT client_processor_erasure_notifica_delivery_generation_not_null1 NOT NULL,
    attempt_number integer CONSTRAINT client_processor_erasure_notification_a_attempt_number_not_null NOT NULL,
    processor_key character varying CONSTRAINT client_processor_erasure_notification_at_processor_key_not_null NOT NULL,
    idempotency_key_digest character varying(64) CONSTRAINT client_processor_erasure_notifi_idempotency_key_digest_not_null NOT NULL,
    outcome character varying NOT NULL,
    started_at timestamp(6) with time zone CONSTRAINT client_processor_erasure_notification_attem_started_at_not_null NOT NULL,
    finished_at timestamp(6) with time zone,
    lease_expires_at timestamp(6) with time zone,
    receipt_reference_digest character varying(64),
    error_code character varying DEFAULT ''::character varying CONSTRAINT client_processor_erasure_notification_attem_error_code_not_null NOT NULL,
    error_message character varying DEFAULT ''::character varying CONSTRAINT client_processor_erasure_notification_at_error_message_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT client_processor_erasure_notification_attem_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT client_processor_erasure_notification_attem_updated_at_not_null NOT NULL,
    CONSTRAINT chk_client_proc_erase_attempt_generation_positive CHECK ((delivery_generation > 0)),
    CONSTRAINT chk_client_proc_erase_attempt_idempotency_digest CHECK (((idempotency_key_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_client_proc_erase_attempt_number_positive CHECK ((attempt_number > 0)),
    CONSTRAINT chk_client_proc_erase_attempt_outcome CHECK (((outcome)::text = ANY ((ARRAY['IN_FLIGHT'::character varying, 'ACCEPTED_PENDING'::character varying, 'SUCCEEDED'::character varying, 'RETRYABLE_FAILURE'::character varying, 'PERMANENT_FAILURE'::character varying])::text[])))
);


--
-- Name: client_processor_erasure_notification_attempts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_processor_erasure_notification_attempts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_processor_erasure_notification_attempts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_processor_erasure_notification_attempts_id_seq OWNED BY public.client_processor_erasure_notification_attempts.id;


--
-- Name: client_processor_erasure_notification_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_processor_erasure_notification_statuses (
    id bigint NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL
);


--
-- Name: client_processor_erasure_notification_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_processor_erasure_notification_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_processor_erasure_notification_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_processor_erasure_notification_statuses_id_seq OWNED BY public.client_processor_erasure_notification_statuses.id;


--
-- Name: client_processor_erasure_notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_processor_erasure_notifications (
    id bigint NOT NULL,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    client_privacy_request_id bigint CONSTRAINT client_processor_erasure_not_client_privacy_request_id_not_null NOT NULL,
    processor_key character varying DEFAULT ''::character varying NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    requested_at timestamp(6) with time zone NOT NULL,
    notified_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    last_error_code character varying DEFAULT ''::character varying NOT NULL,
    last_error_message character varying DEFAULT ''::character varying CONSTRAINT client_processor_erasure_notificati_last_error_message_not_null NOT NULL,
    retry_count integer DEFAULT 0 NOT NULL,
    next_retry_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT client_processor_erasure_notifications_discarded_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT client_processor_erasure_notifications_purged_at_not_null NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    delivery_generation bigint DEFAULT 1 CONSTRAINT client_processor_erasure_notificat_delivery_generation_not_null NOT NULL,
    permanent_failed_at timestamp(6) with time zone,
    delivery_idempotency_key_digest character varying(64) CONSTRAINT client_processor_erasure_no_delivery_idempotency_key_d_not_null NOT NULL,
    CONSTRAINT chk_client_proc_erase_notifications_generation_positive CHECK ((delivery_generation > 0)),
    CONSTRAINT chk_client_proc_erase_notifications_idempotency_digest CHECK (((delivery_idempotency_key_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_client_proc_erase_notifications_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT chk_client_proc_erase_notifications_retry_count_nonnegative CHECK ((retry_count >= 0))
);


--
-- Name: client_processor_erasure_notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_processor_erasure_notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_processor_erasure_notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_processor_erasure_notifications_id_seq OWNED BY public.client_processor_erasure_notifications.id;


--
-- Name: client_profile_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_profile_statuses (
    id bigint NOT NULL
);


--
-- Name: client_profile_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_profile_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_profile_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_profile_statuses_id_seq OWNED BY public.client_profile_statuses.id;


--
-- Name: client_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_profiles (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    division_id bigint,
    lock_version integer DEFAULT 0 NOT NULL,
    moniker character varying,
    public_id character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint,
    client_status_id bigint DEFAULT 0 NOT NULL,
    status_id bigint DEFAULT 0 NOT NULL,
    CONSTRAINT client_profiles_public_id_max_length CHECK ((char_length((public_id)::text) <= 25))
);


--
-- Name: client_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_profiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_profiles_id_seq OWNED BY public.client_profiles.id;


--
-- Name: client_retention_hold_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_retention_hold_statuses (
    id bigint NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL
);


--
-- Name: client_retention_hold_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_retention_hold_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_retention_hold_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_retention_hold_statuses_id_seq OWNED BY public.client_retention_hold_statuses.id;


--
-- Name: client_retention_holds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_retention_holds (
    id bigint NOT NULL,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    client_id bigint NOT NULL,
    hold_kind character varying DEFAULT 'legal_hold'::character varying NOT NULL,
    reason_code character varying DEFAULT 'legal_hold'::character varying NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    applied_at timestamp(6) with time zone NOT NULL,
    released_at timestamp(6) with time zone,
    expires_at timestamp(6) with time zone,
    applied_by_type character varying DEFAULT ''::character varying NOT NULL,
    applied_by_public_id character varying DEFAULT ''::character varying NOT NULL,
    memo character varying DEFAULT ''::character varying NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT client_retention_holds_discarded_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT client_retention_holds_purged_at_not_null NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_client_retention_holds_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: client_retention_holds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_retention_holds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_retention_holds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_retention_holds_id_seq OWNED BY public.client_retention_holds.id;


--
-- Name: client_secret_audit_outboxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_secret_audit_outboxes (
    id bigint NOT NULL,
    event_id uuid NOT NULL,
    event_name character varying(128) NOT NULL,
    client_ref character varying(21) NOT NULL,
    credential_ref character varying(21),
    actor_type character varying,
    actor_id bigint,
    actor_public_ref character varying(21),
    executor_job_id character varying,
    operation_ref uuid NOT NULL,
    occurred_at timestamp(6) with time zone NOT NULL,
    reason character varying(128),
    item_count integer,
    delivered_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    issuance_origin character varying,
    issuance_browser_session_ref character varying,
    issuance_sign_up_flow_ref character varying,
    CONSTRAINT client_secret_audit_actor CHECK ((((actor_type IS NULL) AND (actor_id IS NULL) AND (actor_public_ref IS NULL)) OR ((actor_type IS NOT NULL) AND ((actor_type)::text = 'Client'::text) AND (actor_id IS NOT NULL) AND (actor_public_ref IS NOT NULL)))),
    CONSTRAINT client_secret_audit_count CHECK (((item_count IS NULL) OR ((item_count >= 0) AND (item_count <= 20)))),
    CONSTRAINT client_secret_audit_delivery_retention CHECK (((delivered_at IS NOT NULL) OR (purge_eligible_at = 'infinity'::timestamp with time zone))),
    CONSTRAINT client_secret_issuance_purge_authority_snapshot CHECK ((((event_name)::text <> 'secret.issuance_purged'::text) OR (((issuance_origin IS NULL) AND (issuance_browser_session_ref IS NULL) AND (issuance_sign_up_flow_ref IS NULL)) OR (((issuance_origin)::text = ANY ((ARRAY['manual'::character varying, 'passkey_registration'::character varying])::text[])) AND ((issuance_browser_session_ref IS NULL) <> (issuance_sign_up_flow_ref IS NULL))))))
);


--
-- Name: client_secret_audit_outboxes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_secret_audit_outboxes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_secret_audit_outboxes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_secret_audit_outboxes_id_seq OWNED BY public.client_secret_audit_outboxes.id;


--
-- Name: client_secret_credentials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_secret_credentials (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    client_id bigint NOT NULL,
    issuance_id bigint NOT NULL,
    name character varying(255) NOT NULL,
    password_digest character varying(255) NOT NULL,
    confirmed_at timestamp(6) with time zone,
    claimed_at timestamp(6) with time zone,
    claim_operation_id uuid,
    revoked_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    claim_sign_in_flow_ref character varying(21),
    claim_ceremony_session_id bigint,
    consumed_at timestamp(6) with time zone,
    CONSTRAINT client_secret_claim_binding CHECK ((((claimed_at IS NULL) = (claim_sign_in_flow_ref IS NULL)) AND ((claimed_at IS NULL) = (claim_ceremony_session_id IS NULL)))),
    CONSTRAINT client_secret_consumption CHECK (((consumed_at IS NULL) OR ((claimed_at IS NOT NULL) AND (consumed_at >= claimed_at) AND (discard_at <= consumed_at)))),
    CONSTRAINT client_secret_credential_claim CHECK ((((claimed_at IS NULL) = (claim_operation_id IS NULL)) AND ((claimed_at IS NULL) OR ((confirmed_at IS NOT NULL) AND (claimed_at >= confirmed_at)))))
);


--
-- Name: client_secret_credentials_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_secret_credentials_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_secret_credentials_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_secret_credentials_id_seq OWNED BY public.client_secret_credentials.id;


--
-- Name: client_secret_issuances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_secret_issuances (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    client_id bigint NOT NULL,
    origin_operation_id uuid NOT NULL,
    origin character varying NOT NULL,
    attempt_number integer NOT NULL,
    browser_session_ref character varying,
    sign_up_flow_ref character varying,
    planned_count integer NOT NULL,
    expires_at timestamp(6) with time zone,
    presented_at timestamp(6) with time zone,
    confirmed_at timestamp(6) with time zone,
    canceled_at timestamp(6) with time zone,
    encrypted_payload text,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    signup_completed_at timestamp(6) with time zone,
    CONSTRAINT client_secret_issuance_binding CHECK (((browser_session_ref IS NULL) <> (sign_up_flow_ref IS NULL))),
    CONSTRAINT client_secret_issuance_count CHECK ((((origin)::text = ANY ((ARRAY['manual'::character varying, 'passkey_registration'::character varying])::text[])) AND (attempt_number > 0) AND ((planned_count >= 0) AND (planned_count <= 2)) AND (((origin)::text <> 'manual'::text) OR (planned_count <= 1)))),
    CONSTRAINT client_secret_issuance_facts CHECK (((NOT ((confirmed_at IS NOT NULL) AND (canceled_at IS NOT NULL))) AND ((confirmed_at IS NULL) OR ((presented_at IS NOT NULL) AND (confirmed_at >= presented_at) AND (confirmed_at < expires_at))) AND ((presented_at IS NULL) OR (presented_at < expires_at)))),
    CONSTRAINT client_secret_issuance_omission CHECK ((((planned_count = 0) AND (expires_at IS NULL) AND (presented_at IS NULL) AND (confirmed_at IS NULL) AND (canceled_at IS NULL) AND (encrypted_payload IS NULL)) OR ((planned_count > 0) AND (expires_at IS NOT NULL))))
);


--
-- Name: client_secret_issuances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_secret_issuances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_secret_issuances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_secret_issuances_id_seq OWNED BY public.client_secret_issuances.id;


--
-- Name: client_social_audit_outboxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_social_audit_outboxes (
    id bigint NOT NULL,
    event_uuid uuid NOT NULL,
    operation_ref character varying NOT NULL,
    owner_ref character varying NOT NULL,
    identity_ref character varying NOT NULL,
    provider character varying NOT NULL,
    provider_subject_digest character varying NOT NULL,
    event_name character varying NOT NULL,
    occurred_at timestamp(6) with time zone NOT NULL,
    released_at timestamp(6) with time zone,
    acknowledged_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT client_social_audit_acknowledgment CHECK (((acknowledged_at IS NULL) OR (acknowledged_at >= occurred_at))),
    CONSTRAINT client_social_audit_digest CHECK (((provider_subject_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT client_social_audit_event CHECK (((event_name)::text = ANY ((ARRAY['linked'::character varying, 'unlinked'::character varying])::text[]))),
    CONSTRAINT client_social_audit_provider CHECK (((provider)::text = ANY ((ARRAY['apple'::character varying, 'google'::character varying])::text[]))),
    CONSTRAINT client_social_audit_references CHECK ((((operation_ref)::text <> ''::text) AND ((owner_ref)::text <> ''::text) AND ((identity_ref)::text <> ''::text))),
    CONSTRAINT client_social_audit_release CHECK (((((event_name)::text = 'linked'::text) AND (released_at IS NULL)) OR (((event_name)::text = 'unlinked'::text) AND (released_at IS NOT NULL))))
);


--
-- Name: client_social_audit_outboxes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_social_audit_outboxes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_social_audit_outboxes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_social_audit_outboxes_id_seq OWNED BY public.client_social_audit_outboxes.id;


--
-- Name: client_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_statuses (
    id bigint CONSTRAINT user_statuses_id_not_null NOT NULL
);


--
-- Name: client_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_statuses_id_seq OWNED BY public.client_statuses.id;


--
-- Name: client_telephone_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_telephone_histories (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    fingerprint character varying NOT NULL,
    attached_at timestamp(6) with time zone NOT NULL,
    detached_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_telephone_histories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_telephone_histories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_telephone_histories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_telephone_histories_id_seq OWNED BY public.client_telephone_histories.id;


--
-- Name: client_telephone_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_telephone_statuses (
    id bigint CONSTRAINT user_telephone_statuses_id_not_null NOT NULL
);


--
-- Name: client_telephone_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_telephone_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_telephone_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_telephone_statuses_id_seq OWNED BY public.client_telephone_statuses.id;


--
-- Name: client_telephones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_telephones (
    id bigint CONSTRAINT user_telephones_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_telephones_created_at_not_null NOT NULL,
    locked_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone CONSTRAINT user_telephones_locked_at_not_null NOT NULL,
    number character varying DEFAULT ''::character varying CONSTRAINT user_telephones_number_not_null NOT NULL,
    otp_attempts_count integer DEFAULT 0 CONSTRAINT user_telephones_otp_attempts_count_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT user_telephones_updated_at_not_null NOT NULL,
    user_id bigint CONSTRAINT user_telephones_user_id_not_null NOT NULL,
    user_identity_telephone_status_id bigint DEFAULT 0 CONSTRAINT user_telephones_user_identity_telephone_status_id_not_null NOT NULL,
    public_id character varying(21) CONSTRAINT user_telephones_public_id_not_null NOT NULL,
    number_digest character varying,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT client_telephones_discarded_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT client_telephones_purged_at_not_null NOT NULL,
    binding_finalized_at timestamp(6) with time zone,
    binding_released_at timestamp(6) with time zone,
    otp_last_sent_at timestamp(6) with time zone,
    CONSTRAINT client_telephones_binding_digest_nonblank CHECK (((binding_finalized_at IS NULL) OR ((number_digest IS NOT NULL) AND ((number_digest)::text ~ '[^[:space:]]'::text)))),
    CONSTRAINT client_telephones_binding_digest_unicode_nonblank CHECK (((binding_finalized_at IS NULL) OR ((number_digest IS NOT NULL) AND ((number_digest)::text ~ '[^[:space:]   -     　]'::text)))),
    CONSTRAINT client_telephones_binding_effective_digest_present CHECK (((binding_finalized_at IS NULL) OR ((number_digest IS NOT NULL) AND ((number_digest)::text <> ''::text)))),
    CONSTRAINT client_telephones_binding_release_requires_finalization CHECK (((binding_released_at IS NULL) OR (binding_finalized_at IS NOT NULL)))
);


--
-- Name: client_telephones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_telephones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_telephones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_telephones_id_seq OWNED BY public.client_telephones.id;


--
-- Name: client_totp_credential_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_totp_credential_statuses (
    id bigint CONSTRAINT user_one_time_password_statuses_id_not_null NOT NULL
);


--
-- Name: client_totp_credential_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_totp_credential_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_totp_credential_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_totp_credential_statuses_id_seq OWNED BY public.client_totp_credential_statuses.id;


--
-- Name: client_totp_credentials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_totp_credentials (
    id bigint CONSTRAINT user_one_time_passwords_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT user_one_time_passwords_created_at_not_null NOT NULL,
    last_otp_at timestamp(6) with time zone,
    private_key character varying(1024) DEFAULT ''::character varying CONSTRAINT user_one_time_passwords_private_key_not_null NOT NULL,
    public_id character varying(21) CONSTRAINT user_one_time_passwords_public_id_not_null NOT NULL,
    title character varying(32),
    updated_at timestamp(6) with time zone CONSTRAINT user_one_time_passwords_updated_at_not_null NOT NULL,
    user_id bigint CONSTRAINT user_one_time_passwords_user_id_not_null NOT NULL,
    user_identity_totp_credential_status_id bigint DEFAULT 5 CONSTRAINT user_one_time_passwords_user_identity_one_time_passwor_not_null NOT NULL,
    otp_attempts_count integer DEFAULT 0 NOT NULL,
    CONSTRAINT client_totp_credentials_otp_attempts_count_range CHECK (((otp_attempts_count >= 0) AND (otp_attempts_count <= 100)))
);


--
-- Name: client_totp_credentials_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_totp_credentials_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_totp_credentials_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_totp_credentials_id_seq OWNED BY public.client_totp_credentials.id;


--
-- Name: client_visibilities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_visibilities (
    id bigint CONSTRAINT user_visibilities_id_not_null NOT NULL
);


--
-- Name: client_visibilities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_visibilities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_visibilities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_visibilities_id_seq OWNED BY public.client_visibilities.id;


--
-- Name: client_withdrawal_ceremonies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_withdrawal_ceremonies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    client_id bigint NOT NULL,
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
-- Name: client_withdrawal_ceremonies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_withdrawal_ceremonies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_withdrawal_ceremonies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_withdrawal_ceremonies_id_seq OWNED BY public.client_withdrawal_ceremonies.id;


--
-- Name: client_withdrawal_flow_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_withdrawal_flow_events (
    id bigint CONSTRAINT client_withdrawal_cycle_events_id_not_null NOT NULL,
    client_withdrawal_flow_id bigint CONSTRAINT client_withdrawal_cycle_eve_client_withdrawal_cycle_id_not_null NOT NULL,
    client_id bigint CONSTRAINT client_withdrawal_cycle_events_client_id_not_null NOT NULL,
    from_status_id bigint,
    to_status_id bigint CONSTRAINT client_withdrawal_cycle_events_to_status_id_not_null NOT NULL,
    occurred_at timestamp(6) with time zone CONSTRAINT client_withdrawal_cycle_events_occurred_at_not_null NOT NULL,
    token_public_id character varying(64) DEFAULT ''::character varying CONSTRAINT client_withdrawal_cycle_events_token_public_id_not_null NOT NULL,
    reason character varying(64) DEFAULT ''::character varying CONSTRAINT client_withdrawal_cycle_events_reason_not_null NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb CONSTRAINT client_withdrawal_cycle_events_metadata_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT client_withdrawal_cycle_events_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT client_withdrawal_cycle_events_updated_at_not_null NOT NULL
);


--
-- Name: client_withdrawal_flow_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_withdrawal_flow_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_withdrawal_flow_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_withdrawal_flow_events_id_seq OWNED BY public.client_withdrawal_flow_events.id;


--
-- Name: client_withdrawal_flow_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_withdrawal_flow_statuses (
    id bigint CONSTRAINT client_withdrawal_cycle_statuses_id_not_null NOT NULL
);


--
-- Name: client_withdrawal_flow_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_withdrawal_flow_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_withdrawal_flow_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_withdrawal_flow_statuses_id_seq OWNED BY public.client_withdrawal_flow_statuses.id;


--
-- Name: client_withdrawal_flows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_withdrawal_flows (
    id bigint CONSTRAINT client_withdrawal_cycles_id_not_null NOT NULL,
    public_id character varying(21) CONSTRAINT client_withdrawal_cycles_public_id_not_null NOT NULL,
    client_id bigint CONSTRAINT client_withdrawal_cycles_client_id_not_null NOT NULL,
    status_id bigint DEFAULT 10 CONSTRAINT client_withdrawal_cycles_status_id_not_null NOT NULL,
    began_at timestamp(6) with time zone CONSTRAINT client_withdrawal_cycles_began_at_not_null NOT NULL,
    completed_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT client_withdrawal_cycles_discarded_at_not_null NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT client_withdrawal_cycles_purged_at_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT client_withdrawal_cycles_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT client_withdrawal_cycles_updated_at_not_null NOT NULL,
    CONSTRAINT chk_client_withdrawal_cycles_retention_order CHECK ((discard_at <= purge_eligible_at))
);


--
-- Name: client_withdrawal_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_withdrawal_flows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_withdrawal_flows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_withdrawal_flows_id_seq OWNED BY public.client_withdrawal_flows.id;


--
-- Name: clients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clients (
    id bigint CONSTRAINT users_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT users_created_at_not_null NOT NULL,
    last_step_up_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 CONSTRAINT users_lock_version_not_null NOT NULL,
    public_id character varying(255) DEFAULT ''::character varying CONSTRAINT users_public_id_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT users_updated_at_not_null NOT NULL,
    withdrawn_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone,
    status_id bigint DEFAULT 11 CONSTRAINT users_status_id_not_null NOT NULL,
    mfa_level_enabled boolean DEFAULT false CONSTRAINT users_multi_factor_enabled_not_null NOT NULL,
    withdrawal_started_at timestamp(6) with time zone,
    deactivated_at timestamp(6) with time zone,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT users_purged_at_not_null NOT NULL,
    visibility_id bigint DEFAULT 2 CONSTRAINT users_visibility_id_not_null NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT users_discarded_at_not_null NOT NULL,
    mfa_level_id bigint DEFAULT 0 CONSTRAINT users_multi_factor_id_not_null NOT NULL,
    mfa_status_id bigint DEFAULT 5 CONSTRAINT users_multi_factor_status_id_not_null NOT NULL,
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
    authentication_epoch bigint DEFAULT 0 NOT NULL,
    recovery_available_at timestamp(6) with time zone,
    early_termination_available_at timestamp(6) with time zone,
    CONSTRAINT chk_clients_access_state CHECK (((access_state)::text = ANY ((ARRAY['enabled'::character varying, 'admin_locked'::character varying])::text[]))),
    CONSTRAINT chk_clients_admin_locked_reason_code CHECK (((admin_locked_reason_code IS NULL) OR ((admin_locked_reason_code)::text = ANY ((ARRAY['abuse'::character varying, 'security_incident'::character varying, 'chargeback'::character varying, 'terms_violation'::character varying, 'support_request'::character varying, 'legal_hold'::character varying, 'operator_error_recovery'::character varying, 'other'::character varying])::text[])))),
    CONSTRAINT chk_clients_authentication_epoch_nonnegative CHECK ((authentication_epoch >= 0)),
    CONSTRAINT chk_clients_birthdate_length CHECK (((birthdate IS NULL) OR (char_length(birthdate) <= 1000))),
    CONSTRAINT chk_users_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT clients_public_id_max_length CHECK ((char_length((public_id)::text) <= 25))
);


--
-- Name: clients_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.clients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.clients_id_seq OWNED BY public.clients.id;


--
-- Name: core_app_client_bridges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.core_app_client_bridges (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    rp_client_id character varying DEFAULT 'core_app'::character varying NOT NULL,
    audience character varying DEFAULT 'umaxica-core-app'::character varying NOT NULL,
    host character varying DEFAULT 'jpx.umaxica.app'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT core_app_client_bridges_public_id_max_length CHECK ((char_length((public_id)::text) <= 25))
);


--
-- Name: core_app_client_bridges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.core_app_client_bridges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: core_app_client_bridges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.core_app_client_bridges_id_seq OWNED BY public.core_app_client_bridges.id;


--
-- Name: enterprise_administration_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enterprise_administration_grants (
    id bigint NOT NULL,
    enterprise_id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: enterprise_administration_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enterprise_administration_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enterprise_administration_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enterprise_administration_grants_id_seq OWNED BY public.enterprise_administration_grants.id;


--
-- Name: enterprise_authority_cutovers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enterprise_authority_cutovers (
    id bigint NOT NULL,
    cutover_at timestamp(6) with time zone DEFAULT clock_timestamp() NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_enterprise_authority_cutovers_finite_time CHECK (isfinite(cutover_at)),
    CONSTRAINT chk_enterprise_authority_cutovers_singleton CHECK ((id = 1))
);


--
-- Name: enterprise_authority_cutovers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enterprise_authority_cutovers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enterprise_authority_cutovers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enterprise_authority_cutovers_id_seq OWNED BY public.enterprise_authority_cutovers.id;


--
-- Name: enterprise_delegation_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enterprise_delegation_grants (
    id bigint NOT NULL,
    enterprise_id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: enterprise_delegation_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enterprise_delegation_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enterprise_delegation_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enterprise_delegation_grants_id_seq OWNED BY public.enterprise_delegation_grants.id;


--
-- Name: enterprise_lifecycles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enterprise_lifecycles (
    id bigint NOT NULL,
    enterprise_id bigint NOT NULL,
    state character varying NOT NULL,
    state_changed_at timestamp(6) with time zone DEFAULT clock_timestamp() NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_enterprise_lifecycles_state CHECK (((state)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying, 'discarded'::character varying, 'deleted'::character varying, 'retained'::character varying])::text[])))
);


--
-- Name: enterprise_lifecycles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enterprise_lifecycles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enterprise_lifecycles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enterprise_lifecycles_id_seq OWNED BY public.enterprise_lifecycles.id;


--
-- Name: enterprise_ownership_transfer_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enterprise_ownership_transfer_requests (
    id bigint NOT NULL,
    enterprise_id bigint NOT NULL,
    source_client_id bigint CONSTRAINT enterprise_ownership_transfer_request_source_client_id_not_null NOT NULL,
    destination_client_id bigint CONSTRAINT enterprise_ownership_transfer_re_destination_client_id_not_null NOT NULL,
    public_id character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    expected_ownership_revision integer CONSTRAINT enterprise_ownership_transf_expected_ownership_revisio_not_null NOT NULL,
    requested_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    accepted_at timestamp(6) with time zone,
    rejected_at timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    invalidated_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_enterprise_transfer_requests_distinct_parties CHECK ((source_client_id <> destination_client_id)),
    CONSTRAINT chk_enterprise_transfer_requests_expiry_after_request CHECK ((requested_at < expires_at)),
    CONSTRAINT chk_enterprise_transfer_requests_revision_nonnegative CHECK ((expected_ownership_revision >= 0)),
    CONSTRAINT chk_enterprise_transfer_requests_status CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'accepted'::character varying, 'rejected'::character varying, 'cancelled'::character varying, 'expired'::character varying, 'invalidated'::character varying])::text[]))),
    CONSTRAINT enterprise_ownership_transfer_requests_public_id_max_length CHECK ((char_length((public_id)::text) <= 25))
);


--
-- Name: enterprise_ownership_transfer_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enterprise_ownership_transfer_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enterprise_ownership_transfer_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enterprise_ownership_transfer_requests_id_seq OWNED BY public.enterprise_ownership_transfer_requests.id;


--
-- Name: enterprise_ownerships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enterprise_ownerships (
    id bigint NOT NULL,
    enterprise_id bigint NOT NULL,
    client_id bigint NOT NULL,
    ownership_revision integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_enterprise_ownerships_revision_nonnegative CHECK ((ownership_revision >= 0))
);


--
-- Name: enterprise_ownerships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enterprise_ownerships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enterprise_ownerships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enterprise_ownerships_id_seq OWNED BY public.enterprise_ownerships.id;


--
-- Name: enterprise_unit_closures; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enterprise_unit_closures (
    id bigint NOT NULL,
    ancestor_id bigint NOT NULL,
    descendant_id bigint NOT NULL,
    depth integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_enterprise_unit_closures_depth_matches_self CHECK ((((ancestor_id = descendant_id) AND (depth = 0)) OR ((ancestor_id <> descendant_id) AND (depth > 0)))),
    CONSTRAINT chk_enterprise_unit_closures_depth_nonnegative CHECK ((depth >= 0))
);


--
-- Name: enterprise_unit_closures_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enterprise_unit_closures_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enterprise_unit_closures_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enterprise_unit_closures_id_seq OWNED BY public.enterprise_unit_closures.id;


--
-- Name: enterprise_units; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enterprise_units (
    id bigint NOT NULL,
    enterprise_id bigint NOT NULL,
    parent_id bigint,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT enterprise_units_public_id_max_length CHECK ((char_length((public_id)::text) <= 25))
);


--
-- Name: enterprise_units_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enterprise_units_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enterprise_units_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enterprise_units_id_seq OWNED BY public.enterprise_units.id;


--
-- Name: enterprise_view_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enterprise_view_grants (
    id bigint NOT NULL,
    enterprise_id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: enterprise_view_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enterprise_view_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enterprise_view_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enterprise_view_grants_id_seq OWNED BY public.enterprise_view_grants.id;


--
-- Name: enterprises; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enterprises (
    id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    title character varying NOT NULL,
    CONSTRAINT enterprises_public_id_max_length CHECK ((char_length((public_id)::text) <= 25))
);


--
-- Name: enterprises_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enterprises_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enterprises_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enterprises_id_seq OWNED BY public.enterprises.id;


--
-- Name: identity_authentication_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.identity_authentication_events (
    id bigint NOT NULL,
    event_id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_ref character varying NOT NULL,
    realm character varying(3) NOT NULL,
    cutoff_epoch bigint NOT NULL,
    reason character varying(64) NOT NULL,
    scope character varying(64) NOT NULL,
    committed_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_app_identity_authentication_events_epoch_nonnegative CHECK ((cutoff_epoch >= 0)),
    CONSTRAINT chk_app_identity_authentication_events_realm CHECK (((realm)::text = 'app'::text))
);


--
-- Name: identity_authentication_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.identity_authentication_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: identity_authentication_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.identity_authentication_events_id_seq OWNED BY public.identity_authentication_events.id;


--
-- Name: legacy_replaced_client_banners; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_replaced_client_banners (
    id bigint CONSTRAINT client_banners_id_not_null NOT NULL,
    client_id bigint CONSTRAINT client_banners_client_id_not_null NOT NULL,
    title character varying DEFAULT ''::character varying CONSTRAINT client_banners_title_not_null NOT NULL,
    body text CONSTRAINT client_banners_body_not_null NOT NULL,
    published boolean DEFAULT false CONSTRAINT client_banners_published_not_null NOT NULL,
    starts_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT client_banners_starts_at_not_null NOT NULL,
    ends_at timestamp(6) with time zone DEFAULT '9999-12-31 23:59:59+00'::timestamp with time zone CONSTRAINT client_banners_ends_at_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT client_banners_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT client_banners_updated_at_not_null NOT NULL,
    CONSTRAINT client_banners_ends_at_after_starts_at CHECK ((ends_at > starts_at))
);


--
-- Name: legacy_replaced_client_banners_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.legacy_replaced_client_banners_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: legacy_replaced_client_banners_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.legacy_replaced_client_banners_id_seq OWNED BY public.legacy_replaced_client_banners.id;


--
-- Name: legacy_replaced_client_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_replaced_client_statuses (
    id bigint CONSTRAINT client_statuses_id_not_null NOT NULL
);


--
-- Name: legacy_replaced_client_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.legacy_replaced_client_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: legacy_replaced_client_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.legacy_replaced_client_statuses_id_seq OWNED BY public.legacy_replaced_client_statuses.id;


--
-- Name: legacy_replaced_clients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_replaced_clients (
    id bigint CONSTRAINT clients_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT clients_created_at_not_null NOT NULL,
    division_id bigint,
    lock_version integer DEFAULT 0 CONSTRAINT clients_lock_version_not_null NOT NULL,
    moniker character varying,
    public_id character varying CONSTRAINT clients_public_id_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT clients_updated_at_not_null NOT NULL,
    user_id bigint,
    client_status_id bigint DEFAULT 0 CONSTRAINT clients_client_status_id_not_null NOT NULL,
    status_id bigint DEFAULT 0 CONSTRAINT clients_status_id_not_null NOT NULL
);


--
-- Name: legacy_replaced_clients_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.legacy_replaced_clients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: legacy_replaced_clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.legacy_replaced_clients_id_seq OWNED BY public.legacy_replaced_clients.id;


--
-- Name: member_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.member_statuses (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: member_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.member_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: member_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.member_statuses_id_seq OWNED BY public.member_statuses.id;


--
-- Name: members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.members (
    id bigint NOT NULL,
    public_id character varying NOT NULL,
    moniker character varying,
    user_id bigint,
    division_id bigint,
    status_id bigint DEFAULT 5 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT members_shreddable_at_not_null NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone CONSTRAINT members_discarded_at_not_null NOT NULL,
    CONSTRAINT members_public_id_max_length CHECK ((char_length((public_id)::text) <= 25))
);


--
-- Name: members_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.members_id_seq OWNED BY public.members.id;


--
-- Name: persona_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.persona_assignments (
    id bigint NOT NULL,
    public_id character varying NOT NULL,
    persona_id bigint NOT NULL,
    client_identity_id bigint NOT NULL,
    assigned_at timestamp(6) with time zone NOT NULL,
    revoked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT persona_assignments_public_id_max_length CHECK ((char_length((public_id)::text) <= 25))
);


--
-- Name: persona_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.persona_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: persona_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.persona_assignments_id_seq OWNED BY public.persona_assignments.id;


--
-- Name: persona_membership_kinds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.persona_membership_kinds (
    id bigint NOT NULL
);


--
-- Name: persona_membership_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.persona_membership_kinds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: persona_membership_kinds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.persona_membership_kinds_id_seq OWNED BY public.persona_membership_kinds.id;


--
-- Name: persona_membership_revoke_reasons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.persona_membership_revoke_reasons (
    id bigint NOT NULL
);


--
-- Name: persona_membership_revoke_reasons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.persona_membership_revoke_reasons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: persona_membership_revoke_reasons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.persona_membership_revoke_reasons_id_seq OWNED BY public.persona_membership_revoke_reasons.id;


--
-- Name: persona_membership_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.persona_membership_states (
    id bigint NOT NULL
);


--
-- Name: persona_membership_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.persona_membership_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: persona_membership_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.persona_membership_states_id_seq OWNED BY public.persona_membership_states.id;


--
-- Name: persona_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.persona_memberships (
    id bigint NOT NULL,
    persona_id bigint NOT NULL,
    enterprise_id bigint NOT NULL,
    enterprise_unit_id bigint NOT NULL,
    membership_kind_id bigint DEFAULT 0 NOT NULL,
    membership_state_id bigint DEFAULT 0 NOT NULL,
    "primary" boolean DEFAULT false NOT NULL,
    starts_at timestamp(6) with time zone,
    ends_at timestamp(6) with time zone,
    granted_by_persona_id bigint,
    approved_by_persona_id bigint,
    revoked_by_persona_id bigint,
    revoked_at timestamp(6) with time zone,
    revoke_reason_id bigint,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: persona_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.persona_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: persona_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.persona_memberships_id_seq OWNED BY public.persona_memberships.id;


--
-- Name: personas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.personas (
    id bigint NOT NULL,
    client_identity_id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    moniker character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    title character varying NOT NULL,
    CONSTRAINT personas_public_id_max_length CHECK ((char_length((public_id)::text) <= 25))
);


--
-- Name: personas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.personas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: personas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.personas_id_seq OWNED BY public.personas.id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    key character varying DEFAULT ''::character varying NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    organization_id bigint NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: user_client_deletions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_client_deletions (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: user_client_deletions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_client_deletions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_client_deletions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_client_deletions_id_seq OWNED BY public.user_client_deletions.id;


--
-- Name: user_client_discoveries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_client_discoveries (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: user_client_discoveries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_client_discoveries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_client_discoveries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_client_discoveries_id_seq OWNED BY public.user_client_discoveries.id;


--
-- Name: user_client_impersonations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_client_impersonations (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: user_client_impersonations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_client_impersonations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_client_impersonations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_client_impersonations_id_seq OWNED BY public.user_client_impersonations.id;


--
-- Name: user_client_observations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_client_observations (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: user_client_observations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_client_observations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_client_observations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_client_observations_id_seq OWNED BY public.user_client_observations.id;


--
-- Name: user_client_revocations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_client_revocations (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: user_client_revocations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_client_revocations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_client_revocations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_client_revocations_id_seq OWNED BY public.user_client_revocations.id;


--
-- Name: user_client_suspensions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_client_suspensions (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: user_client_suspensions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_client_suspensions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_client_suspensions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_client_suspensions_id_seq OWNED BY public.user_client_suspensions.id;


--
-- Name: user_clients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_clients (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: user_clients_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_clients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_clients_id_seq OWNED BY public.user_clients.id;


--
-- Name: accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts ALTER COLUMN id SET DEFAULT nextval('public.accounts_id_seq'::regclass);


--
-- Name: app_enforcement_appeals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_enforcement_appeals ALTER COLUMN id SET DEFAULT nextval('public.app_enforcement_appeals_id_seq'::regclass);


--
-- Name: app_enforcement_authentication_method_effects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_enforcement_authentication_method_effects ALTER COLUMN id SET DEFAULT nextval('public.app_enforcement_authentication_method_effects_id_seq'::regclass);


--
-- Name: app_enforcement_cases id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_enforcement_cases ALTER COLUMN id SET DEFAULT nextval('public.app_enforcement_cases_id_seq'::regclass);


--
-- Name: app_enforcement_identifier_effects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_enforcement_identifier_effects ALTER COLUMN id SET DEFAULT nextval('public.app_enforcement_identifier_effects_id_seq'::regclass);


--
-- Name: app_enforcement_principal_effects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_enforcement_principal_effects ALTER COLUMN id SET DEFAULT nextval('public.app_enforcement_principal_effects_id_seq'::regclass);


--
-- Name: app_enforcement_principal_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_enforcement_principal_links ALTER COLUMN id SET DEFAULT nextval('public.app_enforcement_principal_links_id_seq'::regclass);


--
-- Name: apple_auths id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apple_auths ALTER COLUMN id SET DEFAULT nextval('public.apple_auths_id_seq'::regclass);


--
-- Name: client_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_accounts ALTER COLUMN id SET DEFAULT nextval('public.client_accounts_id_seq'::regclass);


--
-- Name: client_apple_notification_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_apple_notification_events ALTER COLUMN id SET DEFAULT nextval('public.client_apple_notification_events_id_seq'::regclass);


--
-- Name: client_authority_locks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_authority_locks ALTER COLUMN id SET DEFAULT nextval('public.client_authority_locks_id_seq'::regclass);


--
-- Name: client_banners id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_banners ALTER COLUMN id SET DEFAULT nextval('public.client_banners_id_seq'::regclass);


--
-- Name: client_bulletins id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_bulletins ALTER COLUMN id SET DEFAULT nextval('public.client_bulletins_id_seq'::regclass);


--
-- Name: client_contact_audit_outboxes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_contact_audit_outboxes ALTER COLUMN id SET DEFAULT nextval('public.client_contact_audit_outboxes_id_seq'::regclass);


--
-- Name: client_email_histories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_email_histories ALTER COLUMN id SET DEFAULT nextval('public.client_email_histories_id_seq'::regclass);


--
-- Name: client_email_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_email_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_email_statuses_id_seq'::regclass);


--
-- Name: client_emails id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_emails ALTER COLUMN id SET DEFAULT nextval('public.client_emails_id_seq'::regclass);


--
-- Name: client_enforcement_recovery_ceremonies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_enforcement_recovery_ceremonies ALTER COLUMN id SET DEFAULT nextval('public.client_enforcement_recovery_ceremonies_id_seq'::regclass);


--
-- Name: client_external_identities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_external_identities ALTER COLUMN id SET DEFAULT nextval('public.client_external_identities_id_seq'::regclass);


--
-- Name: client_identifier_rotation_audits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_identifier_rotation_audits ALTER COLUMN id SET DEFAULT nextval('public.client_identifier_rotation_audits_id_seq'::regclass);


--
-- Name: client_identities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_identities ALTER COLUMN id SET DEFAULT nextval('public.client_identities_id_seq'::regclass);


--
-- Name: client_identity_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_identity_states ALTER COLUMN id SET DEFAULT nextval('public.client_identity_states_id_seq'::regclass);


--
-- Name: client_member_deletions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_deletions ALTER COLUMN id SET DEFAULT nextval('public.client_member_deletions_id_seq'::regclass);


--
-- Name: client_member_discoveries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_discoveries ALTER COLUMN id SET DEFAULT nextval('public.client_member_discoveries_id_seq'::regclass);


--
-- Name: client_member_impersonations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_impersonations ALTER COLUMN id SET DEFAULT nextval('public.client_member_impersonations_id_seq'::regclass);


--
-- Name: client_member_observations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_observations ALTER COLUMN id SET DEFAULT nextval('public.client_member_observations_id_seq'::regclass);


--
-- Name: client_member_revocations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_revocations ALTER COLUMN id SET DEFAULT nextval('public.client_member_revocations_id_seq'::regclass);


--
-- Name: client_member_suspensions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_suspensions ALTER COLUMN id SET DEFAULT nextval('public.client_member_suspensions_id_seq'::regclass);


--
-- Name: client_members id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_members ALTER COLUMN id SET DEFAULT nextval('public.client_members_id_seq'::regclass);


--
-- Name: client_memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_memberships ALTER COLUMN id SET DEFAULT nextval('public.client_memberships_id_seq'::regclass);


--
-- Name: client_mfa_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_mfa_levels ALTER COLUMN id SET DEFAULT nextval('public.client_mfa_levels_id_seq'::regclass);


--
-- Name: client_mfa_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_mfa_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_mfa_statuses_id_seq'::regclass);


--
-- Name: client_oidc_identity_bindings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_oidc_identity_bindings ALTER COLUMN id SET DEFAULT nextval('public.client_oidc_identity_bindings_id_seq'::regclass);


--
-- Name: client_passkey_audit_outboxes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_passkey_audit_outboxes ALTER COLUMN id SET DEFAULT nextval('public.client_passkey_audit_outboxes_id_seq'::regclass);


--
-- Name: client_passkey_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_passkey_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_passkey_statuses_id_seq'::regclass);


--
-- Name: client_passkeys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_passkeys ALTER COLUMN id SET DEFAULT nextval('public.client_passkeys_id_seq'::regclass);


--
-- Name: client_persona_administration_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_administration_grants ALTER COLUMN id SET DEFAULT nextval('public.client_persona_administration_grants_id_seq'::regclass);


--
-- Name: client_persona_authority_cutovers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_authority_cutovers ALTER COLUMN id SET DEFAULT nextval('public.client_persona_authority_cutovers_id_seq'::regclass);


--
-- Name: client_persona_delegation_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_delegation_grants ALTER COLUMN id SET DEFAULT nextval('public.client_persona_delegation_grants_id_seq'::regclass);


--
-- Name: client_persona_lifecycles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_lifecycles ALTER COLUMN id SET DEFAULT nextval('public.client_persona_lifecycles_id_seq'::regclass);


--
-- Name: client_persona_ownership_transfer_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_ownership_transfer_requests ALTER COLUMN id SET DEFAULT nextval('public.client_persona_ownership_transfer_requests_id_seq'::regclass);


--
-- Name: client_persona_ownerships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_ownerships ALTER COLUMN id SET DEFAULT nextval('public.client_persona_ownerships_id_seq'::regclass);


--
-- Name: client_persona_usage_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_usage_grants ALTER COLUMN id SET DEFAULT nextval('public.client_persona_usage_grants_id_seq'::regclass);


--
-- Name: client_persona_view_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_view_grants ALTER COLUMN id SET DEFAULT nextval('public.client_persona_view_grants_id_seq'::regclass);


--
-- Name: client_preference_adult_content_gate_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_adult_content_gate_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_adult_content_gate_options_id_seq'::regclass);


--
-- Name: client_preference_adult_content_gates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_adult_content_gates ALTER COLUMN id SET DEFAULT nextval('public.client_preference_adult_content_gates_id_seq'::regclass);


--
-- Name: client_preference_currencies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_currencies ALTER COLUMN id SET DEFAULT nextval('public.client_preference_currencies_id_seq'::regclass);


--
-- Name: client_preference_currency_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_currency_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_currency_options_id_seq'::regclass);


--
-- Name: client_preference_date_format_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_date_format_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_date_format_options_id_seq'::regclass);


--
-- Name: client_preference_date_formats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_date_formats ALTER COLUMN id SET DEFAULT nextval('public.client_preference_date_formats_id_seq'::regclass);


--
-- Name: client_preference_densities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_densities ALTER COLUMN id SET DEFAULT nextval('public.client_preference_densities_id_seq'::regclass);


--
-- Name: client_preference_density_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_density_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_density_options_id_seq'::regclass);


--
-- Name: client_preference_language_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_language_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_language_options_id_seq'::regclass);


--
-- Name: client_preference_languages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_languages ALTER COLUMN id SET DEFAULT nextval('public.client_preference_languages_id_seq'::regclass);


--
-- Name: client_preference_motion_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_motion_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_motion_options_id_seq'::regclass);


--
-- Name: client_preference_motions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_motions ALTER COLUMN id SET DEFAULT nextval('public.client_preference_motions_id_seq'::regclass);


--
-- Name: client_preference_page_size_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_page_size_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_page_size_options_id_seq'::regclass);


--
-- Name: client_preference_page_sizes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_page_sizes ALTER COLUMN id SET DEFAULT nextval('public.client_preference_page_sizes_id_seq'::regclass);


--
-- Name: client_preference_region_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_region_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_region_options_id_seq'::regclass);


--
-- Name: client_preference_regions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_regions ALTER COLUMN id SET DEFAULT nextval('public.client_preference_regions_id_seq'::regclass);


--
-- Name: client_preference_theme_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_theme_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_theme_options_id_seq'::regclass);


--
-- Name: client_preference_themes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_themes ALTER COLUMN id SET DEFAULT nextval('public.client_preference_themes_id_seq'::regclass);


--
-- Name: client_preference_time_format_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_time_format_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_time_format_options_id_seq'::regclass);


--
-- Name: client_preference_time_formats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_time_formats ALTER COLUMN id SET DEFAULT nextval('public.client_preference_time_formats_id_seq'::regclass);


--
-- Name: client_preference_timezone_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_timezone_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_timezone_options_id_seq'::regclass);


--
-- Name: client_preference_timezones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_timezones ALTER COLUMN id SET DEFAULT nextval('public.client_preference_timezones_id_seq'::regclass);


--
-- Name: client_preferences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preferences ALTER COLUMN id SET DEFAULT nextval('public.client_preferences_id_seq'::regclass);


--
-- Name: client_privacy_request_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_privacy_request_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_privacy_request_statuses_id_seq'::regclass);


--
-- Name: client_privacy_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_privacy_requests ALTER COLUMN id SET DEFAULT nextval('public.client_privacy_requests_id_seq'::regclass);


--
-- Name: client_processor_erasure_notification_attempts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_processor_erasure_notification_attempts ALTER COLUMN id SET DEFAULT nextval('public.client_processor_erasure_notification_attempts_id_seq'::regclass);


--
-- Name: client_processor_erasure_notification_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_processor_erasure_notification_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_processor_erasure_notification_statuses_id_seq'::regclass);


--
-- Name: client_processor_erasure_notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_processor_erasure_notifications ALTER COLUMN id SET DEFAULT nextval('public.client_processor_erasure_notifications_id_seq'::regclass);


--
-- Name: client_profile_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profile_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_profile_statuses_id_seq'::regclass);


--
-- Name: client_profiles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profiles ALTER COLUMN id SET DEFAULT nextval('public.client_profiles_id_seq'::regclass);


--
-- Name: client_retention_hold_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_retention_hold_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_retention_hold_statuses_id_seq'::regclass);


--
-- Name: client_retention_holds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_retention_holds ALTER COLUMN id SET DEFAULT nextval('public.client_retention_holds_id_seq'::regclass);


--
-- Name: client_secret_audit_outboxes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_audit_outboxes ALTER COLUMN id SET DEFAULT nextval('public.client_secret_audit_outboxes_id_seq'::regclass);


--
-- Name: client_secret_credentials id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_credentials ALTER COLUMN id SET DEFAULT nextval('public.client_secret_credentials_id_seq'::regclass);


--
-- Name: client_secret_issuances id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_issuances ALTER COLUMN id SET DEFAULT nextval('public.client_secret_issuances_id_seq'::regclass);


--
-- Name: client_social_audit_outboxes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_social_audit_outboxes ALTER COLUMN id SET DEFAULT nextval('public.client_social_audit_outboxes_id_seq'::regclass);


--
-- Name: client_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_statuses_id_seq'::regclass);


--
-- Name: client_telephone_histories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_telephone_histories ALTER COLUMN id SET DEFAULT nextval('public.client_telephone_histories_id_seq'::regclass);


--
-- Name: client_telephone_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_telephone_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_telephone_statuses_id_seq'::regclass);


--
-- Name: client_telephones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_telephones ALTER COLUMN id SET DEFAULT nextval('public.client_telephones_id_seq'::regclass);


--
-- Name: client_totp_credential_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_totp_credential_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_totp_credential_statuses_id_seq'::regclass);


--
-- Name: client_totp_credentials id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_totp_credentials ALTER COLUMN id SET DEFAULT nextval('public.client_totp_credentials_id_seq'::regclass);


--
-- Name: client_visibilities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_visibilities ALTER COLUMN id SET DEFAULT nextval('public.client_visibilities_id_seq'::regclass);


--
-- Name: client_withdrawal_ceremonies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_ceremonies ALTER COLUMN id SET DEFAULT nextval('public.client_withdrawal_ceremonies_id_seq'::regclass);


--
-- Name: client_withdrawal_flow_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flow_events ALTER COLUMN id SET DEFAULT nextval('public.client_withdrawal_flow_events_id_seq'::regclass);


--
-- Name: client_withdrawal_flow_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flow_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_withdrawal_flow_statuses_id_seq'::regclass);


--
-- Name: client_withdrawal_flows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flows ALTER COLUMN id SET DEFAULT nextval('public.client_withdrawal_flows_id_seq'::regclass);


--
-- Name: clients id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients ALTER COLUMN id SET DEFAULT nextval('public.clients_id_seq'::regclass);


--
-- Name: core_app_client_bridges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.core_app_client_bridges ALTER COLUMN id SET DEFAULT nextval('public.core_app_client_bridges_id_seq'::regclass);


--
-- Name: enterprise_administration_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_administration_grants ALTER COLUMN id SET DEFAULT nextval('public.enterprise_administration_grants_id_seq'::regclass);


--
-- Name: enterprise_authority_cutovers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_authority_cutovers ALTER COLUMN id SET DEFAULT nextval('public.enterprise_authority_cutovers_id_seq'::regclass);


--
-- Name: enterprise_delegation_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_delegation_grants ALTER COLUMN id SET DEFAULT nextval('public.enterprise_delegation_grants_id_seq'::regclass);


--
-- Name: enterprise_lifecycles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_lifecycles ALTER COLUMN id SET DEFAULT nextval('public.enterprise_lifecycles_id_seq'::regclass);


--
-- Name: enterprise_ownership_transfer_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_ownership_transfer_requests ALTER COLUMN id SET DEFAULT nextval('public.enterprise_ownership_transfer_requests_id_seq'::regclass);


--
-- Name: enterprise_ownerships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_ownerships ALTER COLUMN id SET DEFAULT nextval('public.enterprise_ownerships_id_seq'::regclass);


--
-- Name: enterprise_unit_closures id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_unit_closures ALTER COLUMN id SET DEFAULT nextval('public.enterprise_unit_closures_id_seq'::regclass);


--
-- Name: enterprise_units id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_units ALTER COLUMN id SET DEFAULT nextval('public.enterprise_units_id_seq'::regclass);


--
-- Name: enterprise_view_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_view_grants ALTER COLUMN id SET DEFAULT nextval('public.enterprise_view_grants_id_seq'::regclass);


--
-- Name: enterprises id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprises ALTER COLUMN id SET DEFAULT nextval('public.enterprises_id_seq'::regclass);


--
-- Name: identity_authentication_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_authentication_events ALTER COLUMN id SET DEFAULT nextval('public.identity_authentication_events_id_seq'::regclass);


--
-- Name: legacy_replaced_client_banners id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_replaced_client_banners ALTER COLUMN id SET DEFAULT nextval('public.legacy_replaced_client_banners_id_seq'::regclass);


--
-- Name: legacy_replaced_client_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_replaced_client_statuses ALTER COLUMN id SET DEFAULT nextval('public.legacy_replaced_client_statuses_id_seq'::regclass);


--
-- Name: legacy_replaced_clients id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_replaced_clients ALTER COLUMN id SET DEFAULT nextval('public.legacy_replaced_clients_id_seq'::regclass);


--
-- Name: member_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_statuses ALTER COLUMN id SET DEFAULT nextval('public.member_statuses_id_seq'::regclass);


--
-- Name: members id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members ALTER COLUMN id SET DEFAULT nextval('public.members_id_seq'::regclass);


--
-- Name: persona_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_assignments ALTER COLUMN id SET DEFAULT nextval('public.persona_assignments_id_seq'::regclass);


--
-- Name: persona_membership_kinds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_membership_kinds ALTER COLUMN id SET DEFAULT nextval('public.persona_membership_kinds_id_seq'::regclass);


--
-- Name: persona_membership_revoke_reasons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_membership_revoke_reasons ALTER COLUMN id SET DEFAULT nextval('public.persona_membership_revoke_reasons_id_seq'::regclass);


--
-- Name: persona_membership_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_membership_states ALTER COLUMN id SET DEFAULT nextval('public.persona_membership_states_id_seq'::regclass);


--
-- Name: persona_memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships ALTER COLUMN id SET DEFAULT nextval('public.persona_memberships_id_seq'::regclass);


--
-- Name: personas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personas ALTER COLUMN id SET DEFAULT nextval('public.personas_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- Name: user_client_deletions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_deletions ALTER COLUMN id SET DEFAULT nextval('public.user_client_deletions_id_seq'::regclass);


--
-- Name: user_client_discoveries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_discoveries ALTER COLUMN id SET DEFAULT nextval('public.user_client_discoveries_id_seq'::regclass);


--
-- Name: user_client_impersonations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_impersonations ALTER COLUMN id SET DEFAULT nextval('public.user_client_impersonations_id_seq'::regclass);


--
-- Name: user_client_observations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_observations ALTER COLUMN id SET DEFAULT nextval('public.user_client_observations_id_seq'::regclass);


--
-- Name: user_client_revocations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_revocations ALTER COLUMN id SET DEFAULT nextval('public.user_client_revocations_id_seq'::regclass);


--
-- Name: user_client_suspensions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_suspensions ALTER COLUMN id SET DEFAULT nextval('public.user_client_suspensions_id_seq'::regclass);


--
-- Name: user_clients id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_clients ALTER COLUMN id SET DEFAULT nextval('public.user_clients_id_seq'::regclass);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: app_enforcement_appeals app_enforcement_appeals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_enforcement_appeals
    ADD CONSTRAINT app_enforcement_appeals_pkey PRIMARY KEY (id);


--
-- Name: app_enforcement_authentication_method_effects app_enforcement_authentication_method_effects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_enforcement_authentication_method_effects
    ADD CONSTRAINT app_enforcement_authentication_method_effects_pkey PRIMARY KEY (id);


--
-- Name: app_enforcement_cases app_enforcement_cases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_enforcement_cases
    ADD CONSTRAINT app_enforcement_cases_pkey PRIMARY KEY (id);


--
-- Name: app_enforcement_identifier_effects app_enforcement_identifier_effects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_enforcement_identifier_effects
    ADD CONSTRAINT app_enforcement_identifier_effects_pkey PRIMARY KEY (id);


--
-- Name: app_enforcement_principal_effects app_enforcement_principal_effects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_enforcement_principal_effects
    ADD CONSTRAINT app_enforcement_principal_effects_pkey PRIMARY KEY (id);


--
-- Name: app_enforcement_principal_links app_enforcement_principal_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_enforcement_principal_links
    ADD CONSTRAINT app_enforcement_principal_links_pkey PRIMARY KEY (id);


--
-- Name: apple_auths apple_auths_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apple_auths
    ADD CONSTRAINT apple_auths_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: client_emails chk_client_emails_retention_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.client_emails
    ADD CONSTRAINT chk_client_emails_retention_order CHECK ((discard_at <= purge_eligible_at)) NOT VALID;


--
-- Name: client_passkeys chk_client_passkeys_retention_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.client_passkeys
    ADD CONSTRAINT chk_client_passkeys_retention_order CHECK ((discard_at <= purge_eligible_at)) NOT VALID;


--
-- Name: client_telephones chk_client_telephones_retention_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.client_telephones
    ADD CONSTRAINT chk_client_telephones_retention_order CHECK ((discard_at <= purge_eligible_at)) NOT VALID;


--
-- Name: clients chk_clients_mfa_requirement_consistency; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.clients
    ADD CONSTRAINT chk_clients_mfa_requirement_consistency CHECK ((((mfa_level_enabled = false) AND (mfa_level_id = 0)) OR ((mfa_level_enabled = true) AND (mfa_level_id <> 0)))) NOT VALID;


--
-- Name: clients chk_clients_terminated_requires_withdrawn; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.clients
    ADD CONSTRAINT chk_clients_terminated_requires_withdrawn CHECK (((terminated_at IS NULL) OR ((withdrawn_at IS NOT NULL) AND (withdrawn_at < 'infinity'::timestamp without time zone)))) NOT VALID;


--
-- Name: clients chk_clients_withdrawal_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.clients
    ADD CONSTRAINT chk_clients_withdrawal_order CHECK (((withdrawal_started_at IS NULL) OR (withdrawn_at IS NULL) OR (withdrawn_at = 'infinity'::timestamp without time zone) OR (withdrawal_started_at <= withdrawn_at))) NOT VALID;


--
-- Name: client_accounts client_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_accounts
    ADD CONSTRAINT client_accounts_pkey PRIMARY KEY (id);


--
-- Name: client_apple_notification_events client_apple_notification_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_apple_notification_events
    ADD CONSTRAINT client_apple_notification_events_pkey PRIMARY KEY (id);


--
-- Name: client_authority_locks client_authority_locks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_authority_locks
    ADD CONSTRAINT client_authority_locks_pkey PRIMARY KEY (id);


--
-- Name: client_banners client_banners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_banners
    ADD CONSTRAINT client_banners_pkey PRIMARY KEY (id);


--
-- Name: client_bulletins client_bulletins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_bulletins
    ADD CONSTRAINT client_bulletins_pkey PRIMARY KEY (id);


--
-- Name: client_contact_audit_outboxes client_contact_audit_outboxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_contact_audit_outboxes
    ADD CONSTRAINT client_contact_audit_outboxes_pkey PRIMARY KEY (id);


--
-- Name: client_email_histories client_email_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_email_histories
    ADD CONSTRAINT client_email_histories_pkey PRIMARY KEY (id);


--
-- Name: client_email_statuses client_email_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_email_statuses
    ADD CONSTRAINT client_email_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_emails client_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_emails
    ADD CONSTRAINT client_emails_pkey PRIMARY KEY (id);


--
-- Name: client_enforcement_recovery_ceremonies client_enforcement_recovery_ceremonies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_enforcement_recovery_ceremonies
    ADD CONSTRAINT client_enforcement_recovery_ceremonies_pkey PRIMARY KEY (id);


--
-- Name: client_external_identities client_external_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_external_identities
    ADD CONSTRAINT client_external_identities_pkey PRIMARY KEY (id);


--
-- Name: client_identifier_rotation_audits client_identifier_rotation_audits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_identifier_rotation_audits
    ADD CONSTRAINT client_identifier_rotation_audits_pkey PRIMARY KEY (id);


--
-- Name: client_identities client_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_identities
    ADD CONSTRAINT client_identities_pkey PRIMARY KEY (id);


--
-- Name: client_identity_states client_identity_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_identity_states
    ADD CONSTRAINT client_identity_states_pkey PRIMARY KEY (id);


--
-- Name: client_member_deletions client_member_deletions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_deletions
    ADD CONSTRAINT client_member_deletions_pkey PRIMARY KEY (id);


--
-- Name: client_member_discoveries client_member_discoveries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_discoveries
    ADD CONSTRAINT client_member_discoveries_pkey PRIMARY KEY (id);


--
-- Name: client_member_impersonations client_member_impersonations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_impersonations
    ADD CONSTRAINT client_member_impersonations_pkey PRIMARY KEY (id);


--
-- Name: client_member_observations client_member_observations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_observations
    ADD CONSTRAINT client_member_observations_pkey PRIMARY KEY (id);


--
-- Name: client_member_revocations client_member_revocations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_revocations
    ADD CONSTRAINT client_member_revocations_pkey PRIMARY KEY (id);


--
-- Name: client_member_suspensions client_member_suspensions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_suspensions
    ADD CONSTRAINT client_member_suspensions_pkey PRIMARY KEY (id);


--
-- Name: client_members client_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_members
    ADD CONSTRAINT client_members_pkey PRIMARY KEY (id);


--
-- Name: client_memberships client_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_memberships
    ADD CONSTRAINT client_memberships_pkey PRIMARY KEY (id);


--
-- Name: client_mfa_levels client_mfa_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_mfa_levels
    ADD CONSTRAINT client_mfa_levels_pkey PRIMARY KEY (id);


--
-- Name: client_mfa_statuses client_mfa_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_mfa_statuses
    ADD CONSTRAINT client_mfa_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_oidc_identity_bindings client_oidc_identity_bindings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_oidc_identity_bindings
    ADD CONSTRAINT client_oidc_identity_bindings_pkey PRIMARY KEY (id);


--
-- Name: client_passkey_audit_outboxes client_passkey_audit_outboxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_passkey_audit_outboxes
    ADD CONSTRAINT client_passkey_audit_outboxes_pkey PRIMARY KEY (id);


--
-- Name: client_passkey_statuses client_passkey_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_passkey_statuses
    ADD CONSTRAINT client_passkey_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_passkeys client_passkeys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_passkeys
    ADD CONSTRAINT client_passkeys_pkey PRIMARY KEY (id);


--
-- Name: client_persona_administration_grants client_persona_administration_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_administration_grants
    ADD CONSTRAINT client_persona_administration_grants_pkey PRIMARY KEY (id);


--
-- Name: client_persona_authority_cutovers client_persona_authority_cutovers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_authority_cutovers
    ADD CONSTRAINT client_persona_authority_cutovers_pkey PRIMARY KEY (id);


--
-- Name: client_persona_delegation_grants client_persona_delegation_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_delegation_grants
    ADD CONSTRAINT client_persona_delegation_grants_pkey PRIMARY KEY (id);


--
-- Name: client_persona_lifecycles client_persona_lifecycles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_lifecycles
    ADD CONSTRAINT client_persona_lifecycles_pkey PRIMARY KEY (id);


--
-- Name: client_persona_ownership_transfer_requests client_persona_ownership_transfer_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_ownership_transfer_requests
    ADD CONSTRAINT client_persona_ownership_transfer_requests_pkey PRIMARY KEY (id);


--
-- Name: client_persona_ownerships client_persona_ownerships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_ownerships
    ADD CONSTRAINT client_persona_ownerships_pkey PRIMARY KEY (id);


--
-- Name: client_persona_usage_grants client_persona_usage_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_usage_grants
    ADD CONSTRAINT client_persona_usage_grants_pkey PRIMARY KEY (id);


--
-- Name: client_persona_view_grants client_persona_view_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_view_grants
    ADD CONSTRAINT client_persona_view_grants_pkey PRIMARY KEY (id);


--
-- Name: client_preference_adult_content_gate_options client_preference_adult_content_gate_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_adult_content_gate_options
    ADD CONSTRAINT client_preference_adult_content_gate_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_adult_content_gates client_preference_adult_content_gates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_adult_content_gates
    ADD CONSTRAINT client_preference_adult_content_gates_pkey PRIMARY KEY (id);


--
-- Name: client_preference_currencies client_preference_currencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_currencies
    ADD CONSTRAINT client_preference_currencies_pkey PRIMARY KEY (id);


--
-- Name: client_preference_currency_options client_preference_currency_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_currency_options
    ADD CONSTRAINT client_preference_currency_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_date_format_options client_preference_date_format_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_date_format_options
    ADD CONSTRAINT client_preference_date_format_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_date_formats client_preference_date_formats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_date_formats
    ADD CONSTRAINT client_preference_date_formats_pkey PRIMARY KEY (id);


--
-- Name: client_preference_densities client_preference_densities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_densities
    ADD CONSTRAINT client_preference_densities_pkey PRIMARY KEY (id);


--
-- Name: client_preference_density_options client_preference_density_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_density_options
    ADD CONSTRAINT client_preference_density_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_language_options client_preference_language_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_language_options
    ADD CONSTRAINT client_preference_language_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_languages client_preference_languages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_languages
    ADD CONSTRAINT client_preference_languages_pkey PRIMARY KEY (id);


--
-- Name: client_preference_motion_options client_preference_motion_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_motion_options
    ADD CONSTRAINT client_preference_motion_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_motions client_preference_motions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_motions
    ADD CONSTRAINT client_preference_motions_pkey PRIMARY KEY (id);


--
-- Name: client_preference_page_size_options client_preference_page_size_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_page_size_options
    ADD CONSTRAINT client_preference_page_size_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_page_sizes client_preference_page_sizes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_page_sizes
    ADD CONSTRAINT client_preference_page_sizes_pkey PRIMARY KEY (id);


--
-- Name: client_preference_region_options client_preference_region_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_region_options
    ADD CONSTRAINT client_preference_region_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_regions client_preference_regions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_regions
    ADD CONSTRAINT client_preference_regions_pkey PRIMARY KEY (id);


--
-- Name: client_preference_theme_options client_preference_theme_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_theme_options
    ADD CONSTRAINT client_preference_theme_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_themes client_preference_themes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_themes
    ADD CONSTRAINT client_preference_themes_pkey PRIMARY KEY (id);


--
-- Name: client_preference_time_format_options client_preference_time_format_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_time_format_options
    ADD CONSTRAINT client_preference_time_format_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_time_formats client_preference_time_formats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_time_formats
    ADD CONSTRAINT client_preference_time_formats_pkey PRIMARY KEY (id);


--
-- Name: client_preference_timezone_options client_preference_timezone_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_timezone_options
    ADD CONSTRAINT client_preference_timezone_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_timezones client_preference_timezones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_timezones
    ADD CONSTRAINT client_preference_timezones_pkey PRIMARY KEY (id);


--
-- Name: client_preferences client_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preferences
    ADD CONSTRAINT client_preferences_pkey PRIMARY KEY (id);


--
-- Name: client_privacy_request_statuses client_privacy_request_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_privacy_request_statuses
    ADD CONSTRAINT client_privacy_request_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_privacy_requests client_privacy_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_privacy_requests
    ADD CONSTRAINT client_privacy_requests_pkey PRIMARY KEY (id);


--
-- Name: client_processor_erasure_notification_attempts client_processor_erasure_notification_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_processor_erasure_notification_attempts
    ADD CONSTRAINT client_processor_erasure_notification_attempts_pkey PRIMARY KEY (id);


--
-- Name: client_processor_erasure_notification_statuses client_processor_erasure_notification_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_processor_erasure_notification_statuses
    ADD CONSTRAINT client_processor_erasure_notification_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_processor_erasure_notifications client_processor_erasure_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_processor_erasure_notifications
    ADD CONSTRAINT client_processor_erasure_notifications_pkey PRIMARY KEY (id);


--
-- Name: client_profile_statuses client_profile_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profile_statuses
    ADD CONSTRAINT client_profile_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_profiles client_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profiles
    ADD CONSTRAINT client_profiles_pkey PRIMARY KEY (id);


--
-- Name: client_retention_hold_statuses client_retention_hold_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_retention_hold_statuses
    ADD CONSTRAINT client_retention_hold_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_retention_holds client_retention_holds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_retention_holds
    ADD CONSTRAINT client_retention_holds_pkey PRIMARY KEY (id);


--
-- Name: client_secret_audit_outboxes client_secret_audit_outboxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_audit_outboxes
    ADD CONSTRAINT client_secret_audit_outboxes_pkey PRIMARY KEY (id);


--
-- Name: client_secret_credentials client_secret_credentials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_credentials
    ADD CONSTRAINT client_secret_credentials_pkey PRIMARY KEY (id);


--
-- Name: client_secret_issuances client_secret_issuances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_issuances
    ADD CONSTRAINT client_secret_issuances_pkey PRIMARY KEY (id);


--
-- Name: client_social_audit_outboxes client_social_audit_outboxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_social_audit_outboxes
    ADD CONSTRAINT client_social_audit_outboxes_pkey PRIMARY KEY (id);


--
-- Name: client_statuses client_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_statuses
    ADD CONSTRAINT client_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_telephone_histories client_telephone_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_telephone_histories
    ADD CONSTRAINT client_telephone_histories_pkey PRIMARY KEY (id);


--
-- Name: client_telephone_statuses client_telephone_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_telephone_statuses
    ADD CONSTRAINT client_telephone_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_telephones client_telephones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_telephones
    ADD CONSTRAINT client_telephones_pkey PRIMARY KEY (id);


--
-- Name: client_totp_credential_statuses client_totp_credential_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_totp_credential_statuses
    ADD CONSTRAINT client_totp_credential_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_totp_credentials client_totp_credentials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_totp_credentials
    ADD CONSTRAINT client_totp_credentials_pkey PRIMARY KEY (id);


--
-- Name: client_visibilities client_visibilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_visibilities
    ADD CONSTRAINT client_visibilities_pkey PRIMARY KEY (id);


--
-- Name: client_withdrawal_ceremonies client_withdrawal_ceremonies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_ceremonies
    ADD CONSTRAINT client_withdrawal_ceremonies_pkey PRIMARY KEY (id);


--
-- Name: client_withdrawal_flow_events client_withdrawal_flow_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flow_events
    ADD CONSTRAINT client_withdrawal_flow_events_pkey PRIMARY KEY (id);


--
-- Name: client_withdrawal_flow_statuses client_withdrawal_flow_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flow_statuses
    ADD CONSTRAINT client_withdrawal_flow_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_withdrawal_flows client_withdrawal_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flows
    ADD CONSTRAINT client_withdrawal_flows_pkey PRIMARY KEY (id);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- Name: core_app_client_bridges core_app_client_bridges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.core_app_client_bridges
    ADD CONSTRAINT core_app_client_bridges_pkey PRIMARY KEY (id);


--
-- Name: enterprise_administration_grants enterprise_administration_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_administration_grants
    ADD CONSTRAINT enterprise_administration_grants_pkey PRIMARY KEY (id);


--
-- Name: enterprise_authority_cutovers enterprise_authority_cutovers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_authority_cutovers
    ADD CONSTRAINT enterprise_authority_cutovers_pkey PRIMARY KEY (id);


--
-- Name: enterprise_delegation_grants enterprise_delegation_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_delegation_grants
    ADD CONSTRAINT enterprise_delegation_grants_pkey PRIMARY KEY (id);


--
-- Name: enterprise_lifecycles enterprise_lifecycles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_lifecycles
    ADD CONSTRAINT enterprise_lifecycles_pkey PRIMARY KEY (id);


--
-- Name: enterprise_ownership_transfer_requests enterprise_ownership_transfer_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_ownership_transfer_requests
    ADD CONSTRAINT enterprise_ownership_transfer_requests_pkey PRIMARY KEY (id);


--
-- Name: enterprise_ownerships enterprise_ownerships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_ownerships
    ADD CONSTRAINT enterprise_ownerships_pkey PRIMARY KEY (id);


--
-- Name: enterprise_unit_closures enterprise_unit_closures_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_unit_closures
    ADD CONSTRAINT enterprise_unit_closures_pkey PRIMARY KEY (id);


--
-- Name: enterprise_units enterprise_units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_units
    ADD CONSTRAINT enterprise_units_pkey PRIMARY KEY (id);


--
-- Name: enterprise_view_grants enterprise_view_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_view_grants
    ADD CONSTRAINT enterprise_view_grants_pkey PRIMARY KEY (id);


--
-- Name: enterprises enterprises_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprises
    ADD CONSTRAINT enterprises_pkey PRIMARY KEY (id);


--
-- Name: identity_authentication_events identity_authentication_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_authentication_events
    ADD CONSTRAINT identity_authentication_events_pkey PRIMARY KEY (id);


--
-- Name: legacy_replaced_client_banners legacy_replaced_client_banners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_replaced_client_banners
    ADD CONSTRAINT legacy_replaced_client_banners_pkey PRIMARY KEY (id);


--
-- Name: legacy_replaced_client_statuses legacy_replaced_client_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_replaced_client_statuses
    ADD CONSTRAINT legacy_replaced_client_statuses_pkey PRIMARY KEY (id);


--
-- Name: legacy_replaced_clients legacy_replaced_clients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_replaced_clients
    ADD CONSTRAINT legacy_replaced_clients_pkey PRIMARY KEY (id);


--
-- Name: member_statuses member_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_statuses
    ADD CONSTRAINT member_statuses_pkey PRIMARY KEY (id);


--
-- Name: members members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members
    ADD CONSTRAINT members_pkey PRIMARY KEY (id);


--
-- Name: persona_assignments persona_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_assignments
    ADD CONSTRAINT persona_assignments_pkey PRIMARY KEY (id);


--
-- Name: persona_membership_kinds persona_membership_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_membership_kinds
    ADD CONSTRAINT persona_membership_kinds_pkey PRIMARY KEY (id);


--
-- Name: persona_membership_revoke_reasons persona_membership_revoke_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_membership_revoke_reasons
    ADD CONSTRAINT persona_membership_revoke_reasons_pkey PRIMARY KEY (id);


--
-- Name: persona_membership_states persona_membership_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_membership_states
    ADD CONSTRAINT persona_membership_states_pkey PRIMARY KEY (id);


--
-- Name: persona_memberships persona_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT persona_memberships_pkey PRIMARY KEY (id);


--
-- Name: personas personas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personas
    ADD CONSTRAINT personas_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: user_client_deletions user_client_deletions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_deletions
    ADD CONSTRAINT user_client_deletions_pkey PRIMARY KEY (id);


--
-- Name: user_client_discoveries user_client_discoveries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_discoveries
    ADD CONSTRAINT user_client_discoveries_pkey PRIMARY KEY (id);


--
-- Name: user_client_impersonations user_client_impersonations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_impersonations
    ADD CONSTRAINT user_client_impersonations_pkey PRIMARY KEY (id);


--
-- Name: user_client_observations user_client_observations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_observations
    ADD CONSTRAINT user_client_observations_pkey PRIMARY KEY (id);


--
-- Name: user_client_revocations user_client_revocations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_revocations
    ADD CONSTRAINT user_client_revocations_pkey PRIMARY KEY (id);


--
-- Name: user_client_suspensions user_client_suspensions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_suspensions
    ADD CONSTRAINT user_client_suspensions_pkey PRIMARY KEY (id);


--
-- Name: user_clients user_clients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_clients
    ADD CONSTRAINT user_clients_pkey PRIMARY KEY (id);


--
-- Name: client_contact_audit_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX client_contact_audit_pending ON public.client_contact_audit_outboxes USING btree (id) WHERE (acknowledged_at IS NULL);


--
-- Name: client_emails_effective_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX client_emails_effective_digest ON public.client_emails USING btree (address_digest) WHERE ((binding_finalized_at IS NOT NULL) AND (binding_released_at IS NULL));


--
-- Name: client_emails_effective_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX client_emails_effective_owner ON public.client_emails USING btree (user_id) WHERE ((binding_finalized_at IS NOT NULL) AND (binding_released_at IS NULL));


--
-- Name: client_passkey_audit_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX client_passkey_audit_pending ON public.client_passkey_audit_outboxes USING btree (id) WHERE (acknowledged_at IS NULL);


--
-- Name: client_rotation_operation; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX client_rotation_operation ON public.client_identifier_rotation_audits USING btree (operation_ref, channel, record_id);


--
-- Name: client_social_audit_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX client_social_audit_pending ON public.client_social_audit_outboxes USING btree (id) WHERE (acknowledged_at IS NULL);


--
-- Name: client_social_audit_release_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX client_social_audit_release_lookup ON public.client_social_audit_outboxes USING btree (provider, provider_subject_digest, released_at) WHERE ((event_name)::text = 'unlinked'::text);


--
-- Name: client_telephones_effective_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX client_telephones_effective_digest ON public.client_telephones USING btree (number_digest) WHERE ((binding_finalized_at IS NOT NULL) AND (binding_released_at IS NULL));


--
-- Name: client_telephones_effective_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX client_telephones_effective_owner ON public.client_telephones USING btree (user_id) WHERE ((binding_finalized_at IS NOT NULL) AND (binding_released_at IS NULL));


--
-- Name: idx_app_enforcement_cases_state_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_app_enforcement_cases_state_expires_at ON public.app_enforcement_cases USING btree (state, expires_at);


--
-- Name: idx_app_enforcement_identifier_effects_one_open; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_app_enforcement_identifier_effects_one_open ON public.app_enforcement_identifier_effects USING btree (identifier_kind, lookup_digest) WHERE (ended_at IS NULL);


--
-- Name: idx_app_enforcement_method_effects_one_open_per_method; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_app_enforcement_method_effects_one_open_per_method ON public.app_enforcement_authentication_method_effects USING btree (principal_public_id, authentication_method) WHERE (ended_at IS NULL);


--
-- Name: idx_app_enforcement_principal_effects_principal_open; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_app_enforcement_principal_effects_principal_open ON public.app_enforcement_principal_effects USING btree (principal_public_id, ended_at);


--
-- Name: idx_app_identity_authentication_events_actor_epoch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_app_identity_authentication_events_actor_epoch ON public.identity_authentication_events USING btree (actor_ref, cutoff_epoch);


--
-- Name: idx_app_identity_authentication_events_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_app_identity_authentication_events_event_id ON public.identity_authentication_events USING btree (event_id);


--
-- Name: idx_client_apple_notification_events_retry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_apple_notification_events_retry ON public.client_apple_notification_events USING btree (status, next_retry_at);


--
-- Name: idx_client_authority_locks_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_client_authority_locks_on_client_id ON public.client_authority_locks USING btree (client_id);


--
-- Name: idx_client_external_identities_client_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_client_external_identities_client_provider ON public.client_external_identities USING btree (client_id) WHERE (released_at IS NULL);


--
-- Name: idx_client_external_identities_issuer_subject; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_client_external_identities_issuer_subject ON public.client_external_identities USING btree (issuer, subject) WHERE (released_at IS NULL);


--
-- Name: idx_client_oidc_identity_bindings_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_client_oidc_identity_bindings_identity ON public.client_oidc_identity_bindings USING btree (client_identity_id, issuer, audience);


--
-- Name: idx_client_oidc_identity_bindings_subject; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_client_oidc_identity_bindings_subject ON public.client_oidc_identity_bindings USING btree (issuer, subject, audience);


--
-- Name: idx_client_persona_admin_grants_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_persona_admin_grants_on_client_id ON public.client_persona_administration_grants USING btree (client_id);


--
-- Name: idx_client_persona_admin_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_client_persona_admin_grants_unique ON public.client_persona_administration_grants USING btree (client_persona_id, client_id);


--
-- Name: idx_client_persona_delegate_grants_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_persona_delegate_grants_on_client_id ON public.client_persona_delegation_grants USING btree (client_id);


--
-- Name: idx_client_persona_delegate_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_client_persona_delegate_grants_unique ON public.client_persona_delegation_grants USING btree (client_persona_id, client_id);


--
-- Name: idx_client_persona_lifecycles_one_client_persona; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_client_persona_lifecycles_one_client_persona ON public.client_persona_lifecycles USING btree (client_persona_id);


--
-- Name: idx_client_persona_ownerships_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_persona_ownerships_on_client_id ON public.client_persona_ownerships USING btree (client_id);


--
-- Name: idx_client_persona_ownerships_one_resource; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_client_persona_ownerships_one_resource ON public.client_persona_ownerships USING btree (client_persona_id);


--
-- Name: idx_client_persona_transfer_requests_destination; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_persona_transfer_requests_destination ON public.client_persona_ownership_transfer_requests USING btree (destination_client_id, status);


--
-- Name: idx_client_persona_transfer_requests_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_persona_transfer_requests_due ON public.client_persona_ownership_transfer_requests USING btree (status, expires_at);


--
-- Name: idx_client_persona_transfer_requests_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_client_persona_transfer_requests_on_public_id ON public.client_persona_ownership_transfer_requests USING btree (public_id);


--
-- Name: idx_client_persona_transfer_requests_one_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_client_persona_transfer_requests_one_pending ON public.client_persona_ownership_transfer_requests USING btree (client_persona_id) WHERE ((status)::text = 'pending'::text);


--
-- Name: idx_client_persona_usage_grants_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_persona_usage_grants_on_client_id ON public.client_persona_usage_grants USING btree (client_id);


--
-- Name: idx_client_persona_usage_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_client_persona_usage_grants_unique ON public.client_persona_usage_grants USING btree (client_persona_id, client_id);


--
-- Name: idx_client_persona_view_grants_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_persona_view_grants_on_client_id ON public.client_persona_view_grants USING btree (client_id);


--
-- Name: idx_client_persona_view_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_client_persona_view_grants_unique ON public.client_persona_view_grants USING btree (client_persona_id, client_id);


--
-- Name: idx_client_privacy_requests_on_subject_kind_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_privacy_requests_on_subject_kind_status ON public.client_privacy_requests USING btree (client_id, request_kind, status_id);


--
-- Name: idx_client_proc_erase_attempts_generation_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_client_proc_erase_attempts_generation_number ON public.client_processor_erasure_notification_attempts USING btree (client_processor_erasure_notification_id, delivery_generation, attempt_number);


--
-- Name: idx_client_proc_erase_attempts_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_proc_erase_attempts_idempotency ON public.client_processor_erasure_notification_attempts USING btree (client_processor_erasure_notification_id, delivery_generation, idempotency_key_digest);


--
-- Name: idx_client_proc_erase_attempts_processing; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_proc_erase_attempts_processing ON public.client_processor_erasure_notification_attempts USING btree (client_processor_erasure_notification_id, delivery_generation, outcome);


--
-- Name: idx_client_proc_erase_notifications_retry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_proc_erase_notifications_retry ON public.client_processor_erasure_notifications USING btree (status_id, next_retry_at);


--
-- Name: idx_client_proc_erase_notifications_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_client_proc_erase_notifications_unique ON public.client_processor_erasure_notifications USING btree (client_privacy_request_id, processor_key);


--
-- Name: idx_client_retention_holds_on_subject_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_retention_holds_on_subject_status ON public.client_retention_holds USING btree (client_id, status_id);


--
-- Name: idx_core_app_client_bridges_unique_client_rp; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_core_app_client_bridges_unique_client_rp ON public.core_app_client_bridges USING btree (client_id, rp_client_id);


--
-- Name: idx_enterprise_admin_grants_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_enterprise_admin_grants_on_client_id ON public.enterprise_administration_grants USING btree (client_id);


--
-- Name: idx_enterprise_admin_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_enterprise_admin_grants_unique ON public.enterprise_administration_grants USING btree (enterprise_id, client_id);


--
-- Name: idx_enterprise_delegate_grants_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_enterprise_delegate_grants_on_client_id ON public.enterprise_delegation_grants USING btree (client_id);


--
-- Name: idx_enterprise_delegate_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_enterprise_delegate_grants_unique ON public.enterprise_delegation_grants USING btree (enterprise_id, client_id);


--
-- Name: idx_enterprise_lifecycles_one_enterprise; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_enterprise_lifecycles_one_enterprise ON public.enterprise_lifecycles USING btree (enterprise_id);


--
-- Name: idx_enterprise_ownerships_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_enterprise_ownerships_on_client_id ON public.enterprise_ownerships USING btree (client_id);


--
-- Name: idx_enterprise_ownerships_one_resource; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_enterprise_ownerships_one_resource ON public.enterprise_ownerships USING btree (enterprise_id);


--
-- Name: idx_enterprise_transfer_requests_destination; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_enterprise_transfer_requests_destination ON public.enterprise_ownership_transfer_requests USING btree (destination_client_id, status);


--
-- Name: idx_enterprise_transfer_requests_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_enterprise_transfer_requests_due ON public.enterprise_ownership_transfer_requests USING btree (status, expires_at);


--
-- Name: idx_enterprise_transfer_requests_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_enterprise_transfer_requests_on_public_id ON public.enterprise_ownership_transfer_requests USING btree (public_id);


--
-- Name: idx_enterprise_transfer_requests_one_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_enterprise_transfer_requests_one_pending ON public.enterprise_ownership_transfer_requests USING btree (enterprise_id) WHERE ((status)::text = 'pending'::text);


--
-- Name: idx_enterprise_unit_closures_unique_path; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_enterprise_unit_closures_unique_path ON public.enterprise_unit_closures USING btree (ancestor_id, descendant_id);


--
-- Name: idx_enterprise_units_id_enterprise; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_enterprise_units_id_enterprise ON public.enterprise_units USING btree (id, enterprise_id);


--
-- Name: idx_enterprise_view_grants_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_enterprise_view_grants_on_client_id ON public.enterprise_view_grants USING btree (client_id);


--
-- Name: idx_enterprise_view_grants_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_enterprise_view_grants_unique ON public.enterprise_view_grants USING btree (enterprise_id, client_id);


--
-- Name: idx_on_app_enforcement_case_id_7065911d36; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_app_enforcement_case_id_7065911d36 ON public.app_enforcement_identifier_effects USING btree (app_enforcement_case_id);


--
-- Name: idx_on_app_enforcement_case_id_73f5abbece; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_app_enforcement_case_id_73f5abbece ON public.app_enforcement_principal_effects USING btree (app_enforcement_case_id);


--
-- Name: idx_on_app_enforcement_case_id_7ef6eff8df; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_app_enforcement_case_id_7ef6eff8df ON public.app_enforcement_principal_links USING btree (app_enforcement_case_id);


--
-- Name: idx_on_app_enforcement_case_id_e14a728ea9; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_app_enforcement_case_id_e14a728ea9 ON public.app_enforcement_authentication_method_effects USING btree (app_enforcement_case_id);


--
-- Name: idx_on_client_external_identity_id_1019b8f366; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_client_external_identity_id_1019b8f366 ON public.client_apple_notification_events USING btree (client_external_identity_id);


--
-- Name: idx_on_client_id_status_id_expires_at_59a6aa897d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_client_id_status_id_expires_at_59a6aa897d ON public.client_enforcement_recovery_ceremonies USING btree (client_id, status_id, expires_at);


--
-- Name: idx_on_client_id_status_id_expires_at_6c66cf1447; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_client_id_status_id_expires_at_6c66cf1447 ON public.client_withdrawal_ceremonies USING btree (client_id, status_id, expires_at);


--
-- Name: idx_on_client_privacy_request_id_019e8d95c9; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_client_privacy_request_id_019e8d95c9 ON public.client_processor_erasure_notifications USING btree (client_privacy_request_id);


--
-- Name: idx_on_client_processor_erasure_notification_id_2c59431eb8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_client_processor_erasure_notification_id_2c59431eb8 ON public.client_processor_erasure_notification_attempts USING btree (client_processor_erasure_notification_id);


--
-- Name: idx_on_client_withdrawal_flow_id_128dba0f0d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_client_withdrawal_flow_id_128dba0f0d ON public.client_withdrawal_flow_events USING btree (client_withdrawal_flow_id);


--
-- Name: idx_on_delivered_at_occurred_at_7f793f98aa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_delivered_at_occurred_at_7f793f98aa ON public.client_secret_audit_outboxes USING btree (delivered_at, occurred_at);


--
-- Name: idx_on_origin_operation_id_attempt_number_13ceb0af19; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_origin_operation_id_attempt_number_13ceb0af19 ON public.client_secret_issuances USING btree (origin_operation_id, attempt_number);


--
-- Name: idx_on_purge_eligible_at_71ad3fbc7d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_purge_eligible_at_71ad3fbc7d ON public.client_processor_erasure_notifications USING btree (purge_eligible_at) WHERE (purge_eligible_at < 'infinity'::timestamp with time zone);


--
-- Name: idx_on_user_identity_totp_credential_status_id_47a8d28ad3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_user_identity_totp_credential_status_id_47a8d28ad3 ON public.client_totp_credentials USING btree (user_identity_totp_credential_status_id);


--
-- Name: idx_persona_assignments_one_active_identity_per_persona; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_persona_assignments_one_active_identity_per_persona ON public.persona_assignments USING btree (persona_id, client_identity_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_persona_memberships_one_active_primary; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_persona_memberships_one_active_primary ON public.persona_memberships USING btree (persona_id) WHERE (("primary" = true) AND (revoked_at IS NULL) AND (ends_at IS NULL));


--
-- Name: idx_personas_one_per_client_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_personas_one_per_client_identity ON public.personas USING btree (client_identity_id);


--
-- Name: index_accounts_on_accountable_type_and_accountable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_accounts_on_accountable_type_and_accountable_id ON public.accounts USING btree (accountable_type, accountable_id);


--
-- Name: index_accounts_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_accounts_on_email ON public.accounts USING btree (email);


--
-- Name: index_app_enforcement_appeals_on_app_enforcement_case_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_app_enforcement_appeals_on_app_enforcement_case_id ON public.app_enforcement_appeals USING btree (app_enforcement_case_id);


--
-- Name: index_app_enforcement_appeals_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_app_enforcement_appeals_on_public_id ON public.app_enforcement_appeals USING btree (public_id);


--
-- Name: index_app_enforcement_cases_on_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_enforcement_cases_on_kind ON public.app_enforcement_cases USING btree (kind);


--
-- Name: index_app_enforcement_cases_on_principal_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_enforcement_cases_on_principal_public_id ON public.app_enforcement_cases USING btree (principal_public_id);


--
-- Name: index_app_enforcement_cases_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_app_enforcement_cases_on_public_id ON public.app_enforcement_cases USING btree (public_id);


--
-- Name: index_app_enforcement_principal_links_on_principal_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_enforcement_principal_links_on_principal_public_id ON public.app_enforcement_principal_links USING btree (principal_public_id);


--
-- Name: index_apple_auths_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_apple_auths_on_user_id ON public.apple_auths USING btree (user_id);


--
-- Name: index_client_accounts_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_accounts_on_public_id ON public.client_accounts USING btree (public_id);


--
-- Name: index_client_accounts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_accounts_on_user_id ON public.client_accounts USING btree (user_id);


--
-- Name: index_client_apple_notification_events_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_apple_notification_events_on_client_id ON public.client_apple_notification_events USING btree (client_id);


--
-- Name: index_client_apple_notification_events_on_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_apple_notification_events_on_jti ON public.client_apple_notification_events USING btree (jti);


--
-- Name: index_client_banners_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_banners_on_user_id ON public.client_banners USING btree (user_id);


--
-- Name: index_client_bulletins_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_bulletins_on_public_id ON public.client_bulletins USING btree (public_id);


--
-- Name: index_client_bulletins_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_bulletins_on_user_id ON public.client_bulletins USING btree (user_id);


--
-- Name: index_client_contact_audit_outboxes_on_event_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_contact_audit_outboxes_on_event_uuid ON public.client_contact_audit_outboxes USING btree (event_uuid);


--
-- Name: index_client_email_histories_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_email_histories_on_user_id ON public.client_email_histories USING btree (user_id);


--
-- Name: index_client_emails_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_emails_on_discard_at ON public.client_emails USING btree (discard_at);


--
-- Name: index_client_emails_on_otp_last_sent_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_emails_on_otp_last_sent_at ON public.client_emails USING btree (otp_last_sent_at);


--
-- Name: index_client_emails_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_emails_on_public_id ON public.client_emails USING btree (public_id);


--
-- Name: index_client_emails_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_emails_on_purge_eligible_at ON public.client_emails USING btree (purge_eligible_at);


--
-- Name: index_client_emails_on_user_email_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_emails_on_user_email_status_id ON public.client_emails USING btree (user_email_status_id);


--
-- Name: index_client_emails_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_emails_on_user_id ON public.client_emails USING btree (user_id);


--
-- Name: index_client_enforcement_recovery_ceremonies_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_enforcement_recovery_ceremonies_on_client_id ON public.client_enforcement_recovery_ceremonies USING btree (client_id);


--
-- Name: index_client_enforcement_recovery_ceremonies_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_enforcement_recovery_ceremonies_on_public_id ON public.client_enforcement_recovery_ceremonies USING btree (public_id);


--
-- Name: index_client_enforcement_recovery_ceremonies_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_enforcement_recovery_ceremonies_on_token_digest ON public.client_enforcement_recovery_ceremonies USING btree (token_digest);


--
-- Name: index_client_external_identities_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_external_identities_on_client_id ON public.client_external_identities USING btree (client_id);


--
-- Name: index_client_external_identities_on_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_external_identities_on_state ON public.client_external_identities USING btree (state);


--
-- Name: index_client_identities_on_issuer_and_subject_and_audience; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_identities_on_issuer_and_subject_and_audience ON public.client_identities USING btree (issuer, subject, audience);


--
-- Name: index_client_identities_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_identities_on_public_id ON public.client_identities USING btree (public_id);


--
-- Name: index_client_identities_on_source_record_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_identities_on_source_record_id ON public.client_identities USING btree (source_record_id);


--
-- Name: index_client_identities_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_identities_on_status_id ON public.client_identities USING btree (status_id);


--
-- Name: index_client_member_deletions_on_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_member_deletions_on_member_id ON public.client_member_deletions USING btree (member_id);


--
-- Name: index_client_member_deletions_on_user_id_and_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_member_deletions_on_user_id_and_member_id ON public.client_member_deletions USING btree (user_id, member_id);


--
-- Name: index_client_member_discoveries_on_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_member_discoveries_on_member_id ON public.client_member_discoveries USING btree (member_id);


--
-- Name: index_client_member_discoveries_on_user_id_and_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_member_discoveries_on_user_id_and_member_id ON public.client_member_discoveries USING btree (user_id, member_id);


--
-- Name: index_client_member_impersonations_on_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_member_impersonations_on_member_id ON public.client_member_impersonations USING btree (member_id);


--
-- Name: index_client_member_impersonations_on_user_id_and_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_member_impersonations_on_user_id_and_member_id ON public.client_member_impersonations USING btree (user_id, member_id);


--
-- Name: index_client_member_observations_on_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_member_observations_on_member_id ON public.client_member_observations USING btree (member_id);


--
-- Name: index_client_member_observations_on_user_id_and_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_member_observations_on_user_id_and_member_id ON public.client_member_observations USING btree (user_id, member_id);


--
-- Name: index_client_member_revocations_on_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_member_revocations_on_member_id ON public.client_member_revocations USING btree (member_id);


--
-- Name: index_client_member_revocations_on_user_id_and_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_member_revocations_on_user_id_and_member_id ON public.client_member_revocations USING btree (user_id, member_id);


--
-- Name: index_client_member_suspensions_on_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_member_suspensions_on_member_id ON public.client_member_suspensions USING btree (member_id);


--
-- Name: index_client_member_suspensions_on_user_id_and_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_member_suspensions_on_user_id_and_member_id ON public.client_member_suspensions USING btree (user_id, member_id);


--
-- Name: index_client_members_on_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_members_on_member_id ON public.client_members USING btree (member_id);


--
-- Name: index_client_members_on_user_id_and_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_members_on_user_id_and_member_id ON public.client_members USING btree (user_id, member_id);


--
-- Name: index_client_memberships_on_user_id_and_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_memberships_on_user_id_and_workspace_id ON public.client_memberships USING btree (user_id, workspace_id);


--
-- Name: index_client_memberships_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_memberships_on_workspace_id ON public.client_memberships USING btree (workspace_id);


--
-- Name: index_client_oidc_identity_bindings_on_client_identity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_oidc_identity_bindings_on_client_identity_id ON public.client_oidc_identity_bindings USING btree (client_identity_id);


--
-- Name: index_client_passkey_audit_outboxes_on_event_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_passkey_audit_outboxes_on_event_uuid ON public.client_passkey_audit_outboxes USING btree (event_uuid);


--
-- Name: index_client_passkeys_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_passkeys_on_discard_at ON public.client_passkeys USING btree (discard_at);


--
-- Name: index_client_passkeys_on_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_passkeys_on_external_id ON public.client_passkeys USING btree (external_id);


--
-- Name: index_client_passkeys_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_passkeys_on_public_id ON public.client_passkeys USING btree (public_id);


--
-- Name: index_client_passkeys_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_passkeys_on_purge_eligible_at ON public.client_passkeys USING btree (purge_eligible_at);


--
-- Name: index_client_passkeys_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_passkeys_on_status_id ON public.client_passkeys USING btree (status_id);


--
-- Name: index_client_passkeys_on_webauthn_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_passkeys_on_webauthn_id ON public.client_passkeys USING btree (webauthn_id);


--
-- Name: index_client_preference_adult_content_gates_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_adult_content_gates_on_option_id ON public.client_preference_adult_content_gates USING btree (option_id);


--
-- Name: index_client_preference_adult_content_gates_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_adult_content_gates_on_preference_id ON public.client_preference_adult_content_gates USING btree (preference_id);


--
-- Name: index_client_preference_currencies_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_currencies_on_option_id ON public.client_preference_currencies USING btree (option_id);


--
-- Name: index_client_preference_currencies_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_currencies_on_preference_id ON public.client_preference_currencies USING btree (preference_id);


--
-- Name: index_client_preference_date_formats_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_date_formats_on_option_id ON public.client_preference_date_formats USING btree (option_id);


--
-- Name: index_client_preference_date_formats_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_date_formats_on_preference_id ON public.client_preference_date_formats USING btree (preference_id);


--
-- Name: index_client_preference_densities_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_densities_on_option_id ON public.client_preference_densities USING btree (option_id);


--
-- Name: index_client_preference_densities_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_densities_on_preference_id ON public.client_preference_densities USING btree (preference_id);


--
-- Name: index_client_preference_languages_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_languages_on_option_id ON public.client_preference_languages USING btree (option_id);


--
-- Name: index_client_preference_languages_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_languages_on_preference_id ON public.client_preference_languages USING btree (preference_id);


--
-- Name: index_client_preference_motions_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_motions_on_option_id ON public.client_preference_motions USING btree (option_id);


--
-- Name: index_client_preference_motions_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_motions_on_preference_id ON public.client_preference_motions USING btree (preference_id);


--
-- Name: index_client_preference_page_sizes_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_page_sizes_on_option_id ON public.client_preference_page_sizes USING btree (option_id);


--
-- Name: index_client_preference_page_sizes_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_page_sizes_on_preference_id ON public.client_preference_page_sizes USING btree (preference_id);


--
-- Name: index_client_preference_regions_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_regions_on_option_id ON public.client_preference_regions USING btree (option_id);


--
-- Name: index_client_preference_regions_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_regions_on_preference_id ON public.client_preference_regions USING btree (preference_id);


--
-- Name: index_client_preference_themes_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_themes_on_option_id ON public.client_preference_themes USING btree (option_id);


--
-- Name: index_client_preference_themes_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_themes_on_preference_id ON public.client_preference_themes USING btree (preference_id);


--
-- Name: index_client_preference_time_formats_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_time_formats_on_option_id ON public.client_preference_time_formats USING btree (option_id);


--
-- Name: index_client_preference_time_formats_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_time_formats_on_preference_id ON public.client_preference_time_formats USING btree (preference_id);


--
-- Name: index_client_preference_timezones_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_timezones_on_option_id ON public.client_preference_timezones USING btree (option_id);


--
-- Name: index_client_preference_timezones_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_timezones_on_preference_id ON public.client_preference_timezones USING btree (preference_id);


--
-- Name: index_client_preferences_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preferences_on_public_id ON public.client_preferences USING btree (public_id);


--
-- Name: index_client_preferences_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preferences_on_user_id ON public.client_preferences USING btree (user_id);


--
-- Name: index_client_privacy_requests_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_privacy_requests_on_client_id ON public.client_privacy_requests USING btree (client_id);


--
-- Name: index_client_privacy_requests_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_privacy_requests_on_discard_at ON public.client_privacy_requests USING btree (discard_at);


--
-- Name: index_client_privacy_requests_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_privacy_requests_on_public_id ON public.client_privacy_requests USING btree (public_id);


--
-- Name: index_client_privacy_requests_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_privacy_requests_on_purge_eligible_at ON public.client_privacy_requests USING btree (purge_eligible_at) WHERE (purge_eligible_at < 'infinity'::timestamp with time zone);


--
-- Name: index_client_privacy_requests_on_response_due_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_privacy_requests_on_response_due_at ON public.client_privacy_requests USING btree (response_due_at);


--
-- Name: index_client_processor_erasure_notifications_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_processor_erasure_notifications_on_discard_at ON public.client_processor_erasure_notifications USING btree (discard_at);


--
-- Name: index_client_processor_erasure_notifications_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_processor_erasure_notifications_on_public_id ON public.client_processor_erasure_notifications USING btree (public_id);


--
-- Name: index_client_profiles_on_client_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_profiles_on_client_status_id ON public.client_profiles USING btree (client_status_id);


--
-- Name: index_client_profiles_on_division_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_profiles_on_division_id ON public.client_profiles USING btree (division_id);


--
-- Name: index_client_profiles_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_profiles_on_public_id ON public.client_profiles USING btree (public_id);


--
-- Name: index_client_profiles_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_profiles_on_status_id ON public.client_profiles USING btree (status_id);


--
-- Name: index_client_profiles_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_profiles_on_user_id ON public.client_profiles USING btree (user_id);


--
-- Name: index_client_retention_holds_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_retention_holds_on_client_id ON public.client_retention_holds USING btree (client_id);


--
-- Name: index_client_retention_holds_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_retention_holds_on_discard_at ON public.client_retention_holds USING btree (discard_at);


--
-- Name: index_client_retention_holds_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_retention_holds_on_expires_at ON public.client_retention_holds USING btree (expires_at);


--
-- Name: index_client_retention_holds_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_retention_holds_on_public_id ON public.client_retention_holds USING btree (public_id);


--
-- Name: index_client_retention_holds_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_retention_holds_on_purge_eligible_at ON public.client_retention_holds USING btree (purge_eligible_at) WHERE (purge_eligible_at < 'infinity'::timestamp with time zone);


--
-- Name: index_client_secret_audit_outboxes_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_secret_audit_outboxes_on_event_id ON public.client_secret_audit_outboxes USING btree (event_id);


--
-- Name: index_client_secret_credentials_on_claim_operation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_secret_credentials_on_claim_operation_id ON public.client_secret_credentials USING btree (claim_operation_id);


--
-- Name: index_client_secret_credentials_on_claim_sign_in_flow_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_secret_credentials_on_claim_sign_in_flow_ref ON public.client_secret_credentials USING btree (claim_sign_in_flow_ref);


--
-- Name: index_client_secret_credentials_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_secret_credentials_on_client_id ON public.client_secret_credentials USING btree (client_id);


--
-- Name: index_client_secret_credentials_on_issuance_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_secret_credentials_on_issuance_id_and_client_id ON public.client_secret_credentials USING btree (issuance_id, client_id);


--
-- Name: index_client_secret_credentials_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_secret_credentials_on_public_id ON public.client_secret_credentials USING btree (public_id);


--
-- Name: index_client_secret_issuances_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_secret_issuances_on_client_id ON public.client_secret_issuances USING btree (client_id);


--
-- Name: index_client_secret_issuances_on_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_secret_issuances_on_id_and_client_id ON public.client_secret_issuances USING btree (id, client_id);


--
-- Name: index_client_secret_issuances_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_secret_issuances_on_public_id ON public.client_secret_issuances USING btree (public_id);


--
-- Name: index_client_social_audit_outboxes_on_event_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_social_audit_outboxes_on_event_uuid ON public.client_social_audit_outboxes USING btree (event_uuid);


--
-- Name: index_client_telephone_histories_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_telephone_histories_on_user_id ON public.client_telephone_histories USING btree (user_id);


--
-- Name: index_client_telephones_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_telephones_on_discard_at ON public.client_telephones USING btree (discard_at);


--
-- Name: index_client_telephones_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_telephones_on_public_id ON public.client_telephones USING btree (public_id);


--
-- Name: index_client_telephones_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_telephones_on_purge_eligible_at ON public.client_telephones USING btree (purge_eligible_at);


--
-- Name: index_client_telephones_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_telephones_on_user_id ON public.client_telephones USING btree (user_id);


--
-- Name: index_client_telephones_on_user_identity_telephone_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_telephones_on_user_identity_telephone_status_id ON public.client_telephones USING btree (user_identity_telephone_status_id);


--
-- Name: index_client_totp_credentials_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_totp_credentials_on_public_id ON public.client_totp_credentials USING btree (public_id);


--
-- Name: index_client_totp_credentials_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_totp_credentials_on_user_id ON public.client_totp_credentials USING btree (user_id);


--
-- Name: index_client_withdrawal_ceremonies_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_ceremonies_on_client_id ON public.client_withdrawal_ceremonies USING btree (client_id);


--
-- Name: index_client_withdrawal_ceremonies_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_ceremonies_on_expires_at ON public.client_withdrawal_ceremonies USING btree (expires_at);


--
-- Name: index_client_withdrawal_ceremonies_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_withdrawal_ceremonies_on_public_id ON public.client_withdrawal_ceremonies USING btree (public_id);


--
-- Name: index_client_withdrawal_ceremonies_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_withdrawal_ceremonies_on_token_digest ON public.client_withdrawal_ceremonies USING btree (token_digest);


--
-- Name: index_client_withdrawal_flow_events_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_flow_events_on_client_id ON public.client_withdrawal_flow_events USING btree (client_id);


--
-- Name: index_client_withdrawal_flow_events_on_from_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_flow_events_on_from_status_id ON public.client_withdrawal_flow_events USING btree (from_status_id);


--
-- Name: index_client_withdrawal_flow_events_on_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_flow_events_on_occurred_at ON public.client_withdrawal_flow_events USING btree (occurred_at);


--
-- Name: index_client_withdrawal_flow_events_on_to_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_flow_events_on_to_status_id ON public.client_withdrawal_flow_events USING btree (to_status_id);


--
-- Name: index_client_withdrawal_flows_on_began_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_flows_on_began_at ON public.client_withdrawal_flows USING btree (began_at);


--
-- Name: index_client_withdrawal_flows_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_flows_on_client_id ON public.client_withdrawal_flows USING btree (client_id);


--
-- Name: index_client_withdrawal_flows_on_completed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_flows_on_completed_at ON public.client_withdrawal_flows USING btree (completed_at);


--
-- Name: index_client_withdrawal_flows_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_flows_on_discard_at ON public.client_withdrawal_flows USING btree (discard_at);


--
-- Name: index_client_withdrawal_flows_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_withdrawal_flows_on_public_id ON public.client_withdrawal_flows USING btree (public_id);


--
-- Name: index_client_withdrawal_flows_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_flows_on_purge_eligible_at ON public.client_withdrawal_flows USING btree (purge_eligible_at);


--
-- Name: index_client_withdrawal_flows_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_flows_on_status_id ON public.client_withdrawal_flows USING btree (status_id);


--
-- Name: index_clients_on_access_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_access_state ON public.clients USING btree (access_state);


--
-- Name: index_clients_on_admin_locked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_admin_locked_at ON public.clients USING btree (admin_locked_at) WHERE (admin_locked_at IS NOT NULL);


--
-- Name: index_clients_on_deactivated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_deactivated_at ON public.clients USING btree (deactivated_at) WHERE (deactivated_at IS NOT NULL);


--
-- Name: index_clients_on_discard_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_discard_at ON public.clients USING btree (discard_at);


--
-- Name: index_clients_on_early_termination_available_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_early_termination_available_at ON public.clients USING btree (early_termination_available_at) WHERE (early_termination_available_at IS NOT NULL);


--
-- Name: index_clients_on_mfa_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_mfa_level_id ON public.clients USING btree (mfa_level_id);


--
-- Name: index_clients_on_mfa_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_mfa_status_id ON public.clients USING btree (mfa_status_id);


--
-- Name: index_clients_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_clients_on_public_id ON public.clients USING btree (public_id);


--
-- Name: index_clients_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_purge_eligible_at ON public.clients USING btree (purge_eligible_at) WHERE (purge_eligible_at IS NOT NULL);


--
-- Name: index_clients_on_recovery_available_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_recovery_available_at ON public.clients USING btree (recovery_available_at) WHERE (recovery_available_at IS NOT NULL);


--
-- Name: index_clients_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_status_id ON public.clients USING btree (status_id);


--
-- Name: index_clients_on_terminated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_terminated_at ON public.clients USING btree (terminated_at) WHERE (terminated_at IS NOT NULL);


--
-- Name: index_clients_on_token_valid_after_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_token_valid_after_at ON public.clients USING btree (token_valid_after_at) WHERE (token_valid_after_at IS NOT NULL);


--
-- Name: index_clients_on_visibility_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_visibility_id ON public.clients USING btree (visibility_id);


--
-- Name: index_clients_on_webauthn_user_handle; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_clients_on_webauthn_user_handle ON public.clients USING btree (webauthn_user_handle);


--
-- Name: index_clients_on_withdrawal_started_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_withdrawal_started_at ON public.clients USING btree (withdrawal_started_at) WHERE (withdrawal_started_at IS NOT NULL);


--
-- Name: index_clients_on_withdrawn_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_withdrawn_at ON public.clients USING btree (withdrawn_at) WHERE (withdrawn_at IS NOT NULL);


--
-- Name: index_core_app_client_bridges_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_core_app_client_bridges_on_public_id ON public.core_app_client_bridges USING btree (public_id);


--
-- Name: index_enterprise_unit_closures_on_descendant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_enterprise_unit_closures_on_descendant_id ON public.enterprise_unit_closures USING btree (descendant_id);


--
-- Name: index_enterprise_units_on_enterprise_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_enterprise_units_on_enterprise_id ON public.enterprise_units USING btree (enterprise_id);


--
-- Name: index_enterprise_units_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_enterprise_units_on_parent_id ON public.enterprise_units USING btree (parent_id);


--
-- Name: index_enterprise_units_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_enterprise_units_on_public_id ON public.enterprise_units USING btree (public_id);


--
-- Name: index_enterprises_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_enterprises_on_public_id ON public.enterprises USING btree (public_id);


--
-- Name: index_legacy_replaced_client_banners_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_legacy_replaced_client_banners_on_client_id ON public.legacy_replaced_client_banners USING btree (client_id);


--
-- Name: index_legacy_replaced_clients_on_client_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_legacy_replaced_clients_on_client_status_id ON public.legacy_replaced_clients USING btree (client_status_id);


--
-- Name: index_legacy_replaced_clients_on_division_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_legacy_replaced_clients_on_division_id ON public.legacy_replaced_clients USING btree (division_id);


--
-- Name: index_legacy_replaced_clients_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_legacy_replaced_clients_on_public_id ON public.legacy_replaced_clients USING btree (public_id);


--
-- Name: index_legacy_replaced_clients_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_legacy_replaced_clients_on_status_id ON public.legacy_replaced_clients USING btree (status_id);


--
-- Name: index_legacy_replaced_clients_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_legacy_replaced_clients_on_user_id ON public.legacy_replaced_clients USING btree (user_id);


--
-- Name: index_members_on_division_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_members_on_division_id ON public.members USING btree (division_id);


--
-- Name: index_members_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_members_on_public_id ON public.members USING btree (public_id);


--
-- Name: index_members_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_members_on_purge_eligible_at ON public.members USING btree (purge_eligible_at);


--
-- Name: index_members_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_members_on_status_id ON public.members USING btree (status_id);


--
-- Name: index_members_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_members_on_user_id ON public.members USING btree (user_id);


--
-- Name: index_persona_assignments_on_client_identity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_assignments_on_client_identity_id ON public.persona_assignments USING btree (client_identity_id);


--
-- Name: index_persona_assignments_on_persona_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_assignments_on_persona_id ON public.persona_assignments USING btree (persona_id);


--
-- Name: index_persona_assignments_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_persona_assignments_on_public_id ON public.persona_assignments USING btree (public_id);


--
-- Name: index_persona_memberships_on_approved_by_persona_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_memberships_on_approved_by_persona_id ON public.persona_memberships USING btree (approved_by_persona_id);


--
-- Name: index_persona_memberships_on_enterprise_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_memberships_on_enterprise_id ON public.persona_memberships USING btree (enterprise_id);


--
-- Name: index_persona_memberships_on_enterprise_unit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_memberships_on_enterprise_unit_id ON public.persona_memberships USING btree (enterprise_unit_id);


--
-- Name: index_persona_memberships_on_granted_by_persona_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_memberships_on_granted_by_persona_id ON public.persona_memberships USING btree (granted_by_persona_id);


--
-- Name: index_persona_memberships_on_membership_kind_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_memberships_on_membership_kind_id ON public.persona_memberships USING btree (membership_kind_id);


--
-- Name: index_persona_memberships_on_membership_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_memberships_on_membership_state_id ON public.persona_memberships USING btree (membership_state_id);


--
-- Name: index_persona_memberships_on_persona_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_memberships_on_persona_id ON public.persona_memberships USING btree (persona_id);


--
-- Name: index_persona_memberships_on_revoke_reason_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_memberships_on_revoke_reason_id ON public.persona_memberships USING btree (revoke_reason_id);


--
-- Name: index_persona_memberships_on_revoked_by_persona_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_memberships_on_revoked_by_persona_id ON public.persona_memberships USING btree (revoked_by_persona_id);


--
-- Name: index_personas_on_client_identity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_personas_on_client_identity_id ON public.personas USING btree (client_identity_id);


--
-- Name: index_personas_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_personas_on_public_id ON public.personas USING btree (public_id);


--
-- Name: index_roles_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_roles_on_organization_id ON public.roles USING btree (organization_id);


--
-- Name: index_user_client_deletions_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_client_deletions_on_client_id ON public.user_client_deletions USING btree (client_id);


--
-- Name: index_user_client_deletions_on_user_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_client_deletions_on_user_id_and_client_id ON public.user_client_deletions USING btree (user_id, client_id);


--
-- Name: index_user_client_discoveries_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_client_discoveries_on_client_id ON public.user_client_discoveries USING btree (client_id);


--
-- Name: index_user_client_discoveries_on_user_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_client_discoveries_on_user_id_and_client_id ON public.user_client_discoveries USING btree (user_id, client_id);


--
-- Name: index_user_client_impersonations_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_client_impersonations_on_client_id ON public.user_client_impersonations USING btree (client_id);


--
-- Name: index_user_client_impersonations_on_user_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_client_impersonations_on_user_id_and_client_id ON public.user_client_impersonations USING btree (user_id, client_id);


--
-- Name: index_user_client_observations_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_client_observations_on_client_id ON public.user_client_observations USING btree (client_id);


--
-- Name: index_user_client_observations_on_user_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_client_observations_on_user_id_and_client_id ON public.user_client_observations USING btree (user_id, client_id);


--
-- Name: index_user_client_revocations_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_client_revocations_on_client_id ON public.user_client_revocations USING btree (client_id);


--
-- Name: index_user_client_revocations_on_user_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_client_revocations_on_user_id_and_client_id ON public.user_client_revocations USING btree (user_id, client_id);


--
-- Name: index_user_client_suspensions_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_client_suspensions_on_client_id ON public.user_client_suspensions USING btree (client_id);


--
-- Name: index_user_client_suspensions_on_user_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_client_suspensions_on_user_id_and_client_id ON public.user_client_suspensions USING btree (user_id, client_id);


--
-- Name: index_user_clients_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_clients_on_client_id ON public.user_clients USING btree (client_id);


--
-- Name: index_user_clients_on_user_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_clients_on_user_id_and_client_id ON public.user_clients USING btree (user_id, client_id);


--
-- Name: index_user_identity_passkeys_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_identity_passkeys_on_user_id ON public.client_passkeys USING btree (user_id);


--
-- Name: client_emails client_emails_binding_facts_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_emails_binding_facts_trigger BEFORE UPDATE ON public.client_emails FOR EACH ROW EXECUTE FUNCTION public.enforce_client_emails_binding_facts();


--
-- Name: client_external_identities client_external_identities_binding_facts_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_external_identities_binding_facts_trigger BEFORE UPDATE ON public.client_external_identities FOR EACH ROW EXECUTE FUNCTION public.enforce_client_external_identity_binding_facts();


--
-- Name: client_identifier_rotation_audits client_rotation_audit_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_rotation_audit_guard BEFORE INSERT OR UPDATE ON public.client_identifier_rotation_audits FOR EACH ROW EXECUTE FUNCTION public.enforce_client_rotation_audit();


--
-- Name: client_telephones client_telephones_binding_facts_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_telephones_binding_facts_trigger BEFORE UPDATE ON public.client_telephones FOR EACH ROW EXECUTE FUNCTION public.enforce_client_telephones_binding_facts();


--
-- Name: client_emails enforcement_protect_client_emails_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER enforcement_protect_client_emails_delete BEFORE DELETE ON public.client_emails FOR EACH ROW EXECUTE FUNCTION public.enforcement_protect_client_emails_delete();


--
-- Name: clients enforcement_protect_clients_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER enforcement_protect_clients_delete BEFORE DELETE ON public.clients FOR EACH ROW EXECUTE FUNCTION public.enforcement_protect_clients_delete();


--
-- Name: client_processor_erasure_notification_attempts fk_client_proc_erase_attempt_notification; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_processor_erasure_notification_attempts
    ADD CONSTRAINT fk_client_proc_erase_attempt_notification FOREIGN KEY (client_processor_erasure_notification_id) REFERENCES public.client_processor_erasure_notifications(id) ON DELETE CASCADE;


--
-- Name: legacy_replaced_clients fk_clients_on_client_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_replaced_clients
    ADD CONSTRAINT fk_clients_on_client_status_id FOREIGN KEY (client_status_id) REFERENCES public.legacy_replaced_client_statuses(id);


--
-- Name: legacy_replaced_clients fk_clients_on_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_replaced_clients
    ADD CONSTRAINT fk_clients_on_status_id FOREIGN KEY (status_id) REFERENCES public.legacy_replaced_client_statuses(id);


--
-- Name: enterprise_units fk_enterprise_units_parent_same_enterprise; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_units
    ADD CONSTRAINT fk_enterprise_units_parent_same_enterprise FOREIGN KEY (parent_id, enterprise_id) REFERENCES public.enterprise_units(id, enterprise_id) ON DELETE RESTRICT;


--
-- Name: persona_memberships fk_persona_memberships_unit_same_enterprise; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT fk_persona_memberships_unit_same_enterprise FOREIGN KEY (enterprise_unit_id, enterprise_id) REFERENCES public.enterprise_units(id, enterprise_id) ON DELETE RESTRICT;


--
-- Name: client_passkeys fk_rails_0095e1bdca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_passkeys
    ADD CONSTRAINT fk_rails_0095e1bdca FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_preference_densities fk_rails_010ff0dcc1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_densities
    ADD CONSTRAINT fk_rails_010ff0dcc1 FOREIGN KEY (option_id) REFERENCES public.client_preference_density_options(id);


--
-- Name: persona_memberships fk_rails_01b7fc5176; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT fk_rails_01b7fc5176 FOREIGN KEY (persona_id) REFERENCES public.personas(id);


--
-- Name: client_banners fk_rails_08c770fdce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_banners
    ADD CONSTRAINT fk_rails_08c770fdce FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: persona_memberships fk_rails_0d7f5f74b1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT fk_rails_0d7f5f74b1 FOREIGN KEY (revoke_reason_id) REFERENCES public.persona_membership_revoke_reasons(id);


--
-- Name: user_client_suspensions fk_rails_0f76328e35; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_suspensions
    ADD CONSTRAINT fk_rails_0f76328e35 FOREIGN KEY (client_id) REFERENCES public.legacy_replaced_clients(id);


--
-- Name: client_preference_date_formats fk_rails_0fb3559373; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_date_formats
    ADD CONSTRAINT fk_rails_0fb3559373 FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- Name: app_enforcement_authentication_method_effects fk_rails_123aa7db5e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_enforcement_authentication_method_effects
    ADD CONSTRAINT fk_rails_123aa7db5e FOREIGN KEY (app_enforcement_case_id) REFERENCES public.app_enforcement_cases(id);


--
-- Name: client_secret_credentials fk_rails_12f3aec1d7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_credentials
    ADD CONSTRAINT fk_rails_12f3aec1d7 FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: client_persona_ownerships fk_rails_134f20bf77; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_ownerships
    ADD CONSTRAINT fk_rails_134f20bf77 FOREIGN KEY (client_persona_id) REFERENCES public.personas(id);


--
-- Name: client_emails fk_rails_15a0bdccd5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_emails
    ADD CONSTRAINT fk_rails_15a0bdccd5 FOREIGN KEY (user_email_status_id) REFERENCES public.client_email_statuses(id);


--
-- Name: persona_memberships fk_rails_182816542a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT fk_rails_182816542a FOREIGN KEY (membership_state_id) REFERENCES public.persona_membership_states(id);


--
-- Name: client_preference_motions fk_rails_1d88bfb57f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_motions
    ADD CONSTRAINT fk_rails_1d88bfb57f FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- Name: client_secret_credentials fk_rails_1f331d9a65; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_credentials
    ADD CONSTRAINT fk_rails_1f331d9a65 FOREIGN KEY (issuance_id, client_id) REFERENCES public.client_secret_issuances(id, client_id);


--
-- Name: user_clients fk_rails_1ff22d5fc3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_clients
    ADD CONSTRAINT fk_rails_1ff22d5fc3 FOREIGN KEY (client_id) REFERENCES public.legacy_replaced_clients(id) ON DELETE CASCADE;


--
-- Name: client_preference_time_formats fk_rails_21483998fe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_time_formats
    ADD CONSTRAINT fk_rails_21483998fe FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- Name: legacy_replaced_clients fk_rails_21c421fd41; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_replaced_clients
    ADD CONSTRAINT fk_rails_21c421fd41 FOREIGN KEY (user_id) REFERENCES public.clients(id) ON DELETE SET NULL;


--
-- Name: client_apple_notification_events fk_rails_23d9ef1894; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_apple_notification_events
    ADD CONSTRAINT fk_rails_23d9ef1894 FOREIGN KEY (client_external_identity_id) REFERENCES public.client_external_identities(id) ON DELETE SET NULL;


--
-- Name: client_persona_ownership_transfer_requests fk_rails_24ffd1fe54; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_ownership_transfer_requests
    ADD CONSTRAINT fk_rails_24ffd1fe54 FOREIGN KEY (destination_client_id) REFERENCES public.clients(id);


--
-- Name: client_preference_currencies fk_rails_250ae85286; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_currencies
    ADD CONSTRAINT fk_rails_250ae85286 FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- Name: members fk_rails_2e88fb7ce9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members
    ADD CONSTRAINT fk_rails_2e88fb7ce9 FOREIGN KEY (user_id) REFERENCES public.clients(id) ON DELETE SET NULL;


--
-- Name: client_identities fk_rails_3045b2b3f6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_identities
    ADD CONSTRAINT fk_rails_3045b2b3f6 FOREIGN KEY (status_id) REFERENCES public.client_identity_states(id);


--
-- Name: client_preference_time_formats fk_rails_316f4ec31e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_time_formats
    ADD CONSTRAINT fk_rails_316f4ec31e FOREIGN KEY (option_id) REFERENCES public.client_preference_time_format_options(id);


--
-- Name: client_preference_date_formats fk_rails_31ba154e7f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_date_formats
    ADD CONSTRAINT fk_rails_31ba154e7f FOREIGN KEY (option_id) REFERENCES public.client_preference_date_format_options(id);


--
-- Name: client_apple_notification_events fk_rails_37bfb38140; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_apple_notification_events
    ADD CONSTRAINT fk_rails_37bfb38140 FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE SET NULL;


--
-- Name: user_client_deletions fk_rails_38cf70f5c0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_deletions
    ADD CONSTRAINT fk_rails_38cf70f5c0 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: enterprise_view_grants fk_rails_38ff576b28; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_view_grants
    ADD CONSTRAINT fk_rails_38ff576b28 FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: client_preferences fk_rails_39373ef225; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preferences
    ADD CONSTRAINT fk_rails_39373ef225 FOREIGN KEY (user_id) REFERENCES public.clients(id) ON DELETE CASCADE;


--
-- Name: client_preference_currencies fk_rails_3996e38113; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_currencies
    ADD CONSTRAINT fk_rails_3996e38113 FOREIGN KEY (option_id) REFERENCES public.client_preference_currency_options(id);


--
-- Name: client_withdrawal_flows fk_rails_3a897cfb78; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flows
    ADD CONSTRAINT fk_rails_3a897cfb78 FOREIGN KEY (status_id) REFERENCES public.client_withdrawal_flow_statuses(id);


--
-- Name: client_persona_ownerships fk_rails_3ac6a8549a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_ownerships
    ADD CONSTRAINT fk_rails_3ac6a8549a FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: client_persona_usage_grants fk_rails_3cc8e1efa8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_usage_grants
    ADD CONSTRAINT fk_rails_3cc8e1efa8 FOREIGN KEY (client_persona_id) REFERENCES public.personas(id);


--
-- Name: client_member_deletions fk_rails_3d604b095f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_deletions
    ADD CONSTRAINT fk_rails_3d604b095f FOREIGN KEY (member_id) REFERENCES public.members(id);


--
-- Name: client_emails fk_rails_410ac92848; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_emails
    ADD CONSTRAINT fk_rails_410ac92848 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_processor_erasure_notifications fk_rails_41d98680b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_processor_erasure_notifications
    ADD CONSTRAINT fk_rails_41d98680b9 FOREIGN KEY (client_privacy_request_id) REFERENCES public.client_privacy_requests(id);


--
-- Name: client_members fk_rails_4549b9cedb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_members
    ADD CONSTRAINT fk_rails_4549b9cedb FOREIGN KEY (member_id) REFERENCES public.members(id) ON DELETE CASCADE;


--
-- Name: client_member_discoveries fk_rails_4a028721b4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_discoveries
    ADD CONSTRAINT fk_rails_4a028721b4 FOREIGN KEY (member_id) REFERENCES public.members(id);


--
-- Name: client_persona_view_grants fk_rails_4ab2eba395; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_view_grants
    ADD CONSTRAINT fk_rails_4ab2eba395 FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: enterprise_delegation_grants fk_rails_4dbe6f07b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_delegation_grants
    ADD CONSTRAINT fk_rails_4dbe6f07b9 FOREIGN KEY (enterprise_id) REFERENCES public.enterprises(id);


--
-- Name: persona_memberships fk_rails_4f3c994599; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT fk_rails_4f3c994599 FOREIGN KEY (membership_kind_id) REFERENCES public.persona_membership_kinds(id);


--
-- Name: client_profiles fk_rails_510843a98e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profiles
    ADD CONSTRAINT fk_rails_510843a98e FOREIGN KEY (client_status_id) REFERENCES public.client_profile_statuses(id);


--
-- Name: client_totp_credentials fk_rails_5146d3e196; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_totp_credentials
    ADD CONSTRAINT fk_rails_5146d3e196 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: persona_memberships fk_rails_523bf01343; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT fk_rails_523bf01343 FOREIGN KEY (enterprise_unit_id) REFERENCES public.enterprise_units(id);


--
-- Name: persona_memberships fk_rails_529c28deb1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT fk_rails_529c28deb1 FOREIGN KEY (granted_by_persona_id) REFERENCES public.personas(id) ON DELETE SET NULL;


--
-- Name: enterprise_ownership_transfer_requests fk_rails_54f006988a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_ownership_transfer_requests
    ADD CONSTRAINT fk_rails_54f006988a FOREIGN KEY (destination_client_id) REFERENCES public.clients(id);


--
-- Name: client_enforcement_recovery_ceremonies fk_rails_589be2c97e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_enforcement_recovery_ceremonies
    ADD CONSTRAINT fk_rails_589be2c97e FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: client_member_suspensions fk_rails_59ba0ab07d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_suspensions
    ADD CONSTRAINT fk_rails_59ba0ab07d FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_member_deletions fk_rails_5a97c3e343; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_deletions
    ADD CONSTRAINT fk_rails_5a97c3e343 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_privacy_requests fk_rails_5bd919c664; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_privacy_requests
    ADD CONSTRAINT fk_rails_5bd919c664 FOREIGN KEY (status_id) REFERENCES public.client_privacy_request_statuses(id);


--
-- Name: user_client_deletions fk_rails_5c75a5e7b0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_deletions
    ADD CONSTRAINT fk_rails_5c75a5e7b0 FOREIGN KEY (client_id) REFERENCES public.legacy_replaced_clients(id);


--
-- Name: enterprise_ownerships fk_rails_5d20706d60; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_ownerships
    ADD CONSTRAINT fk_rails_5d20706d60 FOREIGN KEY (enterprise_id) REFERENCES public.enterprises(id);


--
-- Name: client_authority_locks fk_rails_5deca3cb88; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_authority_locks
    ADD CONSTRAINT fk_rails_5deca3cb88 FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: client_persona_delegation_grants fk_rails_5e5225af87; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_delegation_grants
    ADD CONSTRAINT fk_rails_5e5225af87 FOREIGN KEY (client_persona_id) REFERENCES public.personas(id);


--
-- Name: user_client_observations fk_rails_61e7ab5f14; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_observations
    ADD CONSTRAINT fk_rails_61e7ab5f14 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_retention_holds fk_rails_64254cb3f7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_retention_holds
    ADD CONSTRAINT fk_rails_64254cb3f7 FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: user_client_discoveries fk_rails_64edfa59fc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_discoveries
    ADD CONSTRAINT fk_rails_64edfa59fc FOREIGN KEY (client_id) REFERENCES public.legacy_replaced_clients(id);


--
-- Name: clients fk_rails_67ec2e6839; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT fk_rails_67ec2e6839 FOREIGN KEY (mfa_status_id) REFERENCES public.client_mfa_statuses(id);


--
-- Name: enterprise_ownership_transfer_requests fk_rails_6f4cf04cde; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_ownership_transfer_requests
    ADD CONSTRAINT fk_rails_6f4cf04cde FOREIGN KEY (source_client_id) REFERENCES public.clients(id);


--
-- Name: client_persona_view_grants fk_rails_701a8325ef; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_view_grants
    ADD CONSTRAINT fk_rails_701a8325ef FOREIGN KEY (client_persona_id) REFERENCES public.personas(id);


--
-- Name: client_member_impersonations fk_rails_7148fa7540; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_impersonations
    ADD CONSTRAINT fk_rails_7148fa7540 FOREIGN KEY (member_id) REFERENCES public.members(id);


--
-- Name: client_processor_erasure_notifications fk_rails_71bb2fb3df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_processor_erasure_notifications
    ADD CONSTRAINT fk_rails_71bb2fb3df FOREIGN KEY (status_id) REFERENCES public.client_processor_erasure_notification_statuses(id);


--
-- Name: client_member_revocations fk_rails_7311994ef4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_revocations
    ADD CONSTRAINT fk_rails_7311994ef4 FOREIGN KEY (member_id) REFERENCES public.members(id);


--
-- Name: client_withdrawal_flow_events fk_rails_7344701780; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_7344701780 FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE;


--
-- Name: clients fk_rails_73fa0fcaee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT fk_rails_73fa0fcaee FOREIGN KEY (mfa_level_id) REFERENCES public.client_mfa_levels(id);


--
-- Name: enterprise_units fk_rails_7793aa24bc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_units
    ADD CONSTRAINT fk_rails_7793aa24bc FOREIGN KEY (enterprise_id) REFERENCES public.enterprises(id);


--
-- Name: client_member_revocations fk_rails_7be747ff66; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_revocations
    ADD CONSTRAINT fk_rails_7be747ff66 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_telephones fk_rails_7d903b3fd3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_telephones
    ADD CONSTRAINT fk_rails_7d903b3fd3 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: user_client_revocations fk_rails_7fd74473b8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_revocations
    ADD CONSTRAINT fk_rails_7fd74473b8 FOREIGN KEY (client_id) REFERENCES public.legacy_replaced_clients(id);


--
-- Name: client_member_observations fk_rails_80174a8986; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_observations
    ADD CONSTRAINT fk_rails_80174a8986 FOREIGN KEY (member_id) REFERENCES public.members(id);


--
-- Name: client_persona_usage_grants fk_rails_828debcf19; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_usage_grants
    ADD CONSTRAINT fk_rails_828debcf19 FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: persona_assignments fk_rails_849865fa8f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_assignments
    ADD CONSTRAINT fk_rails_849865fa8f FOREIGN KEY (persona_id) REFERENCES public.personas(id);


--
-- Name: enterprise_delegation_grants fk_rails_88a00231c9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_delegation_grants
    ADD CONSTRAINT fk_rails_88a00231c9 FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: client_preference_page_sizes fk_rails_8c10421fba; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_page_sizes
    ADD CONSTRAINT fk_rails_8c10421fba FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- Name: personas fk_rails_8dc042a1c9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personas
    ADD CONSTRAINT fk_rails_8dc042a1c9 FOREIGN KEY (client_identity_id) REFERENCES public.client_identities(id) ON DELETE RESTRICT;


--
-- Name: enterprise_unit_closures fk_rails_8e0192642e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_unit_closures
    ADD CONSTRAINT fk_rails_8e0192642e FOREIGN KEY (descendant_id) REFERENCES public.enterprise_units(id);


--
-- Name: client_preference_adult_content_gates fk_rails_8e51082240; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_adult_content_gates
    ADD CONSTRAINT fk_rails_8e51082240 FOREIGN KEY (option_id) REFERENCES public.client_preference_adult_content_gate_options(id);


--
-- Name: enterprise_administration_grants fk_rails_8ec27fc77a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_administration_grants
    ADD CONSTRAINT fk_rails_8ec27fc77a FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: client_persona_ownership_transfer_requests fk_rails_8f473b0328; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_ownership_transfer_requests
    ADD CONSTRAINT fk_rails_8f473b0328 FOREIGN KEY (source_client_id) REFERENCES public.clients(id);


--
-- Name: legacy_replaced_clients fk_rails_910109bee1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_replaced_clients
    ADD CONSTRAINT fk_rails_910109bee1 FOREIGN KEY (client_status_id) REFERENCES public.legacy_replaced_client_statuses(id);


--
-- Name: client_preference_densities fk_rails_92ff4cec37; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_densities
    ADD CONSTRAINT fk_rails_92ff4cec37 FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- Name: client_withdrawal_ceremonies fk_rails_9386315187; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_ceremonies
    ADD CONSTRAINT fk_rails_9386315187 FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: client_member_discoveries fk_rails_93b97b3c26; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_discoveries
    ADD CONSTRAINT fk_rails_93b97b3c26 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: app_enforcement_identifier_effects fk_rails_948f351e94; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_enforcement_identifier_effects
    ADD CONSTRAINT fk_rails_948f351e94 FOREIGN KEY (app_enforcement_case_id) REFERENCES public.app_enforcement_cases(id);


--
-- Name: client_withdrawal_flow_events fk_rails_9511d96f8c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_9511d96f8c FOREIGN KEY (to_status_id) REFERENCES public.client_withdrawal_flow_statuses(id) ON DELETE RESTRICT;


--
-- Name: client_member_observations fk_rails_951fe9a437; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_observations
    ADD CONSTRAINT fk_rails_951fe9a437 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: members fk_rails_958fda1156; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members
    ADD CONSTRAINT fk_rails_958fda1156 FOREIGN KEY (status_id) REFERENCES public.member_statuses(id);


--
-- Name: client_preference_page_sizes fk_rails_991df7332c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_page_sizes
    ADD CONSTRAINT fk_rails_991df7332c FOREIGN KEY (option_id) REFERENCES public.client_preference_page_size_options(id);


--
-- Name: user_client_suspensions fk_rails_9bd8ae64a6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_suspensions
    ADD CONSTRAINT fk_rails_9bd8ae64a6 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: user_client_impersonations fk_rails_a7f1ca79fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_impersonations
    ADD CONSTRAINT fk_rails_a7f1ca79fd FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: app_enforcement_principal_effects fk_rails_a7ff4f6c71; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_enforcement_principal_effects
    ADD CONSTRAINT fk_rails_a7ff4f6c71 FOREIGN KEY (app_enforcement_case_id) REFERENCES public.app_enforcement_cases(id);


--
-- Name: user_client_discoveries fk_rails_a8523d9333; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_discoveries
    ADD CONSTRAINT fk_rails_a8523d9333 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: app_enforcement_appeals fk_rails_a976d1689b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_enforcement_appeals
    ADD CONSTRAINT fk_rails_a976d1689b FOREIGN KEY (app_enforcement_case_id) REFERENCES public.app_enforcement_cases(id);


--
-- Name: client_external_identities fk_rails_abadb8885a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_external_identities
    ADD CONSTRAINT fk_rails_abadb8885a FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: enterprise_lifecycles fk_rails_ac12e249af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_lifecycles
    ADD CONSTRAINT fk_rails_ac12e249af FOREIGN KEY (enterprise_id) REFERENCES public.enterprises(id) ON DELETE RESTRICT;


--
-- Name: user_client_impersonations fk_rails_b0deaee0e3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_impersonations
    ADD CONSTRAINT fk_rails_b0deaee0e3 FOREIGN KEY (client_id) REFERENCES public.legacy_replaced_clients(id);


--
-- Name: client_privacy_requests fk_rails_b3a209b2e0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_privacy_requests
    ADD CONSTRAINT fk_rails_b3a209b2e0 FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: enterprise_ownership_transfer_requests fk_rails_b45ea7f67c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_ownership_transfer_requests
    ADD CONSTRAINT fk_rails_b45ea7f67c FOREIGN KEY (enterprise_id) REFERENCES public.enterprises(id);


--
-- Name: client_withdrawal_flow_events fk_rails_b55e5a56c4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_b55e5a56c4 FOREIGN KEY (client_withdrawal_flow_id) REFERENCES public.client_withdrawal_flows(id);


--
-- Name: persona_memberships fk_rails_b787ae6cc4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT fk_rails_b787ae6cc4 FOREIGN KEY (enterprise_id) REFERENCES public.enterprises(id);


--
-- Name: enterprise_units fk_rails_ba9e99577f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_units
    ADD CONSTRAINT fk_rails_ba9e99577f FOREIGN KEY (parent_id) REFERENCES public.enterprise_units(id);


--
-- Name: enterprise_ownerships fk_rails_c14f4d862b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_ownerships
    ADD CONSTRAINT fk_rails_c14f4d862b FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: persona_assignments fk_rails_c24cce429b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_assignments
    ADD CONSTRAINT fk_rails_c24cce429b FOREIGN KEY (client_identity_id) REFERENCES public.client_identities(id);


--
-- Name: client_profiles fk_rails_c49c0906dc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profiles
    ADD CONSTRAINT fk_rails_c49c0906dc FOREIGN KEY (status_id) REFERENCES public.client_profile_statuses(id);


--
-- Name: client_oidc_identity_bindings fk_rails_c5793099a1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_oidc_identity_bindings
    ADD CONSTRAINT fk_rails_c5793099a1 FOREIGN KEY (client_identity_id) REFERENCES public.client_identities(id) ON DELETE RESTRICT;


--
-- Name: client_telephones fk_rails_c81d47bc96; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_telephones
    ADD CONSTRAINT fk_rails_c81d47bc96 FOREIGN KEY (user_identity_telephone_status_id) REFERENCES public.client_telephone_statuses(id);


--
-- Name: clients fk_rails_c9df50d461; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT fk_rails_c9df50d461 FOREIGN KEY (visibility_id) REFERENCES public.client_visibilities(id);


--
-- Name: persona_memberships fk_rails_cdfe640663; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT fk_rails_cdfe640663 FOREIGN KEY (revoked_by_persona_id) REFERENCES public.personas(id) ON DELETE SET NULL;


--
-- Name: clients fk_rails_ce4a327a04; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT fk_rails_ce4a327a04 FOREIGN KEY (status_id) REFERENCES public.client_statuses(id);


--
-- Name: client_bulletins fk_rails_cedaf1b735; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_bulletins
    ADD CONSTRAINT fk_rails_cedaf1b735 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_persona_delegation_grants fk_rails_d09d3ca4e5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_delegation_grants
    ADD CONSTRAINT fk_rails_d09d3ca4e5 FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: client_members fk_rails_d1678b342d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_members
    ADD CONSTRAINT fk_rails_d1678b342d FOREIGN KEY (user_id) REFERENCES public.clients(id) ON DELETE CASCADE;


--
-- Name: client_persona_ownership_transfer_requests fk_rails_d7c3a63746; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_ownership_transfer_requests
    ADD CONSTRAINT fk_rails_d7c3a63746 FOREIGN KEY (client_persona_id) REFERENCES public.personas(id);


--
-- Name: client_secret_issuances fk_rails_da68d427e0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_issuances
    ADD CONSTRAINT fk_rails_da68d427e0 FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: client_preference_adult_content_gates fk_rails_db31dff0ff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_adult_content_gates
    ADD CONSTRAINT fk_rails_db31dff0ff FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- Name: apple_auths fk_rails_db7b8ce293; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apple_auths
    ADD CONSTRAINT fk_rails_db7b8ce293 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: user_clients fk_rails_dd94a5910e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_clients
    ADD CONSTRAINT fk_rails_dd94a5910e FOREIGN KEY (user_id) REFERENCES public.clients(id) ON DELETE CASCADE;


--
-- Name: persona_memberships fk_rails_e031c03097; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT fk_rails_e031c03097 FOREIGN KEY (approved_by_persona_id) REFERENCES public.personas(id) ON DELETE SET NULL;


--
-- Name: app_enforcement_principal_links fk_rails_e04b2bda45; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_enforcement_principal_links
    ADD CONSTRAINT fk_rails_e04b2bda45 FOREIGN KEY (app_enforcement_case_id) REFERENCES public.app_enforcement_cases(id);


--
-- Name: client_withdrawal_flows fk_rails_e5e99fd372; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flows
    ADD CONSTRAINT fk_rails_e5e99fd372 FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: client_memberships fk_rails_e670a4dd3b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_memberships
    ADD CONSTRAINT fk_rails_e670a4dd3b FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_persona_administration_grants fk_rails_e96f0d0621; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_administration_grants
    ADD CONSTRAINT fk_rails_e96f0d0621 FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: client_retention_holds fk_rails_e971c7082b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_retention_holds
    ADD CONSTRAINT fk_rails_e971c7082b FOREIGN KEY (status_id) REFERENCES public.client_retention_hold_statuses(id);


--
-- Name: client_member_impersonations fk_rails_ec8f1933d6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_impersonations
    ADD CONSTRAINT fk_rails_ec8f1933d6 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_telephone_histories fk_rails_ec8f69eb6b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_telephone_histories
    ADD CONSTRAINT fk_rails_ec8f69eb6b FOREIGN KEY (user_id) REFERENCES public.clients(id) ON DELETE RESTRICT;


--
-- Name: user_client_observations fk_rails_ed2cc58750; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_observations
    ADD CONSTRAINT fk_rails_ed2cc58750 FOREIGN KEY (client_id) REFERENCES public.legacy_replaced_clients(id);


--
-- Name: client_totp_credentials fk_rails_ee2c1859b3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_totp_credentials
    ADD CONSTRAINT fk_rails_ee2c1859b3 FOREIGN KEY (user_identity_totp_credential_status_id) REFERENCES public.client_totp_credential_statuses(id);


--
-- Name: enterprise_view_grants fk_rails_ee327c288c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_view_grants
    ADD CONSTRAINT fk_rails_ee327c288c FOREIGN KEY (enterprise_id) REFERENCES public.enterprises(id);


--
-- Name: client_member_suspensions fk_rails_f0f64ec73d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_suspensions
    ADD CONSTRAINT fk_rails_f0f64ec73d FOREIGN KEY (member_id) REFERENCES public.members(id);


--
-- Name: client_withdrawal_flow_events fk_rails_f24d4919a7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_f24d4919a7 FOREIGN KEY (from_status_id) REFERENCES public.client_withdrawal_flow_statuses(id) ON DELETE RESTRICT;


--
-- Name: enterprise_unit_closures fk_rails_f304c4c398; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_unit_closures
    ADD CONSTRAINT fk_rails_f304c4c398 FOREIGN KEY (ancestor_id) REFERENCES public.enterprise_units(id);


--
-- Name: enterprise_administration_grants fk_rails_f45cb78b7c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_administration_grants
    ADD CONSTRAINT fk_rails_f45cb78b7c FOREIGN KEY (enterprise_id) REFERENCES public.enterprises(id);


--
-- Name: client_preference_motions fk_rails_f49048bc2b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_motions
    ADD CONSTRAINT fk_rails_f49048bc2b FOREIGN KEY (option_id) REFERENCES public.client_preference_motion_options(id);


--
-- Name: client_passkeys fk_rails_f5e90919e8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_passkeys
    ADD CONSTRAINT fk_rails_f5e90919e8 FOREIGN KEY (status_id) REFERENCES public.client_passkey_statuses(id);


--
-- Name: client_persona_administration_grants fk_rails_f6df43c925; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_administration_grants
    ADD CONSTRAINT fk_rails_f6df43c925 FOREIGN KEY (client_persona_id) REFERENCES public.personas(id);


--
-- Name: client_email_histories fk_rails_fbd6bd4806; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_email_histories
    ADD CONSTRAINT fk_rails_fbd6bd4806 FOREIGN KEY (user_id) REFERENCES public.clients(id) ON DELETE RESTRICT;


--
-- Name: client_persona_lifecycles fk_rails_fc7a83d40a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_persona_lifecycles
    ADD CONSTRAINT fk_rails_fc7a83d40a FOREIGN KEY (client_persona_id) REFERENCES public.personas(id) ON DELETE RESTRICT;


--
-- Name: user_client_revocations fk_rails_fdc3477c5a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_revocations
    ADD CONSTRAINT fk_rails_fdc3477c5a FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_preference_languages fk_user_preference_languages_on_option_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_languages
    ADD CONSTRAINT fk_user_preference_languages_on_option_id FOREIGN KEY (option_id) REFERENCES public.client_preference_language_options(id);


--
-- Name: client_preference_languages fk_user_preference_languages_on_preference_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_languages
    ADD CONSTRAINT fk_user_preference_languages_on_preference_id FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- Name: client_preference_regions fk_user_preference_regions_on_option_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_regions
    ADD CONSTRAINT fk_user_preference_regions_on_option_id FOREIGN KEY (option_id) REFERENCES public.client_preference_region_options(id);


--
-- Name: client_preference_regions fk_user_preference_regions_on_preference_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_regions
    ADD CONSTRAINT fk_user_preference_regions_on_preference_id FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- Name: client_preference_themes fk_user_preference_themes_on_option_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_themes
    ADD CONSTRAINT fk_user_preference_themes_on_option_id FOREIGN KEY (option_id) REFERENCES public.client_preference_theme_options(id);


--
-- Name: client_preference_themes fk_user_preference_themes_on_preference_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_themes
    ADD CONSTRAINT fk_user_preference_themes_on_preference_id FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- Name: client_preference_timezones fk_user_preference_timezones_on_option_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_timezones
    ADD CONSTRAINT fk_user_preference_timezones_on_option_id FOREIGN KEY (option_id) REFERENCES public.client_preference_timezone_options(id);


--
-- Name: client_preference_timezones fk_user_preference_timezones_on_preference_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_timezones
    ADD CONSTRAINT fk_user_preference_timezones_on_preference_id FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261019120004'),
('20261019120002'),
('20261019120000'),
('20261016210003'),
('20261016210000'),
('20261012093100'),
('20261012093000'),
('20261012092100'),
('20261012092000'),
('20261012091001'),
('20261012091000'),
('20261012083823'),
('20261012083817'),
('20261010232748'),
('20261010230339'),
('20261009211717'),
('20261009211605'),
('20261009204005'),
('20261008025001'),
('20261007224308'),
('20261007220227'),
('20261007193033'),
('20261007192959'),
('20261007183026'),
('20261007182133'),
('20261007182023'),
('20261007134406'),
('20261007124539'),
('20261007122511'),
('20261007122429'),
('20261007050002'),
('20261007050001'),
('20261007050000'),
('20261007040000'),
('20261007030000'),
('20261007020000'),
('20261006180000'),
('20261006110000'),
('20261005063605'),
('20261005053049'),
('20261003215326'),
('20261003202225'),
('20260926170000'),
('20260923180000'),
('20260923170000'),
('20260923160000'),
('20260923150000'),
('20260923140000'),
('20260922130000'),
('20260921133000'),
('20260920110001'),
('20260920110000'),
('20260919120000'),
('20260917120000'),
('20260911120000'),
('20260831064103'),
('20260830120000'),
('20260731121000'),
('20260729130000'),
('20260729120000'),
('20260727140001'),
('20260727140000'),
('20260727120004'),
('20260727120003'),
('20260727120002'),
('20260727120001'),
('20260727120000'),
('20260724201700'),
('20260724201600'),
('20260724201500'),
('20260724201400'),
('20260724201300'),
('20260724201200'),
('20260724201100'),
('20260724201000'),
('20260724200000'),
('20260724190000'),
('20260721090000'),
('20260719100001'),
('20260719100000'),
('20260714100000'),
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
('20260620123000'),
('20260616150020'),
('20260616150011'),
('20260616150010'),
('20260616150006'),
('20260616150005'),
('20260614090001'),
('20260614090000'),
('20260612100000'),
('20260612000001'),
('20260530032500'),
('20260530032400'),
('20260530032300'),
('20260530032100'),
('20260530032000'),
('20260530031001'),
('20260530031000'),
('20260528162000'),
('20260526130000'),
('20260526090000'),
('20260525200000'),
('20260525131000'),
('20260525120000'),
('20260520143100'),
('20260520143003'),
('20260520143001'),
('20260520143000'),
('20260520133000'),
('20260520120000'),
('20260519172001'),
('20260519172000'),
('20260519161000'),
('20260519094000'),
('20260518181000'),
('20260518180002'),
('20260518180001'),
('20260518180000'),
('20260518170001'),
('20260518170000'),
('20260518163000'),
('20260518120001'),
('20260518120000'),
('20260518085551'),
('20260514143000'),
('20260514140000'),
('20260514100000'),
('20260514063700'),
('20260514062000'),
('20260513161000'),
('20260513153000'),
('20260513122000'),
('20260513120000'),
('20260512120000'),
('20260512110000'),
('20260512103000'),
('20260512102000'),
('20260512101000'),
('20260512100000'),
('20260511223500'),
('20260511223447'),
('20260511223446'),
('20260511090000'),
('20260508202200'),
('20260508151000'),
('20260508140999'),
('20260508140930'),
('20260508135007'),
('20260508135006'),
('20260507000007'),
('20260507000006'),
('20260507000005'),
('20260507000004'),
('20260507000003'),
('20260507000001'),
('20260506210900'),
('20260330000000'),
('20260329150500'),
('20260329084515'),
('20260323013703'),
('20260322100000'),
('20260319125137'),
('20260318050103'),
('20260318050102'),
('20260318035439'),
('20260312200000'),
('20260309000001'),
('20260307121000'),
('20260307120000'),
('20260305114353'),
('20260305114343'),
('20260305114342'),
('20260305114341'),
('20260305114340'),
('20260305114339'),
('20260305114338'),
('20260305114337'),
('20260305114336'),
('20260305114335'),
('20260226150000'),
('20260226130000'),
('20260226100000'),
('20260224170000'),
('20260213150000'),
('20260213010000'),
('20260212000001'),
('20260210123000'),
('20260210120000'),
('20260210100000'),
('20260209090000'),
('20260208193000'),
('20260208180000'),
('20260208170000'),
('20260208152950'),
('20260205150000'),
('20260205140539'),
('20260204170000'),
('20260204160000'),
('20260204150845'),
('20260204133256'),
('20260204133143'),
('20260203172000'),
('20260203160000'),
('20260202260000'),
('20260202250001'),
('20260202250000'),
('20260202230000'),
('20260202220000'),
('20260202210000'),
('20260202200100'),
('20260202200000'),
('20260202185000'),
('20260202160000'),
('20260201214420'),
('20260201210004'),
('20260201190008'),
('20260131149000'),
('20260131140011'),
('20260131140010'),
('20260131140009'),
('20260131140008'),
('20260131140007'),
('20260131140006'),
('20260131140005'),
('20260131140004'),
('20260131140003'),
('20260131140002'),
('20260131140001'),
('20260131140000'),
('20260130130002'),
('20260130114404'),
('20260124174000'),
('20260123172135'),
('20260123162700'),
('20260122100002'),
('20260122100000'),
('20260121184557'),
('20260121084849'),
('20260121083250'),
('20260121083248'),
('20260121083246'),
('20260121000001'),
('20260121000000'),
('20260119051226'),
('20260115120000'),
('20260114120221'),
('20260111120000'),
('20260110194100'),
('20260109141212'),
('20260108100600'),
('20260106120000'),
('20260106110000'),
('20260105150000'),
('20260103122036'),
('20260102100034'),
('20260102100033'),
('20260102100032'),
('20260102100031'),
('20260102100030'),
('20260102100029'),
('20260102100028'),
('20260102100025'),
('20260102100024'),
('20260102100023'),
('20260102100022'),
('20260102100021'),
('20260102100020'),
('20260102100015'),
('20260102100012'),
('20260102100008'),
('20260102100001'),
('20260102100000'),
('20260102091045'),
('20260102080321'),
('20260102080314'),
('20260102080308'),
('20260102080302'),
('20260102080255'),
('20260102080241'),
('20260102035039'),
('20260102035038'),
('20260102035008'),
('20251230170005'),
('20251230150021'),
('20251230150010'),
('20251230145346'),
('20251230145332'),
('20251230140819'),
('20251230133000'),
('20251230120001'),
('20251230093100'),
('20251230072244'),
('20251230072243'),
('20251230072242'),
('20251230072235'),
('20251230072105'),
('20251230010100'),
('20251227230020'),
('20251227223116'),
('20251226020999'),
('20251226013000'),
('20251226000001'),
('20251225213914'),
('20251225183101'),
('20251225000000'),
('20251224190010'),
('20251224190001'),
('20251224184759'),
('20251224173428'),
('20251224173000'),
('20251224172000'),
('20251224171000'),
('20251224170000'),
('20251224164000'),
('20251224163000'),
('20251224162000'),
('20251224161000'),
('20251224154201'),
('20251224152201'),
('20251224140101'),
('20251224130001'),
('20251224123201'),
('20251224122001'),
('20251222213000'),
('20251222212000'),
('20251222205830'),
('20251221134000'),
('20251221133001'),
('20251221130000'),
('20251221120000'),
('20251220185352'),
('20251218150000'),
('20251218141000'),
('20251218120013'),
('20251218120012'),
('20251218120011'),
('20251218120010'),
('20251216132111'),
('20251216131717'),
('20251214141739'),
('20251214133950'),
('20251214133800'),
('20251213160233'),
('20251213154426'),
('20251213153719'),
('20251212163549'),
('20251212163547'),
('20251212163546'),
('20251212163545'),
('20251212163543'),
('20251212163542'),
('20251212163539'),
('20251212163538'),
('20251212163537'),
('20251212163536'),
('20251212163535'),
('20251212163534'),
('20251212163533'),
('20251212163532'),
('20251211170000'),
('20251211163810'),
('20251211163754'),
('20251211163301'),
('20251211163246'),
('20251211100100'),
('20251211100000'),
('20251211081312'),
('20251209143001'),
('20251209123000'),
('20251209020001'),
('20251209014633'),
('20251208230201'),
('20251208230102'),
('20251208223048'),
('20251208211448'),
('20251208210540'),
('20251208054613'),
('20251115084000'),
('20251115081000'),
('20251115080000'),
('20251115076000'),
('20251115075000'),
('20251115074000'),
('20251115072000'),
('20251115070000'),
('20251115061000'),
('20251114051724'),
('20250808064814'),
('20250803215056'),
('20250803215016'),
('20250801193448'),
('20250429234642'),
('20250429231842'),
('20250421131400'),
('20240830171643'),
('20240830171634'),
('20240827130201'),
('20240627130203');

