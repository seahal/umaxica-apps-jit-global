# frozen_string_literal: true

require "fileutils"
require "json"

namespace :identifiers do
  desc "Inventory identifier-related PostgreSQL catalog facts without reading application rows"
  task inventory: :environment do
    raise RuntimeError, "identifier inventory is not permitted against production" if Rails.env.production?

    Umaxica::TestEnvironment::DatabaseSafety.verify!

    result = IdentifierContractInventoryQuery.call
    report_path = ENV["REPORT"]
    report_path = "tmp/identifier-contract/inventory.json" if report_path.nil?
    path = Rails.root.join(report_path)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, result.to_json)

    puts JSON.pretty_generate(
      connections: result.connections.length,
      tables: result.connections.sum { |connection| connection.fetch(:summary).fetch(:table_count) },
      summaries: result.connections.to_h { |connection|
        [connection.fetch(:connection_name), connection.fetch(:summary)]
      },
    )
    puts "Report written to #{path.relative_path_from(Rails.root)}"
  end
end
