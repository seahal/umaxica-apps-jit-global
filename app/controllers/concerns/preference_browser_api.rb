# typed: false
# frozen_string_literal: true

# The HTTP contract of the browser theme and cookie-consent endpoints
# (`/api/v0/preferences/{theme,cookie}`), shared by every family that serves them on its own host.
#
# Preference credentials are host-only cookies (adr/cookie-domain-scope-by-surface.md), so each
# family answers these endpoints for its own host rather than one host answering for all. What they
# share is this adapter: media types, cache policy, and how a refused request is reported. The
# preference read/update itself stays in PreferenceWebThemeEndpoint / PreferenceWebCookieEndpoint;
# nothing here reads or writes a preference.
#
# Opt in from the concrete controller, after its last inherited `prepend_before_action`:
#
#   include ::PreferenceBrowserApi
#   preference_browser_api!
#
# Request order once declared (docs/reference/api-design-standards.md, "Content negotiation"):
#
#   FQDN availability gate -> no-store -> 406 -> 415 -> rate limit, CSRF, preference hydration ...
#
# The negotiation filters are registered by ApiContentNegotiation when it is included. Declaring
# them again with `prepend_before_action` moves them, it does not add a second copy: ActiveSupport
# drops an existing callback with the same filter before inserting the new one. Prepending is what
# puts 406/415 ahead of the CSRF and credential callbacks the family ApplicationController
# registered before this controller was defined.
#
# Contract with the including class:
# - includes FqdnAvailabilityGate (`ensure_fqdn_gate_first!`), and a controller under a
#   DefaultNoStore policy root re-prepends `:apply_default_no_store` after `preference_browser_api!`;
# - uses `protect_from_forgery ... with: :exception`, so a refused token raises.
#
# See adr/preference-browser-transport-family-capability.md.
module PreferenceBrowserApi
  extend ActiveSupport::Concern

  include ProblemDetailsRendering
  include ApiContentNegotiation

  # Field-level type for a 422 `errors` entry (docs/reference/api-design-standards.md, "Errors").
  INVALID_FIELD_TYPE = "#{ProblemType::NAMESPACE}:invalid-format".freeze

  class_methods do
    def preference_browser_api!
      prepend_before_action(:enforce_api_request_media_type!)
      prepend_before_action(:enforce_api_acceptable_response_type!)
      prepend_before_action(:set_preference_browser_api_no_store!)
      ensure_fqdn_gate_first!

      rescue_from(ActionDispatch::Http::Parameters::ParseError, with: :render_preference_browser_api_malformed_body)
      rescue_from(ActionController::InvalidCrossOriginRequest, with: :render_preference_browser_api_csrf_failure)
      rescue_from(PreferenceToken::AudienceMismatchError, with: :render_preference_browser_api_foreign_token)
    end
  end

  private

  # Every answer here carries per-visitor preference state or rotates a credential cookie.
  def set_preference_browser_api_no_store!
    response.set_header("Cache-Control", "no-store")
  end

  # A body that is not JSON at all (including a raw NUL byte the parser refuses). A well-formed body
  # with a bad value is a 422 instead.
  def render_preference_browser_api_malformed_body
    render_problem(:bad_request)
  end

  def render_preference_browser_api_csrf_failure
    render_problem(:csrf_verification_failed)
  end

  # A presented preference access token minted for another host or audience. A missing token is not
  # this case: the endpoints are open, and anonymous visitors keep their existing behavior.
  def render_preference_browser_api_foreign_token
    render_problem(:authentication_required)
  end

  # `pointers` are RFC 6901 JSON Pointers into the request body.
  def render_preference_browser_api_invalid_fields(pointers)
    # rubocop:disable I18n/RailsI18n/DecorateString
    errors =
      pointers.map do |pointer|
        { pointer: pointer, type: INVALID_FIELD_TYPE, detail: "#{pointer} is missing or not an accepted value." }
      end
    # rubocop:enable I18n/RailsI18n/DecorateString

    render_problem(:validation_failed, errors: errors)
  end
end
