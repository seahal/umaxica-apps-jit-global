# typed: false
# frozen_string_literal: true

# Shared identity logic for Client, Operator, and Visitor.
# These are the authenticatable principals that own credentials and sessions.
module Identity
  extend ActiveSupport::Concern

  include ::Withdrawable

  public

  # `status_id` numericality is declared by each host class (Client, Operator, Visitor) so the
  # validation is visible where the attribute lives, rather than injected by inclusion.
  def login_allowed?
    active? && self.class::LOGIN_BLOCKED_STATUS_IDS.exclude?(status_id)
  end

  # D-106 (WU-34): the Sign In boundary additionally refuses a registration that never finished.
  # Sign-up itself keeps using `login_allowed?` for its own pending principal.
  def sign_in_allowed?
    login_allowed? && self.class::UNFINISHED_REGISTRATION_STATUS_IDS.exclude?(status_id)
  end
end
