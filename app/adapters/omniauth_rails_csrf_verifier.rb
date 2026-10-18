# frozen_string_literal: true

class OmniauthRailsCsrfVerifier < OmniAuth::RailsCsrfProtection::TokenVerifier
  class << self
    public

    delegate :config, to: :ApplicationController
  end

  public

  # The pinned gem raises a removed exception alias; preserve the standard Rails predicate and current exception.
  def _call(env)
    @request = ActionDispatch::Request.new(env.dup)
    raise ActionController::InvalidCrossOriginRequest unless verified_request?
  end

  # Rails 8.2 fallback instrumentation requires this controller metadata; the gem does not supply it.
  def action_name
    "request"
  end
end
