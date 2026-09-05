# frozen_string_literal: true

require "flipper"
require "flipper/ui"
require "flipper/adapters/memory"
require "flipper/adapters/active_record"

# Flags are durable configuration, not cache: they must survive a store restart or
# eviction, because a lost flag silently reverts every feature to its default. They
# therefore live in PostgreSQL (the `platform` database) rather than Valkey.
#
# The `platform` database has no replica on purpose. A flag is read immediately after
# it is toggled, so replication lag would surface as a flip that did not apply.
#
# The reading role points at the same database rather than being omitted: the
# DatabaseSelector middleware (config/initializers/multi_db.rb) wraps GET requests in
# `connected_to(role: :reading)`, and a model without a reading pool raises
# ActiveRecord::ConnectionNotDefined there.
#
# Wrapped in the same load hook the adapter uses to define its models: the adapter
# defers `Flipper::Adapters::ActiveRecord::Model` until ActiveRecord::Base is loaded,
# so referencing it eagerly here raises NameError during boot.
ActiveSupport.on_load(:active_record) do
  Flipper::Adapters::ActiveRecord::Model.connects_to(
    database: { writing: :platform, reading: :platform },
  )
end

# The test suite must not depend on a database connection for flag reads.
Flipper.configure do |config|
  config.adapter do
    if Rails.env.test?
      Flipper::Adapters::Memory.new
    else
      Flipper::Adapters::ActiveRecord.new
    end
  end
end

Rails.application.configure do
  config.flipper.memoize = true
  config.flipper.preload = true
end

# The UI is mounted on the developer surface (config/routes/base.rb).
Flipper::UI.configure do |config|
  # The version check calls flippercloud.io from the browser on every page load. The control-plane
  # surface must not reach third-party origins to render.
  config.version_check_enabled = false
end
