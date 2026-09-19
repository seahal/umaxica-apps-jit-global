# typed: false
# frozen_string_literal: true

require_relative "../../lib/umaxica/valkey/connection"
require_relative "../../lib/umaxica/valkey/cleanup"

# Isolates Valkey keys per test-run and per parallel worker. Logical DB indexes
# stay fixed (rate-limit 4, auth-state 6). After fork, rebuild the rate-limit
# store so its namespace includes the worker id.
module ValkeyTestIsolation
  module_function

  def install!
    Umaxica::Valkey::TestNamespace.ensure!
    return if @installed

    ActiveSupport::Testing::Parallelization.after_fork_hook do |worker|
      ENV["VALKEY_NAMESPACE_WORKER_ID"] = worker.to_s
      replace_rate_limit_store!
    end
    @installed = true
  end

  def replace_rate_limit_store!
    valkey = Umaxica::Valkey::Settings.current
    store =
      ActiveSupport::Cache::RedisCacheStore.new(
        url: valkey.rate_limit.url,
        namespace: Umaxica::Valkey::TestNamespace.rate_limit_namespace,
        error_handler: Umaxica::Valkey::StoreErrorHandler.lambda_for("rate_limit"),
      )
    wrapper = Rails.configuration.x.rate_limit.fetch(:store)
    wrapper.default_backend = store if wrapper.respond_to?(:default_backend=)
    wrapper.backend = store if wrapper.respond_to?(:backend=)
  end

  def cleanup_worker_keys!
    valkey = Umaxica::Valkey::Settings.current
    run_id = ENV.fetch("VALKEY_NAMESPACE_RUN_ID")
    worker_id = ENV.fetch("VALKEY_NAMESPACE_WORKER_ID")

    rate_limit_connection = Umaxica::Valkey::Connection.new(
      url: valkey.rate_limit.url,
      namespace: "test_cleanup",
    )
    Umaxica::Valkey::Cleanup.delete_by_prefix(
      rate_limit_connection,
      prefix: "#{Umaxica::Valkey::TestNamespace.rate_limit_namespace}:",
    )

    auth_connection = Umaxica::Valkey::Connection.new(
      url: valkey.auth_state.url,
      namespace: "test_cleanup",
    )
    [
      "auth_state:authorization_code:#{run_id}:#{worker_id}:",
      "auth_state:sign_out_notice:#{run_id}:#{worker_id}:",
      "auth_state:admission:#{run_id}:#{worker_id}:",
    ].each do |prefix|
      Umaxica::Valkey::Cleanup.delete_by_prefix(auth_connection, prefix: prefix)
    end
  ensure
    rate_limit_connection&.close
    auth_connection&.close
  end
end
