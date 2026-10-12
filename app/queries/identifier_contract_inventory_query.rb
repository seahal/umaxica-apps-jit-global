# typed: false
# frozen_string_literal: true

require "json"

# Read-only PostgreSQL catalog inventory for the identifier contract.
#
# This reports database facts needed by the P2/P6 implementation slices. It deliberately does not
# classify a column as an owner identifier, reference, protocol value, or secret. Those meanings
# require the owning model, consumer, and accepted exception to be reviewed by an implementation
# engineer. The report contains catalog metadata only; it never reads application rows.
class IdentifierContractInventoryQuery
  VERSION = 1

  CONNECTION_SPECS = [
    { name: "primary", record_class: ApplicationRecord, ownership: "application" },
    { name: "publishing", record_class: PublishingRecord, ownership: "application" },
    { name: "com_zenith", record_class: ComZenithRecord, ownership: "application" },
    { name: "app_zenith", record_class: AppZenithRecord, ownership: "application" },
    { name: "org_zenith", record_class: OrgZenithRecord, ownership: "application" },
    { name: "app_setting", record_class: AppSettingRecord, ownership: "application" },
    { name: "com_setting", record_class: ComSettingRecord, ownership: "application" },
    { name: "org_setting", record_class: OrgSettingRecord, ownership: "application" },
    { name: "search", record_class: SearchRecord, ownership: "application" },
    { name: "app_ticket", record_class: AppTicketRecord, ownership: "application" },
    { name: "com_ticket", record_class: ComTicketRecord, ownership: "application" },
    { name: "org_ticket", record_class: OrgTicketRecord, ownership: "application" },
    { name: "app_signal", record_class: AppSignalRecord, ownership: "application" },
    { name: "com_signal", record_class: ComSignalRecord, ownership: "application" },
    { name: "org_signal", record_class: OrgSignalRecord, ownership: "application" },
    { name: "avatar", record_class: AvatarRecord, ownership: "application" },
    { name: "chronicle", record_class: ChronicleRecord, ownership: "application" },
    { name: "occurrence", record_class: OccurrenceRecord, ownership: "application" },
    { name: "queue", ownership: "framework" },
    { name: "storage", ownership: "framework" },
  ].map(&:freeze).freeze

  # These are candidate hints only. They are intentionally not semantic classifications. In
  # particular, a suffix such as `_id` may be a reference, an owner identifier, or an unrelated
  # application value and must be resolved from the owning contract.
  CANDIDATE_NAMES = %w(
    public_id
    external_id
    transaction_id
    transfer_id
    session_id
    sid
    jti
    grant_jti
    result_jti
    family_id
    correlation_id
    credential_id
    webauthn_id
    state
    code
    rt
    pt
    der
  ).freeze

  FRAMEWORK_TABLES = {
    "ar_internal_metadata" => "rails",
    "schema_migrations" => "rails",
  }.freeze
  FRAMEWORK_PREFIXES = {
    "solid_queue_" => "solid_queue",
    "active_storage_" => "active_storage",
    "action_mailbox_" => "action_mailbox",
  }.freeze

  TABLE_SQL = <<~SQL.squish
    SELECT
      c.oid::bigint AS table_oid,
      n.nspname AS schema_name,
      c.relname AS table_name,
      c.relkind,
      c.relpersistence,
      c.relispartition AS is_partition,
      pg_get_userbyid(c.relowner) AS owner_role
    FROM pg_catalog.pg_class AS c
    JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
    WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
      AND n.nspname NOT LIKE 'pg_toast%'
      AND c.relkind IN ('r', 'p', 'm', 'f')
    ORDER BY n.nspname, c.relname
  SQL

  COLUMN_SQL = <<~SQL.squish
    SELECT
      a.attrelid::bigint AS table_oid,
      a.attnum::integer AS ordinal,
      a.attname AS column_name,
      format_type(a.atttypid, a.atttypmod) AS sql_type,
      t.typname AS type_name,
      a.attnotnull AS not_null,
      CASE a.attidentity
        WHEN 'a' THEN 'always'
        WHEN 'd' THEN 'by_default'
        ELSE NULL
      END AS identity_kind,
      CASE a.attgenerated
        WHEN 's' THEN 'stored'
        ELSE NULL
      END AS generated_kind,
      (ad.oid IS NOT NULL) AS has_default,
      sequence_info.sequence_schema,
      sequence_info.sequence_name,
      COALESCE(coll.collname, '') AS collation_name
    FROM pg_catalog.pg_attribute AS a
    JOIN pg_catalog.pg_type AS t ON t.oid = a.atttypid
    LEFT JOIN pg_catalog.pg_attrdef AS ad
      ON ad.adrelid = a.attrelid AND ad.adnum = a.attnum
    LEFT JOIN pg_catalog.pg_collation AS coll ON coll.oid = a.attcollation
    LEFT JOIN LATERAL (
      SELECT
        seq_namespace.nspname AS sequence_schema,
        seq.relname AS sequence_name
      FROM pg_catalog.pg_depend AS dep
      JOIN pg_catalog.pg_class AS seq ON seq.oid = dep.objid AND seq.relkind = 'S'
      JOIN pg_catalog.pg_namespace AS seq_namespace ON seq_namespace.oid = seq.relnamespace
      WHERE dep.refobjid = a.attrelid
        AND dep.refobjsubid = a.attnum
        AND dep.deptype IN ('a', 'i')
      ORDER BY seq_namespace.nspname, seq.relname
      LIMIT 1
    ) AS sequence_info ON TRUE
    WHERE a.attnum > 0 AND NOT a.attisdropped
    ORDER BY a.attrelid, a.attnum
  SQL

  PRIMARY_KEY_SQL = <<~SQL.squish
    SELECT
      i.indrelid::bigint AS table_oid,
      a.attnum::integer AS ordinal,
      a.attname AS column_name,
      format_type(a.atttypid, a.atttypmod) AS sql_type
    FROM pg_catalog.pg_index AS i
    CROSS JOIN LATERAL unnest(i.indkey) WITH ORDINALITY AS key_columns(attnum, ordinal)
    JOIN pg_catalog.pg_attribute AS a
      ON a.attrelid = i.indrelid AND a.attnum = key_columns.attnum
    WHERE i.indisprimary
    ORDER BY i.indrelid, key_columns.ordinal
  SQL

  INDEX_SQL = <<~SQL.squish
    SELECT
      i.indrelid::bigint AS table_oid,
      index_class.oid::bigint AS index_oid,
      index_namespace.nspname AS index_schema,
      index_class.relname AS index_name,
      access_method.amname AS access_method,
      i.indisunique AS unique_index,
      i.indisprimary AS primary_index,
      i.indisexclusion AS exclusion_index,
      i.indisvalid AS valid,
      i.indisready AS ready,
      i.indislive AS live,
      i.indnkeyatts::integer AS key_column_count,
      i.indnatts::integer AS total_attribute_count,
      (i.indpred IS NOT NULL) AS partial,
      pg_get_expr(i.indpred, i.indrelid) AS predicate_sql,
      pg_get_indexdef(i.indexrelid) AS definition_sql
    FROM pg_catalog.pg_index AS i
    JOIN pg_catalog.pg_class AS index_class ON index_class.oid = i.indexrelid
    JOIN pg_catalog.pg_namespace AS index_namespace ON index_namespace.oid = index_class.relnamespace
    JOIN pg_catalog.pg_am AS access_method ON access_method.oid = index_class.relam
    ORDER BY i.indrelid, index_class.relname
  SQL

  Result =
    Data.define(:version, :generated_at, :connections) do
      def to_h = { version:, generated_at:, connections: }

      def to_json(*) = JSON.pretty_generate(to_h)
    end

  class << self
    public

    def call(connection_specs: CONNECTION_SPECS)
      specs = normalize_connection_specs(connection_specs)
      connections = specs.map { |spec| scan_connection(spec) }

      Result.new(
        version: VERSION,
        generated_at: Time.now.utc.iso8601(6),
        connections: connections.freeze,
      )
    end

    private

    def normalize_connection_specs(connection_specs)
      raise ArgumentError, "connection_specs must be an Array" unless connection_specs.is_a?(Array)
      raise ArgumentError, "connection_specs must not be empty" if connection_specs.empty?

      connection_specs.map do |spec|
        raise ArgumentError, "connection spec must be a Hash" unless spec.is_a?(Hash)

        name = spec.fetch(:name).to_s
        raise ArgumentError, "connection name must not be empty" if name.empty?

        spec
      end
    end

    def scan_connection(spec)
      with_connection(spec) do |connection|
        tables = connection.select_all(TABLE_SQL).to_a
        columns_by_table = group_rows(connection.select_all(COLUMN_SQL).to_a)
        primary_keys_by_table = group_rows(connection.select_all(PRIMARY_KEY_SQL).to_a)
        indexes_by_table = group_rows(connection.select_all(INDEX_SQL).to_a)

        table_reports =
          tables.map do |table|
            build_table_report(
              table,
              columns_by_table.fetch(table.fetch("table_oid"), []),
              primary_keys_by_table.fetch(table.fetch("table_oid"), []),
              indexes_by_table.fetch(table.fetch("table_oid"), []),
            )
          end

        {
          connection_name: spec.fetch(:name),
          ownership_scope: spec.fetch(:ownership),
          database_name: connection.select_value("SELECT current_database()"),
          server_version: connection.select_value("SHOW server_version"),
          tables: table_reports.freeze,
          summary: summarize(table_reports),
        }.freeze
      end
    end

    def with_connection(spec)
      record_class = spec[:record_class]
      if record_class
        return record_class.connected_to(role: :writing) { yield record_class.lease_connection }
      end

      configured =
        ActiveRecord::Base.configurations.configs_for(
          env_name: Rails.env,
          name: spec.fetch(:name),
          include_hidden: true,
        )
      db_config =
        case configured
        when ActiveRecord::DatabaseConfigurations::HashConfig
          configured
        when Array
          raise ArgumentError, "expected one database configuration for #{spec.fetch(:name)}" unless configured.one?

          configured.first
        else
          raise ArgumentError, "unexpected database configuration for #{spec.fetch(:name)}"
        end
      pool_config =
        ActiveRecord::ConnectionAdapters::PoolConfig.new(
          ActiveRecord::Base,
          db_config,
          :writing,
          nil,
        )
      pool = ActiveRecord::ConnectionAdapters::ConnectionPool.new(pool_config)
      pool.with_connection { |connection| yield connection }
    ensure
      pool_config&.disconnect!
    end

    def group_rows(rows)
      rows.group_by { |row| row.fetch("table_oid") }.transform_values(&:freeze).freeze
    end

    def build_table_report(table, columns, primary_key_columns, indexes)
      primary_key =
        primary_key_columns.map do |column|
          column.slice("ordinal", "column_name", "sql_type")
        end
      column_reports =
        columns.map do |column|
          column.merge(
            "candidate_hints" => candidate_hints(column.fetch("column_name")),
          ).slice(
            "ordinal", "column_name", "sql_type", "type_name", "not_null", "identity_kind",
            "generated_kind", "has_default", "sequence_schema", "sequence_name", "collation_name",
            "candidate_hints",
          )
        end
      index_reports =
        indexes.map do |index|
          index.slice(
            "index_schema", "index_name", "access_method", "unique_index", "primary_index",
            "exclusion_index", "valid", "ready", "live", "key_column_count",
            "total_attribute_count", "partial", "predicate_sql", "definition_sql",
          )
        end

      table.merge(
        "ownership_classification" => ownership_classification(table.fetch("table_name")),
        "primary_key" => primary_key.freeze,
        "primary_key_contract_hint" => primary_key_contract_hint(primary_key),
        "columns" => column_reports.freeze,
        "indexes" => index_reports.freeze,
      ).slice(
        "schema_name", "table_name", "relkind", "relpersistence", "is_partition", "owner_role",
        "ownership_classification", "primary_key", "primary_key_contract_hint", "columns", "indexes",
      ).freeze
    end

    def primary_key_contract_hint(primary_key)
      return "missing" if primary_key.empty?
      return "composite" if primary_key.length > 1
      return "single_bigint" if primary_key.first.fetch("sql_type") == "bigint"

      "single_non_bigint"
    end

    def candidate_hints(column_name)
      hints = []
      hints << column_name if CANDIDATE_NAMES.include?(column_name)
      hints << "uid_boundary" if column_name == "uid" || column_name.end_with?("_uid")
      hints << "id_suffix" if column_name.end_with?("_id")
      hints << "primary_key" if column_name == "id"
      hints.uniq.freeze
    end

    def ownership_classification(table_name)
      return "framework:#{FRAMEWORK_TABLES.fetch(table_name)}" if FRAMEWORK_TABLES.key?(table_name)

      prefix = FRAMEWORK_PREFIXES.keys.find { |candidate| table_name.start_with?(candidate) }
      return "framework:#{FRAMEWORK_PREFIXES.fetch(prefix)}" if prefix

      "requires_owner_review"
    end

    def summarize(table_reports)
      columns = table_reports.flat_map { |table| table.fetch("columns") }
      indexes = table_reports.flat_map { |table| table.fetch("indexes") }
      primary_keys = table_reports.map { |table| table.fetch("primary_key_contract_hint") }

      {
        table_count: table_reports.length,
        candidate_column_count: columns.count { |column| column.fetch("candidate_hints").any? },
        framework_table_count: table_reports.count do |table|
          table.fetch("ownership_classification").start_with?("framework:")
        end,
        missing_primary_key_count: primary_keys.count("missing"),
        non_bigint_primary_key_count: primary_keys.count("single_non_bigint"),
        composite_primary_key_count: primary_keys.count("composite"),
        hash_index_count: indexes.count { |index| index.fetch("access_method") == "hash" },
        invalid_index_count: indexes.count { |index| !index.fetch("valid") },
        unready_index_count: indexes.count { |index| !index.fetch("ready") },
      }.freeze
    end
  end
end
