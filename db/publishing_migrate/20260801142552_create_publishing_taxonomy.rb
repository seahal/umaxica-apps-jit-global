# frozen_string_literal: true

# Adds the publishing taxonomy system: vocabularies scoped by audience and
# surface, locale-specific hierarchical terms, editable revision assignments,
# and immutable version assignment snapshots. Every cardinality, locale,
# vocabulary-kind, hierarchy, and scope invariant is enforced by PostgreSQL;
# Active Record validations are convenience only. See
# adr/publishing-taxonomy-architecture.md.
# rubocop:disable Naming/MethodParameterName -- the migration DSL block variable is conventionally `t`.
require_relative "../migration_support/publishing_schema"

class CreatePublishingTaxonomy < ActiveRecord::Migration[8.2]
  AUDIENCES = PublishingSchema::AUDIENCES
  SURFACES = PublishingSchema::SURFACES
  LOCALES = %w(ja en).freeze
  KINDS = %w(single_hierarchical multiple_ordered_flat).freeze
  SINGLE_KIND = "single_hierarchical"
  MULTIPLE_KIND = "multiple_ordered_flat"
  MAX_DEPTH = 8

  # Written as up/down rather than change: the taxonomy tables reference each
  # other and themselves, so dropping the tables (which cascades their indexes,
  # constraints, and triggers) is both simpler and more reliable than reversing
  # each foreign key individually.
  def up
    # Every table below is created by this migration, so the foreign keys and
    # check constraints validate against no existing rows and block nothing.
    safety_assured do
      create_term_path_validator
      create_vocabularies
      create_terms
      create_revision_assignments
      create_version_assignments
      create_hierarchy_guard
      create_scope_guard
      create_immutability_guard
      create_retirement_guard
      create_snapshot_derivation
      create_snapshot_completeness_guard
      create_media_completeness_guard
      create_promoted_revision_guard
    end
  end

  def down
    safety_assured do
      %w(
        publishing_version_multiple_taxonomy_assignments
        publishing_version_single_taxonomy_assignments
        publishing_revision_multiple_taxonomy_assignments
        publishing_revision_single_taxonomy_assignments
        publishing_taxonomy_terms
        publishing_vocabularies
      ).each { |table| drop_table(table.to_sym) }
      # CASCADE removes the triggers these functions left on the pre-existing
      # entry, revision, and version tables.
      %w(
        publishing_reject_mutation()
        publishing_reject_retirement_by_deletion()
        publishing_vocabulary_structure_guard()
        publishing_promoted_revision_guard()
        publishing_assert_version_snapshot_complete()
        publishing_assert_version_media_complete()
        publishing_version_single_taxonomy_assignments_snapshot()
        publishing_version_multiple_taxonomy_assignments_snapshot()
        publishing_taxonomy_assignment_scope_guard()
        publishing_taxonomy_term_hierarchy_guard()
        publishing_taxonomy_term_path(bigint)
        publishing_valid_term_path(jsonb)
      ).each { |signature| execute("DROP FUNCTION IF EXISTS #{signature} CASCADE") }
    end
  end

  private

  def create_vocabularies
    table = :publishing_vocabularies
    create_table(table) do |t|
      t.string(:public_id, limit: 21, null: false)
      t.string(:audience, null: false)
      t.string(:surface, null: false)
      t.string(:key, null: false)
      t.string(:kind, null: false)
      t.string(:internal_name, null: false)
      t.text(:description)
      t.datetime(:archived_at)
      t.string(:archive_reason)
      t.timestamps(null: false)
    end
    finish_public_id(table)
    add_check_constraint(table, "audience IN (#{quoted(AUDIENCES)})", name: "chk_publishing_vocabularies_audience")
    add_check_constraint(table, "surface IN (#{quoted(SURFACES)})", name: "chk_publishing_vocabularies_surface")
    add_check_constraint(table, "kind IN (#{quoted(KINDS)})", name: "chk_publishing_vocabularies_kind")
    add_check_constraint(table, "btrim(key) <> '' AND key ~ '^[a-z][a-z0-9_]*$'", name: "chk_publishing_vocabularies_key")
    add_check_constraint(table, "btrim(internal_name) <> ''", name: "chk_publishing_vocabularies_internal_name")
    archive_check(table)
    add_index(table, %i(audience surface key), unique: true, name: "uidx_publishing_vocabularies_scope")
    # Composite foreign-key target: an assignment proves it uses a vocabulary of
    # the kind its table is dedicated to.
    add_index(table, %i(id kind), unique: true, name: "uidx_publishing_vocabularies_id_kind")
  end

  def create_terms
    table = :publishing_taxonomy_terms
    create_table(table) do |t|
      t.string(:public_id, limit: 21, null: false)
      t.references(:vocabulary, null: false, foreign_key: { to_table: :publishing_vocabularies, on_delete: :restrict })
      t.string(:vocabulary_kind, null: false)
      t.string(:locale, null: false)
      t.string(:slug, null: false)
      t.string(:name, null: false)
      t.bigint(:parent_id)
      t.integer(:depth, null: false, default: 0)
      t.integer(:position, null: false, default: 0)
      t.datetime(:archived_at)
      t.string(:archive_reason)
      t.timestamps(null: false)
    end
    finish_public_id(table)
    add_check_constraint(table, "locale IN (#{quoted(LOCALES)})", name: "chk_publishing_terms_locale")
    add_check_constraint(table, "vocabulary_kind IN (#{quoted(KINDS)})", name: "chk_publishing_terms_kind")
    add_check_constraint(table, "btrim(slug) <> '' AND #{PublishingSchema::SLUG}", name: "chk_publishing_terms_slug")
    add_check_constraint(table, "btrim(name) <> ''", name: "chk_publishing_terms_name")
    add_check_constraint(table, "depth BETWEEN 0 AND #{MAX_DEPTH}", name: "chk_publishing_terms_depth")
    add_check_constraint(table, "position >= 0", name: "chk_publishing_terms_position")
    add_check_constraint(table, "parent_id IS NULL OR parent_id <> id", name: "chk_publishing_terms_not_self_parent")
    add_check_constraint(
      table,
      "(parent_id IS NULL AND depth = 0) OR (parent_id IS NOT NULL AND depth > 0)",
      name: "chk_publishing_terms_root_depth",
    )
    # Flat vocabularies can never carry hierarchy; hierarchical ones may.
    add_check_constraint(
      table,
      "vocabulary_kind <> '#{MULTIPLE_KIND}' OR (parent_id IS NULL AND depth = 0)",
      name: "chk_publishing_terms_flat_has_no_parent",
    )
    archive_check(table)
    add_index(table, %i(vocabulary_id locale slug), unique: true, name: "uidx_publishing_terms_slug")
    add_index(table, %i(id vocabulary_id locale), unique: true, name: "uidx_publishing_terms_scope")
    add_index(table, :parent_id, name: "idx_publishing_terms_parent")
    # Sibling order is deterministic. NULLS NOT DISTINCT makes the rule apply at
    # the root too, where parent_id is NULL and PostgreSQL would otherwise treat
    # every row as unique. Flat vocabularies always have parent_id NULL, so this
    # single index gives them per-vocabulary-and-locale position uniqueness.
    execute(<<~SQL.squish)
      CREATE UNIQUE INDEX uidx_publishing_terms_sibling_position
      ON public.publishing_taxonomy_terms (vocabulary_id, locale, parent_id, position)
      NULLS NOT DISTINCT
    SQL
    add_foreign_key(
      table, :publishing_vocabularies, column: %i(vocabulary_id vocabulary_kind), primary_key: %i(id kind),
                                       on_delete: :restrict, name: "fk_publishing_terms_vocabulary_kind",
    )
    # Parent and child are proven to share both vocabulary and locale.
    add_foreign_key(
      table, table, column: %i(parent_id vocabulary_id locale), primary_key: %i(id vocabulary_id locale),
                    on_delete: :restrict, name: "fk_publishing_terms_parent_scope",
    )
  end

  def create_revision_assignments
    single = :publishing_revision_single_taxonomy_assignments
    create_table(single) do |t|
      t.references(:entry_revision, null: false, index: false)
      t.references(:vocabulary, null: false, index: false)
      t.string(:vocabulary_kind, null: false)
      t.references(:taxonomy_term, null: false, index: false)
      t.string(:locale, null: false)
      t.timestamps(null: false)
    end
    add_check_constraint(single, "vocabulary_kind = '#{SINGLE_KIND}'", name: "chk_#{single}_kind")
    add_index(single, %i(entry_revision_id vocabulary_id), unique: true, name: "uidx_publishing_revision_single_owner")
    add_index(single, :taxonomy_term_id, name: "idx_publishing_revision_single_term")
    add_index(single, :vocabulary_id, name: "idx_publishing_revision_single_vocabulary")
    assignment_foreign_keys(single, owner: :entry_revision, owner_table: :publishing_entry_revisions)

    multiple = :publishing_revision_multiple_taxonomy_assignments
    create_table(multiple) do |t|
      t.references(:entry_revision, null: false, index: false)
      t.references(:vocabulary, null: false, index: false)
      t.string(:vocabulary_kind, null: false)
      t.references(:taxonomy_term, null: false, index: false)
      t.string(:locale, null: false)
      t.integer(:position, null: false)
      t.timestamps(null: false)
    end
    add_check_constraint(multiple, "vocabulary_kind = '#{MULTIPLE_KIND}'", name: "chk_#{multiple}_kind")
    add_check_constraint(multiple, "position >= 0", name: "chk_#{multiple}_position")
    add_index(multiple, %i(entry_revision_id vocabulary_id taxonomy_term_id), unique: true, name: "uidx_publishing_revision_multiple_term")
    add_index(multiple, %i(entry_revision_id vocabulary_id position), unique: true, name: "uidx_publishing_revision_multiple_position")
    add_index(multiple, :taxonomy_term_id, name: "idx_publishing_revision_multiple_term")
    add_index(multiple, :vocabulary_id, name: "idx_publishing_revision_multiple_vocabulary")
    assignment_foreign_keys(multiple, owner: :entry_revision, owner_table: :publishing_entry_revisions)
  end

  def create_version_assignments
    single = :publishing_version_single_taxonomy_assignments
    create_table(single) do |t|
      t.references(:entry_version, null: false, index: false)
      t.references(:vocabulary, null: false, index: false)
      t.string(:vocabulary_kind, null: false)
      t.references(:taxonomy_term, null: false, index: false)
      t.string(:locale, null: false)
      snapshot_columns(t)
      t.timestamps(null: false)
    end
    add_check_constraint(single, "vocabulary_kind = '#{SINGLE_KIND}'", name: "chk_#{single}_kind")
    add_index(single, %i(entry_version_id vocabulary_id), unique: true, name: "uidx_publishing_version_single_owner")
    add_index(single, :taxonomy_term_id, name: "idx_publishing_version_single_term")
    add_index(single, :vocabulary_id, name: "idx_publishing_version_single_vocabulary")
    snapshot_checks(single)
    snapshot_filter_index(single)
    assignment_foreign_keys(single, owner: :entry_version, owner_table: :publishing_entry_versions)

    multiple = :publishing_version_multiple_taxonomy_assignments
    create_table(multiple) do |t|
      t.references(:entry_version, null: false, index: false)
      t.references(:vocabulary, null: false, index: false)
      t.string(:vocabulary_kind, null: false)
      t.references(:taxonomy_term, null: false, index: false)
      t.string(:locale, null: false)
      t.integer(:position, null: false)
      snapshot_columns(t)
      t.integer(:position_snapshot, null: false)
      t.timestamps(null: false)
    end
    add_check_constraint(multiple, "vocabulary_kind = '#{MULTIPLE_KIND}'", name: "chk_#{multiple}_kind")
    add_check_constraint(multiple, "position >= 0 AND position_snapshot >= 0", name: "chk_#{multiple}_position")
    add_index(multiple, %i(entry_version_id vocabulary_id taxonomy_term_id), unique: true, name: "uidx_publishing_version_multiple_term")
    add_index(multiple, %i(entry_version_id vocabulary_id position), unique: true, name: "uidx_publishing_version_multiple_position")
    add_index(multiple, :taxonomy_term_id, name: "idx_publishing_version_multiple_term")
    add_index(multiple, :vocabulary_id, name: "idx_publishing_version_multiple_vocabulary")
    snapshot_checks(multiple)
    snapshot_filter_index(multiple)
    assignment_foreign_keys(multiple, owner: :entry_version, owner_table: :publishing_entry_versions)
  end

  # Live foreign keys prove locale coherence with the owner, that the term
  # belongs to the assigned vocabulary in the assigned locale, and that the
  # vocabulary carries the kind this table is dedicated to.
  def assignment_foreign_keys(table, owner:, owner_table:)
    add_foreign_key(
      table, owner_table, column: [:"#{owner}_id", :locale], primary_key: %i(id locale),
                          on_delete: :restrict, name: "fk_#{table}_owner_locale",
    )
    add_foreign_key(
      table, :publishing_vocabularies, column: %i(vocabulary_id vocabulary_kind), primary_key: %i(id kind),
                                       on_delete: :restrict, name: "fk_#{table}_vocabulary_kind",
    )
    add_foreign_key(
      table, :publishing_taxonomy_terms, column: %i(taxonomy_term_id vocabulary_id locale), primary_key: %i(id vocabulary_id locale),
                                         on_delete: :restrict, name: "fk_#{table}_term_scope",
    )
  end

  # Frozen rendering history. Live foreign keys stay authoritative for
  # referential tracking; these columns are authoritative for what the
  # published version actually displayed.
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

  # Public filtering matches snapshot columns, so it must not scan every
  # published assignment row to answer `?category=` or `?tag=`.
  def snapshot_filter_index(table)
    add_index(
      table, %i(vocabulary_key_snapshot term_slug_snapshot locale_snapshot),
      name: "idx_#{table}_filter",
    )
  end

  def snapshot_checks(table)
    add_check_constraint(table, "char_length(vocabulary_public_id_snapshot) = 21", name: "chk_#{table}_vocab_public_id")
    add_check_constraint(table, "char_length(term_public_id_snapshot) = 21", name: "chk_#{table}_term_public_id")
    add_check_constraint(table, "vocabulary_kind_snapshot IN (#{quoted(KINDS)})", name: "chk_#{table}_kind_snapshot")
    add_check_constraint(table, "locale_snapshot IN (#{quoted(LOCALES)})", name: "chk_#{table}_locale_snapshot")
    add_check_constraint(
      table,
      "btrim(vocabulary_key_snapshot) <> '' AND btrim(term_slug_snapshot) <> '' AND btrim(term_name_snapshot) <> ''",
      name: "chk_#{table}_snapshot_present",
    )
    # term_path_snapshot is a validated breadcrumb array, never a metadata bag.
    add_check_constraint(table, "publishing_valid_term_path(term_path_snapshot)", name: "chk_#{table}_path_snapshot")
  end

  # A CHECK constraint cannot contain a subquery, and validating the breadcrumb
  # array requires unnesting it, so the rule lives in an IMMUTABLE function the
  # constraints call. The key count is checked too: a breadcrumb step carries
  # exactly public_id, slug, and name, never arbitrary extra metadata.
  #
  # The SQL below must not contain `--` comments: these heredocs are squished
  # onto one line, which would comment out everything after them.
  def create_term_path_validator
    execute(<<~SQL.squish)
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
  end

  # Depth must equal parent.depth + 1, and no move may create a cycle. Both are
  # cross-row facts, so a CHECK cannot express them.
  def create_hierarchy_guard
    execute(<<~SQL.squish)
      CREATE FUNCTION publishing_taxonomy_term_hierarchy_guard() RETURNS trigger AS $$
      DECLARE parent_depth integer;
      BEGIN
        IF NEW.parent_id IS NULL THEN RETURN NEW; END IF;

        SELECT depth INTO parent_depth FROM public.publishing_taxonomy_terms WHERE id = NEW.parent_id;
        IF parent_depth IS NULL THEN
          RAISE EXCEPTION 'publishing taxonomy: parent term % not found', NEW.parent_id;
        END IF;
        IF NEW.depth <> parent_depth + 1 THEN
          RAISE EXCEPTION 'publishing taxonomy: depth % must equal parent depth % plus one', NEW.depth, parent_depth;
        END IF;
        IF EXISTS (
          WITH RECURSIVE ancestors(id, parent_id, level) AS (
            SELECT t.id, t.parent_id, 1 FROM public.publishing_taxonomy_terms t WHERE t.id = NEW.parent_id
            UNION ALL
            SELECT t.id, t.parent_id, a.level + 1
            FROM public.publishing_taxonomy_terms t JOIN ancestors a ON t.id = a.parent_id
            WHERE a.level <= #{MAX_DEPTH} + 1
          )
          SELECT 1 FROM ancestors WHERE id = NEW.id
        ) THEN
          RAISE EXCEPTION 'publishing taxonomy: term % cannot descend from itself', NEW.id;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql SET search_path = pg_catalog, public;
    SQL
    execute(<<~SQL.squish)
      CREATE TRIGGER trg_publishing_terms_hierarchy
      BEFORE INSERT OR UPDATE ON publishing_taxonomy_terms
      FOR EACH ROW EXECUTE FUNCTION publishing_taxonomy_term_hierarchy_guard();
    SQL
  end

  # A vocabulary may only be assigned to content of the same audience and
  # surface. The owner reaches its edition through its entry, so this is a
  # multi-table fact enforced by a constraint trigger rather than a CHECK.
  def create_scope_guard
    execute(<<~SQL.squish)
      CREATE FUNCTION publishing_taxonomy_assignment_scope_guard() RETURNS trigger AS $$
      DECLARE
        owner_table text := TG_ARGV[0];
        owner_column text := TG_ARGV[1];
        owner_id bigint;
        vocabulary_audience text;
        vocabulary_surface text;
        edition_audience text;
        edition_surface text;
      BEGIN
        EXECUTE format('SELECT ($1).%I', owner_column) INTO owner_id USING NEW;

        SELECT v.audience, v.surface INTO vocabulary_audience, vocabulary_surface
        FROM public.publishing_vocabularies v WHERE v.id = NEW.vocabulary_id;

        EXECUTE format(
          'SELECT ed.audience, ed.surface FROM public.%I o
             JOIN public.publishing_entries en ON en.id = o.entry_id
             JOIN public.publishing_editions ed ON ed.id = en.edition_id
           WHERE o.id = $1', owner_table)
        INTO edition_audience, edition_surface USING owner_id;

        IF vocabulary_audience IS DISTINCT FROM edition_audience
           OR vocabulary_surface IS DISTINCT FROM edition_surface THEN
          RAISE EXCEPTION
            'publishing taxonomy: vocabulary scope %/% does not match edition scope %/%',
            vocabulary_audience, vocabulary_surface, edition_audience, edition_surface;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql SET search_path = pg_catalog, public;
    SQL
    scope_guarded_tables.each do |table, (owner_table, owner_column)|
      execute(<<~SQL.squish)
        CREATE CONSTRAINT TRIGGER trg_#{table}_scope
        AFTER INSERT OR UPDATE ON #{table}
        DEFERRABLE INITIALLY IMMEDIATE
        FOR EACH ROW EXECUTE FUNCTION
        publishing_taxonomy_assignment_scope_guard('#{owner_table}', '#{owner_column}');
      SQL
    end
  end

  def scope_guarded_tables
    {
      publishing_revision_single_taxonomy_assignments: %w(publishing_entry_revisions entry_revision_id),
      publishing_revision_multiple_taxonomy_assignments: %w(publishing_entry_revisions entry_revision_id),
      publishing_version_single_taxonomy_assignments: %w(publishing_entry_versions entry_version_id),
      publishing_version_multiple_taxonomy_assignments: %w(publishing_entry_versions entry_version_id),
    }
  end

  # Application callbacks are bypassed by update_column, update_all, and raw
  # SQL, so published history is frozen in the database itself.
  def create_immutability_guard
    execute(<<~SQL.squish)
      CREATE FUNCTION publishing_reject_mutation() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'publishing: % is immutable (attempted %)', TG_TABLE_NAME, TG_OP;
      END;
      $$ LANGUAGE plpgsql SET search_path = pg_catalog, public;
    SQL
    immutable_tables.each do |table|
      execute(<<~SQL.squish)
        CREATE TRIGGER trg_#{table}_immutable
        BEFORE UPDATE OR DELETE ON #{table}
        FOR EACH ROW EXECUTE FUNCTION publishing_reject_mutation();
      SQL
    end
  end

  # Vocabularies and terms are retired by archiving. Physical deletion would
  # free an identity for reuse, which would silently rewrite the meaning of a
  # published snapshot that still names it.
  def create_retirement_guard
    execute(<<~SQL.squish)
      CREATE FUNCTION publishing_reject_retirement_by_deletion() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION
          'publishing taxonomy: % rows are retired by archiving, never deleted (id %)',
          TG_TABLE_NAME, OLD.id
          USING ERRCODE = 'restrict_violation';
      END;
      $$ LANGUAGE plpgsql SET search_path = pg_catalog, public;
    SQL
    %w(publishing_vocabularies publishing_taxonomy_terms).each do |table|
      execute(<<~SQL.squish)
        CREATE TRIGGER trg_#{table}_no_delete
        BEFORE DELETE ON public.#{table}
        FOR EACH ROW EXECUTE FUNCTION publishing_reject_retirement_by_deletion();
      SQL
    end

    # A vocabulary's structural identity is what its terms and every published
    # snapshot were built against; changing it retroactively would invalidate
    # them. Archiving and relabelling stay allowed.
    execute(<<~SQL.squish)
      CREATE FUNCTION publishing_vocabulary_structure_guard() RETURNS trigger AS $$
      BEGIN
        IF NEW.public_id IS DISTINCT FROM OLD.public_id
           OR NEW.audience IS DISTINCT FROM OLD.audience
           OR NEW.surface IS DISTINCT FROM OLD.surface
           OR NEW.key IS DISTINCT FROM OLD.key
           OR NEW.kind IS DISTINCT FROM OLD.kind THEN
          IF EXISTS (SELECT 1 FROM public.publishing_taxonomy_terms t WHERE t.vocabulary_id = OLD.id) THEN
            RAISE EXCEPTION
              'publishing taxonomy: vocabulary % has terms; public_id, audience, surface, key, and kind are frozen',
              OLD.id
              USING ERRCODE = 'restrict_violation';
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql SET search_path = pg_catalog, public;
    SQL
    execute(<<~SQL.squish)
      CREATE TRIGGER trg_publishing_vocabularies_structure
      BEFORE UPDATE ON public.publishing_vocabularies
      FOR EACH ROW EXECUTE FUNCTION publishing_vocabulary_structure_guard();
    SQL
  end

  # Snapshot columns are derived from the authoritative live rows rather than
  # trusted from the caller, so a forged INSERT cannot claim a term name, slug,
  # key, kind, or path that never existed.
  def create_snapshot_derivation
    execute(<<~SQL.squish)
      CREATE FUNCTION publishing_taxonomy_term_path(target_id bigint) RETURNS jsonb AS $$
        WITH RECURSIVE chain(id, parent_id, public_id, slug, name, level) AS (
          SELECT t.id, t.parent_id, t.public_id, t.slug, t.name, 0
          FROM public.publishing_taxonomy_terms t WHERE t.id = target_id
          UNION ALL
          SELECT t.id, t.parent_id, t.public_id, t.slug, t.name, c.level + 1
          FROM public.publishing_taxonomy_terms t JOIN chain c ON t.id = c.parent_id
        )
        SELECT coalesce(
          jsonb_agg(jsonb_build_object('public_id', public_id, 'slug', slug, 'name', name) ORDER BY level DESC),
          '[]'::jsonb
        )
        FROM chain;
      $$ LANGUAGE sql STABLE SET search_path = pg_catalog, public;
    SQL
    # One function per table rather than one shared function rewriting NEW
    # dynamically: assigning individual fields keeps the trigger to plain,
    # statically resolvable plpgsql, and lets the ordered table snapshot its
    # position without the single-valued table ever referencing that column.
    snapshot_assignments = <<~SQL
      NEW.vocabulary_public_id_snapshot := vocabulary.public_id;
      NEW.vocabulary_key_snapshot := vocabulary.key;
      NEW.vocabulary_kind_snapshot := vocabulary.kind;
      NEW.term_public_id_snapshot := term.public_id;
      NEW.term_slug_snapshot := term.slug;
      NEW.term_name_snapshot := term.name;
      NEW.term_path_snapshot := publishing_taxonomy_term_path(term.id);
      NEW.locale_snapshot := term.locale;
    SQL

    {
      publishing_version_single_taxonomy_assignments: "",
      publishing_version_multiple_taxonomy_assignments: "NEW.position_snapshot := NEW.position;",
    }.each do |table, ordered_assignment|
      execute(<<~SQL.squish)
        CREATE FUNCTION #{table}_snapshot() RETURNS trigger AS $$
        DECLARE
          vocabulary public.publishing_vocabularies%ROWTYPE;
          term public.publishing_taxonomy_terms%ROWTYPE;
        BEGIN
          SELECT * INTO vocabulary FROM public.publishing_vocabularies WHERE id = NEW.vocabulary_id;
          SELECT * INTO term FROM public.publishing_taxonomy_terms WHERE id = NEW.taxonomy_term_id;
          IF vocabulary.id IS NULL OR term.id IS NULL THEN
            RAISE EXCEPTION 'publishing taxonomy: cannot snapshot a missing vocabulary or term'
              USING ERRCODE = 'foreign_key_violation';
          END IF;
          #{snapshot_assignments}
          #{ordered_assignment}
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql SET search_path = pg_catalog, public;
      SQL
      execute(<<~SQL.squish)
        CREATE TRIGGER trg_#{table}_derive_snapshot
        BEFORE INSERT ON public.#{table}
        FOR EACH ROW EXECUTE FUNCTION #{table}_snapshot();
      SQL
    end
  end

  # A version's taxonomy must match the revision it was promoted from, exactly.
  # Deferred to commit because the version row and its snapshots are necessarily
  # written as separate statements.
  def create_snapshot_completeness_guard
    execute(<<~SQL.squish)
      CREATE FUNCTION publishing_assert_version_snapshot_complete() RETURNS trigger AS $$
      DECLARE
        target_version_id bigint;
        source_revision_id bigint;
        mismatch integer;
      BEGIN
        IF TG_TABLE_NAME = 'publishing_entry_versions' THEN
          target_version_id := NEW.id;
        ELSE
          target_version_id := NEW.entry_version_id;
        END IF;

        SELECT entry_revision_id INTO source_revision_id
        FROM public.publishing_entry_versions WHERE id = target_version_id;
        IF source_revision_id IS NULL THEN RETURN NULL; END IF;

        SELECT count(*) INTO mismatch FROM (
          (
            SELECT vocabulary_id, taxonomy_term_id FROM public.publishing_revision_single_taxonomy_assignments
              WHERE entry_revision_id = source_revision_id
            EXCEPT ALL
            SELECT vocabulary_id, taxonomy_term_id FROM public.publishing_version_single_taxonomy_assignments
              WHERE entry_version_id = target_version_id
          )
          UNION ALL
          (
            SELECT vocabulary_id, taxonomy_term_id FROM public.publishing_version_single_taxonomy_assignments
              WHERE entry_version_id = target_version_id
            EXCEPT ALL
            SELECT vocabulary_id, taxonomy_term_id FROM public.publishing_revision_single_taxonomy_assignments
              WHERE entry_revision_id = source_revision_id
          )
        ) AS single_difference;
        IF mismatch > 0 THEN
          RAISE EXCEPTION
            'publishing taxonomy: version % single-valued snapshots do not match revision %',
            target_version_id, source_revision_id
            USING ERRCODE = 'integrity_constraint_violation';
        END IF;

        SELECT count(*) INTO mismatch FROM (
          (
            SELECT vocabulary_id, taxonomy_term_id, position FROM public.publishing_revision_multiple_taxonomy_assignments
              WHERE entry_revision_id = source_revision_id
            EXCEPT ALL
            SELECT vocabulary_id, taxonomy_term_id, position FROM public.publishing_version_multiple_taxonomy_assignments
              WHERE entry_version_id = target_version_id
          )
          UNION ALL
          (
            SELECT vocabulary_id, taxonomy_term_id, position FROM public.publishing_version_multiple_taxonomy_assignments
              WHERE entry_version_id = target_version_id
            EXCEPT ALL
            SELECT vocabulary_id, taxonomy_term_id, position FROM public.publishing_revision_multiple_taxonomy_assignments
              WHERE entry_revision_id = source_revision_id
          )
        ) AS multiple_difference;
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
    %w(
      publishing_entry_versions
      publishing_version_single_taxonomy_assignments
      publishing_version_multiple_taxonomy_assignments
    ).each do |table|
      execute(<<~SQL.squish)
        CREATE CONSTRAINT TRIGGER trg_#{table}_snapshot_complete
        AFTER INSERT ON public.#{table}
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION publishing_assert_version_snapshot_complete();
      SQL
    end
  end

  # Version media is a complete immutable snapshot of the source revision's
  # placements AND presentation fields. Rails DSL cannot defer a multi-row
  # equality check until COMMIT.
  # rubocop:disable Metrics/MethodLength -- one deferred completeness function
  # rubocop:disable I18n/RailsI18n/DecorateString -- DDL is not user-facing copy
  def create_media_completeness_guard
    execute(<<~SQL.squish)
      CREATE FUNCTION publishing_assert_version_media_complete() RETURNS trigger AS $$
      DECLARE
        target_version_id bigint;
        source_revision_id bigint;
        mismatch integer;
      BEGIN
        IF TG_TABLE_NAME = 'publishing_entry_versions' THEN
          target_version_id := NEW.id;
        ELSE
          target_version_id := NEW.entry_version_id;
        END IF;

        SELECT entry_revision_id INTO source_revision_id
        FROM public.publishing_entry_versions WHERE id = target_version_id;
        IF source_revision_id IS NULL THEN RETURN NULL; END IF;

        SELECT count(*) INTO mismatch FROM (
          (
            SELECT media_file_id, role, field_path, block_path, position, alt_text, caption, presentation_metadata
            FROM public.publishing_revision_media_usages
            WHERE entry_revision_id = source_revision_id
            EXCEPT ALL
            SELECT media_file_id, role, field_path, block_path, position, alt_text, caption, presentation_metadata
            FROM public.publishing_version_media_usages
            WHERE entry_version_id = target_version_id
          )
          UNION ALL
          (
            SELECT media_file_id, role, field_path, block_path, position, alt_text, caption, presentation_metadata
            FROM public.publishing_version_media_usages
            WHERE entry_version_id = target_version_id
            EXCEPT ALL
            SELECT media_file_id, role, field_path, block_path, position, alt_text, caption, presentation_metadata
            FROM public.publishing_revision_media_usages
            WHERE entry_revision_id = source_revision_id
          )
        ) AS media_difference;
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
    %w(publishing_entry_versions publishing_version_media_usages).each do |table|
      execute(<<~SQL.squish)
        CREATE CONSTRAINT TRIGGER trg_#{table}_media_complete
        AFTER INSERT ON public.#{table}
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION publishing_assert_version_media_complete();
      SQL
    end
  end
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable I18n/RailsI18n/DecorateString

  # Once a revision has been promoted, it is the historical record of what was
  # published. Letting it drift afterwards would leave the version and the
  # revision describing different promotion events, and UNIQUE(entry_revision_id)
  # makes a corrected second version impossible. Draft revisions stay editable.
  def create_promoted_revision_guard
    execute(<<~SQL.squish)
      CREATE FUNCTION publishing_promoted_revision_guard() RETURNS trigger AS $$
      DECLARE
        subject_revision_id bigint;
        promoted_version_id bigint;
      BEGIN
        IF TG_TABLE_NAME = 'publishing_entry_revisions' THEN
          IF TG_OP = 'DELETE' THEN subject_revision_id := OLD.id;
          ELSE subject_revision_id := NEW.id;
          END IF;
        ELSIF TG_OP = 'DELETE' THEN
          subject_revision_id := OLD.entry_revision_id;
        ELSE
          subject_revision_id := NEW.entry_revision_id;
        END IF;

        SELECT id INTO promoted_version_id
        FROM public.publishing_entry_versions WHERE entry_revision_id = subject_revision_id;

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
    execute(<<~SQL.squish)
      CREATE TRIGGER trg_publishing_entry_revisions_promoted
      BEFORE UPDATE OR DELETE ON public.publishing_entry_revisions
      FOR EACH ROW EXECUTE FUNCTION publishing_promoted_revision_guard();
    SQL
    %w(
      publishing_revision_single_taxonomy_assignments
      publishing_revision_multiple_taxonomy_assignments
      publishing_revision_media_usages
    ).each do |table|
      execute(<<~SQL.squish)
        CREATE TRIGGER trg_#{table}_promoted
        BEFORE INSERT OR UPDATE OR DELETE ON public.#{table}
        FOR EACH ROW EXECUTE FUNCTION publishing_promoted_revision_guard();
      SQL
    end
  end

  def immutable_tables
    %w(
      publishing_entry_versions
      publishing_version_single_taxonomy_assignments
      publishing_version_multiple_taxonomy_assignments
      publishing_version_media_usages
    )
  end

  def finish_public_id(table)
    add_index(table, :public_id, unique: true)
    add_check_constraint(table, PublishingSchema::PUBLIC_ID, name: "chk_#{table}_public_id")
  end

  def archive_check(table)
    add_check_constraint(
      table,
      "(archived_at IS NULL AND archive_reason IS NULL) OR (archived_at IS NOT NULL AND archive_reason IS NOT NULL)",
      name: "chk_#{table}_archive",
    )
  end

  def quoted(values) = values.map { |value| "'#{value}'" }.join(",")
end
# rubocop:enable Naming/MethodParameterName
