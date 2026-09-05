# frozen_string_literal: true

# Builds the central publishing database schema: editions (audience x surface x
# locale) and the entry lifecycle (entry -> revision -> version -> publication)
# plus media. Taxonomy is intentionally not part of this schema; see
# adr/publishing-db-content-authority.md. This module is migration-only.
# rubocop:disable Naming/MethodParameterName -- concise migration DSL aliases keep the shared DDL readable.
module PublishingSchema
  module_function

  PUBLIC_ID = "char_length(public_id) = 21".freeze
  SLUG = "slug ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'".freeze
  DIGEST = "content_digest ~ '^[0-9a-f]{64}$'".freeze
  AUDIENCES = %w(app com org).freeze
  SURFACES = %w(info docs news help).freeze

  def create_schema(migration)
    migration.enable_extension("btree_gist") unless migration.extension_enabled?("btree_gist")

    create_editions(migration)
    create_entries(migration)
    create_slugs(migration)
    create_revisions(migration)
    add_current_revision(migration)
    create_versions(migration)
    create_publications(migration)
    create_media(migration)
  end

  def create_editions(m)
    table = :publishing_editions
    m.create_table(table) do |t|
      public_id(t)
      t.string(:audience, null: false)
      t.string(:surface, null: false)
      t.string(:locale, null: false)
      t.string(:region_code)
      t.timestamps(null: false)
    end
    finish_public_id(m, table)
    m.add_check_constraint(table, "audience IN (#{quoted_list(AUDIENCES)})", name: "chk_publishing_editions_audience")
    m.add_check_constraint(table, "surface IN (#{quoted_list(SURFACES)})", name: "chk_publishing_editions_surface")
    m.add_index(table, %i(audience surface locale), unique: true, name: "uidx_publishing_editions_scope")
    m.add_index(table, %i(id locale), unique: true)
  end

  def create_entries(m)
    table = :publishing_entries
    m.create_table(table) do |t|
      public_id(t)
      t.references(:edition, null: false, foreign_key: { to_table: :publishing_editions, on_delete: :restrict })
      t.string(:locale, null: false)
      archive(t)
      t.integer(:lock_version, null: false, default: 0)
      t.timestamps(null: false)
    end
    finish_public_id(m, table)
    m.add_check_constraint(table, "lock_version >= 0", name: "chk_publishing_entries_lock_version")
    archive_check(m, table)
    m.add_index(table, %i(id locale), unique: true)
    composite_fk(
      m, table, %i(edition_id locale), :publishing_editions, %i(id locale),
      "fk_publishing_entries_edition_locale",
    )
  end

  def create_slugs(m)
    table = :publishing_entry_slugs
    m.create_table(table) do |t|
      public_id(t)
      t.references(:entry, null: false, foreign_key: { to_table: :publishing_entries, on_delete: :restrict })
      t.references(:edition, null: false, foreign_key: { to_table: :publishing_editions, on_delete: :restrict })
      t.string(:locale, null: false)
      t.string(:slug, null: false)
      t.string(:state, null: false)
      t.datetime(:canonicalized_at)
      t.datetime(:redirected_at)
      t.timestamps(null: false)
    end
    finish_public_id(m, table)
    m.add_index(table, %i(edition_id slug), unique: true)
    m.add_index(table, :entry_id, unique: true, where: "state = 'reserved'", name: "uidx_publishing_slug_reserved")
    m.add_index(table, :entry_id, unique: true, where: "state = 'canonical'", name: "uidx_publishing_slug_canonical")
    m.add_check_constraint(table, "state IN ('reserved','canonical','redirect')", name: "chk_publishing_slug_state")
    m.add_check_constraint(table, SLUG, name: "chk_publishing_slug_format")
    m.add_check_constraint(
      table,
      "(state = 'reserved' AND canonicalized_at IS NULL AND redirected_at IS NULL) OR " \
      "(state = 'canonical' AND canonicalized_at IS NOT NULL AND redirected_at IS NULL) OR " \
      "(state = 'redirect' AND canonicalized_at IS NOT NULL AND " \
      "redirected_at IS NOT NULL AND redirected_at >= canonicalized_at)",
      name: "chk_publishing_slug_timestamps",
    )
    composite_fk(m, table, %i(entry_id locale), :publishing_entries, %i(id locale), "fk_publishing_slug_entry_locale")
    composite_fk(
      m, table, %i(edition_id locale), :publishing_editions, %i(id locale),
      "fk_publishing_slug_edition_locale",
    )
  end

  def create_revisions(m)
    table = :publishing_entry_revisions
    m.create_table(table) do |t|
      public_id(t)
      t.references(:entry, null: false, foreign_key: { to_table: :publishing_entries, on_delete: :restrict })
      t.bigint(:restored_from_revision_id)
      t.bigint(:restored_from_version_id)
      content(t)
      provenance(t)
      t.integer(:sequence, null: false)
      t.timestamps(null: false)
    end
    finish_public_id(m, table)
    m.add_index(table, %i(entry_id sequence), unique: true)
    m.add_index(table, %i(id entry_id), unique: true)
    m.add_index(table, %i(id locale), unique: true)
    m.add_index(table, %i(id entry_id locale), unique: true)
    content_checks(m, table)
    m.add_check_constraint(table, "sequence > 0", name: "chk_publishing_revision_sequence")
    m.add_check_constraint(
      table, "num_nonnulls(restored_from_revision_id, restored_from_version_id) <= 1",
      name: "chk_publishing_restore_source",
    )
    m.add_foreign_key(
      table, table, column: %i(restored_from_revision_id entry_id), primary_key: %i(id entry_id),
                    on_delete: :restrict, name: "fk_publishing_restore_revision_entry",
    )
    composite_fk(
      m, table, %i(entry_id locale), :publishing_entries, %i(id locale),
      "fk_publishing_revision_entry_locale",
    )
  end

  def add_current_revision(m)
    entries = :publishing_entries
    revisions = :publishing_entry_revisions
    m.add_column(entries, :current_revision_id, :bigint)
    m.add_index(entries, :current_revision_id, unique: true)
    m.add_foreign_key(
      entries, revisions, column: %i(current_revision_id id), primary_key: %i(id entry_id),
                          on_delete: :restrict, name: "fk_publishing_entries_current_revision",
    )
  end

  def create_versions(m)
    table = :publishing_entry_versions
    m.create_table(table) do |t|
      public_id(t)
      t.references(:entry, null: false, foreign_key: { to_table: :publishing_entries, on_delete: :restrict })
      t.references(:entry_revision, null: false, index: false)
      content(t)
      provenance(t)
      t.integer(:sequence, null: false)
      t.timestamps(null: false)
    end
    finish_public_id(m, table)
    m.add_index(table, %i(entry_id sequence), unique: true)
    m.add_index(table, :entry_revision_id, unique: true)
    m.add_index(table, %i(id entry_id), unique: true)
    m.add_index(table, %i(id locale), unique: true)
    m.add_index(table, %i(id entry_id locale), unique: true)
    m.add_foreign_key(
      table, :publishing_entry_revisions, column: %i(entry_revision_id entry_id), primary_key: %i(id entry_id),
                                          on_delete: :restrict, name: "fk_publishing_version_revision_entry",
    )
    composite_fk(
      m, table, %i(entry_id locale), :publishing_entries, %i(id locale),
      "fk_publishing_version_entry_locale",
    )
    content_checks(m, table)
    m.add_check_constraint(table, "sequence > 0", name: "chk_publishing_version_sequence")
    m.add_foreign_key(
      :publishing_entry_revisions, table, column: %i(restored_from_version_id entry_id), primary_key: %i(id entry_id),
                                          on_delete: :restrict, name: "fk_publishing_restore_version_entry",
    )
  end

  def create_publications(m)
    table = :publishing_publications
    m.create_table(table) do |t|
      public_id(t)
      t.references(:entry, null: false, foreign_key: { to_table: :publishing_entries, on_delete: :restrict })
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
      table, :publishing_entry_versions, column: %i(entry_version_id entry_id), primary_key: %i(id entry_id),
                                         on_delete: :restrict, name: "fk_publishing_publication_version_entry",
    )
    add_publication_constraints(m, table)
  end

  def add_publication_constraints(m, table)
    m.add_check_constraint(
      table, "effective_until IS NULL OR effective_until > effective_from",
      name: "chk_publishing_publication_window",
    )
    m.add_check_constraint(
      table, "NOT (cancelled_at IS NOT NULL AND terminated_at IS NOT NULL)",
      name: "chk_publishing_publication_end_mode",
    )
    m.add_check_constraint(
      table,
      "(cancelled_at IS NULL AND cancellation_reason IS NULL) OR " \
      "(cancelled_at IS NOT NULL AND cancellation_reason IS NOT NULL AND cancelled_at < effective_from)",
      name: "chk_publishing_publication_cancellation",
    )
    m.add_check_constraint(
      table,
      "(terminated_at IS NULL AND termination_reason IS NULL) OR " \
      "(terminated_at IS NOT NULL AND termination_reason IS NOT NULL AND " \
      "terminated_at >= effective_from AND effective_until = terminated_at)",
      name: "chk_publishing_publication_termination",
    )
    m.add_exclusion_constraint(
      table,
      "entry_id WITH =, tstzrange(effective_from, effective_until, '[)') WITH &&",
      using: :gist, where: "cancelled_at IS NULL",
      name: "excl_publishing_publication_windows",
    )
  end

  def create_media(m)
    create_media_files(m)
    create_owner_media_usages(
      m, :publishing_revision_media_usages,
      owner: :entry_revision, owner_table: :publishing_entry_revisions,
      unique_index: "uidx_publishing_revision_media_usages_position",
    )
    create_owner_media_usages(
      m, :publishing_version_media_usages,
      owner: :entry_version, owner_table: :publishing_entry_versions,
      unique_index: "uidx_publishing_version_media_usages_position",
    )
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
    archive_check(m, files)
  end

  # One owner column per table. entry_id and locale are derived from the owner
  # revision/version and are not stored here.
  def create_owner_media_usages(m, table, owner:, owner_table:, unique_index:)
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
    m.add_check_constraint(table, "position >= 0", name: "chk_#{table}_position")
    m.add_check_constraint(
      table, "field_path IS NOT NULL OR block_path IS NOT NULL",
      name: "chk_#{table}_path",
    )
    m.add_check_constraint(
      table, "presentation_metadata IS NULL OR jsonb_typeof(presentation_metadata) = 'object'",
      name: "chk_#{table}_presentation_metadata",
    )
    m.add_index(
      table, [owner_id, :role, :field_path, :block_path, :position],
      unique: true, name: unique_index,
    )
  end

  def public_id(t) = t.string(:public_id, limit: 21, null: false)

  def provenance(t) = t.string(:created_by_operator_public_id, limit: 21)

  def archive(t)
    t.datetime(:archived_at)
    t.string(:archive_reason)
  end

  def content(t)
    t.string(:locale, null: false)
    t.string(:title, null: false)
    t.text(:summary)
    t.jsonb(:body, null: false)
    t.integer(:schema_version, null: false)
    t.string(:content_digest, limit: 64, null: false)
  end

  def finish_public_id(m, table)
    m.add_index(table, :public_id, unique: true)
    m.add_check_constraint(table, PUBLIC_ID, name: "chk_#{table}_public_id")
  end

  def archive_check(m, table)
    m.add_check_constraint(
      table,
      "(archived_at IS NULL AND archive_reason IS NULL) OR " \
      "(archived_at IS NOT NULL AND archive_reason IS NOT NULL)",
      name: "chk_#{table}_archive",
    )
  end

  def content_checks(m, table)
    m.add_check_constraint(table, "jsonb_typeof(body) = 'object'", name: "chk_#{table}_body")
    m.add_check_constraint(table, "schema_version > 0", name: "chk_#{table}_schema")
    m.add_check_constraint(table, DIGEST, name: "chk_#{table}_digest")
  end

  def composite_fk(m, from, columns, to, primary_key, name)
    m.add_foreign_key(from, to, column: columns, primary_key:, on_delete: :restrict, name:)
  end

  def quoted_list(values) = values.map { |value| "'#{value}'" }.join(",")
end
# rubocop:enable Naming/MethodParameterName
