# typed: false
# frozen_string_literal: true

module VisitorSecretCredentialKinds
  extend ActiveSupport::Concern

  LOGIN = VisitorSecretCredentialKind::LOGIN
  RECOVERY = VisitorSecretCredentialKind::RECOVERY
  API = VisitorSecretCredentialKind::API
  ONE_TIME = VisitorSecretCredentialKind::ONE_TIME

  ALL = [LOGIN, RECOVERY, API].freeze

  def login_secret_credential?
    visitor_secret_credential_kind_id == LOGIN
  end

  def recovery_secret_credential?
    visitor_secret_credential_kind_id == RECOVERY
  end

  def api_secret_credential?
    visitor_secret_credential_kind_id == API
  end

  def one_time_secret_credential?
    visitor_secret_credential_kind_id == ONE_TIME
  end
end
