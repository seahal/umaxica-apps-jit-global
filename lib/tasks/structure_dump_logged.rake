# frozen_string_literal: true

# The test environment creates UNLOGGED tables for speed (config/environments/test.rb), and
# pg_dump preserves that persistence. A structure file dumped from the test database would then
# create UNLOGGED tables in development and production, and any later migration adding a
# permanent table with a foreign key to them fails with "constraints on permanent tables may
# reference only permanent tables". Structure files therefore always record plain tables; the
# test environment still applies UNLOGGED when it creates tables.
namespace :db do
  task normalize_structure_persistence: :environment do
    Rails.root.glob("db/*structure.sql").each do |path|
      sql = path.read
      normalized = sql.gsub(/CREATE UNLOGGED (TABLE|SEQUENCE)/, "CREATE \\1")
      path.write(normalized) unless normalized == sql
    end
  end
end

Rake::Task.tasks.each do |task|
  next unless task.name == "db:schema:dump" || task.name.start_with?("db:schema:dump:")

  task.enhance { Rake::Task["db:normalize_structure_persistence"].execute }
end
