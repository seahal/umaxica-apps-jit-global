# typed: false
# frozen_string_literal: true

# Signals that cleanup acquired an OP Flow lock from a stale unbound instance and must retry
# after that lock has been rolled back, using the bound actor-first lock path.
class SignUpCleanupStalePrincipalBindingError < StandardError; end
