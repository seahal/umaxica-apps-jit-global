# typed: false
# frozen_string_literal: true

# Runtime kill switch for outbound delivery channels that depend on a third party
# (Amazon SNS for SMS, the SMTP relay for email, APNs/FCM for push).
#
# Polarity is deliberate and the opposite of
# ExternalAuthentication::FlipperProviderAvailabilityAdapter: the feature names a
# *suspension*, so an unset or unknown feature means "not suspended" and delivery runs
# normally. A flag store that has never been written must not take the product's OTP
# delivery down, whereas an operator enabling the flag during a provider incident must
# stop delivery immediately. The authentication adapter faces the opposite risk (a lost
# flag must not let a ceremony through) and therefore reads unset as disabled.
class OutboundChannelSuspension
  CHANNEL_FEATURE_NAMES = {
    sms: :outbound_sms_suspended,
    email: :outbound_email_suspended,
    promotional_email: :outbound_promotional_email_suspended,
    push: :outbound_push_suspended,
  }.freeze

  def self.suspended?(channel, flipper: Flipper)
    new(flipper: flipper).suspended?(channel)
  end

  def initialize(flipper: Flipper)
    @flipper = flipper
  end

  # Suspending :email stops promotional mail as well: it is the wider switch.
  def suspended?(channel)
    feature_name =
      CHANNEL_FEATURE_NAMES.fetch(channel.to_sym) do
        raise ArgumentError, "unsupported outbound channel: #{channel}"
      end

    if (channel.to_sym == :promotional_email) && FeatureFlags.enabled?(
      CHANNEL_FEATURE_NAMES.fetch(:email),
      flipper: @flipper,
    )
      return true
    end

    FeatureFlags.enabled?(feature_name, flipper: @flipper)
  end
end
