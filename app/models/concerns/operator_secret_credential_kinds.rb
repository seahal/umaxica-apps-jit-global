# typed: false
# frozen_string_literal: true

module OperatorSecretCredentialKinds
  extend ActiveSupport::Concern

  # Kind constants (integer IDs)
  LOGIN = OperatorSecretCredentialKind::LOGIN
  ONE_TIME = OperatorSecretCredentialKind::ONE_TIME

  ALL = [LOGIN].freeze

  # Predicates using string equality on staff_secret_kind_id column (no JOINs)
  def login_secret_credential?
    staff_secret_kind_id == LOGIN
  end

  def one_time_secret_credential?
    staff_secret_kind_id == ONE_TIME
  end
end
