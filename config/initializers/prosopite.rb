# typed: false
# frozen_string_literal: true

unless Rails.env.production?
  module ProsopiteWritingRoleFingerprint
    def fingerprint(query)
      return super if ActiveRecord::Base.current_role == ActiveRecord.writing_role

      ActiveRecord::Base.connected_to(role: ActiveRecord.writing_role) { super }
    end
  end

  unless Prosopite.singleton_class < ProsopiteWritingRoleFingerprint
    Prosopite.singleton_class.prepend(ProsopiteWritingRoleFingerprint)
  end

  Prosopite.rails_logger = true # Logs to Rails logger.
  Prosopite.prosopite_logger = true # Logs to log/prosopite.log.
  Prosopite.raise = Rails.env.local? # Fail fast on N+1 in dev and test.

  # Ignore internal Rails tables during multi-DB boot
  Prosopite.ignore_queries = [
    /SELECT.*FROM.*"ar_internal_metadata"/,
    /SELECT.*FROM.*"schema_migrations"/,
  ]

  # Mission Control Jobs pages its own Solid Queue tables (a lookup per recurring task key, 1000-row
  # job pages). Those N+1s are in gem code this application does not own and cannot fix, so exempt
  # stack frames inside that gem. The exemption is keyed on the stack path rather than on the
  # Solid Queue tables, so application code that queries them is still scanned.
  Prosopite.allow_stack_paths = [%r{/mission_control-jobs-}]
end

if Rails.env.development?
  require "prosopite/middleware/rack"

  Rails.configuration.middleware.use(Prosopite::Middleware::Rack)
end
