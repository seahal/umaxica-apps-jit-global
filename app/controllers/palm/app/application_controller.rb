# typed: false
# frozen_string_literal: true

module Palm
  module App
    # Base for Palm's browser-facing HTML pages. Palm is the native RP surface, so this is a thin
    # stack: it carries the same edge protections as BareController plus the region request context,
    # and nothing else. Machine endpoints (health, robots, sitemap, OIDC, CSP reports, the bearer
    # API) stay on BareController and deliberately do not participate in region routing.
    class ApplicationController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit
      include ::JumpRtReturnVerification
      include ::PreferenceGlobal

      AUTHENTICATION_MODE = :bare

      layout "palm/app/application"

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token, with: :exception

      # Surface-wide default web request limit (defense-in-depth baseline).
      # RateLimit stays a side-effect-free helper; the limit and its numeric
      # value are declared here on the inheriting controller.
      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "palm_app_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { render_rate_limited(retry_after: 60) },
      )

      # Palm renders regional HTML, so it owes the same `ri` contract as every other HTML surface:
      # a GET/HEAD without a valid region is redirected to the canonical URL that carries one, and
      # `PreferenceGlobal#default_url_options` then propagates it into every generated link.
      # See docs/architecture/preference.md and test/unit/security/ri_routing_contract_test.rb.
      before_action :verify_jump_return_rt!, if: :jump_return_rt_request?
      before_action :resolve_param_context
      before_action :set_region
    end
  end
end
