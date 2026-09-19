# typed: false
# frozen_string_literal: true

module SignVerificationTotpChecks
  extend ActiveSupport::Concern

  private

  def verify_totp!
    code = verification_params[:code].to_s
    unless code.match?(/\A\d{6}\z/)
      @verification_errors = ["確認コードが不正です"]
      return false
    end

    result = TotpWindowConsumer.call(credentials: active_totp_credentials, token: code)
    unless result.accepted?
      @verification_errors =
        if result.locked?
          ["確認コードの試行回数が上限に達しました。しばらくしてから再度お試しください"]
        else
          ["確認コードが正しくありません"]
        end
    end
    result.accepted?
  end

  def active_totp_credentials
    raise NotImplementedError, "#{self.class} must define #active_totp_credentials"
  end
end
