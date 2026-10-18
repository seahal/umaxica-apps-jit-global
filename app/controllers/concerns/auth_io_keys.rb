# typed: false
# frozen_string_literal: true

module AuthIoKeys
  HOST_COOKIE_PREFIX = "__Host-"

  module Cookies
    ACCESS_BASENAME = "auth_access"
    REFRESH_BASENAME = "auth_refresh"
    DBSC_BASENAME = "auth_dbsc"

    public_constant :ACCESS_BASENAME
    public_constant :REFRESH_BASENAME
    public_constant :DBSC_BASENAME
  end

  module Headers
    AUTHORIZATION = "Authorization"
    SECURE_DBSC_REGISTRATION = "Secure-Session-Registration"
    SECURE_DBSC_CHALLENGE = "Secure-Session-Challenge"
    SECURE_DBSC_SESSION_ID = "Secure-Session-Id"
    SECURE_DBSC_RESPONSE = "Secure-Session-Response"
    SECURE_DBSC_SKIPPED = "Secure-Session-Skipped"
    DBSC_REGISTRATION = "Sec-Session-Registration"
    DBSC_CHALLENGE = "Sec-Session-Challenge"
    DBSC_SESSION_ID = "Sec-Session-Id"
    DBSC_RESPONSE = "Sec-Session-Response"
    DBSC_SKIPPED = "Sec-Session-Skipped"

    public_constant :AUTHORIZATION
    public_constant :SECURE_DBSC_REGISTRATION
    public_constant :SECURE_DBSC_CHALLENGE
    public_constant :SECURE_DBSC_SESSION_ID
    public_constant :SECURE_DBSC_RESPONSE
    public_constant :SECURE_DBSC_SKIPPED
    public_constant :DBSC_REGISTRATION
    public_constant :DBSC_CHALLENGE
    public_constant :DBSC_SESSION_ID
    public_constant :DBSC_RESPONSE
    public_constant :DBSC_SKIPPED
  end

  module Params
    RI = :ri
    PT = :pt
    NT = :nt
    # Signed binding of a phase-bound request to the flow instance its page was rendered for.
    FLOW_BINDING = :fb

    public_constant :RI
    public_constant :PT
    public_constant :NT
    public_constant :FLOW_BINDING
  end

  module Session
    DEFAULT_PT = :user_email_authentication_pt
    CHECKPOINT = :sign_in_checkpoint
    BULLETIN = CHECKPOINT

    public_constant :DEFAULT_PT
    public_constant :CHECKPOINT
    public_constant :BULLETIN
  end

  module Env
    AUTH_REFRESHED_FLAG = "auth_refreshed"

    public_constant :AUTH_REFRESHED_FLAG
  end

  public_constant :HOST_COOKIE_PREFIX
end
