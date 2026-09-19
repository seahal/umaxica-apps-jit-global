# typed: false
# frozen_string_literal: true

module Umaxica
  module Valkey
    module Namespaces
      module_function

      AUTHORIZATION_CODES = "auth_state:authorization_code"
      SIGN_OUT_NOTICES = "auth_state:sign_out_notice"
      ADMISSION = "auth_state:admission"

      RUNTIME_ID_PATTERN = /\A[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}\z/.freeze

      def authorization_codes(suite_run_id: nil, worker_id: nil, test_id: nil)
        namespace(AUTHORIZATION_CODES, suite_run_id: suite_run_id, worker_id: worker_id, test_id: test_id)
      end

      def sign_out_notices(suite_run_id: nil, worker_id: nil, test_id: nil)
        namespace(SIGN_OUT_NOTICES, suite_run_id: suite_run_id, worker_id: worker_id, test_id: test_id)
      end

      def admission(suite_run_id: nil, worker_id: nil, test_id: nil)
        namespace(ADMISSION, suite_run_id: suite_run_id, worker_id: worker_id, test_id: test_id)
      end

      # A test run supplies a unique scope before Rails boots. Production and development keep
      # their established namespaces because they do not share the test cleanup contract.
      def runtime_scope
        suite_run_id = ENV["VALKEY_NAMESPACE_RUN_ID"].presence
        return {} if suite_run_id.blank?
        unless suite_run_id.match?(RUNTIME_ID_PATTERN)
          raise Umaxica::Valkey::ConfigurationError, "invalid Valkey runtime scope"
        end

        worker_id = ENV["VALKEY_NAMESPACE_WORKER_ID"].presence
        { suite_run_id: suite_run_id, worker_id: worker_id }.compact
      end

      def namespace(base, suite_run_id:, worker_id:, test_id:)
        [base, suite_run_id, worker_id, test_id].compact_blank.join(":")
      end
    end
  end
end
