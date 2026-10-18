# typed: false
# frozen_string_literal: true

require "fileutils"

module Umaxica
  module Valkey
    # A local claim prevents two wrappers from reusing the same run scope concurrently. A
    # process killed with SIGKILL leaves the claim for deliberate manual recovery.
    module TestRunScope
      ROOT = File.expand_path("../../../tmp/test-valkey-runs", __dir__).freeze
      RUN_ID_PATTERN = /\A[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}\z/.freeze

      module_function

      def claim!(run_id)
        validate!(run_id)
        FileUtils.mkdir_p(ROOT)
        path = marker_path(run_id)
        File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |marker|
          marker.write("#{Process.pid}\n")
        end
        path
      rescue Errno::EEXIST => e
        raise ConfigurationError, "Valkey test run ID is already claimed: #{run_id.inspect}", cause: e
      end

      def release!(run_id)
        validate!(run_id)
        File.delete(marker_path(run_id))
      rescue Errno::ENOENT
        nil
      end

      def claimed?(run_id)
        validate!(run_id)
        File.exist?(marker_path(run_id))
      end

      def ensure_cleanup_allowed!(run_id, allow_claimed: ENV["VALKEY_CLEANUP_ALLOW_CLAIM"] == "1")
        return unless claimed?(run_id) && !allow_claimed

        raise ConfigurationError,
              "Valkey test run is still claimed; use the owning wrapper or explicit recovery"
      end

      def validate!(run_id)
        return if run_id.to_s.match?(RUN_ID_PATTERN)

        raise ConfigurationError, "invalid VALKEY_NAMESPACE_RUN_ID"
      end

      def marker_path(run_id)
        File.join(ROOT, "#{run_id}.claim")
      end
    end
  end
end
