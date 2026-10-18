# typed: false
# frozen_string_literal: true

# Shared behavior of the twelve cell principal models (Rp<Family><Realm>Principal).
module RpPrincipal
  extend ActiveSupport::Concern

  public

  # ActionPolicy resolves every cell principal to one policy.
  def policy_class = RpPrincipalPolicy

  # A local principal has no canonical lifecycle; disablement is the cell's own stop.
  def deactivated? = disabled_at.present?
end
