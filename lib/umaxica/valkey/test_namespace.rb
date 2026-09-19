# typed: false
# frozen_string_literal: true

require "securerandom"

module Umaxica
  module Valkey
    # Assigns a suite-run identifier before Rails parallel workers fork. Workers
    # share the run id and differ only by worker id. Logical DB indexes stay fixed.
    module TestNamespace
      RUN_ID_PATTERN = /\A[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}\z/.freeze

      public

      module_function

      def ensure!(environment: ENV)
        if environment["VALKEY_NAMESPACE_RUN_ID"].to_s.blank?
          environment["VALKEY_NAMESPACE_RUN_ID"] = "r#{Process.pid}#{SecureRandom.alphanumeric(10)}"
        end
        run_id = environment.fetch("VALKEY_NAMESPACE_RUN_ID")
        unless run_id.match?(RUN_ID_PATTERN)
          raise ConfigurationError,
                "VALKEY_NAMESPACE_RUN_ID must contain only letters, digits, dot, underscore, or hyphen"
        end

        environment["VALKEY_NAMESPACE_WORKER_ID"] = "parent" if environment["VALKEY_NAMESPACE_WORKER_ID"].to_s.blank?
        environment.fetch("VALKEY_NAMESPACE_RUN_ID")
      end

      def rate_limit_namespace(environment: ENV, rails_env: "test")
        [
          "rate_limit",
          rails_env,
          environment.fetch("VALKEY_NAMESPACE_RUN_ID"),
          environment.fetch("VALKEY_NAMESPACE_WORKER_ID"),
        ].join(":")
      end
    end
  end
end
