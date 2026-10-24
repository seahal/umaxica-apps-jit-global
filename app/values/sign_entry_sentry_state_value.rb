# typed: false
# frozen_string_literal: true

# The result of one server-selected Sign In/Sign Up availability lookup.  The
# uppercase constants are deliberate: these are the two protocol states named
# by the Sign Entry Sentry ADR, not a lifecycle enum or persisted status.
SignEntrySentryStateValue =
  Data.define(:state, :surface, :flow) do
    def allowed? = state == self.class::ALLOWED

    def blocked? = state == self.class::BLOCKED
  end

SignEntrySentryStateValue::ALLOWED = :ALLOWED
SignEntrySentryStateValue::BLOCKED = :BLOCKED
