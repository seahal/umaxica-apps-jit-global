# typed: false
# frozen_string_literal: true

# Routes OTP email through a Noticed notifier while the migration is in progress.
#
# This exists only so the ~20 call sites that already go through OtpAdapter.for
# need no change while the rollout flag is flipped surface by surface. It is
# deleted together with OtpEmailAdapter and OtpEmailNotifierRollout once the call
# sites address Notify::<Surface>::OtpNotifier directly.
class OtpEmailNotifierAdapter < OtpAdapter
  def initialize(notifier)
    super()
    @notifier = notifier
  end

  def deliver(record:, otp_code:, verification_token: nil, public_id: nil, purpose: nil, **)
    notifier_params = {
      record: record,
      otp_code: otp_code,
      verification_token: verification_token,
      public_id: public_id,
    }
    notifier_params[:purpose] = purpose if purpose.present?
    @notifier.issue(**notifier_params)
  end
end
