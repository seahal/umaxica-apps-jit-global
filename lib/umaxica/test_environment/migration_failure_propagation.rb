# typed: false
# frozen_string_literal: true

require "fileutils"

module Umaxica
  module TestEnvironment
    # Rails' pinned test-schema loader invokes db:test:prepare through Kernel#system and does not
    # surface a false return. A preparation failure must stop the test process before any test
    # file is loaded, especially when the disposable-database manifest is invalid.
    module MigrationFailurePropagation
      def load_schema!
        root = defined?(ENGINE_ROOT) ? ENGINE_ROOT : Rails.root

        FileUtils.cd(root) do
          ActiveRecord::Base.connection_handler.clear_all_connections!(:all)
          prepared = system("bin/rails db:test:prepare")
          raise Umaxica::TestEnvironment::ConfigurationError, "db:test:prepare failed" unless prepared
        end
      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Migration.singleton_class.prepend(Umaxica::TestEnvironment::MigrationFailurePropagation)
end
