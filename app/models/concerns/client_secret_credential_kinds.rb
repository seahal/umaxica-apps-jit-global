# typed: false
# frozen_string_literal: true

module ClientSecretCredentialKinds
  extend ActiveSupport::Concern

  # Kind constants
  LOGIN = ClientSecretCredentialKind::LOGIN
  TOTP = ClientSecretCredentialKind::TOTP
  RECOVERY = ClientSecretCredentialKind::RECOVERY
  API = ClientSecretCredentialKind::API
  ONE_TIME = ClientSecretCredentialKind::ONE_TIME

  ALL = [LOGIN, TOTP, RECOVERY, API].freeze

  # Predicates using string equality on user_secret_kind_id column (no JOINs)
  def login_secret_credential?
    user_secret_kind_id == LOGIN
  end

  def totp_secret_credential?
    user_secret_kind_id == TOTP
  end

  def recovery_secret_credential?
    user_secret_kind_id == RECOVERY
  end

  def api_secret_credential?
    user_secret_kind_id == API
  end

  def one_time_secret_credential?
    user_secret_kind_id == ONE_TIME
  end
end
