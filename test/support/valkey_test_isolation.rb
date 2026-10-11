# typed: false
# frozen_string_literal: true

# Gives application-owned auth-state keys a run and worker scope during Rails tests. The wrapper
# owns the run id; this hook only changes the worker component after Rails forks a process.
module ValkeyTestIsolation
  RUN_ID_PATTERN = /\A[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}\z/.freeze

  module_function

  def install!
    run_id = ENV.fetch("VALKEY_NAMESPACE_RUN_ID")
    raise ArgumentError, "invalid VALKEY_NAMESPACE_RUN_ID" unless run_id.match?(RUN_ID_PATTERN)

    ENV["VALKEY_NAMESPACE_WORKER_ID"] ||= "parent"
    return if @installed

    ActiveSupport::Testing::Parallelization.after_fork_hook do |worker|
      ENV["VALKEY_NAMESPACE_WORKER_ID"] = worker.to_s
    end
    @installed = true
  end
end
