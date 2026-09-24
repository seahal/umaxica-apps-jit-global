# frozen_string_literal: true

require "fileutils"
require "json"

namespace :authority do
  desc "Inventory legacy resource-to-principal candidates without changing data"
  task owner_inventory: :environment do
    report_path = ENV.fetch("REPORT", "tmp/authority/owner_migration_inventory.json")
    result = AuthorityOwnerMigrationInventory.call
    path = Rails.root.join(report_path)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, result.to_json)

    puts JSON.pretty_generate(result.summary)
    puts "Report written to #{report_path}"
  end

  desc "Check every approved resource family for fail-closed owner cutover readiness"
  task cutover_guard: :environment do
    report_path = ENV.fetch("REPORT", "tmp/authority/owner_cutover_guard.json")
    families =
      AuthorityOwnerMigrationInventory::RESOURCE_CONFIGS.map do |configuration|
        result = AuthorityOwnerCutoverGuard.call(
          surface: configuration.fetch(:surface),
          resource_kind: configuration.fetch(:resource_kind),
        )
        {
          surface: result.surface,
          resource_kind: result.resource_kind,
          ready: result.ready?,
          resource_count: result.resource_count,
          authoritative_owner_count: result.authoritative_owner_count,
          cutover_established: result.cutover_established?,
          unresolved_count: result.unresolved_count,
          unresolved_resources: result.unresolved_resources,
          blocking_reasons: result.blocking_reasons,
        }
      end
    report = {
      ready: families.all? { |family| family.fetch(:ready) },
      families:,
    }
    path = Rails.root.join(report_path)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, JSON.pretty_generate(report))

    summary =
      families.map do |family|
        family.slice(
          :surface,
          :resource_kind,
          :ready,
          :cutover_established,
          :resource_count,
          :unresolved_count,
          :blocking_reasons,
        )
      end
    puts JSON.pretty_generate(ready: report.fetch(:ready), families: summary)
    puts "Report written to #{report_path}"
  end
end
