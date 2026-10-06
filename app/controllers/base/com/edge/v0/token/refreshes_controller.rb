# typed: false
# frozen_string_literal: true

class Base::Com::Edge::V0::Token::RefreshesController < Base::Com::AuthorityController
  include SignEdgeV0JsonApi
  include ::PreferenceWebCookieEndpoint

  AUTHENTICATION_MODE = :deny_all
  declare_authentication_mode! :open, only: :create

  before_action :ensure_json_request

  def create
    response.set_header("Cache-Control", "no-store")

    if params[:refresh_token].present?
      render json: {
        error: I18n.t("sign.token_refresh.errors.invalid_refresh_token"),
        error_code: "invalid_refresh_transport",
      }, status: :bad_request
      return
    end

    refresh_plain = cookies[AuthenticationBase::REFRESH_COOKIE_KEY]

    if refresh_plain.blank?
      render json: {
        error: I18n.t("sign.token_refresh.errors.missing_refresh_token"),
        error_code: "missing_refresh_token",
      }, status: :bad_request
      return
    end

    refresh_public_id, = token_class.parse_refresh_token(refresh_plain.to_s)
    token_record = find_refresh_token_record(refresh_public_id)
    if token_record&.restricted?
      handle_restricted_refresh_rejected(token_record, refresh_public_id)
      render json: {
        error: I18n.t(token_refresh_error_key(refresh_failure_code)),
        error_code: refresh_failure_code,
      }, status: refresh_failure_status
      return
    end

    credentials = refresh_access_token(refresh_plain)

    if credentials
      sync_consented_buffer_cookie_safely!
      render json: { refreshed: true, dbsc: credentials[:dbsc] }, status: :ok
    else
      status = refresh_failure_status
      code = refresh_failure_code
      render json: {
        error: I18n.t(token_refresh_error_key(code)),
        error_code: code,
      }, status: status
    end
  end

  private

  def token_refresh_error_key(code)
    {
      "invalid_refresh_token" => "sign.token_refresh.errors.invalid_refresh_token",
      "withdrawal_required" => "sign.token_refresh.errors.withdrawal_required",
      "administrative_access_locked" => "sign.token_refresh.errors.invalid_refresh_token",
      "restricted_session" => "sign.token_refresh.errors.restricted_session",
    }.fetch(code) { "sign.token_refresh.errors.invalid_refresh_token" }
  end
end
