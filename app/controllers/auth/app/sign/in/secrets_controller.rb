# frozen_string_literal: true

class Auth::App::Sign::In::SecretsController < Auth::App::ApplicationController
  include SurfaceInertiaPage
  include AuthenticationModeSwitchGuard
  include CloudflareTurnstile
  include TurnstilePageProps
  include MinimumResponseBudget

  AUTHENTICATION_MODE = :guest
  declare_authentication_mode! :guest
  prepend_before_action :require_sign_in_ceremony_admission!
  ensure_fqdn_gate_first!
  prepend_before_action :apply_default_no_store
  before_action :start_minimum_response_budget
  after_action :enforce_minimum_response_budget

  rate_limit to: 5, within: 1.minute, by: -> { request.remote_ip },
             scope: "auth_app_sign_in", name: "secret_ip_burst", store: rate_limit_store,
             only: :create, with: -> { render_rate_limited(retry_after: 60) }
  rate_limit to: 20, within: 15.minutes, by: -> { request.remote_ip },
             scope: "auth_app_sign_in", name: "secret_ip_sustained", store: rate_limit_store,
             only: :create, with: -> { render_rate_limited(retry_after: 900) }
  before_action :resolve_secret_client, only: :create
  rate_limit to: 5, within: 1.minute, by: -> { @resolved_client&.id || "unknown:#{request.remote_ip}" },
             scope: "auth_app_sign_in", name: "secret_client_burst", store: rate_limit_store,
             only: :create, with: -> { render_rate_limited(retry_after: 60) }

  public

  def new
    render_form
  end

  def create
    flow = auth_ceremony_local_sign_in_flow
    transaction = auth_ceremony_authorization_transaction
    ceremony = admitted_auth_ceremony_session
    unless @resolved_client && (flow || transaction) && ceremony
      return render_form(status: :unprocessable_content, error: t("sign.app.authentication.secret.invalid"))
    end

    claim =
      if transaction
        ClientSecretClaimCommitter.call_for_oidc!(
          client: @resolved_client, secret: secret_params[:secret],
          transaction: transaction, ceremony: ceremony,
        )
      else
        ClientSecretClaimCommitter.call!(
          client: @resolved_client, secret: secret_params[:secret], flow: flow,
          ceremony: ceremony,
        )
      end
    return render_form(status: :unprocessable_content, error: t("sign.app.authentication.secret.invalid")) unless claim

    result = AuthenticationSessionCommitter.call(
      controller: self, resource: claim.client, pt: signed_pt_param, ri: current_region_identifier,
      auth_method: "secret_credential",
    )
    if transaction && result[:status] == :authentication_evidence_recorded
      redirect_to_sign_in_sequence!(pt: signed_pt_param, status: :see_other)
    elsif %i(authentication_evidence_recorded mfa_required).include?(result[:status]) && result[:redirect_path]
      redirect_to(result.fetch(:redirect_path), status: :see_other)
    else
      render_form(status: :unprocessable_content, error: t("sign.app.authentication.secret.invalid"))
    end
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError
    render plain: t("errors.rate_limit.backend_unavailable"), status: :service_unavailable
  end

  private

  def resolve_secret_client
    @resolved_client =
      if cloudflare_turnstile_validation["success"] == true
        ClientSecretIdentityResolverQuery.call(identifier: secret_params[:identifier])
      end
  end

  def secret_params
    {
      identifier: params[:identifier],
      secret: params[:secret],
      authenticity_token: params[:authenticity_token],
      "cf-turnstile-response": params["cf-turnstile-response"],
      ri: params[:ri],
      pt: params[:pt],
    }.with_indifferent_access
  end

  def minimum_response_budget_enabled?
    action_name == "create"
  end

  def render_form(status: :ok, error: nil)
    render inertia: "auth/app/sign/in/secrets/new", status: status, props: {
      title: t("sign.app.authentication.secret.title"),
      label: t("sign.app.authentication.secret.label"),
      identifier_label: t("sign.app.authentication.secret.identifier_label"),
      submit: t("sign.app.authentication.secret.submit"),
      error: error,
      action: auth_app_sign_in_secret_path(ri: current_region_identifier, pt: signed_pt_param),
      authenticity_token: form_authenticity_token,
      turnstile: turnstile_visible_props,
    }
  end
end
