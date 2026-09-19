# frozen_string_literal: true

# Builds the publishing database: one global media_files table plus twelve
# physical content families (surface x audience). Migration-time iteration over
# the static matrix is schema construction, not runtime polymorphic dispatch.
# rubocop:disable Naming/MethodParameterName
module PublishingSchema
  module_function

  PUBLIC_ID = "char_length(public_id) = 21".freeze
  SLUG = "slug ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'".freeze
  DIGEST = "content_digest ~ '^[0-9a-f]{64}$'".freeze
  AUDIENCES = %w(app com org).freeze
  SURFACES = %w(info docs news help).freeze
  LOCALES = %w(ja en).freeze
  KINDS = %w(single_hierarchical multiple_ordered_flat).freeze
  SINGLE_KIND = "single_hierarchical"
  MULTIPLE_KIND = "multiple_ordered_flat"
  MAX_DEPTH = 8
  FAMILIES = SURFACES.product(AUDIENCES).freeze

  def create_schema(migration)
    migration.enable_extension("btree_gist") unless migration.extension_enabled?("btree_gist")
    create_media_files(migration)
    create_shared_functions(migration)
    FAMILIES.each { |surface, audience| create_family(migration, surface:, audience:) }
  end

  def prefix(surface, audience) = "publishing_#{surface}_#{audience}"

  def short(surface, audience) = "#{surface}_#{audience}"

  def create_family(m, surface:, audience:)
    p = prefix(surface, audience)
    s = short(surface, audience)
    entries = :"#{p}_entries"
    slugs = :"#{p}_entry_slugs"
    revisions = :"#{p}_entry_revisions"
    versions = :"#{p}_entry_versions"
    publications = :"#{p}_publications"
    vocabs = :"#{p}_vocabularies"
    terms = :"#{p}_taxonomy_terms"
    rev_single = :"#{p}_revision_single_taxonomy_assignments"
    rev_multi = :"#{p}_revision_multiple_taxonomy_assignments"
    ver_single = :"#{p}_version_single_taxonomy_assignments"
    ver_multi = :"#{p}_version_multiple_taxonomy_assignments"
    rev_media = :"#{p}_revision_media_usages"
    ver_media = :"#{p}_version_media_usages"

    create_entries(m, entries, s)
    create_slugs(m, slugs, entries, s)
    create_revisions(m, revisions, entries, s)
    add_current_revision(m, entries, revisions, s)
    create_versions(m, versions, entries, revisions, s)
    create_publications(m, publications, entries, versions, s)
    create_vocabularies(m, vocabs, s)
    create_terms(m, terms, vocabs, s)
    create_revision_assignments(m, rev_single, rev_multi, revisions, vocabs, terms, s)
    create_version_assignments(m, ver_single, ver_multi, versions, vocabs, terms, s)
    create_owner_media_usages(m, rev_media, owner: :entry_revision, owner_table: revisions, short: s, kind: "rev")
    create_owner_media_usages(m, ver_media, owner: :entry_version, owner_table: versions, short: s, kind: "ver")
    attach_family_triggers(
      m, s:, terms:, vocabs:, revisions:, versions:,
         rev_single:, rev_multi:, ver_single:, ver_multi:, rev_media:, ver_media:,
    )
  end

  def create_entries(m, table, s)
    m.create_table(table) do |t|
      public_id(t)
      t.string(:locale, null: false)
      archive(t)
      t.integer(:lock_version, null: false, default: 0)
      t.timestamps(null: false)
    end
    finish_public_id(m, table)
    m.add_check_constraint(table, "lock_version >= 0", name: "chk_#{s}_ent_lock")
    archive_check(m, table, s, "ent")
    m.add_index(table, %i(id locale), unique: true, name: "uidx_#{s}_ent_id_locale")
  end

  def create_slugs(m, table, entries, s)
    m.create_table(table) do |t|
      public_id(t)
      t.references(:entry, null: false, foreign_key: { to_table: entries, on_delete: :restrict })
      t.string(:locale, null: false)
      t.string(:slug, null: false)
      t.string(:state, null: false)
      t.datetime(:canonicalized_at)
      t.datetime(:redirected_at)
      t.timestamps(null: false)
    end
    finish_public_id(m, table)
    m.add_index(table, %i(locale slug), unique: true, name: "uidx_#{s}_slug_locale")
    m.add_index(table, :entry_id, unique: true, where: "state = 'reserved'", name: "uidx_#{s}_slug_reserved")
    m.add_index(table, :entry_id, unique: true, where: "state = 'canonical'", name: "uidx_#{s}_slug_canonical")
    m.add_check_constraint(table, "state IN ('reserved','canonical','redirect')", name: "chk_#{s}_slug_state")
    m.add_check_constraint(table, SLUG, name: "chk_#{s}_slug_format")
    m.add_check_constraint(
      table,
      "(state = 'reserved' AND canonicalized_at IS NULL AND redirected_at IS NULL) OR " \
      "(state = 'canonical' AND canonicalized_at IS NOT NULL AND redirected_at IS NULL) OR " \
      "(state = 'redirect' AND canonicalized_at IS NOT NULL AND " \
      "redirected_at IS NOT NULL AND redirected_at >= canonicalized_at)",
      name: "chk_#{s}_slug_ts",
    )
    composite_fk(m, table, %i(entry_id locale), entries, %i(id locale), "fk_#{s}_slug_entry_locale")
  end

  def create_revisions(m, table, entries, s)
    m.create_table(table) do |t|
      public_id(t)
      t.references(:entry, null: false, foreign_key: { to_table: entries, on_delete: :restrict })
      t.bigint(:restored_from_revision_id)
      t.bigint(:restored_from_version_id)
      encrypted_content(t)
      provenance(t)
      t.integer(:sequence, null: false)
      t.timestamps(null: false)
    end
    finish_public_id(m, table)
    m.add_index(table, %i(entry_id sequence), unique: true, name: "uidx_#{s}_rev_seq")
    m.add_index(table, %i(id entry_id), unique: true, name: "uidx_#{s}_rev_id_entry")
    m.add_index(table, %i(id locale), unique: true, name: "uidx_#{s}_rev_id_locale")
    m.add_index(table, %i(id entry_id locale), unique: true, name: "uidx_#{s}_rev_id_entry_locale")
    content_checks(m, table, s, "rev")
    m.add_check_constraint(table, "sequence > 0", name: "chk_#{s}_rev_seq")
    m.add_check_constraint(
      table, "num_nonnulls(restored_from_revision_id, restored_from_version_id) <= 1",
      name: "chk_#{s}_rev_restore",
    )
    m.add_foreign_key(
      table, table, column: %i(restored_from_revision_id entry_id), primary_key: %i(id entry_id),
                    on_delete: :restrict, name: "fk_#{s}_rev_restore_rev",
    )
    composite_fk(m, table, %i(entry_id locale), entries, %i(id locale), "fk_#{s}_rev_entry_locale")
  end

  def add_current_revision(m, entries, revisions, s)
    m.add_column(entries, :current_revision_id, :bigint)
    m.add_index(entries, :current_revision_id, unique: true, name: "uidx_#{s}_ent_current_rev")
    m.add_foreign_key(
      entries, revisions, column: %i(current_revision_id id), primary_key: %i(id entry_id),
                          on_delete: :restrict, name: "fk_#{s}_ent_current_rev",
    )
  end

  def create_versions(m, table, entries, revisions, s)
    m.create_table(table) do |t|
      public_id(t)
      t.references(:entry, null: false, foreign_key: { to_table: entries, on_delete: :restrict })
      t.references(:entry_revision, null: false, index: false)
      encrypted_content(t)
      provenance(t)
      t.integer(:sequence, null: false)
      t.timestamps(null: false)
    end
    finish_public_id(m, table)
    m.add_index(table, %i(entry_id sequence), unique: true, name: "uidx_#{s}_ver_seq")
    m.add_index(table, :entry_revision_id, unique: true, name: "uidx_#{s}_ver_on_revision")
    m.add_index(table, %i(id entry_id), unique: true, name: "uidx_#{s}_ver_id_entry")
    m.add_index(table, %i(id locale), unique: true, name: "uidx_#{s}_ver_id_locale")
    m.add_index(table, %i(id entry_id locale), unique: true, name: "uidx_#{s}_ver_id_entry_locale")
    m.add_foreign_key(
      table, revisions, column: %i(entry_revision_id entry_id), primary_key: %i(id entry_id),
                        on_delete: :restrict, name: "fk_#{s}_ver_revision_entry",
    )
    composite_fk(m, table, %i(entry_id locale), entries, %i(id locale), "fk_#{s}_ver_entry_locale")
    content_checks(m, table, s, "ver")
    m.add_check_constraint(table, "sequence > 0", name: "chk_#{s}_ver_seq")
    m.add_foreign_key(
      revisions, table, column: %i(restored_from_version_id entry_id), primary_key: %i(id entry_id),
                        on_delete: :restrict, name: "fk_#{s}_rev_restore_ver",
    )
  end

  def create_publications(m, table, entries, versions, s)
    m.create_table(table) do |t|
      public_id(t)
      t.references(:entry, null: false, foreign_key: { to_table: entries, on_delete: :restrict })
      t.references(:entry_version, null: false)
      t.datetime(:effective_from, null: false)
      t.datetime(:effective_until)
      t.datetime(:cancelled_at)
      t.string(:cancellation_reason)
      t.datetime(:terminated_at)
      t.string(:termination_reason)
      provenance(t)
      t.timestamps(null: false)
    end
    finish_public_id(m, table)
    m.add_foreign_key(
      table, versions, column: %i(entry_version_id entry_id), primary_key: %i(id entry_id),
                       on_delete: :restrict, name: "fk_#{s}_pub_version_entry",
    )
    m.add_check_constraint(
      table, "effective_until IS NULL OR effective_until > effective_from",
      name: "chk_#{s}_pub_window",
    )
    m.add_check_constraint(
      table, "NOT (cancelled_at IS NOT NULL AND terminated_at IS NOT NULL)",
      name: "chk_#{s}_pub_end_mode",
    )
    m.add_check_constraint(
      table,
      "(cancelled_at IS NULL AND cancellation_reason IS NULL) OR " \
      "(cancelled_at IS NOT NULL AND cancellation_reason IS NOT NULL AND cancelled_at < effective_from)",
      name: "chk_#{s}_pub_cancel",
    )
    m.add_check_constraint(
      table,
      "(terminated_at IS NULL AND termination_reason IS NULL) OR " \
      "(terminated_at IS NOT NULL AND termination_reason IS NOT NULL AND " \
      "terminated_at >= effective_from AND effective_until = terminated_at)",
      name: "chk_#{s}_pub_term",
    )
    m.add_exclusion_constraint(
      table,
      "entry_id WITH =, tstzrange(effective_from, effective_until, '[)') WITH &&",
      using: :gist, where: "cancelled_at IS NULL",
      name: "excl_#{s}_pub_windows",
    )
  end

  def create_vocabularies(m, table, s)
    m.create_table(table) do |t|
      public_id(t)
      t.string(:key, null: false)
      t.string(:kind, null: false)
      t.string(:internal_name, null: false)
      t.text(:description)
      archive(t)
      t.timestamps(null: false)
    end
    finish_public_id(m, table)
    m.add_check_constraint(table, "kind IN (#{quoted_list(KINDS)})", name: "chk_#{s}_voc_kind")
    m.add_check_constraint(table, "btrim(key) <> '' AND key ~ '^[a-z][a-z0-9_]*$'", name: "chk_#{s}_voc_key")
    m.add_check_constraint(table, "btrim(internal_name) <> ''", name: "chk_#{s}_voc_name")
    archive_check(m, table, s, "voc")
    m.add_index(table, :key, unique: true, name: "uidx_#{s}_voc_key")
    m.add_index(table, %i(id kind), unique: true, name: "uidx_#{s}_voc_id_kind")
  end

  def create_terms(m, table, vocabs, s)
    m.create_table(table) do |t|
      public_id(t)
      t.references(:vocabulary, null: false, foreign_key: { to_table: vocabs, on_delete: :restrict })
      t.string(:vocabulary_kind, null: false)
      t.string(:locale, null: false)
      t.string(:slug, null: false)
      t.string(:name, null: false)
      t.bigint(:parent_id)
      t.integer(:depth, null: false, default: 0)
      t.integer(:position, null: false, default: 0)
      archive(t)
      t.timestamps(null: false)
    end
    finish_public_id(m, table)
    term_guards(m, table, vocabs, s)
  end

  def term_guards(m, table, vocabs, s)
    m.add_check_constraint(table, "locale IN (#{quoted_list(LOCALES)})", name: "chk_#{s}_term_locale")
    m.add_check_constraint(table, "vocabulary_kind IN (#{quoted_list(KINDS)})", name: "chk_#{s}_term_kind")
    m.add_check_constraint(table, "btrim(slug) <> '' AND #{SLUG}", name: "chk_#{s}_term_slug")
    m.add_check_constraint(table, "btrim(name) <> ''", name: "chk_#{s}_term_name")
    m.add_check_constraint(table, "depth BETWEEN 0 AND #{MAX_DEPTH}", name: "chk_#{s}_term_depth")
    m.add_check_constraint(table, "position >= 0", name: "chk_#{s}_term_pos")
    m.add_check_constraint(table, "parent_id IS NULL OR parent_id <> id", name: "chk_#{s}_term_not_self")
    m.add_check_constraint(
      table,
      "(parent_id IS NULL AND depth = 0) OR (parent_id IS NOT NULL AND depth > 0)",
      name: "chk_#{s}_term_root_depth",
    )
    m.add_check_constraint(
      table,
      "vocabulary_kind <> '#{MULTIPLE_KIND}' OR (parent_id IS NULL AND depth = 0)",
      name: "chk_#{s}_term_flat",
    )
    archive_check(m, table, s, "term")
    m.add_index(table, %i(vocabulary_id locale slug), unique: true, name: "uidx_#{s}_term_slug")
    m.add_index(table, %i(id vocabulary_id locale), unique: true, name: "uidx_#{s}_term_scope")
    m.add_index(table, :parent_id, name: "idx_#{s}_term_parent")
    table_ref = "public.#{table}"
    m.execute(<<~SQL.squish)
      CREATE UNIQUE INDEX uidx_#{s}_term_sib_pos
      ON #{table_ref} (vocabulary_id, locale, parent_id, position)
      NULLS NOT DISTINCT
    SQL
    m.add_foreign_key(
      table, vocabs, column: %i(vocabulary_id vocabulary_kind), primary_key: %i(id kind),
                     on_delete: :restrict, name: "fk_#{s}_term_voc_kind",
    )
    m.add_foreign_key(
      table, table, column: %i(parent_id vocabulary_id locale), primary_key: %i(id vocabulary_id locale),
                    on_delete: :restrict, name: "fk_#{s}_term_parent_scope",
    )
  end

  def create_revision_assignments(m, single, multiple, revisions, vocabs, terms, s)
    create_assignment_table(
      m, single, owner: :entry_revision, owner_table: revisions, vocabs:, terms:, s:,
                 kind: SINGLE_KIND, ordered: false, prefix: "rs",
    )
    create_assignment_table(
      m, multiple, owner: :entry_revision, owner_table: revisions, vocabs:, terms:, s:,
                   kind: MULTIPLE_KIND, ordered: true, prefix: "rm",
    )
  end

  def create_version_assignments(m, single, multiple, versions, vocabs, terms, s)
    create_assignment_table(
      m, single, owner: :entry_version, owner_table: versions, vocabs:, terms:, s:,
                 kind: SINGLE_KIND, ordered: false, prefix: "vs", snapshot: true,
    )
    create_assignment_table(
      m, multiple, owner: :entry_version, owner_table: versions, vocabs:, terms:, s:,
                   kind: MULTIPLE_KIND, ordered: true, prefix: "vm", snapshot: true,
    )
  end

  def create_assignment_table(m, table, owner:, owner_table:, vocabs:, terms:, s:, kind:, ordered:, prefix:,
                              snapshot: false)
    m.create_table(table) do |t|
      t.references(owner, null: false, index: false)
      t.references(:vocabulary, null: false, index: false)
      t.string(:vocabulary_kind, null: false)
      t.references(:taxonomy_term, null: false, index: false)
      t.string(:locale, null: false)
      t.integer(:position, null: false) if ordered
      if snapshot
        snapshot_columns(t)
        t.integer(:position_snapshot, null: false) if ordered
      end
      t.timestamps(null: false)
    end
    assignment_guards(m, table, owner:, owner_table:, vocabs:, terms:, s:, kind:, ordered:, prefix:, snapshot:)
  end

  def assignment_guards(m, table, owner:, owner_table:, vocabs:, terms:, s:, kind:, ordered:, prefix:, snapshot:)
    m.add_check_constraint(table, "vocabulary_kind = '#{kind}'", name: "chk_#{s}_#{prefix}_kind")
    if ordered
      m.add_check_constraint(
        table,
        snapshot ? "position >= 0 AND position_snapshot >= 0" : "position >= 0",
        name: "chk_#{s}_#{prefix}_pos",
      )
      m.add_index(
        table, [:"#{owner}_id", :vocabulary_id, :taxonomy_term_id],
        unique: true, name: "uidx_#{s}_#{prefix}_term",
      )
      m.add_index(
        table, [:"#{owner}_id", :vocabulary_id, :position],
        unique: true, name: "uidx_#{s}_#{prefix}_pos",
      )
    else
      m.add_index(table, [:"#{owner}_id", :vocabulary_id], unique: true, name: "uidx_#{s}_#{prefix}_owner")
    end
    m.add_index(table, :taxonomy_term_id, name: "idx_#{s}_#{prefix}_term")
    m.add_index(table, :vocabulary_id, name: "idx_#{s}_#{prefix}_voc")
    if snapshot
      snapshot_checks(m, table, s, prefix)
      m.add_index(
        table, %i(vocabulary_key_snapshot term_slug_snapshot locale_snapshot),
        name: "idx_#{s}_#{prefix}_filter",
      )
    end
    m.add_foreign_key(
      table, owner_table, column: [:"#{owner}_id", :locale], primary_key: %i(id locale),
                          on_delete: :restrict, name: "fk_#{s}_#{prefix}_owner_locale",
    )
    m.add_foreign_key(
      table, vocabs, column: %i(vocabulary_id vocabulary_kind), primary_key: %i(id kind),
                     on_delete: :restrict, name: "fk_#{s}_#{prefix}_voc_kind",
    )
    m.add_foreign_key(
      table, terms, column: %i(taxonomy_term_id vocabulary_id locale),
                    primary_key: %i(id vocabulary_id locale),
                    on_delete: :restrict, name: "fk_#{s}_#{prefix}_term_scope",
    )
  end

  def snapshot_columns(t)
    t.string(:vocabulary_public_id_snapshot, limit: 21, null: false)
    t.string(:vocabulary_key_snapshot, null: false)
    t.string(:vocabulary_kind_snapshot, null: false)
    t.string(:term_public_id_snapshot, limit: 21, null: false)
    t.string(:term_slug_snapshot, null: false)
    t.string(:term_name_snapshot, null: false)
    t.jsonb(:term_path_snapshot, null: false)
    t.string(:locale_snapshot, null: false)
  end

  def snapshot_checks(m, table, s, prefix)
    m.add_check_constraint(table, "char_length(vocabulary_public_id_snapshot) = 21", name: "chk_#{s}_#{prefix}_vp")
    m.add_check_constraint(table, "char_length(term_public_id_snapshot) = 21", name: "chk_#{s}_#{prefix}_tp")
    m.add_check_constraint(table, "vocabulary_kind_snapshot IN (#{quoted_list(KINDS)})", name: "chk_#{s}_#{prefix}_ks")
    m.add_check_constraint(table, "locale_snapshot IN (#{quoted_list(LOCALES)})", name: "chk_#{s}_#{prefix}_ls")
    m.add_check_constraint(
      table,
      "btrim(vocabulary_key_snapshot) <> '' AND btrim(term_slug_snapshot) <> '' AND btrim(term_name_snapshot) <> ''",
      name: "chk_#{s}_#{prefix}_snap",
    )
    m.add_check_constraint(table, "publishing_valid_term_path(term_path_snapshot)", name: "chk_#{s}_#{prefix}_path")
  end

  def create_media_files(m)
    files = :publishing_media_files
    m.create_table(files) do |t|
      public_id(t)
      t.string(:storage_key, null: false)
      t.string(:content_type, null: false)
      t.bigint(:byte_size, null: false)
      t.string(:digest_algorithm, null: false)
      t.string(:digest, null: false)
      t.integer(:width)
      t.integer(:height)
      t.jsonb(:metadata, null: false, default: {})
      archive(t)
      t.datetime(:purged_at)
      t.timestamps(null: false)
    end
    finish_public_id(m, files)
    m.add_index(files, :storage_key, unique: true)
    m.add_check_constraint(files, "byte_size >= 0", name: "chk_publishing_media_size")
    m.add_check_constraint(
      files, "digest_algorithm = 'sha256' AND digest ~ '^[0-9a-f]{64}$'",
      name: "chk_publishing_media_digest",
    )
    m.add_check_constraint(
      files, "(width IS NULL AND height IS NULL) OR (width > 0 AND height > 0)",
      name: "chk_publishing_media_dimensions",
    )
    m.add_check_constraint(files, "jsonb_typeof(metadata) = 'object'", name: "chk_publishing_media_metadata")
    m.add_check_constraint(
      files,
      "(archived_at IS NULL AND archive_reason IS NULL) OR " \
      "(archived_at IS NOT NULL AND archive_reason IS NOT NULL)",
      name: "chk_publishing_media_archive",
    )
  end

  def create_owner_media_usages(m, table, owner:, owner_table:, short:, kind:)
    owner_id = :"#{owner}_id"
    m.create_table(table) do |t|
      public_id(t)
      t.references(:media_file, null: false, foreign_key: { to_table: :publishing_media_files, on_delete: :restrict })
      t.references(owner, null: false, foreign_key: { to_table: owner_table, on_delete: :restrict })
      t.string(:role, null: false)
      t.string(:field_path)
      t.string(:block_path)
      t.integer(:position, null: false, default: 0)
      t.string(:alt_text)
      t.text(:caption)
      t.jsonb(:presentation_metadata)
      t.timestamps(null: false)
    end
    finish_public_id(m, table)
    m.add_check_constraint(table, "position >= 0", name: "chk_#{short}_#{kind}_media_pos")
    m.add_check_constraint(
      table, "field_path IS NOT NULL OR block_path IS NOT NULL",
      name: "chk_#{short}_#{kind}_media_path",
    )
    m.add_check_constraint(
      table, "presentation_metadata IS NULL OR jsonb_typeof(presentation_metadata) = 'object'",
      name: "chk_#{short}_#{kind}_media_pres",
    )
    m.add_index(
      table, [owner_id, :role, :field_path, :block_path, :position],
      unique: true, name: "uidx_#{short}_#{kind}_media_pos",
    )
  end

  SHARED_VALID_TERM_PATH_SQL = <<~SQL.squish
    CREATE FUNCTION publishing_valid_term_path(path jsonb) RETURNS boolean AS $$
      SELECT jsonb_typeof(path) = 'array' AND NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(path) AS element(value)
        WHERE jsonb_typeof(element.value) <> 'object'
           OR jsonb_typeof(element.value -> 'public_id') IS DISTINCT FROM 'string'
           OR jsonb_typeof(element.value -> 'slug') IS DISTINCT FROM 'string'
           OR jsonb_typeof(element.value -> 'name') IS DISTINCT FROM 'string'
           OR (SELECT count(*) FROM jsonb_object_keys(element.value)) <> 3
      );
    $$ LANGUAGE sql IMMUTABLE SET search_path = pg_catalog, public;
  SQL
  SHARED_REJECT_MUTATION_SQL = <<~SQL.squish
    CREATE FUNCTION publishing_reject_mutation() RETURNS trigger AS $$
    BEGIN
      RAISE EXCEPTION 'publishing: % is immutable (attempted %)', TG_TABLE_NAME, TG_OP;
    END;
    $$ LANGUAGE plpgsql SET search_path = pg_catalog, public;
  SQL
  SHARED_REJECT_RETIREMENT_BY_DELETION_SQL = <<~SQL.squish
    CREATE FUNCTION publishing_reject_retirement_by_deletion() RETURNS trigger AS $$
    BEGIN
      RAISE EXCEPTION
        'publishing taxonomy: % rows are retired by archiving, never deleted (id %)',
        TG_TABLE_NAME, OLD.id
        USING ERRCODE = 'restrict_violation';
    END;
    $$ LANGUAGE plpgsql SET search_path = pg_catalog, public;
  SQL
  SHARED_VOCABULARY_STRUCTURE_GUARD_SQL = <<~SQL.squish
    CREATE FUNCTION publishing_vocabulary_structure_guard() RETURNS trigger AS $$
    BEGIN
      IF NEW.public_id IS DISTINCT FROM OLD.public_id
         OR NEW.key IS DISTINCT FROM OLD.key
         OR NEW.kind IS DISTINCT FROM OLD.kind THEN
        RAISE EXCEPTION
          'publishing taxonomy: vocabulary % public_id, key, and kind are frozen after insert',
          OLD.id
          USING ERRCODE = 'restrict_violation';
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql SET search_path = pg_catalog, public;
  SQL
  SHARED_TAXONOMY_TERM_HIERARCHY_GUARD_SQL = <<~SQL.squish
    CREATE FUNCTION publishing_taxonomy_term_hierarchy_guard() RETURNS trigger AS $$
    DECLARE
      terms_table text := TG_ARGV[0];
      parent_depth integer;
      cycle_found boolean;
    BEGIN
      IF NEW.parent_id IS NULL THEN RETURN NEW; END IF;
      EXECUTE format('SELECT depth FROM public.%I WHERE id = $1', terms_table)
        INTO parent_depth USING NEW.parent_id;
      IF parent_depth IS NULL THEN
        RAISE EXCEPTION 'publishing taxonomy: parent term % not found', NEW.parent_id;
      END IF;
      IF NEW.depth <> parent_depth + 1 THEN
        RAISE EXCEPTION 'publishing taxonomy: depth % must equal parent depth % plus one', NEW.depth, parent_depth;
      END IF;
      EXECUTE format(
        'SELECT EXISTS (
           WITH RECURSIVE ancestors(id, parent_id, level) AS (
             SELECT t.id, t.parent_id, 1 FROM public.%I t WHERE t.id = $1
             UNION ALL
             SELECT t.id, t.parent_id, a.level + 1
             FROM public.%I t JOIN ancestors a ON t.id = a.parent_id
             WHERE a.level <= %s + 1
           )
           SELECT 1 FROM ancestors WHERE id = $2
         )', terms_table, terms_table, #{MAX_DEPTH})
        INTO cycle_found USING NEW.parent_id, NEW.id;
      IF cycle_found THEN
        RAISE EXCEPTION 'publishing taxonomy: term % cannot descend from itself', NEW.id;
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql SET search_path = pg_catalog, public;
  SQL
  SHARED_TAXONOMY_TERM_PATH_SQL = <<~SQL.squish
    CREATE FUNCTION publishing_taxonomy_term_path(terms_table text, target_id bigint) RETURNS jsonb AS $$
    DECLARE result jsonb;
    BEGIN
      EXECUTE format(
        $q$
        WITH RECURSIVE chain(id, parent_id, public_id, slug, name, level) AS (
          SELECT t.id, t.parent_id, t.public_id, t.slug, t.name, 0
          FROM public.%I t WHERE t.id = $1
          UNION ALL
          SELECT t.id, t.parent_id, t.public_id, t.slug, t.name, c.level + 1
          FROM public.%I t JOIN chain c ON t.id = c.parent_id
        )
        SELECT coalesce(
          jsonb_agg(jsonb_build_object('public_id', public_id, 'slug', slug, 'name', name) ORDER BY level DESC),
          '[]'::jsonb
        )
        FROM chain
        $q$, terms_table, terms_table)
        INTO result USING target_id;
      RETURN result;
    END;
    $$ LANGUAGE plpgsql STABLE SET search_path = pg_catalog, public;
  SQL
  SHARED_VERSION_ASSIGNMENT_SNAPSHOT_SQL = <<~SQL.squish
    CREATE FUNCTION publishing_version_assignment_snapshot() RETURNS trigger AS $$
    DECLARE
      vocab_table text := TG_ARGV[0];
      terms_table text := TG_ARGV[1];
      ordered boolean := TG_ARGV[2] = 'ordered';
      vocabulary_public_id text;
      vocabulary_key text;
      vocabulary_kind text;
      term_public_id text;
      term_slug text;
      term_name text;
      term_locale text;
    BEGIN
      EXECUTE format('SELECT public_id, key, kind FROM public.%I WHERE id = $1', vocab_table)
        INTO vocabulary_public_id, vocabulary_key, vocabulary_kind USING NEW.vocabulary_id;
      EXECUTE format('SELECT public_id, slug, name, locale FROM public.%I WHERE id = $1', terms_table)
        INTO term_public_id, term_slug, term_name, term_locale USING NEW.taxonomy_term_id;
      IF vocabulary_public_id IS NULL OR term_public_id IS NULL THEN
        RAISE EXCEPTION 'publishing taxonomy: cannot snapshot a missing vocabulary or term'
          USING ERRCODE = 'foreign_key_violation';
      END IF;
      NEW.vocabulary_public_id_snapshot := vocabulary_public_id;
      NEW.vocabulary_key_snapshot := vocabulary_key;
      NEW.vocabulary_kind_snapshot := vocabulary_kind;
      NEW.term_public_id_snapshot := term_public_id;
      NEW.term_slug_snapshot := term_slug;
      NEW.term_name_snapshot := term_name;
      NEW.term_path_snapshot := publishing_taxonomy_term_path(terms_table, NEW.taxonomy_term_id);
      NEW.locale_snapshot := term_locale;
      IF ordered THEN
        NEW.position_snapshot := NEW.position;
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql SET search_path = pg_catalog, public;
  SQL
  SHARED_ASSERT_VERSION_SNAPSHOT_COMPLETE_SQL = <<~SQL.squish
    CREATE FUNCTION publishing_assert_version_snapshot_complete() RETURNS trigger AS $$
    DECLARE
      versions_table text := TG_ARGV[0];
      rev_single text := TG_ARGV[1];
      ver_single text := TG_ARGV[2];
      rev_multi text := TG_ARGV[3];
      ver_multi text := TG_ARGV[4];
      target_version_id bigint;
      source_revision_id bigint;
      mismatch integer;
    BEGIN
      IF TG_TABLE_NAME = versions_table THEN
        target_version_id := NEW.id;
      ELSE
        target_version_id := NEW.entry_version_id;
      END IF;
      EXECUTE format('SELECT entry_revision_id FROM public.%I WHERE id = $1', versions_table)
        INTO source_revision_id USING target_version_id;
      IF source_revision_id IS NULL THEN RETURN NULL; END IF;
      EXECUTE format(
        'SELECT count(*) FROM (
           (SELECT vocabulary_id, taxonomy_term_id FROM public.%I WHERE entry_revision_id = $1
            EXCEPT ALL
            SELECT vocabulary_id, taxonomy_term_id FROM public.%I WHERE entry_version_id = $2)
           UNION ALL
           (SELECT vocabulary_id, taxonomy_term_id FROM public.%I WHERE entry_version_id = $2
            EXCEPT ALL
            SELECT vocabulary_id, taxonomy_term_id FROM public.%I WHERE entry_revision_id = $1)
         ) d', rev_single, ver_single, ver_single, rev_single)
        INTO mismatch USING source_revision_id, target_version_id;
      IF mismatch > 0 THEN
        RAISE EXCEPTION
          'publishing taxonomy: version % single-valued snapshots do not match revision %',
          target_version_id, source_revision_id
          USING ERRCODE = 'integrity_constraint_violation';
      END IF;
      EXECUTE format(
        'SELECT count(*) FROM (
           (SELECT vocabulary_id, taxonomy_term_id, position FROM public.%I WHERE entry_revision_id = $1
            EXCEPT ALL
            SELECT vocabulary_id, taxonomy_term_id, position FROM public.%I WHERE entry_version_id = $2)
           UNION ALL
           (SELECT vocabulary_id, taxonomy_term_id, position FROM public.%I WHERE entry_version_id = $2
            EXCEPT ALL
            SELECT vocabulary_id, taxonomy_term_id, position FROM public.%I WHERE entry_revision_id = $1)
         ) d', rev_multi, ver_multi, ver_multi, rev_multi)
        INTO mismatch USING source_revision_id, target_version_id;
      IF mismatch > 0 THEN
        RAISE EXCEPTION
          'publishing taxonomy: version % ordered snapshots do not match revision %',
          target_version_id, source_revision_id
          USING ERRCODE = 'integrity_constraint_violation';
      END IF;
      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql SET search_path = pg_catalog, public;
  SQL
  SHARED_ASSERT_VERSION_MEDIA_COMPLETE_SQL = <<~SQL.squish
    CREATE FUNCTION publishing_assert_version_media_complete() RETURNS trigger AS $$
    DECLARE
      versions_table text := TG_ARGV[0];
      rev_media text := TG_ARGV[1];
      ver_media text := TG_ARGV[2];
      target_version_id bigint;
      source_revision_id bigint;
      mismatch integer;
    BEGIN
      IF TG_TABLE_NAME = versions_table THEN
        target_version_id := NEW.id;
      ELSE
        target_version_id := NEW.entry_version_id;
      END IF;
      EXECUTE format('SELECT entry_revision_id FROM public.%I WHERE id = $1', versions_table)
        INTO source_revision_id USING target_version_id;
      IF source_revision_id IS NULL THEN RETURN NULL; END IF;
      EXECUTE format(
        'SELECT count(*) FROM (
           (SELECT media_file_id, role, field_path, block_path, position, alt_text, caption, presentation_metadata
            FROM public.%I WHERE entry_revision_id = $1
            EXCEPT ALL
            SELECT media_file_id, role, field_path, block_path, position, alt_text, caption, presentation_metadata
            FROM public.%I WHERE entry_version_id = $2)
           UNION ALL
           (SELECT media_file_id, role, field_path, block_path, position, alt_text, caption, presentation_metadata
            FROM public.%I WHERE entry_version_id = $2
            EXCEPT ALL
            SELECT media_file_id, role, field_path, block_path, position, alt_text, caption, presentation_metadata
            FROM public.%I WHERE entry_revision_id = $1)
         ) d', rev_media, ver_media, ver_media, rev_media)
        INTO mismatch USING source_revision_id, target_version_id;
      IF mismatch > 0 THEN
        RAISE EXCEPTION
          'publishing media: version % usages do not match revision %',
          target_version_id, source_revision_id
          USING ERRCODE = 'integrity_constraint_violation';
      END IF;
      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql SET search_path = pg_catalog, public;
  SQL
  SHARED_PROMOTED_REVISION_GUARD_SQL = <<~SQL.squish
    CREATE FUNCTION publishing_promoted_revision_guard() RETURNS trigger AS $$
    DECLARE
      versions_table text := TG_ARGV[0];
      subject_revision_id bigint;
      promoted_version_id bigint;
    BEGIN
      IF TG_TABLE_NAME LIKE '%entry_revisions' THEN
        IF TG_OP = 'DELETE' THEN subject_revision_id := OLD.id;
        ELSE subject_revision_id := NEW.id;
        END IF;
      ELSIF TG_OP = 'DELETE' THEN
        subject_revision_id := OLD.entry_revision_id;
      ELSE
        subject_revision_id := NEW.entry_revision_id;
      END IF;
      EXECUTE format('SELECT id FROM public.%I WHERE entry_revision_id = $1', versions_table)
        INTO promoted_version_id USING subject_revision_id;
      IF promoted_version_id IS NOT NULL THEN
        RAISE EXCEPTION
          'publishing: revision % was promoted into version % and can no longer change (attempted % on %)',
          subject_revision_id, promoted_version_id, TG_OP, TG_TABLE_NAME
          USING ERRCODE = 'restrict_violation';
      END IF;
      IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql SET search_path = pg_catalog, public;
  SQL

  SHARED_FUNCTION_SQL = [
    SHARED_VALID_TERM_PATH_SQL,
    SHARED_REJECT_MUTATION_SQL,
    SHARED_REJECT_RETIREMENT_BY_DELETION_SQL,
    SHARED_VOCABULARY_STRUCTURE_GUARD_SQL,
    SHARED_TAXONOMY_TERM_HIERARCHY_GUARD_SQL,
    SHARED_TAXONOMY_TERM_PATH_SQL,
    SHARED_VERSION_ASSIGNMENT_SNAPSHOT_SQL,
    SHARED_ASSERT_VERSION_SNAPSHOT_COMPLETE_SQL,
    SHARED_ASSERT_VERSION_MEDIA_COMPLETE_SQL,
    SHARED_PROMOTED_REVISION_GUARD_SQL,
  ].freeze

  def create_shared_functions(m)
    SHARED_FUNCTION_SQL.each { |sql| m.execute(sql) }
  end

  def attach_family_triggers(m, s:, terms:, vocabs:, revisions:, versions:, rev_single:, rev_multi:, ver_single:,
                             ver_multi:, rev_media:, ver_media:)
    trigger_hierarchy(m, s:, terms:)
    trigger_no_delete(m, s:, tag: "voc", table: vocabs)
    trigger_no_delete(m, s:, tag: "term", table: terms)
    trigger_structure(m, s:, vocabs:)
    trigger_assignment_snapshot(m, s:, vocabs:, terms:, ver_single:, ver_multi:)
    trigger_snapshot_complete(m, s:, versions:, rev_single:, ver_single:, rev_multi:, ver_multi:)
    trigger_media_complete(m, s:, versions:, rev_media:, ver_media:)
    trigger_immutable(m, s:, versions:, ver_single:, ver_multi:, ver_media:)
    trigger_promoted_revision(m, s:, revisions:, versions:)
    trigger_promoted_revision_for_usages(m, s:, versions:, rev_single:, rev_multi:, rev_media:)
  end

  def trigger_hierarchy(m, s:, terms:)
    m.execute(<<~SQL.squish)
      CREATE TRIGGER trg_#{s}_terms_hierarchy
      BEFORE INSERT OR UPDATE ON #{terms}
      FOR EACH ROW EXECUTE FUNCTION publishing_taxonomy_term_hierarchy_guard('#{terms}');
    SQL
  end

  def trigger_no_delete(m, s:, tag:, table:)
    table_ref = "public.#{table}"
    m.execute(<<~SQL.squish)
      CREATE TRIGGER trg_#{s}_#{tag}_no_delete
      BEFORE DELETE ON #{table_ref}
      FOR EACH ROW EXECUTE FUNCTION publishing_reject_retirement_by_deletion();
    SQL
  end

  def trigger_structure(m, s:, vocabs:)
    vocabs_ref = "public.#{vocabs}"
    m.execute(<<~SQL.squish)
      CREATE TRIGGER trg_#{s}_voc_structure
      BEFORE UPDATE ON #{vocabs_ref}
      FOR EACH ROW EXECUTE FUNCTION publishing_vocabulary_structure_guard();
    SQL
  end

  def trigger_assignment_snapshot(m, s:, vocabs:, terms:, ver_single:, ver_multi:)
    single_ref = "public.#{ver_single}"
    multi_ref = "public.#{ver_multi}"
    m.execute(<<~SQL.squish)
      CREATE TRIGGER trg_#{s}_vs_snap
      BEFORE INSERT ON #{single_ref}
      FOR EACH ROW EXECUTE FUNCTION publishing_version_assignment_snapshot('#{vocabs}', '#{terms}', 'single');
    SQL
    m.execute(<<~SQL.squish)
      CREATE TRIGGER trg_#{s}_vm_snap
      BEFORE INSERT ON #{multi_ref}
      FOR EACH ROW EXECUTE FUNCTION publishing_version_assignment_snapshot('#{vocabs}', '#{terms}', 'ordered');
    SQL
  end

  def trigger_snapshot_complete(m, s:, versions:, rev_single:, ver_single:, rev_multi:, ver_multi:)
    args = "'#{versions}', '#{rev_single}', '#{ver_single}', '#{rev_multi}', '#{ver_multi}'"
    {
      ver: versions,
      vs: ver_single,
      vm: ver_multi,
    }.each do |tag, table|
      table_ref = "public.#{table}"
      m.execute(<<~SQL.squish)
        CREATE CONSTRAINT TRIGGER trg_#{s}_#{tag}_snap_c
        AFTER INSERT ON #{table_ref}
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION publishing_assert_version_snapshot_complete(
          #{args}
        );
      SQL
    end
  end

  def trigger_media_complete(m, s:, versions:, rev_media:, ver_media:)
    args = "'#{versions}', '#{rev_media}', '#{ver_media}'"
    [versions, ver_media].each do |table|
      tag = (table == versions) ? "ver" : "vmedia"
      table_ref = "public.#{table}"
      m.execute(<<~SQL.squish)
        CREATE CONSTRAINT TRIGGER trg_#{s}_#{tag}_media_c
        AFTER INSERT ON #{table_ref}
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION publishing_assert_version_media_complete(
          #{args}
        );
      SQL
    end
  end

  def trigger_immutable(m, s:, versions:, ver_single:, ver_multi:, ver_media:)
    {
      ver: versions,
      vs: ver_single,
      vm: ver_multi,
      vmedia: ver_media,
    }.each do |tag, table|
      m.execute(<<~SQL.squish)
        CREATE TRIGGER trg_#{s}_#{tag}_imm
        BEFORE UPDATE OR DELETE ON #{table}
        FOR EACH ROW EXECUTE FUNCTION publishing_reject_mutation();
      SQL
    end
  end

  def trigger_promoted_revision(m, s:, revisions:, versions:)
    revisions_ref = "public.#{revisions}"
    m.execute(<<~SQL.squish)
      CREATE TRIGGER trg_#{s}_rev_promoted
      BEFORE UPDATE OR DELETE ON #{revisions_ref}
      FOR EACH ROW EXECUTE FUNCTION publishing_promoted_revision_guard('#{versions}');
    SQL
  end

  def trigger_promoted_revision_for_usages(m, s:, versions:, rev_single:, rev_multi:, rev_media:)
    {
      rs: rev_single,
      rm: rev_multi,
      rmedia: rev_media,
    }.each do |tag, table|
      table_ref = "public.#{table}"
      m.execute(<<~SQL.squish)
        CREATE TRIGGER trg_#{s}_#{tag}_promoted
        BEFORE INSERT OR UPDATE OR DELETE ON #{table_ref}
        FOR EACH ROW EXECUTE FUNCTION publishing_promoted_revision_guard('#{versions}');
      SQL
    end
  end

  def public_id(t) = t.string(:public_id, limit: 21, null: false)

  def provenance(t) = t.string(:created_by_operator_public_id, limit: 21)

  def archive(t)
    t.datetime(:archived_at)
    t.string(:archive_reason)
  end

  def encrypted_content(t)
    t.string(:locale, null: false)
    t.text(:title, null: false)
    t.text(:summary)
    t.text(:body, null: false)
    t.integer(:schema_version, null: false)
    t.string(:content_digest, limit: 64, null: false)
  end

  def finish_public_id(m, table)
    m.add_index(table, :public_id, unique: true)
    ident = table.to_s.delete_prefix('publishing_').gsub("taxonomy_", "").gsub("assignments", "asg")
    name = "chk_#{ident}_pid"
    name = "chk_#{ident[0, 55]}_pid" if name.length > 63
    m.add_check_constraint(table, PUBLIC_ID, name:)
  end

  def archive_check(m, table, s, tag)
    m.add_check_constraint(
      table,
      "(archived_at IS NULL AND archive_reason IS NULL) OR " \
      "(archived_at IS NOT NULL AND archive_reason IS NOT NULL)",
      name: "chk_#{s}_#{tag}_archive",
    )
  end

  def content_checks(m, table, s, tag)
    m.add_check_constraint(table, "schema_version > 0", name: "chk_#{s}_#{tag}_schema")
    m.add_check_constraint(table, DIGEST, name: "chk_#{s}_#{tag}_digest")
  end

  def composite_fk(m, from, columns, to, primary_key, name)
    m.add_foreign_key(from, to, column: columns, primary_key:, on_delete: :restrict, name:)
  end

  def quoted_list(values) = values.map { |value| "'#{value}'" }.join(",")
end
# rubocop:enable Naming/MethodParameterName
