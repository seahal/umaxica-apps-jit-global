# typed: false
# frozen_string_literal: true

# Deletes authorization transactions whose expiry is at least RETENTION_PERIOD in the past. Nothing
# reads a transaction after it expires; without this, rows accumulated without bound
# (plans/active/sign-fqdn-integrated-plan.md section 5).
class OidcAuthorizationTransactionPurger
  MODELS = {
    "app" => ClientOidcAuthorizationTransaction,
    "com" => VisitorOidcAuthorizationTransaction,
    "org" => OperatorOidcAuthorizationTransaction,
  }.freeze

  class << self
    public

    def call(now: Time.current, retention_period: OidcAuthorizationTransactionable::RETENTION_PERIOD)
      new(now: now, retention_period: retention_period).call
    end
  end

  public

  def initialize(now: Time.current, retention_period: OidcAuthorizationTransactionable::RETENTION_PERIOD)
    @now = now
    @retention_period = retention_period
  end

  def call
    MODELS.transform_values do |model|
      model.connection_owner.connected_to(role: :writing) do
        model.purgeable_at(now, retention_period: retention_period).delete_all
      end
    end
  end

  private

  attr_reader :now, :retention_period
end
