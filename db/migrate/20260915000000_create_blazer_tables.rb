# typed: false
# frozen_string_literal: true

# Storage for the Blazer SQL dashboard (config/blazer.yml, config/routes/blazer.rb). Mirrors
# `rails generate blazer:install` minus `blazer_audits`: query auditing is disabled in
# config/initializers/blazer.rb, so that table is never read or written.
class CreateBlazerTables < ActiveRecord::Migration[8.2]
  def up
    create_table(:blazer_queries) do |t|
      t.references(:creator)
      t.string(:name)
      t.text(:description)
      t.text(:statement)
      t.string(:data_source)
      t.string(:status)
      t.timestamps(null: false)
    end

    create_table(:blazer_dashboards) do |t|
      t.references(:creator)
      t.string(:name)
      t.timestamps(null: false)
    end

    create_table(:blazer_dashboard_queries) do |t|
      t.references(:dashboard)
      t.references(:query)
      t.integer(:position)
      t.timestamps(null: false)
    end

    create_table(:blazer_checks) do |t|
      t.references(:creator)
      t.references(:query)
      t.string(:state)
      t.string(:schedule)
      t.text(:emails)
      t.text(:slack_channels)
      t.string(:check_type)
      t.text(:message)
      t.datetime(:last_run_at)
      t.timestamps(null: false)
    end
  end

  def down
    drop_table(:blazer_checks)
    drop_table(:blazer_dashboard_queries)
    drop_table(:blazer_dashboards)
    drop_table(:blazer_queries)
  end
end
