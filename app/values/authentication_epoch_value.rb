# typed: false
# frozen_string_literal: true

# Actor authentication epoch rules shared by every OP issuance and redelivery path (R5-WU06/08,
# one.md section 6.3). The epoch is monotonic and only an identity stop advances it.
class AuthenticationEpochValue
  class << self
    public

    # True when a root may still mint or redeliver authority for this actor. A root records the
    # epoch read under the principal lock (D-163) and the actor's epoch only grows, so only equality
    # is current; a larger root epoch can only be corruption (D-165).
    def root_current?(root_token:, actor:)
      root_token.authentication_epoch == actor.authentication_epoch
    end
  end
end
