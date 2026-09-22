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
-- Name: avatar_agent_bindings; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatar_agent_bindings (
    id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    agent_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    public_id character varying(21) NOT NULL,
    assigned_at timestamp(6) with time zone NOT NULL,
    revoked_at timestamp(6) with time zone,
    CONSTRAINT chk_avatar_agent_bindings_revoked_after_assigned CHECK (((revoked_at IS NULL) OR (revoked_at >= assigned_at)))
);


--
-- Name: avatar_agent_bindings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatar_agent_bindings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatar_agent_bindings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatar_agent_bindings_id_seq OWNED BY public.avatar_agent_bindings.id;


--
-- Name: avatar_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatar_assignments (
    id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    role character varying(50) DEFAULT 'viewer'::character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL,
    CONSTRAINT check_avatar_assignment_role CHECK (((role)::text = ANY (ARRAY[('owner'::character varying)::text, ('affiliation'::character varying)::text, ('administrator'::character varying)::text, ('editor'::character varying)::text, ('reviewer'::character varying)::text, ('viewer'::character varying)::text])))
);


--
-- Name: avatar_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatar_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatar_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatar_assignments_id_seq OWNED BY public.avatar_assignments.id;


--
-- Name: avatar_blocks; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatar_blocks (
    id bigint NOT NULL,
    blocked_avatar_id bigint NOT NULL,
    blocker_avatar_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    reason character varying,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_avatar_blocks_no_self_edge CHECK ((blocker_avatar_id <> blocked_avatar_id))
);


--
-- Name: avatar_blocks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatar_blocks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatar_blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatar_blocks_id_seq OWNED BY public.avatar_blocks.id;


--
-- Name: avatar_capabilities; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatar_capabilities (
    id bigint NOT NULL
);


--
-- Name: avatar_capabilities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatar_capabilities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatar_capabilities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatar_capabilities_id_seq OWNED BY public.avatar_capabilities.id;


--
-- Name: avatar_follows; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatar_follows (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    followed_avatar_id bigint NOT NULL,
    follower_avatar_id bigint NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_avatar_follows_no_self_edge CHECK ((follower_avatar_id <> followed_avatar_id))
);


--
-- Name: avatar_follows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatar_follows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatar_follows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatar_follows_id_seq OWNED BY public.avatar_follows.id;


--
-- Name: avatar_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatar_groups (
    id bigint NOT NULL,
    public_id character varying NOT NULL,
    account_surface character varying NOT NULL,
    account_public_id character varying NOT NULL,
    name character varying NOT NULL,
    description text,
    state character varying DEFAULT 'active'::character varying NOT NULL,
    archived_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_avatar_groups_account_surface CHECK (((account_surface)::text = ANY ((ARRAY['app'::character varying, 'org'::character varying, 'com'::character varying])::text[]))),
    CONSTRAINT chk_avatar_groups_archive_state CHECK ((((state)::text = 'archived'::text) = (archived_at IS NOT NULL))),
    CONSTRAINT chk_avatar_groups_state CHECK (((state)::text = ANY ((ARRAY['active'::character varying, 'archived'::character varying])::text[])))
);


--
-- Name: avatar_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatar_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatar_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatar_groups_id_seq OWNED BY public.avatar_groups.id;


--
-- Name: avatar_individual_bindings; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatar_individual_bindings (
    id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    individual_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    public_id character varying(21) NOT NULL,
    assigned_at timestamp(6) with time zone NOT NULL,
    revoked_at timestamp(6) with time zone,
    CONSTRAINT chk_avatar_individual_bindings_revoked_after_assigned CHECK (((revoked_at IS NULL) OR (revoked_at >= assigned_at)))
);


--
-- Name: avatar_individual_bindings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatar_individual_bindings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatar_individual_bindings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatar_individual_bindings_id_seq OWNED BY public.avatar_individual_bindings.id;


--
-- Name: avatar_lifecycle_events; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatar_lifecycle_events (
    id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    from_state_key character varying NOT NULL,
    to_state_key character varying NOT NULL,
    changed_by_type character varying,
    changed_by_public_id character varying,
    reason text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_avatar_lifecycle_events_state_changes CHECK (((from_state_key)::text <> (to_state_key)::text))
);


--
-- Name: avatar_lifecycle_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatar_lifecycle_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatar_lifecycle_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatar_lifecycle_events_id_seq OWNED BY public.avatar_lifecycle_events.id;


--
-- Name: avatar_lifecycle_states; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatar_lifecycle_states (
    id bigint NOT NULL,
    key character varying NOT NULL,
    title character varying NOT NULL,
    description text,
    can_create_content boolean NOT NULL,
    visible_by_default boolean NOT NULL,
    editable_by_owner boolean NOT NULL,
    restorable_by_owner boolean NOT NULL,
    followable boolean NOT NULL,
    group_attachable boolean NOT NULL,
    discoverable boolean NOT NULL,
    moderation_visible boolean NOT NULL,
    terminal boolean NOT NULL,
    sort_order integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: avatar_lifecycle_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatar_lifecycle_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatar_lifecycle_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatar_lifecycle_states_id_seq OWNED BY public.avatar_lifecycle_states.id;


--
-- Name: avatar_membership_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatar_membership_statuses (
    id bigint NOT NULL
);


--
-- Name: avatar_membership_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatar_membership_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatar_membership_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatar_membership_statuses_id_seq OWNED BY public.avatar_membership_statuses.id;


--
-- Name: avatar_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatar_memberships (
    id bigint NOT NULL,
    actor_id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    avatar_membership_status_id bigint,
    created_at timestamp(6) with time zone NOT NULL,
    granted_by_actor_id bigint,
    role_id bigint DEFAULT 0 NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    valid_from timestamp with time zone NOT NULL,
    valid_to timestamp with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT chk_avatar_memberships_avatar_membership_status_id_positive CHECK (((avatar_membership_status_id IS NULL) OR (avatar_membership_status_id >= 0))),
    CONSTRAINT chk_avatar_memberships_role_id_positive CHECK ((role_id >= 0)),
    CONSTRAINT chk_avatar_memberships_valid_period CHECK ((valid_from <= valid_to))
);


--
-- Name: avatar_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatar_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatar_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatar_memberships_id_seq OWNED BY public.avatar_memberships.id;


--
-- Name: avatar_moniker_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatar_moniker_statuses (
    id bigint NOT NULL
);


--
-- Name: avatar_moniker_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatar_moniker_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatar_moniker_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatar_moniker_statuses_id_seq OWNED BY public.avatar_moniker_statuses.id;


--
-- Name: avatar_monikers; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatar_monikers (
    id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    avatar_moniker_status_id bigint,
    created_at timestamp(6) with time zone NOT NULL,
    moniker character varying NOT NULL,
    set_by_actor_id bigint,
    updated_at timestamp(6) with time zone NOT NULL,
    valid_from timestamp with time zone NOT NULL,
    valid_to timestamp with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT chk_avatar_monikers_avatar_moniker_status_id_positive CHECK (((avatar_moniker_status_id IS NULL) OR (avatar_moniker_status_id >= 0)))
);


--
-- Name: avatar_monikers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatar_monikers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatar_monikers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatar_monikers_id_seq OWNED BY public.avatar_monikers.id;


--
-- Name: avatar_mutes; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatar_mutes (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    muted_avatar_id bigint NOT NULL,
    muter_avatar_id bigint NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_avatar_mutes_no_self_edge CHECK ((muter_avatar_id <> muted_avatar_id))
);


--
-- Name: avatar_mutes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatar_mutes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatar_mutes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatar_mutes_id_seq OWNED BY public.avatar_mutes.id;


--
-- Name: avatar_ownership_periods; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatar_ownership_periods (
    id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    avatar_ownership_status_id bigint,
    created_at timestamp(6) with time zone NOT NULL,
    owner_organization_id character varying NOT NULL,
    transferred_by_actor_id bigint,
    updated_at timestamp(6) with time zone NOT NULL,
    valid_from timestamp with time zone NOT NULL,
    valid_to timestamp with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT chk_avatar_ownership_periods_avatar_ownership_status_id_positiv CHECK (((avatar_ownership_status_id IS NULL) OR (avatar_ownership_status_id >= 0)))
);


--
-- Name: avatar_ownership_periods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatar_ownership_periods_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatar_ownership_periods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatar_ownership_periods_id_seq OWNED BY public.avatar_ownership_periods.id;


--
-- Name: avatar_ownership_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatar_ownership_statuses (
    id bigint NOT NULL
);


--
-- Name: avatar_ownership_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatar_ownership_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatar_ownership_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatar_ownership_statuses_id_seq OWNED BY public.avatar_ownership_statuses.id;


--
-- Name: avatar_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatar_permissions (
    id bigint NOT NULL
);


--
-- Name: avatar_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatar_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatar_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatar_permissions_id_seq OWNED BY public.avatar_permissions.id;


--
-- Name: avatar_persona_bindings; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatar_persona_bindings (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    avatar_id bigint NOT NULL,
    persona_id bigint NOT NULL,
    assigned_at timestamp(6) with time zone NOT NULL,
    revoked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_avatar_persona_bindings_revoked_after_assigned CHECK (((revoked_at IS NULL) OR (revoked_at >= assigned_at)))
);


--
-- Name: avatar_persona_bindings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatar_persona_bindings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatar_persona_bindings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatar_persona_bindings_id_seq OWNED BY public.avatar_persona_bindings.id;


--
-- Name: avatar_role_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatar_role_permissions (
    id bigint NOT NULL,
    avatar_permission_id bigint DEFAULT 0 NOT NULL,
    avatar_role_id bigint DEFAULT 0 NOT NULL,
    CONSTRAINT chk_avatar_role_permissions_permission_id_positive CHECK ((avatar_permission_id >= 0)),
    CONSTRAINT chk_avatar_role_permissions_role_id_positive CHECK ((avatar_role_id >= 0))
);


--
-- Name: avatar_role_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatar_role_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatar_role_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatar_role_permissions_id_seq OWNED BY public.avatar_role_permissions.id;


--
-- Name: avatar_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatar_roles (
    id bigint NOT NULL
);


--
-- Name: avatar_roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatar_roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatar_roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatar_roles_id_seq OWNED BY public.avatar_roles.id;


--
-- Name: avatars; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.avatars (
    id bigint NOT NULL,
    active_handle_id bigint NOT NULL,
    avatar_status_id character varying,
    capability_id bigint DEFAULT 0 NOT NULL,
    client_id bigint,
    created_at timestamp(6) with time zone NOT NULL,
    image_data jsonb,
    lock_version integer DEFAULT 0 NOT NULL,
    moniker character varying NOT NULL,
    owner_organization_id character varying,
    public_id character varying NOT NULL,
    representing_organization_id character varying,
    updated_at timestamp(6) with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    lifecycle_state_id bigint NOT NULL,
    CONSTRAINT chk_avatars_capability_id_positive CHECK ((capability_id >= 0))
);


--
-- Name: avatars_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.avatars_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avatars_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avatars_id_seq OWNED BY public.avatars.id;


--
-- Name: client_avatar_accesses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.client_avatar_accesses (
    id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_avatar_accesses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.client_avatar_accesses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_avatar_accesses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_avatar_accesses_id_seq OWNED BY public.client_avatar_accesses.id;


--
-- Name: client_avatar_deletions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.client_avatar_deletions (
    id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_avatar_deletions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.client_avatar_deletions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_avatar_deletions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_avatar_deletions_id_seq OWNED BY public.client_avatar_deletions.id;


--
-- Name: client_avatar_extractions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.client_avatar_extractions (
    id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_avatar_extractions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.client_avatar_extractions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_avatar_extractions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_avatar_extractions_id_seq OWNED BY public.client_avatar_extractions.id;


--
-- Name: client_avatar_impersonations; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.client_avatar_impersonations (
    id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_avatar_impersonations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.client_avatar_impersonations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_avatar_impersonations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_avatar_impersonations_id_seq OWNED BY public.client_avatar_impersonations.id;


--
-- Name: client_avatar_oversights; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.client_avatar_oversights (
    id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_avatar_oversights_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.client_avatar_oversights_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_avatar_oversights_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_avatar_oversights_id_seq OWNED BY public.client_avatar_oversights.id;


--
-- Name: client_avatar_suspensions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.client_avatar_suspensions (
    id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_avatar_suspensions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.client_avatar_suspensions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_avatar_suspensions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_avatar_suspensions_id_seq OWNED BY public.client_avatar_suspensions.id;


--
-- Name: client_avatar_visibilities; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.client_avatar_visibilities (
    id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_avatar_visibilities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.client_avatar_visibilities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_avatar_visibilities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_avatar_visibilities_id_seq OWNED BY public.client_avatar_visibilities.id;


--
-- Name: group_avatar_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.group_avatar_memberships (
    id bigint NOT NULL,
    public_id character varying NOT NULL,
    avatar_group_id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    role character varying DEFAULT 'member'::character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    state character varying DEFAULT 'active'::character varying NOT NULL,
    assigned_at timestamp(6) with time zone NOT NULL,
    removed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_group_avatar_memberships_removed_after_assigned CHECK (((removed_at IS NULL) OR (removed_at >= assigned_at))),
    CONSTRAINT chk_group_avatar_memberships_removed_state CHECK ((((state)::text = 'removed'::text) = (removed_at IS NOT NULL))),
    CONSTRAINT chk_group_avatar_memberships_state CHECK (((state)::text = ANY ((ARRAY['active'::character varying, 'removed'::character varying])::text[])))
);


--
-- Name: group_avatar_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.group_avatar_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: group_avatar_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.group_avatar_memberships_id_seq OWNED BY public.group_avatar_memberships.id;


--
-- Name: handle_assignment_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.handle_assignment_statuses (
    id bigint NOT NULL
);


--
-- Name: handle_assignment_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.handle_assignment_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: handle_assignment_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.handle_assignment_statuses_id_seq OWNED BY public.handle_assignment_statuses.id;


--
-- Name: handle_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.handle_assignments (
    id bigint NOT NULL,
    assigned_by_actor_id bigint,
    avatar_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    handle_assignment_status_id bigint,
    handle_id bigint NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    valid_from timestamp with time zone NOT NULL,
    valid_to timestamp with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT chk_handle_assignments_handle_assignment_status_id_positive CHECK (((handle_assignment_status_id IS NULL) OR (handle_assignment_status_id >= 0)))
);


--
-- Name: handle_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.handle_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: handle_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.handle_assignments_id_seq OWNED BY public.handle_assignments.id;


--
-- Name: handle_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.handle_statuses (
    id bigint NOT NULL
);


--
-- Name: handle_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.handle_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: handle_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.handle_statuses_id_seq OWNED BY public.handle_statuses.id;


--
-- Name: handles; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.handles (
    id bigint NOT NULL,
    cooldown_until timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    handle character varying NOT NULL,
    handle_status_id bigint,
    is_system boolean DEFAULT false NOT NULL,
    public_id character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_handles_handle_status_id_positive CHECK (((handle_status_id IS NULL) OR (handle_status_id >= 0)))
);


--
-- Name: handles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.handles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: handles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.handles_id_seq OWNED BY public.handles.id;


--
-- Name: member_avatar_accesses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.member_avatar_accesses (
    id bigint NOT NULL,
    member_id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: member_avatar_accesses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.member_avatar_accesses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: member_avatar_accesses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.member_avatar_accesses_id_seq OWNED BY public.member_avatar_accesses.id;


--
-- Name: member_avatar_deletions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.member_avatar_deletions (
    id bigint NOT NULL,
    member_id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: member_avatar_deletions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.member_avatar_deletions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: member_avatar_deletions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.member_avatar_deletions_id_seq OWNED BY public.member_avatar_deletions.id;


--
-- Name: member_avatar_extractions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.member_avatar_extractions (
    id bigint NOT NULL,
    member_id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: member_avatar_extractions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.member_avatar_extractions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: member_avatar_extractions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.member_avatar_extractions_id_seq OWNED BY public.member_avatar_extractions.id;


--
-- Name: member_avatar_impersonations; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.member_avatar_impersonations (
    id bigint NOT NULL,
    member_id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: member_avatar_impersonations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.member_avatar_impersonations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: member_avatar_impersonations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.member_avatar_impersonations_id_seq OWNED BY public.member_avatar_impersonations.id;


--
-- Name: member_avatar_oversights; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.member_avatar_oversights (
    id bigint NOT NULL,
    member_id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: member_avatar_oversights_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.member_avatar_oversights_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: member_avatar_oversights_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.member_avatar_oversights_id_seq OWNED BY public.member_avatar_oversights.id;


--
-- Name: member_avatar_suspensions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.member_avatar_suspensions (
    id bigint NOT NULL,
    member_id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: member_avatar_suspensions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.member_avatar_suspensions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: member_avatar_suspensions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.member_avatar_suspensions_id_seq OWNED BY public.member_avatar_suspensions.id;


--
-- Name: member_avatar_visibilities; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.member_avatar_visibilities (
    id bigint NOT NULL,
    member_id bigint NOT NULL,
    avatar_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: member_avatar_visibilities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.member_avatar_visibilities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: member_avatar_visibilities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.member_avatar_visibilities_id_seq OWNED BY public.member_avatar_visibilities.id;


--
-- Name: post_review_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.post_review_statuses (
    id bigint NOT NULL
);


--
-- Name: post_review_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.post_review_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_review_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_review_statuses_id_seq OWNED BY public.post_review_statuses.id;


--
-- Name: post_reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.post_reviews (
    id bigint NOT NULL,
    comment text,
    created_at timestamp(6) with time zone NOT NULL,
    decided_at timestamp with time zone,
    post_id bigint NOT NULL,
    post_review_status_id bigint DEFAULT 0 NOT NULL,
    reviewer_actor_id bigint NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_post_reviews_post_review_status_id_positive CHECK (((post_review_status_id IS NULL) OR (post_review_status_id >= 0)))
);


--
-- Name: post_reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.post_reviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_reviews_id_seq OWNED BY public.post_reviews.id;


--
-- Name: post_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.post_statuses (
    id bigint NOT NULL
);


--
-- Name: post_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.post_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_statuses_id_seq OWNED BY public.post_statuses.id;


--
-- Name: post_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.post_versions (
    id bigint NOT NULL,
    body text,
    created_at timestamp(6) with time zone NOT NULL,
    description character varying,
    edited_by_id bigint,
    edited_by_type character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    permalink character varying(200) NOT NULL,
    post_id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    publish_at timestamp(6) with time zone NOT NULL,
    redirect_url character varying,
    response_mode character varying NOT NULL,
    title character varying,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: post_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.post_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_versions_id_seq OWNED BY public.post_versions.id;


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.posts (
    id bigint NOT NULL,
    author_avatar_id bigint NOT NULL,
    body text NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    created_by_actor_id bigint NOT NULL,
    post_status_id bigint DEFAULT 0 NOT NULL,
    public_id character varying NOT NULL,
    published_at timestamp with time zone,
    published_by_actor_id bigint,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_posts_post_status_id_positive CHECK (((post_status_id IS NULL) OR (post_status_id >= 0)))
);


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.posts_id_seq OWNED BY public.posts.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: avatar_agent_bindings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_agent_bindings ALTER COLUMN id SET DEFAULT nextval('public.avatar_agent_bindings_id_seq'::regclass);


--
-- Name: avatar_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_assignments ALTER COLUMN id SET DEFAULT nextval('public.avatar_assignments_id_seq'::regclass);


--
-- Name: avatar_blocks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_blocks ALTER COLUMN id SET DEFAULT nextval('public.avatar_blocks_id_seq'::regclass);


--
-- Name: avatar_capabilities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_capabilities ALTER COLUMN id SET DEFAULT nextval('public.avatar_capabilities_id_seq'::regclass);


--
-- Name: avatar_follows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_follows ALTER COLUMN id SET DEFAULT nextval('public.avatar_follows_id_seq'::regclass);


--
-- Name: avatar_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_groups ALTER COLUMN id SET DEFAULT nextval('public.avatar_groups_id_seq'::regclass);


--
-- Name: avatar_individual_bindings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_individual_bindings ALTER COLUMN id SET DEFAULT nextval('public.avatar_individual_bindings_id_seq'::regclass);


--
-- Name: avatar_lifecycle_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_lifecycle_events ALTER COLUMN id SET DEFAULT nextval('public.avatar_lifecycle_events_id_seq'::regclass);


--
-- Name: avatar_lifecycle_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_lifecycle_states ALTER COLUMN id SET DEFAULT nextval('public.avatar_lifecycle_states_id_seq'::regclass);


--
-- Name: avatar_membership_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_membership_statuses ALTER COLUMN id SET DEFAULT nextval('public.avatar_membership_statuses_id_seq'::regclass);


--
-- Name: avatar_memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_memberships ALTER COLUMN id SET DEFAULT nextval('public.avatar_memberships_id_seq'::regclass);


--
-- Name: avatar_moniker_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_moniker_statuses ALTER COLUMN id SET DEFAULT nextval('public.avatar_moniker_statuses_id_seq'::regclass);


--
-- Name: avatar_monikers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_monikers ALTER COLUMN id SET DEFAULT nextval('public.avatar_monikers_id_seq'::regclass);


--
-- Name: avatar_mutes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_mutes ALTER COLUMN id SET DEFAULT nextval('public.avatar_mutes_id_seq'::regclass);


--
-- Name: avatar_ownership_periods id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_ownership_periods ALTER COLUMN id SET DEFAULT nextval('public.avatar_ownership_periods_id_seq'::regclass);


--
-- Name: avatar_ownership_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_ownership_statuses ALTER COLUMN id SET DEFAULT nextval('public.avatar_ownership_statuses_id_seq'::regclass);


--
-- Name: avatar_permissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_permissions ALTER COLUMN id SET DEFAULT nextval('public.avatar_permissions_id_seq'::regclass);


--
-- Name: avatar_persona_bindings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_persona_bindings ALTER COLUMN id SET DEFAULT nextval('public.avatar_persona_bindings_id_seq'::regclass);


--
-- Name: avatar_role_permissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_role_permissions ALTER COLUMN id SET DEFAULT nextval('public.avatar_role_permissions_id_seq'::regclass);


--
-- Name: avatar_roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_roles ALTER COLUMN id SET DEFAULT nextval('public.avatar_roles_id_seq'::regclass);


--
-- Name: avatars id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatars ALTER COLUMN id SET DEFAULT nextval('public.avatars_id_seq'::regclass);


--
-- Name: client_avatar_accesses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_accesses ALTER COLUMN id SET DEFAULT nextval('public.client_avatar_accesses_id_seq'::regclass);


--
-- Name: client_avatar_deletions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_deletions ALTER COLUMN id SET DEFAULT nextval('public.client_avatar_deletions_id_seq'::regclass);


--
-- Name: client_avatar_extractions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_extractions ALTER COLUMN id SET DEFAULT nextval('public.client_avatar_extractions_id_seq'::regclass);


--
-- Name: client_avatar_impersonations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_impersonations ALTER COLUMN id SET DEFAULT nextval('public.client_avatar_impersonations_id_seq'::regclass);


--
-- Name: client_avatar_oversights id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_oversights ALTER COLUMN id SET DEFAULT nextval('public.client_avatar_oversights_id_seq'::regclass);


--
-- Name: client_avatar_suspensions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_suspensions ALTER COLUMN id SET DEFAULT nextval('public.client_avatar_suspensions_id_seq'::regclass);


--
-- Name: client_avatar_visibilities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_visibilities ALTER COLUMN id SET DEFAULT nextval('public.client_avatar_visibilities_id_seq'::regclass);


--
-- Name: group_avatar_memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_avatar_memberships ALTER COLUMN id SET DEFAULT nextval('public.group_avatar_memberships_id_seq'::regclass);


--
-- Name: handle_assignment_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.handle_assignment_statuses ALTER COLUMN id SET DEFAULT nextval('public.handle_assignment_statuses_id_seq'::regclass);


--
-- Name: handle_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.handle_assignments ALTER COLUMN id SET DEFAULT nextval('public.handle_assignments_id_seq'::regclass);


--
-- Name: handle_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.handle_statuses ALTER COLUMN id SET DEFAULT nextval('public.handle_statuses_id_seq'::regclass);


--
-- Name: handles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.handles ALTER COLUMN id SET DEFAULT nextval('public.handles_id_seq'::regclass);


--
-- Name: member_avatar_accesses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_accesses ALTER COLUMN id SET DEFAULT nextval('public.member_avatar_accesses_id_seq'::regclass);


--
-- Name: member_avatar_deletions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_deletions ALTER COLUMN id SET DEFAULT nextval('public.member_avatar_deletions_id_seq'::regclass);


--
-- Name: member_avatar_extractions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_extractions ALTER COLUMN id SET DEFAULT nextval('public.member_avatar_extractions_id_seq'::regclass);


--
-- Name: member_avatar_impersonations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_impersonations ALTER COLUMN id SET DEFAULT nextval('public.member_avatar_impersonations_id_seq'::regclass);


--
-- Name: member_avatar_oversights id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_oversights ALTER COLUMN id SET DEFAULT nextval('public.member_avatar_oversights_id_seq'::regclass);


--
-- Name: member_avatar_suspensions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_suspensions ALTER COLUMN id SET DEFAULT nextval('public.member_avatar_suspensions_id_seq'::regclass);


--
-- Name: member_avatar_visibilities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_visibilities ALTER COLUMN id SET DEFAULT nextval('public.member_avatar_visibilities_id_seq'::regclass);


--
-- Name: post_review_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_review_statuses ALTER COLUMN id SET DEFAULT nextval('public.post_review_statuses_id_seq'::regclass);


--
-- Name: post_reviews id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_reviews ALTER COLUMN id SET DEFAULT nextval('public.post_reviews_id_seq'::regclass);


--
-- Name: post_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_statuses ALTER COLUMN id SET DEFAULT nextval('public.post_statuses_id_seq'::regclass);


--
-- Name: post_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_versions ALTER COLUMN id SET DEFAULT nextval('public.post_versions_id_seq'::regclass);


--
-- Name: posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: avatar_agent_bindings avatar_agent_bindings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_agent_bindings
    ADD CONSTRAINT avatar_agent_bindings_pkey PRIMARY KEY (id);


--
-- Name: avatar_assignments avatar_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_assignments
    ADD CONSTRAINT avatar_assignments_pkey PRIMARY KEY (id);


--
-- Name: avatar_blocks avatar_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_blocks
    ADD CONSTRAINT avatar_blocks_pkey PRIMARY KEY (id);


--
-- Name: avatar_capabilities avatar_capabilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_capabilities
    ADD CONSTRAINT avatar_capabilities_pkey PRIMARY KEY (id);


--
-- Name: avatar_follows avatar_follows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_follows
    ADD CONSTRAINT avatar_follows_pkey PRIMARY KEY (id);


--
-- Name: avatar_groups avatar_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_groups
    ADD CONSTRAINT avatar_groups_pkey PRIMARY KEY (id);


--
-- Name: avatar_individual_bindings avatar_individual_bindings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_individual_bindings
    ADD CONSTRAINT avatar_individual_bindings_pkey PRIMARY KEY (id);


--
-- Name: avatar_lifecycle_events avatar_lifecycle_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_lifecycle_events
    ADD CONSTRAINT avatar_lifecycle_events_pkey PRIMARY KEY (id);


--
-- Name: avatar_lifecycle_states avatar_lifecycle_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_lifecycle_states
    ADD CONSTRAINT avatar_lifecycle_states_pkey PRIMARY KEY (id);


--
-- Name: avatar_membership_statuses avatar_membership_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_membership_statuses
    ADD CONSTRAINT avatar_membership_statuses_pkey PRIMARY KEY (id);


--
-- Name: avatar_memberships avatar_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_memberships
    ADD CONSTRAINT avatar_memberships_pkey PRIMARY KEY (id);


--
-- Name: avatar_moniker_statuses avatar_moniker_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_moniker_statuses
    ADD CONSTRAINT avatar_moniker_statuses_pkey PRIMARY KEY (id);


--
-- Name: avatar_monikers avatar_monikers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_monikers
    ADD CONSTRAINT avatar_monikers_pkey PRIMARY KEY (id);


--
-- Name: avatar_mutes avatar_mutes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_mutes
    ADD CONSTRAINT avatar_mutes_pkey PRIMARY KEY (id);


--
-- Name: avatar_ownership_periods avatar_ownership_periods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_ownership_periods
    ADD CONSTRAINT avatar_ownership_periods_pkey PRIMARY KEY (id);


--
-- Name: avatar_ownership_statuses avatar_ownership_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_ownership_statuses
    ADD CONSTRAINT avatar_ownership_statuses_pkey PRIMARY KEY (id);


--
-- Name: avatar_permissions avatar_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_permissions
    ADD CONSTRAINT avatar_permissions_pkey PRIMARY KEY (id);


--
-- Name: avatar_persona_bindings avatar_persona_bindings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_persona_bindings
    ADD CONSTRAINT avatar_persona_bindings_pkey PRIMARY KEY (id);


--
-- Name: avatar_role_permissions avatar_role_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_role_permissions
    ADD CONSTRAINT avatar_role_permissions_pkey PRIMARY KEY (id);


--
-- Name: avatar_roles avatar_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_roles
    ADD CONSTRAINT avatar_roles_pkey PRIMARY KEY (id);


--
-- Name: avatars avatars_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatars
    ADD CONSTRAINT avatars_pkey PRIMARY KEY (id);


--
-- Name: client_avatar_accesses client_avatar_accesses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_accesses
    ADD CONSTRAINT client_avatar_accesses_pkey PRIMARY KEY (id);


--
-- Name: client_avatar_deletions client_avatar_deletions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_deletions
    ADD CONSTRAINT client_avatar_deletions_pkey PRIMARY KEY (id);


--
-- Name: client_avatar_extractions client_avatar_extractions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_extractions
    ADD CONSTRAINT client_avatar_extractions_pkey PRIMARY KEY (id);


--
-- Name: client_avatar_impersonations client_avatar_impersonations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_impersonations
    ADD CONSTRAINT client_avatar_impersonations_pkey PRIMARY KEY (id);


--
-- Name: client_avatar_oversights client_avatar_oversights_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_oversights
    ADD CONSTRAINT client_avatar_oversights_pkey PRIMARY KEY (id);


--
-- Name: client_avatar_suspensions client_avatar_suspensions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_suspensions
    ADD CONSTRAINT client_avatar_suspensions_pkey PRIMARY KEY (id);


--
-- Name: client_avatar_visibilities client_avatar_visibilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_visibilities
    ADD CONSTRAINT client_avatar_visibilities_pkey PRIMARY KEY (id);


--
-- Name: group_avatar_memberships group_avatar_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_avatar_memberships
    ADD CONSTRAINT group_avatar_memberships_pkey PRIMARY KEY (id);


--
-- Name: handle_assignment_statuses handle_assignment_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.handle_assignment_statuses
    ADD CONSTRAINT handle_assignment_statuses_pkey PRIMARY KEY (id);


--
-- Name: handle_assignments handle_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.handle_assignments
    ADD CONSTRAINT handle_assignments_pkey PRIMARY KEY (id);


--
-- Name: handle_statuses handle_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.handle_statuses
    ADD CONSTRAINT handle_statuses_pkey PRIMARY KEY (id);


--
-- Name: handles handles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.handles
    ADD CONSTRAINT handles_pkey PRIMARY KEY (id);


--
-- Name: member_avatar_accesses member_avatar_accesses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_accesses
    ADD CONSTRAINT member_avatar_accesses_pkey PRIMARY KEY (id);


--
-- Name: member_avatar_deletions member_avatar_deletions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_deletions
    ADD CONSTRAINT member_avatar_deletions_pkey PRIMARY KEY (id);


--
-- Name: member_avatar_extractions member_avatar_extractions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_extractions
    ADD CONSTRAINT member_avatar_extractions_pkey PRIMARY KEY (id);


--
-- Name: member_avatar_impersonations member_avatar_impersonations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_impersonations
    ADD CONSTRAINT member_avatar_impersonations_pkey PRIMARY KEY (id);


--
-- Name: member_avatar_oversights member_avatar_oversights_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_oversights
    ADD CONSTRAINT member_avatar_oversights_pkey PRIMARY KEY (id);


--
-- Name: member_avatar_suspensions member_avatar_suspensions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_suspensions
    ADD CONSTRAINT member_avatar_suspensions_pkey PRIMARY KEY (id);


--
-- Name: member_avatar_visibilities member_avatar_visibilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_visibilities
    ADD CONSTRAINT member_avatar_visibilities_pkey PRIMARY KEY (id);


--
-- Name: post_review_statuses post_review_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_review_statuses
    ADD CONSTRAINT post_review_statuses_pkey PRIMARY KEY (id);


--
-- Name: post_reviews post_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_reviews
    ADD CONSTRAINT post_reviews_pkey PRIMARY KEY (id);


--
-- Name: post_statuses post_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_statuses
    ADD CONSTRAINT post_statuses_pkey PRIMARY KEY (id);


--
-- Name: post_versions post_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_versions
    ADD CONSTRAINT post_versions_pkey PRIMARY KEY (id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: idx_avatar_agent_bindings_active_agent; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_avatar_agent_bindings_active_agent ON public.avatar_agent_bindings USING btree (agent_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_avatar_agent_bindings_active_avatar; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_avatar_agent_bindings_active_avatar ON public.avatar_agent_bindings USING btree (avatar_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_avatar_agent_bindings_active_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_avatar_agent_bindings_active_pair ON public.avatar_agent_bindings USING btree (avatar_id, agent_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_avatar_individual_bindings_active_avatar; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_avatar_individual_bindings_active_avatar ON public.avatar_individual_bindings USING btree (avatar_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_avatar_individual_bindings_active_individual; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_avatar_individual_bindings_active_individual ON public.avatar_individual_bindings USING btree (individual_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_avatar_individual_bindings_active_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_avatar_individual_bindings_active_pair ON public.avatar_individual_bindings USING btree (avatar_id, individual_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_avatar_ownership_periods_avatar_id_all_rows; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_avatar_ownership_periods_avatar_id_all_rows ON public.avatar_ownership_periods USING btree (avatar_id);


--
-- Name: idx_avatar_persona_bindings_active_avatar; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_avatar_persona_bindings_active_avatar ON public.avatar_persona_bindings USING btree (avatar_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_avatar_persona_bindings_active_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_avatar_persona_bindings_active_pair ON public.avatar_persona_bindings USING btree (avatar_id, persona_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_avatar_persona_bindings_active_persona; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_avatar_persona_bindings_active_persona ON public.avatar_persona_bindings USING btree (persona_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_group_avatar_memberships_active_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_group_avatar_memberships_active_pair ON public.group_avatar_memberships USING btree (avatar_group_id, avatar_id) WHERE (removed_at IS NULL);


--
-- Name: index_avatar_agent_bindings_on_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_agent_bindings_on_agent_id ON public.avatar_agent_bindings USING btree (agent_id);


--
-- Name: index_avatar_agent_bindings_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_agent_bindings_on_avatar_id ON public.avatar_agent_bindings USING btree (avatar_id);


--
-- Name: index_avatar_agent_bindings_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_avatar_agent_bindings_on_public_id ON public.avatar_agent_bindings USING btree (public_id);


--
-- Name: index_avatar_assignments_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_assignments_on_user_id ON public.avatar_assignments USING btree (user_id);


--
-- Name: index_avatar_assignments_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_avatar_assignments_unique ON public.avatar_assignments USING btree (avatar_id, user_id, role);


--
-- Name: index_avatar_assignments_unique_affiliation; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_avatar_assignments_unique_affiliation ON public.avatar_assignments USING btree (avatar_id) WHERE ((role)::text = 'affiliation'::text);


--
-- Name: index_avatar_assignments_unique_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_avatar_assignments_unique_owner ON public.avatar_assignments USING btree (avatar_id) WHERE ((role)::text = 'owner'::text);


--
-- Name: index_avatar_blocks_on_blocked_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_blocks_on_blocked_avatar_id ON public.avatar_blocks USING btree (blocked_avatar_id);


--
-- Name: index_avatar_blocks_on_blocker_and_blocked_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_avatar_blocks_on_blocker_and_blocked_avatar_id ON public.avatar_blocks USING btree (blocker_avatar_id, blocked_avatar_id);


--
-- Name: index_avatar_blocks_on_blocker_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_blocks_on_blocker_avatar_id ON public.avatar_blocks USING btree (blocker_avatar_id);


--
-- Name: index_avatar_follows_on_followed_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_follows_on_followed_avatar_id ON public.avatar_follows USING btree (followed_avatar_id);


--
-- Name: index_avatar_follows_on_follower_and_followed_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_avatar_follows_on_follower_and_followed_avatar_id ON public.avatar_follows USING btree (follower_avatar_id, followed_avatar_id);


--
-- Name: index_avatar_follows_on_follower_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_follows_on_follower_avatar_id ON public.avatar_follows USING btree (follower_avatar_id);


--
-- Name: index_avatar_groups_on_account_surface_and_account_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_groups_on_account_surface_and_account_public_id ON public.avatar_groups USING btree (account_surface, account_public_id);


--
-- Name: index_avatar_groups_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_avatar_groups_on_public_id ON public.avatar_groups USING btree (public_id);


--
-- Name: index_avatar_individual_bindings_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_individual_bindings_on_avatar_id ON public.avatar_individual_bindings USING btree (avatar_id);


--
-- Name: index_avatar_individual_bindings_on_individual_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_individual_bindings_on_individual_id ON public.avatar_individual_bindings USING btree (individual_id);


--
-- Name: index_avatar_individual_bindings_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_avatar_individual_bindings_on_public_id ON public.avatar_individual_bindings USING btree (public_id);


--
-- Name: index_avatar_lifecycle_events_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_lifecycle_events_on_avatar_id ON public.avatar_lifecycle_events USING btree (avatar_id);


--
-- Name: index_avatar_lifecycle_events_on_avatar_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_lifecycle_events_on_avatar_id_and_created_at ON public.avatar_lifecycle_events USING btree (avatar_id, created_at);


--
-- Name: index_avatar_lifecycle_events_on_changed_by_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_lifecycle_events_on_changed_by_public_id ON public.avatar_lifecycle_events USING btree (changed_by_public_id);


--
-- Name: index_avatar_lifecycle_events_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_lifecycle_events_on_created_at ON public.avatar_lifecycle_events USING btree (created_at);


--
-- Name: index_avatar_lifecycle_states_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_avatar_lifecycle_states_on_key ON public.avatar_lifecycle_states USING btree (key);


--
-- Name: index_avatar_lifecycle_states_on_sort_order; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_avatar_lifecycle_states_on_sort_order ON public.avatar_lifecycle_states USING btree (sort_order);


--
-- Name: index_avatar_memberships_on_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_memberships_on_actor_id ON public.avatar_memberships USING btree (actor_id) WHERE (valid_to = 'infinity'::timestamp with time zone);


--
-- Name: index_avatar_memberships_on_avatar_id_and_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_avatar_memberships_on_avatar_id_and_actor_id ON public.avatar_memberships USING btree (avatar_id, actor_id) WHERE (valid_to = 'infinity'::timestamp with time zone);


--
-- Name: index_avatar_memberships_on_avatar_membership_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_memberships_on_avatar_membership_status_id ON public.avatar_memberships USING btree (avatar_membership_status_id);


--
-- Name: index_avatar_memberships_on_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_memberships_on_role_id ON public.avatar_memberships USING btree (role_id);


--
-- Name: index_avatar_monikers_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_avatar_monikers_on_avatar_id ON public.avatar_monikers USING btree (avatar_id) WHERE (valid_to = 'infinity'::timestamp with time zone);


--
-- Name: index_avatar_monikers_on_avatar_id_and_valid_from; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_monikers_on_avatar_id_and_valid_from ON public.avatar_monikers USING btree (avatar_id, valid_from DESC);


--
-- Name: index_avatar_monikers_on_avatar_moniker_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_monikers_on_avatar_moniker_status_id ON public.avatar_monikers USING btree (avatar_moniker_status_id);


--
-- Name: index_avatar_mutes_on_muted_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_mutes_on_muted_avatar_id ON public.avatar_mutes USING btree (muted_avatar_id);


--
-- Name: index_avatar_mutes_on_muter_and_muted_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_avatar_mutes_on_muter_and_muted_avatar_id ON public.avatar_mutes USING btree (muter_avatar_id, muted_avatar_id);


--
-- Name: index_avatar_mutes_on_muter_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_mutes_on_muter_avatar_id ON public.avatar_mutes USING btree (muter_avatar_id);


--
-- Name: index_avatar_ownership_periods_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_avatar_ownership_periods_on_avatar_id ON public.avatar_ownership_periods USING btree (avatar_id) WHERE (valid_to = 'infinity'::timestamp with time zone);


--
-- Name: index_avatar_ownership_periods_on_avatar_ownership_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_ownership_periods_on_avatar_ownership_status_id ON public.avatar_ownership_periods USING btree (avatar_ownership_status_id);


--
-- Name: index_avatar_ownership_periods_on_owner_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_ownership_periods_on_owner_organization_id ON public.avatar_ownership_periods USING btree (owner_organization_id) WHERE (valid_to = 'infinity'::timestamp with time zone);


--
-- Name: index_avatar_persona_bindings_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_persona_bindings_on_avatar_id ON public.avatar_persona_bindings USING btree (avatar_id);


--
-- Name: index_avatar_persona_bindings_on_persona_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_persona_bindings_on_persona_id ON public.avatar_persona_bindings USING btree (persona_id);


--
-- Name: index_avatar_persona_bindings_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_avatar_persona_bindings_on_public_id ON public.avatar_persona_bindings USING btree (public_id);


--
-- Name: index_avatar_role_permissions_on_avatar_permission_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatar_role_permissions_on_avatar_permission_id ON public.avatar_role_permissions USING btree (avatar_permission_id);


--
-- Name: index_avatars_on_active_handle_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatars_on_active_handle_id ON public.avatars USING btree (active_handle_id);


--
-- Name: index_avatars_on_capability_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatars_on_capability_id ON public.avatars USING btree (capability_id);


--
-- Name: index_avatars_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatars_on_client_id ON public.avatars USING btree (client_id);


--
-- Name: index_avatars_on_lifecycle_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatars_on_lifecycle_state_id ON public.avatars USING btree (lifecycle_state_id);


--
-- Name: index_avatars_on_owner_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatars_on_owner_organization_id ON public.avatars USING btree (owner_organization_id);


--
-- Name: index_avatars_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_avatars_on_public_id ON public.avatars USING btree (public_id);


--
-- Name: index_avatars_on_purge_eligible_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatars_on_purge_eligible_at ON public.avatars USING btree (purge_eligible_at);


--
-- Name: index_avatars_on_representing_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avatars_on_representing_organization_id ON public.avatars USING btree (representing_organization_id);


--
-- Name: index_client_avatar_accesses_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_avatar_accesses_on_avatar_id ON public.client_avatar_accesses USING btree (avatar_id);


--
-- Name: index_client_avatar_accesses_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_avatar_accesses_on_client_id ON public.client_avatar_accesses USING btree (client_id);


--
-- Name: index_client_avatar_accesses_on_client_id_and_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_avatar_accesses_on_client_id_and_avatar_id ON public.client_avatar_accesses USING btree (client_id, avatar_id);


--
-- Name: index_client_avatar_deletions_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_avatar_deletions_on_avatar_id ON public.client_avatar_deletions USING btree (avatar_id);


--
-- Name: index_client_avatar_deletions_on_client_and_avatar; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_avatar_deletions_on_client_and_avatar ON public.client_avatar_deletions USING btree (client_id, avatar_id);


--
-- Name: index_client_avatar_deletions_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_avatar_deletions_on_client_id ON public.client_avatar_deletions USING btree (client_id);


--
-- Name: index_client_avatar_extractions_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_avatar_extractions_on_avatar_id ON public.client_avatar_extractions USING btree (avatar_id);


--
-- Name: index_client_avatar_extractions_on_client_and_avatar; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_avatar_extractions_on_client_and_avatar ON public.client_avatar_extractions USING btree (client_id, avatar_id);


--
-- Name: index_client_avatar_extractions_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_avatar_extractions_on_client_id ON public.client_avatar_extractions USING btree (client_id);


--
-- Name: index_client_avatar_impersonations_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_avatar_impersonations_on_avatar_id ON public.client_avatar_impersonations USING btree (avatar_id);


--
-- Name: index_client_avatar_impersonations_on_client_and_avatar; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_avatar_impersonations_on_client_and_avatar ON public.client_avatar_impersonations USING btree (client_id, avatar_id);


--
-- Name: index_client_avatar_impersonations_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_avatar_impersonations_on_client_id ON public.client_avatar_impersonations USING btree (client_id);


--
-- Name: index_client_avatar_oversights_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_avatar_oversights_on_avatar_id ON public.client_avatar_oversights USING btree (avatar_id);


--
-- Name: index_client_avatar_oversights_on_client_and_avatar; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_avatar_oversights_on_client_and_avatar ON public.client_avatar_oversights USING btree (client_id, avatar_id);


--
-- Name: index_client_avatar_oversights_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_avatar_oversights_on_client_id ON public.client_avatar_oversights USING btree (client_id);


--
-- Name: index_client_avatar_suspensions_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_avatar_suspensions_on_avatar_id ON public.client_avatar_suspensions USING btree (avatar_id);


--
-- Name: index_client_avatar_suspensions_on_client_and_avatar; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_avatar_suspensions_on_client_and_avatar ON public.client_avatar_suspensions USING btree (client_id, avatar_id);


--
-- Name: index_client_avatar_suspensions_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_avatar_suspensions_on_client_id ON public.client_avatar_suspensions USING btree (client_id);


--
-- Name: index_client_avatar_visibilities_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_avatar_visibilities_on_avatar_id ON public.client_avatar_visibilities USING btree (avatar_id);


--
-- Name: index_client_avatar_visibilities_on_client_and_avatar; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_avatar_visibilities_on_client_and_avatar ON public.client_avatar_visibilities USING btree (client_id, avatar_id);


--
-- Name: index_client_avatar_visibilities_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_avatar_visibilities_on_client_id ON public.client_avatar_visibilities USING btree (client_id);


--
-- Name: index_group_avatar_memberships_on_avatar_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_group_avatar_memberships_on_avatar_group_id ON public.group_avatar_memberships USING btree (avatar_group_id);


--
-- Name: index_group_avatar_memberships_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_group_avatar_memberships_on_avatar_id ON public.group_avatar_memberships USING btree (avatar_id);


--
-- Name: index_group_avatar_memberships_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_group_avatar_memberships_on_public_id ON public.group_avatar_memberships USING btree (public_id);


--
-- Name: index_handle_assignments_on_assigned_by_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_handle_assignments_on_assigned_by_actor_id ON public.handle_assignments USING btree (assigned_by_actor_id);


--
-- Name: index_handle_assignments_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_handle_assignments_on_avatar_id ON public.handle_assignments USING btree (avatar_id) WHERE (valid_to = 'infinity'::timestamp with time zone);


--
-- Name: index_handle_assignments_on_avatar_id_and_valid_from; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_handle_assignments_on_avatar_id_and_valid_from ON public.handle_assignments USING btree (avatar_id, valid_from DESC);


--
-- Name: index_handle_assignments_on_handle_assignment_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_handle_assignments_on_handle_assignment_status_id ON public.handle_assignments USING btree (handle_assignment_status_id);


--
-- Name: index_handle_assignments_on_handle_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_handle_assignments_on_handle_id ON public.handle_assignments USING btree (handle_id) WHERE (valid_to = 'infinity'::timestamp with time zone);


--
-- Name: index_handle_assignments_on_handle_id_and_valid_from; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_handle_assignments_on_handle_id_and_valid_from ON public.handle_assignments USING btree (handle_id, valid_from DESC);


--
-- Name: index_handles_on_cooldown_until; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_handles_on_cooldown_until ON public.handles USING btree (cooldown_until);


--
-- Name: index_handles_on_handle_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_handles_on_handle_status_id ON public.handles USING btree (handle_status_id);


--
-- Name: index_handles_on_is_system; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_handles_on_is_system ON public.handles USING btree (is_system);


--
-- Name: index_handles_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_handles_on_public_id ON public.handles USING btree (public_id);


--
-- Name: index_member_avatar_accesses_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_member_avatar_accesses_on_avatar_id ON public.member_avatar_accesses USING btree (avatar_id);


--
-- Name: index_member_avatar_accesses_on_member_id_and_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_member_avatar_accesses_on_member_id_and_avatar_id ON public.member_avatar_accesses USING btree (member_id, avatar_id);


--
-- Name: index_member_avatar_deletions_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_member_avatar_deletions_on_avatar_id ON public.member_avatar_deletions USING btree (avatar_id);


--
-- Name: index_member_avatar_deletions_on_member_id_and_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_member_avatar_deletions_on_member_id_and_avatar_id ON public.member_avatar_deletions USING btree (member_id, avatar_id);


--
-- Name: index_member_avatar_extractions_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_member_avatar_extractions_on_avatar_id ON public.member_avatar_extractions USING btree (avatar_id);


--
-- Name: index_member_avatar_extractions_on_member_id_and_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_member_avatar_extractions_on_member_id_and_avatar_id ON public.member_avatar_extractions USING btree (member_id, avatar_id);


--
-- Name: index_member_avatar_impersonations_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_member_avatar_impersonations_on_avatar_id ON public.member_avatar_impersonations USING btree (avatar_id);


--
-- Name: index_member_avatar_impersonations_on_member_id_and_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_member_avatar_impersonations_on_member_id_and_avatar_id ON public.member_avatar_impersonations USING btree (member_id, avatar_id);


--
-- Name: index_member_avatar_oversights_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_member_avatar_oversights_on_avatar_id ON public.member_avatar_oversights USING btree (avatar_id);


--
-- Name: index_member_avatar_oversights_on_member_id_and_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_member_avatar_oversights_on_member_id_and_avatar_id ON public.member_avatar_oversights USING btree (member_id, avatar_id);


--
-- Name: index_member_avatar_suspensions_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_member_avatar_suspensions_on_avatar_id ON public.member_avatar_suspensions USING btree (avatar_id);


--
-- Name: index_member_avatar_suspensions_on_member_id_and_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_member_avatar_suspensions_on_member_id_and_avatar_id ON public.member_avatar_suspensions USING btree (member_id, avatar_id);


--
-- Name: index_member_avatar_visibilities_on_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_member_avatar_visibilities_on_avatar_id ON public.member_avatar_visibilities USING btree (avatar_id);


--
-- Name: index_member_avatar_visibilities_on_member_id_and_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_member_avatar_visibilities_on_member_id_and_avatar_id ON public.member_avatar_visibilities USING btree (member_id, avatar_id);


--
-- Name: index_post_reviews_on_post_id_and_reviewer_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_reviews_on_post_id_and_reviewer_actor_id ON public.post_reviews USING btree (post_id, reviewer_actor_id);


--
-- Name: index_post_reviews_on_post_review_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_reviews_on_post_review_status_id ON public.post_reviews USING btree (post_review_status_id);


--
-- Name: index_post_reviews_on_reviewer_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_reviews_on_reviewer_actor_id ON public.post_reviews USING btree (reviewer_actor_id) WHERE (decided_at IS NULL);


--
-- Name: index_post_versions_on_post_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_versions_on_post_id_and_created_at ON public.post_versions USING btree (post_id, created_at DESC);


--
-- Name: index_post_versions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_versions_on_public_id ON public.post_versions USING btree (public_id);


--
-- Name: index_posts_on_author_avatar_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_author_avatar_id_and_created_at ON public.posts USING btree (author_avatar_id, created_at DESC);


--
-- Name: index_posts_on_post_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_post_status_id ON public.posts USING btree (post_status_id);


--
-- Name: index_posts_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_posts_on_public_id ON public.posts USING btree (public_id);


--
-- Name: uniq_avatar_role_permissions; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uniq_avatar_role_permissions ON public.avatar_role_permissions USING btree (avatar_role_id, avatar_permission_id);


--
-- Name: uniq_handles_handle_non_system; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uniq_handles_handle_non_system ON public.handles USING btree (handle) WHERE (is_system = false);


--
-- Name: avatar_lifecycle_events fk_avatar_lifecycle_events_from_state_key; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_lifecycle_events
    ADD CONSTRAINT fk_avatar_lifecycle_events_from_state_key FOREIGN KEY (from_state_key) REFERENCES public.avatar_lifecycle_states(key);


--
-- Name: avatar_lifecycle_events fk_avatar_lifecycle_events_to_state_key; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_lifecycle_events
    ADD CONSTRAINT fk_avatar_lifecycle_events_to_state_key FOREIGN KEY (to_state_key) REFERENCES public.avatar_lifecycle_states(key);


--
-- Name: handle_assignments fk_rails_091cd3dea0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.handle_assignments
    ADD CONSTRAINT fk_rails_091cd3dea0 FOREIGN KEY (avatar_id) REFERENCES public.avatars(id);


--
-- Name: avatar_monikers fk_rails_0b04be00c1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_monikers
    ADD CONSTRAINT fk_rails_0b04be00c1 FOREIGN KEY (avatar_id) REFERENCES public.avatars(id);


--
-- Name: posts fk_rails_0c2fab94dc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT fk_rails_0c2fab94dc FOREIGN KEY (post_status_id) REFERENCES public.post_statuses(id);


--
-- Name: group_avatar_memberships fk_rails_1098c365ca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_avatar_memberships
    ADD CONSTRAINT fk_rails_1098c365ca FOREIGN KEY (avatar_id) REFERENCES public.avatars(id) ON DELETE RESTRICT;


--
-- Name: avatars fk_rails_11d7aa8bc0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatars
    ADD CONSTRAINT fk_rails_11d7aa8bc0 FOREIGN KEY (active_handle_id) REFERENCES public.handles(id);


--
-- Name: client_avatar_extractions fk_rails_16e7d13f5a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_extractions
    ADD CONSTRAINT fk_rails_16e7d13f5a FOREIGN KEY (avatar_id) REFERENCES public.avatars(id);


--
-- Name: handles fk_rails_17aa34449d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.handles
    ADD CONSTRAINT fk_rails_17aa34449d FOREIGN KEY (handle_status_id) REFERENCES public.handle_statuses(id);


--
-- Name: avatar_mutes fk_rails_23710bcc08; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_mutes
    ADD CONSTRAINT fk_rails_23710bcc08 FOREIGN KEY (muter_avatar_id) REFERENCES public.avatars(id) ON DELETE CASCADE NOT VALID;


--
-- Name: client_avatar_oversights fk_rails_299c73e8e4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_oversights
    ADD CONSTRAINT fk_rails_299c73e8e4 FOREIGN KEY (avatar_id) REFERENCES public.avatars(id);


--
-- Name: avatar_assignments fk_rails_3d21426314; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_assignments
    ADD CONSTRAINT fk_rails_3d21426314 FOREIGN KEY (avatar_id) REFERENCES public.avatars(id) ON DELETE CASCADE;


--
-- Name: handle_assignments fk_rails_4ba426ebd3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.handle_assignments
    ADD CONSTRAINT fk_rails_4ba426ebd3 FOREIGN KEY (handle_assignment_status_id) REFERENCES public.handle_assignment_statuses(id);


--
-- Name: client_avatar_visibilities fk_rails_4bc5709a56; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_visibilities
    ADD CONSTRAINT fk_rails_4bc5709a56 FOREIGN KEY (avatar_id) REFERENCES public.avatars(id);


--
-- Name: avatar_follows fk_rails_4f8f52feb4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_follows
    ADD CONSTRAINT fk_rails_4f8f52feb4 FOREIGN KEY (follower_avatar_id) REFERENCES public.avatars(id);


--
-- Name: avatar_role_permissions fk_rails_5451469732; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_role_permissions
    ADD CONSTRAINT fk_rails_5451469732 FOREIGN KEY (avatar_role_id) REFERENCES public.avatar_roles(id);


--
-- Name: post_versions fk_rails_5f7c4b6bbb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_versions
    ADD CONSTRAINT fk_rails_5f7c4b6bbb FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: group_avatar_memberships fk_rails_60c73b2b09; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_avatar_memberships
    ADD CONSTRAINT fk_rails_60c73b2b09 FOREIGN KEY (avatar_group_id) REFERENCES public.avatar_groups(id) ON DELETE RESTRICT;


--
-- Name: member_avatar_extractions fk_rails_61c586e4e8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_extractions
    ADD CONSTRAINT fk_rails_61c586e4e8 FOREIGN KEY (avatar_id) REFERENCES public.avatars(id);


--
-- Name: client_avatar_impersonations fk_rails_65c9dc3988; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_impersonations
    ADD CONSTRAINT fk_rails_65c9dc3988 FOREIGN KEY (avatar_id) REFERENCES public.avatars(id);


--
-- Name: avatar_ownership_periods fk_rails_6c57478126; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_ownership_periods
    ADD CONSTRAINT fk_rails_6c57478126 FOREIGN KEY (avatar_ownership_status_id) REFERENCES public.avatar_ownership_statuses(id);


--
-- Name: avatar_lifecycle_events fk_rails_6fde42eb1b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_lifecycle_events
    ADD CONSTRAINT fk_rails_6fde42eb1b FOREIGN KEY (avatar_id) REFERENCES public.avatars(id);


--
-- Name: avatars fk_rails_758523e525; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatars
    ADD CONSTRAINT fk_rails_758523e525 FOREIGN KEY (lifecycle_state_id) REFERENCES public.avatar_lifecycle_states(id);


--
-- Name: posts fk_rails_79a94e151e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT fk_rails_79a94e151e FOREIGN KEY (author_avatar_id) REFERENCES public.avatars(id);


--
-- Name: member_avatar_impersonations fk_rails_7b4afb4521; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_impersonations
    ADD CONSTRAINT fk_rails_7b4afb4521 FOREIGN KEY (avatar_id) REFERENCES public.avatars(id);


--
-- Name: member_avatar_accesses fk_rails_81dad1c5f4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_accesses
    ADD CONSTRAINT fk_rails_81dad1c5f4 FOREIGN KEY (avatar_id) REFERENCES public.avatars(id);


--
-- Name: avatar_blocks fk_rails_8250386a91; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_blocks
    ADD CONSTRAINT fk_rails_8250386a91 FOREIGN KEY (blocker_avatar_id) REFERENCES public.avatars(id) ON DELETE CASCADE NOT VALID;


--
-- Name: avatar_ownership_periods fk_rails_84bbb0d37f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_ownership_periods
    ADD CONSTRAINT fk_rails_84bbb0d37f FOREIGN KEY (avatar_id) REFERENCES public.avatars(id);


--
-- Name: client_avatar_accesses fk_rails_8c98db8fd6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_accesses
    ADD CONSTRAINT fk_rails_8c98db8fd6 FOREIGN KEY (avatar_id) REFERENCES public.avatars(id);


--
-- Name: avatar_blocks fk_rails_903ed2c4c2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_blocks
    ADD CONSTRAINT fk_rails_903ed2c4c2 FOREIGN KEY (blocked_avatar_id) REFERENCES public.avatars(id) ON DELETE CASCADE NOT VALID;


--
-- Name: member_avatar_deletions fk_rails_9444feb810; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_deletions
    ADD CONSTRAINT fk_rails_9444feb810 FOREIGN KEY (avatar_id) REFERENCES public.avatars(id);


--
-- Name: avatar_memberships fk_rails_a87a3bd5c0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_memberships
    ADD CONSTRAINT fk_rails_a87a3bd5c0 FOREIGN KEY (avatar_id) REFERENCES public.avatars(id);


--
-- Name: avatar_monikers fk_rails_b221a42f2d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_monikers
    ADD CONSTRAINT fk_rails_b221a42f2d FOREIGN KEY (avatar_moniker_status_id) REFERENCES public.avatar_moniker_statuses(id);


--
-- Name: avatar_memberships fk_rails_b71dd102ff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_memberships
    ADD CONSTRAINT fk_rails_b71dd102ff FOREIGN KEY (avatar_membership_status_id) REFERENCES public.avatar_membership_statuses(id);


--
-- Name: member_avatar_oversights fk_rails_bca6c873b1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_oversights
    ADD CONSTRAINT fk_rails_bca6c873b1 FOREIGN KEY (avatar_id) REFERENCES public.avatars(id);


--
-- Name: avatar_mutes fk_rails_c0a7894e9b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_mutes
    ADD CONSTRAINT fk_rails_c0a7894e9b FOREIGN KEY (muted_avatar_id) REFERENCES public.avatars(id) ON DELETE CASCADE NOT VALID;


--
-- Name: member_avatar_suspensions fk_rails_c32d6db33a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_suspensions
    ADD CONSTRAINT fk_rails_c32d6db33a FOREIGN KEY (avatar_id) REFERENCES public.avatars(id);


--
-- Name: member_avatar_visibilities fk_rails_c9da4a801f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_avatar_visibilities
    ADD CONSTRAINT fk_rails_c9da4a801f FOREIGN KEY (avatar_id) REFERENCES public.avatars(id);


--
-- Name: post_reviews fk_rails_cf21001c1d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_reviews
    ADD CONSTRAINT fk_rails_cf21001c1d FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: avatar_follows fk_rails_d256033bc4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_follows
    ADD CONSTRAINT fk_rails_d256033bc4 FOREIGN KEY (followed_avatar_id) REFERENCES public.avatars(id);


--
-- Name: avatar_role_permissions fk_rails_d42028fbe6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_role_permissions
    ADD CONSTRAINT fk_rails_d42028fbe6 FOREIGN KEY (avatar_permission_id) REFERENCES public.avatar_permissions(id);


--
-- Name: post_reviews fk_rails_db5004f1f7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_reviews
    ADD CONSTRAINT fk_rails_db5004f1f7 FOREIGN KEY (post_review_status_id) REFERENCES public.post_review_statuses(id);


--
-- Name: avatar_memberships fk_rails_dbdc52efb8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatar_memberships
    ADD CONSTRAINT fk_rails_dbdc52efb8 FOREIGN KEY (role_id) REFERENCES public.avatar_roles(id);


--
-- Name: avatars fk_rails_e0e994d36f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avatars
    ADD CONSTRAINT fk_rails_e0e994d36f FOREIGN KEY (capability_id) REFERENCES public.avatar_capabilities(id);


--
-- Name: handle_assignments fk_rails_f7e5b6b4d6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.handle_assignments
    ADD CONSTRAINT fk_rails_f7e5b6b4d6 FOREIGN KEY (handle_id) REFERENCES public.handles(id);


--
-- Name: client_avatar_suspensions fk_rails_fc7d8e786c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_suspensions
    ADD CONSTRAINT fk_rails_fc7d8e786c FOREIGN KEY (avatar_id) REFERENCES public.avatars(id);


--
-- Name: client_avatar_deletions fk_rails_fefa19eeff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_avatar_deletions
    ADD CONSTRAINT fk_rails_fefa19eeff FOREIGN KEY (avatar_id) REFERENCES public.avatars(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260921133000'),
('20260920152000'),
('20260906000002'),
('20260906000001'),
('20260703010000'),
('20260703000005'),
('20260703000004'),
('20260703000003'),
('20260703000002'),
('20260703000001'),
('20260627000004'),
('20260627000003'),
('20260627000002'),
('20260616150022'),
('20260616150020'),
('20260616150010'),
('20260616150002'),
('20260612000001'),
('20260518044331'),
('20260508151000'),
('20260508140999'),
('20260508135006'),
('20260508000001'),
('20260508000000'),
('20260507000002'),
('20260507000001'),
('20260507000000'),
('20260202260000'),
('20260202210000'),
('20260202150000'),
('20260201214520'),
('20260201160000'),
('20260131150006'),
('20260131150005'),
('20260131150004'),
('20260131150001'),
('20260130030719'),
('20251226013002'),
('20251225200010'),
('20251225200000');

