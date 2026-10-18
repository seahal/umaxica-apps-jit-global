# typed: false
# frozen_string_literal: true

# Actor authentication epoch rules shared by every OP issuance and redelivery path (R5-WU06/08,
# one.md section 6.3). The epoch is monotonic and only an identity stop advances it.
class AuthenticationEpochValue
  class << self
    public

    # True when a root may still mint or redeliver authority for this actor. A root issued under an
    # older epoch is cut off by the stop that advanced it; a root without a recorded epoch predates
    # epoch tracking and is only valid while no stop has occurred.
    def root_current?(root_token:, actor:)
      actor_epoch = actor.authentication_epoch
      return actor_epoch.zero? if root_token.authentication_epoch.nil?

      root_token.authentication_epoch >= actor_epoch
    end
  end
end
