# typed: false
# frozen_string_literal: true

# Owner-side response adapter for org administration pages moved behind an HTTPS owner (R5-WU12).
#
# The owner keeps the existing controller logic verbatim; this concern turns its page outcomes into
# a JSON answer the Base Self-RP relays: `{component, props}` for a rendered page, `{redirect}` for
# a redirect, and `{error: "step_up_required", scope}` when Step-Up must run first. JSON responses
# of the original API format pass through unchanged. Step-Up is checked here against the actor's own
# root; administrative audit rows record the browser facts forwarded by the authenticated RP.
#
# Deviation recorded in evidence: these org administration props are composed at the owner (same
# application, same i18n and route helpers) rather than in the RP, to keep the existing behavior
# exact while the data and decisions move behind the owner.
# Contract: the including controller declares `before_action :apply_browser_context` right after
# authenticating its caller.
module OwnerPageResponses
  extend ActiveSupport::Concern

  private

  # The RP forwards the browser's requested format and its own URL context so respond_to branches
  # and route helpers behave exactly as they did in the page itself.
  def apply_browser_context
    format = request.headers["X-Browser-Format"].to_s
    request.format = format if %w(html json).include?(format)
    options = JSON.parse(request.headers["X-Browser-Url-Options"].presence || "{}")
    keys = PreferenceGlobal::PARAM_CONTEXT_KEYS.map(&:to_s)
    @browser_url_options = options.is_a?(Hash) ? options.slice(*keys).symbolize_keys : {}
  rescue JSON::ParserError
    @browser_url_options = {}
  end

  def default_url_options = @browser_url_options || {}

  def render(*args, **options)
    return super unless options.key?(:inertia)

    super(json: { component: options[:inertia], props: options[:props] }, status: options.fetch(:status, :ok))
  end

  # The RP performs the redirect itself (always 303 See Other for these page outcomes).
  def redirect_to(location, **)
    render json: { redirect: location }
  end

  def require_step_up!(scope:, **)
    surface = self.class.const_get(:AVATAR_SURFACE, false)
    methods = avatar_actor.is_a?(Operator) ? [:passkey] : %i(email_otp passkey totp)
    requirement = StepUpRequirement.new(
      scope:, step_up_required: true, allowed_methods: methods, phishing_resistant_required: false,
      user_verification_required: false, full_reauthentication_required: false,
      session_binding: avatar_root.public_id, token_binding: avatar_root.public_id, ttl: VerificationBase::STEP_UP_TTL,
      purpose: "step_up", audience: "step_up:#{surface}", require_session_binding: true,
      actor_ref: avatar_actor.public_id, resource_ref: nil, tenant_ref: nil,
    )
    return true if StepUpResolver.call(token: avatar_root, requirement:).satisfied?

    render json: { error: "step_up_required", scope: }, status: :forbidden
    false
  end

  def current_operator = avatar_actor

  def audit_request
    Struct.new(:request_id, :remote_ip, :user_agent).new(
      request.headers["X-Browser-Request-Id"].presence || request.request_id,
      request.headers["X-Browser-Ip"].presence || request.remote_ip,
      request.headers["X-Browser-User-Agent"].to_s,
    )
  end
end
