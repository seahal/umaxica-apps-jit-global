# typed: false
# frozen_string_literal: true

require "digest"
require "open3"
require "tmpdir"

module SchemaDriftVerification
  module_function

  def normalize(sql, database: nil)
    require "pg_query"

    normalized = sql.gsub(/^CREATE UNLOGGED (TABLE|SEQUENCE) /, 'CREATE \1 ')
    normalized = normalize_roles(normalized, database:)
    normalized.gsub(/AS (\$\w*\$)(.*?)\1;/m) do
      delimiter = Regexp.last_match(1)
      body = Regexp.last_match(2)
      scan, = PgQuery.scan(body)
      # SQL string and quoted-identifier tokens retain their exact bytes, including whitespace.
      tokens = scan.tokens.map { |token| body.byteslice(token.start...token.end) }
      "AS #{delimiter}#{tokens.join("\n")}#{delimiter};"
    end
  end

  def normalize_roles(sql, database:)
    expected = Digest::SHA256.hexdigest(database)[0, 12] unless database.nil?
    sql.gsub(/\bumaxica_(app|com|org)_(email|telephone)_hmac_definer_([0-9a-f]{12})\b/) do
      role = Regexp.last_match
      if !database.nil? && role[3] != expected
        raise ArgumentError, "HMAC definer role does not match database #{database}"
      end

      "umaxica_#{role[1]}_#{role[2]}_hmac_definer_DATABASE"
    end
  end

  def dump_matches?(configuration, reference, directory)
    previous_schema = ENV["SCHEMA"]
    ENV["SCHEMA"] = File.join(directory, "#{configuration.name}.#{configuration.schema_format}")
    ActiveRecord::Tasks::DatabaseTasks.dump_schema(configuration)
    generated = File.read(ENV.fetch("SCHEMA"))
    return File.read(reference) == generated unless configuration.schema_format == :sql

    normalize(File.read(reference)) == normalize(generated, database: configuration.database)
  ensure
    if previous_schema.nil?
      ENV.delete("SCHEMA")
    else
      ENV["SCHEMA"] = previous_schema
    end
  end
end

namespace :db do
  desc "Compare temporary schema dumps with tracked files without changing the worktree"
  task verify_no_schema_drift: :environment do
    Umaxica::TestEnvironment::DatabaseSafety.verify!
    configurations =
      ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).reject do |configuration|
        configuration.replica? || !configuration.schema_dump
      end
    schema_files = []
    drifted = []
    Dir.mktmpdir("umaxica-schema-verification-") do |directory|
      configurations.each do |configuration|
        reference = ActiveRecord::Tasks::DatabaseTasks.schema_dump_path(configuration)
        relative = Pathname.new(reference).relative_path_from(Rails.root).to_s
        schema_files << relative
        unless SchemaDriftVerification.dump_matches?(configuration, reference, directory)
          drifted << relative
        end
      end
    end

    if schema_files.empty?
      puts "No schema dump files are configured for #{Rails.env}."
      next
    end

    stdout, stderr, status = Open3.capture3(
      "git", "diff", "--name-only", "--", *schema_files, chdir: Rails.root.to_s,
    )
    abort(stderr.presence || I18n.t("db_verify_no_schema_drift.unable_to_inspect")) unless status.success?
    drifted.concat(stdout.lines.map(&:strip))
    drifted.uniq!
    drifted.sort!
    if drifted.any?
      abort(
        [
          "Schema drift detected in committed schema dump files:",
          *drifted.map { |file| "  - #{file}" },
          I18n.t("db_verify_no_schema_drift.run_reset_workflow"),
        ].join("\n"),
      )
    end

    puts "No schema drift detected in #{schema_files.uniq.size} schema dump file(s)."
  end
end
