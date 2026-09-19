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
end
