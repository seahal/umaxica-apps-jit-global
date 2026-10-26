# typed: false
# frozen_string_literal: true

class AuthenticationSelectedSessionRevoker
  def self.call(...)
    new(...).call
  end

  def initialize(owner:, token:, current_token: nil, current_session_public_id: nil, reason: "selected_session_revoked")
    @owner = owner
    @token = token
    @current_token = current_token
    @current_session_public_id = current_session_public_id
    @reason = reason
  end

  def call
    return failure(:missing_token) if token.blank?
    return failure(:current_session) if current_session?

    AuthenticationLogoutCurrentSession.call(
      resource: owner,
      token: token,
      reason: reason,
      cause: "revoke_others", # D-173
    )
    LogoutResult.success(token: token, revoked_tokens: [token], message: :session_revoked)
  end

  private

  attr_reader :owner, :token, :current_token, :current_session_public_id, :reason

  def current_session?
    token.id == current_token&.id || token.public_id == current_session_public_id
  end

  def failure(message)
    LogoutResult.new(
      status: :failure,
      token: token,
      revoked_tokens: [],
      redirect_to: nil,
      response_status: :unprocessable_content,
      message: message,
    )
  end
end
