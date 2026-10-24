# typed: false
# frozen_string_literal: true

# REQ-CURFEW (WU-06, D-75): an attempt on the Sign-in path is within its curfew while the OP database
# that owns its Admission Binding reads a time before `curfew_at`. The clock is that model's
# `database_now`, read once per decision.
class AdmissionCurfewValue
  attr_reader :curfew_at, :decided_at

  class << self
    public

    def for(binding)
      model = binding.class
      decided_at = model.connection_class_for_self.connected_to(role: :writing) { model.database_now }
      new(curfew_at: binding.curfew_at, decided_at: decided_at)
    end
  end

  public

  def initialize(curfew_at:, decided_at:)
    raise ArgumentError, "curfew_at is required" if curfew_at.nil?
    raise ArgumentError, "decided_at is required" if decided_at.nil?

    @curfew_at = curfew_at
    @decided_at = decided_at
    freeze
  end

  def within?
    decided_at < curfew_at
  end
end
