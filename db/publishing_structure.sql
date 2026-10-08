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
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: publishing_assert_version_media_complete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_assert_version_media_complete() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public'
    AS $_$ DECLARE versions_table text := TG_ARGV[0]; rev_media text := TG_ARGV[1]; ver_media text := TG_ARGV[2]; target_version_id bigint; source_revision_id bigint; mismatch integer; BEGIN IF TG_TABLE_NAME = versions_table THEN target_version_id := NEW.id; ELSE target_version_id := NEW.entry_version_id; END IF; EXECUTE format('SELECT entry_revision_id FROM public.%I WHERE id = $1', versions_table) INTO source_revision_id USING target_version_id; IF source_revision_id IS NULL THEN RETURN NULL; END IF; EXECUTE format( 'SELECT count(*) FROM ( (SELECT media_file_id, role, field_path, block_path, position, alt_text, caption, presentation_metadata FROM public.%I WHERE entry_revision_id = $1 EXCEPT ALL SELECT media_file_id, role, field_path, block_path, position, alt_text, caption, presentation_metadata FROM public.%I WHERE entry_version_id = $2) UNION ALL (SELECT media_file_id, role, field_path, block_path, position, alt_text, caption, presentation_metadata FROM public.%I WHERE entry_version_id = $2 EXCEPT ALL SELECT media_file_id, role, field_path, block_path, position, alt_text, caption, presentation_metadata FROM public.%I WHERE entry_revision_id = $1) ) d', rev_media, ver_media, ver_media, rev_media) INTO mismatch USING source_revision_id, target_version_id; IF mismatch > 0 THEN RAISE EXCEPTION 'publishing media: version % usages do not match revision %', target_version_id, source_revision_id USING ERRCODE = 'integrity_constraint_violation'; END IF; RETURN NULL; END; $_$;


--
-- Name: publishing_assert_version_snapshot_complete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_assert_version_snapshot_complete() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public'
    AS $_$ DECLARE versions_table text := TG_ARGV[0]; rev_single text := TG_ARGV[1]; ver_single text := TG_ARGV[2]; rev_multi text := TG_ARGV[3]; ver_multi text := TG_ARGV[4]; target_version_id bigint; source_revision_id bigint; mismatch integer; BEGIN IF TG_TABLE_NAME = versions_table THEN target_version_id := NEW.id; ELSE target_version_id := NEW.entry_version_id; END IF; EXECUTE format('SELECT entry_revision_id FROM public.%I WHERE id = $1', versions_table) INTO source_revision_id USING target_version_id; IF source_revision_id IS NULL THEN RETURN NULL; END IF; EXECUTE format( 'SELECT count(*) FROM ( (SELECT vocabulary_id, taxonomy_term_id FROM public.%I WHERE entry_revision_id = $1 EXCEPT ALL SELECT vocabulary_id, taxonomy_term_id FROM public.%I WHERE entry_version_id = $2) UNION ALL (SELECT vocabulary_id, taxonomy_term_id FROM public.%I WHERE entry_version_id = $2 EXCEPT ALL SELECT vocabulary_id, taxonomy_term_id FROM public.%I WHERE entry_revision_id = $1) ) d', rev_single, ver_single, ver_single, rev_single) INTO mismatch USING source_revision_id, target_version_id; IF mismatch > 0 THEN RAISE EXCEPTION 'publishing taxonomy: version % single-valued snapshots do not match revision %', target_version_id, source_revision_id USING ERRCODE = 'integrity_constraint_violation'; END IF; EXECUTE format( 'SELECT count(*) FROM ( (SELECT vocabulary_id, taxonomy_term_id, position FROM public.%I WHERE entry_revision_id = $1 EXCEPT ALL SELECT vocabulary_id, taxonomy_term_id, position FROM public.%I WHERE entry_version_id = $2) UNION ALL (SELECT vocabulary_id, taxonomy_term_id, position FROM public.%I WHERE entry_version_id = $2 EXCEPT ALL SELECT vocabulary_id, taxonomy_term_id, position FROM public.%I WHERE entry_revision_id = $1) ) d', rev_multi, ver_multi, ver_multi, rev_multi) INTO mismatch USING source_revision_id, target_version_id; IF mismatch > 0 THEN RAISE EXCEPTION 'publishing taxonomy: version % ordered snapshots do not match revision %', target_version_id, source_revision_id USING ERRCODE = 'integrity_constraint_violation'; END IF; RETURN NULL; END; $_$;


--
-- Name: publishing_promoted_revision_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_promoted_revision_guard() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public'
    AS $_$ DECLARE versions_table text := TG_ARGV[0]; subject_revision_id bigint; promoted_version_id bigint; BEGIN IF TG_TABLE_NAME LIKE '%entry_revisions' THEN IF TG_OP = 'DELETE' THEN subject_revision_id := OLD.id; ELSE subject_revision_id := NEW.id; END IF; ELSIF TG_OP = 'DELETE' THEN subject_revision_id := OLD.entry_revision_id; ELSE subject_revision_id := NEW.entry_revision_id; END IF; EXECUTE format('SELECT id FROM public.%I WHERE entry_revision_id = $1', versions_table) INTO promoted_version_id USING subject_revision_id; IF promoted_version_id IS NOT NULL THEN RAISE EXCEPTION 'publishing: revision % was promoted into version % and can no longer change (attempted % on %)', subject_revision_id, promoted_version_id, TG_OP, TG_TABLE_NAME USING ERRCODE = 'restrict_violation'; END IF; IF TG_OP = 'DELETE' THEN RETURN OLD; END IF; RETURN NEW; END; $_$;


--
-- Name: publishing_reject_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_reject_mutation() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public'
    AS $$ BEGIN RAISE EXCEPTION 'publishing: % is immutable (attempted %)', TG_TABLE_NAME, TG_OP; END; $$;


--
-- Name: publishing_reject_retirement_by_deletion(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_reject_retirement_by_deletion() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public'
    AS $$ BEGIN RAISE EXCEPTION 'publishing taxonomy: % rows are retired by archiving, never deleted (id %)', TG_TABLE_NAME, OLD.id USING ERRCODE = 'restrict_violation'; END; $$;


--
-- Name: publishing_taxonomy_term_hierarchy_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_taxonomy_term_hierarchy_guard() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public'
    AS $_$ DECLARE terms_table text := TG_ARGV[0]; parent_depth integer; cycle_found boolean; BEGIN IF NEW.parent_id IS NULL THEN RETURN NEW; END IF; EXECUTE format('SELECT depth FROM public.%I WHERE id = $1', terms_table) INTO parent_depth USING NEW.parent_id; IF parent_depth IS NULL THEN RAISE EXCEPTION 'publishing taxonomy: parent term % not found', NEW.parent_id; END IF; IF NEW.depth <> parent_depth + 1 THEN RAISE EXCEPTION 'publishing taxonomy: depth % must equal parent depth % plus one', NEW.depth, parent_depth; END IF; EXECUTE format( 'SELECT EXISTS ( WITH RECURSIVE ancestors(id, parent_id, level) AS ( SELECT t.id, t.parent_id, 1 FROM public.%I t WHERE t.id = $1 UNION ALL SELECT t.id, t.parent_id, a.level + 1 FROM public.%I t JOIN ancestors a ON t.id = a.parent_id WHERE a.level <= %s + 1 ) SELECT 1 FROM ancestors WHERE id = $2 )', terms_table, terms_table, 8) INTO cycle_found USING NEW.parent_id, NEW.id; IF cycle_found THEN RAISE EXCEPTION 'publishing taxonomy: term % cannot descend from itself', NEW.id; END IF; RETURN NEW; END; $_$;


--
-- Name: publishing_taxonomy_term_path(text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_taxonomy_term_path(terms_table text, target_id bigint) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    SET search_path TO 'pg_catalog', 'public'
    AS $_$ DECLARE result jsonb; BEGIN EXECUTE format( $q$ WITH RECURSIVE chain(id, parent_id, public_id, slug, name, level) AS ( SELECT t.id, t.parent_id, t.public_id, t.slug, t.name, 0 FROM public.%I t WHERE t.id = $1 UNION ALL SELECT t.id, t.parent_id, t.public_id, t.slug, t.name, c.level + 1 FROM public.%I t JOIN chain c ON t.id = c.parent_id ) SELECT coalesce( jsonb_agg(jsonb_build_object('public_id', public_id, 'slug', slug, 'name', name) ORDER BY level DESC), '[]'::jsonb ) FROM chain $q$, terms_table, terms_table) INTO result USING target_id; RETURN result; END; $_$;


--
-- Name: publishing_valid_term_path(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_valid_term_path(path jsonb) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'pg_catalog', 'public'
    AS $$ SELECT jsonb_typeof(path) = 'array' AND NOT EXISTS ( SELECT 1 FROM jsonb_array_elements(path) AS element(value) WHERE jsonb_typeof(element.value) <> 'object' OR jsonb_typeof(element.value -> 'public_id') IS DISTINCT FROM 'string' OR jsonb_typeof(element.value -> 'slug') IS DISTINCT FROM 'string' OR jsonb_typeof(element.value -> 'name') IS DISTINCT FROM 'string' OR (SELECT count(*) FROM jsonb_object_keys(element.value)) <> 3 ); $$;


--
-- Name: publishing_version_assignment_snapshot(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_version_assignment_snapshot() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public'
    AS $_$ DECLARE vocab_table text := TG_ARGV[0]; terms_table text := TG_ARGV[1]; ordered boolean := TG_ARGV[2] = 'ordered'; vocabulary_public_id text; vocabulary_key text; vocabulary_kind text; term_public_id text; term_slug text; term_name text; term_locale text; BEGIN EXECUTE format('SELECT public_id, key, kind FROM public.%I WHERE id = $1', vocab_table) INTO vocabulary_public_id, vocabulary_key, vocabulary_kind USING NEW.vocabulary_id; EXECUTE format('SELECT public_id, slug, name, locale FROM public.%I WHERE id = $1', terms_table) INTO term_public_id, term_slug, term_name, term_locale USING NEW.taxonomy_term_id; IF vocabulary_public_id IS NULL OR term_public_id IS NULL THEN RAISE EXCEPTION 'publishing taxonomy: cannot snapshot a missing vocabulary or term' USING ERRCODE = 'foreign_key_violation'; END IF; NEW.vocabulary_public_id_snapshot := vocabulary_public_id; NEW.vocabulary_key_snapshot := vocabulary_key; NEW.vocabulary_kind_snapshot := vocabulary_kind; NEW.term_public_id_snapshot := term_public_id; NEW.term_slug_snapshot := term_slug; NEW.term_name_snapshot := term_name; NEW.term_path_snapshot := publishing_taxonomy_term_path(terms_table, NEW.taxonomy_term_id); NEW.locale_snapshot := term_locale; IF ordered THEN NEW.position_snapshot := NEW.position; END IF; RETURN NEW; END; $_$;


--
-- Name: publishing_vocabulary_structure_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_vocabulary_structure_guard() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public'
    AS $$ BEGIN IF NEW.public_id IS DISTINCT FROM OLD.public_id OR NEW.key IS DISTINCT FROM OLD.key OR NEW.kind IS DISTINCT FROM OLD.kind THEN RAISE EXCEPTION 'publishing taxonomy: vocabulary % public_id, key, and kind are frozen after insert', OLD.id USING ERRCODE = 'restrict_violation'; END IF; RETURN NEW; END; $$;


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
-- Name: publishing_docs_app_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_app_entries (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    locale character varying NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    current_revision_id bigint,
    archived_by_operator_public_id character varying(21),
    CONSTRAINT chk_docs_app_ent_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_docs_app_ent_lock CHECK ((lock_version >= 0)),
    CONSTRAINT chk_docs_app_entries_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_docs_app_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_app_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_app_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_app_entries_id_seq OWNED BY public.publishing_docs_app_entries.id;


--
-- Name: publishing_docs_app_entry_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_app_entry_revisions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    restored_from_revision_id bigint,
    restored_from_version_id bigint,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_app_entry_revisions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_docs_app_rev_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_docs_app_rev_restore CHECK ((num_nonnulls(restored_from_revision_id, restored_from_version_id) <= 1)),
    CONSTRAINT chk_docs_app_rev_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_docs_app_rev_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_docs_app_entry_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_app_entry_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_app_entry_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_app_entry_revisions_id_seq OWNED BY public.publishing_docs_app_entry_revisions.id;


--
-- Name: publishing_docs_app_entry_slugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_app_entry_slugs (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    state character varying NOT NULL,
    canonicalized_at timestamp(6) with time zone,
    redirected_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_app_entry_slugs_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_docs_app_slug_format CHECK (((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text)),
    CONSTRAINT chk_docs_app_slug_state CHECK (((state)::text = ANY (ARRAY[('reserved'::character varying)::text, ('canonical'::character varying)::text, ('redirect'::character varying)::text]))),
    CONSTRAINT chk_docs_app_slug_ts CHECK (((((state)::text = 'reserved'::text) AND (canonicalized_at IS NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'canonical'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'redirect'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NOT NULL) AND (redirected_at >= canonicalized_at))))
);


--
-- Name: publishing_docs_app_entry_slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_app_entry_slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_app_entry_slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_app_entry_slugs_id_seq OWNED BY public.publishing_docs_app_entry_slugs.id;


--
-- Name: publishing_docs_app_entry_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_app_entry_versions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_app_entry_versions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_docs_app_ver_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_docs_app_ver_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_docs_app_ver_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_docs_app_entry_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_app_entry_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_app_entry_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_app_entry_versions_id_seq OWNED BY public.publishing_docs_app_entry_versions.id;


--
-- Name: publishing_docs_app_publications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_app_publications (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    effective_from timestamp(6) with time zone NOT NULL,
    effective_until timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    cancellation_reason character varying,
    terminated_at timestamp(6) with time zone,
    termination_reason character varying,
    created_by_operator_public_id character varying(21),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    ended_by_operator_public_id character varying(21),
    CONSTRAINT chk_docs_app_pub_cancel CHECK ((((cancelled_at IS NULL) AND (cancellation_reason IS NULL)) OR ((cancelled_at IS NOT NULL) AND (cancellation_reason IS NOT NULL) AND (cancelled_at < effective_from)))),
    CONSTRAINT chk_docs_app_pub_end_mode CHECK ((NOT ((cancelled_at IS NOT NULL) AND (terminated_at IS NOT NULL)))),
    CONSTRAINT chk_docs_app_pub_term CHECK ((((terminated_at IS NULL) AND (termination_reason IS NULL)) OR ((terminated_at IS NOT NULL) AND (termination_reason IS NOT NULL) AND (terminated_at >= effective_from) AND (effective_until = terminated_at)))),
    CONSTRAINT chk_docs_app_pub_window CHECK (((effective_until IS NULL) OR (effective_until > effective_from))),
    CONSTRAINT chk_docs_app_publications_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_docs_app_publications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_app_publications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_app_publications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_app_publications_id_seq OWNED BY public.publishing_docs_app_publications.id;


--
-- Name: publishing_docs_app_revision_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_app_revision_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_app_rev_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_docs_app_rev_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_docs_app_rev_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_docs_app_revision_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_docs_app_revision_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_app_revision_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_app_revision_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_app_revision_media_usages_id_seq OWNED BY public.publishing_docs_app_revision_media_usages.id;


--
-- Name: publishing_docs_app_revision_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_app_revision_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_app_rm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_docs_app_rm_pos CHECK (("position" >= 0))
);


--
-- Name: publishing_docs_app_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_app_revision_multiple_taxonomy_assignmen_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_app_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_app_revision_multiple_taxonomy_assignmen_id_seq OWNED BY public.publishing_docs_app_revision_multiple_taxonomy_assignments.id;


--
-- Name: publishing_docs_app_revision_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_app_revision_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_app_rs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text))
);


--
-- Name: publishing_docs_app_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_app_revision_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_app_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_app_revision_single_taxonomy_assignments_id_seq OWNED BY public.publishing_docs_app_revision_single_taxonomy_assignments.id;


--
-- Name: publishing_docs_app_taxonomy_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_app_taxonomy_terms (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    name character varying NOT NULL,
    parent_id bigint,
    depth integer DEFAULT 0 NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_app_term_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_docs_app_term_depth CHECK (((depth >= 0) AND (depth <= 8))),
    CONSTRAINT chk_docs_app_term_flat CHECK ((((vocabulary_kind)::text <> 'multiple_ordered_flat'::text) OR ((parent_id IS NULL) AND (depth = 0)))),
    CONSTRAINT chk_docs_app_term_kind CHECK (((vocabulary_kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_docs_app_term_locale CHECK (((locale)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_docs_app_term_name CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT chk_docs_app_term_not_self CHECK (((parent_id IS NULL) OR (parent_id <> id))),
    CONSTRAINT chk_docs_app_term_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_docs_app_term_root_depth CHECK ((((parent_id IS NULL) AND (depth = 0)) OR ((parent_id IS NOT NULL) AND (depth > 0)))),
    CONSTRAINT chk_docs_app_term_slug CHECK (((btrim((slug)::text) <> ''::text) AND ((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text))),
    CONSTRAINT chk_docs_app_terms_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_docs_app_taxonomy_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_app_taxonomy_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_app_taxonomy_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_app_taxonomy_terms_id_seq OWNED BY public.publishing_docs_app_taxonomy_terms.id;


--
-- Name: publishing_docs_app_version_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_app_version_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_app_ver_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_docs_app_ver_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_docs_app_ver_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_docs_app_version_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_docs_app_version_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_app_version_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_app_version_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_app_version_media_usages_id_seq OWNED BY public.publishing_docs_app_version_media_usages.id;


--
-- Name: publishing_docs_app_version_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_app_version_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    position_snapshot integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_app_vm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_docs_app_vm_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_docs_app_vm_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_docs_app_vm_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_docs_app_vm_pos CHECK ((("position" >= 0) AND (position_snapshot >= 0))),
    CONSTRAINT chk_docs_app_vm_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_docs_app_vm_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_docs_app_vm_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_docs_app_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_app_version_multiple_taxonomy_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_app_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_app_version_multiple_taxonomy_assignment_id_seq OWNED BY public.publishing_docs_app_version_multiple_taxonomy_assignments.id;


--
-- Name: publishing_docs_app_version_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_app_version_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_app_vs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text)),
    CONSTRAINT chk_docs_app_vs_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_docs_app_vs_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_docs_app_vs_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_docs_app_vs_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_docs_app_vs_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_docs_app_vs_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_docs_app_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_app_version_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_app_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_app_version_single_taxonomy_assignments_id_seq OWNED BY public.publishing_docs_app_version_single_taxonomy_assignments.id;


--
-- Name: publishing_docs_app_vocabularies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_app_vocabularies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    key character varying NOT NULL,
    kind character varying NOT NULL,
    internal_name character varying NOT NULL,
    description text,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_app_voc_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_docs_app_voc_key CHECK (((btrim((key)::text) <> ''::text) AND ((key)::text ~ '^[a-z][a-z0-9_]*$'::text))),
    CONSTRAINT chk_docs_app_voc_kind CHECK (((kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_docs_app_voc_name CHECK ((btrim((internal_name)::text) <> ''::text)),
    CONSTRAINT chk_docs_app_vocabularies_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_docs_app_vocabularies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_app_vocabularies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_app_vocabularies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_app_vocabularies_id_seq OWNED BY public.publishing_docs_app_vocabularies.id;


--
-- Name: publishing_docs_com_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_com_entries (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    locale character varying NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    current_revision_id bigint,
    archived_by_operator_public_id character varying(21),
    CONSTRAINT chk_docs_com_ent_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_docs_com_ent_lock CHECK ((lock_version >= 0)),
    CONSTRAINT chk_docs_com_entries_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_docs_com_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_com_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_com_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_com_entries_id_seq OWNED BY public.publishing_docs_com_entries.id;


--
-- Name: publishing_docs_com_entry_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_com_entry_revisions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    restored_from_revision_id bigint,
    restored_from_version_id bigint,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_com_entry_revisions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_docs_com_rev_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_docs_com_rev_restore CHECK ((num_nonnulls(restored_from_revision_id, restored_from_version_id) <= 1)),
    CONSTRAINT chk_docs_com_rev_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_docs_com_rev_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_docs_com_entry_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_com_entry_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_com_entry_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_com_entry_revisions_id_seq OWNED BY public.publishing_docs_com_entry_revisions.id;


--
-- Name: publishing_docs_com_entry_slugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_com_entry_slugs (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    state character varying NOT NULL,
    canonicalized_at timestamp(6) with time zone,
    redirected_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_com_entry_slugs_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_docs_com_slug_format CHECK (((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text)),
    CONSTRAINT chk_docs_com_slug_state CHECK (((state)::text = ANY (ARRAY[('reserved'::character varying)::text, ('canonical'::character varying)::text, ('redirect'::character varying)::text]))),
    CONSTRAINT chk_docs_com_slug_ts CHECK (((((state)::text = 'reserved'::text) AND (canonicalized_at IS NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'canonical'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'redirect'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NOT NULL) AND (redirected_at >= canonicalized_at))))
);


--
-- Name: publishing_docs_com_entry_slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_com_entry_slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_com_entry_slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_com_entry_slugs_id_seq OWNED BY public.publishing_docs_com_entry_slugs.id;


--
-- Name: publishing_docs_com_entry_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_com_entry_versions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_com_entry_versions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_docs_com_ver_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_docs_com_ver_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_docs_com_ver_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_docs_com_entry_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_com_entry_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_com_entry_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_com_entry_versions_id_seq OWNED BY public.publishing_docs_com_entry_versions.id;


--
-- Name: publishing_docs_com_publications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_com_publications (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    effective_from timestamp(6) with time zone NOT NULL,
    effective_until timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    cancellation_reason character varying,
    terminated_at timestamp(6) with time zone,
    termination_reason character varying,
    created_by_operator_public_id character varying(21),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    ended_by_operator_public_id character varying(21),
    CONSTRAINT chk_docs_com_pub_cancel CHECK ((((cancelled_at IS NULL) AND (cancellation_reason IS NULL)) OR ((cancelled_at IS NOT NULL) AND (cancellation_reason IS NOT NULL) AND (cancelled_at < effective_from)))),
    CONSTRAINT chk_docs_com_pub_end_mode CHECK ((NOT ((cancelled_at IS NOT NULL) AND (terminated_at IS NOT NULL)))),
    CONSTRAINT chk_docs_com_pub_term CHECK ((((terminated_at IS NULL) AND (termination_reason IS NULL)) OR ((terminated_at IS NOT NULL) AND (termination_reason IS NOT NULL) AND (terminated_at >= effective_from) AND (effective_until = terminated_at)))),
    CONSTRAINT chk_docs_com_pub_window CHECK (((effective_until IS NULL) OR (effective_until > effective_from))),
    CONSTRAINT chk_docs_com_publications_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_docs_com_publications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_com_publications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_com_publications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_com_publications_id_seq OWNED BY public.publishing_docs_com_publications.id;


--
-- Name: publishing_docs_com_revision_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_com_revision_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_com_rev_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_docs_com_rev_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_docs_com_rev_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_docs_com_revision_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_docs_com_revision_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_com_revision_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_com_revision_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_com_revision_media_usages_id_seq OWNED BY public.publishing_docs_com_revision_media_usages.id;


--
-- Name: publishing_docs_com_revision_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_com_revision_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_com_rm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_docs_com_rm_pos CHECK (("position" >= 0))
);


--
-- Name: publishing_docs_com_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_com_revision_multiple_taxonomy_assignmen_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_com_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_com_revision_multiple_taxonomy_assignmen_id_seq OWNED BY public.publishing_docs_com_revision_multiple_taxonomy_assignments.id;


--
-- Name: publishing_docs_com_revision_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_com_revision_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_com_rs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text))
);


--
-- Name: publishing_docs_com_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_com_revision_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_com_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_com_revision_single_taxonomy_assignments_id_seq OWNED BY public.publishing_docs_com_revision_single_taxonomy_assignments.id;


--
-- Name: publishing_docs_com_taxonomy_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_com_taxonomy_terms (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    name character varying NOT NULL,
    parent_id bigint,
    depth integer DEFAULT 0 NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_com_term_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_docs_com_term_depth CHECK (((depth >= 0) AND (depth <= 8))),
    CONSTRAINT chk_docs_com_term_flat CHECK ((((vocabulary_kind)::text <> 'multiple_ordered_flat'::text) OR ((parent_id IS NULL) AND (depth = 0)))),
    CONSTRAINT chk_docs_com_term_kind CHECK (((vocabulary_kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_docs_com_term_locale CHECK (((locale)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_docs_com_term_name CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT chk_docs_com_term_not_self CHECK (((parent_id IS NULL) OR (parent_id <> id))),
    CONSTRAINT chk_docs_com_term_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_docs_com_term_root_depth CHECK ((((parent_id IS NULL) AND (depth = 0)) OR ((parent_id IS NOT NULL) AND (depth > 0)))),
    CONSTRAINT chk_docs_com_term_slug CHECK (((btrim((slug)::text) <> ''::text) AND ((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text))),
    CONSTRAINT chk_docs_com_terms_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_docs_com_taxonomy_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_com_taxonomy_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_com_taxonomy_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_com_taxonomy_terms_id_seq OWNED BY public.publishing_docs_com_taxonomy_terms.id;


--
-- Name: publishing_docs_com_version_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_com_version_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_com_ver_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_docs_com_ver_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_docs_com_ver_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_docs_com_version_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_docs_com_version_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_com_version_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_com_version_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_com_version_media_usages_id_seq OWNED BY public.publishing_docs_com_version_media_usages.id;


--
-- Name: publishing_docs_com_version_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_com_version_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    position_snapshot integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_com_vm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_docs_com_vm_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_docs_com_vm_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_docs_com_vm_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_docs_com_vm_pos CHECK ((("position" >= 0) AND (position_snapshot >= 0))),
    CONSTRAINT chk_docs_com_vm_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_docs_com_vm_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_docs_com_vm_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_docs_com_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_com_version_multiple_taxonomy_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_com_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_com_version_multiple_taxonomy_assignment_id_seq OWNED BY public.publishing_docs_com_version_multiple_taxonomy_assignments.id;


--
-- Name: publishing_docs_com_version_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_com_version_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_com_vs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text)),
    CONSTRAINT chk_docs_com_vs_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_docs_com_vs_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_docs_com_vs_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_docs_com_vs_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_docs_com_vs_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_docs_com_vs_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_docs_com_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_com_version_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_com_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_com_version_single_taxonomy_assignments_id_seq OWNED BY public.publishing_docs_com_version_single_taxonomy_assignments.id;


--
-- Name: publishing_docs_com_vocabularies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_com_vocabularies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    key character varying NOT NULL,
    kind character varying NOT NULL,
    internal_name character varying NOT NULL,
    description text,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_com_voc_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_docs_com_voc_key CHECK (((btrim((key)::text) <> ''::text) AND ((key)::text ~ '^[a-z][a-z0-9_]*$'::text))),
    CONSTRAINT chk_docs_com_voc_kind CHECK (((kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_docs_com_voc_name CHECK ((btrim((internal_name)::text) <> ''::text)),
    CONSTRAINT chk_docs_com_vocabularies_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_docs_com_vocabularies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_com_vocabularies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_com_vocabularies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_com_vocabularies_id_seq OWNED BY public.publishing_docs_com_vocabularies.id;


--
-- Name: publishing_docs_org_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_org_entries (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    locale character varying NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    current_revision_id bigint,
    archived_by_operator_public_id character varying(21),
    CONSTRAINT chk_docs_org_ent_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_docs_org_ent_lock CHECK ((lock_version >= 0)),
    CONSTRAINT chk_docs_org_entries_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_docs_org_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_org_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_org_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_org_entries_id_seq OWNED BY public.publishing_docs_org_entries.id;


--
-- Name: publishing_docs_org_entry_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_org_entry_revisions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    restored_from_revision_id bigint,
    restored_from_version_id bigint,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_org_entry_revisions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_docs_org_rev_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_docs_org_rev_restore CHECK ((num_nonnulls(restored_from_revision_id, restored_from_version_id) <= 1)),
    CONSTRAINT chk_docs_org_rev_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_docs_org_rev_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_docs_org_entry_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_org_entry_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_org_entry_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_org_entry_revisions_id_seq OWNED BY public.publishing_docs_org_entry_revisions.id;


--
-- Name: publishing_docs_org_entry_slugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_org_entry_slugs (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    state character varying NOT NULL,
    canonicalized_at timestamp(6) with time zone,
    redirected_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_org_entry_slugs_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_docs_org_slug_format CHECK (((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text)),
    CONSTRAINT chk_docs_org_slug_state CHECK (((state)::text = ANY (ARRAY[('reserved'::character varying)::text, ('canonical'::character varying)::text, ('redirect'::character varying)::text]))),
    CONSTRAINT chk_docs_org_slug_ts CHECK (((((state)::text = 'reserved'::text) AND (canonicalized_at IS NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'canonical'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'redirect'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NOT NULL) AND (redirected_at >= canonicalized_at))))
);


--
-- Name: publishing_docs_org_entry_slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_org_entry_slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_org_entry_slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_org_entry_slugs_id_seq OWNED BY public.publishing_docs_org_entry_slugs.id;


--
-- Name: publishing_docs_org_entry_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_org_entry_versions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_org_entry_versions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_docs_org_ver_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_docs_org_ver_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_docs_org_ver_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_docs_org_entry_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_org_entry_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_org_entry_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_org_entry_versions_id_seq OWNED BY public.publishing_docs_org_entry_versions.id;


--
-- Name: publishing_docs_org_publications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_org_publications (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    effective_from timestamp(6) with time zone NOT NULL,
    effective_until timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    cancellation_reason character varying,
    terminated_at timestamp(6) with time zone,
    termination_reason character varying,
    created_by_operator_public_id character varying(21),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    ended_by_operator_public_id character varying(21),
    CONSTRAINT chk_docs_org_pub_cancel CHECK ((((cancelled_at IS NULL) AND (cancellation_reason IS NULL)) OR ((cancelled_at IS NOT NULL) AND (cancellation_reason IS NOT NULL) AND (cancelled_at < effective_from)))),
    CONSTRAINT chk_docs_org_pub_end_mode CHECK ((NOT ((cancelled_at IS NOT NULL) AND (terminated_at IS NOT NULL)))),
    CONSTRAINT chk_docs_org_pub_term CHECK ((((terminated_at IS NULL) AND (termination_reason IS NULL)) OR ((terminated_at IS NOT NULL) AND (termination_reason IS NOT NULL) AND (terminated_at >= effective_from) AND (effective_until = terminated_at)))),
    CONSTRAINT chk_docs_org_pub_window CHECK (((effective_until IS NULL) OR (effective_until > effective_from))),
    CONSTRAINT chk_docs_org_publications_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_docs_org_publications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_org_publications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_org_publications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_org_publications_id_seq OWNED BY public.publishing_docs_org_publications.id;


--
-- Name: publishing_docs_org_revision_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_org_revision_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_org_rev_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_docs_org_rev_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_docs_org_rev_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_docs_org_revision_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_docs_org_revision_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_org_revision_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_org_revision_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_org_revision_media_usages_id_seq OWNED BY public.publishing_docs_org_revision_media_usages.id;


--
-- Name: publishing_docs_org_revision_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_org_revision_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_org_rm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_docs_org_rm_pos CHECK (("position" >= 0))
);


--
-- Name: publishing_docs_org_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_org_revision_multiple_taxonomy_assignmen_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_org_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_org_revision_multiple_taxonomy_assignmen_id_seq OWNED BY public.publishing_docs_org_revision_multiple_taxonomy_assignments.id;


--
-- Name: publishing_docs_org_revision_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_org_revision_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_org_rs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text))
);


--
-- Name: publishing_docs_org_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_org_revision_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_org_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_org_revision_single_taxonomy_assignments_id_seq OWNED BY public.publishing_docs_org_revision_single_taxonomy_assignments.id;


--
-- Name: publishing_docs_org_taxonomy_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_org_taxonomy_terms (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    name character varying NOT NULL,
    parent_id bigint,
    depth integer DEFAULT 0 NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_org_term_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_docs_org_term_depth CHECK (((depth >= 0) AND (depth <= 8))),
    CONSTRAINT chk_docs_org_term_flat CHECK ((((vocabulary_kind)::text <> 'multiple_ordered_flat'::text) OR ((parent_id IS NULL) AND (depth = 0)))),
    CONSTRAINT chk_docs_org_term_kind CHECK (((vocabulary_kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_docs_org_term_locale CHECK (((locale)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_docs_org_term_name CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT chk_docs_org_term_not_self CHECK (((parent_id IS NULL) OR (parent_id <> id))),
    CONSTRAINT chk_docs_org_term_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_docs_org_term_root_depth CHECK ((((parent_id IS NULL) AND (depth = 0)) OR ((parent_id IS NOT NULL) AND (depth > 0)))),
    CONSTRAINT chk_docs_org_term_slug CHECK (((btrim((slug)::text) <> ''::text) AND ((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text))),
    CONSTRAINT chk_docs_org_terms_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_docs_org_taxonomy_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_org_taxonomy_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_org_taxonomy_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_org_taxonomy_terms_id_seq OWNED BY public.publishing_docs_org_taxonomy_terms.id;


--
-- Name: publishing_docs_org_version_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_org_version_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_org_ver_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_docs_org_ver_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_docs_org_ver_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_docs_org_version_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_docs_org_version_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_org_version_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_org_version_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_org_version_media_usages_id_seq OWNED BY public.publishing_docs_org_version_media_usages.id;


--
-- Name: publishing_docs_org_version_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_org_version_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    position_snapshot integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_org_vm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_docs_org_vm_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_docs_org_vm_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_docs_org_vm_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_docs_org_vm_pos CHECK ((("position" >= 0) AND (position_snapshot >= 0))),
    CONSTRAINT chk_docs_org_vm_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_docs_org_vm_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_docs_org_vm_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_docs_org_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_org_version_multiple_taxonomy_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_org_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_org_version_multiple_taxonomy_assignment_id_seq OWNED BY public.publishing_docs_org_version_multiple_taxonomy_assignments.id;


--
-- Name: publishing_docs_org_version_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_org_version_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_org_vs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text)),
    CONSTRAINT chk_docs_org_vs_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_docs_org_vs_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_docs_org_vs_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_docs_org_vs_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_docs_org_vs_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_docs_org_vs_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_docs_org_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_org_version_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_org_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_org_version_single_taxonomy_assignments_id_seq OWNED BY public.publishing_docs_org_version_single_taxonomy_assignments.id;


--
-- Name: publishing_docs_org_vocabularies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_docs_org_vocabularies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    key character varying NOT NULL,
    kind character varying NOT NULL,
    internal_name character varying NOT NULL,
    description text,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_docs_org_voc_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_docs_org_voc_key CHECK (((btrim((key)::text) <> ''::text) AND ((key)::text ~ '^[a-z][a-z0-9_]*$'::text))),
    CONSTRAINT chk_docs_org_voc_kind CHECK (((kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_docs_org_voc_name CHECK ((btrim((internal_name)::text) <> ''::text)),
    CONSTRAINT chk_docs_org_vocabularies_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_docs_org_vocabularies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_docs_org_vocabularies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_docs_org_vocabularies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_docs_org_vocabularies_id_seq OWNED BY public.publishing_docs_org_vocabularies.id;


--
-- Name: publishing_help_app_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_app_entries (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    locale character varying NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    current_revision_id bigint,
    archived_by_operator_public_id character varying(21),
    CONSTRAINT chk_help_app_ent_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_help_app_ent_lock CHECK ((lock_version >= 0)),
    CONSTRAINT chk_help_app_entries_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_help_app_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_app_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_app_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_app_entries_id_seq OWNED BY public.publishing_help_app_entries.id;


--
-- Name: publishing_help_app_entry_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_app_entry_revisions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    restored_from_revision_id bigint,
    restored_from_version_id bigint,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_app_entry_revisions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_help_app_rev_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_help_app_rev_restore CHECK ((num_nonnulls(restored_from_revision_id, restored_from_version_id) <= 1)),
    CONSTRAINT chk_help_app_rev_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_help_app_rev_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_help_app_entry_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_app_entry_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_app_entry_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_app_entry_revisions_id_seq OWNED BY public.publishing_help_app_entry_revisions.id;


--
-- Name: publishing_help_app_entry_slugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_app_entry_slugs (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    state character varying NOT NULL,
    canonicalized_at timestamp(6) with time zone,
    redirected_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_app_entry_slugs_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_help_app_slug_format CHECK (((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text)),
    CONSTRAINT chk_help_app_slug_state CHECK (((state)::text = ANY (ARRAY[('reserved'::character varying)::text, ('canonical'::character varying)::text, ('redirect'::character varying)::text]))),
    CONSTRAINT chk_help_app_slug_ts CHECK (((((state)::text = 'reserved'::text) AND (canonicalized_at IS NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'canonical'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'redirect'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NOT NULL) AND (redirected_at >= canonicalized_at))))
);


--
-- Name: publishing_help_app_entry_slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_app_entry_slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_app_entry_slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_app_entry_slugs_id_seq OWNED BY public.publishing_help_app_entry_slugs.id;


--
-- Name: publishing_help_app_entry_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_app_entry_versions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_app_entry_versions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_help_app_ver_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_help_app_ver_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_help_app_ver_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_help_app_entry_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_app_entry_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_app_entry_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_app_entry_versions_id_seq OWNED BY public.publishing_help_app_entry_versions.id;


--
-- Name: publishing_help_app_publications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_app_publications (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    effective_from timestamp(6) with time zone NOT NULL,
    effective_until timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    cancellation_reason character varying,
    terminated_at timestamp(6) with time zone,
    termination_reason character varying,
    created_by_operator_public_id character varying(21),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    ended_by_operator_public_id character varying(21),
    CONSTRAINT chk_help_app_pub_cancel CHECK ((((cancelled_at IS NULL) AND (cancellation_reason IS NULL)) OR ((cancelled_at IS NOT NULL) AND (cancellation_reason IS NOT NULL) AND (cancelled_at < effective_from)))),
    CONSTRAINT chk_help_app_pub_end_mode CHECK ((NOT ((cancelled_at IS NOT NULL) AND (terminated_at IS NOT NULL)))),
    CONSTRAINT chk_help_app_pub_term CHECK ((((terminated_at IS NULL) AND (termination_reason IS NULL)) OR ((terminated_at IS NOT NULL) AND (termination_reason IS NOT NULL) AND (terminated_at >= effective_from) AND (effective_until = terminated_at)))),
    CONSTRAINT chk_help_app_pub_window CHECK (((effective_until IS NULL) OR (effective_until > effective_from))),
    CONSTRAINT chk_help_app_publications_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_help_app_publications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_app_publications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_app_publications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_app_publications_id_seq OWNED BY public.publishing_help_app_publications.id;


--
-- Name: publishing_help_app_revision_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_app_revision_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_app_rev_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_help_app_rev_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_help_app_rev_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_help_app_revision_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_help_app_revision_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_app_revision_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_app_revision_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_app_revision_media_usages_id_seq OWNED BY public.publishing_help_app_revision_media_usages.id;


--
-- Name: publishing_help_app_revision_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_app_revision_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_app_rm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_help_app_rm_pos CHECK (("position" >= 0))
);


--
-- Name: publishing_help_app_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_app_revision_multiple_taxonomy_assignmen_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_app_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_app_revision_multiple_taxonomy_assignmen_id_seq OWNED BY public.publishing_help_app_revision_multiple_taxonomy_assignments.id;


--
-- Name: publishing_help_app_revision_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_app_revision_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_app_rs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text))
);


--
-- Name: publishing_help_app_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_app_revision_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_app_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_app_revision_single_taxonomy_assignments_id_seq OWNED BY public.publishing_help_app_revision_single_taxonomy_assignments.id;


--
-- Name: publishing_help_app_taxonomy_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_app_taxonomy_terms (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    name character varying NOT NULL,
    parent_id bigint,
    depth integer DEFAULT 0 NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_app_term_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_help_app_term_depth CHECK (((depth >= 0) AND (depth <= 8))),
    CONSTRAINT chk_help_app_term_flat CHECK ((((vocabulary_kind)::text <> 'multiple_ordered_flat'::text) OR ((parent_id IS NULL) AND (depth = 0)))),
    CONSTRAINT chk_help_app_term_kind CHECK (((vocabulary_kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_help_app_term_locale CHECK (((locale)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_help_app_term_name CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT chk_help_app_term_not_self CHECK (((parent_id IS NULL) OR (parent_id <> id))),
    CONSTRAINT chk_help_app_term_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_help_app_term_root_depth CHECK ((((parent_id IS NULL) AND (depth = 0)) OR ((parent_id IS NOT NULL) AND (depth > 0)))),
    CONSTRAINT chk_help_app_term_slug CHECK (((btrim((slug)::text) <> ''::text) AND ((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text))),
    CONSTRAINT chk_help_app_terms_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_help_app_taxonomy_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_app_taxonomy_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_app_taxonomy_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_app_taxonomy_terms_id_seq OWNED BY public.publishing_help_app_taxonomy_terms.id;


--
-- Name: publishing_help_app_version_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_app_version_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_app_ver_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_help_app_ver_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_help_app_ver_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_help_app_version_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_help_app_version_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_app_version_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_app_version_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_app_version_media_usages_id_seq OWNED BY public.publishing_help_app_version_media_usages.id;


--
-- Name: publishing_help_app_version_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_app_version_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    position_snapshot integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_app_vm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_help_app_vm_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_help_app_vm_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_help_app_vm_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_help_app_vm_pos CHECK ((("position" >= 0) AND (position_snapshot >= 0))),
    CONSTRAINT chk_help_app_vm_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_help_app_vm_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_help_app_vm_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_help_app_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_app_version_multiple_taxonomy_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_app_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_app_version_multiple_taxonomy_assignment_id_seq OWNED BY public.publishing_help_app_version_multiple_taxonomy_assignments.id;


--
-- Name: publishing_help_app_version_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_app_version_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_app_vs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text)),
    CONSTRAINT chk_help_app_vs_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_help_app_vs_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_help_app_vs_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_help_app_vs_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_help_app_vs_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_help_app_vs_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_help_app_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_app_version_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_app_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_app_version_single_taxonomy_assignments_id_seq OWNED BY public.publishing_help_app_version_single_taxonomy_assignments.id;


--
-- Name: publishing_help_app_vocabularies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_app_vocabularies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    key character varying NOT NULL,
    kind character varying NOT NULL,
    internal_name character varying NOT NULL,
    description text,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_app_voc_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_help_app_voc_key CHECK (((btrim((key)::text) <> ''::text) AND ((key)::text ~ '^[a-z][a-z0-9_]*$'::text))),
    CONSTRAINT chk_help_app_voc_kind CHECK (((kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_help_app_voc_name CHECK ((btrim((internal_name)::text) <> ''::text)),
    CONSTRAINT chk_help_app_vocabularies_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_help_app_vocabularies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_app_vocabularies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_app_vocabularies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_app_vocabularies_id_seq OWNED BY public.publishing_help_app_vocabularies.id;


--
-- Name: publishing_help_com_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_com_entries (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    locale character varying NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    current_revision_id bigint,
    archived_by_operator_public_id character varying(21),
    CONSTRAINT chk_help_com_ent_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_help_com_ent_lock CHECK ((lock_version >= 0)),
    CONSTRAINT chk_help_com_entries_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_help_com_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_com_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_com_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_com_entries_id_seq OWNED BY public.publishing_help_com_entries.id;


--
-- Name: publishing_help_com_entry_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_com_entry_revisions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    restored_from_revision_id bigint,
    restored_from_version_id bigint,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_com_entry_revisions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_help_com_rev_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_help_com_rev_restore CHECK ((num_nonnulls(restored_from_revision_id, restored_from_version_id) <= 1)),
    CONSTRAINT chk_help_com_rev_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_help_com_rev_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_help_com_entry_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_com_entry_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_com_entry_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_com_entry_revisions_id_seq OWNED BY public.publishing_help_com_entry_revisions.id;


--
-- Name: publishing_help_com_entry_slugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_com_entry_slugs (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    state character varying NOT NULL,
    canonicalized_at timestamp(6) with time zone,
    redirected_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_com_entry_slugs_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_help_com_slug_format CHECK (((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text)),
    CONSTRAINT chk_help_com_slug_state CHECK (((state)::text = ANY (ARRAY[('reserved'::character varying)::text, ('canonical'::character varying)::text, ('redirect'::character varying)::text]))),
    CONSTRAINT chk_help_com_slug_ts CHECK (((((state)::text = 'reserved'::text) AND (canonicalized_at IS NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'canonical'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'redirect'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NOT NULL) AND (redirected_at >= canonicalized_at))))
);


--
-- Name: publishing_help_com_entry_slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_com_entry_slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_com_entry_slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_com_entry_slugs_id_seq OWNED BY public.publishing_help_com_entry_slugs.id;


--
-- Name: publishing_help_com_entry_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_com_entry_versions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_com_entry_versions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_help_com_ver_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_help_com_ver_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_help_com_ver_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_help_com_entry_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_com_entry_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_com_entry_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_com_entry_versions_id_seq OWNED BY public.publishing_help_com_entry_versions.id;


--
-- Name: publishing_help_com_publications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_com_publications (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    effective_from timestamp(6) with time zone NOT NULL,
    effective_until timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    cancellation_reason character varying,
    terminated_at timestamp(6) with time zone,
    termination_reason character varying,
    created_by_operator_public_id character varying(21),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    ended_by_operator_public_id character varying(21),
    CONSTRAINT chk_help_com_pub_cancel CHECK ((((cancelled_at IS NULL) AND (cancellation_reason IS NULL)) OR ((cancelled_at IS NOT NULL) AND (cancellation_reason IS NOT NULL) AND (cancelled_at < effective_from)))),
    CONSTRAINT chk_help_com_pub_end_mode CHECK ((NOT ((cancelled_at IS NOT NULL) AND (terminated_at IS NOT NULL)))),
    CONSTRAINT chk_help_com_pub_term CHECK ((((terminated_at IS NULL) AND (termination_reason IS NULL)) OR ((terminated_at IS NOT NULL) AND (termination_reason IS NOT NULL) AND (terminated_at >= effective_from) AND (effective_until = terminated_at)))),
    CONSTRAINT chk_help_com_pub_window CHECK (((effective_until IS NULL) OR (effective_until > effective_from))),
    CONSTRAINT chk_help_com_publications_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_help_com_publications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_com_publications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_com_publications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_com_publications_id_seq OWNED BY public.publishing_help_com_publications.id;


--
-- Name: publishing_help_com_revision_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_com_revision_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_com_rev_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_help_com_rev_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_help_com_rev_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_help_com_revision_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_help_com_revision_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_com_revision_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_com_revision_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_com_revision_media_usages_id_seq OWNED BY public.publishing_help_com_revision_media_usages.id;


--
-- Name: publishing_help_com_revision_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_com_revision_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_com_rm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_help_com_rm_pos CHECK (("position" >= 0))
);


--
-- Name: publishing_help_com_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_com_revision_multiple_taxonomy_assignmen_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_com_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_com_revision_multiple_taxonomy_assignmen_id_seq OWNED BY public.publishing_help_com_revision_multiple_taxonomy_assignments.id;


--
-- Name: publishing_help_com_revision_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_com_revision_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_com_rs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text))
);


--
-- Name: publishing_help_com_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_com_revision_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_com_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_com_revision_single_taxonomy_assignments_id_seq OWNED BY public.publishing_help_com_revision_single_taxonomy_assignments.id;


--
-- Name: publishing_help_com_taxonomy_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_com_taxonomy_terms (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    name character varying NOT NULL,
    parent_id bigint,
    depth integer DEFAULT 0 NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_com_term_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_help_com_term_depth CHECK (((depth >= 0) AND (depth <= 8))),
    CONSTRAINT chk_help_com_term_flat CHECK ((((vocabulary_kind)::text <> 'multiple_ordered_flat'::text) OR ((parent_id IS NULL) AND (depth = 0)))),
    CONSTRAINT chk_help_com_term_kind CHECK (((vocabulary_kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_help_com_term_locale CHECK (((locale)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_help_com_term_name CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT chk_help_com_term_not_self CHECK (((parent_id IS NULL) OR (parent_id <> id))),
    CONSTRAINT chk_help_com_term_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_help_com_term_root_depth CHECK ((((parent_id IS NULL) AND (depth = 0)) OR ((parent_id IS NOT NULL) AND (depth > 0)))),
    CONSTRAINT chk_help_com_term_slug CHECK (((btrim((slug)::text) <> ''::text) AND ((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text))),
    CONSTRAINT chk_help_com_terms_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_help_com_taxonomy_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_com_taxonomy_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_com_taxonomy_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_com_taxonomy_terms_id_seq OWNED BY public.publishing_help_com_taxonomy_terms.id;


--
-- Name: publishing_help_com_version_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_com_version_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_com_ver_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_help_com_ver_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_help_com_ver_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_help_com_version_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_help_com_version_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_com_version_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_com_version_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_com_version_media_usages_id_seq OWNED BY public.publishing_help_com_version_media_usages.id;


--
-- Name: publishing_help_com_version_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_com_version_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    position_snapshot integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_com_vm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_help_com_vm_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_help_com_vm_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_help_com_vm_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_help_com_vm_pos CHECK ((("position" >= 0) AND (position_snapshot >= 0))),
    CONSTRAINT chk_help_com_vm_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_help_com_vm_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_help_com_vm_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_help_com_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_com_version_multiple_taxonomy_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_com_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_com_version_multiple_taxonomy_assignment_id_seq OWNED BY public.publishing_help_com_version_multiple_taxonomy_assignments.id;


--
-- Name: publishing_help_com_version_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_com_version_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_com_vs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text)),
    CONSTRAINT chk_help_com_vs_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_help_com_vs_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_help_com_vs_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_help_com_vs_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_help_com_vs_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_help_com_vs_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_help_com_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_com_version_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_com_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_com_version_single_taxonomy_assignments_id_seq OWNED BY public.publishing_help_com_version_single_taxonomy_assignments.id;


--
-- Name: publishing_help_com_vocabularies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_com_vocabularies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    key character varying NOT NULL,
    kind character varying NOT NULL,
    internal_name character varying NOT NULL,
    description text,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_com_voc_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_help_com_voc_key CHECK (((btrim((key)::text) <> ''::text) AND ((key)::text ~ '^[a-z][a-z0-9_]*$'::text))),
    CONSTRAINT chk_help_com_voc_kind CHECK (((kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_help_com_voc_name CHECK ((btrim((internal_name)::text) <> ''::text)),
    CONSTRAINT chk_help_com_vocabularies_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_help_com_vocabularies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_com_vocabularies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_com_vocabularies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_com_vocabularies_id_seq OWNED BY public.publishing_help_com_vocabularies.id;


--
-- Name: publishing_help_org_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_org_entries (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    locale character varying NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    current_revision_id bigint,
    archived_by_operator_public_id character varying(21),
    CONSTRAINT chk_help_org_ent_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_help_org_ent_lock CHECK ((lock_version >= 0)),
    CONSTRAINT chk_help_org_entries_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_help_org_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_org_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_org_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_org_entries_id_seq OWNED BY public.publishing_help_org_entries.id;


--
-- Name: publishing_help_org_entry_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_org_entry_revisions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    restored_from_revision_id bigint,
    restored_from_version_id bigint,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_org_entry_revisions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_help_org_rev_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_help_org_rev_restore CHECK ((num_nonnulls(restored_from_revision_id, restored_from_version_id) <= 1)),
    CONSTRAINT chk_help_org_rev_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_help_org_rev_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_help_org_entry_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_org_entry_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_org_entry_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_org_entry_revisions_id_seq OWNED BY public.publishing_help_org_entry_revisions.id;


--
-- Name: publishing_help_org_entry_slugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_org_entry_slugs (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    state character varying NOT NULL,
    canonicalized_at timestamp(6) with time zone,
    redirected_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_org_entry_slugs_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_help_org_slug_format CHECK (((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text)),
    CONSTRAINT chk_help_org_slug_state CHECK (((state)::text = ANY (ARRAY[('reserved'::character varying)::text, ('canonical'::character varying)::text, ('redirect'::character varying)::text]))),
    CONSTRAINT chk_help_org_slug_ts CHECK (((((state)::text = 'reserved'::text) AND (canonicalized_at IS NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'canonical'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'redirect'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NOT NULL) AND (redirected_at >= canonicalized_at))))
);


--
-- Name: publishing_help_org_entry_slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_org_entry_slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_org_entry_slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_org_entry_slugs_id_seq OWNED BY public.publishing_help_org_entry_slugs.id;


--
-- Name: publishing_help_org_entry_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_org_entry_versions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_org_entry_versions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_help_org_ver_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_help_org_ver_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_help_org_ver_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_help_org_entry_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_org_entry_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_org_entry_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_org_entry_versions_id_seq OWNED BY public.publishing_help_org_entry_versions.id;


--
-- Name: publishing_help_org_publications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_org_publications (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    effective_from timestamp(6) with time zone NOT NULL,
    effective_until timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    cancellation_reason character varying,
    terminated_at timestamp(6) with time zone,
    termination_reason character varying,
    created_by_operator_public_id character varying(21),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    ended_by_operator_public_id character varying(21),
    CONSTRAINT chk_help_org_pub_cancel CHECK ((((cancelled_at IS NULL) AND (cancellation_reason IS NULL)) OR ((cancelled_at IS NOT NULL) AND (cancellation_reason IS NOT NULL) AND (cancelled_at < effective_from)))),
    CONSTRAINT chk_help_org_pub_end_mode CHECK ((NOT ((cancelled_at IS NOT NULL) AND (terminated_at IS NOT NULL)))),
    CONSTRAINT chk_help_org_pub_term CHECK ((((terminated_at IS NULL) AND (termination_reason IS NULL)) OR ((terminated_at IS NOT NULL) AND (termination_reason IS NOT NULL) AND (terminated_at >= effective_from) AND (effective_until = terminated_at)))),
    CONSTRAINT chk_help_org_pub_window CHECK (((effective_until IS NULL) OR (effective_until > effective_from))),
    CONSTRAINT chk_help_org_publications_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_help_org_publications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_org_publications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_org_publications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_org_publications_id_seq OWNED BY public.publishing_help_org_publications.id;


--
-- Name: publishing_help_org_revision_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_org_revision_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_org_rev_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_help_org_rev_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_help_org_rev_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_help_org_revision_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_help_org_revision_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_org_revision_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_org_revision_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_org_revision_media_usages_id_seq OWNED BY public.publishing_help_org_revision_media_usages.id;


--
-- Name: publishing_help_org_revision_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_org_revision_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_org_rm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_help_org_rm_pos CHECK (("position" >= 0))
);


--
-- Name: publishing_help_org_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_org_revision_multiple_taxonomy_assignmen_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_org_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_org_revision_multiple_taxonomy_assignmen_id_seq OWNED BY public.publishing_help_org_revision_multiple_taxonomy_assignments.id;


--
-- Name: publishing_help_org_revision_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_org_revision_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_org_rs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text))
);


--
-- Name: publishing_help_org_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_org_revision_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_org_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_org_revision_single_taxonomy_assignments_id_seq OWNED BY public.publishing_help_org_revision_single_taxonomy_assignments.id;


--
-- Name: publishing_help_org_taxonomy_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_org_taxonomy_terms (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    name character varying NOT NULL,
    parent_id bigint,
    depth integer DEFAULT 0 NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_org_term_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_help_org_term_depth CHECK (((depth >= 0) AND (depth <= 8))),
    CONSTRAINT chk_help_org_term_flat CHECK ((((vocabulary_kind)::text <> 'multiple_ordered_flat'::text) OR ((parent_id IS NULL) AND (depth = 0)))),
    CONSTRAINT chk_help_org_term_kind CHECK (((vocabulary_kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_help_org_term_locale CHECK (((locale)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_help_org_term_name CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT chk_help_org_term_not_self CHECK (((parent_id IS NULL) OR (parent_id <> id))),
    CONSTRAINT chk_help_org_term_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_help_org_term_root_depth CHECK ((((parent_id IS NULL) AND (depth = 0)) OR ((parent_id IS NOT NULL) AND (depth > 0)))),
    CONSTRAINT chk_help_org_term_slug CHECK (((btrim((slug)::text) <> ''::text) AND ((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text))),
    CONSTRAINT chk_help_org_terms_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_help_org_taxonomy_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_org_taxonomy_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_org_taxonomy_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_org_taxonomy_terms_id_seq OWNED BY public.publishing_help_org_taxonomy_terms.id;


--
-- Name: publishing_help_org_version_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_org_version_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_org_ver_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_help_org_ver_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_help_org_ver_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_help_org_version_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_help_org_version_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_org_version_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_org_version_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_org_version_media_usages_id_seq OWNED BY public.publishing_help_org_version_media_usages.id;


--
-- Name: publishing_help_org_version_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_org_version_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    position_snapshot integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_org_vm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_help_org_vm_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_help_org_vm_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_help_org_vm_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_help_org_vm_pos CHECK ((("position" >= 0) AND (position_snapshot >= 0))),
    CONSTRAINT chk_help_org_vm_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_help_org_vm_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_help_org_vm_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_help_org_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_org_version_multiple_taxonomy_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_org_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_org_version_multiple_taxonomy_assignment_id_seq OWNED BY public.publishing_help_org_version_multiple_taxonomy_assignments.id;


--
-- Name: publishing_help_org_version_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_org_version_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_org_vs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text)),
    CONSTRAINT chk_help_org_vs_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_help_org_vs_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_help_org_vs_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_help_org_vs_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_help_org_vs_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_help_org_vs_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_help_org_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_org_version_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_org_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_org_version_single_taxonomy_assignments_id_seq OWNED BY public.publishing_help_org_version_single_taxonomy_assignments.id;


--
-- Name: publishing_help_org_vocabularies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_help_org_vocabularies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    key character varying NOT NULL,
    kind character varying NOT NULL,
    internal_name character varying NOT NULL,
    description text,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_help_org_voc_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_help_org_voc_key CHECK (((btrim((key)::text) <> ''::text) AND ((key)::text ~ '^[a-z][a-z0-9_]*$'::text))),
    CONSTRAINT chk_help_org_voc_kind CHECK (((kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_help_org_voc_name CHECK ((btrim((internal_name)::text) <> ''::text)),
    CONSTRAINT chk_help_org_vocabularies_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_help_org_vocabularies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_help_org_vocabularies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_help_org_vocabularies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_help_org_vocabularies_id_seq OWNED BY public.publishing_help_org_vocabularies.id;


--
-- Name: publishing_info_app_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_app_entries (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    locale character varying NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    current_revision_id bigint,
    archived_by_operator_public_id character varying(21),
    CONSTRAINT chk_info_app_ent_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_info_app_ent_lock CHECK ((lock_version >= 0)),
    CONSTRAINT chk_info_app_entries_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_info_app_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_app_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_app_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_app_entries_id_seq OWNED BY public.publishing_info_app_entries.id;


--
-- Name: publishing_info_app_entry_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_app_entry_revisions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    restored_from_revision_id bigint,
    restored_from_version_id bigint,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_app_entry_revisions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_info_app_rev_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_info_app_rev_restore CHECK ((num_nonnulls(restored_from_revision_id, restored_from_version_id) <= 1)),
    CONSTRAINT chk_info_app_rev_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_info_app_rev_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_info_app_entry_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_app_entry_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_app_entry_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_app_entry_revisions_id_seq OWNED BY public.publishing_info_app_entry_revisions.id;


--
-- Name: publishing_info_app_entry_slugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_app_entry_slugs (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    state character varying NOT NULL,
    canonicalized_at timestamp(6) with time zone,
    redirected_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_app_entry_slugs_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_info_app_slug_format CHECK (((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text)),
    CONSTRAINT chk_info_app_slug_state CHECK (((state)::text = ANY (ARRAY[('reserved'::character varying)::text, ('canonical'::character varying)::text, ('redirect'::character varying)::text]))),
    CONSTRAINT chk_info_app_slug_ts CHECK (((((state)::text = 'reserved'::text) AND (canonicalized_at IS NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'canonical'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'redirect'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NOT NULL) AND (redirected_at >= canonicalized_at))))
);


--
-- Name: publishing_info_app_entry_slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_app_entry_slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_app_entry_slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_app_entry_slugs_id_seq OWNED BY public.publishing_info_app_entry_slugs.id;


--
-- Name: publishing_info_app_entry_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_app_entry_versions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_app_entry_versions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_info_app_ver_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_info_app_ver_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_info_app_ver_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_info_app_entry_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_app_entry_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_app_entry_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_app_entry_versions_id_seq OWNED BY public.publishing_info_app_entry_versions.id;


--
-- Name: publishing_info_app_publications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_app_publications (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    effective_from timestamp(6) with time zone NOT NULL,
    effective_until timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    cancellation_reason character varying,
    terminated_at timestamp(6) with time zone,
    termination_reason character varying,
    created_by_operator_public_id character varying(21),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    ended_by_operator_public_id character varying(21),
    CONSTRAINT chk_info_app_pub_cancel CHECK ((((cancelled_at IS NULL) AND (cancellation_reason IS NULL)) OR ((cancelled_at IS NOT NULL) AND (cancellation_reason IS NOT NULL) AND (cancelled_at < effective_from)))),
    CONSTRAINT chk_info_app_pub_end_mode CHECK ((NOT ((cancelled_at IS NOT NULL) AND (terminated_at IS NOT NULL)))),
    CONSTRAINT chk_info_app_pub_term CHECK ((((terminated_at IS NULL) AND (termination_reason IS NULL)) OR ((terminated_at IS NOT NULL) AND (termination_reason IS NOT NULL) AND (terminated_at >= effective_from) AND (effective_until = terminated_at)))),
    CONSTRAINT chk_info_app_pub_window CHECK (((effective_until IS NULL) OR (effective_until > effective_from))),
    CONSTRAINT chk_info_app_publications_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_info_app_publications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_app_publications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_app_publications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_app_publications_id_seq OWNED BY public.publishing_info_app_publications.id;


--
-- Name: publishing_info_app_revision_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_app_revision_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_app_rev_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_info_app_rev_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_info_app_rev_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_info_app_revision_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_info_app_revision_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_app_revision_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_app_revision_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_app_revision_media_usages_id_seq OWNED BY public.publishing_info_app_revision_media_usages.id;


--
-- Name: publishing_info_app_revision_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_app_revision_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_app_rm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_info_app_rm_pos CHECK (("position" >= 0))
);


--
-- Name: publishing_info_app_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_app_revision_multiple_taxonomy_assignmen_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_app_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_app_revision_multiple_taxonomy_assignmen_id_seq OWNED BY public.publishing_info_app_revision_multiple_taxonomy_assignments.id;


--
-- Name: publishing_info_app_revision_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_app_revision_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_app_rs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text))
);


--
-- Name: publishing_info_app_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_app_revision_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_app_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_app_revision_single_taxonomy_assignments_id_seq OWNED BY public.publishing_info_app_revision_single_taxonomy_assignments.id;


--
-- Name: publishing_info_app_taxonomy_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_app_taxonomy_terms (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    name character varying NOT NULL,
    parent_id bigint,
    depth integer DEFAULT 0 NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_app_term_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_info_app_term_depth CHECK (((depth >= 0) AND (depth <= 8))),
    CONSTRAINT chk_info_app_term_flat CHECK ((((vocabulary_kind)::text <> 'multiple_ordered_flat'::text) OR ((parent_id IS NULL) AND (depth = 0)))),
    CONSTRAINT chk_info_app_term_kind CHECK (((vocabulary_kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_info_app_term_locale CHECK (((locale)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_info_app_term_name CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT chk_info_app_term_not_self CHECK (((parent_id IS NULL) OR (parent_id <> id))),
    CONSTRAINT chk_info_app_term_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_info_app_term_root_depth CHECK ((((parent_id IS NULL) AND (depth = 0)) OR ((parent_id IS NOT NULL) AND (depth > 0)))),
    CONSTRAINT chk_info_app_term_slug CHECK (((btrim((slug)::text) <> ''::text) AND ((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text))),
    CONSTRAINT chk_info_app_terms_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_info_app_taxonomy_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_app_taxonomy_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_app_taxonomy_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_app_taxonomy_terms_id_seq OWNED BY public.publishing_info_app_taxonomy_terms.id;


--
-- Name: publishing_info_app_version_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_app_version_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_app_ver_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_info_app_ver_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_info_app_ver_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_info_app_version_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_info_app_version_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_app_version_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_app_version_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_app_version_media_usages_id_seq OWNED BY public.publishing_info_app_version_media_usages.id;


--
-- Name: publishing_info_app_version_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_app_version_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    position_snapshot integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_app_vm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_info_app_vm_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_info_app_vm_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_info_app_vm_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_info_app_vm_pos CHECK ((("position" >= 0) AND (position_snapshot >= 0))),
    CONSTRAINT chk_info_app_vm_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_info_app_vm_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_info_app_vm_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_info_app_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_app_version_multiple_taxonomy_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_app_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_app_version_multiple_taxonomy_assignment_id_seq OWNED BY public.publishing_info_app_version_multiple_taxonomy_assignments.id;


--
-- Name: publishing_info_app_version_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_app_version_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_app_vs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text)),
    CONSTRAINT chk_info_app_vs_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_info_app_vs_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_info_app_vs_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_info_app_vs_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_info_app_vs_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_info_app_vs_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_info_app_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_app_version_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_app_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_app_version_single_taxonomy_assignments_id_seq OWNED BY public.publishing_info_app_version_single_taxonomy_assignments.id;


--
-- Name: publishing_info_app_vocabularies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_app_vocabularies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    key character varying NOT NULL,
    kind character varying NOT NULL,
    internal_name character varying NOT NULL,
    description text,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_app_voc_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_info_app_voc_key CHECK (((btrim((key)::text) <> ''::text) AND ((key)::text ~ '^[a-z][a-z0-9_]*$'::text))),
    CONSTRAINT chk_info_app_voc_kind CHECK (((kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_info_app_voc_name CHECK ((btrim((internal_name)::text) <> ''::text)),
    CONSTRAINT chk_info_app_vocabularies_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_info_app_vocabularies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_app_vocabularies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_app_vocabularies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_app_vocabularies_id_seq OWNED BY public.publishing_info_app_vocabularies.id;


--
-- Name: publishing_info_com_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_com_entries (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    locale character varying NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    current_revision_id bigint,
    archived_by_operator_public_id character varying(21),
    CONSTRAINT chk_info_com_ent_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_info_com_ent_lock CHECK ((lock_version >= 0)),
    CONSTRAINT chk_info_com_entries_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_info_com_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_com_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_com_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_com_entries_id_seq OWNED BY public.publishing_info_com_entries.id;


--
-- Name: publishing_info_com_entry_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_com_entry_revisions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    restored_from_revision_id bigint,
    restored_from_version_id bigint,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_com_entry_revisions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_info_com_rev_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_info_com_rev_restore CHECK ((num_nonnulls(restored_from_revision_id, restored_from_version_id) <= 1)),
    CONSTRAINT chk_info_com_rev_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_info_com_rev_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_info_com_entry_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_com_entry_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_com_entry_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_com_entry_revisions_id_seq OWNED BY public.publishing_info_com_entry_revisions.id;


--
-- Name: publishing_info_com_entry_slugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_com_entry_slugs (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    state character varying NOT NULL,
    canonicalized_at timestamp(6) with time zone,
    redirected_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_com_entry_slugs_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_info_com_slug_format CHECK (((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text)),
    CONSTRAINT chk_info_com_slug_state CHECK (((state)::text = ANY (ARRAY[('reserved'::character varying)::text, ('canonical'::character varying)::text, ('redirect'::character varying)::text]))),
    CONSTRAINT chk_info_com_slug_ts CHECK (((((state)::text = 'reserved'::text) AND (canonicalized_at IS NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'canonical'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'redirect'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NOT NULL) AND (redirected_at >= canonicalized_at))))
);


--
-- Name: publishing_info_com_entry_slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_com_entry_slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_com_entry_slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_com_entry_slugs_id_seq OWNED BY public.publishing_info_com_entry_slugs.id;


--
-- Name: publishing_info_com_entry_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_com_entry_versions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_com_entry_versions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_info_com_ver_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_info_com_ver_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_info_com_ver_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_info_com_entry_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_com_entry_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_com_entry_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_com_entry_versions_id_seq OWNED BY public.publishing_info_com_entry_versions.id;


--
-- Name: publishing_info_com_publications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_com_publications (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    effective_from timestamp(6) with time zone NOT NULL,
    effective_until timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    cancellation_reason character varying,
    terminated_at timestamp(6) with time zone,
    termination_reason character varying,
    created_by_operator_public_id character varying(21),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    ended_by_operator_public_id character varying(21),
    CONSTRAINT chk_info_com_pub_cancel CHECK ((((cancelled_at IS NULL) AND (cancellation_reason IS NULL)) OR ((cancelled_at IS NOT NULL) AND (cancellation_reason IS NOT NULL) AND (cancelled_at < effective_from)))),
    CONSTRAINT chk_info_com_pub_end_mode CHECK ((NOT ((cancelled_at IS NOT NULL) AND (terminated_at IS NOT NULL)))),
    CONSTRAINT chk_info_com_pub_term CHECK ((((terminated_at IS NULL) AND (termination_reason IS NULL)) OR ((terminated_at IS NOT NULL) AND (termination_reason IS NOT NULL) AND (terminated_at >= effective_from) AND (effective_until = terminated_at)))),
    CONSTRAINT chk_info_com_pub_window CHECK (((effective_until IS NULL) OR (effective_until > effective_from))),
    CONSTRAINT chk_info_com_publications_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_info_com_publications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_com_publications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_com_publications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_com_publications_id_seq OWNED BY public.publishing_info_com_publications.id;


--
-- Name: publishing_info_com_revision_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_com_revision_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_com_rev_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_info_com_rev_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_info_com_rev_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_info_com_revision_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_info_com_revision_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_com_revision_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_com_revision_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_com_revision_media_usages_id_seq OWNED BY public.publishing_info_com_revision_media_usages.id;


--
-- Name: publishing_info_com_revision_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_com_revision_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_com_rm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_info_com_rm_pos CHECK (("position" >= 0))
);


--
-- Name: publishing_info_com_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_com_revision_multiple_taxonomy_assignmen_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_com_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_com_revision_multiple_taxonomy_assignmen_id_seq OWNED BY public.publishing_info_com_revision_multiple_taxonomy_assignments.id;


--
-- Name: publishing_info_com_revision_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_com_revision_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_com_rs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text))
);


--
-- Name: publishing_info_com_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_com_revision_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_com_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_com_revision_single_taxonomy_assignments_id_seq OWNED BY public.publishing_info_com_revision_single_taxonomy_assignments.id;


--
-- Name: publishing_info_com_taxonomy_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_com_taxonomy_terms (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    name character varying NOT NULL,
    parent_id bigint,
    depth integer DEFAULT 0 NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_com_term_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_info_com_term_depth CHECK (((depth >= 0) AND (depth <= 8))),
    CONSTRAINT chk_info_com_term_flat CHECK ((((vocabulary_kind)::text <> 'multiple_ordered_flat'::text) OR ((parent_id IS NULL) AND (depth = 0)))),
    CONSTRAINT chk_info_com_term_kind CHECK (((vocabulary_kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_info_com_term_locale CHECK (((locale)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_info_com_term_name CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT chk_info_com_term_not_self CHECK (((parent_id IS NULL) OR (parent_id <> id))),
    CONSTRAINT chk_info_com_term_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_info_com_term_root_depth CHECK ((((parent_id IS NULL) AND (depth = 0)) OR ((parent_id IS NOT NULL) AND (depth > 0)))),
    CONSTRAINT chk_info_com_term_slug CHECK (((btrim((slug)::text) <> ''::text) AND ((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text))),
    CONSTRAINT chk_info_com_terms_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_info_com_taxonomy_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_com_taxonomy_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_com_taxonomy_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_com_taxonomy_terms_id_seq OWNED BY public.publishing_info_com_taxonomy_terms.id;


--
-- Name: publishing_info_com_version_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_com_version_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_com_ver_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_info_com_ver_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_info_com_ver_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_info_com_version_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_info_com_version_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_com_version_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_com_version_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_com_version_media_usages_id_seq OWNED BY public.publishing_info_com_version_media_usages.id;


--
-- Name: publishing_info_com_version_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_com_version_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    position_snapshot integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_com_vm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_info_com_vm_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_info_com_vm_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_info_com_vm_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_info_com_vm_pos CHECK ((("position" >= 0) AND (position_snapshot >= 0))),
    CONSTRAINT chk_info_com_vm_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_info_com_vm_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_info_com_vm_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_info_com_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_com_version_multiple_taxonomy_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_com_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_com_version_multiple_taxonomy_assignment_id_seq OWNED BY public.publishing_info_com_version_multiple_taxonomy_assignments.id;


--
-- Name: publishing_info_com_version_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_com_version_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_com_vs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text)),
    CONSTRAINT chk_info_com_vs_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_info_com_vs_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_info_com_vs_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_info_com_vs_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_info_com_vs_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_info_com_vs_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_info_com_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_com_version_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_com_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_com_version_single_taxonomy_assignments_id_seq OWNED BY public.publishing_info_com_version_single_taxonomy_assignments.id;


--
-- Name: publishing_info_com_vocabularies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_com_vocabularies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    key character varying NOT NULL,
    kind character varying NOT NULL,
    internal_name character varying NOT NULL,
    description text,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_com_voc_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_info_com_voc_key CHECK (((btrim((key)::text) <> ''::text) AND ((key)::text ~ '^[a-z][a-z0-9_]*$'::text))),
    CONSTRAINT chk_info_com_voc_kind CHECK (((kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_info_com_voc_name CHECK ((btrim((internal_name)::text) <> ''::text)),
    CONSTRAINT chk_info_com_vocabularies_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_info_com_vocabularies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_com_vocabularies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_com_vocabularies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_com_vocabularies_id_seq OWNED BY public.publishing_info_com_vocabularies.id;


--
-- Name: publishing_info_org_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_org_entries (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    locale character varying NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    current_revision_id bigint,
    archived_by_operator_public_id character varying(21),
    CONSTRAINT chk_info_org_ent_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_info_org_ent_lock CHECK ((lock_version >= 0)),
    CONSTRAINT chk_info_org_entries_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_info_org_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_org_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_org_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_org_entries_id_seq OWNED BY public.publishing_info_org_entries.id;


--
-- Name: publishing_info_org_entry_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_org_entry_revisions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    restored_from_revision_id bigint,
    restored_from_version_id bigint,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_org_entry_revisions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_info_org_rev_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_info_org_rev_restore CHECK ((num_nonnulls(restored_from_revision_id, restored_from_version_id) <= 1)),
    CONSTRAINT chk_info_org_rev_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_info_org_rev_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_info_org_entry_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_org_entry_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_org_entry_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_org_entry_revisions_id_seq OWNED BY public.publishing_info_org_entry_revisions.id;


--
-- Name: publishing_info_org_entry_slugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_org_entry_slugs (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    state character varying NOT NULL,
    canonicalized_at timestamp(6) with time zone,
    redirected_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_org_entry_slugs_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_info_org_slug_format CHECK (((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text)),
    CONSTRAINT chk_info_org_slug_state CHECK (((state)::text = ANY (ARRAY[('reserved'::character varying)::text, ('canonical'::character varying)::text, ('redirect'::character varying)::text]))),
    CONSTRAINT chk_info_org_slug_ts CHECK (((((state)::text = 'reserved'::text) AND (canonicalized_at IS NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'canonical'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'redirect'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NOT NULL) AND (redirected_at >= canonicalized_at))))
);


--
-- Name: publishing_info_org_entry_slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_org_entry_slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_org_entry_slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_org_entry_slugs_id_seq OWNED BY public.publishing_info_org_entry_slugs.id;


--
-- Name: publishing_info_org_entry_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_org_entry_versions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_org_entry_versions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_info_org_ver_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_info_org_ver_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_info_org_ver_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_info_org_entry_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_org_entry_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_org_entry_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_org_entry_versions_id_seq OWNED BY public.publishing_info_org_entry_versions.id;


--
-- Name: publishing_info_org_publications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_org_publications (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    effective_from timestamp(6) with time zone NOT NULL,
    effective_until timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    cancellation_reason character varying,
    terminated_at timestamp(6) with time zone,
    termination_reason character varying,
    created_by_operator_public_id character varying(21),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    ended_by_operator_public_id character varying(21),
    CONSTRAINT chk_info_org_pub_cancel CHECK ((((cancelled_at IS NULL) AND (cancellation_reason IS NULL)) OR ((cancelled_at IS NOT NULL) AND (cancellation_reason IS NOT NULL) AND (cancelled_at < effective_from)))),
    CONSTRAINT chk_info_org_pub_end_mode CHECK ((NOT ((cancelled_at IS NOT NULL) AND (terminated_at IS NOT NULL)))),
    CONSTRAINT chk_info_org_pub_term CHECK ((((terminated_at IS NULL) AND (termination_reason IS NULL)) OR ((terminated_at IS NOT NULL) AND (termination_reason IS NOT NULL) AND (terminated_at >= effective_from) AND (effective_until = terminated_at)))),
    CONSTRAINT chk_info_org_pub_window CHECK (((effective_until IS NULL) OR (effective_until > effective_from))),
    CONSTRAINT chk_info_org_publications_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_info_org_publications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_org_publications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_org_publications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_org_publications_id_seq OWNED BY public.publishing_info_org_publications.id;


--
-- Name: publishing_info_org_revision_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_org_revision_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_org_rev_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_info_org_rev_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_info_org_rev_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_info_org_revision_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_info_org_revision_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_org_revision_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_org_revision_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_org_revision_media_usages_id_seq OWNED BY public.publishing_info_org_revision_media_usages.id;


--
-- Name: publishing_info_org_revision_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_org_revision_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_org_rm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_info_org_rm_pos CHECK (("position" >= 0))
);


--
-- Name: publishing_info_org_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_org_revision_multiple_taxonomy_assignmen_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_org_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_org_revision_multiple_taxonomy_assignmen_id_seq OWNED BY public.publishing_info_org_revision_multiple_taxonomy_assignments.id;


--
-- Name: publishing_info_org_revision_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_org_revision_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_org_rs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text))
);


--
-- Name: publishing_info_org_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_org_revision_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_org_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_org_revision_single_taxonomy_assignments_id_seq OWNED BY public.publishing_info_org_revision_single_taxonomy_assignments.id;


--
-- Name: publishing_info_org_taxonomy_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_org_taxonomy_terms (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    name character varying NOT NULL,
    parent_id bigint,
    depth integer DEFAULT 0 NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_org_term_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_info_org_term_depth CHECK (((depth >= 0) AND (depth <= 8))),
    CONSTRAINT chk_info_org_term_flat CHECK ((((vocabulary_kind)::text <> 'multiple_ordered_flat'::text) OR ((parent_id IS NULL) AND (depth = 0)))),
    CONSTRAINT chk_info_org_term_kind CHECK (((vocabulary_kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_info_org_term_locale CHECK (((locale)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_info_org_term_name CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT chk_info_org_term_not_self CHECK (((parent_id IS NULL) OR (parent_id <> id))),
    CONSTRAINT chk_info_org_term_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_info_org_term_root_depth CHECK ((((parent_id IS NULL) AND (depth = 0)) OR ((parent_id IS NOT NULL) AND (depth > 0)))),
    CONSTRAINT chk_info_org_term_slug CHECK (((btrim((slug)::text) <> ''::text) AND ((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text))),
    CONSTRAINT chk_info_org_terms_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_info_org_taxonomy_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_org_taxonomy_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_org_taxonomy_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_org_taxonomy_terms_id_seq OWNED BY public.publishing_info_org_taxonomy_terms.id;


--
-- Name: publishing_info_org_version_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_org_version_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_org_ver_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_info_org_ver_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_info_org_ver_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_info_org_version_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_info_org_version_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_org_version_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_org_version_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_org_version_media_usages_id_seq OWNED BY public.publishing_info_org_version_media_usages.id;


--
-- Name: publishing_info_org_version_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_org_version_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    position_snapshot integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_org_vm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_info_org_vm_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_info_org_vm_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_info_org_vm_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_info_org_vm_pos CHECK ((("position" >= 0) AND (position_snapshot >= 0))),
    CONSTRAINT chk_info_org_vm_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_info_org_vm_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_info_org_vm_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_info_org_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_org_version_multiple_taxonomy_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_org_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_org_version_multiple_taxonomy_assignment_id_seq OWNED BY public.publishing_info_org_version_multiple_taxonomy_assignments.id;


--
-- Name: publishing_info_org_version_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_org_version_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_org_vs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text)),
    CONSTRAINT chk_info_org_vs_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_info_org_vs_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_info_org_vs_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_info_org_vs_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_info_org_vs_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_info_org_vs_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_info_org_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_org_version_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_org_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_org_version_single_taxonomy_assignments_id_seq OWNED BY public.publishing_info_org_version_single_taxonomy_assignments.id;


--
-- Name: publishing_info_org_vocabularies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_info_org_vocabularies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    key character varying NOT NULL,
    kind character varying NOT NULL,
    internal_name character varying NOT NULL,
    description text,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_info_org_voc_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_info_org_voc_key CHECK (((btrim((key)::text) <> ''::text) AND ((key)::text ~ '^[a-z][a-z0-9_]*$'::text))),
    CONSTRAINT chk_info_org_voc_kind CHECK (((kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_info_org_voc_name CHECK ((btrim((internal_name)::text) <> ''::text)),
    CONSTRAINT chk_info_org_vocabularies_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_info_org_vocabularies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_info_org_vocabularies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_info_org_vocabularies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_info_org_vocabularies_id_seq OWNED BY public.publishing_info_org_vocabularies.id;


--
-- Name: publishing_media_files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_media_files (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    storage_key character varying NOT NULL,
    content_type character varying NOT NULL,
    byte_size bigint NOT NULL,
    digest_algorithm character varying NOT NULL,
    digest character varying NOT NULL,
    width integer,
    height integer,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    purged_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    file_data jsonb,
    CONSTRAINT chk_media_files_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_publishing_media_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_publishing_media_digest CHECK ((((digest_algorithm)::text = 'sha256'::text) AND ((digest)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT chk_publishing_media_dimensions CHECK ((((width IS NULL) AND (height IS NULL)) OR ((width > 0) AND (height > 0)))),
    CONSTRAINT chk_publishing_media_metadata CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT chk_publishing_media_size CHECK ((byte_size >= 0))
);


--
-- Name: publishing_media_files_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_media_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_media_files_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_media_files_id_seq OWNED BY public.publishing_media_files.id;


--
-- Name: publishing_news_app_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_app_entries (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    locale character varying NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    current_revision_id bigint,
    archived_by_operator_public_id character varying(21),
    CONSTRAINT chk_news_app_ent_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_news_app_ent_lock CHECK ((lock_version >= 0)),
    CONSTRAINT chk_news_app_entries_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_news_app_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_app_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_app_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_app_entries_id_seq OWNED BY public.publishing_news_app_entries.id;


--
-- Name: publishing_news_app_entry_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_app_entry_revisions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    restored_from_revision_id bigint,
    restored_from_version_id bigint,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_app_entry_revisions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_news_app_rev_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_news_app_rev_restore CHECK ((num_nonnulls(restored_from_revision_id, restored_from_version_id) <= 1)),
    CONSTRAINT chk_news_app_rev_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_news_app_rev_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_news_app_entry_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_app_entry_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_app_entry_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_app_entry_revisions_id_seq OWNED BY public.publishing_news_app_entry_revisions.id;


--
-- Name: publishing_news_app_entry_slugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_app_entry_slugs (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    state character varying NOT NULL,
    canonicalized_at timestamp(6) with time zone,
    redirected_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_app_entry_slugs_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_news_app_slug_format CHECK (((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text)),
    CONSTRAINT chk_news_app_slug_state CHECK (((state)::text = ANY (ARRAY[('reserved'::character varying)::text, ('canonical'::character varying)::text, ('redirect'::character varying)::text]))),
    CONSTRAINT chk_news_app_slug_ts CHECK (((((state)::text = 'reserved'::text) AND (canonicalized_at IS NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'canonical'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'redirect'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NOT NULL) AND (redirected_at >= canonicalized_at))))
);


--
-- Name: publishing_news_app_entry_slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_app_entry_slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_app_entry_slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_app_entry_slugs_id_seq OWNED BY public.publishing_news_app_entry_slugs.id;


--
-- Name: publishing_news_app_entry_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_app_entry_versions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_app_entry_versions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_news_app_ver_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_news_app_ver_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_news_app_ver_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_news_app_entry_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_app_entry_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_app_entry_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_app_entry_versions_id_seq OWNED BY public.publishing_news_app_entry_versions.id;


--
-- Name: publishing_news_app_publications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_app_publications (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    effective_from timestamp(6) with time zone NOT NULL,
    effective_until timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    cancellation_reason character varying,
    terminated_at timestamp(6) with time zone,
    termination_reason character varying,
    created_by_operator_public_id character varying(21),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    ended_by_operator_public_id character varying(21),
    CONSTRAINT chk_news_app_pub_cancel CHECK ((((cancelled_at IS NULL) AND (cancellation_reason IS NULL)) OR ((cancelled_at IS NOT NULL) AND (cancellation_reason IS NOT NULL) AND (cancelled_at < effective_from)))),
    CONSTRAINT chk_news_app_pub_end_mode CHECK ((NOT ((cancelled_at IS NOT NULL) AND (terminated_at IS NOT NULL)))),
    CONSTRAINT chk_news_app_pub_term CHECK ((((terminated_at IS NULL) AND (termination_reason IS NULL)) OR ((terminated_at IS NOT NULL) AND (termination_reason IS NOT NULL) AND (terminated_at >= effective_from) AND (effective_until = terminated_at)))),
    CONSTRAINT chk_news_app_pub_window CHECK (((effective_until IS NULL) OR (effective_until > effective_from))),
    CONSTRAINT chk_news_app_publications_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_news_app_publications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_app_publications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_app_publications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_app_publications_id_seq OWNED BY public.publishing_news_app_publications.id;


--
-- Name: publishing_news_app_revision_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_app_revision_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_app_rev_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_news_app_rev_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_news_app_rev_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_news_app_revision_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_news_app_revision_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_app_revision_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_app_revision_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_app_revision_media_usages_id_seq OWNED BY public.publishing_news_app_revision_media_usages.id;


--
-- Name: publishing_news_app_revision_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_app_revision_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_app_rm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_news_app_rm_pos CHECK (("position" >= 0))
);


--
-- Name: publishing_news_app_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_app_revision_multiple_taxonomy_assignmen_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_app_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_app_revision_multiple_taxonomy_assignmen_id_seq OWNED BY public.publishing_news_app_revision_multiple_taxonomy_assignments.id;


--
-- Name: publishing_news_app_revision_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_app_revision_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_app_rs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text))
);


--
-- Name: publishing_news_app_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_app_revision_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_app_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_app_revision_single_taxonomy_assignments_id_seq OWNED BY public.publishing_news_app_revision_single_taxonomy_assignments.id;


--
-- Name: publishing_news_app_taxonomy_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_app_taxonomy_terms (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    name character varying NOT NULL,
    parent_id bigint,
    depth integer DEFAULT 0 NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_app_term_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_news_app_term_depth CHECK (((depth >= 0) AND (depth <= 8))),
    CONSTRAINT chk_news_app_term_flat CHECK ((((vocabulary_kind)::text <> 'multiple_ordered_flat'::text) OR ((parent_id IS NULL) AND (depth = 0)))),
    CONSTRAINT chk_news_app_term_kind CHECK (((vocabulary_kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_news_app_term_locale CHECK (((locale)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_news_app_term_name CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT chk_news_app_term_not_self CHECK (((parent_id IS NULL) OR (parent_id <> id))),
    CONSTRAINT chk_news_app_term_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_news_app_term_root_depth CHECK ((((parent_id IS NULL) AND (depth = 0)) OR ((parent_id IS NOT NULL) AND (depth > 0)))),
    CONSTRAINT chk_news_app_term_slug CHECK (((btrim((slug)::text) <> ''::text) AND ((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text))),
    CONSTRAINT chk_news_app_terms_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_news_app_taxonomy_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_app_taxonomy_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_app_taxonomy_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_app_taxonomy_terms_id_seq OWNED BY public.publishing_news_app_taxonomy_terms.id;


--
-- Name: publishing_news_app_version_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_app_version_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_app_ver_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_news_app_ver_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_news_app_ver_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_news_app_version_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_news_app_version_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_app_version_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_app_version_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_app_version_media_usages_id_seq OWNED BY public.publishing_news_app_version_media_usages.id;


--
-- Name: publishing_news_app_version_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_app_version_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    position_snapshot integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_app_vm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_news_app_vm_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_news_app_vm_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_news_app_vm_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_news_app_vm_pos CHECK ((("position" >= 0) AND (position_snapshot >= 0))),
    CONSTRAINT chk_news_app_vm_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_news_app_vm_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_news_app_vm_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_news_app_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_app_version_multiple_taxonomy_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_app_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_app_version_multiple_taxonomy_assignment_id_seq OWNED BY public.publishing_news_app_version_multiple_taxonomy_assignments.id;


--
-- Name: publishing_news_app_version_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_app_version_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_app_vs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text)),
    CONSTRAINT chk_news_app_vs_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_news_app_vs_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_news_app_vs_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_news_app_vs_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_news_app_vs_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_news_app_vs_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_news_app_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_app_version_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_app_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_app_version_single_taxonomy_assignments_id_seq OWNED BY public.publishing_news_app_version_single_taxonomy_assignments.id;


--
-- Name: publishing_news_app_vocabularies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_app_vocabularies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    key character varying NOT NULL,
    kind character varying NOT NULL,
    internal_name character varying NOT NULL,
    description text,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_app_voc_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_news_app_voc_key CHECK (((btrim((key)::text) <> ''::text) AND ((key)::text ~ '^[a-z][a-z0-9_]*$'::text))),
    CONSTRAINT chk_news_app_voc_kind CHECK (((kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_news_app_voc_name CHECK ((btrim((internal_name)::text) <> ''::text)),
    CONSTRAINT chk_news_app_vocabularies_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_news_app_vocabularies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_app_vocabularies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_app_vocabularies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_app_vocabularies_id_seq OWNED BY public.publishing_news_app_vocabularies.id;


--
-- Name: publishing_news_com_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_com_entries (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    locale character varying NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    current_revision_id bigint,
    archived_by_operator_public_id character varying(21),
    CONSTRAINT chk_news_com_ent_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_news_com_ent_lock CHECK ((lock_version >= 0)),
    CONSTRAINT chk_news_com_entries_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_news_com_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_com_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_com_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_com_entries_id_seq OWNED BY public.publishing_news_com_entries.id;


--
-- Name: publishing_news_com_entry_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_com_entry_revisions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    restored_from_revision_id bigint,
    restored_from_version_id bigint,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_com_entry_revisions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_news_com_rev_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_news_com_rev_restore CHECK ((num_nonnulls(restored_from_revision_id, restored_from_version_id) <= 1)),
    CONSTRAINT chk_news_com_rev_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_news_com_rev_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_news_com_entry_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_com_entry_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_com_entry_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_com_entry_revisions_id_seq OWNED BY public.publishing_news_com_entry_revisions.id;


--
-- Name: publishing_news_com_entry_slugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_com_entry_slugs (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    state character varying NOT NULL,
    canonicalized_at timestamp(6) with time zone,
    redirected_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_com_entry_slugs_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_news_com_slug_format CHECK (((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text)),
    CONSTRAINT chk_news_com_slug_state CHECK (((state)::text = ANY (ARRAY[('reserved'::character varying)::text, ('canonical'::character varying)::text, ('redirect'::character varying)::text]))),
    CONSTRAINT chk_news_com_slug_ts CHECK (((((state)::text = 'reserved'::text) AND (canonicalized_at IS NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'canonical'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'redirect'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NOT NULL) AND (redirected_at >= canonicalized_at))))
);


--
-- Name: publishing_news_com_entry_slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_com_entry_slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_com_entry_slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_com_entry_slugs_id_seq OWNED BY public.publishing_news_com_entry_slugs.id;


--
-- Name: publishing_news_com_entry_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_com_entry_versions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_com_entry_versions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_news_com_ver_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_news_com_ver_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_news_com_ver_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_news_com_entry_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_com_entry_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_com_entry_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_com_entry_versions_id_seq OWNED BY public.publishing_news_com_entry_versions.id;


--
-- Name: publishing_news_com_publications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_com_publications (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    effective_from timestamp(6) with time zone NOT NULL,
    effective_until timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    cancellation_reason character varying,
    terminated_at timestamp(6) with time zone,
    termination_reason character varying,
    created_by_operator_public_id character varying(21),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    ended_by_operator_public_id character varying(21),
    CONSTRAINT chk_news_com_pub_cancel CHECK ((((cancelled_at IS NULL) AND (cancellation_reason IS NULL)) OR ((cancelled_at IS NOT NULL) AND (cancellation_reason IS NOT NULL) AND (cancelled_at < effective_from)))),
    CONSTRAINT chk_news_com_pub_end_mode CHECK ((NOT ((cancelled_at IS NOT NULL) AND (terminated_at IS NOT NULL)))),
    CONSTRAINT chk_news_com_pub_term CHECK ((((terminated_at IS NULL) AND (termination_reason IS NULL)) OR ((terminated_at IS NOT NULL) AND (termination_reason IS NOT NULL) AND (terminated_at >= effective_from) AND (effective_until = terminated_at)))),
    CONSTRAINT chk_news_com_pub_window CHECK (((effective_until IS NULL) OR (effective_until > effective_from))),
    CONSTRAINT chk_news_com_publications_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_news_com_publications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_com_publications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_com_publications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_com_publications_id_seq OWNED BY public.publishing_news_com_publications.id;


--
-- Name: publishing_news_com_revision_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_com_revision_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_com_rev_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_news_com_rev_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_news_com_rev_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_news_com_revision_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_news_com_revision_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_com_revision_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_com_revision_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_com_revision_media_usages_id_seq OWNED BY public.publishing_news_com_revision_media_usages.id;


--
-- Name: publishing_news_com_revision_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_com_revision_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_com_rm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_news_com_rm_pos CHECK (("position" >= 0))
);


--
-- Name: publishing_news_com_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_com_revision_multiple_taxonomy_assignmen_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_com_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_com_revision_multiple_taxonomy_assignmen_id_seq OWNED BY public.publishing_news_com_revision_multiple_taxonomy_assignments.id;


--
-- Name: publishing_news_com_revision_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_com_revision_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_com_rs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text))
);


--
-- Name: publishing_news_com_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_com_revision_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_com_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_com_revision_single_taxonomy_assignments_id_seq OWNED BY public.publishing_news_com_revision_single_taxonomy_assignments.id;


--
-- Name: publishing_news_com_taxonomy_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_com_taxonomy_terms (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    name character varying NOT NULL,
    parent_id bigint,
    depth integer DEFAULT 0 NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_com_term_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_news_com_term_depth CHECK (((depth >= 0) AND (depth <= 8))),
    CONSTRAINT chk_news_com_term_flat CHECK ((((vocabulary_kind)::text <> 'multiple_ordered_flat'::text) OR ((parent_id IS NULL) AND (depth = 0)))),
    CONSTRAINT chk_news_com_term_kind CHECK (((vocabulary_kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_news_com_term_locale CHECK (((locale)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_news_com_term_name CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT chk_news_com_term_not_self CHECK (((parent_id IS NULL) OR (parent_id <> id))),
    CONSTRAINT chk_news_com_term_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_news_com_term_root_depth CHECK ((((parent_id IS NULL) AND (depth = 0)) OR ((parent_id IS NOT NULL) AND (depth > 0)))),
    CONSTRAINT chk_news_com_term_slug CHECK (((btrim((slug)::text) <> ''::text) AND ((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text))),
    CONSTRAINT chk_news_com_terms_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_news_com_taxonomy_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_com_taxonomy_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_com_taxonomy_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_com_taxonomy_terms_id_seq OWNED BY public.publishing_news_com_taxonomy_terms.id;


--
-- Name: publishing_news_com_version_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_com_version_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_com_ver_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_news_com_ver_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_news_com_ver_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_news_com_version_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_news_com_version_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_com_version_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_com_version_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_com_version_media_usages_id_seq OWNED BY public.publishing_news_com_version_media_usages.id;


--
-- Name: publishing_news_com_version_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_com_version_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    position_snapshot integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_com_vm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_news_com_vm_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_news_com_vm_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_news_com_vm_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_news_com_vm_pos CHECK ((("position" >= 0) AND (position_snapshot >= 0))),
    CONSTRAINT chk_news_com_vm_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_news_com_vm_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_news_com_vm_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_news_com_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_com_version_multiple_taxonomy_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_com_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_com_version_multiple_taxonomy_assignment_id_seq OWNED BY public.publishing_news_com_version_multiple_taxonomy_assignments.id;


--
-- Name: publishing_news_com_version_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_com_version_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_com_vs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text)),
    CONSTRAINT chk_news_com_vs_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_news_com_vs_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_news_com_vs_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_news_com_vs_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_news_com_vs_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_news_com_vs_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_news_com_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_com_version_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_com_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_com_version_single_taxonomy_assignments_id_seq OWNED BY public.publishing_news_com_version_single_taxonomy_assignments.id;


--
-- Name: publishing_news_com_vocabularies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_com_vocabularies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    key character varying NOT NULL,
    kind character varying NOT NULL,
    internal_name character varying NOT NULL,
    description text,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_com_voc_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_news_com_voc_key CHECK (((btrim((key)::text) <> ''::text) AND ((key)::text ~ '^[a-z][a-z0-9_]*$'::text))),
    CONSTRAINT chk_news_com_voc_kind CHECK (((kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_news_com_voc_name CHECK ((btrim((internal_name)::text) <> ''::text)),
    CONSTRAINT chk_news_com_vocabularies_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_news_com_vocabularies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_com_vocabularies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_com_vocabularies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_com_vocabularies_id_seq OWNED BY public.publishing_news_com_vocabularies.id;


--
-- Name: publishing_news_org_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_org_entries (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    locale character varying NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    current_revision_id bigint,
    archived_by_operator_public_id character varying(21),
    CONSTRAINT chk_news_org_ent_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_news_org_ent_lock CHECK ((lock_version >= 0)),
    CONSTRAINT chk_news_org_entries_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_news_org_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_org_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_org_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_org_entries_id_seq OWNED BY public.publishing_news_org_entries.id;


--
-- Name: publishing_news_org_entry_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_org_entry_revisions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    restored_from_revision_id bigint,
    restored_from_version_id bigint,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_org_entry_revisions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_news_org_rev_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_news_org_rev_restore CHECK ((num_nonnulls(restored_from_revision_id, restored_from_version_id) <= 1)),
    CONSTRAINT chk_news_org_rev_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_news_org_rev_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_news_org_entry_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_org_entry_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_org_entry_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_org_entry_revisions_id_seq OWNED BY public.publishing_news_org_entry_revisions.id;


--
-- Name: publishing_news_org_entry_slugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_org_entry_slugs (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    state character varying NOT NULL,
    canonicalized_at timestamp(6) with time zone,
    redirected_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_org_entry_slugs_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_news_org_slug_format CHECK (((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text)),
    CONSTRAINT chk_news_org_slug_state CHECK (((state)::text = ANY (ARRAY[('reserved'::character varying)::text, ('canonical'::character varying)::text, ('redirect'::character varying)::text]))),
    CONSTRAINT chk_news_org_slug_ts CHECK (((((state)::text = 'reserved'::text) AND (canonicalized_at IS NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'canonical'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'redirect'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NOT NULL) AND (redirected_at >= canonicalized_at))))
);


--
-- Name: publishing_news_org_entry_slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_org_entry_slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_org_entry_slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_org_entry_slugs_id_seq OWNED BY public.publishing_news_org_entry_slugs.id;


--
-- Name: publishing_news_org_entry_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_org_entry_versions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    locale character varying NOT NULL,
    title text NOT NULL,
    summary text,
    body text NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_org_entry_versions_pid CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_news_org_ver_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_news_org_ver_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_news_org_ver_seq CHECK ((sequence > 0))
);


--
-- Name: publishing_news_org_entry_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_org_entry_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_org_entry_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_org_entry_versions_id_seq OWNED BY public.publishing_news_org_entry_versions.id;


--
-- Name: publishing_news_org_publications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_org_publications (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    effective_from timestamp(6) with time zone NOT NULL,
    effective_until timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    cancellation_reason character varying,
    terminated_at timestamp(6) with time zone,
    termination_reason character varying,
    created_by_operator_public_id character varying(21),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    ended_by_operator_public_id character varying(21),
    CONSTRAINT chk_news_org_pub_cancel CHECK ((((cancelled_at IS NULL) AND (cancellation_reason IS NULL)) OR ((cancelled_at IS NOT NULL) AND (cancellation_reason IS NOT NULL) AND (cancelled_at < effective_from)))),
    CONSTRAINT chk_news_org_pub_end_mode CHECK ((NOT ((cancelled_at IS NOT NULL) AND (terminated_at IS NOT NULL)))),
    CONSTRAINT chk_news_org_pub_term CHECK ((((terminated_at IS NULL) AND (termination_reason IS NULL)) OR ((terminated_at IS NOT NULL) AND (termination_reason IS NOT NULL) AND (terminated_at >= effective_from) AND (effective_until = terminated_at)))),
    CONSTRAINT chk_news_org_pub_window CHECK (((effective_until IS NULL) OR (effective_until > effective_from))),
    CONSTRAINT chk_news_org_publications_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_news_org_publications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_org_publications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_org_publications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_org_publications_id_seq OWNED BY public.publishing_news_org_publications.id;


--
-- Name: publishing_news_org_revision_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_org_revision_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_org_rev_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_news_org_rev_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_news_org_rev_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_news_org_revision_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_news_org_revision_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_org_revision_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_org_revision_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_org_revision_media_usages_id_seq OWNED BY public.publishing_news_org_revision_media_usages.id;


--
-- Name: publishing_news_org_revision_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_org_revision_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_org_rm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_news_org_rm_pos CHECK (("position" >= 0))
);


--
-- Name: publishing_news_org_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_org_revision_multiple_taxonomy_assignmen_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_org_revision_multiple_taxonomy_assignmen_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_org_revision_multiple_taxonomy_assignmen_id_seq OWNED BY public.publishing_news_org_revision_multiple_taxonomy_assignments.id;


--
-- Name: publishing_news_org_revision_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_org_revision_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_org_rs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text))
);


--
-- Name: publishing_news_org_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_org_revision_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_org_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_org_revision_single_taxonomy_assignments_id_seq OWNED BY public.publishing_news_org_revision_single_taxonomy_assignments.id;


--
-- Name: publishing_news_org_taxonomy_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_org_taxonomy_terms (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    name character varying NOT NULL,
    parent_id bigint,
    depth integer DEFAULT 0 NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_org_term_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_news_org_term_depth CHECK (((depth >= 0) AND (depth <= 8))),
    CONSTRAINT chk_news_org_term_flat CHECK ((((vocabulary_kind)::text <> 'multiple_ordered_flat'::text) OR ((parent_id IS NULL) AND (depth = 0)))),
    CONSTRAINT chk_news_org_term_kind CHECK (((vocabulary_kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_news_org_term_locale CHECK (((locale)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_news_org_term_name CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT chk_news_org_term_not_self CHECK (((parent_id IS NULL) OR (parent_id <> id))),
    CONSTRAINT chk_news_org_term_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_news_org_term_root_depth CHECK ((((parent_id IS NULL) AND (depth = 0)) OR ((parent_id IS NOT NULL) AND (depth > 0)))),
    CONSTRAINT chk_news_org_term_slug CHECK (((btrim((slug)::text) <> ''::text) AND ((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text))),
    CONSTRAINT chk_news_org_terms_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_news_org_taxonomy_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_org_taxonomy_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_org_taxonomy_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_org_taxonomy_terms_id_seq OWNED BY public.publishing_news_org_taxonomy_terms.id;


--
-- Name: publishing_news_org_version_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_org_version_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_org_ver_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_news_org_ver_media_pos CHECK (("position" >= 0)),
    CONSTRAINT chk_news_org_ver_media_pres CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text))),
    CONSTRAINT chk_news_org_version_media_usages_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_news_org_version_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_org_version_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_org_version_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_org_version_media_usages_id_seq OWNED BY public.publishing_news_org_version_media_usages.id;


--
-- Name: publishing_news_org_version_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_org_version_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    position_snapshot integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_org_vm_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_news_org_vm_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_news_org_vm_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_news_org_vm_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_news_org_vm_pos CHECK ((("position" >= 0) AND (position_snapshot >= 0))),
    CONSTRAINT chk_news_org_vm_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_news_org_vm_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_news_org_vm_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_news_org_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_org_version_multiple_taxonomy_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_org_version_multiple_taxonomy_assignment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_org_version_multiple_taxonomy_assignment_id_seq OWNED BY public.publishing_news_org_version_multiple_taxonomy_assignments.id;


--
-- Name: publishing_news_org_version_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_org_version_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_org_vs_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text)),
    CONSTRAINT chk_news_org_vs_ks CHECK (((vocabulary_kind_snapshot)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_news_org_vs_ls CHECK (((locale_snapshot)::text = ANY (ARRAY[('ja'::character varying)::text, ('en'::character varying)::text]))),
    CONSTRAINT chk_news_org_vs_path CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_news_org_vs_snap CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_news_org_vs_tp CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_news_org_vs_vp CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_news_org_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_org_version_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_org_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_org_version_single_taxonomy_assignments_id_seq OWNED BY public.publishing_news_org_version_single_taxonomy_assignments.id;


--
-- Name: publishing_news_org_vocabularies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_news_org_vocabularies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    key character varying NOT NULL,
    kind character varying NOT NULL,
    internal_name character varying NOT NULL,
    description text,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_news_org_voc_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_news_org_voc_key CHECK (((btrim((key)::text) <> ''::text) AND ((key)::text ~ '^[a-z][a-z0-9_]*$'::text))),
    CONSTRAINT chk_news_org_voc_kind CHECK (((kind)::text = ANY (ARRAY[('single_hierarchical'::character varying)::text, ('multiple_ordered_flat'::character varying)::text]))),
    CONSTRAINT chk_news_org_voc_name CHECK ((btrim((internal_name)::text) <> ''::text)),
    CONSTRAINT chk_news_org_vocabularies_pid CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_news_org_vocabularies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_news_org_vocabularies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_news_org_vocabularies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_news_org_vocabularies_id_seq OWNED BY public.publishing_news_org_vocabularies.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: publishing_docs_app_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_entries ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_app_entries_id_seq'::regclass);


--
-- Name: publishing_docs_app_entry_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_entry_revisions ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_app_entry_revisions_id_seq'::regclass);


--
-- Name: publishing_docs_app_entry_slugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_entry_slugs ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_app_entry_slugs_id_seq'::regclass);


--
-- Name: publishing_docs_app_entry_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_entry_versions ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_app_entry_versions_id_seq'::regclass);


--
-- Name: publishing_docs_app_publications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_publications ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_app_publications_id_seq'::regclass);


--
-- Name: publishing_docs_app_revision_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_revision_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_app_revision_media_usages_id_seq'::regclass);


--
-- Name: publishing_docs_app_revision_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_revision_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_app_revision_multiple_taxonomy_assignmen_id_seq'::regclass);


--
-- Name: publishing_docs_app_revision_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_revision_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_app_revision_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_docs_app_taxonomy_terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_taxonomy_terms ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_app_taxonomy_terms_id_seq'::regclass);


--
-- Name: publishing_docs_app_version_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_version_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_app_version_media_usages_id_seq'::regclass);


--
-- Name: publishing_docs_app_version_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_version_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_app_version_multiple_taxonomy_assignment_id_seq'::regclass);


--
-- Name: publishing_docs_app_version_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_version_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_app_version_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_docs_app_vocabularies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_vocabularies ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_app_vocabularies_id_seq'::regclass);


--
-- Name: publishing_docs_com_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_entries ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_com_entries_id_seq'::regclass);


--
-- Name: publishing_docs_com_entry_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_entry_revisions ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_com_entry_revisions_id_seq'::regclass);


--
-- Name: publishing_docs_com_entry_slugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_entry_slugs ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_com_entry_slugs_id_seq'::regclass);


--
-- Name: publishing_docs_com_entry_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_entry_versions ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_com_entry_versions_id_seq'::regclass);


--
-- Name: publishing_docs_com_publications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_publications ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_com_publications_id_seq'::regclass);


--
-- Name: publishing_docs_com_revision_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_revision_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_com_revision_media_usages_id_seq'::regclass);


--
-- Name: publishing_docs_com_revision_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_revision_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_com_revision_multiple_taxonomy_assignmen_id_seq'::regclass);


--
-- Name: publishing_docs_com_revision_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_revision_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_com_revision_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_docs_com_taxonomy_terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_taxonomy_terms ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_com_taxonomy_terms_id_seq'::regclass);


--
-- Name: publishing_docs_com_version_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_version_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_com_version_media_usages_id_seq'::regclass);


--
-- Name: publishing_docs_com_version_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_version_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_com_version_multiple_taxonomy_assignment_id_seq'::regclass);


--
-- Name: publishing_docs_com_version_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_version_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_com_version_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_docs_com_vocabularies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_vocabularies ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_com_vocabularies_id_seq'::regclass);


--
-- Name: publishing_docs_org_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_entries ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_org_entries_id_seq'::regclass);


--
-- Name: publishing_docs_org_entry_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_entry_revisions ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_org_entry_revisions_id_seq'::regclass);


--
-- Name: publishing_docs_org_entry_slugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_entry_slugs ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_org_entry_slugs_id_seq'::regclass);


--
-- Name: publishing_docs_org_entry_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_entry_versions ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_org_entry_versions_id_seq'::regclass);


--
-- Name: publishing_docs_org_publications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_publications ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_org_publications_id_seq'::regclass);


--
-- Name: publishing_docs_org_revision_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_revision_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_org_revision_media_usages_id_seq'::regclass);


--
-- Name: publishing_docs_org_revision_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_revision_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_org_revision_multiple_taxonomy_assignmen_id_seq'::regclass);


--
-- Name: publishing_docs_org_revision_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_revision_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_org_revision_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_docs_org_taxonomy_terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_taxonomy_terms ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_org_taxonomy_terms_id_seq'::regclass);


--
-- Name: publishing_docs_org_version_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_version_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_org_version_media_usages_id_seq'::regclass);


--
-- Name: publishing_docs_org_version_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_version_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_org_version_multiple_taxonomy_assignment_id_seq'::regclass);


--
-- Name: publishing_docs_org_version_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_version_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_org_version_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_docs_org_vocabularies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_vocabularies ALTER COLUMN id SET DEFAULT nextval('public.publishing_docs_org_vocabularies_id_seq'::regclass);


--
-- Name: publishing_help_app_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_entries ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_app_entries_id_seq'::regclass);


--
-- Name: publishing_help_app_entry_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_entry_revisions ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_app_entry_revisions_id_seq'::regclass);


--
-- Name: publishing_help_app_entry_slugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_entry_slugs ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_app_entry_slugs_id_seq'::regclass);


--
-- Name: publishing_help_app_entry_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_entry_versions ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_app_entry_versions_id_seq'::regclass);


--
-- Name: publishing_help_app_publications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_publications ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_app_publications_id_seq'::regclass);


--
-- Name: publishing_help_app_revision_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_revision_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_app_revision_media_usages_id_seq'::regclass);


--
-- Name: publishing_help_app_revision_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_revision_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_app_revision_multiple_taxonomy_assignmen_id_seq'::regclass);


--
-- Name: publishing_help_app_revision_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_revision_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_app_revision_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_help_app_taxonomy_terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_taxonomy_terms ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_app_taxonomy_terms_id_seq'::regclass);


--
-- Name: publishing_help_app_version_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_version_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_app_version_media_usages_id_seq'::regclass);


--
-- Name: publishing_help_app_version_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_version_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_app_version_multiple_taxonomy_assignment_id_seq'::regclass);


--
-- Name: publishing_help_app_version_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_version_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_app_version_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_help_app_vocabularies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_vocabularies ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_app_vocabularies_id_seq'::regclass);


--
-- Name: publishing_help_com_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_entries ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_com_entries_id_seq'::regclass);


--
-- Name: publishing_help_com_entry_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_entry_revisions ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_com_entry_revisions_id_seq'::regclass);


--
-- Name: publishing_help_com_entry_slugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_entry_slugs ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_com_entry_slugs_id_seq'::regclass);


--
-- Name: publishing_help_com_entry_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_entry_versions ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_com_entry_versions_id_seq'::regclass);


--
-- Name: publishing_help_com_publications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_publications ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_com_publications_id_seq'::regclass);


--
-- Name: publishing_help_com_revision_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_revision_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_com_revision_media_usages_id_seq'::regclass);


--
-- Name: publishing_help_com_revision_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_revision_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_com_revision_multiple_taxonomy_assignmen_id_seq'::regclass);


--
-- Name: publishing_help_com_revision_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_revision_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_com_revision_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_help_com_taxonomy_terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_taxonomy_terms ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_com_taxonomy_terms_id_seq'::regclass);


--
-- Name: publishing_help_com_version_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_version_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_com_version_media_usages_id_seq'::regclass);


--
-- Name: publishing_help_com_version_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_version_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_com_version_multiple_taxonomy_assignment_id_seq'::regclass);


--
-- Name: publishing_help_com_version_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_version_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_com_version_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_help_com_vocabularies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_vocabularies ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_com_vocabularies_id_seq'::regclass);


--
-- Name: publishing_help_org_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_entries ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_org_entries_id_seq'::regclass);


--
-- Name: publishing_help_org_entry_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_entry_revisions ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_org_entry_revisions_id_seq'::regclass);


--
-- Name: publishing_help_org_entry_slugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_entry_slugs ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_org_entry_slugs_id_seq'::regclass);


--
-- Name: publishing_help_org_entry_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_entry_versions ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_org_entry_versions_id_seq'::regclass);


--
-- Name: publishing_help_org_publications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_publications ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_org_publications_id_seq'::regclass);


--
-- Name: publishing_help_org_revision_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_revision_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_org_revision_media_usages_id_seq'::regclass);


--
-- Name: publishing_help_org_revision_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_revision_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_org_revision_multiple_taxonomy_assignmen_id_seq'::regclass);


--
-- Name: publishing_help_org_revision_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_revision_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_org_revision_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_help_org_taxonomy_terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_taxonomy_terms ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_org_taxonomy_terms_id_seq'::regclass);


--
-- Name: publishing_help_org_version_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_version_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_org_version_media_usages_id_seq'::regclass);


--
-- Name: publishing_help_org_version_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_version_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_org_version_multiple_taxonomy_assignment_id_seq'::regclass);


--
-- Name: publishing_help_org_version_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_version_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_org_version_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_help_org_vocabularies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_vocabularies ALTER COLUMN id SET DEFAULT nextval('public.publishing_help_org_vocabularies_id_seq'::regclass);


--
-- Name: publishing_info_app_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_entries ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_app_entries_id_seq'::regclass);


--
-- Name: publishing_info_app_entry_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_entry_revisions ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_app_entry_revisions_id_seq'::regclass);


--
-- Name: publishing_info_app_entry_slugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_entry_slugs ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_app_entry_slugs_id_seq'::regclass);


--
-- Name: publishing_info_app_entry_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_entry_versions ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_app_entry_versions_id_seq'::regclass);


--
-- Name: publishing_info_app_publications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_publications ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_app_publications_id_seq'::regclass);


--
-- Name: publishing_info_app_revision_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_revision_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_app_revision_media_usages_id_seq'::regclass);


--
-- Name: publishing_info_app_revision_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_revision_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_app_revision_multiple_taxonomy_assignmen_id_seq'::regclass);


--
-- Name: publishing_info_app_revision_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_revision_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_app_revision_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_info_app_taxonomy_terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_taxonomy_terms ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_app_taxonomy_terms_id_seq'::regclass);


--
-- Name: publishing_info_app_version_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_version_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_app_version_media_usages_id_seq'::regclass);


--
-- Name: publishing_info_app_version_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_version_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_app_version_multiple_taxonomy_assignment_id_seq'::regclass);


--
-- Name: publishing_info_app_version_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_version_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_app_version_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_info_app_vocabularies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_vocabularies ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_app_vocabularies_id_seq'::regclass);


--
-- Name: publishing_info_com_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_entries ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_com_entries_id_seq'::regclass);


--
-- Name: publishing_info_com_entry_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_entry_revisions ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_com_entry_revisions_id_seq'::regclass);


--
-- Name: publishing_info_com_entry_slugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_entry_slugs ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_com_entry_slugs_id_seq'::regclass);


--
-- Name: publishing_info_com_entry_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_entry_versions ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_com_entry_versions_id_seq'::regclass);


--
-- Name: publishing_info_com_publications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_publications ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_com_publications_id_seq'::regclass);


--
-- Name: publishing_info_com_revision_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_revision_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_com_revision_media_usages_id_seq'::regclass);


--
-- Name: publishing_info_com_revision_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_revision_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_com_revision_multiple_taxonomy_assignmen_id_seq'::regclass);


--
-- Name: publishing_info_com_revision_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_revision_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_com_revision_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_info_com_taxonomy_terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_taxonomy_terms ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_com_taxonomy_terms_id_seq'::regclass);


--
-- Name: publishing_info_com_version_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_version_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_com_version_media_usages_id_seq'::regclass);


--
-- Name: publishing_info_com_version_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_version_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_com_version_multiple_taxonomy_assignment_id_seq'::regclass);


--
-- Name: publishing_info_com_version_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_version_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_com_version_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_info_com_vocabularies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_vocabularies ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_com_vocabularies_id_seq'::regclass);


--
-- Name: publishing_info_org_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_entries ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_org_entries_id_seq'::regclass);


--
-- Name: publishing_info_org_entry_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_entry_revisions ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_org_entry_revisions_id_seq'::regclass);


--
-- Name: publishing_info_org_entry_slugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_entry_slugs ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_org_entry_slugs_id_seq'::regclass);


--
-- Name: publishing_info_org_entry_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_entry_versions ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_org_entry_versions_id_seq'::regclass);


--
-- Name: publishing_info_org_publications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_publications ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_org_publications_id_seq'::regclass);


--
-- Name: publishing_info_org_revision_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_revision_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_org_revision_media_usages_id_seq'::regclass);


--
-- Name: publishing_info_org_revision_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_revision_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_org_revision_multiple_taxonomy_assignmen_id_seq'::regclass);


--
-- Name: publishing_info_org_revision_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_revision_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_org_revision_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_info_org_taxonomy_terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_taxonomy_terms ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_org_taxonomy_terms_id_seq'::regclass);


--
-- Name: publishing_info_org_version_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_version_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_org_version_media_usages_id_seq'::regclass);


--
-- Name: publishing_info_org_version_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_version_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_org_version_multiple_taxonomy_assignment_id_seq'::regclass);


--
-- Name: publishing_info_org_version_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_version_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_org_version_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_info_org_vocabularies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_vocabularies ALTER COLUMN id SET DEFAULT nextval('public.publishing_info_org_vocabularies_id_seq'::regclass);


--
-- Name: publishing_media_files id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_media_files ALTER COLUMN id SET DEFAULT nextval('public.publishing_media_files_id_seq'::regclass);


--
-- Name: publishing_news_app_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_entries ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_app_entries_id_seq'::regclass);


--
-- Name: publishing_news_app_entry_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_entry_revisions ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_app_entry_revisions_id_seq'::regclass);


--
-- Name: publishing_news_app_entry_slugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_entry_slugs ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_app_entry_slugs_id_seq'::regclass);


--
-- Name: publishing_news_app_entry_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_entry_versions ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_app_entry_versions_id_seq'::regclass);


--
-- Name: publishing_news_app_publications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_publications ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_app_publications_id_seq'::regclass);


--
-- Name: publishing_news_app_revision_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_revision_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_app_revision_media_usages_id_seq'::regclass);


--
-- Name: publishing_news_app_revision_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_revision_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_app_revision_multiple_taxonomy_assignmen_id_seq'::regclass);


--
-- Name: publishing_news_app_revision_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_revision_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_app_revision_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_news_app_taxonomy_terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_taxonomy_terms ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_app_taxonomy_terms_id_seq'::regclass);


--
-- Name: publishing_news_app_version_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_version_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_app_version_media_usages_id_seq'::regclass);


--
-- Name: publishing_news_app_version_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_version_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_app_version_multiple_taxonomy_assignment_id_seq'::regclass);


--
-- Name: publishing_news_app_version_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_version_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_app_version_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_news_app_vocabularies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_vocabularies ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_app_vocabularies_id_seq'::regclass);


--
-- Name: publishing_news_com_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_entries ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_com_entries_id_seq'::regclass);


--
-- Name: publishing_news_com_entry_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_entry_revisions ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_com_entry_revisions_id_seq'::regclass);


--
-- Name: publishing_news_com_entry_slugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_entry_slugs ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_com_entry_slugs_id_seq'::regclass);


--
-- Name: publishing_news_com_entry_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_entry_versions ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_com_entry_versions_id_seq'::regclass);


--
-- Name: publishing_news_com_publications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_publications ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_com_publications_id_seq'::regclass);


--
-- Name: publishing_news_com_revision_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_revision_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_com_revision_media_usages_id_seq'::regclass);


--
-- Name: publishing_news_com_revision_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_revision_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_com_revision_multiple_taxonomy_assignmen_id_seq'::regclass);


--
-- Name: publishing_news_com_revision_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_revision_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_com_revision_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_news_com_taxonomy_terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_taxonomy_terms ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_com_taxonomy_terms_id_seq'::regclass);


--
-- Name: publishing_news_com_version_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_version_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_com_version_media_usages_id_seq'::regclass);


--
-- Name: publishing_news_com_version_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_version_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_com_version_multiple_taxonomy_assignment_id_seq'::regclass);


--
-- Name: publishing_news_com_version_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_version_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_com_version_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_news_com_vocabularies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_vocabularies ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_com_vocabularies_id_seq'::regclass);


--
-- Name: publishing_news_org_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_entries ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_org_entries_id_seq'::regclass);


--
-- Name: publishing_news_org_entry_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_entry_revisions ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_org_entry_revisions_id_seq'::regclass);


--
-- Name: publishing_news_org_entry_slugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_entry_slugs ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_org_entry_slugs_id_seq'::regclass);


--
-- Name: publishing_news_org_entry_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_entry_versions ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_org_entry_versions_id_seq'::regclass);


--
-- Name: publishing_news_org_publications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_publications ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_org_publications_id_seq'::regclass);


--
-- Name: publishing_news_org_revision_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_revision_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_org_revision_media_usages_id_seq'::regclass);


--
-- Name: publishing_news_org_revision_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_revision_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_org_revision_multiple_taxonomy_assignmen_id_seq'::regclass);


--
-- Name: publishing_news_org_revision_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_revision_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_org_revision_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_news_org_taxonomy_terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_taxonomy_terms ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_org_taxonomy_terms_id_seq'::regclass);


--
-- Name: publishing_news_org_version_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_version_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_org_version_media_usages_id_seq'::regclass);


--
-- Name: publishing_news_org_version_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_version_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_org_version_multiple_taxonomy_assignment_id_seq'::regclass);


--
-- Name: publishing_news_org_version_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_version_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_org_version_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_news_org_vocabularies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_vocabularies ALTER COLUMN id SET DEFAULT nextval('public.publishing_news_org_vocabularies_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: publishing_docs_app_publications excl_docs_app_pub_windows; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_publications
    ADD CONSTRAINT excl_docs_app_pub_windows EXCLUDE USING gist (entry_id WITH =, tstzrange(effective_from, effective_until, '[)'::text) WITH &&) WHERE ((cancelled_at IS NULL));


--
-- Name: publishing_docs_com_publications excl_docs_com_pub_windows; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_publications
    ADD CONSTRAINT excl_docs_com_pub_windows EXCLUDE USING gist (entry_id WITH =, tstzrange(effective_from, effective_until, '[)'::text) WITH &&) WHERE ((cancelled_at IS NULL));


--
-- Name: publishing_docs_org_publications excl_docs_org_pub_windows; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_publications
    ADD CONSTRAINT excl_docs_org_pub_windows EXCLUDE USING gist (entry_id WITH =, tstzrange(effective_from, effective_until, '[)'::text) WITH &&) WHERE ((cancelled_at IS NULL));


--
-- Name: publishing_help_app_publications excl_help_app_pub_windows; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_publications
    ADD CONSTRAINT excl_help_app_pub_windows EXCLUDE USING gist (entry_id WITH =, tstzrange(effective_from, effective_until, '[)'::text) WITH &&) WHERE ((cancelled_at IS NULL));


--
-- Name: publishing_help_com_publications excl_help_com_pub_windows; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_publications
    ADD CONSTRAINT excl_help_com_pub_windows EXCLUDE USING gist (entry_id WITH =, tstzrange(effective_from, effective_until, '[)'::text) WITH &&) WHERE ((cancelled_at IS NULL));


--
-- Name: publishing_help_org_publications excl_help_org_pub_windows; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_publications
    ADD CONSTRAINT excl_help_org_pub_windows EXCLUDE USING gist (entry_id WITH =, tstzrange(effective_from, effective_until, '[)'::text) WITH &&) WHERE ((cancelled_at IS NULL));


--
-- Name: publishing_info_app_publications excl_info_app_pub_windows; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_publications
    ADD CONSTRAINT excl_info_app_pub_windows EXCLUDE USING gist (entry_id WITH =, tstzrange(effective_from, effective_until, '[)'::text) WITH &&) WHERE ((cancelled_at IS NULL));


--
-- Name: publishing_info_com_publications excl_info_com_pub_windows; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_publications
    ADD CONSTRAINT excl_info_com_pub_windows EXCLUDE USING gist (entry_id WITH =, tstzrange(effective_from, effective_until, '[)'::text) WITH &&) WHERE ((cancelled_at IS NULL));


--
-- Name: publishing_info_org_publications excl_info_org_pub_windows; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_publications
    ADD CONSTRAINT excl_info_org_pub_windows EXCLUDE USING gist (entry_id WITH =, tstzrange(effective_from, effective_until, '[)'::text) WITH &&) WHERE ((cancelled_at IS NULL));


--
-- Name: publishing_news_app_publications excl_news_app_pub_windows; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_publications
    ADD CONSTRAINT excl_news_app_pub_windows EXCLUDE USING gist (entry_id WITH =, tstzrange(effective_from, effective_until, '[)'::text) WITH &&) WHERE ((cancelled_at IS NULL));


--
-- Name: publishing_news_com_publications excl_news_com_pub_windows; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_publications
    ADD CONSTRAINT excl_news_com_pub_windows EXCLUDE USING gist (entry_id WITH =, tstzrange(effective_from, effective_until, '[)'::text) WITH &&) WHERE ((cancelled_at IS NULL));


--
-- Name: publishing_news_org_publications excl_news_org_pub_windows; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_publications
    ADD CONSTRAINT excl_news_org_pub_windows EXCLUDE USING gist (entry_id WITH =, tstzrange(effective_from, effective_until, '[)'::text) WITH &&) WHERE ((cancelled_at IS NULL));


--
-- Name: publishing_docs_app_entries publishing_docs_app_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_entries
    ADD CONSTRAINT publishing_docs_app_entries_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_app_entry_revisions publishing_docs_app_entry_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_entry_revisions
    ADD CONSTRAINT publishing_docs_app_entry_revisions_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_app_entry_slugs publishing_docs_app_entry_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_entry_slugs
    ADD CONSTRAINT publishing_docs_app_entry_slugs_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_app_entry_versions publishing_docs_app_entry_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_entry_versions
    ADD CONSTRAINT publishing_docs_app_entry_versions_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_app_publications publishing_docs_app_publications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_publications
    ADD CONSTRAINT publishing_docs_app_publications_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_app_revision_media_usages publishing_docs_app_revision_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_revision_media_usages
    ADD CONSTRAINT publishing_docs_app_revision_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_app_revision_multiple_taxonomy_assignments publishing_docs_app_revision_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_docs_app_revision_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_app_revision_single_taxonomy_assignments publishing_docs_app_revision_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_revision_single_taxonomy_assignments
    ADD CONSTRAINT publishing_docs_app_revision_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_app_taxonomy_terms publishing_docs_app_taxonomy_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_taxonomy_terms
    ADD CONSTRAINT publishing_docs_app_taxonomy_terms_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_app_version_media_usages publishing_docs_app_version_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_version_media_usages
    ADD CONSTRAINT publishing_docs_app_version_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_app_version_multiple_taxonomy_assignments publishing_docs_app_version_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_version_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_docs_app_version_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_app_version_single_taxonomy_assignments publishing_docs_app_version_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_version_single_taxonomy_assignments
    ADD CONSTRAINT publishing_docs_app_version_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_app_vocabularies publishing_docs_app_vocabularies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_vocabularies
    ADD CONSTRAINT publishing_docs_app_vocabularies_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_com_entries publishing_docs_com_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_entries
    ADD CONSTRAINT publishing_docs_com_entries_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_com_entry_revisions publishing_docs_com_entry_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_entry_revisions
    ADD CONSTRAINT publishing_docs_com_entry_revisions_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_com_entry_slugs publishing_docs_com_entry_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_entry_slugs
    ADD CONSTRAINT publishing_docs_com_entry_slugs_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_com_entry_versions publishing_docs_com_entry_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_entry_versions
    ADD CONSTRAINT publishing_docs_com_entry_versions_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_com_publications publishing_docs_com_publications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_publications
    ADD CONSTRAINT publishing_docs_com_publications_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_com_revision_media_usages publishing_docs_com_revision_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_revision_media_usages
    ADD CONSTRAINT publishing_docs_com_revision_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_com_revision_multiple_taxonomy_assignments publishing_docs_com_revision_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_docs_com_revision_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_com_revision_single_taxonomy_assignments publishing_docs_com_revision_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_revision_single_taxonomy_assignments
    ADD CONSTRAINT publishing_docs_com_revision_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_com_taxonomy_terms publishing_docs_com_taxonomy_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_taxonomy_terms
    ADD CONSTRAINT publishing_docs_com_taxonomy_terms_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_com_version_media_usages publishing_docs_com_version_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_version_media_usages
    ADD CONSTRAINT publishing_docs_com_version_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_com_version_multiple_taxonomy_assignments publishing_docs_com_version_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_version_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_docs_com_version_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_com_version_single_taxonomy_assignments publishing_docs_com_version_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_version_single_taxonomy_assignments
    ADD CONSTRAINT publishing_docs_com_version_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_com_vocabularies publishing_docs_com_vocabularies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_vocabularies
    ADD CONSTRAINT publishing_docs_com_vocabularies_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_org_entries publishing_docs_org_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_entries
    ADD CONSTRAINT publishing_docs_org_entries_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_org_entry_revisions publishing_docs_org_entry_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_entry_revisions
    ADD CONSTRAINT publishing_docs_org_entry_revisions_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_org_entry_slugs publishing_docs_org_entry_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_entry_slugs
    ADD CONSTRAINT publishing_docs_org_entry_slugs_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_org_entry_versions publishing_docs_org_entry_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_entry_versions
    ADD CONSTRAINT publishing_docs_org_entry_versions_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_org_publications publishing_docs_org_publications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_publications
    ADD CONSTRAINT publishing_docs_org_publications_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_org_revision_media_usages publishing_docs_org_revision_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_revision_media_usages
    ADD CONSTRAINT publishing_docs_org_revision_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_org_revision_multiple_taxonomy_assignments publishing_docs_org_revision_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_docs_org_revision_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_org_revision_single_taxonomy_assignments publishing_docs_org_revision_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_revision_single_taxonomy_assignments
    ADD CONSTRAINT publishing_docs_org_revision_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_org_taxonomy_terms publishing_docs_org_taxonomy_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_taxonomy_terms
    ADD CONSTRAINT publishing_docs_org_taxonomy_terms_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_org_version_media_usages publishing_docs_org_version_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_version_media_usages
    ADD CONSTRAINT publishing_docs_org_version_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_org_version_multiple_taxonomy_assignments publishing_docs_org_version_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_version_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_docs_org_version_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_org_version_single_taxonomy_assignments publishing_docs_org_version_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_version_single_taxonomy_assignments
    ADD CONSTRAINT publishing_docs_org_version_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_docs_org_vocabularies publishing_docs_org_vocabularies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_vocabularies
    ADD CONSTRAINT publishing_docs_org_vocabularies_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_app_entries publishing_help_app_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_entries
    ADD CONSTRAINT publishing_help_app_entries_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_app_entry_revisions publishing_help_app_entry_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_entry_revisions
    ADD CONSTRAINT publishing_help_app_entry_revisions_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_app_entry_slugs publishing_help_app_entry_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_entry_slugs
    ADD CONSTRAINT publishing_help_app_entry_slugs_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_app_entry_versions publishing_help_app_entry_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_entry_versions
    ADD CONSTRAINT publishing_help_app_entry_versions_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_app_publications publishing_help_app_publications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_publications
    ADD CONSTRAINT publishing_help_app_publications_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_app_revision_media_usages publishing_help_app_revision_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_revision_media_usages
    ADD CONSTRAINT publishing_help_app_revision_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_app_revision_multiple_taxonomy_assignments publishing_help_app_revision_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_help_app_revision_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_app_revision_single_taxonomy_assignments publishing_help_app_revision_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_revision_single_taxonomy_assignments
    ADD CONSTRAINT publishing_help_app_revision_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_app_taxonomy_terms publishing_help_app_taxonomy_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_taxonomy_terms
    ADD CONSTRAINT publishing_help_app_taxonomy_terms_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_app_version_media_usages publishing_help_app_version_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_version_media_usages
    ADD CONSTRAINT publishing_help_app_version_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_app_version_multiple_taxonomy_assignments publishing_help_app_version_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_version_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_help_app_version_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_app_version_single_taxonomy_assignments publishing_help_app_version_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_version_single_taxonomy_assignments
    ADD CONSTRAINT publishing_help_app_version_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_app_vocabularies publishing_help_app_vocabularies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_vocabularies
    ADD CONSTRAINT publishing_help_app_vocabularies_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_com_entries publishing_help_com_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_entries
    ADD CONSTRAINT publishing_help_com_entries_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_com_entry_revisions publishing_help_com_entry_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_entry_revisions
    ADD CONSTRAINT publishing_help_com_entry_revisions_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_com_entry_slugs publishing_help_com_entry_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_entry_slugs
    ADD CONSTRAINT publishing_help_com_entry_slugs_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_com_entry_versions publishing_help_com_entry_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_entry_versions
    ADD CONSTRAINT publishing_help_com_entry_versions_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_com_publications publishing_help_com_publications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_publications
    ADD CONSTRAINT publishing_help_com_publications_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_com_revision_media_usages publishing_help_com_revision_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_revision_media_usages
    ADD CONSTRAINT publishing_help_com_revision_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_com_revision_multiple_taxonomy_assignments publishing_help_com_revision_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_help_com_revision_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_com_revision_single_taxonomy_assignments publishing_help_com_revision_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_revision_single_taxonomy_assignments
    ADD CONSTRAINT publishing_help_com_revision_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_com_taxonomy_terms publishing_help_com_taxonomy_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_taxonomy_terms
    ADD CONSTRAINT publishing_help_com_taxonomy_terms_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_com_version_media_usages publishing_help_com_version_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_version_media_usages
    ADD CONSTRAINT publishing_help_com_version_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_com_version_multiple_taxonomy_assignments publishing_help_com_version_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_version_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_help_com_version_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_com_version_single_taxonomy_assignments publishing_help_com_version_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_version_single_taxonomy_assignments
    ADD CONSTRAINT publishing_help_com_version_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_com_vocabularies publishing_help_com_vocabularies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_vocabularies
    ADD CONSTRAINT publishing_help_com_vocabularies_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_org_entries publishing_help_org_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_entries
    ADD CONSTRAINT publishing_help_org_entries_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_org_entry_revisions publishing_help_org_entry_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_entry_revisions
    ADD CONSTRAINT publishing_help_org_entry_revisions_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_org_entry_slugs publishing_help_org_entry_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_entry_slugs
    ADD CONSTRAINT publishing_help_org_entry_slugs_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_org_entry_versions publishing_help_org_entry_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_entry_versions
    ADD CONSTRAINT publishing_help_org_entry_versions_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_org_publications publishing_help_org_publications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_publications
    ADD CONSTRAINT publishing_help_org_publications_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_org_revision_media_usages publishing_help_org_revision_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_revision_media_usages
    ADD CONSTRAINT publishing_help_org_revision_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_org_revision_multiple_taxonomy_assignments publishing_help_org_revision_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_help_org_revision_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_org_revision_single_taxonomy_assignments publishing_help_org_revision_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_revision_single_taxonomy_assignments
    ADD CONSTRAINT publishing_help_org_revision_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_org_taxonomy_terms publishing_help_org_taxonomy_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_taxonomy_terms
    ADD CONSTRAINT publishing_help_org_taxonomy_terms_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_org_version_media_usages publishing_help_org_version_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_version_media_usages
    ADD CONSTRAINT publishing_help_org_version_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_org_version_multiple_taxonomy_assignments publishing_help_org_version_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_version_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_help_org_version_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_org_version_single_taxonomy_assignments publishing_help_org_version_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_version_single_taxonomy_assignments
    ADD CONSTRAINT publishing_help_org_version_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_help_org_vocabularies publishing_help_org_vocabularies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_vocabularies
    ADD CONSTRAINT publishing_help_org_vocabularies_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_app_entries publishing_info_app_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_entries
    ADD CONSTRAINT publishing_info_app_entries_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_app_entry_revisions publishing_info_app_entry_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_entry_revisions
    ADD CONSTRAINT publishing_info_app_entry_revisions_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_app_entry_slugs publishing_info_app_entry_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_entry_slugs
    ADD CONSTRAINT publishing_info_app_entry_slugs_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_app_entry_versions publishing_info_app_entry_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_entry_versions
    ADD CONSTRAINT publishing_info_app_entry_versions_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_app_publications publishing_info_app_publications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_publications
    ADD CONSTRAINT publishing_info_app_publications_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_app_revision_media_usages publishing_info_app_revision_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_revision_media_usages
    ADD CONSTRAINT publishing_info_app_revision_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_app_revision_multiple_taxonomy_assignments publishing_info_app_revision_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_info_app_revision_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_app_revision_single_taxonomy_assignments publishing_info_app_revision_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_revision_single_taxonomy_assignments
    ADD CONSTRAINT publishing_info_app_revision_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_app_taxonomy_terms publishing_info_app_taxonomy_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_taxonomy_terms
    ADD CONSTRAINT publishing_info_app_taxonomy_terms_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_app_version_media_usages publishing_info_app_version_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_version_media_usages
    ADD CONSTRAINT publishing_info_app_version_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_app_version_multiple_taxonomy_assignments publishing_info_app_version_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_version_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_info_app_version_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_app_version_single_taxonomy_assignments publishing_info_app_version_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_version_single_taxonomy_assignments
    ADD CONSTRAINT publishing_info_app_version_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_app_vocabularies publishing_info_app_vocabularies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_vocabularies
    ADD CONSTRAINT publishing_info_app_vocabularies_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_com_entries publishing_info_com_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_entries
    ADD CONSTRAINT publishing_info_com_entries_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_com_entry_revisions publishing_info_com_entry_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_entry_revisions
    ADD CONSTRAINT publishing_info_com_entry_revisions_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_com_entry_slugs publishing_info_com_entry_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_entry_slugs
    ADD CONSTRAINT publishing_info_com_entry_slugs_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_com_entry_versions publishing_info_com_entry_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_entry_versions
    ADD CONSTRAINT publishing_info_com_entry_versions_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_com_publications publishing_info_com_publications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_publications
    ADD CONSTRAINT publishing_info_com_publications_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_com_revision_media_usages publishing_info_com_revision_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_revision_media_usages
    ADD CONSTRAINT publishing_info_com_revision_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_com_revision_multiple_taxonomy_assignments publishing_info_com_revision_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_info_com_revision_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_com_revision_single_taxonomy_assignments publishing_info_com_revision_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_revision_single_taxonomy_assignments
    ADD CONSTRAINT publishing_info_com_revision_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_com_taxonomy_terms publishing_info_com_taxonomy_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_taxonomy_terms
    ADD CONSTRAINT publishing_info_com_taxonomy_terms_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_com_version_media_usages publishing_info_com_version_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_version_media_usages
    ADD CONSTRAINT publishing_info_com_version_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_com_version_multiple_taxonomy_assignments publishing_info_com_version_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_version_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_info_com_version_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_com_version_single_taxonomy_assignments publishing_info_com_version_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_version_single_taxonomy_assignments
    ADD CONSTRAINT publishing_info_com_version_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_com_vocabularies publishing_info_com_vocabularies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_vocabularies
    ADD CONSTRAINT publishing_info_com_vocabularies_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_org_entries publishing_info_org_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_entries
    ADD CONSTRAINT publishing_info_org_entries_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_org_entry_revisions publishing_info_org_entry_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_entry_revisions
    ADD CONSTRAINT publishing_info_org_entry_revisions_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_org_entry_slugs publishing_info_org_entry_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_entry_slugs
    ADD CONSTRAINT publishing_info_org_entry_slugs_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_org_entry_versions publishing_info_org_entry_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_entry_versions
    ADD CONSTRAINT publishing_info_org_entry_versions_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_org_publications publishing_info_org_publications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_publications
    ADD CONSTRAINT publishing_info_org_publications_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_org_revision_media_usages publishing_info_org_revision_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_revision_media_usages
    ADD CONSTRAINT publishing_info_org_revision_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_org_revision_multiple_taxonomy_assignments publishing_info_org_revision_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_info_org_revision_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_org_revision_single_taxonomy_assignments publishing_info_org_revision_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_revision_single_taxonomy_assignments
    ADD CONSTRAINT publishing_info_org_revision_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_org_taxonomy_terms publishing_info_org_taxonomy_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_taxonomy_terms
    ADD CONSTRAINT publishing_info_org_taxonomy_terms_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_org_version_media_usages publishing_info_org_version_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_version_media_usages
    ADD CONSTRAINT publishing_info_org_version_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_org_version_multiple_taxonomy_assignments publishing_info_org_version_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_version_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_info_org_version_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_org_version_single_taxonomy_assignments publishing_info_org_version_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_version_single_taxonomy_assignments
    ADD CONSTRAINT publishing_info_org_version_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_info_org_vocabularies publishing_info_org_vocabularies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_vocabularies
    ADD CONSTRAINT publishing_info_org_vocabularies_pkey PRIMARY KEY (id);


--
-- Name: publishing_media_files publishing_media_files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_media_files
    ADD CONSTRAINT publishing_media_files_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_app_entries publishing_news_app_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_entries
    ADD CONSTRAINT publishing_news_app_entries_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_app_entry_revisions publishing_news_app_entry_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_entry_revisions
    ADD CONSTRAINT publishing_news_app_entry_revisions_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_app_entry_slugs publishing_news_app_entry_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_entry_slugs
    ADD CONSTRAINT publishing_news_app_entry_slugs_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_app_entry_versions publishing_news_app_entry_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_entry_versions
    ADD CONSTRAINT publishing_news_app_entry_versions_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_app_publications publishing_news_app_publications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_publications
    ADD CONSTRAINT publishing_news_app_publications_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_app_revision_media_usages publishing_news_app_revision_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_revision_media_usages
    ADD CONSTRAINT publishing_news_app_revision_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_app_revision_multiple_taxonomy_assignments publishing_news_app_revision_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_news_app_revision_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_app_revision_single_taxonomy_assignments publishing_news_app_revision_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_revision_single_taxonomy_assignments
    ADD CONSTRAINT publishing_news_app_revision_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_app_taxonomy_terms publishing_news_app_taxonomy_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_taxonomy_terms
    ADD CONSTRAINT publishing_news_app_taxonomy_terms_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_app_version_media_usages publishing_news_app_version_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_version_media_usages
    ADD CONSTRAINT publishing_news_app_version_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_app_version_multiple_taxonomy_assignments publishing_news_app_version_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_version_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_news_app_version_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_app_version_single_taxonomy_assignments publishing_news_app_version_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_version_single_taxonomy_assignments
    ADD CONSTRAINT publishing_news_app_version_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_app_vocabularies publishing_news_app_vocabularies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_vocabularies
    ADD CONSTRAINT publishing_news_app_vocabularies_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_com_entries publishing_news_com_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_entries
    ADD CONSTRAINT publishing_news_com_entries_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_com_entry_revisions publishing_news_com_entry_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_entry_revisions
    ADD CONSTRAINT publishing_news_com_entry_revisions_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_com_entry_slugs publishing_news_com_entry_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_entry_slugs
    ADD CONSTRAINT publishing_news_com_entry_slugs_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_com_entry_versions publishing_news_com_entry_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_entry_versions
    ADD CONSTRAINT publishing_news_com_entry_versions_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_com_publications publishing_news_com_publications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_publications
    ADD CONSTRAINT publishing_news_com_publications_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_com_revision_media_usages publishing_news_com_revision_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_revision_media_usages
    ADD CONSTRAINT publishing_news_com_revision_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_com_revision_multiple_taxonomy_assignments publishing_news_com_revision_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_news_com_revision_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_com_revision_single_taxonomy_assignments publishing_news_com_revision_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_revision_single_taxonomy_assignments
    ADD CONSTRAINT publishing_news_com_revision_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_com_taxonomy_terms publishing_news_com_taxonomy_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_taxonomy_terms
    ADD CONSTRAINT publishing_news_com_taxonomy_terms_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_com_version_media_usages publishing_news_com_version_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_version_media_usages
    ADD CONSTRAINT publishing_news_com_version_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_com_version_multiple_taxonomy_assignments publishing_news_com_version_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_version_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_news_com_version_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_com_version_single_taxonomy_assignments publishing_news_com_version_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_version_single_taxonomy_assignments
    ADD CONSTRAINT publishing_news_com_version_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_com_vocabularies publishing_news_com_vocabularies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_vocabularies
    ADD CONSTRAINT publishing_news_com_vocabularies_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_org_entries publishing_news_org_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_entries
    ADD CONSTRAINT publishing_news_org_entries_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_org_entry_revisions publishing_news_org_entry_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_entry_revisions
    ADD CONSTRAINT publishing_news_org_entry_revisions_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_org_entry_slugs publishing_news_org_entry_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_entry_slugs
    ADD CONSTRAINT publishing_news_org_entry_slugs_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_org_entry_versions publishing_news_org_entry_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_entry_versions
    ADD CONSTRAINT publishing_news_org_entry_versions_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_org_publications publishing_news_org_publications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_publications
    ADD CONSTRAINT publishing_news_org_publications_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_org_revision_media_usages publishing_news_org_revision_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_revision_media_usages
    ADD CONSTRAINT publishing_news_org_revision_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_org_revision_multiple_taxonomy_assignments publishing_news_org_revision_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_news_org_revision_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_org_revision_single_taxonomy_assignments publishing_news_org_revision_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_revision_single_taxonomy_assignments
    ADD CONSTRAINT publishing_news_org_revision_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_org_taxonomy_terms publishing_news_org_taxonomy_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_taxonomy_terms
    ADD CONSTRAINT publishing_news_org_taxonomy_terms_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_org_version_media_usages publishing_news_org_version_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_version_media_usages
    ADD CONSTRAINT publishing_news_org_version_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_org_version_multiple_taxonomy_assignments publishing_news_org_version_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_version_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_news_org_version_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_org_version_single_taxonomy_assignments publishing_news_org_version_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_version_single_taxonomy_assignments
    ADD CONSTRAINT publishing_news_org_version_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_news_org_vocabularies publishing_news_org_vocabularies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_vocabularies
    ADD CONSTRAINT publishing_news_org_vocabularies_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: idx_docs_app_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_app_rm_term ON public.publishing_docs_app_revision_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_docs_app_rm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_app_rm_voc ON public.publishing_docs_app_revision_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_docs_app_rs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_app_rs_term ON public.publishing_docs_app_revision_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_docs_app_rs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_app_rs_voc ON public.publishing_docs_app_revision_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_docs_app_term_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_app_term_parent ON public.publishing_docs_app_taxonomy_terms USING btree (parent_id);


--
-- Name: idx_docs_app_vm_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_app_vm_filter ON public.publishing_docs_app_version_multiple_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_docs_app_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_app_vm_term ON public.publishing_docs_app_version_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_docs_app_vm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_app_vm_voc ON public.publishing_docs_app_version_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_docs_app_vs_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_app_vs_filter ON public.publishing_docs_app_version_single_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_docs_app_vs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_app_vs_term ON public.publishing_docs_app_version_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_docs_app_vs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_app_vs_voc ON public.publishing_docs_app_version_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_docs_com_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_com_rm_term ON public.publishing_docs_com_revision_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_docs_com_rm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_com_rm_voc ON public.publishing_docs_com_revision_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_docs_com_rs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_com_rs_term ON public.publishing_docs_com_revision_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_docs_com_rs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_com_rs_voc ON public.publishing_docs_com_revision_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_docs_com_term_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_com_term_parent ON public.publishing_docs_com_taxonomy_terms USING btree (parent_id);


--
-- Name: idx_docs_com_vm_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_com_vm_filter ON public.publishing_docs_com_version_multiple_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_docs_com_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_com_vm_term ON public.publishing_docs_com_version_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_docs_com_vm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_com_vm_voc ON public.publishing_docs_com_version_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_docs_com_vs_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_com_vs_filter ON public.publishing_docs_com_version_single_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_docs_com_vs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_com_vs_term ON public.publishing_docs_com_version_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_docs_com_vs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_com_vs_voc ON public.publishing_docs_com_version_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_docs_org_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_org_rm_term ON public.publishing_docs_org_revision_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_docs_org_rm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_org_rm_voc ON public.publishing_docs_org_revision_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_docs_org_rs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_org_rs_term ON public.publishing_docs_org_revision_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_docs_org_rs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_org_rs_voc ON public.publishing_docs_org_revision_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_docs_org_term_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_org_term_parent ON public.publishing_docs_org_taxonomy_terms USING btree (parent_id);


--
-- Name: idx_docs_org_vm_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_org_vm_filter ON public.publishing_docs_org_version_multiple_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_docs_org_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_org_vm_term ON public.publishing_docs_org_version_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_docs_org_vm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_org_vm_voc ON public.publishing_docs_org_version_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_docs_org_vs_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_org_vs_filter ON public.publishing_docs_org_version_single_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_docs_org_vs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_org_vs_term ON public.publishing_docs_org_version_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_docs_org_vs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docs_org_vs_voc ON public.publishing_docs_org_version_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_help_app_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_app_rm_term ON public.publishing_help_app_revision_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_help_app_rm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_app_rm_voc ON public.publishing_help_app_revision_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_help_app_rs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_app_rs_term ON public.publishing_help_app_revision_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_help_app_rs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_app_rs_voc ON public.publishing_help_app_revision_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_help_app_term_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_app_term_parent ON public.publishing_help_app_taxonomy_terms USING btree (parent_id);


--
-- Name: idx_help_app_vm_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_app_vm_filter ON public.publishing_help_app_version_multiple_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_help_app_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_app_vm_term ON public.publishing_help_app_version_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_help_app_vm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_app_vm_voc ON public.publishing_help_app_version_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_help_app_vs_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_app_vs_filter ON public.publishing_help_app_version_single_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_help_app_vs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_app_vs_term ON public.publishing_help_app_version_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_help_app_vs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_app_vs_voc ON public.publishing_help_app_version_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_help_com_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_com_rm_term ON public.publishing_help_com_revision_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_help_com_rm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_com_rm_voc ON public.publishing_help_com_revision_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_help_com_rs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_com_rs_term ON public.publishing_help_com_revision_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_help_com_rs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_com_rs_voc ON public.publishing_help_com_revision_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_help_com_term_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_com_term_parent ON public.publishing_help_com_taxonomy_terms USING btree (parent_id);


--
-- Name: idx_help_com_vm_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_com_vm_filter ON public.publishing_help_com_version_multiple_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_help_com_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_com_vm_term ON public.publishing_help_com_version_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_help_com_vm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_com_vm_voc ON public.publishing_help_com_version_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_help_com_vs_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_com_vs_filter ON public.publishing_help_com_version_single_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_help_com_vs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_com_vs_term ON public.publishing_help_com_version_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_help_com_vs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_com_vs_voc ON public.publishing_help_com_version_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_help_org_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_org_rm_term ON public.publishing_help_org_revision_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_help_org_rm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_org_rm_voc ON public.publishing_help_org_revision_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_help_org_rs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_org_rs_term ON public.publishing_help_org_revision_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_help_org_rs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_org_rs_voc ON public.publishing_help_org_revision_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_help_org_term_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_org_term_parent ON public.publishing_help_org_taxonomy_terms USING btree (parent_id);


--
-- Name: idx_help_org_vm_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_org_vm_filter ON public.publishing_help_org_version_multiple_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_help_org_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_org_vm_term ON public.publishing_help_org_version_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_help_org_vm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_org_vm_voc ON public.publishing_help_org_version_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_help_org_vs_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_org_vs_filter ON public.publishing_help_org_version_single_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_help_org_vs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_org_vs_term ON public.publishing_help_org_version_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_help_org_vs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_help_org_vs_voc ON public.publishing_help_org_version_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_info_app_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_app_rm_term ON public.publishing_info_app_revision_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_info_app_rm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_app_rm_voc ON public.publishing_info_app_revision_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_info_app_rs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_app_rs_term ON public.publishing_info_app_revision_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_info_app_rs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_app_rs_voc ON public.publishing_info_app_revision_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_info_app_term_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_app_term_parent ON public.publishing_info_app_taxonomy_terms USING btree (parent_id);


--
-- Name: idx_info_app_vm_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_app_vm_filter ON public.publishing_info_app_version_multiple_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_info_app_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_app_vm_term ON public.publishing_info_app_version_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_info_app_vm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_app_vm_voc ON public.publishing_info_app_version_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_info_app_vs_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_app_vs_filter ON public.publishing_info_app_version_single_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_info_app_vs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_app_vs_term ON public.publishing_info_app_version_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_info_app_vs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_app_vs_voc ON public.publishing_info_app_version_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_info_com_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_com_rm_term ON public.publishing_info_com_revision_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_info_com_rm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_com_rm_voc ON public.publishing_info_com_revision_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_info_com_rs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_com_rs_term ON public.publishing_info_com_revision_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_info_com_rs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_com_rs_voc ON public.publishing_info_com_revision_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_info_com_term_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_com_term_parent ON public.publishing_info_com_taxonomy_terms USING btree (parent_id);


--
-- Name: idx_info_com_vm_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_com_vm_filter ON public.publishing_info_com_version_multiple_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_info_com_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_com_vm_term ON public.publishing_info_com_version_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_info_com_vm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_com_vm_voc ON public.publishing_info_com_version_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_info_com_vs_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_com_vs_filter ON public.publishing_info_com_version_single_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_info_com_vs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_com_vs_term ON public.publishing_info_com_version_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_info_com_vs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_com_vs_voc ON public.publishing_info_com_version_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_info_org_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_org_rm_term ON public.publishing_info_org_revision_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_info_org_rm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_org_rm_voc ON public.publishing_info_org_revision_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_info_org_rs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_org_rs_term ON public.publishing_info_org_revision_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_info_org_rs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_org_rs_voc ON public.publishing_info_org_revision_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_info_org_term_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_org_term_parent ON public.publishing_info_org_taxonomy_terms USING btree (parent_id);


--
-- Name: idx_info_org_vm_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_org_vm_filter ON public.publishing_info_org_version_multiple_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_info_org_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_org_vm_term ON public.publishing_info_org_version_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_info_org_vm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_org_vm_voc ON public.publishing_info_org_version_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_info_org_vs_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_org_vs_filter ON public.publishing_info_org_version_single_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_info_org_vs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_org_vs_term ON public.publishing_info_org_version_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_info_org_vs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_info_org_vs_voc ON public.publishing_info_org_version_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_news_app_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_app_rm_term ON public.publishing_news_app_revision_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_news_app_rm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_app_rm_voc ON public.publishing_news_app_revision_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_news_app_rs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_app_rs_term ON public.publishing_news_app_revision_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_news_app_rs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_app_rs_voc ON public.publishing_news_app_revision_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_news_app_term_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_app_term_parent ON public.publishing_news_app_taxonomy_terms USING btree (parent_id);


--
-- Name: idx_news_app_vm_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_app_vm_filter ON public.publishing_news_app_version_multiple_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_news_app_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_app_vm_term ON public.publishing_news_app_version_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_news_app_vm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_app_vm_voc ON public.publishing_news_app_version_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_news_app_vs_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_app_vs_filter ON public.publishing_news_app_version_single_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_news_app_vs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_app_vs_term ON public.publishing_news_app_version_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_news_app_vs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_app_vs_voc ON public.publishing_news_app_version_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_news_com_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_com_rm_term ON public.publishing_news_com_revision_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_news_com_rm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_com_rm_voc ON public.publishing_news_com_revision_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_news_com_rs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_com_rs_term ON public.publishing_news_com_revision_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_news_com_rs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_com_rs_voc ON public.publishing_news_com_revision_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_news_com_term_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_com_term_parent ON public.publishing_news_com_taxonomy_terms USING btree (parent_id);


--
-- Name: idx_news_com_vm_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_com_vm_filter ON public.publishing_news_com_version_multiple_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_news_com_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_com_vm_term ON public.publishing_news_com_version_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_news_com_vm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_com_vm_voc ON public.publishing_news_com_version_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_news_com_vs_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_com_vs_filter ON public.publishing_news_com_version_single_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_news_com_vs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_com_vs_term ON public.publishing_news_com_version_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_news_com_vs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_com_vs_voc ON public.publishing_news_com_version_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_news_org_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_org_rm_term ON public.publishing_news_org_revision_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_news_org_rm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_org_rm_voc ON public.publishing_news_org_revision_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_news_org_rs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_org_rs_term ON public.publishing_news_org_revision_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_news_org_rs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_org_rs_voc ON public.publishing_news_org_revision_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_news_org_term_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_org_term_parent ON public.publishing_news_org_taxonomy_terms USING btree (parent_id);


--
-- Name: idx_news_org_vm_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_org_vm_filter ON public.publishing_news_org_version_multiple_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_news_org_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_org_vm_term ON public.publishing_news_org_version_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_news_org_vm_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_org_vm_voc ON public.publishing_news_org_version_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_news_org_vs_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_org_vs_filter ON public.publishing_news_org_version_single_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_news_org_vs_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_org_vs_term ON public.publishing_news_org_version_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_news_org_vs_voc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_org_vs_voc ON public.publishing_news_org_version_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_on_entry_revision_id_0e042ce215; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_revision_id_0e042ce215 ON public.publishing_info_org_revision_media_usages USING btree (entry_revision_id);


--
-- Name: idx_on_entry_revision_id_335482b5b7; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_revision_id_335482b5b7 ON public.publishing_docs_com_revision_media_usages USING btree (entry_revision_id);


--
-- Name: idx_on_entry_revision_id_89d55e3ea8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_revision_id_89d55e3ea8 ON public.publishing_info_app_revision_media_usages USING btree (entry_revision_id);


--
-- Name: idx_on_entry_revision_id_936880ceca; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_revision_id_936880ceca ON public.publishing_news_com_revision_media_usages USING btree (entry_revision_id);


--
-- Name: idx_on_entry_revision_id_943136696e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_revision_id_943136696e ON public.publishing_news_app_revision_media_usages USING btree (entry_revision_id);


--
-- Name: idx_on_entry_revision_id_ae3645a48c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_revision_id_ae3645a48c ON public.publishing_docs_app_revision_media_usages USING btree (entry_revision_id);


--
-- Name: idx_on_entry_revision_id_af519933a0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_revision_id_af519933a0 ON public.publishing_news_org_revision_media_usages USING btree (entry_revision_id);


--
-- Name: idx_on_entry_revision_id_c4b49013a6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_revision_id_c4b49013a6 ON public.publishing_help_org_revision_media_usages USING btree (entry_revision_id);


--
-- Name: idx_on_entry_revision_id_dadda0980d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_revision_id_dadda0980d ON public.publishing_info_com_revision_media_usages USING btree (entry_revision_id);


--
-- Name: idx_on_entry_revision_id_e430280ab1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_revision_id_e430280ab1 ON public.publishing_help_com_revision_media_usages USING btree (entry_revision_id);


--
-- Name: idx_on_entry_revision_id_f220c8f97e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_revision_id_f220c8f97e ON public.publishing_docs_org_revision_media_usages USING btree (entry_revision_id);


--
-- Name: idx_on_entry_revision_id_f987c52794; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_revision_id_f987c52794 ON public.publishing_help_app_revision_media_usages USING btree (entry_revision_id);


--
-- Name: idx_on_entry_version_id_0ee210b2b5; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_version_id_0ee210b2b5 ON public.publishing_help_app_version_media_usages USING btree (entry_version_id);


--
-- Name: idx_on_entry_version_id_2a922bfe07; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_version_id_2a922bfe07 ON public.publishing_info_com_version_media_usages USING btree (entry_version_id);


--
-- Name: idx_on_entry_version_id_2cc4568c50; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_version_id_2cc4568c50 ON public.publishing_news_com_version_media_usages USING btree (entry_version_id);


--
-- Name: idx_on_entry_version_id_45404796f4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_version_id_45404796f4 ON public.publishing_news_app_version_media_usages USING btree (entry_version_id);


--
-- Name: idx_on_entry_version_id_4cd943f55f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_version_id_4cd943f55f ON public.publishing_docs_org_version_media_usages USING btree (entry_version_id);


--
-- Name: idx_on_entry_version_id_5047b8eaae; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_version_id_5047b8eaae ON public.publishing_help_org_version_media_usages USING btree (entry_version_id);


--
-- Name: idx_on_entry_version_id_85c8b1949a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_version_id_85c8b1949a ON public.publishing_news_org_version_media_usages USING btree (entry_version_id);


--
-- Name: idx_on_entry_version_id_c7a3fd4207; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_version_id_c7a3fd4207 ON public.publishing_docs_app_version_media_usages USING btree (entry_version_id);


--
-- Name: idx_on_entry_version_id_d118d04df1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_version_id_d118d04df1 ON public.publishing_info_app_version_media_usages USING btree (entry_version_id);


--
-- Name: idx_on_entry_version_id_d451e876f4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_version_id_d451e876f4 ON public.publishing_docs_com_version_media_usages USING btree (entry_version_id);


--
-- Name: idx_on_entry_version_id_d7a15f73b8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_version_id_d7a15f73b8 ON public.publishing_info_org_version_media_usages USING btree (entry_version_id);


--
-- Name: idx_on_entry_version_id_de9d71656a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entry_version_id_de9d71656a ON public.publishing_help_com_version_media_usages USING btree (entry_version_id);


--
-- Name: idx_on_media_file_id_01928b5218; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_01928b5218 ON public.publishing_info_com_revision_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_01d87ca3ba; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_01d87ca3ba ON public.publishing_docs_com_revision_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_0832f321e9; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_0832f321e9 ON public.publishing_help_app_revision_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_1be8f36109; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_1be8f36109 ON public.publishing_news_org_version_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_2417f056cc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_2417f056cc ON public.publishing_docs_app_version_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_25b8f24fd1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_25b8f24fd1 ON public.publishing_docs_org_version_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_28b4d7396b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_28b4d7396b ON public.publishing_docs_org_revision_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_28de61afca; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_28de61afca ON public.publishing_news_com_revision_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_2ec310eb66; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_2ec310eb66 ON public.publishing_info_com_version_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_4e1c13b84e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_4e1c13b84e ON public.publishing_info_org_version_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_557e733a56; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_557e733a56 ON public.publishing_help_com_version_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_56ba5e678a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_56ba5e678a ON public.publishing_help_org_version_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_76a3d97a5c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_76a3d97a5c ON public.publishing_help_app_version_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_7cedbc0fd8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_7cedbc0fd8 ON public.publishing_docs_app_revision_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_8fc5672828; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_8fc5672828 ON public.publishing_help_com_revision_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_9617fb5e42; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_9617fb5e42 ON public.publishing_news_org_revision_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_9fe91f0a31; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_9fe91f0a31 ON public.publishing_news_com_version_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_a0eeed670b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_a0eeed670b ON public.publishing_info_org_revision_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_af4be1042c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_af4be1042c ON public.publishing_docs_com_version_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_bae5ca5838; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_bae5ca5838 ON public.publishing_news_app_version_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_bd680caa1d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_bd680caa1d ON public.publishing_info_app_version_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_c4ecba3db0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_c4ecba3db0 ON public.publishing_news_app_revision_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_e859d797b1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_e859d797b1 ON public.publishing_info_app_revision_media_usages USING btree (media_file_id);


--
-- Name: idx_on_media_file_id_f4df55bb06; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_media_file_id_f4df55bb06 ON public.publishing_help_org_revision_media_usages USING btree (media_file_id);


--
-- Name: index_publishing_docs_app_entries_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_app_entries_on_public_id ON public.publishing_docs_app_entries USING btree (public_id);


--
-- Name: index_publishing_docs_app_entry_revisions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_docs_app_entry_revisions_on_entry_id ON public.publishing_docs_app_entry_revisions USING btree (entry_id);


--
-- Name: index_publishing_docs_app_entry_revisions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_app_entry_revisions_on_public_id ON public.publishing_docs_app_entry_revisions USING btree (public_id);


--
-- Name: index_publishing_docs_app_entry_slugs_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_docs_app_entry_slugs_on_entry_id ON public.publishing_docs_app_entry_slugs USING btree (entry_id);


--
-- Name: index_publishing_docs_app_entry_slugs_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_app_entry_slugs_on_public_id ON public.publishing_docs_app_entry_slugs USING btree (public_id);


--
-- Name: index_publishing_docs_app_entry_versions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_docs_app_entry_versions_on_entry_id ON public.publishing_docs_app_entry_versions USING btree (entry_id);


--
-- Name: index_publishing_docs_app_entry_versions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_app_entry_versions_on_public_id ON public.publishing_docs_app_entry_versions USING btree (public_id);


--
-- Name: index_publishing_docs_app_publications_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_docs_app_publications_on_entry_id ON public.publishing_docs_app_publications USING btree (entry_id);


--
-- Name: index_publishing_docs_app_publications_on_entry_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_docs_app_publications_on_entry_version_id ON public.publishing_docs_app_publications USING btree (entry_version_id);


--
-- Name: index_publishing_docs_app_publications_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_app_publications_on_public_id ON public.publishing_docs_app_publications USING btree (public_id);


--
-- Name: index_publishing_docs_app_revision_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_app_revision_media_usages_on_public_id ON public.publishing_docs_app_revision_media_usages USING btree (public_id);


--
-- Name: index_publishing_docs_app_taxonomy_terms_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_app_taxonomy_terms_on_public_id ON public.publishing_docs_app_taxonomy_terms USING btree (public_id);


--
-- Name: index_publishing_docs_app_taxonomy_terms_on_vocabulary_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_docs_app_taxonomy_terms_on_vocabulary_id ON public.publishing_docs_app_taxonomy_terms USING btree (vocabulary_id);


--
-- Name: index_publishing_docs_app_version_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_app_version_media_usages_on_public_id ON public.publishing_docs_app_version_media_usages USING btree (public_id);


--
-- Name: index_publishing_docs_app_vocabularies_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_app_vocabularies_on_public_id ON public.publishing_docs_app_vocabularies USING btree (public_id);


--
-- Name: index_publishing_docs_com_entries_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_com_entries_on_public_id ON public.publishing_docs_com_entries USING btree (public_id);


--
-- Name: index_publishing_docs_com_entry_revisions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_docs_com_entry_revisions_on_entry_id ON public.publishing_docs_com_entry_revisions USING btree (entry_id);


--
-- Name: index_publishing_docs_com_entry_revisions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_com_entry_revisions_on_public_id ON public.publishing_docs_com_entry_revisions USING btree (public_id);


--
-- Name: index_publishing_docs_com_entry_slugs_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_docs_com_entry_slugs_on_entry_id ON public.publishing_docs_com_entry_slugs USING btree (entry_id);


--
-- Name: index_publishing_docs_com_entry_slugs_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_com_entry_slugs_on_public_id ON public.publishing_docs_com_entry_slugs USING btree (public_id);


--
-- Name: index_publishing_docs_com_entry_versions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_docs_com_entry_versions_on_entry_id ON public.publishing_docs_com_entry_versions USING btree (entry_id);


--
-- Name: index_publishing_docs_com_entry_versions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_com_entry_versions_on_public_id ON public.publishing_docs_com_entry_versions USING btree (public_id);


--
-- Name: index_publishing_docs_com_publications_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_docs_com_publications_on_entry_id ON public.publishing_docs_com_publications USING btree (entry_id);


--
-- Name: index_publishing_docs_com_publications_on_entry_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_docs_com_publications_on_entry_version_id ON public.publishing_docs_com_publications USING btree (entry_version_id);


--
-- Name: index_publishing_docs_com_publications_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_com_publications_on_public_id ON public.publishing_docs_com_publications USING btree (public_id);


--
-- Name: index_publishing_docs_com_revision_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_com_revision_media_usages_on_public_id ON public.publishing_docs_com_revision_media_usages USING btree (public_id);


--
-- Name: index_publishing_docs_com_taxonomy_terms_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_com_taxonomy_terms_on_public_id ON public.publishing_docs_com_taxonomy_terms USING btree (public_id);


--
-- Name: index_publishing_docs_com_taxonomy_terms_on_vocabulary_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_docs_com_taxonomy_terms_on_vocabulary_id ON public.publishing_docs_com_taxonomy_terms USING btree (vocabulary_id);


--
-- Name: index_publishing_docs_com_version_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_com_version_media_usages_on_public_id ON public.publishing_docs_com_version_media_usages USING btree (public_id);


--
-- Name: index_publishing_docs_com_vocabularies_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_com_vocabularies_on_public_id ON public.publishing_docs_com_vocabularies USING btree (public_id);


--
-- Name: index_publishing_docs_org_entries_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_org_entries_on_public_id ON public.publishing_docs_org_entries USING btree (public_id);


--
-- Name: index_publishing_docs_org_entry_revisions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_docs_org_entry_revisions_on_entry_id ON public.publishing_docs_org_entry_revisions USING btree (entry_id);


--
-- Name: index_publishing_docs_org_entry_revisions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_org_entry_revisions_on_public_id ON public.publishing_docs_org_entry_revisions USING btree (public_id);


--
-- Name: index_publishing_docs_org_entry_slugs_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_docs_org_entry_slugs_on_entry_id ON public.publishing_docs_org_entry_slugs USING btree (entry_id);


--
-- Name: index_publishing_docs_org_entry_slugs_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_org_entry_slugs_on_public_id ON public.publishing_docs_org_entry_slugs USING btree (public_id);


--
-- Name: index_publishing_docs_org_entry_versions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_docs_org_entry_versions_on_entry_id ON public.publishing_docs_org_entry_versions USING btree (entry_id);


--
-- Name: index_publishing_docs_org_entry_versions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_org_entry_versions_on_public_id ON public.publishing_docs_org_entry_versions USING btree (public_id);


--
-- Name: index_publishing_docs_org_publications_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_docs_org_publications_on_entry_id ON public.publishing_docs_org_publications USING btree (entry_id);


--
-- Name: index_publishing_docs_org_publications_on_entry_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_docs_org_publications_on_entry_version_id ON public.publishing_docs_org_publications USING btree (entry_version_id);


--
-- Name: index_publishing_docs_org_publications_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_org_publications_on_public_id ON public.publishing_docs_org_publications USING btree (public_id);


--
-- Name: index_publishing_docs_org_revision_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_org_revision_media_usages_on_public_id ON public.publishing_docs_org_revision_media_usages USING btree (public_id);


--
-- Name: index_publishing_docs_org_taxonomy_terms_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_org_taxonomy_terms_on_public_id ON public.publishing_docs_org_taxonomy_terms USING btree (public_id);


--
-- Name: index_publishing_docs_org_taxonomy_terms_on_vocabulary_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_docs_org_taxonomy_terms_on_vocabulary_id ON public.publishing_docs_org_taxonomy_terms USING btree (vocabulary_id);


--
-- Name: index_publishing_docs_org_version_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_org_version_media_usages_on_public_id ON public.publishing_docs_org_version_media_usages USING btree (public_id);


--
-- Name: index_publishing_docs_org_vocabularies_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_docs_org_vocabularies_on_public_id ON public.publishing_docs_org_vocabularies USING btree (public_id);


--
-- Name: index_publishing_help_app_entries_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_app_entries_on_public_id ON public.publishing_help_app_entries USING btree (public_id);


--
-- Name: index_publishing_help_app_entry_revisions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_help_app_entry_revisions_on_entry_id ON public.publishing_help_app_entry_revisions USING btree (entry_id);


--
-- Name: index_publishing_help_app_entry_revisions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_app_entry_revisions_on_public_id ON public.publishing_help_app_entry_revisions USING btree (public_id);


--
-- Name: index_publishing_help_app_entry_slugs_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_help_app_entry_slugs_on_entry_id ON public.publishing_help_app_entry_slugs USING btree (entry_id);


--
-- Name: index_publishing_help_app_entry_slugs_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_app_entry_slugs_on_public_id ON public.publishing_help_app_entry_slugs USING btree (public_id);


--
-- Name: index_publishing_help_app_entry_versions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_help_app_entry_versions_on_entry_id ON public.publishing_help_app_entry_versions USING btree (entry_id);


--
-- Name: index_publishing_help_app_entry_versions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_app_entry_versions_on_public_id ON public.publishing_help_app_entry_versions USING btree (public_id);


--
-- Name: index_publishing_help_app_publications_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_help_app_publications_on_entry_id ON public.publishing_help_app_publications USING btree (entry_id);


--
-- Name: index_publishing_help_app_publications_on_entry_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_help_app_publications_on_entry_version_id ON public.publishing_help_app_publications USING btree (entry_version_id);


--
-- Name: index_publishing_help_app_publications_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_app_publications_on_public_id ON public.publishing_help_app_publications USING btree (public_id);


--
-- Name: index_publishing_help_app_revision_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_app_revision_media_usages_on_public_id ON public.publishing_help_app_revision_media_usages USING btree (public_id);


--
-- Name: index_publishing_help_app_taxonomy_terms_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_app_taxonomy_terms_on_public_id ON public.publishing_help_app_taxonomy_terms USING btree (public_id);


--
-- Name: index_publishing_help_app_taxonomy_terms_on_vocabulary_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_help_app_taxonomy_terms_on_vocabulary_id ON public.publishing_help_app_taxonomy_terms USING btree (vocabulary_id);


--
-- Name: index_publishing_help_app_version_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_app_version_media_usages_on_public_id ON public.publishing_help_app_version_media_usages USING btree (public_id);


--
-- Name: index_publishing_help_app_vocabularies_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_app_vocabularies_on_public_id ON public.publishing_help_app_vocabularies USING btree (public_id);


--
-- Name: index_publishing_help_com_entries_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_com_entries_on_public_id ON public.publishing_help_com_entries USING btree (public_id);


--
-- Name: index_publishing_help_com_entry_revisions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_help_com_entry_revisions_on_entry_id ON public.publishing_help_com_entry_revisions USING btree (entry_id);


--
-- Name: index_publishing_help_com_entry_revisions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_com_entry_revisions_on_public_id ON public.publishing_help_com_entry_revisions USING btree (public_id);


--
-- Name: index_publishing_help_com_entry_slugs_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_help_com_entry_slugs_on_entry_id ON public.publishing_help_com_entry_slugs USING btree (entry_id);


--
-- Name: index_publishing_help_com_entry_slugs_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_com_entry_slugs_on_public_id ON public.publishing_help_com_entry_slugs USING btree (public_id);


--
-- Name: index_publishing_help_com_entry_versions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_help_com_entry_versions_on_entry_id ON public.publishing_help_com_entry_versions USING btree (entry_id);


--
-- Name: index_publishing_help_com_entry_versions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_com_entry_versions_on_public_id ON public.publishing_help_com_entry_versions USING btree (public_id);


--
-- Name: index_publishing_help_com_publications_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_help_com_publications_on_entry_id ON public.publishing_help_com_publications USING btree (entry_id);


--
-- Name: index_publishing_help_com_publications_on_entry_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_help_com_publications_on_entry_version_id ON public.publishing_help_com_publications USING btree (entry_version_id);


--
-- Name: index_publishing_help_com_publications_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_com_publications_on_public_id ON public.publishing_help_com_publications USING btree (public_id);


--
-- Name: index_publishing_help_com_revision_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_com_revision_media_usages_on_public_id ON public.publishing_help_com_revision_media_usages USING btree (public_id);


--
-- Name: index_publishing_help_com_taxonomy_terms_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_com_taxonomy_terms_on_public_id ON public.publishing_help_com_taxonomy_terms USING btree (public_id);


--
-- Name: index_publishing_help_com_taxonomy_terms_on_vocabulary_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_help_com_taxonomy_terms_on_vocabulary_id ON public.publishing_help_com_taxonomy_terms USING btree (vocabulary_id);


--
-- Name: index_publishing_help_com_version_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_com_version_media_usages_on_public_id ON public.publishing_help_com_version_media_usages USING btree (public_id);


--
-- Name: index_publishing_help_com_vocabularies_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_com_vocabularies_on_public_id ON public.publishing_help_com_vocabularies USING btree (public_id);


--
-- Name: index_publishing_help_org_entries_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_org_entries_on_public_id ON public.publishing_help_org_entries USING btree (public_id);


--
-- Name: index_publishing_help_org_entry_revisions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_help_org_entry_revisions_on_entry_id ON public.publishing_help_org_entry_revisions USING btree (entry_id);


--
-- Name: index_publishing_help_org_entry_revisions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_org_entry_revisions_on_public_id ON public.publishing_help_org_entry_revisions USING btree (public_id);


--
-- Name: index_publishing_help_org_entry_slugs_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_help_org_entry_slugs_on_entry_id ON public.publishing_help_org_entry_slugs USING btree (entry_id);


--
-- Name: index_publishing_help_org_entry_slugs_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_org_entry_slugs_on_public_id ON public.publishing_help_org_entry_slugs USING btree (public_id);


--
-- Name: index_publishing_help_org_entry_versions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_help_org_entry_versions_on_entry_id ON public.publishing_help_org_entry_versions USING btree (entry_id);


--
-- Name: index_publishing_help_org_entry_versions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_org_entry_versions_on_public_id ON public.publishing_help_org_entry_versions USING btree (public_id);


--
-- Name: index_publishing_help_org_publications_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_help_org_publications_on_entry_id ON public.publishing_help_org_publications USING btree (entry_id);


--
-- Name: index_publishing_help_org_publications_on_entry_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_help_org_publications_on_entry_version_id ON public.publishing_help_org_publications USING btree (entry_version_id);


--
-- Name: index_publishing_help_org_publications_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_org_publications_on_public_id ON public.publishing_help_org_publications USING btree (public_id);


--
-- Name: index_publishing_help_org_revision_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_org_revision_media_usages_on_public_id ON public.publishing_help_org_revision_media_usages USING btree (public_id);


--
-- Name: index_publishing_help_org_taxonomy_terms_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_org_taxonomy_terms_on_public_id ON public.publishing_help_org_taxonomy_terms USING btree (public_id);


--
-- Name: index_publishing_help_org_taxonomy_terms_on_vocabulary_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_help_org_taxonomy_terms_on_vocabulary_id ON public.publishing_help_org_taxonomy_terms USING btree (vocabulary_id);


--
-- Name: index_publishing_help_org_version_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_org_version_media_usages_on_public_id ON public.publishing_help_org_version_media_usages USING btree (public_id);


--
-- Name: index_publishing_help_org_vocabularies_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_help_org_vocabularies_on_public_id ON public.publishing_help_org_vocabularies USING btree (public_id);


--
-- Name: index_publishing_info_app_entries_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_app_entries_on_public_id ON public.publishing_info_app_entries USING btree (public_id);


--
-- Name: index_publishing_info_app_entry_revisions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_info_app_entry_revisions_on_entry_id ON public.publishing_info_app_entry_revisions USING btree (entry_id);


--
-- Name: index_publishing_info_app_entry_revisions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_app_entry_revisions_on_public_id ON public.publishing_info_app_entry_revisions USING btree (public_id);


--
-- Name: index_publishing_info_app_entry_slugs_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_info_app_entry_slugs_on_entry_id ON public.publishing_info_app_entry_slugs USING btree (entry_id);


--
-- Name: index_publishing_info_app_entry_slugs_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_app_entry_slugs_on_public_id ON public.publishing_info_app_entry_slugs USING btree (public_id);


--
-- Name: index_publishing_info_app_entry_versions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_info_app_entry_versions_on_entry_id ON public.publishing_info_app_entry_versions USING btree (entry_id);


--
-- Name: index_publishing_info_app_entry_versions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_app_entry_versions_on_public_id ON public.publishing_info_app_entry_versions USING btree (public_id);


--
-- Name: index_publishing_info_app_publications_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_info_app_publications_on_entry_id ON public.publishing_info_app_publications USING btree (entry_id);


--
-- Name: index_publishing_info_app_publications_on_entry_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_info_app_publications_on_entry_version_id ON public.publishing_info_app_publications USING btree (entry_version_id);


--
-- Name: index_publishing_info_app_publications_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_app_publications_on_public_id ON public.publishing_info_app_publications USING btree (public_id);


--
-- Name: index_publishing_info_app_revision_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_app_revision_media_usages_on_public_id ON public.publishing_info_app_revision_media_usages USING btree (public_id);


--
-- Name: index_publishing_info_app_taxonomy_terms_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_app_taxonomy_terms_on_public_id ON public.publishing_info_app_taxonomy_terms USING btree (public_id);


--
-- Name: index_publishing_info_app_taxonomy_terms_on_vocabulary_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_info_app_taxonomy_terms_on_vocabulary_id ON public.publishing_info_app_taxonomy_terms USING btree (vocabulary_id);


--
-- Name: index_publishing_info_app_version_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_app_version_media_usages_on_public_id ON public.publishing_info_app_version_media_usages USING btree (public_id);


--
-- Name: index_publishing_info_app_vocabularies_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_app_vocabularies_on_public_id ON public.publishing_info_app_vocabularies USING btree (public_id);


--
-- Name: index_publishing_info_com_entries_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_com_entries_on_public_id ON public.publishing_info_com_entries USING btree (public_id);


--
-- Name: index_publishing_info_com_entry_revisions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_info_com_entry_revisions_on_entry_id ON public.publishing_info_com_entry_revisions USING btree (entry_id);


--
-- Name: index_publishing_info_com_entry_revisions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_com_entry_revisions_on_public_id ON public.publishing_info_com_entry_revisions USING btree (public_id);


--
-- Name: index_publishing_info_com_entry_slugs_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_info_com_entry_slugs_on_entry_id ON public.publishing_info_com_entry_slugs USING btree (entry_id);


--
-- Name: index_publishing_info_com_entry_slugs_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_com_entry_slugs_on_public_id ON public.publishing_info_com_entry_slugs USING btree (public_id);


--
-- Name: index_publishing_info_com_entry_versions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_info_com_entry_versions_on_entry_id ON public.publishing_info_com_entry_versions USING btree (entry_id);


--
-- Name: index_publishing_info_com_entry_versions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_com_entry_versions_on_public_id ON public.publishing_info_com_entry_versions USING btree (public_id);


--
-- Name: index_publishing_info_com_publications_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_info_com_publications_on_entry_id ON public.publishing_info_com_publications USING btree (entry_id);


--
-- Name: index_publishing_info_com_publications_on_entry_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_info_com_publications_on_entry_version_id ON public.publishing_info_com_publications USING btree (entry_version_id);


--
-- Name: index_publishing_info_com_publications_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_com_publications_on_public_id ON public.publishing_info_com_publications USING btree (public_id);


--
-- Name: index_publishing_info_com_revision_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_com_revision_media_usages_on_public_id ON public.publishing_info_com_revision_media_usages USING btree (public_id);


--
-- Name: index_publishing_info_com_taxonomy_terms_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_com_taxonomy_terms_on_public_id ON public.publishing_info_com_taxonomy_terms USING btree (public_id);


--
-- Name: index_publishing_info_com_taxonomy_terms_on_vocabulary_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_info_com_taxonomy_terms_on_vocabulary_id ON public.publishing_info_com_taxonomy_terms USING btree (vocabulary_id);


--
-- Name: index_publishing_info_com_version_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_com_version_media_usages_on_public_id ON public.publishing_info_com_version_media_usages USING btree (public_id);


--
-- Name: index_publishing_info_com_vocabularies_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_com_vocabularies_on_public_id ON public.publishing_info_com_vocabularies USING btree (public_id);


--
-- Name: index_publishing_info_org_entries_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_org_entries_on_public_id ON public.publishing_info_org_entries USING btree (public_id);


--
-- Name: index_publishing_info_org_entry_revisions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_info_org_entry_revisions_on_entry_id ON public.publishing_info_org_entry_revisions USING btree (entry_id);


--
-- Name: index_publishing_info_org_entry_revisions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_org_entry_revisions_on_public_id ON public.publishing_info_org_entry_revisions USING btree (public_id);


--
-- Name: index_publishing_info_org_entry_slugs_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_info_org_entry_slugs_on_entry_id ON public.publishing_info_org_entry_slugs USING btree (entry_id);


--
-- Name: index_publishing_info_org_entry_slugs_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_org_entry_slugs_on_public_id ON public.publishing_info_org_entry_slugs USING btree (public_id);


--
-- Name: index_publishing_info_org_entry_versions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_info_org_entry_versions_on_entry_id ON public.publishing_info_org_entry_versions USING btree (entry_id);


--
-- Name: index_publishing_info_org_entry_versions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_org_entry_versions_on_public_id ON public.publishing_info_org_entry_versions USING btree (public_id);


--
-- Name: index_publishing_info_org_publications_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_info_org_publications_on_entry_id ON public.publishing_info_org_publications USING btree (entry_id);


--
-- Name: index_publishing_info_org_publications_on_entry_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_info_org_publications_on_entry_version_id ON public.publishing_info_org_publications USING btree (entry_version_id);


--
-- Name: index_publishing_info_org_publications_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_org_publications_on_public_id ON public.publishing_info_org_publications USING btree (public_id);


--
-- Name: index_publishing_info_org_revision_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_org_revision_media_usages_on_public_id ON public.publishing_info_org_revision_media_usages USING btree (public_id);


--
-- Name: index_publishing_info_org_taxonomy_terms_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_org_taxonomy_terms_on_public_id ON public.publishing_info_org_taxonomy_terms USING btree (public_id);


--
-- Name: index_publishing_info_org_taxonomy_terms_on_vocabulary_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_info_org_taxonomy_terms_on_vocabulary_id ON public.publishing_info_org_taxonomy_terms USING btree (vocabulary_id);


--
-- Name: index_publishing_info_org_version_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_org_version_media_usages_on_public_id ON public.publishing_info_org_version_media_usages USING btree (public_id);


--
-- Name: index_publishing_info_org_vocabularies_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_info_org_vocabularies_on_public_id ON public.publishing_info_org_vocabularies USING btree (public_id);


--
-- Name: index_publishing_media_files_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_media_files_on_public_id ON public.publishing_media_files USING btree (public_id);


--
-- Name: index_publishing_media_files_on_storage_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_media_files_on_storage_key ON public.publishing_media_files USING btree (storage_key);


--
-- Name: index_publishing_news_app_entries_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_app_entries_on_public_id ON public.publishing_news_app_entries USING btree (public_id);


--
-- Name: index_publishing_news_app_entry_revisions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_news_app_entry_revisions_on_entry_id ON public.publishing_news_app_entry_revisions USING btree (entry_id);


--
-- Name: index_publishing_news_app_entry_revisions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_app_entry_revisions_on_public_id ON public.publishing_news_app_entry_revisions USING btree (public_id);


--
-- Name: index_publishing_news_app_entry_slugs_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_news_app_entry_slugs_on_entry_id ON public.publishing_news_app_entry_slugs USING btree (entry_id);


--
-- Name: index_publishing_news_app_entry_slugs_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_app_entry_slugs_on_public_id ON public.publishing_news_app_entry_slugs USING btree (public_id);


--
-- Name: index_publishing_news_app_entry_versions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_news_app_entry_versions_on_entry_id ON public.publishing_news_app_entry_versions USING btree (entry_id);


--
-- Name: index_publishing_news_app_entry_versions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_app_entry_versions_on_public_id ON public.publishing_news_app_entry_versions USING btree (public_id);


--
-- Name: index_publishing_news_app_publications_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_news_app_publications_on_entry_id ON public.publishing_news_app_publications USING btree (entry_id);


--
-- Name: index_publishing_news_app_publications_on_entry_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_news_app_publications_on_entry_version_id ON public.publishing_news_app_publications USING btree (entry_version_id);


--
-- Name: index_publishing_news_app_publications_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_app_publications_on_public_id ON public.publishing_news_app_publications USING btree (public_id);


--
-- Name: index_publishing_news_app_revision_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_app_revision_media_usages_on_public_id ON public.publishing_news_app_revision_media_usages USING btree (public_id);


--
-- Name: index_publishing_news_app_taxonomy_terms_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_app_taxonomy_terms_on_public_id ON public.publishing_news_app_taxonomy_terms USING btree (public_id);


--
-- Name: index_publishing_news_app_taxonomy_terms_on_vocabulary_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_news_app_taxonomy_terms_on_vocabulary_id ON public.publishing_news_app_taxonomy_terms USING btree (vocabulary_id);


--
-- Name: index_publishing_news_app_version_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_app_version_media_usages_on_public_id ON public.publishing_news_app_version_media_usages USING btree (public_id);


--
-- Name: index_publishing_news_app_vocabularies_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_app_vocabularies_on_public_id ON public.publishing_news_app_vocabularies USING btree (public_id);


--
-- Name: index_publishing_news_com_entries_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_com_entries_on_public_id ON public.publishing_news_com_entries USING btree (public_id);


--
-- Name: index_publishing_news_com_entry_revisions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_news_com_entry_revisions_on_entry_id ON public.publishing_news_com_entry_revisions USING btree (entry_id);


--
-- Name: index_publishing_news_com_entry_revisions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_com_entry_revisions_on_public_id ON public.publishing_news_com_entry_revisions USING btree (public_id);


--
-- Name: index_publishing_news_com_entry_slugs_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_news_com_entry_slugs_on_entry_id ON public.publishing_news_com_entry_slugs USING btree (entry_id);


--
-- Name: index_publishing_news_com_entry_slugs_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_com_entry_slugs_on_public_id ON public.publishing_news_com_entry_slugs USING btree (public_id);


--
-- Name: index_publishing_news_com_entry_versions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_news_com_entry_versions_on_entry_id ON public.publishing_news_com_entry_versions USING btree (entry_id);


--
-- Name: index_publishing_news_com_entry_versions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_com_entry_versions_on_public_id ON public.publishing_news_com_entry_versions USING btree (public_id);


--
-- Name: index_publishing_news_com_publications_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_news_com_publications_on_entry_id ON public.publishing_news_com_publications USING btree (entry_id);


--
-- Name: index_publishing_news_com_publications_on_entry_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_news_com_publications_on_entry_version_id ON public.publishing_news_com_publications USING btree (entry_version_id);


--
-- Name: index_publishing_news_com_publications_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_com_publications_on_public_id ON public.publishing_news_com_publications USING btree (public_id);


--
-- Name: index_publishing_news_com_revision_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_com_revision_media_usages_on_public_id ON public.publishing_news_com_revision_media_usages USING btree (public_id);


--
-- Name: index_publishing_news_com_taxonomy_terms_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_com_taxonomy_terms_on_public_id ON public.publishing_news_com_taxonomy_terms USING btree (public_id);


--
-- Name: index_publishing_news_com_taxonomy_terms_on_vocabulary_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_news_com_taxonomy_terms_on_vocabulary_id ON public.publishing_news_com_taxonomy_terms USING btree (vocabulary_id);


--
-- Name: index_publishing_news_com_version_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_com_version_media_usages_on_public_id ON public.publishing_news_com_version_media_usages USING btree (public_id);


--
-- Name: index_publishing_news_com_vocabularies_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_com_vocabularies_on_public_id ON public.publishing_news_com_vocabularies USING btree (public_id);


--
-- Name: index_publishing_news_org_entries_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_org_entries_on_public_id ON public.publishing_news_org_entries USING btree (public_id);


--
-- Name: index_publishing_news_org_entry_revisions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_news_org_entry_revisions_on_entry_id ON public.publishing_news_org_entry_revisions USING btree (entry_id);


--
-- Name: index_publishing_news_org_entry_revisions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_org_entry_revisions_on_public_id ON public.publishing_news_org_entry_revisions USING btree (public_id);


--
-- Name: index_publishing_news_org_entry_slugs_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_news_org_entry_slugs_on_entry_id ON public.publishing_news_org_entry_slugs USING btree (entry_id);


--
-- Name: index_publishing_news_org_entry_slugs_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_org_entry_slugs_on_public_id ON public.publishing_news_org_entry_slugs USING btree (public_id);


--
-- Name: index_publishing_news_org_entry_versions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_news_org_entry_versions_on_entry_id ON public.publishing_news_org_entry_versions USING btree (entry_id);


--
-- Name: index_publishing_news_org_entry_versions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_org_entry_versions_on_public_id ON public.publishing_news_org_entry_versions USING btree (public_id);


--
-- Name: index_publishing_news_org_publications_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_news_org_publications_on_entry_id ON public.publishing_news_org_publications USING btree (entry_id);


--
-- Name: index_publishing_news_org_publications_on_entry_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_news_org_publications_on_entry_version_id ON public.publishing_news_org_publications USING btree (entry_version_id);


--
-- Name: index_publishing_news_org_publications_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_org_publications_on_public_id ON public.publishing_news_org_publications USING btree (public_id);


--
-- Name: index_publishing_news_org_revision_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_org_revision_media_usages_on_public_id ON public.publishing_news_org_revision_media_usages USING btree (public_id);


--
-- Name: index_publishing_news_org_taxonomy_terms_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_org_taxonomy_terms_on_public_id ON public.publishing_news_org_taxonomy_terms USING btree (public_id);


--
-- Name: index_publishing_news_org_taxonomy_terms_on_vocabulary_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_news_org_taxonomy_terms_on_vocabulary_id ON public.publishing_news_org_taxonomy_terms USING btree (vocabulary_id);


--
-- Name: index_publishing_news_org_version_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_org_version_media_usages_on_public_id ON public.publishing_news_org_version_media_usages USING btree (public_id);


--
-- Name: index_publishing_news_org_vocabularies_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_news_org_vocabularies_on_public_id ON public.publishing_news_org_vocabularies USING btree (public_id);


--
-- Name: uidx_docs_app_ent_current_rev; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_ent_current_rev ON public.publishing_docs_app_entries USING btree (current_revision_id);


--
-- Name: uidx_docs_app_ent_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_ent_id_locale ON public.publishing_docs_app_entries USING btree (id, locale);


--
-- Name: uidx_docs_app_rev_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_rev_id_entry ON public.publishing_docs_app_entry_revisions USING btree (id, entry_id);


--
-- Name: uidx_docs_app_rev_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_rev_id_entry_locale ON public.publishing_docs_app_entry_revisions USING btree (id, entry_id, locale);


--
-- Name: uidx_docs_app_rev_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_rev_id_locale ON public.publishing_docs_app_entry_revisions USING btree (id, locale);


--
-- Name: uidx_docs_app_rev_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_rev_media_pos ON public.publishing_docs_app_revision_media_usages USING btree (entry_revision_id, role, field_path, block_path, "position");


--
-- Name: uidx_docs_app_rev_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_rev_seq ON public.publishing_docs_app_entry_revisions USING btree (entry_id, sequence);


--
-- Name: uidx_docs_app_rm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_rm_pos ON public.publishing_docs_app_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, "position");


--
-- Name: uidx_docs_app_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_rm_term ON public.publishing_docs_app_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_docs_app_rs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_rs_owner ON public.publishing_docs_app_revision_single_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id);


--
-- Name: uidx_docs_app_slug_canonical; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_slug_canonical ON public.publishing_docs_app_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'canonical'::text);


--
-- Name: uidx_docs_app_slug_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_slug_locale ON public.publishing_docs_app_entry_slugs USING btree (locale, slug);


--
-- Name: uidx_docs_app_slug_reserved; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_slug_reserved ON public.publishing_docs_app_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'reserved'::text);


--
-- Name: uidx_docs_app_term_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_term_scope ON public.publishing_docs_app_taxonomy_terms USING btree (id, vocabulary_id, locale);


--
-- Name: uidx_docs_app_term_sib_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_term_sib_pos ON public.publishing_docs_app_taxonomy_terms USING btree (vocabulary_id, locale, parent_id, "position") NULLS NOT DISTINCT;


--
-- Name: uidx_docs_app_term_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_term_slug ON public.publishing_docs_app_taxonomy_terms USING btree (vocabulary_id, locale, slug);


--
-- Name: uidx_docs_app_ver_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_ver_id_entry ON public.publishing_docs_app_entry_versions USING btree (id, entry_id);


--
-- Name: uidx_docs_app_ver_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_ver_id_entry_locale ON public.publishing_docs_app_entry_versions USING btree (id, entry_id, locale);


--
-- Name: uidx_docs_app_ver_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_ver_id_locale ON public.publishing_docs_app_entry_versions USING btree (id, locale);


--
-- Name: uidx_docs_app_ver_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_ver_media_pos ON public.publishing_docs_app_version_media_usages USING btree (entry_version_id, role, field_path, block_path, "position");


--
-- Name: uidx_docs_app_ver_on_revision; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_ver_on_revision ON public.publishing_docs_app_entry_versions USING btree (entry_revision_id);


--
-- Name: uidx_docs_app_ver_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_ver_seq ON public.publishing_docs_app_entry_versions USING btree (entry_id, sequence);


--
-- Name: uidx_docs_app_vm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_vm_pos ON public.publishing_docs_app_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, "position");


--
-- Name: uidx_docs_app_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_vm_term ON public.publishing_docs_app_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_docs_app_voc_id_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_voc_id_kind ON public.publishing_docs_app_vocabularies USING btree (id, kind);


--
-- Name: uidx_docs_app_voc_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_voc_key ON public.publishing_docs_app_vocabularies USING btree (key);


--
-- Name: uidx_docs_app_vs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_app_vs_owner ON public.publishing_docs_app_version_single_taxonomy_assignments USING btree (entry_version_id, vocabulary_id);


--
-- Name: uidx_docs_com_ent_current_rev; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_ent_current_rev ON public.publishing_docs_com_entries USING btree (current_revision_id);


--
-- Name: uidx_docs_com_ent_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_ent_id_locale ON public.publishing_docs_com_entries USING btree (id, locale);


--
-- Name: uidx_docs_com_rev_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_rev_id_entry ON public.publishing_docs_com_entry_revisions USING btree (id, entry_id);


--
-- Name: uidx_docs_com_rev_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_rev_id_entry_locale ON public.publishing_docs_com_entry_revisions USING btree (id, entry_id, locale);


--
-- Name: uidx_docs_com_rev_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_rev_id_locale ON public.publishing_docs_com_entry_revisions USING btree (id, locale);


--
-- Name: uidx_docs_com_rev_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_rev_media_pos ON public.publishing_docs_com_revision_media_usages USING btree (entry_revision_id, role, field_path, block_path, "position");


--
-- Name: uidx_docs_com_rev_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_rev_seq ON public.publishing_docs_com_entry_revisions USING btree (entry_id, sequence);


--
-- Name: uidx_docs_com_rm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_rm_pos ON public.publishing_docs_com_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, "position");


--
-- Name: uidx_docs_com_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_rm_term ON public.publishing_docs_com_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_docs_com_rs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_rs_owner ON public.publishing_docs_com_revision_single_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id);


--
-- Name: uidx_docs_com_slug_canonical; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_slug_canonical ON public.publishing_docs_com_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'canonical'::text);


--
-- Name: uidx_docs_com_slug_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_slug_locale ON public.publishing_docs_com_entry_slugs USING btree (locale, slug);


--
-- Name: uidx_docs_com_slug_reserved; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_slug_reserved ON public.publishing_docs_com_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'reserved'::text);


--
-- Name: uidx_docs_com_term_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_term_scope ON public.publishing_docs_com_taxonomy_terms USING btree (id, vocabulary_id, locale);


--
-- Name: uidx_docs_com_term_sib_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_term_sib_pos ON public.publishing_docs_com_taxonomy_terms USING btree (vocabulary_id, locale, parent_id, "position") NULLS NOT DISTINCT;


--
-- Name: uidx_docs_com_term_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_term_slug ON public.publishing_docs_com_taxonomy_terms USING btree (vocabulary_id, locale, slug);


--
-- Name: uidx_docs_com_ver_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_ver_id_entry ON public.publishing_docs_com_entry_versions USING btree (id, entry_id);


--
-- Name: uidx_docs_com_ver_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_ver_id_entry_locale ON public.publishing_docs_com_entry_versions USING btree (id, entry_id, locale);


--
-- Name: uidx_docs_com_ver_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_ver_id_locale ON public.publishing_docs_com_entry_versions USING btree (id, locale);


--
-- Name: uidx_docs_com_ver_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_ver_media_pos ON public.publishing_docs_com_version_media_usages USING btree (entry_version_id, role, field_path, block_path, "position");


--
-- Name: uidx_docs_com_ver_on_revision; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_ver_on_revision ON public.publishing_docs_com_entry_versions USING btree (entry_revision_id);


--
-- Name: uidx_docs_com_ver_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_ver_seq ON public.publishing_docs_com_entry_versions USING btree (entry_id, sequence);


--
-- Name: uidx_docs_com_vm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_vm_pos ON public.publishing_docs_com_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, "position");


--
-- Name: uidx_docs_com_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_vm_term ON public.publishing_docs_com_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_docs_com_voc_id_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_voc_id_kind ON public.publishing_docs_com_vocabularies USING btree (id, kind);


--
-- Name: uidx_docs_com_voc_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_voc_key ON public.publishing_docs_com_vocabularies USING btree (key);


--
-- Name: uidx_docs_com_vs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_com_vs_owner ON public.publishing_docs_com_version_single_taxonomy_assignments USING btree (entry_version_id, vocabulary_id);


--
-- Name: uidx_docs_org_ent_current_rev; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_ent_current_rev ON public.publishing_docs_org_entries USING btree (current_revision_id);


--
-- Name: uidx_docs_org_ent_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_ent_id_locale ON public.publishing_docs_org_entries USING btree (id, locale);


--
-- Name: uidx_docs_org_rev_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_rev_id_entry ON public.publishing_docs_org_entry_revisions USING btree (id, entry_id);


--
-- Name: uidx_docs_org_rev_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_rev_id_entry_locale ON public.publishing_docs_org_entry_revisions USING btree (id, entry_id, locale);


--
-- Name: uidx_docs_org_rev_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_rev_id_locale ON public.publishing_docs_org_entry_revisions USING btree (id, locale);


--
-- Name: uidx_docs_org_rev_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_rev_media_pos ON public.publishing_docs_org_revision_media_usages USING btree (entry_revision_id, role, field_path, block_path, "position");


--
-- Name: uidx_docs_org_rev_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_rev_seq ON public.publishing_docs_org_entry_revisions USING btree (entry_id, sequence);


--
-- Name: uidx_docs_org_rm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_rm_pos ON public.publishing_docs_org_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, "position");


--
-- Name: uidx_docs_org_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_rm_term ON public.publishing_docs_org_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_docs_org_rs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_rs_owner ON public.publishing_docs_org_revision_single_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id);


--
-- Name: uidx_docs_org_slug_canonical; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_slug_canonical ON public.publishing_docs_org_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'canonical'::text);


--
-- Name: uidx_docs_org_slug_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_slug_locale ON public.publishing_docs_org_entry_slugs USING btree (locale, slug);


--
-- Name: uidx_docs_org_slug_reserved; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_slug_reserved ON public.publishing_docs_org_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'reserved'::text);


--
-- Name: uidx_docs_org_term_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_term_scope ON public.publishing_docs_org_taxonomy_terms USING btree (id, vocabulary_id, locale);


--
-- Name: uidx_docs_org_term_sib_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_term_sib_pos ON public.publishing_docs_org_taxonomy_terms USING btree (vocabulary_id, locale, parent_id, "position") NULLS NOT DISTINCT;


--
-- Name: uidx_docs_org_term_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_term_slug ON public.publishing_docs_org_taxonomy_terms USING btree (vocabulary_id, locale, slug);


--
-- Name: uidx_docs_org_ver_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_ver_id_entry ON public.publishing_docs_org_entry_versions USING btree (id, entry_id);


--
-- Name: uidx_docs_org_ver_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_ver_id_entry_locale ON public.publishing_docs_org_entry_versions USING btree (id, entry_id, locale);


--
-- Name: uidx_docs_org_ver_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_ver_id_locale ON public.publishing_docs_org_entry_versions USING btree (id, locale);


--
-- Name: uidx_docs_org_ver_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_ver_media_pos ON public.publishing_docs_org_version_media_usages USING btree (entry_version_id, role, field_path, block_path, "position");


--
-- Name: uidx_docs_org_ver_on_revision; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_ver_on_revision ON public.publishing_docs_org_entry_versions USING btree (entry_revision_id);


--
-- Name: uidx_docs_org_ver_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_ver_seq ON public.publishing_docs_org_entry_versions USING btree (entry_id, sequence);


--
-- Name: uidx_docs_org_vm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_vm_pos ON public.publishing_docs_org_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, "position");


--
-- Name: uidx_docs_org_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_vm_term ON public.publishing_docs_org_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_docs_org_voc_id_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_voc_id_kind ON public.publishing_docs_org_vocabularies USING btree (id, kind);


--
-- Name: uidx_docs_org_voc_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_voc_key ON public.publishing_docs_org_vocabularies USING btree (key);


--
-- Name: uidx_docs_org_vs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_docs_org_vs_owner ON public.publishing_docs_org_version_single_taxonomy_assignments USING btree (entry_version_id, vocabulary_id);


--
-- Name: uidx_help_app_ent_current_rev; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_ent_current_rev ON public.publishing_help_app_entries USING btree (current_revision_id);


--
-- Name: uidx_help_app_ent_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_ent_id_locale ON public.publishing_help_app_entries USING btree (id, locale);


--
-- Name: uidx_help_app_rev_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_rev_id_entry ON public.publishing_help_app_entry_revisions USING btree (id, entry_id);


--
-- Name: uidx_help_app_rev_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_rev_id_entry_locale ON public.publishing_help_app_entry_revisions USING btree (id, entry_id, locale);


--
-- Name: uidx_help_app_rev_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_rev_id_locale ON public.publishing_help_app_entry_revisions USING btree (id, locale);


--
-- Name: uidx_help_app_rev_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_rev_media_pos ON public.publishing_help_app_revision_media_usages USING btree (entry_revision_id, role, field_path, block_path, "position");


--
-- Name: uidx_help_app_rev_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_rev_seq ON public.publishing_help_app_entry_revisions USING btree (entry_id, sequence);


--
-- Name: uidx_help_app_rm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_rm_pos ON public.publishing_help_app_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, "position");


--
-- Name: uidx_help_app_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_rm_term ON public.publishing_help_app_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_help_app_rs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_rs_owner ON public.publishing_help_app_revision_single_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id);


--
-- Name: uidx_help_app_slug_canonical; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_slug_canonical ON public.publishing_help_app_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'canonical'::text);


--
-- Name: uidx_help_app_slug_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_slug_locale ON public.publishing_help_app_entry_slugs USING btree (locale, slug);


--
-- Name: uidx_help_app_slug_reserved; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_slug_reserved ON public.publishing_help_app_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'reserved'::text);


--
-- Name: uidx_help_app_term_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_term_scope ON public.publishing_help_app_taxonomy_terms USING btree (id, vocabulary_id, locale);


--
-- Name: uidx_help_app_term_sib_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_term_sib_pos ON public.publishing_help_app_taxonomy_terms USING btree (vocabulary_id, locale, parent_id, "position") NULLS NOT DISTINCT;


--
-- Name: uidx_help_app_term_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_term_slug ON public.publishing_help_app_taxonomy_terms USING btree (vocabulary_id, locale, slug);


--
-- Name: uidx_help_app_ver_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_ver_id_entry ON public.publishing_help_app_entry_versions USING btree (id, entry_id);


--
-- Name: uidx_help_app_ver_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_ver_id_entry_locale ON public.publishing_help_app_entry_versions USING btree (id, entry_id, locale);


--
-- Name: uidx_help_app_ver_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_ver_id_locale ON public.publishing_help_app_entry_versions USING btree (id, locale);


--
-- Name: uidx_help_app_ver_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_ver_media_pos ON public.publishing_help_app_version_media_usages USING btree (entry_version_id, role, field_path, block_path, "position");


--
-- Name: uidx_help_app_ver_on_revision; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_ver_on_revision ON public.publishing_help_app_entry_versions USING btree (entry_revision_id);


--
-- Name: uidx_help_app_ver_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_ver_seq ON public.publishing_help_app_entry_versions USING btree (entry_id, sequence);


--
-- Name: uidx_help_app_vm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_vm_pos ON public.publishing_help_app_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, "position");


--
-- Name: uidx_help_app_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_vm_term ON public.publishing_help_app_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_help_app_voc_id_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_voc_id_kind ON public.publishing_help_app_vocabularies USING btree (id, kind);


--
-- Name: uidx_help_app_voc_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_voc_key ON public.publishing_help_app_vocabularies USING btree (key);


--
-- Name: uidx_help_app_vs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_app_vs_owner ON public.publishing_help_app_version_single_taxonomy_assignments USING btree (entry_version_id, vocabulary_id);


--
-- Name: uidx_help_com_ent_current_rev; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_ent_current_rev ON public.publishing_help_com_entries USING btree (current_revision_id);


--
-- Name: uidx_help_com_ent_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_ent_id_locale ON public.publishing_help_com_entries USING btree (id, locale);


--
-- Name: uidx_help_com_rev_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_rev_id_entry ON public.publishing_help_com_entry_revisions USING btree (id, entry_id);


--
-- Name: uidx_help_com_rev_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_rev_id_entry_locale ON public.publishing_help_com_entry_revisions USING btree (id, entry_id, locale);


--
-- Name: uidx_help_com_rev_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_rev_id_locale ON public.publishing_help_com_entry_revisions USING btree (id, locale);


--
-- Name: uidx_help_com_rev_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_rev_media_pos ON public.publishing_help_com_revision_media_usages USING btree (entry_revision_id, role, field_path, block_path, "position");


--
-- Name: uidx_help_com_rev_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_rev_seq ON public.publishing_help_com_entry_revisions USING btree (entry_id, sequence);


--
-- Name: uidx_help_com_rm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_rm_pos ON public.publishing_help_com_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, "position");


--
-- Name: uidx_help_com_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_rm_term ON public.publishing_help_com_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_help_com_rs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_rs_owner ON public.publishing_help_com_revision_single_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id);


--
-- Name: uidx_help_com_slug_canonical; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_slug_canonical ON public.publishing_help_com_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'canonical'::text);


--
-- Name: uidx_help_com_slug_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_slug_locale ON public.publishing_help_com_entry_slugs USING btree (locale, slug);


--
-- Name: uidx_help_com_slug_reserved; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_slug_reserved ON public.publishing_help_com_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'reserved'::text);


--
-- Name: uidx_help_com_term_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_term_scope ON public.publishing_help_com_taxonomy_terms USING btree (id, vocabulary_id, locale);


--
-- Name: uidx_help_com_term_sib_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_term_sib_pos ON public.publishing_help_com_taxonomy_terms USING btree (vocabulary_id, locale, parent_id, "position") NULLS NOT DISTINCT;


--
-- Name: uidx_help_com_term_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_term_slug ON public.publishing_help_com_taxonomy_terms USING btree (vocabulary_id, locale, slug);


--
-- Name: uidx_help_com_ver_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_ver_id_entry ON public.publishing_help_com_entry_versions USING btree (id, entry_id);


--
-- Name: uidx_help_com_ver_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_ver_id_entry_locale ON public.publishing_help_com_entry_versions USING btree (id, entry_id, locale);


--
-- Name: uidx_help_com_ver_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_ver_id_locale ON public.publishing_help_com_entry_versions USING btree (id, locale);


--
-- Name: uidx_help_com_ver_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_ver_media_pos ON public.publishing_help_com_version_media_usages USING btree (entry_version_id, role, field_path, block_path, "position");


--
-- Name: uidx_help_com_ver_on_revision; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_ver_on_revision ON public.publishing_help_com_entry_versions USING btree (entry_revision_id);


--
-- Name: uidx_help_com_ver_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_ver_seq ON public.publishing_help_com_entry_versions USING btree (entry_id, sequence);


--
-- Name: uidx_help_com_vm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_vm_pos ON public.publishing_help_com_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, "position");


--
-- Name: uidx_help_com_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_vm_term ON public.publishing_help_com_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_help_com_voc_id_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_voc_id_kind ON public.publishing_help_com_vocabularies USING btree (id, kind);


--
-- Name: uidx_help_com_voc_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_voc_key ON public.publishing_help_com_vocabularies USING btree (key);


--
-- Name: uidx_help_com_vs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_com_vs_owner ON public.publishing_help_com_version_single_taxonomy_assignments USING btree (entry_version_id, vocabulary_id);


--
-- Name: uidx_help_org_ent_current_rev; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_ent_current_rev ON public.publishing_help_org_entries USING btree (current_revision_id);


--
-- Name: uidx_help_org_ent_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_ent_id_locale ON public.publishing_help_org_entries USING btree (id, locale);


--
-- Name: uidx_help_org_rev_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_rev_id_entry ON public.publishing_help_org_entry_revisions USING btree (id, entry_id);


--
-- Name: uidx_help_org_rev_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_rev_id_entry_locale ON public.publishing_help_org_entry_revisions USING btree (id, entry_id, locale);


--
-- Name: uidx_help_org_rev_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_rev_id_locale ON public.publishing_help_org_entry_revisions USING btree (id, locale);


--
-- Name: uidx_help_org_rev_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_rev_media_pos ON public.publishing_help_org_revision_media_usages USING btree (entry_revision_id, role, field_path, block_path, "position");


--
-- Name: uidx_help_org_rev_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_rev_seq ON public.publishing_help_org_entry_revisions USING btree (entry_id, sequence);


--
-- Name: uidx_help_org_rm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_rm_pos ON public.publishing_help_org_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, "position");


--
-- Name: uidx_help_org_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_rm_term ON public.publishing_help_org_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_help_org_rs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_rs_owner ON public.publishing_help_org_revision_single_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id);


--
-- Name: uidx_help_org_slug_canonical; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_slug_canonical ON public.publishing_help_org_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'canonical'::text);


--
-- Name: uidx_help_org_slug_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_slug_locale ON public.publishing_help_org_entry_slugs USING btree (locale, slug);


--
-- Name: uidx_help_org_slug_reserved; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_slug_reserved ON public.publishing_help_org_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'reserved'::text);


--
-- Name: uidx_help_org_term_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_term_scope ON public.publishing_help_org_taxonomy_terms USING btree (id, vocabulary_id, locale);


--
-- Name: uidx_help_org_term_sib_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_term_sib_pos ON public.publishing_help_org_taxonomy_terms USING btree (vocabulary_id, locale, parent_id, "position") NULLS NOT DISTINCT;


--
-- Name: uidx_help_org_term_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_term_slug ON public.publishing_help_org_taxonomy_terms USING btree (vocabulary_id, locale, slug);


--
-- Name: uidx_help_org_ver_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_ver_id_entry ON public.publishing_help_org_entry_versions USING btree (id, entry_id);


--
-- Name: uidx_help_org_ver_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_ver_id_entry_locale ON public.publishing_help_org_entry_versions USING btree (id, entry_id, locale);


--
-- Name: uidx_help_org_ver_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_ver_id_locale ON public.publishing_help_org_entry_versions USING btree (id, locale);


--
-- Name: uidx_help_org_ver_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_ver_media_pos ON public.publishing_help_org_version_media_usages USING btree (entry_version_id, role, field_path, block_path, "position");


--
-- Name: uidx_help_org_ver_on_revision; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_ver_on_revision ON public.publishing_help_org_entry_versions USING btree (entry_revision_id);


--
-- Name: uidx_help_org_ver_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_ver_seq ON public.publishing_help_org_entry_versions USING btree (entry_id, sequence);


--
-- Name: uidx_help_org_vm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_vm_pos ON public.publishing_help_org_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, "position");


--
-- Name: uidx_help_org_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_vm_term ON public.publishing_help_org_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_help_org_voc_id_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_voc_id_kind ON public.publishing_help_org_vocabularies USING btree (id, kind);


--
-- Name: uidx_help_org_voc_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_voc_key ON public.publishing_help_org_vocabularies USING btree (key);


--
-- Name: uidx_help_org_vs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_help_org_vs_owner ON public.publishing_help_org_version_single_taxonomy_assignments USING btree (entry_version_id, vocabulary_id);


--
-- Name: uidx_info_app_ent_current_rev; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_ent_current_rev ON public.publishing_info_app_entries USING btree (current_revision_id);


--
-- Name: uidx_info_app_ent_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_ent_id_locale ON public.publishing_info_app_entries USING btree (id, locale);


--
-- Name: uidx_info_app_rev_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_rev_id_entry ON public.publishing_info_app_entry_revisions USING btree (id, entry_id);


--
-- Name: uidx_info_app_rev_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_rev_id_entry_locale ON public.publishing_info_app_entry_revisions USING btree (id, entry_id, locale);


--
-- Name: uidx_info_app_rev_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_rev_id_locale ON public.publishing_info_app_entry_revisions USING btree (id, locale);


--
-- Name: uidx_info_app_rev_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_rev_media_pos ON public.publishing_info_app_revision_media_usages USING btree (entry_revision_id, role, field_path, block_path, "position");


--
-- Name: uidx_info_app_rev_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_rev_seq ON public.publishing_info_app_entry_revisions USING btree (entry_id, sequence);


--
-- Name: uidx_info_app_rm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_rm_pos ON public.publishing_info_app_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, "position");


--
-- Name: uidx_info_app_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_rm_term ON public.publishing_info_app_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_info_app_rs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_rs_owner ON public.publishing_info_app_revision_single_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id);


--
-- Name: uidx_info_app_slug_canonical; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_slug_canonical ON public.publishing_info_app_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'canonical'::text);


--
-- Name: uidx_info_app_slug_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_slug_locale ON public.publishing_info_app_entry_slugs USING btree (locale, slug);


--
-- Name: uidx_info_app_slug_reserved; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_slug_reserved ON public.publishing_info_app_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'reserved'::text);


--
-- Name: uidx_info_app_term_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_term_scope ON public.publishing_info_app_taxonomy_terms USING btree (id, vocabulary_id, locale);


--
-- Name: uidx_info_app_term_sib_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_term_sib_pos ON public.publishing_info_app_taxonomy_terms USING btree (vocabulary_id, locale, parent_id, "position") NULLS NOT DISTINCT;


--
-- Name: uidx_info_app_term_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_term_slug ON public.publishing_info_app_taxonomy_terms USING btree (vocabulary_id, locale, slug);


--
-- Name: uidx_info_app_ver_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_ver_id_entry ON public.publishing_info_app_entry_versions USING btree (id, entry_id);


--
-- Name: uidx_info_app_ver_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_ver_id_entry_locale ON public.publishing_info_app_entry_versions USING btree (id, entry_id, locale);


--
-- Name: uidx_info_app_ver_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_ver_id_locale ON public.publishing_info_app_entry_versions USING btree (id, locale);


--
-- Name: uidx_info_app_ver_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_ver_media_pos ON public.publishing_info_app_version_media_usages USING btree (entry_version_id, role, field_path, block_path, "position");


--
-- Name: uidx_info_app_ver_on_revision; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_ver_on_revision ON public.publishing_info_app_entry_versions USING btree (entry_revision_id);


--
-- Name: uidx_info_app_ver_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_ver_seq ON public.publishing_info_app_entry_versions USING btree (entry_id, sequence);


--
-- Name: uidx_info_app_vm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_vm_pos ON public.publishing_info_app_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, "position");


--
-- Name: uidx_info_app_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_vm_term ON public.publishing_info_app_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_info_app_voc_id_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_voc_id_kind ON public.publishing_info_app_vocabularies USING btree (id, kind);


--
-- Name: uidx_info_app_voc_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_voc_key ON public.publishing_info_app_vocabularies USING btree (key);


--
-- Name: uidx_info_app_vs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_app_vs_owner ON public.publishing_info_app_version_single_taxonomy_assignments USING btree (entry_version_id, vocabulary_id);


--
-- Name: uidx_info_com_ent_current_rev; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_ent_current_rev ON public.publishing_info_com_entries USING btree (current_revision_id);


--
-- Name: uidx_info_com_ent_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_ent_id_locale ON public.publishing_info_com_entries USING btree (id, locale);


--
-- Name: uidx_info_com_rev_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_rev_id_entry ON public.publishing_info_com_entry_revisions USING btree (id, entry_id);


--
-- Name: uidx_info_com_rev_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_rev_id_entry_locale ON public.publishing_info_com_entry_revisions USING btree (id, entry_id, locale);


--
-- Name: uidx_info_com_rev_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_rev_id_locale ON public.publishing_info_com_entry_revisions USING btree (id, locale);


--
-- Name: uidx_info_com_rev_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_rev_media_pos ON public.publishing_info_com_revision_media_usages USING btree (entry_revision_id, role, field_path, block_path, "position");


--
-- Name: uidx_info_com_rev_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_rev_seq ON public.publishing_info_com_entry_revisions USING btree (entry_id, sequence);


--
-- Name: uidx_info_com_rm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_rm_pos ON public.publishing_info_com_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, "position");


--
-- Name: uidx_info_com_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_rm_term ON public.publishing_info_com_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_info_com_rs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_rs_owner ON public.publishing_info_com_revision_single_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id);


--
-- Name: uidx_info_com_slug_canonical; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_slug_canonical ON public.publishing_info_com_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'canonical'::text);


--
-- Name: uidx_info_com_slug_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_slug_locale ON public.publishing_info_com_entry_slugs USING btree (locale, slug);


--
-- Name: uidx_info_com_slug_reserved; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_slug_reserved ON public.publishing_info_com_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'reserved'::text);


--
-- Name: uidx_info_com_term_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_term_scope ON public.publishing_info_com_taxonomy_terms USING btree (id, vocabulary_id, locale);


--
-- Name: uidx_info_com_term_sib_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_term_sib_pos ON public.publishing_info_com_taxonomy_terms USING btree (vocabulary_id, locale, parent_id, "position") NULLS NOT DISTINCT;


--
-- Name: uidx_info_com_term_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_term_slug ON public.publishing_info_com_taxonomy_terms USING btree (vocabulary_id, locale, slug);


--
-- Name: uidx_info_com_ver_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_ver_id_entry ON public.publishing_info_com_entry_versions USING btree (id, entry_id);


--
-- Name: uidx_info_com_ver_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_ver_id_entry_locale ON public.publishing_info_com_entry_versions USING btree (id, entry_id, locale);


--
-- Name: uidx_info_com_ver_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_ver_id_locale ON public.publishing_info_com_entry_versions USING btree (id, locale);


--
-- Name: uidx_info_com_ver_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_ver_media_pos ON public.publishing_info_com_version_media_usages USING btree (entry_version_id, role, field_path, block_path, "position");


--
-- Name: uidx_info_com_ver_on_revision; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_ver_on_revision ON public.publishing_info_com_entry_versions USING btree (entry_revision_id);


--
-- Name: uidx_info_com_ver_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_ver_seq ON public.publishing_info_com_entry_versions USING btree (entry_id, sequence);


--
-- Name: uidx_info_com_vm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_vm_pos ON public.publishing_info_com_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, "position");


--
-- Name: uidx_info_com_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_vm_term ON public.publishing_info_com_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_info_com_voc_id_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_voc_id_kind ON public.publishing_info_com_vocabularies USING btree (id, kind);


--
-- Name: uidx_info_com_voc_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_voc_key ON public.publishing_info_com_vocabularies USING btree (key);


--
-- Name: uidx_info_com_vs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_com_vs_owner ON public.publishing_info_com_version_single_taxonomy_assignments USING btree (entry_version_id, vocabulary_id);


--
-- Name: uidx_info_org_ent_current_rev; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_ent_current_rev ON public.publishing_info_org_entries USING btree (current_revision_id);


--
-- Name: uidx_info_org_ent_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_ent_id_locale ON public.publishing_info_org_entries USING btree (id, locale);


--
-- Name: uidx_info_org_rev_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_rev_id_entry ON public.publishing_info_org_entry_revisions USING btree (id, entry_id);


--
-- Name: uidx_info_org_rev_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_rev_id_entry_locale ON public.publishing_info_org_entry_revisions USING btree (id, entry_id, locale);


--
-- Name: uidx_info_org_rev_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_rev_id_locale ON public.publishing_info_org_entry_revisions USING btree (id, locale);


--
-- Name: uidx_info_org_rev_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_rev_media_pos ON public.publishing_info_org_revision_media_usages USING btree (entry_revision_id, role, field_path, block_path, "position");


--
-- Name: uidx_info_org_rev_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_rev_seq ON public.publishing_info_org_entry_revisions USING btree (entry_id, sequence);


--
-- Name: uidx_info_org_rm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_rm_pos ON public.publishing_info_org_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, "position");


--
-- Name: uidx_info_org_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_rm_term ON public.publishing_info_org_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_info_org_rs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_rs_owner ON public.publishing_info_org_revision_single_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id);


--
-- Name: uidx_info_org_slug_canonical; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_slug_canonical ON public.publishing_info_org_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'canonical'::text);


--
-- Name: uidx_info_org_slug_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_slug_locale ON public.publishing_info_org_entry_slugs USING btree (locale, slug);


--
-- Name: uidx_info_org_slug_reserved; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_slug_reserved ON public.publishing_info_org_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'reserved'::text);


--
-- Name: uidx_info_org_term_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_term_scope ON public.publishing_info_org_taxonomy_terms USING btree (id, vocabulary_id, locale);


--
-- Name: uidx_info_org_term_sib_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_term_sib_pos ON public.publishing_info_org_taxonomy_terms USING btree (vocabulary_id, locale, parent_id, "position") NULLS NOT DISTINCT;


--
-- Name: uidx_info_org_term_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_term_slug ON public.publishing_info_org_taxonomy_terms USING btree (vocabulary_id, locale, slug);


--
-- Name: uidx_info_org_ver_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_ver_id_entry ON public.publishing_info_org_entry_versions USING btree (id, entry_id);


--
-- Name: uidx_info_org_ver_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_ver_id_entry_locale ON public.publishing_info_org_entry_versions USING btree (id, entry_id, locale);


--
-- Name: uidx_info_org_ver_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_ver_id_locale ON public.publishing_info_org_entry_versions USING btree (id, locale);


--
-- Name: uidx_info_org_ver_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_ver_media_pos ON public.publishing_info_org_version_media_usages USING btree (entry_version_id, role, field_path, block_path, "position");


--
-- Name: uidx_info_org_ver_on_revision; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_ver_on_revision ON public.publishing_info_org_entry_versions USING btree (entry_revision_id);


--
-- Name: uidx_info_org_ver_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_ver_seq ON public.publishing_info_org_entry_versions USING btree (entry_id, sequence);


--
-- Name: uidx_info_org_vm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_vm_pos ON public.publishing_info_org_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, "position");


--
-- Name: uidx_info_org_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_vm_term ON public.publishing_info_org_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_info_org_voc_id_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_voc_id_kind ON public.publishing_info_org_vocabularies USING btree (id, kind);


--
-- Name: uidx_info_org_voc_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_voc_key ON public.publishing_info_org_vocabularies USING btree (key);


--
-- Name: uidx_info_org_vs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_info_org_vs_owner ON public.publishing_info_org_version_single_taxonomy_assignments USING btree (entry_version_id, vocabulary_id);


--
-- Name: uidx_news_app_ent_current_rev; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_ent_current_rev ON public.publishing_news_app_entries USING btree (current_revision_id);


--
-- Name: uidx_news_app_ent_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_ent_id_locale ON public.publishing_news_app_entries USING btree (id, locale);


--
-- Name: uidx_news_app_rev_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_rev_id_entry ON public.publishing_news_app_entry_revisions USING btree (id, entry_id);


--
-- Name: uidx_news_app_rev_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_rev_id_entry_locale ON public.publishing_news_app_entry_revisions USING btree (id, entry_id, locale);


--
-- Name: uidx_news_app_rev_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_rev_id_locale ON public.publishing_news_app_entry_revisions USING btree (id, locale);


--
-- Name: uidx_news_app_rev_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_rev_media_pos ON public.publishing_news_app_revision_media_usages USING btree (entry_revision_id, role, field_path, block_path, "position");


--
-- Name: uidx_news_app_rev_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_rev_seq ON public.publishing_news_app_entry_revisions USING btree (entry_id, sequence);


--
-- Name: uidx_news_app_rm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_rm_pos ON public.publishing_news_app_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, "position");


--
-- Name: uidx_news_app_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_rm_term ON public.publishing_news_app_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_news_app_rs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_rs_owner ON public.publishing_news_app_revision_single_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id);


--
-- Name: uidx_news_app_slug_canonical; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_slug_canonical ON public.publishing_news_app_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'canonical'::text);


--
-- Name: uidx_news_app_slug_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_slug_locale ON public.publishing_news_app_entry_slugs USING btree (locale, slug);


--
-- Name: uidx_news_app_slug_reserved; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_slug_reserved ON public.publishing_news_app_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'reserved'::text);


--
-- Name: uidx_news_app_term_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_term_scope ON public.publishing_news_app_taxonomy_terms USING btree (id, vocabulary_id, locale);


--
-- Name: uidx_news_app_term_sib_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_term_sib_pos ON public.publishing_news_app_taxonomy_terms USING btree (vocabulary_id, locale, parent_id, "position") NULLS NOT DISTINCT;


--
-- Name: uidx_news_app_term_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_term_slug ON public.publishing_news_app_taxonomy_terms USING btree (vocabulary_id, locale, slug);


--
-- Name: uidx_news_app_ver_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_ver_id_entry ON public.publishing_news_app_entry_versions USING btree (id, entry_id);


--
-- Name: uidx_news_app_ver_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_ver_id_entry_locale ON public.publishing_news_app_entry_versions USING btree (id, entry_id, locale);


--
-- Name: uidx_news_app_ver_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_ver_id_locale ON public.publishing_news_app_entry_versions USING btree (id, locale);


--
-- Name: uidx_news_app_ver_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_ver_media_pos ON public.publishing_news_app_version_media_usages USING btree (entry_version_id, role, field_path, block_path, "position");


--
-- Name: uidx_news_app_ver_on_revision; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_ver_on_revision ON public.publishing_news_app_entry_versions USING btree (entry_revision_id);


--
-- Name: uidx_news_app_ver_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_ver_seq ON public.publishing_news_app_entry_versions USING btree (entry_id, sequence);


--
-- Name: uidx_news_app_vm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_vm_pos ON public.publishing_news_app_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, "position");


--
-- Name: uidx_news_app_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_vm_term ON public.publishing_news_app_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_news_app_voc_id_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_voc_id_kind ON public.publishing_news_app_vocabularies USING btree (id, kind);


--
-- Name: uidx_news_app_voc_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_voc_key ON public.publishing_news_app_vocabularies USING btree (key);


--
-- Name: uidx_news_app_vs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_app_vs_owner ON public.publishing_news_app_version_single_taxonomy_assignments USING btree (entry_version_id, vocabulary_id);


--
-- Name: uidx_news_com_ent_current_rev; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_ent_current_rev ON public.publishing_news_com_entries USING btree (current_revision_id);


--
-- Name: uidx_news_com_ent_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_ent_id_locale ON public.publishing_news_com_entries USING btree (id, locale);


--
-- Name: uidx_news_com_rev_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_rev_id_entry ON public.publishing_news_com_entry_revisions USING btree (id, entry_id);


--
-- Name: uidx_news_com_rev_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_rev_id_entry_locale ON public.publishing_news_com_entry_revisions USING btree (id, entry_id, locale);


--
-- Name: uidx_news_com_rev_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_rev_id_locale ON public.publishing_news_com_entry_revisions USING btree (id, locale);


--
-- Name: uidx_news_com_rev_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_rev_media_pos ON public.publishing_news_com_revision_media_usages USING btree (entry_revision_id, role, field_path, block_path, "position");


--
-- Name: uidx_news_com_rev_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_rev_seq ON public.publishing_news_com_entry_revisions USING btree (entry_id, sequence);


--
-- Name: uidx_news_com_rm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_rm_pos ON public.publishing_news_com_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, "position");


--
-- Name: uidx_news_com_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_rm_term ON public.publishing_news_com_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_news_com_rs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_rs_owner ON public.publishing_news_com_revision_single_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id);


--
-- Name: uidx_news_com_slug_canonical; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_slug_canonical ON public.publishing_news_com_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'canonical'::text);


--
-- Name: uidx_news_com_slug_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_slug_locale ON public.publishing_news_com_entry_slugs USING btree (locale, slug);


--
-- Name: uidx_news_com_slug_reserved; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_slug_reserved ON public.publishing_news_com_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'reserved'::text);


--
-- Name: uidx_news_com_term_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_term_scope ON public.publishing_news_com_taxonomy_terms USING btree (id, vocabulary_id, locale);


--
-- Name: uidx_news_com_term_sib_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_term_sib_pos ON public.publishing_news_com_taxonomy_terms USING btree (vocabulary_id, locale, parent_id, "position") NULLS NOT DISTINCT;


--
-- Name: uidx_news_com_term_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_term_slug ON public.publishing_news_com_taxonomy_terms USING btree (vocabulary_id, locale, slug);


--
-- Name: uidx_news_com_ver_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_ver_id_entry ON public.publishing_news_com_entry_versions USING btree (id, entry_id);


--
-- Name: uidx_news_com_ver_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_ver_id_entry_locale ON public.publishing_news_com_entry_versions USING btree (id, entry_id, locale);


--
-- Name: uidx_news_com_ver_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_ver_id_locale ON public.publishing_news_com_entry_versions USING btree (id, locale);


--
-- Name: uidx_news_com_ver_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_ver_media_pos ON public.publishing_news_com_version_media_usages USING btree (entry_version_id, role, field_path, block_path, "position");


--
-- Name: uidx_news_com_ver_on_revision; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_ver_on_revision ON public.publishing_news_com_entry_versions USING btree (entry_revision_id);


--
-- Name: uidx_news_com_ver_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_ver_seq ON public.publishing_news_com_entry_versions USING btree (entry_id, sequence);


--
-- Name: uidx_news_com_vm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_vm_pos ON public.publishing_news_com_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, "position");


--
-- Name: uidx_news_com_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_vm_term ON public.publishing_news_com_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_news_com_voc_id_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_voc_id_kind ON public.publishing_news_com_vocabularies USING btree (id, kind);


--
-- Name: uidx_news_com_voc_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_voc_key ON public.publishing_news_com_vocabularies USING btree (key);


--
-- Name: uidx_news_com_vs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_com_vs_owner ON public.publishing_news_com_version_single_taxonomy_assignments USING btree (entry_version_id, vocabulary_id);


--
-- Name: uidx_news_org_ent_current_rev; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_ent_current_rev ON public.publishing_news_org_entries USING btree (current_revision_id);


--
-- Name: uidx_news_org_ent_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_ent_id_locale ON public.publishing_news_org_entries USING btree (id, locale);


--
-- Name: uidx_news_org_rev_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_rev_id_entry ON public.publishing_news_org_entry_revisions USING btree (id, entry_id);


--
-- Name: uidx_news_org_rev_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_rev_id_entry_locale ON public.publishing_news_org_entry_revisions USING btree (id, entry_id, locale);


--
-- Name: uidx_news_org_rev_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_rev_id_locale ON public.publishing_news_org_entry_revisions USING btree (id, locale);


--
-- Name: uidx_news_org_rev_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_rev_media_pos ON public.publishing_news_org_revision_media_usages USING btree (entry_revision_id, role, field_path, block_path, "position");


--
-- Name: uidx_news_org_rev_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_rev_seq ON public.publishing_news_org_entry_revisions USING btree (entry_id, sequence);


--
-- Name: uidx_news_org_rm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_rm_pos ON public.publishing_news_org_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, "position");


--
-- Name: uidx_news_org_rm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_rm_term ON public.publishing_news_org_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_news_org_rs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_rs_owner ON public.publishing_news_org_revision_single_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id);


--
-- Name: uidx_news_org_slug_canonical; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_slug_canonical ON public.publishing_news_org_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'canonical'::text);


--
-- Name: uidx_news_org_slug_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_slug_locale ON public.publishing_news_org_entry_slugs USING btree (locale, slug);


--
-- Name: uidx_news_org_slug_reserved; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_slug_reserved ON public.publishing_news_org_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'reserved'::text);


--
-- Name: uidx_news_org_term_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_term_scope ON public.publishing_news_org_taxonomy_terms USING btree (id, vocabulary_id, locale);


--
-- Name: uidx_news_org_term_sib_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_term_sib_pos ON public.publishing_news_org_taxonomy_terms USING btree (vocabulary_id, locale, parent_id, "position") NULLS NOT DISTINCT;


--
-- Name: uidx_news_org_term_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_term_slug ON public.publishing_news_org_taxonomy_terms USING btree (vocabulary_id, locale, slug);


--
-- Name: uidx_news_org_ver_id_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_ver_id_entry ON public.publishing_news_org_entry_versions USING btree (id, entry_id);


--
-- Name: uidx_news_org_ver_id_entry_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_ver_id_entry_locale ON public.publishing_news_org_entry_versions USING btree (id, entry_id, locale);


--
-- Name: uidx_news_org_ver_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_ver_id_locale ON public.publishing_news_org_entry_versions USING btree (id, locale);


--
-- Name: uidx_news_org_ver_media_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_ver_media_pos ON public.publishing_news_org_version_media_usages USING btree (entry_version_id, role, field_path, block_path, "position");


--
-- Name: uidx_news_org_ver_on_revision; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_ver_on_revision ON public.publishing_news_org_entry_versions USING btree (entry_revision_id);


--
-- Name: uidx_news_org_ver_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_ver_seq ON public.publishing_news_org_entry_versions USING btree (entry_id, sequence);


--
-- Name: uidx_news_org_vm_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_vm_pos ON public.publishing_news_org_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, "position");


--
-- Name: uidx_news_org_vm_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_vm_term ON public.publishing_news_org_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_news_org_voc_id_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_voc_id_kind ON public.publishing_news_org_vocabularies USING btree (id, kind);


--
-- Name: uidx_news_org_voc_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_voc_key ON public.publishing_news_org_vocabularies USING btree (key);


--
-- Name: uidx_news_org_vs_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_news_org_vs_owner ON public.publishing_news_org_version_single_taxonomy_assignments USING btree (entry_version_id, vocabulary_id);


--
-- Name: publishing_docs_app_entry_revisions trg_docs_app_rev_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_app_rev_promoted BEFORE DELETE OR UPDATE ON public.publishing_docs_app_entry_revisions FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_docs_app_entry_versions');


--
-- Name: publishing_docs_app_revision_multiple_taxonomy_assignments trg_docs_app_rm_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_app_rm_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_docs_app_revision_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_docs_app_entry_versions');


--
-- Name: publishing_docs_app_revision_media_usages trg_docs_app_rmedia_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_app_rmedia_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_docs_app_revision_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_docs_app_entry_versions');


--
-- Name: publishing_docs_app_revision_single_taxonomy_assignments trg_docs_app_rs_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_app_rs_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_docs_app_revision_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_docs_app_entry_versions');


--
-- Name: publishing_docs_app_taxonomy_terms trg_docs_app_term_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_app_term_no_delete BEFORE DELETE ON public.publishing_docs_app_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_docs_app_taxonomy_terms trg_docs_app_terms_hierarchy; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_app_terms_hierarchy BEFORE INSERT OR UPDATE ON public.publishing_docs_app_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_taxonomy_term_hierarchy_guard('publishing_docs_app_taxonomy_terms');


--
-- Name: publishing_docs_app_entry_versions trg_docs_app_ver_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_app_ver_imm BEFORE DELETE OR UPDATE ON public.publishing_docs_app_entry_versions FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_docs_app_entry_versions trg_docs_app_ver_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_docs_app_ver_media_c AFTER INSERT ON public.publishing_docs_app_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_docs_app_entry_versions', 'publishing_docs_app_revision_media_usages', 'publishing_docs_app_version_media_usages');


--
-- Name: publishing_docs_app_entry_versions trg_docs_app_ver_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_docs_app_ver_snap_c AFTER INSERT ON public.publishing_docs_app_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_docs_app_entry_versions', 'publishing_docs_app_revision_single_taxonomy_assignments', 'publishing_docs_app_version_single_taxonomy_assignments', 'publishing_docs_app_revision_multiple_taxonomy_assignments', 'publishing_docs_app_version_multiple_taxonomy_assignments');


--
-- Name: publishing_docs_app_version_multiple_taxonomy_assignments trg_docs_app_vm_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_app_vm_imm BEFORE DELETE OR UPDATE ON public.publishing_docs_app_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_docs_app_version_multiple_taxonomy_assignments trg_docs_app_vm_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_app_vm_snap BEFORE INSERT ON public.publishing_docs_app_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_docs_app_vocabularies', 'publishing_docs_app_taxonomy_terms', 'ordered');


--
-- Name: publishing_docs_app_version_multiple_taxonomy_assignments trg_docs_app_vm_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_docs_app_vm_snap_c AFTER INSERT ON public.publishing_docs_app_version_multiple_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_docs_app_entry_versions', 'publishing_docs_app_revision_single_taxonomy_assignments', 'publishing_docs_app_version_single_taxonomy_assignments', 'publishing_docs_app_revision_multiple_taxonomy_assignments', 'publishing_docs_app_version_multiple_taxonomy_assignments');


--
-- Name: publishing_docs_app_version_media_usages trg_docs_app_vmedia_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_app_vmedia_imm BEFORE DELETE OR UPDATE ON public.publishing_docs_app_version_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_docs_app_version_media_usages trg_docs_app_vmedia_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_docs_app_vmedia_media_c AFTER INSERT ON public.publishing_docs_app_version_media_usages DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_docs_app_entry_versions', 'publishing_docs_app_revision_media_usages', 'publishing_docs_app_version_media_usages');


--
-- Name: publishing_docs_app_vocabularies trg_docs_app_voc_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_app_voc_no_delete BEFORE DELETE ON public.publishing_docs_app_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_docs_app_vocabularies trg_docs_app_voc_structure; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_app_voc_structure BEFORE UPDATE ON public.publishing_docs_app_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_vocabulary_structure_guard();


--
-- Name: publishing_docs_app_version_single_taxonomy_assignments trg_docs_app_vs_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_app_vs_imm BEFORE DELETE OR UPDATE ON public.publishing_docs_app_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_docs_app_version_single_taxonomy_assignments trg_docs_app_vs_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_app_vs_snap BEFORE INSERT ON public.publishing_docs_app_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_docs_app_vocabularies', 'publishing_docs_app_taxonomy_terms', 'single');


--
-- Name: publishing_docs_app_version_single_taxonomy_assignments trg_docs_app_vs_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_docs_app_vs_snap_c AFTER INSERT ON public.publishing_docs_app_version_single_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_docs_app_entry_versions', 'publishing_docs_app_revision_single_taxonomy_assignments', 'publishing_docs_app_version_single_taxonomy_assignments', 'publishing_docs_app_revision_multiple_taxonomy_assignments', 'publishing_docs_app_version_multiple_taxonomy_assignments');


--
-- Name: publishing_docs_com_entry_revisions trg_docs_com_rev_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_com_rev_promoted BEFORE DELETE OR UPDATE ON public.publishing_docs_com_entry_revisions FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_docs_com_entry_versions');


--
-- Name: publishing_docs_com_revision_multiple_taxonomy_assignments trg_docs_com_rm_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_com_rm_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_docs_com_revision_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_docs_com_entry_versions');


--
-- Name: publishing_docs_com_revision_media_usages trg_docs_com_rmedia_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_com_rmedia_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_docs_com_revision_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_docs_com_entry_versions');


--
-- Name: publishing_docs_com_revision_single_taxonomy_assignments trg_docs_com_rs_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_com_rs_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_docs_com_revision_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_docs_com_entry_versions');


--
-- Name: publishing_docs_com_taxonomy_terms trg_docs_com_term_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_com_term_no_delete BEFORE DELETE ON public.publishing_docs_com_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_docs_com_taxonomy_terms trg_docs_com_terms_hierarchy; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_com_terms_hierarchy BEFORE INSERT OR UPDATE ON public.publishing_docs_com_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_taxonomy_term_hierarchy_guard('publishing_docs_com_taxonomy_terms');


--
-- Name: publishing_docs_com_entry_versions trg_docs_com_ver_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_com_ver_imm BEFORE DELETE OR UPDATE ON public.publishing_docs_com_entry_versions FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_docs_com_entry_versions trg_docs_com_ver_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_docs_com_ver_media_c AFTER INSERT ON public.publishing_docs_com_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_docs_com_entry_versions', 'publishing_docs_com_revision_media_usages', 'publishing_docs_com_version_media_usages');


--
-- Name: publishing_docs_com_entry_versions trg_docs_com_ver_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_docs_com_ver_snap_c AFTER INSERT ON public.publishing_docs_com_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_docs_com_entry_versions', 'publishing_docs_com_revision_single_taxonomy_assignments', 'publishing_docs_com_version_single_taxonomy_assignments', 'publishing_docs_com_revision_multiple_taxonomy_assignments', 'publishing_docs_com_version_multiple_taxonomy_assignments');


--
-- Name: publishing_docs_com_version_multiple_taxonomy_assignments trg_docs_com_vm_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_com_vm_imm BEFORE DELETE OR UPDATE ON public.publishing_docs_com_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_docs_com_version_multiple_taxonomy_assignments trg_docs_com_vm_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_com_vm_snap BEFORE INSERT ON public.publishing_docs_com_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_docs_com_vocabularies', 'publishing_docs_com_taxonomy_terms', 'ordered');


--
-- Name: publishing_docs_com_version_multiple_taxonomy_assignments trg_docs_com_vm_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_docs_com_vm_snap_c AFTER INSERT ON public.publishing_docs_com_version_multiple_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_docs_com_entry_versions', 'publishing_docs_com_revision_single_taxonomy_assignments', 'publishing_docs_com_version_single_taxonomy_assignments', 'publishing_docs_com_revision_multiple_taxonomy_assignments', 'publishing_docs_com_version_multiple_taxonomy_assignments');


--
-- Name: publishing_docs_com_version_media_usages trg_docs_com_vmedia_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_com_vmedia_imm BEFORE DELETE OR UPDATE ON public.publishing_docs_com_version_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_docs_com_version_media_usages trg_docs_com_vmedia_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_docs_com_vmedia_media_c AFTER INSERT ON public.publishing_docs_com_version_media_usages DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_docs_com_entry_versions', 'publishing_docs_com_revision_media_usages', 'publishing_docs_com_version_media_usages');


--
-- Name: publishing_docs_com_vocabularies trg_docs_com_voc_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_com_voc_no_delete BEFORE DELETE ON public.publishing_docs_com_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_docs_com_vocabularies trg_docs_com_voc_structure; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_com_voc_structure BEFORE UPDATE ON public.publishing_docs_com_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_vocabulary_structure_guard();


--
-- Name: publishing_docs_com_version_single_taxonomy_assignments trg_docs_com_vs_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_com_vs_imm BEFORE DELETE OR UPDATE ON public.publishing_docs_com_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_docs_com_version_single_taxonomy_assignments trg_docs_com_vs_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_com_vs_snap BEFORE INSERT ON public.publishing_docs_com_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_docs_com_vocabularies', 'publishing_docs_com_taxonomy_terms', 'single');


--
-- Name: publishing_docs_com_version_single_taxonomy_assignments trg_docs_com_vs_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_docs_com_vs_snap_c AFTER INSERT ON public.publishing_docs_com_version_single_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_docs_com_entry_versions', 'publishing_docs_com_revision_single_taxonomy_assignments', 'publishing_docs_com_version_single_taxonomy_assignments', 'publishing_docs_com_revision_multiple_taxonomy_assignments', 'publishing_docs_com_version_multiple_taxonomy_assignments');


--
-- Name: publishing_docs_org_entry_revisions trg_docs_org_rev_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_org_rev_promoted BEFORE DELETE OR UPDATE ON public.publishing_docs_org_entry_revisions FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_docs_org_entry_versions');


--
-- Name: publishing_docs_org_revision_multiple_taxonomy_assignments trg_docs_org_rm_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_org_rm_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_docs_org_revision_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_docs_org_entry_versions');


--
-- Name: publishing_docs_org_revision_media_usages trg_docs_org_rmedia_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_org_rmedia_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_docs_org_revision_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_docs_org_entry_versions');


--
-- Name: publishing_docs_org_revision_single_taxonomy_assignments trg_docs_org_rs_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_org_rs_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_docs_org_revision_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_docs_org_entry_versions');


--
-- Name: publishing_docs_org_taxonomy_terms trg_docs_org_term_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_org_term_no_delete BEFORE DELETE ON public.publishing_docs_org_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_docs_org_taxonomy_terms trg_docs_org_terms_hierarchy; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_org_terms_hierarchy BEFORE INSERT OR UPDATE ON public.publishing_docs_org_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_taxonomy_term_hierarchy_guard('publishing_docs_org_taxonomy_terms');


--
-- Name: publishing_docs_org_entry_versions trg_docs_org_ver_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_org_ver_imm BEFORE DELETE OR UPDATE ON public.publishing_docs_org_entry_versions FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_docs_org_entry_versions trg_docs_org_ver_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_docs_org_ver_media_c AFTER INSERT ON public.publishing_docs_org_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_docs_org_entry_versions', 'publishing_docs_org_revision_media_usages', 'publishing_docs_org_version_media_usages');


--
-- Name: publishing_docs_org_entry_versions trg_docs_org_ver_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_docs_org_ver_snap_c AFTER INSERT ON public.publishing_docs_org_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_docs_org_entry_versions', 'publishing_docs_org_revision_single_taxonomy_assignments', 'publishing_docs_org_version_single_taxonomy_assignments', 'publishing_docs_org_revision_multiple_taxonomy_assignments', 'publishing_docs_org_version_multiple_taxonomy_assignments');


--
-- Name: publishing_docs_org_version_multiple_taxonomy_assignments trg_docs_org_vm_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_org_vm_imm BEFORE DELETE OR UPDATE ON public.publishing_docs_org_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_docs_org_version_multiple_taxonomy_assignments trg_docs_org_vm_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_org_vm_snap BEFORE INSERT ON public.publishing_docs_org_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_docs_org_vocabularies', 'publishing_docs_org_taxonomy_terms', 'ordered');


--
-- Name: publishing_docs_org_version_multiple_taxonomy_assignments trg_docs_org_vm_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_docs_org_vm_snap_c AFTER INSERT ON public.publishing_docs_org_version_multiple_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_docs_org_entry_versions', 'publishing_docs_org_revision_single_taxonomy_assignments', 'publishing_docs_org_version_single_taxonomy_assignments', 'publishing_docs_org_revision_multiple_taxonomy_assignments', 'publishing_docs_org_version_multiple_taxonomy_assignments');


--
-- Name: publishing_docs_org_version_media_usages trg_docs_org_vmedia_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_org_vmedia_imm BEFORE DELETE OR UPDATE ON public.publishing_docs_org_version_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_docs_org_version_media_usages trg_docs_org_vmedia_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_docs_org_vmedia_media_c AFTER INSERT ON public.publishing_docs_org_version_media_usages DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_docs_org_entry_versions', 'publishing_docs_org_revision_media_usages', 'publishing_docs_org_version_media_usages');


--
-- Name: publishing_docs_org_vocabularies trg_docs_org_voc_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_org_voc_no_delete BEFORE DELETE ON public.publishing_docs_org_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_docs_org_vocabularies trg_docs_org_voc_structure; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_org_voc_structure BEFORE UPDATE ON public.publishing_docs_org_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_vocabulary_structure_guard();


--
-- Name: publishing_docs_org_version_single_taxonomy_assignments trg_docs_org_vs_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_org_vs_imm BEFORE DELETE OR UPDATE ON public.publishing_docs_org_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_docs_org_version_single_taxonomy_assignments trg_docs_org_vs_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_docs_org_vs_snap BEFORE INSERT ON public.publishing_docs_org_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_docs_org_vocabularies', 'publishing_docs_org_taxonomy_terms', 'single');


--
-- Name: publishing_docs_org_version_single_taxonomy_assignments trg_docs_org_vs_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_docs_org_vs_snap_c AFTER INSERT ON public.publishing_docs_org_version_single_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_docs_org_entry_versions', 'publishing_docs_org_revision_single_taxonomy_assignments', 'publishing_docs_org_version_single_taxonomy_assignments', 'publishing_docs_org_revision_multiple_taxonomy_assignments', 'publishing_docs_org_version_multiple_taxonomy_assignments');


--
-- Name: publishing_help_app_entry_revisions trg_help_app_rev_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_app_rev_promoted BEFORE DELETE OR UPDATE ON public.publishing_help_app_entry_revisions FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_help_app_entry_versions');


--
-- Name: publishing_help_app_revision_multiple_taxonomy_assignments trg_help_app_rm_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_app_rm_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_help_app_revision_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_help_app_entry_versions');


--
-- Name: publishing_help_app_revision_media_usages trg_help_app_rmedia_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_app_rmedia_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_help_app_revision_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_help_app_entry_versions');


--
-- Name: publishing_help_app_revision_single_taxonomy_assignments trg_help_app_rs_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_app_rs_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_help_app_revision_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_help_app_entry_versions');


--
-- Name: publishing_help_app_taxonomy_terms trg_help_app_term_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_app_term_no_delete BEFORE DELETE ON public.publishing_help_app_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_help_app_taxonomy_terms trg_help_app_terms_hierarchy; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_app_terms_hierarchy BEFORE INSERT OR UPDATE ON public.publishing_help_app_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_taxonomy_term_hierarchy_guard('publishing_help_app_taxonomy_terms');


--
-- Name: publishing_help_app_entry_versions trg_help_app_ver_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_app_ver_imm BEFORE DELETE OR UPDATE ON public.publishing_help_app_entry_versions FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_help_app_entry_versions trg_help_app_ver_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_help_app_ver_media_c AFTER INSERT ON public.publishing_help_app_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_help_app_entry_versions', 'publishing_help_app_revision_media_usages', 'publishing_help_app_version_media_usages');


--
-- Name: publishing_help_app_entry_versions trg_help_app_ver_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_help_app_ver_snap_c AFTER INSERT ON public.publishing_help_app_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_help_app_entry_versions', 'publishing_help_app_revision_single_taxonomy_assignments', 'publishing_help_app_version_single_taxonomy_assignments', 'publishing_help_app_revision_multiple_taxonomy_assignments', 'publishing_help_app_version_multiple_taxonomy_assignments');


--
-- Name: publishing_help_app_version_multiple_taxonomy_assignments trg_help_app_vm_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_app_vm_imm BEFORE DELETE OR UPDATE ON public.publishing_help_app_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_help_app_version_multiple_taxonomy_assignments trg_help_app_vm_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_app_vm_snap BEFORE INSERT ON public.publishing_help_app_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_help_app_vocabularies', 'publishing_help_app_taxonomy_terms', 'ordered');


--
-- Name: publishing_help_app_version_multiple_taxonomy_assignments trg_help_app_vm_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_help_app_vm_snap_c AFTER INSERT ON public.publishing_help_app_version_multiple_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_help_app_entry_versions', 'publishing_help_app_revision_single_taxonomy_assignments', 'publishing_help_app_version_single_taxonomy_assignments', 'publishing_help_app_revision_multiple_taxonomy_assignments', 'publishing_help_app_version_multiple_taxonomy_assignments');


--
-- Name: publishing_help_app_version_media_usages trg_help_app_vmedia_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_app_vmedia_imm BEFORE DELETE OR UPDATE ON public.publishing_help_app_version_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_help_app_version_media_usages trg_help_app_vmedia_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_help_app_vmedia_media_c AFTER INSERT ON public.publishing_help_app_version_media_usages DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_help_app_entry_versions', 'publishing_help_app_revision_media_usages', 'publishing_help_app_version_media_usages');


--
-- Name: publishing_help_app_vocabularies trg_help_app_voc_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_app_voc_no_delete BEFORE DELETE ON public.publishing_help_app_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_help_app_vocabularies trg_help_app_voc_structure; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_app_voc_structure BEFORE UPDATE ON public.publishing_help_app_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_vocabulary_structure_guard();


--
-- Name: publishing_help_app_version_single_taxonomy_assignments trg_help_app_vs_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_app_vs_imm BEFORE DELETE OR UPDATE ON public.publishing_help_app_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_help_app_version_single_taxonomy_assignments trg_help_app_vs_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_app_vs_snap BEFORE INSERT ON public.publishing_help_app_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_help_app_vocabularies', 'publishing_help_app_taxonomy_terms', 'single');


--
-- Name: publishing_help_app_version_single_taxonomy_assignments trg_help_app_vs_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_help_app_vs_snap_c AFTER INSERT ON public.publishing_help_app_version_single_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_help_app_entry_versions', 'publishing_help_app_revision_single_taxonomy_assignments', 'publishing_help_app_version_single_taxonomy_assignments', 'publishing_help_app_revision_multiple_taxonomy_assignments', 'publishing_help_app_version_multiple_taxonomy_assignments');


--
-- Name: publishing_help_com_entry_revisions trg_help_com_rev_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_com_rev_promoted BEFORE DELETE OR UPDATE ON public.publishing_help_com_entry_revisions FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_help_com_entry_versions');


--
-- Name: publishing_help_com_revision_multiple_taxonomy_assignments trg_help_com_rm_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_com_rm_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_help_com_revision_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_help_com_entry_versions');


--
-- Name: publishing_help_com_revision_media_usages trg_help_com_rmedia_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_com_rmedia_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_help_com_revision_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_help_com_entry_versions');


--
-- Name: publishing_help_com_revision_single_taxonomy_assignments trg_help_com_rs_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_com_rs_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_help_com_revision_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_help_com_entry_versions');


--
-- Name: publishing_help_com_taxonomy_terms trg_help_com_term_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_com_term_no_delete BEFORE DELETE ON public.publishing_help_com_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_help_com_taxonomy_terms trg_help_com_terms_hierarchy; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_com_terms_hierarchy BEFORE INSERT OR UPDATE ON public.publishing_help_com_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_taxonomy_term_hierarchy_guard('publishing_help_com_taxonomy_terms');


--
-- Name: publishing_help_com_entry_versions trg_help_com_ver_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_com_ver_imm BEFORE DELETE OR UPDATE ON public.publishing_help_com_entry_versions FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_help_com_entry_versions trg_help_com_ver_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_help_com_ver_media_c AFTER INSERT ON public.publishing_help_com_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_help_com_entry_versions', 'publishing_help_com_revision_media_usages', 'publishing_help_com_version_media_usages');


--
-- Name: publishing_help_com_entry_versions trg_help_com_ver_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_help_com_ver_snap_c AFTER INSERT ON public.publishing_help_com_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_help_com_entry_versions', 'publishing_help_com_revision_single_taxonomy_assignments', 'publishing_help_com_version_single_taxonomy_assignments', 'publishing_help_com_revision_multiple_taxonomy_assignments', 'publishing_help_com_version_multiple_taxonomy_assignments');


--
-- Name: publishing_help_com_version_multiple_taxonomy_assignments trg_help_com_vm_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_com_vm_imm BEFORE DELETE OR UPDATE ON public.publishing_help_com_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_help_com_version_multiple_taxonomy_assignments trg_help_com_vm_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_com_vm_snap BEFORE INSERT ON public.publishing_help_com_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_help_com_vocabularies', 'publishing_help_com_taxonomy_terms', 'ordered');


--
-- Name: publishing_help_com_version_multiple_taxonomy_assignments trg_help_com_vm_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_help_com_vm_snap_c AFTER INSERT ON public.publishing_help_com_version_multiple_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_help_com_entry_versions', 'publishing_help_com_revision_single_taxonomy_assignments', 'publishing_help_com_version_single_taxonomy_assignments', 'publishing_help_com_revision_multiple_taxonomy_assignments', 'publishing_help_com_version_multiple_taxonomy_assignments');


--
-- Name: publishing_help_com_version_media_usages trg_help_com_vmedia_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_com_vmedia_imm BEFORE DELETE OR UPDATE ON public.publishing_help_com_version_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_help_com_version_media_usages trg_help_com_vmedia_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_help_com_vmedia_media_c AFTER INSERT ON public.publishing_help_com_version_media_usages DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_help_com_entry_versions', 'publishing_help_com_revision_media_usages', 'publishing_help_com_version_media_usages');


--
-- Name: publishing_help_com_vocabularies trg_help_com_voc_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_com_voc_no_delete BEFORE DELETE ON public.publishing_help_com_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_help_com_vocabularies trg_help_com_voc_structure; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_com_voc_structure BEFORE UPDATE ON public.publishing_help_com_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_vocabulary_structure_guard();


--
-- Name: publishing_help_com_version_single_taxonomy_assignments trg_help_com_vs_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_com_vs_imm BEFORE DELETE OR UPDATE ON public.publishing_help_com_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_help_com_version_single_taxonomy_assignments trg_help_com_vs_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_com_vs_snap BEFORE INSERT ON public.publishing_help_com_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_help_com_vocabularies', 'publishing_help_com_taxonomy_terms', 'single');


--
-- Name: publishing_help_com_version_single_taxonomy_assignments trg_help_com_vs_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_help_com_vs_snap_c AFTER INSERT ON public.publishing_help_com_version_single_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_help_com_entry_versions', 'publishing_help_com_revision_single_taxonomy_assignments', 'publishing_help_com_version_single_taxonomy_assignments', 'publishing_help_com_revision_multiple_taxonomy_assignments', 'publishing_help_com_version_multiple_taxonomy_assignments');


--
-- Name: publishing_help_org_entry_revisions trg_help_org_rev_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_org_rev_promoted BEFORE DELETE OR UPDATE ON public.publishing_help_org_entry_revisions FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_help_org_entry_versions');


--
-- Name: publishing_help_org_revision_multiple_taxonomy_assignments trg_help_org_rm_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_org_rm_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_help_org_revision_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_help_org_entry_versions');


--
-- Name: publishing_help_org_revision_media_usages trg_help_org_rmedia_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_org_rmedia_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_help_org_revision_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_help_org_entry_versions');


--
-- Name: publishing_help_org_revision_single_taxonomy_assignments trg_help_org_rs_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_org_rs_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_help_org_revision_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_help_org_entry_versions');


--
-- Name: publishing_help_org_taxonomy_terms trg_help_org_term_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_org_term_no_delete BEFORE DELETE ON public.publishing_help_org_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_help_org_taxonomy_terms trg_help_org_terms_hierarchy; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_org_terms_hierarchy BEFORE INSERT OR UPDATE ON public.publishing_help_org_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_taxonomy_term_hierarchy_guard('publishing_help_org_taxonomy_terms');


--
-- Name: publishing_help_org_entry_versions trg_help_org_ver_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_org_ver_imm BEFORE DELETE OR UPDATE ON public.publishing_help_org_entry_versions FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_help_org_entry_versions trg_help_org_ver_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_help_org_ver_media_c AFTER INSERT ON public.publishing_help_org_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_help_org_entry_versions', 'publishing_help_org_revision_media_usages', 'publishing_help_org_version_media_usages');


--
-- Name: publishing_help_org_entry_versions trg_help_org_ver_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_help_org_ver_snap_c AFTER INSERT ON public.publishing_help_org_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_help_org_entry_versions', 'publishing_help_org_revision_single_taxonomy_assignments', 'publishing_help_org_version_single_taxonomy_assignments', 'publishing_help_org_revision_multiple_taxonomy_assignments', 'publishing_help_org_version_multiple_taxonomy_assignments');


--
-- Name: publishing_help_org_version_multiple_taxonomy_assignments trg_help_org_vm_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_org_vm_imm BEFORE DELETE OR UPDATE ON public.publishing_help_org_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_help_org_version_multiple_taxonomy_assignments trg_help_org_vm_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_org_vm_snap BEFORE INSERT ON public.publishing_help_org_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_help_org_vocabularies', 'publishing_help_org_taxonomy_terms', 'ordered');


--
-- Name: publishing_help_org_version_multiple_taxonomy_assignments trg_help_org_vm_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_help_org_vm_snap_c AFTER INSERT ON public.publishing_help_org_version_multiple_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_help_org_entry_versions', 'publishing_help_org_revision_single_taxonomy_assignments', 'publishing_help_org_version_single_taxonomy_assignments', 'publishing_help_org_revision_multiple_taxonomy_assignments', 'publishing_help_org_version_multiple_taxonomy_assignments');


--
-- Name: publishing_help_org_version_media_usages trg_help_org_vmedia_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_org_vmedia_imm BEFORE DELETE OR UPDATE ON public.publishing_help_org_version_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_help_org_version_media_usages trg_help_org_vmedia_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_help_org_vmedia_media_c AFTER INSERT ON public.publishing_help_org_version_media_usages DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_help_org_entry_versions', 'publishing_help_org_revision_media_usages', 'publishing_help_org_version_media_usages');


--
-- Name: publishing_help_org_vocabularies trg_help_org_voc_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_org_voc_no_delete BEFORE DELETE ON public.publishing_help_org_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_help_org_vocabularies trg_help_org_voc_structure; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_org_voc_structure BEFORE UPDATE ON public.publishing_help_org_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_vocabulary_structure_guard();


--
-- Name: publishing_help_org_version_single_taxonomy_assignments trg_help_org_vs_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_org_vs_imm BEFORE DELETE OR UPDATE ON public.publishing_help_org_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_help_org_version_single_taxonomy_assignments trg_help_org_vs_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_help_org_vs_snap BEFORE INSERT ON public.publishing_help_org_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_help_org_vocabularies', 'publishing_help_org_taxonomy_terms', 'single');


--
-- Name: publishing_help_org_version_single_taxonomy_assignments trg_help_org_vs_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_help_org_vs_snap_c AFTER INSERT ON public.publishing_help_org_version_single_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_help_org_entry_versions', 'publishing_help_org_revision_single_taxonomy_assignments', 'publishing_help_org_version_single_taxonomy_assignments', 'publishing_help_org_revision_multiple_taxonomy_assignments', 'publishing_help_org_version_multiple_taxonomy_assignments');


--
-- Name: publishing_info_app_entry_revisions trg_info_app_rev_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_app_rev_promoted BEFORE DELETE OR UPDATE ON public.publishing_info_app_entry_revisions FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_info_app_entry_versions');


--
-- Name: publishing_info_app_revision_multiple_taxonomy_assignments trg_info_app_rm_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_app_rm_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_info_app_revision_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_info_app_entry_versions');


--
-- Name: publishing_info_app_revision_media_usages trg_info_app_rmedia_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_app_rmedia_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_info_app_revision_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_info_app_entry_versions');


--
-- Name: publishing_info_app_revision_single_taxonomy_assignments trg_info_app_rs_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_app_rs_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_info_app_revision_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_info_app_entry_versions');


--
-- Name: publishing_info_app_taxonomy_terms trg_info_app_term_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_app_term_no_delete BEFORE DELETE ON public.publishing_info_app_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_info_app_taxonomy_terms trg_info_app_terms_hierarchy; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_app_terms_hierarchy BEFORE INSERT OR UPDATE ON public.publishing_info_app_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_taxonomy_term_hierarchy_guard('publishing_info_app_taxonomy_terms');


--
-- Name: publishing_info_app_entry_versions trg_info_app_ver_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_app_ver_imm BEFORE DELETE OR UPDATE ON public.publishing_info_app_entry_versions FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_info_app_entry_versions trg_info_app_ver_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_info_app_ver_media_c AFTER INSERT ON public.publishing_info_app_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_info_app_entry_versions', 'publishing_info_app_revision_media_usages', 'publishing_info_app_version_media_usages');


--
-- Name: publishing_info_app_entry_versions trg_info_app_ver_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_info_app_ver_snap_c AFTER INSERT ON public.publishing_info_app_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_info_app_entry_versions', 'publishing_info_app_revision_single_taxonomy_assignments', 'publishing_info_app_version_single_taxonomy_assignments', 'publishing_info_app_revision_multiple_taxonomy_assignments', 'publishing_info_app_version_multiple_taxonomy_assignments');


--
-- Name: publishing_info_app_version_multiple_taxonomy_assignments trg_info_app_vm_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_app_vm_imm BEFORE DELETE OR UPDATE ON public.publishing_info_app_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_info_app_version_multiple_taxonomy_assignments trg_info_app_vm_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_app_vm_snap BEFORE INSERT ON public.publishing_info_app_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_info_app_vocabularies', 'publishing_info_app_taxonomy_terms', 'ordered');


--
-- Name: publishing_info_app_version_multiple_taxonomy_assignments trg_info_app_vm_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_info_app_vm_snap_c AFTER INSERT ON public.publishing_info_app_version_multiple_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_info_app_entry_versions', 'publishing_info_app_revision_single_taxonomy_assignments', 'publishing_info_app_version_single_taxonomy_assignments', 'publishing_info_app_revision_multiple_taxonomy_assignments', 'publishing_info_app_version_multiple_taxonomy_assignments');


--
-- Name: publishing_info_app_version_media_usages trg_info_app_vmedia_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_app_vmedia_imm BEFORE DELETE OR UPDATE ON public.publishing_info_app_version_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_info_app_version_media_usages trg_info_app_vmedia_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_info_app_vmedia_media_c AFTER INSERT ON public.publishing_info_app_version_media_usages DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_info_app_entry_versions', 'publishing_info_app_revision_media_usages', 'publishing_info_app_version_media_usages');


--
-- Name: publishing_info_app_vocabularies trg_info_app_voc_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_app_voc_no_delete BEFORE DELETE ON public.publishing_info_app_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_info_app_vocabularies trg_info_app_voc_structure; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_app_voc_structure BEFORE UPDATE ON public.publishing_info_app_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_vocabulary_structure_guard();


--
-- Name: publishing_info_app_version_single_taxonomy_assignments trg_info_app_vs_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_app_vs_imm BEFORE DELETE OR UPDATE ON public.publishing_info_app_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_info_app_version_single_taxonomy_assignments trg_info_app_vs_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_app_vs_snap BEFORE INSERT ON public.publishing_info_app_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_info_app_vocabularies', 'publishing_info_app_taxonomy_terms', 'single');


--
-- Name: publishing_info_app_version_single_taxonomy_assignments trg_info_app_vs_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_info_app_vs_snap_c AFTER INSERT ON public.publishing_info_app_version_single_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_info_app_entry_versions', 'publishing_info_app_revision_single_taxonomy_assignments', 'publishing_info_app_version_single_taxonomy_assignments', 'publishing_info_app_revision_multiple_taxonomy_assignments', 'publishing_info_app_version_multiple_taxonomy_assignments');


--
-- Name: publishing_info_com_entry_revisions trg_info_com_rev_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_com_rev_promoted BEFORE DELETE OR UPDATE ON public.publishing_info_com_entry_revisions FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_info_com_entry_versions');


--
-- Name: publishing_info_com_revision_multiple_taxonomy_assignments trg_info_com_rm_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_com_rm_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_info_com_revision_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_info_com_entry_versions');


--
-- Name: publishing_info_com_revision_media_usages trg_info_com_rmedia_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_com_rmedia_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_info_com_revision_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_info_com_entry_versions');


--
-- Name: publishing_info_com_revision_single_taxonomy_assignments trg_info_com_rs_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_com_rs_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_info_com_revision_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_info_com_entry_versions');


--
-- Name: publishing_info_com_taxonomy_terms trg_info_com_term_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_com_term_no_delete BEFORE DELETE ON public.publishing_info_com_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_info_com_taxonomy_terms trg_info_com_terms_hierarchy; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_com_terms_hierarchy BEFORE INSERT OR UPDATE ON public.publishing_info_com_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_taxonomy_term_hierarchy_guard('publishing_info_com_taxonomy_terms');


--
-- Name: publishing_info_com_entry_versions trg_info_com_ver_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_com_ver_imm BEFORE DELETE OR UPDATE ON public.publishing_info_com_entry_versions FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_info_com_entry_versions trg_info_com_ver_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_info_com_ver_media_c AFTER INSERT ON public.publishing_info_com_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_info_com_entry_versions', 'publishing_info_com_revision_media_usages', 'publishing_info_com_version_media_usages');


--
-- Name: publishing_info_com_entry_versions trg_info_com_ver_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_info_com_ver_snap_c AFTER INSERT ON public.publishing_info_com_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_info_com_entry_versions', 'publishing_info_com_revision_single_taxonomy_assignments', 'publishing_info_com_version_single_taxonomy_assignments', 'publishing_info_com_revision_multiple_taxonomy_assignments', 'publishing_info_com_version_multiple_taxonomy_assignments');


--
-- Name: publishing_info_com_version_multiple_taxonomy_assignments trg_info_com_vm_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_com_vm_imm BEFORE DELETE OR UPDATE ON public.publishing_info_com_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_info_com_version_multiple_taxonomy_assignments trg_info_com_vm_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_com_vm_snap BEFORE INSERT ON public.publishing_info_com_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_info_com_vocabularies', 'publishing_info_com_taxonomy_terms', 'ordered');


--
-- Name: publishing_info_com_version_multiple_taxonomy_assignments trg_info_com_vm_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_info_com_vm_snap_c AFTER INSERT ON public.publishing_info_com_version_multiple_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_info_com_entry_versions', 'publishing_info_com_revision_single_taxonomy_assignments', 'publishing_info_com_version_single_taxonomy_assignments', 'publishing_info_com_revision_multiple_taxonomy_assignments', 'publishing_info_com_version_multiple_taxonomy_assignments');


--
-- Name: publishing_info_com_version_media_usages trg_info_com_vmedia_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_com_vmedia_imm BEFORE DELETE OR UPDATE ON public.publishing_info_com_version_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_info_com_version_media_usages trg_info_com_vmedia_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_info_com_vmedia_media_c AFTER INSERT ON public.publishing_info_com_version_media_usages DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_info_com_entry_versions', 'publishing_info_com_revision_media_usages', 'publishing_info_com_version_media_usages');


--
-- Name: publishing_info_com_vocabularies trg_info_com_voc_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_com_voc_no_delete BEFORE DELETE ON public.publishing_info_com_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_info_com_vocabularies trg_info_com_voc_structure; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_com_voc_structure BEFORE UPDATE ON public.publishing_info_com_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_vocabulary_structure_guard();


--
-- Name: publishing_info_com_version_single_taxonomy_assignments trg_info_com_vs_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_com_vs_imm BEFORE DELETE OR UPDATE ON public.publishing_info_com_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_info_com_version_single_taxonomy_assignments trg_info_com_vs_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_com_vs_snap BEFORE INSERT ON public.publishing_info_com_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_info_com_vocabularies', 'publishing_info_com_taxonomy_terms', 'single');


--
-- Name: publishing_info_com_version_single_taxonomy_assignments trg_info_com_vs_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_info_com_vs_snap_c AFTER INSERT ON public.publishing_info_com_version_single_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_info_com_entry_versions', 'publishing_info_com_revision_single_taxonomy_assignments', 'publishing_info_com_version_single_taxonomy_assignments', 'publishing_info_com_revision_multiple_taxonomy_assignments', 'publishing_info_com_version_multiple_taxonomy_assignments');


--
-- Name: publishing_info_org_entry_revisions trg_info_org_rev_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_org_rev_promoted BEFORE DELETE OR UPDATE ON public.publishing_info_org_entry_revisions FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_info_org_entry_versions');


--
-- Name: publishing_info_org_revision_multiple_taxonomy_assignments trg_info_org_rm_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_org_rm_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_info_org_revision_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_info_org_entry_versions');


--
-- Name: publishing_info_org_revision_media_usages trg_info_org_rmedia_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_org_rmedia_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_info_org_revision_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_info_org_entry_versions');


--
-- Name: publishing_info_org_revision_single_taxonomy_assignments trg_info_org_rs_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_org_rs_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_info_org_revision_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_info_org_entry_versions');


--
-- Name: publishing_info_org_taxonomy_terms trg_info_org_term_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_org_term_no_delete BEFORE DELETE ON public.publishing_info_org_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_info_org_taxonomy_terms trg_info_org_terms_hierarchy; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_org_terms_hierarchy BEFORE INSERT OR UPDATE ON public.publishing_info_org_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_taxonomy_term_hierarchy_guard('publishing_info_org_taxonomy_terms');


--
-- Name: publishing_info_org_entry_versions trg_info_org_ver_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_org_ver_imm BEFORE DELETE OR UPDATE ON public.publishing_info_org_entry_versions FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_info_org_entry_versions trg_info_org_ver_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_info_org_ver_media_c AFTER INSERT ON public.publishing_info_org_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_info_org_entry_versions', 'publishing_info_org_revision_media_usages', 'publishing_info_org_version_media_usages');


--
-- Name: publishing_info_org_entry_versions trg_info_org_ver_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_info_org_ver_snap_c AFTER INSERT ON public.publishing_info_org_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_info_org_entry_versions', 'publishing_info_org_revision_single_taxonomy_assignments', 'publishing_info_org_version_single_taxonomy_assignments', 'publishing_info_org_revision_multiple_taxonomy_assignments', 'publishing_info_org_version_multiple_taxonomy_assignments');


--
-- Name: publishing_info_org_version_multiple_taxonomy_assignments trg_info_org_vm_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_org_vm_imm BEFORE DELETE OR UPDATE ON public.publishing_info_org_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_info_org_version_multiple_taxonomy_assignments trg_info_org_vm_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_org_vm_snap BEFORE INSERT ON public.publishing_info_org_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_info_org_vocabularies', 'publishing_info_org_taxonomy_terms', 'ordered');


--
-- Name: publishing_info_org_version_multiple_taxonomy_assignments trg_info_org_vm_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_info_org_vm_snap_c AFTER INSERT ON public.publishing_info_org_version_multiple_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_info_org_entry_versions', 'publishing_info_org_revision_single_taxonomy_assignments', 'publishing_info_org_version_single_taxonomy_assignments', 'publishing_info_org_revision_multiple_taxonomy_assignments', 'publishing_info_org_version_multiple_taxonomy_assignments');


--
-- Name: publishing_info_org_version_media_usages trg_info_org_vmedia_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_org_vmedia_imm BEFORE DELETE OR UPDATE ON public.publishing_info_org_version_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_info_org_version_media_usages trg_info_org_vmedia_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_info_org_vmedia_media_c AFTER INSERT ON public.publishing_info_org_version_media_usages DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_info_org_entry_versions', 'publishing_info_org_revision_media_usages', 'publishing_info_org_version_media_usages');


--
-- Name: publishing_info_org_vocabularies trg_info_org_voc_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_org_voc_no_delete BEFORE DELETE ON public.publishing_info_org_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_info_org_vocabularies trg_info_org_voc_structure; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_org_voc_structure BEFORE UPDATE ON public.publishing_info_org_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_vocabulary_structure_guard();


--
-- Name: publishing_info_org_version_single_taxonomy_assignments trg_info_org_vs_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_org_vs_imm BEFORE DELETE OR UPDATE ON public.publishing_info_org_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_info_org_version_single_taxonomy_assignments trg_info_org_vs_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_info_org_vs_snap BEFORE INSERT ON public.publishing_info_org_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_info_org_vocabularies', 'publishing_info_org_taxonomy_terms', 'single');


--
-- Name: publishing_info_org_version_single_taxonomy_assignments trg_info_org_vs_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_info_org_vs_snap_c AFTER INSERT ON public.publishing_info_org_version_single_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_info_org_entry_versions', 'publishing_info_org_revision_single_taxonomy_assignments', 'publishing_info_org_version_single_taxonomy_assignments', 'publishing_info_org_revision_multiple_taxonomy_assignments', 'publishing_info_org_version_multiple_taxonomy_assignments');


--
-- Name: publishing_news_app_entry_revisions trg_news_app_rev_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_app_rev_promoted BEFORE DELETE OR UPDATE ON public.publishing_news_app_entry_revisions FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_news_app_entry_versions');


--
-- Name: publishing_news_app_revision_multiple_taxonomy_assignments trg_news_app_rm_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_app_rm_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_news_app_revision_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_news_app_entry_versions');


--
-- Name: publishing_news_app_revision_media_usages trg_news_app_rmedia_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_app_rmedia_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_news_app_revision_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_news_app_entry_versions');


--
-- Name: publishing_news_app_revision_single_taxonomy_assignments trg_news_app_rs_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_app_rs_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_news_app_revision_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_news_app_entry_versions');


--
-- Name: publishing_news_app_taxonomy_terms trg_news_app_term_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_app_term_no_delete BEFORE DELETE ON public.publishing_news_app_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_news_app_taxonomy_terms trg_news_app_terms_hierarchy; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_app_terms_hierarchy BEFORE INSERT OR UPDATE ON public.publishing_news_app_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_taxonomy_term_hierarchy_guard('publishing_news_app_taxonomy_terms');


--
-- Name: publishing_news_app_entry_versions trg_news_app_ver_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_app_ver_imm BEFORE DELETE OR UPDATE ON public.publishing_news_app_entry_versions FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_news_app_entry_versions trg_news_app_ver_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_news_app_ver_media_c AFTER INSERT ON public.publishing_news_app_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_news_app_entry_versions', 'publishing_news_app_revision_media_usages', 'publishing_news_app_version_media_usages');


--
-- Name: publishing_news_app_entry_versions trg_news_app_ver_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_news_app_ver_snap_c AFTER INSERT ON public.publishing_news_app_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_news_app_entry_versions', 'publishing_news_app_revision_single_taxonomy_assignments', 'publishing_news_app_version_single_taxonomy_assignments', 'publishing_news_app_revision_multiple_taxonomy_assignments', 'publishing_news_app_version_multiple_taxonomy_assignments');


--
-- Name: publishing_news_app_version_multiple_taxonomy_assignments trg_news_app_vm_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_app_vm_imm BEFORE DELETE OR UPDATE ON public.publishing_news_app_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_news_app_version_multiple_taxonomy_assignments trg_news_app_vm_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_app_vm_snap BEFORE INSERT ON public.publishing_news_app_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_news_app_vocabularies', 'publishing_news_app_taxonomy_terms', 'ordered');


--
-- Name: publishing_news_app_version_multiple_taxonomy_assignments trg_news_app_vm_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_news_app_vm_snap_c AFTER INSERT ON public.publishing_news_app_version_multiple_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_news_app_entry_versions', 'publishing_news_app_revision_single_taxonomy_assignments', 'publishing_news_app_version_single_taxonomy_assignments', 'publishing_news_app_revision_multiple_taxonomy_assignments', 'publishing_news_app_version_multiple_taxonomy_assignments');


--
-- Name: publishing_news_app_version_media_usages trg_news_app_vmedia_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_app_vmedia_imm BEFORE DELETE OR UPDATE ON public.publishing_news_app_version_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_news_app_version_media_usages trg_news_app_vmedia_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_news_app_vmedia_media_c AFTER INSERT ON public.publishing_news_app_version_media_usages DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_news_app_entry_versions', 'publishing_news_app_revision_media_usages', 'publishing_news_app_version_media_usages');


--
-- Name: publishing_news_app_vocabularies trg_news_app_voc_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_app_voc_no_delete BEFORE DELETE ON public.publishing_news_app_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_news_app_vocabularies trg_news_app_voc_structure; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_app_voc_structure BEFORE UPDATE ON public.publishing_news_app_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_vocabulary_structure_guard();


--
-- Name: publishing_news_app_version_single_taxonomy_assignments trg_news_app_vs_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_app_vs_imm BEFORE DELETE OR UPDATE ON public.publishing_news_app_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_news_app_version_single_taxonomy_assignments trg_news_app_vs_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_app_vs_snap BEFORE INSERT ON public.publishing_news_app_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_news_app_vocabularies', 'publishing_news_app_taxonomy_terms', 'single');


--
-- Name: publishing_news_app_version_single_taxonomy_assignments trg_news_app_vs_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_news_app_vs_snap_c AFTER INSERT ON public.publishing_news_app_version_single_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_news_app_entry_versions', 'publishing_news_app_revision_single_taxonomy_assignments', 'publishing_news_app_version_single_taxonomy_assignments', 'publishing_news_app_revision_multiple_taxonomy_assignments', 'publishing_news_app_version_multiple_taxonomy_assignments');


--
-- Name: publishing_news_com_entry_revisions trg_news_com_rev_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_com_rev_promoted BEFORE DELETE OR UPDATE ON public.publishing_news_com_entry_revisions FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_news_com_entry_versions');


--
-- Name: publishing_news_com_revision_multiple_taxonomy_assignments trg_news_com_rm_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_com_rm_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_news_com_revision_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_news_com_entry_versions');


--
-- Name: publishing_news_com_revision_media_usages trg_news_com_rmedia_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_com_rmedia_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_news_com_revision_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_news_com_entry_versions');


--
-- Name: publishing_news_com_revision_single_taxonomy_assignments trg_news_com_rs_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_com_rs_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_news_com_revision_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_news_com_entry_versions');


--
-- Name: publishing_news_com_taxonomy_terms trg_news_com_term_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_com_term_no_delete BEFORE DELETE ON public.publishing_news_com_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_news_com_taxonomy_terms trg_news_com_terms_hierarchy; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_com_terms_hierarchy BEFORE INSERT OR UPDATE ON public.publishing_news_com_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_taxonomy_term_hierarchy_guard('publishing_news_com_taxonomy_terms');


--
-- Name: publishing_news_com_entry_versions trg_news_com_ver_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_com_ver_imm BEFORE DELETE OR UPDATE ON public.publishing_news_com_entry_versions FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_news_com_entry_versions trg_news_com_ver_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_news_com_ver_media_c AFTER INSERT ON public.publishing_news_com_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_news_com_entry_versions', 'publishing_news_com_revision_media_usages', 'publishing_news_com_version_media_usages');


--
-- Name: publishing_news_com_entry_versions trg_news_com_ver_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_news_com_ver_snap_c AFTER INSERT ON public.publishing_news_com_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_news_com_entry_versions', 'publishing_news_com_revision_single_taxonomy_assignments', 'publishing_news_com_version_single_taxonomy_assignments', 'publishing_news_com_revision_multiple_taxonomy_assignments', 'publishing_news_com_version_multiple_taxonomy_assignments');


--
-- Name: publishing_news_com_version_multiple_taxonomy_assignments trg_news_com_vm_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_com_vm_imm BEFORE DELETE OR UPDATE ON public.publishing_news_com_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_news_com_version_multiple_taxonomy_assignments trg_news_com_vm_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_com_vm_snap BEFORE INSERT ON public.publishing_news_com_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_news_com_vocabularies', 'publishing_news_com_taxonomy_terms', 'ordered');


--
-- Name: publishing_news_com_version_multiple_taxonomy_assignments trg_news_com_vm_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_news_com_vm_snap_c AFTER INSERT ON public.publishing_news_com_version_multiple_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_news_com_entry_versions', 'publishing_news_com_revision_single_taxonomy_assignments', 'publishing_news_com_version_single_taxonomy_assignments', 'publishing_news_com_revision_multiple_taxonomy_assignments', 'publishing_news_com_version_multiple_taxonomy_assignments');


--
-- Name: publishing_news_com_version_media_usages trg_news_com_vmedia_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_com_vmedia_imm BEFORE DELETE OR UPDATE ON public.publishing_news_com_version_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_news_com_version_media_usages trg_news_com_vmedia_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_news_com_vmedia_media_c AFTER INSERT ON public.publishing_news_com_version_media_usages DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_news_com_entry_versions', 'publishing_news_com_revision_media_usages', 'publishing_news_com_version_media_usages');


--
-- Name: publishing_news_com_vocabularies trg_news_com_voc_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_com_voc_no_delete BEFORE DELETE ON public.publishing_news_com_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_news_com_vocabularies trg_news_com_voc_structure; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_com_voc_structure BEFORE UPDATE ON public.publishing_news_com_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_vocabulary_structure_guard();


--
-- Name: publishing_news_com_version_single_taxonomy_assignments trg_news_com_vs_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_com_vs_imm BEFORE DELETE OR UPDATE ON public.publishing_news_com_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_news_com_version_single_taxonomy_assignments trg_news_com_vs_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_com_vs_snap BEFORE INSERT ON public.publishing_news_com_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_news_com_vocabularies', 'publishing_news_com_taxonomy_terms', 'single');


--
-- Name: publishing_news_com_version_single_taxonomy_assignments trg_news_com_vs_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_news_com_vs_snap_c AFTER INSERT ON public.publishing_news_com_version_single_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_news_com_entry_versions', 'publishing_news_com_revision_single_taxonomy_assignments', 'publishing_news_com_version_single_taxonomy_assignments', 'publishing_news_com_revision_multiple_taxonomy_assignments', 'publishing_news_com_version_multiple_taxonomy_assignments');


--
-- Name: publishing_news_org_entry_revisions trg_news_org_rev_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_org_rev_promoted BEFORE DELETE OR UPDATE ON public.publishing_news_org_entry_revisions FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_news_org_entry_versions');


--
-- Name: publishing_news_org_revision_multiple_taxonomy_assignments trg_news_org_rm_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_org_rm_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_news_org_revision_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_news_org_entry_versions');


--
-- Name: publishing_news_org_revision_media_usages trg_news_org_rmedia_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_org_rmedia_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_news_org_revision_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_news_org_entry_versions');


--
-- Name: publishing_news_org_revision_single_taxonomy_assignments trg_news_org_rs_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_org_rs_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_news_org_revision_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard('publishing_news_org_entry_versions');


--
-- Name: publishing_news_org_taxonomy_terms trg_news_org_term_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_org_term_no_delete BEFORE DELETE ON public.publishing_news_org_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_news_org_taxonomy_terms trg_news_org_terms_hierarchy; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_org_terms_hierarchy BEFORE INSERT OR UPDATE ON public.publishing_news_org_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_taxonomy_term_hierarchy_guard('publishing_news_org_taxonomy_terms');


--
-- Name: publishing_news_org_entry_versions trg_news_org_ver_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_org_ver_imm BEFORE DELETE OR UPDATE ON public.publishing_news_org_entry_versions FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_news_org_entry_versions trg_news_org_ver_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_news_org_ver_media_c AFTER INSERT ON public.publishing_news_org_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_news_org_entry_versions', 'publishing_news_org_revision_media_usages', 'publishing_news_org_version_media_usages');


--
-- Name: publishing_news_org_entry_versions trg_news_org_ver_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_news_org_ver_snap_c AFTER INSERT ON public.publishing_news_org_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_news_org_entry_versions', 'publishing_news_org_revision_single_taxonomy_assignments', 'publishing_news_org_version_single_taxonomy_assignments', 'publishing_news_org_revision_multiple_taxonomy_assignments', 'publishing_news_org_version_multiple_taxonomy_assignments');


--
-- Name: publishing_news_org_version_multiple_taxonomy_assignments trg_news_org_vm_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_org_vm_imm BEFORE DELETE OR UPDATE ON public.publishing_news_org_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_news_org_version_multiple_taxonomy_assignments trg_news_org_vm_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_org_vm_snap BEFORE INSERT ON public.publishing_news_org_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_news_org_vocabularies', 'publishing_news_org_taxonomy_terms', 'ordered');


--
-- Name: publishing_news_org_version_multiple_taxonomy_assignments trg_news_org_vm_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_news_org_vm_snap_c AFTER INSERT ON public.publishing_news_org_version_multiple_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_news_org_entry_versions', 'publishing_news_org_revision_single_taxonomy_assignments', 'publishing_news_org_version_single_taxonomy_assignments', 'publishing_news_org_revision_multiple_taxonomy_assignments', 'publishing_news_org_version_multiple_taxonomy_assignments');


--
-- Name: publishing_news_org_version_media_usages trg_news_org_vmedia_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_org_vmedia_imm BEFORE DELETE OR UPDATE ON public.publishing_news_org_version_media_usages FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_news_org_version_media_usages trg_news_org_vmedia_media_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_news_org_vmedia_media_c AFTER INSERT ON public.publishing_news_org_version_media_usages DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_media_complete('publishing_news_org_entry_versions', 'publishing_news_org_revision_media_usages', 'publishing_news_org_version_media_usages');


--
-- Name: publishing_news_org_vocabularies trg_news_org_voc_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_org_voc_no_delete BEFORE DELETE ON public.publishing_news_org_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_news_org_vocabularies trg_news_org_voc_structure; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_org_voc_structure BEFORE UPDATE ON public.publishing_news_org_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_vocabulary_structure_guard();


--
-- Name: publishing_news_org_version_single_taxonomy_assignments trg_news_org_vs_imm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_org_vs_imm BEFORE DELETE OR UPDATE ON public.publishing_news_org_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_news_org_version_single_taxonomy_assignments trg_news_org_vs_snap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_org_vs_snap BEFORE INSERT ON public.publishing_news_org_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_assignment_snapshot('publishing_news_org_vocabularies', 'publishing_news_org_taxonomy_terms', 'single');


--
-- Name: publishing_news_org_version_single_taxonomy_assignments trg_news_org_vs_snap_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_news_org_vs_snap_c AFTER INSERT ON public.publishing_news_org_version_single_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete('publishing_news_org_entry_versions', 'publishing_news_org_revision_single_taxonomy_assignments', 'publishing_news_org_version_single_taxonomy_assignments', 'publishing_news_org_revision_multiple_taxonomy_assignments', 'publishing_news_org_version_multiple_taxonomy_assignments');


--
-- Name: publishing_docs_app_entries fk_docs_app_ent_current_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_entries
    ADD CONSTRAINT fk_docs_app_ent_current_rev FOREIGN KEY (current_revision_id, id) REFERENCES public.publishing_docs_app_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_publications fk_docs_app_pub_version_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_publications
    ADD CONSTRAINT fk_docs_app_pub_version_entry FOREIGN KEY (entry_version_id, entry_id) REFERENCES public.publishing_docs_app_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_entry_revisions fk_docs_app_rev_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_entry_revisions
    ADD CONSTRAINT fk_docs_app_rev_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_docs_app_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_entry_revisions fk_docs_app_rev_restore_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_entry_revisions
    ADD CONSTRAINT fk_docs_app_rev_restore_rev FOREIGN KEY (restored_from_revision_id, entry_id) REFERENCES public.publishing_docs_app_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_entry_revisions fk_docs_app_rev_restore_ver; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_entry_revisions
    ADD CONSTRAINT fk_docs_app_rev_restore_ver FOREIGN KEY (restored_from_version_id, entry_id) REFERENCES public.publishing_docs_app_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_revision_multiple_taxonomy_assignments fk_docs_app_rm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_docs_app_rm_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_docs_app_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_revision_multiple_taxonomy_assignments fk_docs_app_rm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_docs_app_rm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_docs_app_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_revision_multiple_taxonomy_assignments fk_docs_app_rm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_docs_app_rm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_docs_app_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_revision_single_taxonomy_assignments fk_docs_app_rs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_docs_app_rs_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_docs_app_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_revision_single_taxonomy_assignments fk_docs_app_rs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_docs_app_rs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_docs_app_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_revision_single_taxonomy_assignments fk_docs_app_rs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_docs_app_rs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_docs_app_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_entry_slugs fk_docs_app_slug_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_entry_slugs
    ADD CONSTRAINT fk_docs_app_slug_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_docs_app_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_taxonomy_terms fk_docs_app_term_parent_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_taxonomy_terms
    ADD CONSTRAINT fk_docs_app_term_parent_scope FOREIGN KEY (parent_id, vocabulary_id, locale) REFERENCES public.publishing_docs_app_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_taxonomy_terms fk_docs_app_term_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_taxonomy_terms
    ADD CONSTRAINT fk_docs_app_term_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_docs_app_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_entry_versions fk_docs_app_ver_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_entry_versions
    ADD CONSTRAINT fk_docs_app_ver_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_docs_app_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_entry_versions fk_docs_app_ver_revision_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_entry_versions
    ADD CONSTRAINT fk_docs_app_ver_revision_entry FOREIGN KEY (entry_revision_id, entry_id) REFERENCES public.publishing_docs_app_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_version_multiple_taxonomy_assignments fk_docs_app_vm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_docs_app_vm_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_docs_app_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_version_multiple_taxonomy_assignments fk_docs_app_vm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_docs_app_vm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_docs_app_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_version_multiple_taxonomy_assignments fk_docs_app_vm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_docs_app_vm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_docs_app_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_version_single_taxonomy_assignments fk_docs_app_vs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_docs_app_vs_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_docs_app_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_version_single_taxonomy_assignments fk_docs_app_vs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_docs_app_vs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_docs_app_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_version_single_taxonomy_assignments fk_docs_app_vs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_docs_app_vs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_docs_app_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_entries fk_docs_com_ent_current_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_entries
    ADD CONSTRAINT fk_docs_com_ent_current_rev FOREIGN KEY (current_revision_id, id) REFERENCES public.publishing_docs_com_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_publications fk_docs_com_pub_version_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_publications
    ADD CONSTRAINT fk_docs_com_pub_version_entry FOREIGN KEY (entry_version_id, entry_id) REFERENCES public.publishing_docs_com_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_entry_revisions fk_docs_com_rev_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_entry_revisions
    ADD CONSTRAINT fk_docs_com_rev_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_docs_com_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_entry_revisions fk_docs_com_rev_restore_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_entry_revisions
    ADD CONSTRAINT fk_docs_com_rev_restore_rev FOREIGN KEY (restored_from_revision_id, entry_id) REFERENCES public.publishing_docs_com_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_entry_revisions fk_docs_com_rev_restore_ver; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_entry_revisions
    ADD CONSTRAINT fk_docs_com_rev_restore_ver FOREIGN KEY (restored_from_version_id, entry_id) REFERENCES public.publishing_docs_com_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_revision_multiple_taxonomy_assignments fk_docs_com_rm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_docs_com_rm_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_docs_com_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_revision_multiple_taxonomy_assignments fk_docs_com_rm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_docs_com_rm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_docs_com_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_revision_multiple_taxonomy_assignments fk_docs_com_rm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_docs_com_rm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_docs_com_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_revision_single_taxonomy_assignments fk_docs_com_rs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_docs_com_rs_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_docs_com_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_revision_single_taxonomy_assignments fk_docs_com_rs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_docs_com_rs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_docs_com_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_revision_single_taxonomy_assignments fk_docs_com_rs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_docs_com_rs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_docs_com_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_entry_slugs fk_docs_com_slug_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_entry_slugs
    ADD CONSTRAINT fk_docs_com_slug_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_docs_com_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_taxonomy_terms fk_docs_com_term_parent_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_taxonomy_terms
    ADD CONSTRAINT fk_docs_com_term_parent_scope FOREIGN KEY (parent_id, vocabulary_id, locale) REFERENCES public.publishing_docs_com_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_taxonomy_terms fk_docs_com_term_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_taxonomy_terms
    ADD CONSTRAINT fk_docs_com_term_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_docs_com_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_entry_versions fk_docs_com_ver_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_entry_versions
    ADD CONSTRAINT fk_docs_com_ver_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_docs_com_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_entry_versions fk_docs_com_ver_revision_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_entry_versions
    ADD CONSTRAINT fk_docs_com_ver_revision_entry FOREIGN KEY (entry_revision_id, entry_id) REFERENCES public.publishing_docs_com_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_version_multiple_taxonomy_assignments fk_docs_com_vm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_docs_com_vm_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_docs_com_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_version_multiple_taxonomy_assignments fk_docs_com_vm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_docs_com_vm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_docs_com_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_version_multiple_taxonomy_assignments fk_docs_com_vm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_docs_com_vm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_docs_com_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_version_single_taxonomy_assignments fk_docs_com_vs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_docs_com_vs_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_docs_com_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_version_single_taxonomy_assignments fk_docs_com_vs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_docs_com_vs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_docs_com_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_version_single_taxonomy_assignments fk_docs_com_vs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_docs_com_vs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_docs_com_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_entries fk_docs_org_ent_current_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_entries
    ADD CONSTRAINT fk_docs_org_ent_current_rev FOREIGN KEY (current_revision_id, id) REFERENCES public.publishing_docs_org_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_publications fk_docs_org_pub_version_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_publications
    ADD CONSTRAINT fk_docs_org_pub_version_entry FOREIGN KEY (entry_version_id, entry_id) REFERENCES public.publishing_docs_org_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_entry_revisions fk_docs_org_rev_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_entry_revisions
    ADD CONSTRAINT fk_docs_org_rev_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_docs_org_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_entry_revisions fk_docs_org_rev_restore_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_entry_revisions
    ADD CONSTRAINT fk_docs_org_rev_restore_rev FOREIGN KEY (restored_from_revision_id, entry_id) REFERENCES public.publishing_docs_org_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_entry_revisions fk_docs_org_rev_restore_ver; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_entry_revisions
    ADD CONSTRAINT fk_docs_org_rev_restore_ver FOREIGN KEY (restored_from_version_id, entry_id) REFERENCES public.publishing_docs_org_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_revision_multiple_taxonomy_assignments fk_docs_org_rm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_docs_org_rm_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_docs_org_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_revision_multiple_taxonomy_assignments fk_docs_org_rm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_docs_org_rm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_docs_org_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_revision_multiple_taxonomy_assignments fk_docs_org_rm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_docs_org_rm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_docs_org_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_revision_single_taxonomy_assignments fk_docs_org_rs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_docs_org_rs_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_docs_org_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_revision_single_taxonomy_assignments fk_docs_org_rs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_docs_org_rs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_docs_org_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_revision_single_taxonomy_assignments fk_docs_org_rs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_docs_org_rs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_docs_org_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_entry_slugs fk_docs_org_slug_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_entry_slugs
    ADD CONSTRAINT fk_docs_org_slug_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_docs_org_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_taxonomy_terms fk_docs_org_term_parent_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_taxonomy_terms
    ADD CONSTRAINT fk_docs_org_term_parent_scope FOREIGN KEY (parent_id, vocabulary_id, locale) REFERENCES public.publishing_docs_org_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_taxonomy_terms fk_docs_org_term_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_taxonomy_terms
    ADD CONSTRAINT fk_docs_org_term_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_docs_org_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_entry_versions fk_docs_org_ver_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_entry_versions
    ADD CONSTRAINT fk_docs_org_ver_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_docs_org_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_entry_versions fk_docs_org_ver_revision_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_entry_versions
    ADD CONSTRAINT fk_docs_org_ver_revision_entry FOREIGN KEY (entry_revision_id, entry_id) REFERENCES public.publishing_docs_org_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_version_multiple_taxonomy_assignments fk_docs_org_vm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_docs_org_vm_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_docs_org_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_version_multiple_taxonomy_assignments fk_docs_org_vm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_docs_org_vm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_docs_org_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_version_multiple_taxonomy_assignments fk_docs_org_vm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_docs_org_vm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_docs_org_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_version_single_taxonomy_assignments fk_docs_org_vs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_docs_org_vs_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_docs_org_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_version_single_taxonomy_assignments fk_docs_org_vs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_docs_org_vs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_docs_org_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_version_single_taxonomy_assignments fk_docs_org_vs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_docs_org_vs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_docs_org_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_entries fk_help_app_ent_current_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_entries
    ADD CONSTRAINT fk_help_app_ent_current_rev FOREIGN KEY (current_revision_id, id) REFERENCES public.publishing_help_app_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_publications fk_help_app_pub_version_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_publications
    ADD CONSTRAINT fk_help_app_pub_version_entry FOREIGN KEY (entry_version_id, entry_id) REFERENCES public.publishing_help_app_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_entry_revisions fk_help_app_rev_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_entry_revisions
    ADD CONSTRAINT fk_help_app_rev_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_help_app_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_entry_revisions fk_help_app_rev_restore_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_entry_revisions
    ADD CONSTRAINT fk_help_app_rev_restore_rev FOREIGN KEY (restored_from_revision_id, entry_id) REFERENCES public.publishing_help_app_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_entry_revisions fk_help_app_rev_restore_ver; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_entry_revisions
    ADD CONSTRAINT fk_help_app_rev_restore_ver FOREIGN KEY (restored_from_version_id, entry_id) REFERENCES public.publishing_help_app_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_revision_multiple_taxonomy_assignments fk_help_app_rm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_help_app_rm_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_help_app_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_revision_multiple_taxonomy_assignments fk_help_app_rm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_help_app_rm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_help_app_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_revision_multiple_taxonomy_assignments fk_help_app_rm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_help_app_rm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_help_app_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_revision_single_taxonomy_assignments fk_help_app_rs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_help_app_rs_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_help_app_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_revision_single_taxonomy_assignments fk_help_app_rs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_help_app_rs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_help_app_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_revision_single_taxonomy_assignments fk_help_app_rs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_help_app_rs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_help_app_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_entry_slugs fk_help_app_slug_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_entry_slugs
    ADD CONSTRAINT fk_help_app_slug_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_help_app_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_taxonomy_terms fk_help_app_term_parent_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_taxonomy_terms
    ADD CONSTRAINT fk_help_app_term_parent_scope FOREIGN KEY (parent_id, vocabulary_id, locale) REFERENCES public.publishing_help_app_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_taxonomy_terms fk_help_app_term_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_taxonomy_terms
    ADD CONSTRAINT fk_help_app_term_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_help_app_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_entry_versions fk_help_app_ver_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_entry_versions
    ADD CONSTRAINT fk_help_app_ver_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_help_app_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_entry_versions fk_help_app_ver_revision_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_entry_versions
    ADD CONSTRAINT fk_help_app_ver_revision_entry FOREIGN KEY (entry_revision_id, entry_id) REFERENCES public.publishing_help_app_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_version_multiple_taxonomy_assignments fk_help_app_vm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_help_app_vm_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_help_app_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_version_multiple_taxonomy_assignments fk_help_app_vm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_help_app_vm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_help_app_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_version_multiple_taxonomy_assignments fk_help_app_vm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_help_app_vm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_help_app_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_version_single_taxonomy_assignments fk_help_app_vs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_help_app_vs_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_help_app_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_version_single_taxonomy_assignments fk_help_app_vs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_help_app_vs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_help_app_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_version_single_taxonomy_assignments fk_help_app_vs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_help_app_vs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_help_app_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_entries fk_help_com_ent_current_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_entries
    ADD CONSTRAINT fk_help_com_ent_current_rev FOREIGN KEY (current_revision_id, id) REFERENCES public.publishing_help_com_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_publications fk_help_com_pub_version_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_publications
    ADD CONSTRAINT fk_help_com_pub_version_entry FOREIGN KEY (entry_version_id, entry_id) REFERENCES public.publishing_help_com_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_entry_revisions fk_help_com_rev_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_entry_revisions
    ADD CONSTRAINT fk_help_com_rev_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_help_com_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_entry_revisions fk_help_com_rev_restore_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_entry_revisions
    ADD CONSTRAINT fk_help_com_rev_restore_rev FOREIGN KEY (restored_from_revision_id, entry_id) REFERENCES public.publishing_help_com_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_entry_revisions fk_help_com_rev_restore_ver; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_entry_revisions
    ADD CONSTRAINT fk_help_com_rev_restore_ver FOREIGN KEY (restored_from_version_id, entry_id) REFERENCES public.publishing_help_com_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_revision_multiple_taxonomy_assignments fk_help_com_rm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_help_com_rm_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_help_com_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_revision_multiple_taxonomy_assignments fk_help_com_rm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_help_com_rm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_help_com_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_revision_multiple_taxonomy_assignments fk_help_com_rm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_help_com_rm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_help_com_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_revision_single_taxonomy_assignments fk_help_com_rs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_help_com_rs_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_help_com_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_revision_single_taxonomy_assignments fk_help_com_rs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_help_com_rs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_help_com_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_revision_single_taxonomy_assignments fk_help_com_rs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_help_com_rs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_help_com_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_entry_slugs fk_help_com_slug_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_entry_slugs
    ADD CONSTRAINT fk_help_com_slug_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_help_com_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_taxonomy_terms fk_help_com_term_parent_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_taxonomy_terms
    ADD CONSTRAINT fk_help_com_term_parent_scope FOREIGN KEY (parent_id, vocabulary_id, locale) REFERENCES public.publishing_help_com_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_taxonomy_terms fk_help_com_term_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_taxonomy_terms
    ADD CONSTRAINT fk_help_com_term_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_help_com_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_entry_versions fk_help_com_ver_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_entry_versions
    ADD CONSTRAINT fk_help_com_ver_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_help_com_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_entry_versions fk_help_com_ver_revision_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_entry_versions
    ADD CONSTRAINT fk_help_com_ver_revision_entry FOREIGN KEY (entry_revision_id, entry_id) REFERENCES public.publishing_help_com_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_version_multiple_taxonomy_assignments fk_help_com_vm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_help_com_vm_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_help_com_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_version_multiple_taxonomy_assignments fk_help_com_vm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_help_com_vm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_help_com_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_version_multiple_taxonomy_assignments fk_help_com_vm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_help_com_vm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_help_com_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_version_single_taxonomy_assignments fk_help_com_vs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_help_com_vs_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_help_com_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_version_single_taxonomy_assignments fk_help_com_vs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_help_com_vs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_help_com_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_version_single_taxonomy_assignments fk_help_com_vs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_help_com_vs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_help_com_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_entries fk_help_org_ent_current_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_entries
    ADD CONSTRAINT fk_help_org_ent_current_rev FOREIGN KEY (current_revision_id, id) REFERENCES public.publishing_help_org_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_publications fk_help_org_pub_version_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_publications
    ADD CONSTRAINT fk_help_org_pub_version_entry FOREIGN KEY (entry_version_id, entry_id) REFERENCES public.publishing_help_org_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_entry_revisions fk_help_org_rev_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_entry_revisions
    ADD CONSTRAINT fk_help_org_rev_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_help_org_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_entry_revisions fk_help_org_rev_restore_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_entry_revisions
    ADD CONSTRAINT fk_help_org_rev_restore_rev FOREIGN KEY (restored_from_revision_id, entry_id) REFERENCES public.publishing_help_org_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_entry_revisions fk_help_org_rev_restore_ver; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_entry_revisions
    ADD CONSTRAINT fk_help_org_rev_restore_ver FOREIGN KEY (restored_from_version_id, entry_id) REFERENCES public.publishing_help_org_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_revision_multiple_taxonomy_assignments fk_help_org_rm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_help_org_rm_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_help_org_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_revision_multiple_taxonomy_assignments fk_help_org_rm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_help_org_rm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_help_org_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_revision_multiple_taxonomy_assignments fk_help_org_rm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_help_org_rm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_help_org_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_revision_single_taxonomy_assignments fk_help_org_rs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_help_org_rs_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_help_org_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_revision_single_taxonomy_assignments fk_help_org_rs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_help_org_rs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_help_org_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_revision_single_taxonomy_assignments fk_help_org_rs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_help_org_rs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_help_org_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_entry_slugs fk_help_org_slug_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_entry_slugs
    ADD CONSTRAINT fk_help_org_slug_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_help_org_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_taxonomy_terms fk_help_org_term_parent_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_taxonomy_terms
    ADD CONSTRAINT fk_help_org_term_parent_scope FOREIGN KEY (parent_id, vocabulary_id, locale) REFERENCES public.publishing_help_org_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_taxonomy_terms fk_help_org_term_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_taxonomy_terms
    ADD CONSTRAINT fk_help_org_term_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_help_org_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_entry_versions fk_help_org_ver_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_entry_versions
    ADD CONSTRAINT fk_help_org_ver_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_help_org_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_entry_versions fk_help_org_ver_revision_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_entry_versions
    ADD CONSTRAINT fk_help_org_ver_revision_entry FOREIGN KEY (entry_revision_id, entry_id) REFERENCES public.publishing_help_org_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_version_multiple_taxonomy_assignments fk_help_org_vm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_help_org_vm_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_help_org_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_version_multiple_taxonomy_assignments fk_help_org_vm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_help_org_vm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_help_org_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_version_multiple_taxonomy_assignments fk_help_org_vm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_help_org_vm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_help_org_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_version_single_taxonomy_assignments fk_help_org_vs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_help_org_vs_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_help_org_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_version_single_taxonomy_assignments fk_help_org_vs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_help_org_vs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_help_org_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_version_single_taxonomy_assignments fk_help_org_vs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_help_org_vs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_help_org_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_entries fk_info_app_ent_current_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_entries
    ADD CONSTRAINT fk_info_app_ent_current_rev FOREIGN KEY (current_revision_id, id) REFERENCES public.publishing_info_app_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_publications fk_info_app_pub_version_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_publications
    ADD CONSTRAINT fk_info_app_pub_version_entry FOREIGN KEY (entry_version_id, entry_id) REFERENCES public.publishing_info_app_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_entry_revisions fk_info_app_rev_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_entry_revisions
    ADD CONSTRAINT fk_info_app_rev_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_info_app_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_entry_revisions fk_info_app_rev_restore_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_entry_revisions
    ADD CONSTRAINT fk_info_app_rev_restore_rev FOREIGN KEY (restored_from_revision_id, entry_id) REFERENCES public.publishing_info_app_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_entry_revisions fk_info_app_rev_restore_ver; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_entry_revisions
    ADD CONSTRAINT fk_info_app_rev_restore_ver FOREIGN KEY (restored_from_version_id, entry_id) REFERENCES public.publishing_info_app_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_revision_multiple_taxonomy_assignments fk_info_app_rm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_info_app_rm_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_info_app_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_revision_multiple_taxonomy_assignments fk_info_app_rm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_info_app_rm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_info_app_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_revision_multiple_taxonomy_assignments fk_info_app_rm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_info_app_rm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_info_app_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_revision_single_taxonomy_assignments fk_info_app_rs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_info_app_rs_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_info_app_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_revision_single_taxonomy_assignments fk_info_app_rs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_info_app_rs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_info_app_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_revision_single_taxonomy_assignments fk_info_app_rs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_info_app_rs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_info_app_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_entry_slugs fk_info_app_slug_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_entry_slugs
    ADD CONSTRAINT fk_info_app_slug_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_info_app_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_taxonomy_terms fk_info_app_term_parent_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_taxonomy_terms
    ADD CONSTRAINT fk_info_app_term_parent_scope FOREIGN KEY (parent_id, vocabulary_id, locale) REFERENCES public.publishing_info_app_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_taxonomy_terms fk_info_app_term_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_taxonomy_terms
    ADD CONSTRAINT fk_info_app_term_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_info_app_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_entry_versions fk_info_app_ver_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_entry_versions
    ADD CONSTRAINT fk_info_app_ver_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_info_app_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_entry_versions fk_info_app_ver_revision_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_entry_versions
    ADD CONSTRAINT fk_info_app_ver_revision_entry FOREIGN KEY (entry_revision_id, entry_id) REFERENCES public.publishing_info_app_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_version_multiple_taxonomy_assignments fk_info_app_vm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_info_app_vm_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_info_app_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_version_multiple_taxonomy_assignments fk_info_app_vm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_info_app_vm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_info_app_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_version_multiple_taxonomy_assignments fk_info_app_vm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_info_app_vm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_info_app_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_version_single_taxonomy_assignments fk_info_app_vs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_info_app_vs_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_info_app_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_version_single_taxonomy_assignments fk_info_app_vs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_info_app_vs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_info_app_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_version_single_taxonomy_assignments fk_info_app_vs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_info_app_vs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_info_app_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_entries fk_info_com_ent_current_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_entries
    ADD CONSTRAINT fk_info_com_ent_current_rev FOREIGN KEY (current_revision_id, id) REFERENCES public.publishing_info_com_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_publications fk_info_com_pub_version_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_publications
    ADD CONSTRAINT fk_info_com_pub_version_entry FOREIGN KEY (entry_version_id, entry_id) REFERENCES public.publishing_info_com_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_entry_revisions fk_info_com_rev_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_entry_revisions
    ADD CONSTRAINT fk_info_com_rev_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_info_com_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_entry_revisions fk_info_com_rev_restore_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_entry_revisions
    ADD CONSTRAINT fk_info_com_rev_restore_rev FOREIGN KEY (restored_from_revision_id, entry_id) REFERENCES public.publishing_info_com_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_entry_revisions fk_info_com_rev_restore_ver; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_entry_revisions
    ADD CONSTRAINT fk_info_com_rev_restore_ver FOREIGN KEY (restored_from_version_id, entry_id) REFERENCES public.publishing_info_com_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_revision_multiple_taxonomy_assignments fk_info_com_rm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_info_com_rm_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_info_com_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_revision_multiple_taxonomy_assignments fk_info_com_rm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_info_com_rm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_info_com_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_revision_multiple_taxonomy_assignments fk_info_com_rm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_info_com_rm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_info_com_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_revision_single_taxonomy_assignments fk_info_com_rs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_info_com_rs_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_info_com_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_revision_single_taxonomy_assignments fk_info_com_rs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_info_com_rs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_info_com_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_revision_single_taxonomy_assignments fk_info_com_rs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_info_com_rs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_info_com_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_entry_slugs fk_info_com_slug_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_entry_slugs
    ADD CONSTRAINT fk_info_com_slug_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_info_com_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_taxonomy_terms fk_info_com_term_parent_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_taxonomy_terms
    ADD CONSTRAINT fk_info_com_term_parent_scope FOREIGN KEY (parent_id, vocabulary_id, locale) REFERENCES public.publishing_info_com_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_taxonomy_terms fk_info_com_term_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_taxonomy_terms
    ADD CONSTRAINT fk_info_com_term_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_info_com_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_entry_versions fk_info_com_ver_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_entry_versions
    ADD CONSTRAINT fk_info_com_ver_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_info_com_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_entry_versions fk_info_com_ver_revision_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_entry_versions
    ADD CONSTRAINT fk_info_com_ver_revision_entry FOREIGN KEY (entry_revision_id, entry_id) REFERENCES public.publishing_info_com_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_version_multiple_taxonomy_assignments fk_info_com_vm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_info_com_vm_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_info_com_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_version_multiple_taxonomy_assignments fk_info_com_vm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_info_com_vm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_info_com_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_version_multiple_taxonomy_assignments fk_info_com_vm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_info_com_vm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_info_com_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_version_single_taxonomy_assignments fk_info_com_vs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_info_com_vs_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_info_com_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_version_single_taxonomy_assignments fk_info_com_vs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_info_com_vs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_info_com_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_version_single_taxonomy_assignments fk_info_com_vs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_info_com_vs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_info_com_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_entries fk_info_org_ent_current_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_entries
    ADD CONSTRAINT fk_info_org_ent_current_rev FOREIGN KEY (current_revision_id, id) REFERENCES public.publishing_info_org_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_publications fk_info_org_pub_version_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_publications
    ADD CONSTRAINT fk_info_org_pub_version_entry FOREIGN KEY (entry_version_id, entry_id) REFERENCES public.publishing_info_org_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_entry_revisions fk_info_org_rev_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_entry_revisions
    ADD CONSTRAINT fk_info_org_rev_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_info_org_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_entry_revisions fk_info_org_rev_restore_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_entry_revisions
    ADD CONSTRAINT fk_info_org_rev_restore_rev FOREIGN KEY (restored_from_revision_id, entry_id) REFERENCES public.publishing_info_org_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_entry_revisions fk_info_org_rev_restore_ver; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_entry_revisions
    ADD CONSTRAINT fk_info_org_rev_restore_ver FOREIGN KEY (restored_from_version_id, entry_id) REFERENCES public.publishing_info_org_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_revision_multiple_taxonomy_assignments fk_info_org_rm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_info_org_rm_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_info_org_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_revision_multiple_taxonomy_assignments fk_info_org_rm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_info_org_rm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_info_org_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_revision_multiple_taxonomy_assignments fk_info_org_rm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_info_org_rm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_info_org_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_revision_single_taxonomy_assignments fk_info_org_rs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_info_org_rs_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_info_org_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_revision_single_taxonomy_assignments fk_info_org_rs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_info_org_rs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_info_org_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_revision_single_taxonomy_assignments fk_info_org_rs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_info_org_rs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_info_org_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_entry_slugs fk_info_org_slug_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_entry_slugs
    ADD CONSTRAINT fk_info_org_slug_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_info_org_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_taxonomy_terms fk_info_org_term_parent_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_taxonomy_terms
    ADD CONSTRAINT fk_info_org_term_parent_scope FOREIGN KEY (parent_id, vocabulary_id, locale) REFERENCES public.publishing_info_org_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_taxonomy_terms fk_info_org_term_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_taxonomy_terms
    ADD CONSTRAINT fk_info_org_term_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_info_org_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_entry_versions fk_info_org_ver_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_entry_versions
    ADD CONSTRAINT fk_info_org_ver_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_info_org_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_entry_versions fk_info_org_ver_revision_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_entry_versions
    ADD CONSTRAINT fk_info_org_ver_revision_entry FOREIGN KEY (entry_revision_id, entry_id) REFERENCES public.publishing_info_org_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_version_multiple_taxonomy_assignments fk_info_org_vm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_info_org_vm_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_info_org_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_version_multiple_taxonomy_assignments fk_info_org_vm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_info_org_vm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_info_org_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_version_multiple_taxonomy_assignments fk_info_org_vm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_info_org_vm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_info_org_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_version_single_taxonomy_assignments fk_info_org_vs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_info_org_vs_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_info_org_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_version_single_taxonomy_assignments fk_info_org_vs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_info_org_vs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_info_org_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_version_single_taxonomy_assignments fk_info_org_vs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_info_org_vs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_info_org_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_entries fk_news_app_ent_current_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_entries
    ADD CONSTRAINT fk_news_app_ent_current_rev FOREIGN KEY (current_revision_id, id) REFERENCES public.publishing_news_app_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_publications fk_news_app_pub_version_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_publications
    ADD CONSTRAINT fk_news_app_pub_version_entry FOREIGN KEY (entry_version_id, entry_id) REFERENCES public.publishing_news_app_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_entry_revisions fk_news_app_rev_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_entry_revisions
    ADD CONSTRAINT fk_news_app_rev_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_news_app_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_entry_revisions fk_news_app_rev_restore_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_entry_revisions
    ADD CONSTRAINT fk_news_app_rev_restore_rev FOREIGN KEY (restored_from_revision_id, entry_id) REFERENCES public.publishing_news_app_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_entry_revisions fk_news_app_rev_restore_ver; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_entry_revisions
    ADD CONSTRAINT fk_news_app_rev_restore_ver FOREIGN KEY (restored_from_version_id, entry_id) REFERENCES public.publishing_news_app_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_revision_multiple_taxonomy_assignments fk_news_app_rm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_news_app_rm_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_news_app_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_revision_multiple_taxonomy_assignments fk_news_app_rm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_news_app_rm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_news_app_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_revision_multiple_taxonomy_assignments fk_news_app_rm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_news_app_rm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_news_app_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_revision_single_taxonomy_assignments fk_news_app_rs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_news_app_rs_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_news_app_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_revision_single_taxonomy_assignments fk_news_app_rs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_news_app_rs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_news_app_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_revision_single_taxonomy_assignments fk_news_app_rs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_news_app_rs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_news_app_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_entry_slugs fk_news_app_slug_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_entry_slugs
    ADD CONSTRAINT fk_news_app_slug_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_news_app_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_taxonomy_terms fk_news_app_term_parent_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_taxonomy_terms
    ADD CONSTRAINT fk_news_app_term_parent_scope FOREIGN KEY (parent_id, vocabulary_id, locale) REFERENCES public.publishing_news_app_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_taxonomy_terms fk_news_app_term_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_taxonomy_terms
    ADD CONSTRAINT fk_news_app_term_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_news_app_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_entry_versions fk_news_app_ver_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_entry_versions
    ADD CONSTRAINT fk_news_app_ver_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_news_app_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_entry_versions fk_news_app_ver_revision_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_entry_versions
    ADD CONSTRAINT fk_news_app_ver_revision_entry FOREIGN KEY (entry_revision_id, entry_id) REFERENCES public.publishing_news_app_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_version_multiple_taxonomy_assignments fk_news_app_vm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_news_app_vm_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_news_app_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_version_multiple_taxonomy_assignments fk_news_app_vm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_news_app_vm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_news_app_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_version_multiple_taxonomy_assignments fk_news_app_vm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_news_app_vm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_news_app_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_version_single_taxonomy_assignments fk_news_app_vs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_news_app_vs_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_news_app_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_version_single_taxonomy_assignments fk_news_app_vs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_news_app_vs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_news_app_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_version_single_taxonomy_assignments fk_news_app_vs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_news_app_vs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_news_app_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_entries fk_news_com_ent_current_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_entries
    ADD CONSTRAINT fk_news_com_ent_current_rev FOREIGN KEY (current_revision_id, id) REFERENCES public.publishing_news_com_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_publications fk_news_com_pub_version_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_publications
    ADD CONSTRAINT fk_news_com_pub_version_entry FOREIGN KEY (entry_version_id, entry_id) REFERENCES public.publishing_news_com_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_entry_revisions fk_news_com_rev_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_entry_revisions
    ADD CONSTRAINT fk_news_com_rev_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_news_com_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_entry_revisions fk_news_com_rev_restore_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_entry_revisions
    ADD CONSTRAINT fk_news_com_rev_restore_rev FOREIGN KEY (restored_from_revision_id, entry_id) REFERENCES public.publishing_news_com_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_entry_revisions fk_news_com_rev_restore_ver; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_entry_revisions
    ADD CONSTRAINT fk_news_com_rev_restore_ver FOREIGN KEY (restored_from_version_id, entry_id) REFERENCES public.publishing_news_com_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_revision_multiple_taxonomy_assignments fk_news_com_rm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_news_com_rm_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_news_com_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_revision_multiple_taxonomy_assignments fk_news_com_rm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_news_com_rm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_news_com_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_revision_multiple_taxonomy_assignments fk_news_com_rm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_news_com_rm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_news_com_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_revision_single_taxonomy_assignments fk_news_com_rs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_news_com_rs_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_news_com_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_revision_single_taxonomy_assignments fk_news_com_rs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_news_com_rs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_news_com_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_revision_single_taxonomy_assignments fk_news_com_rs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_news_com_rs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_news_com_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_entry_slugs fk_news_com_slug_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_entry_slugs
    ADD CONSTRAINT fk_news_com_slug_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_news_com_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_taxonomy_terms fk_news_com_term_parent_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_taxonomy_terms
    ADD CONSTRAINT fk_news_com_term_parent_scope FOREIGN KEY (parent_id, vocabulary_id, locale) REFERENCES public.publishing_news_com_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_taxonomy_terms fk_news_com_term_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_taxonomy_terms
    ADD CONSTRAINT fk_news_com_term_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_news_com_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_entry_versions fk_news_com_ver_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_entry_versions
    ADD CONSTRAINT fk_news_com_ver_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_news_com_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_entry_versions fk_news_com_ver_revision_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_entry_versions
    ADD CONSTRAINT fk_news_com_ver_revision_entry FOREIGN KEY (entry_revision_id, entry_id) REFERENCES public.publishing_news_com_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_version_multiple_taxonomy_assignments fk_news_com_vm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_news_com_vm_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_news_com_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_version_multiple_taxonomy_assignments fk_news_com_vm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_news_com_vm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_news_com_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_version_multiple_taxonomy_assignments fk_news_com_vm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_news_com_vm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_news_com_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_version_single_taxonomy_assignments fk_news_com_vs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_news_com_vs_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_news_com_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_version_single_taxonomy_assignments fk_news_com_vs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_news_com_vs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_news_com_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_version_single_taxonomy_assignments fk_news_com_vs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_news_com_vs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_news_com_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_entries fk_news_org_ent_current_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_entries
    ADD CONSTRAINT fk_news_org_ent_current_rev FOREIGN KEY (current_revision_id, id) REFERENCES public.publishing_news_org_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_publications fk_news_org_pub_version_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_publications
    ADD CONSTRAINT fk_news_org_pub_version_entry FOREIGN KEY (entry_version_id, entry_id) REFERENCES public.publishing_news_org_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_entry_revisions fk_news_org_rev_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_entry_revisions
    ADD CONSTRAINT fk_news_org_rev_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_news_org_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_entry_revisions fk_news_org_rev_restore_rev; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_entry_revisions
    ADD CONSTRAINT fk_news_org_rev_restore_rev FOREIGN KEY (restored_from_revision_id, entry_id) REFERENCES public.publishing_news_org_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_entry_revisions fk_news_org_rev_restore_ver; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_entry_revisions
    ADD CONSTRAINT fk_news_org_rev_restore_ver FOREIGN KEY (restored_from_version_id, entry_id) REFERENCES public.publishing_news_org_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_revision_multiple_taxonomy_assignments fk_news_org_rm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_news_org_rm_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_news_org_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_revision_multiple_taxonomy_assignments fk_news_org_rm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_news_org_rm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_news_org_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_revision_multiple_taxonomy_assignments fk_news_org_rm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_news_org_rm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_news_org_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_revision_single_taxonomy_assignments fk_news_org_rs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_news_org_rs_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_news_org_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_revision_single_taxonomy_assignments fk_news_org_rs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_news_org_rs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_news_org_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_revision_single_taxonomy_assignments fk_news_org_rs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_news_org_rs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_news_org_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_entry_slugs fk_news_org_slug_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_entry_slugs
    ADD CONSTRAINT fk_news_org_slug_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_news_org_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_taxonomy_terms fk_news_org_term_parent_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_taxonomy_terms
    ADD CONSTRAINT fk_news_org_term_parent_scope FOREIGN KEY (parent_id, vocabulary_id, locale) REFERENCES public.publishing_news_org_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_taxonomy_terms fk_news_org_term_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_taxonomy_terms
    ADD CONSTRAINT fk_news_org_term_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_news_org_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_entry_versions fk_news_org_ver_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_entry_versions
    ADD CONSTRAINT fk_news_org_ver_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_news_org_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_entry_versions fk_news_org_ver_revision_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_entry_versions
    ADD CONSTRAINT fk_news_org_ver_revision_entry FOREIGN KEY (entry_revision_id, entry_id) REFERENCES public.publishing_news_org_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_version_multiple_taxonomy_assignments fk_news_org_vm_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_news_org_vm_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_news_org_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_version_multiple_taxonomy_assignments fk_news_org_vm_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_news_org_vm_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_news_org_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_version_multiple_taxonomy_assignments fk_news_org_vm_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_news_org_vm_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_news_org_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_version_single_taxonomy_assignments fk_news_org_vs_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_news_org_vs_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_news_org_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_version_single_taxonomy_assignments fk_news_org_vs_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_news_org_vs_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_news_org_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_version_single_taxonomy_assignments fk_news_org_vs_voc_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_news_org_vs_voc_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_news_org_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_taxonomy_terms fk_rails_01d55ef761; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_taxonomy_terms
    ADD CONSTRAINT fk_rails_01d55ef761 FOREIGN KEY (vocabulary_id) REFERENCES public.publishing_docs_app_vocabularies(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_version_media_usages fk_rails_06516ceffc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_version_media_usages
    ADD CONSTRAINT fk_rails_06516ceffc FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_entry_versions fk_rails_0980b0232c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_entry_versions
    ADD CONSTRAINT fk_rails_0980b0232c FOREIGN KEY (entry_id) REFERENCES public.publishing_help_app_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_taxonomy_terms fk_rails_09da75ab63; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_taxonomy_terms
    ADD CONSTRAINT fk_rails_09da75ab63 FOREIGN KEY (vocabulary_id) REFERENCES public.publishing_info_app_vocabularies(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_revision_media_usages fk_rails_0ac82a949c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_revision_media_usages
    ADD CONSTRAINT fk_rails_0ac82a949c FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_taxonomy_terms fk_rails_0fb1bcb2bf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_taxonomy_terms
    ADD CONSTRAINT fk_rails_0fb1bcb2bf FOREIGN KEY (vocabulary_id) REFERENCES public.publishing_help_org_vocabularies(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_version_media_usages fk_rails_108aea87f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_version_media_usages
    ADD CONSTRAINT fk_rails_108aea87f0 FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_publications fk_rails_135da7d014; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_publications
    ADD CONSTRAINT fk_rails_135da7d014 FOREIGN KEY (entry_id) REFERENCES public.publishing_info_com_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_entry_revisions fk_rails_145f23fb8d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_entry_revisions
    ADD CONSTRAINT fk_rails_145f23fb8d FOREIGN KEY (entry_id) REFERENCES public.publishing_help_com_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_taxonomy_terms fk_rails_16430b0d33; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_taxonomy_terms
    ADD CONSTRAINT fk_rails_16430b0d33 FOREIGN KEY (vocabulary_id) REFERENCES public.publishing_help_com_vocabularies(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_entry_slugs fk_rails_1b4a3f0676; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_entry_slugs
    ADD CONSTRAINT fk_rails_1b4a3f0676 FOREIGN KEY (entry_id) REFERENCES public.publishing_news_org_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_entry_slugs fk_rails_1ba6ad33f7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_entry_slugs
    ADD CONSTRAINT fk_rails_1ba6ad33f7 FOREIGN KEY (entry_id) REFERENCES public.publishing_docs_org_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_version_media_usages fk_rails_1de2686b86; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_version_media_usages
    ADD CONSTRAINT fk_rails_1de2686b86 FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_version_media_usages fk_rails_1f1b8a6e14; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_version_media_usages
    ADD CONSTRAINT fk_rails_1f1b8a6e14 FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_entry_revisions fk_rails_2000ef2dbb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_entry_revisions
    ADD CONSTRAINT fk_rails_2000ef2dbb FOREIGN KEY (entry_id) REFERENCES public.publishing_news_app_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_entry_revisions fk_rails_21e1ea33f1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_entry_revisions
    ADD CONSTRAINT fk_rails_21e1ea33f1 FOREIGN KEY (entry_id) REFERENCES public.publishing_docs_org_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_revision_media_usages fk_rails_221e98e3cd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_revision_media_usages
    ADD CONSTRAINT fk_rails_221e98e3cd FOREIGN KEY (entry_revision_id) REFERENCES public.publishing_docs_app_entry_revisions(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_entry_versions fk_rails_252fc9d7c7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_entry_versions
    ADD CONSTRAINT fk_rails_252fc9d7c7 FOREIGN KEY (entry_id) REFERENCES public.publishing_docs_org_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_publications fk_rails_2aa916bd46; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_publications
    ADD CONSTRAINT fk_rails_2aa916bd46 FOREIGN KEY (entry_id) REFERENCES public.publishing_docs_com_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_version_media_usages fk_rails_2bde500ca5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_version_media_usages
    ADD CONSTRAINT fk_rails_2bde500ca5 FOREIGN KEY (entry_version_id) REFERENCES public.publishing_help_app_entry_versions(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_entry_revisions fk_rails_2c973e20e7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_entry_revisions
    ADD CONSTRAINT fk_rails_2c973e20e7 FOREIGN KEY (entry_id) REFERENCES public.publishing_info_com_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_entry_slugs fk_rails_2e3f553631; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_entry_slugs
    ADD CONSTRAINT fk_rails_2e3f553631 FOREIGN KEY (entry_id) REFERENCES public.publishing_info_org_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_entry_slugs fk_rails_32315981ca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_entry_slugs
    ADD CONSTRAINT fk_rails_32315981ca FOREIGN KEY (entry_id) REFERENCES public.publishing_news_com_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_version_media_usages fk_rails_3393e38a53; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_version_media_usages
    ADD CONSTRAINT fk_rails_3393e38a53 FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_version_media_usages fk_rails_33b129d39b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_version_media_usages
    ADD CONSTRAINT fk_rails_33b129d39b FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_revision_media_usages fk_rails_37b83b461d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_revision_media_usages
    ADD CONSTRAINT fk_rails_37b83b461d FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_entry_revisions fk_rails_3d51cd7fe3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_entry_revisions
    ADD CONSTRAINT fk_rails_3d51cd7fe3 FOREIGN KEY (entry_id) REFERENCES public.publishing_help_org_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_version_media_usages fk_rails_42947d4e72; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_version_media_usages
    ADD CONSTRAINT fk_rails_42947d4e72 FOREIGN KEY (entry_version_id) REFERENCES public.publishing_news_com_entry_versions(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_entry_slugs fk_rails_46eccafd09; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_entry_slugs
    ADD CONSTRAINT fk_rails_46eccafd09 FOREIGN KEY (entry_id) REFERENCES public.publishing_help_org_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_version_media_usages fk_rails_4d359435c9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_version_media_usages
    ADD CONSTRAINT fk_rails_4d359435c9 FOREIGN KEY (entry_version_id) REFERENCES public.publishing_info_org_entry_versions(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_revision_media_usages fk_rails_51262f68cb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_revision_media_usages
    ADD CONSTRAINT fk_rails_51262f68cb FOREIGN KEY (entry_revision_id) REFERENCES public.publishing_help_com_entry_revisions(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_entry_slugs fk_rails_5188b2920d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_entry_slugs
    ADD CONSTRAINT fk_rails_5188b2920d FOREIGN KEY (entry_id) REFERENCES public.publishing_docs_app_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_revision_media_usages fk_rails_52f1d0b504; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_revision_media_usages
    ADD CONSTRAINT fk_rails_52f1d0b504 FOREIGN KEY (entry_revision_id) REFERENCES public.publishing_news_app_entry_revisions(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_revision_media_usages fk_rails_54eaf89534; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_revision_media_usages
    ADD CONSTRAINT fk_rails_54eaf89534 FOREIGN KEY (entry_revision_id) REFERENCES public.publishing_info_org_entry_revisions(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_entry_slugs fk_rails_561b34728e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_entry_slugs
    ADD CONSTRAINT fk_rails_561b34728e FOREIGN KEY (entry_id) REFERENCES public.publishing_news_app_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_taxonomy_terms fk_rails_5a7a6fd39b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_taxonomy_terms
    ADD CONSTRAINT fk_rails_5a7a6fd39b FOREIGN KEY (vocabulary_id) REFERENCES public.publishing_docs_com_vocabularies(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_version_media_usages fk_rails_5cbd2f48a7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_version_media_usages
    ADD CONSTRAINT fk_rails_5cbd2f48a7 FOREIGN KEY (entry_version_id) REFERENCES public.publishing_info_com_entry_versions(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_entry_revisions fk_rails_5e12acc268; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_entry_revisions
    ADD CONSTRAINT fk_rails_5e12acc268 FOREIGN KEY (entry_id) REFERENCES public.publishing_docs_app_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_publications fk_rails_5fbb3e23fc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_publications
    ADD CONSTRAINT fk_rails_5fbb3e23fc FOREIGN KEY (entry_id) REFERENCES public.publishing_news_com_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_revision_media_usages fk_rails_65c3667a70; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_revision_media_usages
    ADD CONSTRAINT fk_rails_65c3667a70 FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_entry_versions fk_rails_6954e8073f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_entry_versions
    ADD CONSTRAINT fk_rails_6954e8073f FOREIGN KEY (entry_id) REFERENCES public.publishing_info_app_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_entry_revisions fk_rails_6983ce984a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_entry_revisions
    ADD CONSTRAINT fk_rails_6983ce984a FOREIGN KEY (entry_id) REFERENCES public.publishing_news_org_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_revision_media_usages fk_rails_6c4789e901; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_revision_media_usages
    ADD CONSTRAINT fk_rails_6c4789e901 FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_taxonomy_terms fk_rails_6ca1fb7fdd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_taxonomy_terms
    ADD CONSTRAINT fk_rails_6ca1fb7fdd FOREIGN KEY (vocabulary_id) REFERENCES public.publishing_docs_org_vocabularies(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_revision_media_usages fk_rails_6ef780ee95; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_revision_media_usages
    ADD CONSTRAINT fk_rails_6ef780ee95 FOREIGN KEY (entry_revision_id) REFERENCES public.publishing_docs_com_entry_revisions(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_revision_media_usages fk_rails_7315ba4a34; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_revision_media_usages
    ADD CONSTRAINT fk_rails_7315ba4a34 FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_version_media_usages fk_rails_74dfc6c3bc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_version_media_usages
    ADD CONSTRAINT fk_rails_74dfc6c3bc FOREIGN KEY (entry_version_id) REFERENCES public.publishing_docs_org_entry_versions(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_version_media_usages fk_rails_7a37ad4046; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_version_media_usages
    ADD CONSTRAINT fk_rails_7a37ad4046 FOREIGN KEY (entry_version_id) REFERENCES public.publishing_docs_com_entry_versions(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_version_media_usages fk_rails_7abbba8f8e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_version_media_usages
    ADD CONSTRAINT fk_rails_7abbba8f8e FOREIGN KEY (entry_version_id) REFERENCES public.publishing_help_com_entry_versions(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_taxonomy_terms fk_rails_7cf898a345; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_taxonomy_terms
    ADD CONSTRAINT fk_rails_7cf898a345 FOREIGN KEY (vocabulary_id) REFERENCES public.publishing_news_com_vocabularies(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_revision_media_usages fk_rails_7dbb4a9a7e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_revision_media_usages
    ADD CONSTRAINT fk_rails_7dbb4a9a7e FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_entry_revisions fk_rails_7e5b3ea31e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_entry_revisions
    ADD CONSTRAINT fk_rails_7e5b3ea31e FOREIGN KEY (entry_id) REFERENCES public.publishing_docs_com_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_entry_versions fk_rails_7e826386bb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_entry_versions
    ADD CONSTRAINT fk_rails_7e826386bb FOREIGN KEY (entry_id) REFERENCES public.publishing_news_com_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_entry_versions fk_rails_7fc374cb54; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_entry_versions
    ADD CONSTRAINT fk_rails_7fc374cb54 FOREIGN KEY (entry_id) REFERENCES public.publishing_news_app_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_publications fk_rails_8412aa073d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_publications
    ADD CONSTRAINT fk_rails_8412aa073d FOREIGN KEY (entry_id) REFERENCES public.publishing_info_app_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_entry_versions fk_rails_8e6f7743b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_entry_versions
    ADD CONSTRAINT fk_rails_8e6f7743b9 FOREIGN KEY (entry_id) REFERENCES public.publishing_news_org_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_version_media_usages fk_rails_8ef1072d94; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_version_media_usages
    ADD CONSTRAINT fk_rails_8ef1072d94 FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_revision_media_usages fk_rails_913443bf80; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_revision_media_usages
    ADD CONSTRAINT fk_rails_913443bf80 FOREIGN KEY (entry_revision_id) REFERENCES public.publishing_info_app_entry_revisions(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_publications fk_rails_93b6af5f37; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_publications
    ADD CONSTRAINT fk_rails_93b6af5f37 FOREIGN KEY (entry_id) REFERENCES public.publishing_info_org_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_entry_versions fk_rails_93cbf47b72; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_entry_versions
    ADD CONSTRAINT fk_rails_93cbf47b72 FOREIGN KEY (entry_id) REFERENCES public.publishing_docs_app_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_revision_media_usages fk_rails_9660533530; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_revision_media_usages
    ADD CONSTRAINT fk_rails_9660533530 FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_version_media_usages fk_rails_96ce627c8d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_version_media_usages
    ADD CONSTRAINT fk_rails_96ce627c8d FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_version_media_usages fk_rails_97d2ff0370; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_version_media_usages
    ADD CONSTRAINT fk_rails_97d2ff0370 FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_revision_media_usages fk_rails_983f96444a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_revision_media_usages
    ADD CONSTRAINT fk_rails_983f96444a FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_version_media_usages fk_rails_9b39162b69; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_version_media_usages
    ADD CONSTRAINT fk_rails_9b39162b69 FOREIGN KEY (entry_version_id) REFERENCES public.publishing_help_org_entry_versions(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_entry_versions fk_rails_9ed969450b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_entry_versions
    ADD CONSTRAINT fk_rails_9ed969450b FOREIGN KEY (entry_id) REFERENCES public.publishing_info_com_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_version_media_usages fk_rails_a15a8b0246; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_version_media_usages
    ADD CONSTRAINT fk_rails_a15a8b0246 FOREIGN KEY (entry_version_id) REFERENCES public.publishing_news_app_entry_versions(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_publications fk_rails_a4d5fb1724; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_publications
    ADD CONSTRAINT fk_rails_a4d5fb1724 FOREIGN KEY (entry_id) REFERENCES public.publishing_news_app_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_entry_slugs fk_rails_a7158a1acf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_entry_slugs
    ADD CONSTRAINT fk_rails_a7158a1acf FOREIGN KEY (entry_id) REFERENCES public.publishing_docs_com_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_revision_media_usages fk_rails_ac3453271d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_revision_media_usages
    ADD CONSTRAINT fk_rails_ac3453271d FOREIGN KEY (entry_revision_id) REFERENCES public.publishing_help_org_entry_revisions(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_revision_media_usages fk_rails_ac5eb88b89; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_revision_media_usages
    ADD CONSTRAINT fk_rails_ac5eb88b89 FOREIGN KEY (entry_revision_id) REFERENCES public.publishing_news_org_entry_revisions(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_revision_media_usages fk_rails_b069785f42; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_revision_media_usages
    ADD CONSTRAINT fk_rails_b069785f42 FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_revision_media_usages fk_rails_b21499f38b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_revision_media_usages
    ADD CONSTRAINT fk_rails_b21499f38b FOREIGN KEY (entry_revision_id) REFERENCES public.publishing_info_com_entry_revisions(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_version_media_usages fk_rails_b5e5ee7fc9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_version_media_usages
    ADD CONSTRAINT fk_rails_b5e5ee7fc9 FOREIGN KEY (entry_version_id) REFERENCES public.publishing_info_app_entry_versions(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_revision_media_usages fk_rails_b69e88a6e9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_revision_media_usages
    ADD CONSTRAINT fk_rails_b69e88a6e9 FOREIGN KEY (entry_revision_id) REFERENCES public.publishing_news_com_entry_revisions(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_version_media_usages fk_rails_b7ce210206; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_version_media_usages
    ADD CONSTRAINT fk_rails_b7ce210206 FOREIGN KEY (entry_version_id) REFERENCES public.publishing_news_org_entry_versions(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_entry_versions fk_rails_b7d7f4a297; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_entry_versions
    ADD CONSTRAINT fk_rails_b7d7f4a297 FOREIGN KEY (entry_id) REFERENCES public.publishing_help_org_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_taxonomy_terms fk_rails_b8e686ccf0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_taxonomy_terms
    ADD CONSTRAINT fk_rails_b8e686ccf0 FOREIGN KEY (vocabulary_id) REFERENCES public.publishing_info_com_vocabularies(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_revision_media_usages fk_rails_ba55608b99; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_revision_media_usages
    ADD CONSTRAINT fk_rails_ba55608b99 FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_entry_revisions fk_rails_bd7fe50e78; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_entry_revisions
    ADD CONSTRAINT fk_rails_bd7fe50e78 FOREIGN KEY (entry_id) REFERENCES public.publishing_news_com_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_taxonomy_terms fk_rails_bfe75380c6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_taxonomy_terms
    ADD CONSTRAINT fk_rails_bfe75380c6 FOREIGN KEY (vocabulary_id) REFERENCES public.publishing_help_app_vocabularies(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_app_taxonomy_terms fk_rails_c0f2e98ddd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_app_taxonomy_terms
    ADD CONSTRAINT fk_rails_c0f2e98ddd FOREIGN KEY (vocabulary_id) REFERENCES public.publishing_news_app_vocabularies(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_entry_slugs fk_rails_c4eb97570e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_entry_slugs
    ADD CONSTRAINT fk_rails_c4eb97570e FOREIGN KEY (entry_id) REFERENCES public.publishing_help_app_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_publications fk_rails_cdbfd49ec1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_publications
    ADD CONSTRAINT fk_rails_cdbfd49ec1 FOREIGN KEY (entry_id) REFERENCES public.publishing_docs_org_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_publications fk_rails_ce90541b53; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_publications
    ADD CONSTRAINT fk_rails_ce90541b53 FOREIGN KEY (entry_id) REFERENCES public.publishing_help_org_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_entry_revisions fk_rails_d46a1aa250; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_entry_revisions
    ADD CONSTRAINT fk_rails_d46a1aa250 FOREIGN KEY (entry_id) REFERENCES public.publishing_info_org_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_taxonomy_terms fk_rails_d6e9124383; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_taxonomy_terms
    ADD CONSTRAINT fk_rails_d6e9124383 FOREIGN KEY (vocabulary_id) REFERENCES public.publishing_info_org_vocabularies(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_revision_media_usages fk_rails_d76574c547; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_revision_media_usages
    ADD CONSTRAINT fk_rails_d76574c547 FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_publications fk_rails_d8a7b197a0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_publications
    ADD CONSTRAINT fk_rails_d8a7b197a0 FOREIGN KEY (entry_id) REFERENCES public.publishing_docs_app_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_revision_media_usages fk_rails_daa2ad57f5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_revision_media_usages
    ADD CONSTRAINT fk_rails_daa2ad57f5 FOREIGN KEY (entry_revision_id) REFERENCES public.publishing_help_app_entry_revisions(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_version_media_usages fk_rails_dbf54168f9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_version_media_usages
    ADD CONSTRAINT fk_rails_dbf54168f9 FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_com_entry_slugs fk_rails_e0f23a8096; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_com_entry_slugs
    ADD CONSTRAINT fk_rails_e0f23a8096 FOREIGN KEY (entry_id) REFERENCES public.publishing_info_com_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_publications fk_rails_e4c5d812cb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_publications
    ADD CONSTRAINT fk_rails_e4c5d812cb FOREIGN KEY (entry_id) REFERENCES public.publishing_help_app_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_version_media_usages fk_rails_e57058466b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_version_media_usages
    ADD CONSTRAINT fk_rails_e57058466b FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_publications fk_rails_ef45046158; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_publications
    ADD CONSTRAINT fk_rails_ef45046158 FOREIGN KEY (entry_id) REFERENCES public.publishing_news_org_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_entry_versions fk_rails_f01732cdd4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_entry_versions
    ADD CONSTRAINT fk_rails_f01732cdd4 FOREIGN KEY (entry_id) REFERENCES public.publishing_help_com_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_entry_revisions fk_rails_f1dab244f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_entry_revisions
    ADD CONSTRAINT fk_rails_f1dab244f0 FOREIGN KEY (entry_id) REFERENCES public.publishing_info_app_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_app_version_media_usages fk_rails_f2f9c98cf2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_app_version_media_usages
    ADD CONSTRAINT fk_rails_f2f9c98cf2 FOREIGN KEY (entry_version_id) REFERENCES public.publishing_docs_app_entry_versions(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_org_entry_versions fk_rails_f404a50c8a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_org_entry_versions
    ADD CONSTRAINT fk_rails_f404a50c8a FOREIGN KEY (entry_id) REFERENCES public.publishing_info_org_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_entry_slugs fk_rails_f81b6729ca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_entry_slugs
    ADD CONSTRAINT fk_rails_f81b6729ca FOREIGN KEY (entry_id) REFERENCES public.publishing_help_com_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_org_taxonomy_terms fk_rails_f96559cb11; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_org_taxonomy_terms
    ADD CONSTRAINT fk_rails_f96559cb11 FOREIGN KEY (vocabulary_id) REFERENCES public.publishing_news_org_vocabularies(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_com_entry_versions fk_rails_f96fc102d1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_com_entry_versions
    ADD CONSTRAINT fk_rails_f96fc102d1 FOREIGN KEY (entry_id) REFERENCES public.publishing_docs_com_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_news_com_version_media_usages fk_rails_ff8f9312c9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_news_com_version_media_usages
    ADD CONSTRAINT fk_rails_ff8f9312c9 FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_com_publications fk_rails_ff9aae8310; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_com_publications
    ADD CONSTRAINT fk_rails_ff9aae8310 FOREIGN KEY (entry_id) REFERENCES public.publishing_help_com_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_docs_org_revision_media_usages fk_rails_ffa272f420; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_docs_org_revision_media_usages
    ADD CONSTRAINT fk_rails_ffa272f420 FOREIGN KEY (entry_revision_id) REFERENCES public.publishing_docs_org_entry_revisions(id) ON DELETE RESTRICT;


--
-- Name: publishing_info_app_entry_slugs fk_rails_ffcb29d9b7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_info_app_entry_slugs
    ADD CONSTRAINT fk_rails_ffcb29d9b7 FOREIGN KEY (entry_id) REFERENCES public.publishing_info_app_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_app_entry_revisions fk_rails_ffe74576ea; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_app_entry_revisions
    ADD CONSTRAINT fk_rails_ffe74576ea FOREIGN KEY (entry_id) REFERENCES public.publishing_help_app_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_help_org_revision_media_usages fk_rails_ffeb4d8a07; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_help_org_revision_media_usages
    ADD CONSTRAINT fk_rails_ffeb4d8a07 FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260906120000'),
('20260906000001'),
('20260810013000'),
('20260716180000');

