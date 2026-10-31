# typed: false
# frozen_string_literal: true

module PrivacyErasureRequestFlow
  extend ActiveSupport::Concern
  include WithdrawalCeremonyAuthentication

  private

  def render_privacy_erasure_new(subject)
    @privacy_request = latest_privacy_request_for(subject)
  end

  def render_privacy_erasure_status(subject)
    @privacy_request = latest_privacy_request_for(subject)
  end

  def latest_privacy_request_for(subject)
    privacy_requests_for(subject).order(created_at: :desc).first
  end

  def privacy_requests_for(subject)
    case subject
    when Client then subject.client_privacy_requests
    else
      raise ArgumentError, "unsupported privacy erasure subject: #{subject.class.name}"
    end
  end

  def render_privacy_erasure_forbidden
    render plain: I18n.t("privacy_erasure.forbidden"),
           status: :forbidden
  end
end
